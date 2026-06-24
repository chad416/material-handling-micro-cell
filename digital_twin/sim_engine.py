import asyncio
import logging
import random
import time
from asyncua import Server, ua, uamethod

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')
logger = logging.getLogger("MHMC_DigitalTwin")

class PackageSim:
    def __init__(self, pkg_id, barcode, route_target, position=0.0):
        self.id = pkg_id
        self.barcode = barcode
        self.route_target = route_target  # 1 = Lane A, 2 = Lane B, 9 = Reject
        self.position = position          # Position in meters along Conveyor 1
        self.width = 0.25                 # Package length (meters)
        self.diverted = False             # Has the package been diverted out of the main queue?
        self.exit_timer = 0.0             # Timer to track exit sensor duration
        self.velocity = 0.0               # Current velocity (m/s)

class DigitalTwinCell:
    def __init__(self):
        # Simulation Constants
        self.CONVEYOR_LENGTH = 4.2       # meters
        self.PE1_POS = 0.2
        self.PE2_POS = 1.2
        self.SCANNER_POS = 1.3
        self.PE3_POS = 2.2                # Diverter 1 check
        self.DIV1_POS = 2.2
        self.DIV2_POS = 3.2
        self.PE4_POS = 2.3                # Lane A exit verify (off-conveyor)
        self.PE5_POS = 3.3                # Lane B exit verify (off-conveyor)
        self.PE6_POS = 4.0                # Reject exit verify

        # State Variables
        self.current_state = 9            # 9 = IDLE (PackML)
        self.current_mode = 1             # 1 = AUTO (PackML)
        self.conveyor_speed_sp = 0.5      # setpoint
        self.conveyor_speed_fb = 0.0      # feedback
        self.motor_current = 0.0          # Amps
        self.conveyor_running = False
        self.conveyor_faulted = False
        
        # Sensor states
        self.pe1 = False
        self.pe2 = False
        self.pe3 = False
        self.pe4 = False
        self.pe5 = False
        self.pe6 = False

        # Diverter Pneumatics
        self.div1_extend = False
        self.div1_pos = 0.0               # 0.0 (retracted) to 0.15 (extended)
        self.div1_home = True
        self.div1_work = False
        self.div1_faulted = False
        
        self.div2_extend = False
        self.div2_pos = 0.0               # 0.0 to 0.15
        self.div2_home = True
        self.div2_work = False
        self.div2_faulted = False

        # Scanner
        self.last_barcode = ""
        self.scanner_trigger = False
        self.scanner_success = False

        # KPIs
        self.total_count = 0
        self.lane_a_count = 0
        self.lane_b_count = 0
        self.reject_count = 0
        self.total_jams = 0
        self.oee = 100.0

        # Simulation Runtime lists
        self.packages = []
        self.package_counter = 1
        self.spawn_timer = 0.0
        
        # Anomaly Injection Controls
        self.force_jam_pe2 = False
        self.force_div1_fault = False
        self.jammed_pkg_id = -1
        
        # Time tracking
        self.total_running_time = 0.0
        self.total_fault_time = 0.0
        self.last_time = time.time()

    def step(self, dt):
        """Advances the physics simulation by timestep dt (seconds)"""
        # Conveyor Speed Inertia Simulation (Tau = 0.4s)
        if self.conveyor_running and not self.conveyor_faulted:
            self.conveyor_speed_fb += (self.conveyor_speed_sp - self.conveyor_speed_fb) * (dt / 0.4)
            self.motor_current = (self.conveyor_speed_fb * 4.5) + (random.random() * 0.1 + 0.4)
        else:
            self.conveyor_speed_fb -= self.conveyor_speed_fb * (dt / 0.15) # Decelerates faster
            if self.conveyor_speed_fb < 0.01:
                self.conveyor_speed_fb = 0.0
            self.motor_current = 0.0

        # Update running times
        if self.current_state == 2:  # EXECUTE
            self.total_running_time += dt
        elif self.current_state in (4, 5, 8):  # HOLDING, HELD, ABORTED
            self.total_fault_time += dt

        # Spawn Packages (Only in AUTO Mode, EXECUTE State, and every 3.5 seconds)
        if self.current_state == 2 and not self.conveyor_faulted:
            self.spawn_timer += dt
            if self.spawn_timer >= 3.5:
                self.spawn_timer = 0.0
                self.spawn_package()

        # Update Diverter Pneumatics position dynamics
        # Diverter 1
        if self.force_div1_fault:
            # Mechanical jam simulation: cylinder stuck at 0.05m
            self.div1_pos = 0.05
            self.div1_home = False
            self.div1_work = False
        else:
            if self.div1_extend:
                self.div1_pos = min(0.15, self.div1_pos + (0.15 / 0.3) * dt)  # Takes 0.3s
            else:
                self.div1_pos = max(0.0, self.div1_pos - (0.15 / 0.3) * dt)
            self.div1_home = (self.div1_pos <= 0.01)
            self.div1_work = (self.div1_pos >= 0.14)

        # Diverter 2
        if self.div2_extend:
            self.div2_pos = min(0.15, self.div2_pos + (0.15 / 0.3) * dt)
        else:
            self.div2_pos = max(0.0, self.div2_pos - (0.15 / 0.3) * dt)
        self.div2_home = (self.div2_pos <= 0.01)
        self.div2_work = (self.div2_pos >= 0.14)

        # Update package position and state
        pe1_hit = False
        pe2_hit = False
        pe3_hit = False
        pe4_hit = False
        pe5_hit = False
        pe6_hit = False

        active_packages = []
        for pkg in self.packages:
            if pkg.diverted:
                # Package is currently off the main belt, traveling past exit sensor
                pkg.exit_timer += dt
                if pkg.route_target == 1:
                    pe4_hit = True
                elif pkg.route_target == 2:
                    pe5_hit = True
                elif pkg.route_target == 9:
                    pe6_hit = True

                # Clear package after exit confirmation duration
                if pkg.exit_timer >= 0.6:
                    self.total_count += 1
                    if pkg.route_target == 1:
                        self.lane_a_count += 1
                    elif pkg.route_target == 2:
                        self.lane_b_count += 1
                    elif pkg.route_target == 9:
                        self.reject_count += 1
                    logger.info(f"Package ID {pkg.id} EXITED cell. Target Lane: {pkg.route_target}")
                    continue  # Do not add back to active list
            else:
                # Advance package along the conveyor
                if self.force_jam_pe2 and pkg.id == self.jammed_pkg_id:
                    # Package is physically jammed at PE2 (1.2m)
                    pkg.position = self.PE2_POS
                    logger.warning(f"SIMULATOR: Injecting physical jam for Package {pkg.id} at PE2")
                else:
                    pkg.position += self.conveyor_speed_fb * dt

                # Scanner Trigger Check (When package enters SCANNER_POS)
                if pkg.position >= (self.SCANNER_POS - 0.05) and pkg.position <= (self.SCANNER_POS + 0.05):
                    if not self.scanner_trigger:
                        self.scanner_trigger = True
                        self.last_barcode = pkg.barcode
                        self.scanner_success = ("BAD-SCAN" not in pkg.barcode)
                        logger.info(f"SIMULATOR: Barcode Scan - Code: {pkg.barcode}, Target: {pkg.route_target}")

                # Diverter 1 Actuation check
                if pkg.position >= (self.DIV1_POS - 0.15) and pkg.position <= (self.DIV1_POS + 0.15):
                    if pkg.route_target == 1 and self.div1_work:
                        # Diverted successfully
                        pkg.diverted = True
                        pkg.exit_timer = 0.0
                        logger.info(f"SIMULATOR: Package ID {pkg.id} diverted to Lane A.")
                
                # Diverter 2 Actuation check
                if pkg.position >= (self.DIV2_POS - 0.15) and pkg.position <= (self.DIV2_POS + 0.15):
                    if pkg.route_target == 2 and self.div2_work:
                        # Diverted successfully
                        pkg.diverted = True
                        pkg.exit_timer = 0.0
                        logger.info(f"SIMULATOR: Package ID {pkg.id} diverted to Lane B.")

                # Reject area trigger (conveyor terminal end)
                if pkg.position >= self.PE6_POS:
                    pkg.diverted = True
                    pkg.exit_timer = 0.0
                    logger.info(f"SIMULATOR: Package ID {pkg.id} reached Reject Lane.")

                # Calculate sensor beams
                # PE1: Infeed (0.2m)
                if pkg.position <= self.PE1_POS <= (pkg.position + pkg.width):
                    pe1_hit = True
                # PE2: Scanner trigger (1.2m)
                if pkg.position <= self.PE2_POS <= (pkg.position + pkg.width):
                    pe2_hit = True
                # PE3: Diverter 1 Check (2.2m)
                if pkg.position <= self.PE3_POS <= (pkg.position + pkg.width):
                    pe3_hit = True

            active_packages.append(pkg)
        
        self.packages = active_packages
        self.pe1 = pe1_hit
        self.pe2 = pe2_hit
        self.pe3 = pe3_hit
        self.pe4 = pe4_hit
        self.pe5 = pe5_hit
        self.pe6 = pe6_hit

        # Turn off scanner trigger when scan zone is clear
        if not pe2_hit:
            self.scanner_trigger = False

        # Reset scanner success status
        if not pe2_hit and self.scanner_success:
            self.scanner_success = False

        # Recalculate OEE
        # Availability = Total running time / (Total running + Total fault time)
        total_sched = self.total_running_time + self.total_fault_time
        avail = (self.total_running_time / total_sched) if total_sched > 0 else 1.0
        perf = 0.96 # Fixed coefficient representing speed/pitch capacity
        qual = 1.0 - (self.reject_count / self.total_count) if self.total_count > 0 else 1.0
        self.oee = avail * perf * qual * 100.0

    def spawn_package(self):
        """Instantiates a new virtual package"""
        choices = [
            ("PKG-LANE-A-FDS", 1),
            ("PKG-LANE-A-DT", 1),
            ("PKG-LANE-B-ST", 2),
            ("PKG-LANE-B-OPC", 2),
            ("PKG-BAD-SCAN-999", 9)  # Bad code causing Reject route
        ]
        barcode, route = random.choice(choices)
        pkg = PackageSim(self.package_counter, barcode, route)
        self.packages.append(pkg)
        logger.info(f"SIMULATOR: Package ID {self.package_counter} spawned on belt.")
        self.package_counter += 1


# ==========================================
# OPC UA SERVER IMPLEMENTATION
# ==========================================

async def main():
    # Instantiate simulator
    cell = DigitalTwinCell()

    # Create server instance
    server = Server()
    await server.init()
    server.set_endpoint("opc.tcp://0.0.0.0:4840/freeopcua/server/")
    server.set_server_name("MHMC Material Handling Micro Cell Simulator")

    # Set up namespace
    uri = "http://antigravity.automation.org/MHMC/"
    idx = await server.register_namespace(uri)

    # 1. CREATE STRUCTS AND OBJECTS
    objects = server.nodes.objects
    mhmc_cell = await objects.add_folder(idx, "MHMC_Cell")
    device_set = await mhmc_cell.add_folder(idx, "DeviceSet")
    control_state = await mhmc_cell.add_folder(idx, "ControlState")
    kpi_set = await mhmc_cell.add_folder(idx, "KPIs")
    methods_set = await mhmc_cell.add_folder(idx, "Methods")

    # 2. POPULATE DEVICE NODES
    # Conveyor 1
    conv_obj = await device_set.add_object(idx, "Conveyor_1")
    node_conv_speed_sp = await conv_obj.add_variable(idx, "SpeedSetpoint", 0.5, ua.VariantType.Double)
    await node_conv_speed_sp.set_writable(True)
    node_conv_speed_fb = await conv_obj.add_variable(idx, "SpeedFeedback", 0.0, ua.VariantType.Double)
    node_conv_run = await conv_obj.add_variable(idx, "IsRunning", False, ua.VariantType.Boolean)
    node_pe1 = await conv_obj.add_variable(idx, "PE1_Blocked", False, ua.VariantType.Boolean)
    node_pe2 = await conv_obj.add_variable(idx, "PE2_Blocked", False, ua.VariantType.Boolean)
    node_pe3 = await conv_obj.add_variable(idx, "PE3_Blocked", False, ua.VariantType.Boolean)
    node_conv_current = await conv_obj.add_variable(idx, "VFD_Current", 0.0, ua.VariantType.Double)
    node_conv_faulted = await conv_obj.add_variable(idx, "Faulted", False, ua.VariantType.Boolean)

    # Diverter 1
    div1_obj = await device_set.add_object(idx, "Diverter_1")
    node_div1_home = await div1_obj.add_variable(idx, "Home", True, ua.VariantType.Boolean)
    node_div1_work = await div1_obj.add_variable(idx, "Work", False, ua.VariantType.Boolean)
    node_div1_cmd = await div1_obj.add_variable(idx, "CommandExtend", False, ua.VariantType.Boolean)
    await node_div1_cmd.set_writable(True)
    node_div1_pe = await div1_obj.add_variable(idx, "PE_Verify", False, ua.VariantType.Boolean)
    node_div1_faulted = await div1_obj.add_variable(idx, "Faulted", False, ua.VariantType.Boolean)

    # Diverter 2
    div2_obj = await device_set.add_object(idx, "Diverter_2")
    node_div2_home = await div2_obj.add_variable(idx, "Home", True, ua.VariantType.Boolean)
    node_div2_work = await div2_obj.add_variable(idx, "Work", False, ua.VariantType.Boolean)
    node_div2_cmd = await div2_obj.add_variable(idx, "CommandExtend", False, ua.VariantType.Boolean)
    await node_div2_cmd.set_writable(True)
    node_div2_pe = await div2_obj.add_variable(idx, "PE_Verify", False, ua.VariantType.Boolean)
    node_div2_faulted = await div2_obj.add_variable(idx, "Faulted", False, ua.VariantType.Boolean)

    # Scanner 1
    scan_obj = await device_set.add_object(idx, "Scanner_1")
    node_scan_barcode = await scan_obj.add_variable(idx, "LastReadBarcode", "", ua.VariantType.String)
    node_scan_trigger = await scan_obj.add_variable(idx, "Trigger", False, ua.VariantType.Boolean)
    await node_scan_trigger.set_writable(True)
    node_scan_success = await scan_obj.add_variable(idx, "ReadSuccess", False, ua.VariantType.Boolean)

    # 3. POPULATE CONTROLSTATE NODES
    node_mode = await control_state.add_variable(idx, "CurrentMode", 1, ua.VariantType.Int32) # 1=AUTO
    await node_mode.set_writable(True)
    node_state = await control_state.add_variable(idx, "CurrentState", 9, ua.VariantType.Int32) # 9=IDLE
    node_permissives = await control_state.add_variable(idx, "PermissivesOK", True, ua.VariantType.Boolean)
    node_heartbeat = await control_state.add_variable(idx, "Heartbeat", 0, ua.VariantType.UInt16)

    # 4. POPULATE KPI NODES
    node_kpi_total = await kpi_set.add_variable(idx, "ThroughputTotal", 0, ua.VariantType.UInt32)
    node_kpi_lane_a = await kpi_set.add_variable(idx, "ThroughputLaneA", 0, ua.VariantType.UInt32)
    node_kpi_lane_b = await kpi_set.add_variable(idx, "ThroughputLaneB", 0, ua.VariantType.UInt32)
    node_kpi_reject = await kpi_set.add_variable(idx, "ThroughputReject", 0, ua.VariantType.UInt32)
    node_kpi_jams = await kpi_set.add_variable(idx, "TotalJams", 0, ua.VariantType.UInt16)
    node_kpi_oee = await kpi_set.add_variable(idx, "OEE", 100.0, ua.VariantType.Double)

    # 5. DEFINE PROCESS METHODS
    @uamethod
    def start_cell(parent):
        logger.info("OPC UA METHOD CALL: StartCell executed.")
        if cell.current_state in (9, 0): # IDLE or STOPPED
            cell.current_state = 1 # STARTING
            cell.conveyor_running = True
            return True
        return False

    @uamethod
    def stop_cell(parent):
        logger.info("OPC UA METHOD CALL: StopCell executed.")
        cell.current_state = 7 # STOPPING
        return True

    @uamethod
    def reset_jam(parent):
        logger.info("OPC UA METHOD CALL: ResetJam executed.")
        if cell.conveyor_faulted:
            cell.conveyor_faulted = False
            cell.force_jam_pe2 = False
            cell.force_div1_fault = False
            cell.current_state = 6 # UNHOLDING
            return True
        return False

    # Register methods on OPC UA Namespace
    await methods_set.add_method(idx, "StartCell", start_cell, [], [ua.Argument(Name="Success", DataType=ua.NodeId(ua.ObjectIds.Boolean))])
    await methods_set.add_method(idx, "StopCell", stop_cell, [], [ua.Argument(Name="Success", DataType=ua.NodeId(ua.ObjectIds.Boolean))])
    await methods_set.add_method(idx, "ResetJam", reset_jam, [], [ua.Argument(Name="Success", DataType=ua.NodeId(ua.ObjectIds.Boolean))])

    logger.info("OPC UA Namespace successfully built.")
    
    # 6. RUN SERVER TIMESTEP LOOP
    await server.start()
    logger.info("OPC UA Server is running at: opc.tcp://0.0.0.0:4840/freeopcua/server/")
    
    # Start internal state complete auto transitions
    state_timer = 0.0
    hb_counter = 0

    try:
        # Loop interval settings
        dt = 0.05  # 50ms simulation ticks
        current_time = time.time()

        # Dynamic Scenario Scheduler for autonomous demo execution
        demo_elapsed = 0.0

        while True:
            # Advance simulation clock
            await asyncio.sleep(dt)
            demo_elapsed += dt
            
            # Read OPC UA writable registers
            cell.conveyor_speed_sp = await node_conv_speed_sp.get_value()
            cell.div1_extend = await node_div1_cmd.get_value()
            cell.div2_extend = await node_div2_cmd.get_value()
            cell.current_mode = await node_mode.get_value()

            # ----------------------------------------------------
            # AUTONOMOUS DEMO SCENARIO SCHEDULER
            # ----------------------------------------------------
            if demo_elapsed >= 0.0 and cell.current_state == 9: # IDLE
                # Automatically start line after 2s
                if demo_elapsed >= 2.0 and demo_elapsed < 3.0:
                    logger.info("DEMO ACTION: Automatically triggering cell Start command.")
                    cell.current_state = 1  # STARTING
                    cell.conveyor_running = True

            # Handle PackML auto transition timers
            if cell.current_state in (1, 6, 7): # STARTING, UNHOLDING, STOPPING
                state_timer += dt
                if state_timer >= 1.5:  # Take 1.5 seconds in starting/stopping phase
                    state_timer = 0.0
                    if cell.current_state == 1:
                        cell.current_state = 2  # -> EXECUTE
                        logger.info("STATE TRANSITION: Cell is now running (EXECUTE).")
                    elif cell.current_state == 6:
                        cell.current_state = 2  # -> EXECUTE
                        logger.info("STATE TRANSITION: Cell recovered (EXECUTE).")
                    elif cell.current_state == 7:
                        cell.current_state = 0  # -> STOPPED
                        cell.conveyor_running = False
                        logger.info("STATE TRANSITION: Cell stopped (STOPPED).")

            # Dynamic Alarm Watchdogs (Jam check)
            # If PE2 blocks for more than 2.0s, trigger Jam
            if cell.pe2 and cell.conveyor_running:
                # If we've forced a jam, or if it naturally gets blocked for too long
                # (Normally package moves past in <0.5s)
                if not hasattr(cell, 'pe2_block_timer'):
                    cell.pe2_block_timer = 0.0
                cell.pe2_block_timer += dt
                if cell.pe2_block_timer >= 2.0 and not cell.conveyor_faulted:
                    logger.error("WATCHDOG TRIGGERED: Package Jam detected at PE2 checkpoint!")
                    cell.conveyor_faulted = True
                    cell.current_state = 4  # -> HOLDING
                    cell.total_jams += 1
            else:
                cell.pe2_block_timer = 0.0

            # Handle Holding transition
            if cell.current_state == 4:
                state_timer += dt
                if state_timer >= 0.5:
                    state_timer = 0.0
                    cell.current_state = 5  # -> HELD
                    logger.info("STATE TRANSITION: System decelerated to safety stop (HELD).")

            # Inject package jam at 18 seconds
            if 18.0 <= demo_elapsed < 18.1 and not cell.conveyor_faulted:
                if len(cell.packages) > 0:
                    target_pkg = cell.packages[-1]
                    cell.force_jam_pe2 = True
                    cell.jammed_pkg_id = target_pkg.id
                    logger.warning(f"DEMO ACTION: Injecting artificial package jam on Package {target_pkg.id} at PE2!")

            # Automatically clear package jam after 8 seconds of HELD state
            if cell.current_state == 5 and cell.force_jam_pe2:
                if not hasattr(cell, 'jam_clear_hold'):
                    cell.jam_clear_hold = 0.0
                cell.jam_clear_hold += dt
                if cell.jam_clear_hold >= 6.0:
                    cell.jam_clear_hold = 0.0
                    logger.info("DEMO ACTION: Operator cleared jammed package. Triggering ResetJam method.")
                    cell.conveyor_faulted = False
                    cell.force_jam_pe2 = False
                    cell.current_state = 6 # UNHOLDING
                    state_timer = 0.0

            # Step Physics
            cell.step(dt)

            # Map divert commands in simulation based on package routing target:
            # (In a real physical system, the PLC controls this. Here we simulate PLC logic)
            if cell.current_state == 2 and not cell.conveyor_faulted:
                # Diverter 1 control logic
                div1_should_fire = False
                for p in cell.packages:
                    if p.route_target == 1 and (2.05 <= p.position <= 2.35):
                        div1_should_fire = True
                cell.div1_extend = div1_should_fire
                
                # Diverter 2 control logic
                div2_should_fire = False
                for p in cell.packages:
                    if p.route_target == 2 and (3.05 <= p.position <= 3.35):
                        div2_should_fire = True
                cell.div2_extend = div2_should_fire
            else:
                cell.div1_extend = False
                cell.div2_extend = False

            # Update OPC UA variables
            await node_conv_speed_fb.write_value(float(cell.conveyor_speed_fb))
            await node_conv_run.write_value(bool(cell.conveyor_running))
            await node_pe1.write_value(bool(cell.pe1))
            await node_pe2.write_value(bool(cell.pe2))
            await node_pe3.write_value(bool(cell.pe3))
            await node_conv_current.write_value(float(cell.motor_current))
            await node_conv_faulted.write_value(bool(cell.conveyor_faulted))

            await node_div1_home.write_value(bool(cell.div1_home))
            await node_div1_work.write_value(bool(cell.div1_work))
            await node_div1_cmd.write_value(bool(cell.div1_extend))
            await node_div1_pe.write_value(bool(cell.pe4))
            await node_div1_faulted.write_value(bool(cell.div1_faulted))

            await node_div2_home.write_value(bool(cell.div2_home))
            await node_div2_work.write_value(bool(cell.div2_work))
            await node_div2_cmd.write_value(bool(cell.div2_extend))
            await node_div2_pe.write_value(bool(cell.pe5))
            await node_div2_faulted.write_value(bool(cell.div2_faulted))

            await node_scan_barcode.write_value(str(cell.last_barcode))
            await node_scan_success.write_value(bool(cell.scanner_success))
            await node_scan_trigger.write_value(bool(cell.scanner_trigger))

            await node_state.write_value(ua.Variant(int(cell.current_state), ua.VariantType.Int32))
            await node_permissives.write_value(not cell.conveyor_faulted)

            hb_counter = (hb_counter + 1) % 10000
            await node_heartbeat.write_value(ua.Variant(int(hb_counter), ua.VariantType.UInt16))

            await node_kpi_total.write_value(ua.Variant(int(cell.total_count), ua.VariantType.UInt32))
            await node_kpi_lane_a.write_value(ua.Variant(int(cell.lane_a_count), ua.VariantType.UInt32))
            await node_kpi_lane_b.write_value(ua.Variant(int(cell.lane_b_count), ua.VariantType.UInt32))
            await node_kpi_reject.write_value(ua.Variant(int(cell.reject_count), ua.VariantType.UInt32))
            await node_kpi_jams.write_value(ua.Variant(int(cell.total_jams), ua.VariantType.UInt16))
            await node_kpi_oee.write_value(float(cell.oee))

    finally:
        await server.stop()
        logger.info("OPC UA Server stopped successfully.")

if __name__ == '__main__':
    asyncio.run(main())

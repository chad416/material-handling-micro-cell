PROGRAM Main
VAR
    // 1. HARDWARE / INTERFACE MAPPING VARIABLES
    xSafetyLoopOK       : BOOL := TRUE;  // Safety Relay Feed
    xAirPressureOK      : BOOL := TRUE;  // Digital Pressure Switch ($> 5.5 bar$)
    xRemoteStart        : BOOL := FALSE; // Start push button (HMI/OPC UA)
    xRemoteStop         : BOOL := FALSE; // Stop push button (HMI/OPC UA)
    xRemoteReset        : BOOL := FALSE; // Reset push button (HMI/OPC UA)
    xRemoteHold         : BOOL := FALSE; // Hold push button (HMI/OPC UA)
    xRemoteUnhold       : BOOL := FALSE; // Unhold push button (HMI/OPC UA)
    xRemoteClear        : BOOL := FALSE; // Clear push button (HMI/OPC UA)
    
    // Physical / Simulated Sensor Inputs
    xSensorPE1          : BOOL; // Conveyor Infeed PE
    xSensorPE2          : BOOL; // Conveyor Trigger PE
    xSensorPE3          : BOOL; // Conveyor Diverter 1 Checkpoint PE
    xSensorPE4          : BOOL; // Lane A Exit Confirm PE
    xSensorPE5          : BOOL; // Lane B Exit Confirm PE
    xSensorPE6          : BOOL; // Reject Lane Exit Confirm PE
    
    // 2. STATE MACHINE & CONTROL INSTANCES
    fbPackML            : FB_PackML_State;
    fbConveyor          : FB_ConveyorControl;
    fbRouting           : FB_RoutingLogic;
    
    // Operational Parameters
    eSelectedMode       : E_PackML_Mode := E_PackML_Mode.AUTO;
    rTargetConveyorSpeed: REAL := 0.5;   // Commanded velocity (m/s)
    xPermissivesOK      : BOOL := FALSE; // Logical sum of permissives
    uiHeartbeat         : UINT := 0;     // OPC UA watchdog cyclic counter
    uiJamEventCounter   : UINT := 0;     // Jam count metric
    xJamResetTrig       : BOOL := FALSE; // Edge detector
    xJamResetTrig_Last  : BOOL := FALSE;
    
    // Barcode scanner integration registers
    sScannerData        : STRING(80) := "";
    xScannerDataValid   : BOOL := FALSE;
    
    // OEE Metrics
    rAvailability       : REAL := 0.98;  // Assume 98% machine availability
    rPerformance        : REAL := 0.96;  // Assume 96% conveyor capacity performance
    rQuality            : REAL := 1.0;   // Calculated: Good / Total
    rOEEPercentage      : REAL := 0.0;
    
    // Internal state completion logic
    xStateCompleteTrigger : BOOL := FALSE;
    tonStateTransitTime   : TON;
END_VAR

// ==========================================
// PROGRAM LOGIC
// ==========================================

// 1. CALCULATE LINE PERMISSIVES
xPermissivesOK := xSafetyLoopOK 
                  AND xAirPressureOK 
                  AND fbConveyor.xReady 
                  AND NOT fbRouting.stDiverter1.xFaulted 
                  AND NOT fbRouting.stDiverter2.xFaulted;

// 2. PACKML STATE LOGIC AND COMMAND MAPPING
// Map critical process faults to state machine HOLDING state trigger
xRemoteHold := fbConveyor.stStatus.xFaulted 
               OR fbRouting.stDiverter1.xFaulted 
               OR fbRouting.stDiverter2.xFaulted;

// Map E-stop / Safety loop drop to ABORTED state trigger
IF NOT xSafetyLoopOK THEN
    fbPackML.xAbort := TRUE;
ELSE
    fbPackML.xAbort := FALSE;
END_IF;

// Run state machine transition execution
fbPackML(
    xStart := xRemoteStart,
    xStop := xRemoteStop,
    xReset := xRemoteReset,
    xHold := xRemoteHold,
    xUnhold := xRemoteUnhold,
    xClear := xRemoteClear,
    xStateComplete := xStateCompleteTrigger,
    eRequestedMode := eSelectedMode
);

// Auto-complete active transition states (Starting, Resetting, Stopping, Holding, Unholding)
// In a physical cell, this checks physical steps (e.g. pressure charge).
// For SIL simulation, we transition after a short time delay.
tonStateTransitTime(
    IN := fbPackML.xStateActive, 
    PT := T#1S
);
xStateCompleteTrigger := tonStateTransitTime.Q;

// 3. RUN CONVEYOR CONTROL
fbConveyor(
    xRunCmd := (fbPackML.eCurrentState = E_PackML_State.EXECUTE) 
               OR (fbPackML.eCurrentState = E_PackML_State.STARTING)
               OR (fbPackML.eCurrentState = E_PackML_State.STOPPING)
               OR (fbPackML.eCurrentState = E_PackML_State.UNHOLDING),
    rCmdSpeed := rTargetConveyorSpeed,
    xRawPE1 := xSensorPE1,
    xRawPE2 := xSensorPE2,
    xRawPE3 := xSensorPE3,
    xResetAlarms := xRemoteReset
);

// Track Jam Count
xJamResetTrig := fbConveyor.xJamAlarm;
IF xJamResetTrig AND NOT xJamResetTrig_Last THEN
    uiJamEventCounter := uiJamEventCounter + 1;
END_IF;
xJamResetTrig_Last := xJamResetTrig;

// 4. RUN AUTOMATIC ROUTING & FIFO QUEUE
fbRouting(
    xConveyorRunning := fbConveyor.stStatus.xIsRunning,
    rConveyorSpeed := fbConveyor.stStatus.rSpeedFeedback,
    sScannerString := sScannerData,
    xScannerReadSuccess := xScannerDataValid,
    xRawPE4 := xSensorPE4,
    xRawPE5 := xSensorPE5,
    xRawPE6 := xSensorPE6,
    xResetAlarms := xRemoteReset,
    xPE1 := xSensorPE1,
    xPE2 := xSensorPE2,
    xPE3 := xSensorPE3,
    tCycleTime := 0.05 // 50ms cycle
);

// 5. CALCULATE QUALITY AND OEE PERCENTAGE
IF fbRouting.udiTotalCount > 0 THEN
    // Quality is defined as (Good / Total).
    // Reject items are classified as defective sorting (due to bad code or logic).
    rQuality := 1.0 - (UDINT_TO_REAL(fbRouting.udiRejectCount) / UDINT_TO_REAL(fbRouting.udiTotalCount));
ELSE
    rQuality := 1.0;
END_IF;

rOEEPercentage := rAvailability * rPerformance * rQuality * 100.0;

// 6. CYCLIC WATCHDOG/HEARTBEAT FOR OPC UA
uiHeartbeat := uiHeartbeat + 1;
IF uiHeartbeat > 9999 THEN
    uiHeartbeat := 0;
END_IF;

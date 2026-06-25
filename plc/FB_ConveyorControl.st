FUNCTION_BLOCK FB_ConveyorControl
VAR_INPUT
    xRunCmd         : BOOL;         // VFD Start Command from State Machine
    rCmdSpeed       : REAL;         // Commanded VFD Speed (m/s)
    xRawPE1         : BOOL;         // Physical Infeed Sensor Input
    xRawPE2         : BOOL;         // Physical Trigger Sensor Input
    xRawPE3         : BOOL;         // Physical Diverter Checkpoint Input
    tJamLimit       : TIME := T#3S; // Configuration jam limit time
    xResetAlarms    : BOOL;         // Command to reset local alarms
END_VAR
VAR_OUTPUT
    stStatus        : ST_Conveyor_Status;
    xJamAlarm       : BOOL;         // General Jam alarm active
    xReady          : BOOL;         // Conveyor is healthy and ready to run
END_VAR
VAR
    tonPE1_Jam      : TON;          // Timer for PE1 jam verification
    tonPE2_Jam      : TON;          // Timer for PE2 jam verification
    tonPE3_Jam      : TON;          // Timer for PE3 jam verification
    rCurrentSpeed   : REAL := 0.0;  // Local speed tracking
    xFaultDrive     : BOOL := FALSE; // Local VFD fault flag
END_VAR

// 1. INPUT BINDINGS
stStatus.xPE1 := xRawPE1;
stStatus.xPE2 := xRawPE2;
stStatus.xPE3 := xRawPE3;

// 2. SPEED PROFILE / INERTIA SIMULATION (LAG FILTER)
// In a real PLC, we write to an analog out or fieldbus VFD register.
// Here we mimic VFD ramp behavior.
IF xRunCmd AND NOT xJamAlarm AND NOT xFaultDrive THEN
    rCurrentSpeed := rCurrentSpeed + (rCmdSpeed - rCurrentSpeed) * 0.1;
    stStatus.xIsRunning := TRUE;
ELSE
    rCurrentSpeed := rCurrentSpeed - (rCurrentSpeed * 0.2); // Faster stop ramp
    IF rCurrentSpeed < 0.01 THEN
        rCurrentSpeed := 0.0;
        stStatus.xIsRunning := FALSE;
    END_IF;
END_IF;

stStatus.rSpeedFeedback := rCurrentSpeed;
stStatus.rSpeedSetpoint := rCmdSpeed;

// Motor Current calculation (proportional to speed + loading factor)
IF stStatus.xIsRunning THEN
    stStatus.rCurrent := (rCurrentSpeed * 4.5) + 0.5; // Linear current estimate (Amps)
ELSE
    stStatus.rCurrent := 0.0;
END_IF;

// 3. WATCHDOG / JAM TIMERS
// Timers run if a PE is blocked while the conveyor is active and running.
tonPE1_Jam(IN := (xRawPE1 AND stStatus.xIsRunning), PT := tJamLimit);
tonPE2_Jam(IN := (xRawPE2 AND stStatus.xIsRunning), PT := tJamLimit);
tonPE3_Jam(IN := (xRawPE3 AND stStatus.xIsRunning), PT := tJamLimit);

// Trigger alarm if any PE is blocked beyond the limit
IF tonPE1_Jam.Q OR tonPE2_Jam.Q OR tonPE3_Jam.Q THEN
    xJamAlarm := TRUE;
END_IF;

// Reset local alarm flags upon command
IF xResetAlarms THEN
    xJamAlarm := FALSE;
    tonPE1_Jam(IN := FALSE);
    tonPE2_Jam(IN := FALSE);
    tonPE3_Jam(IN := FALSE);
END_IF;

// Conveyor Status outputs
stStatus.xFaulted := xJamAlarm OR xFaultDrive;
xReady := NOT stStatus.xFaulted;
END_FUNCTION_BLOCK

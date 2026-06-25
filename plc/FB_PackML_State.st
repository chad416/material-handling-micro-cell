FUNCTION_BLOCK FB_PackML_State
VAR_INPUT
    xStart          : BOOL; // Command Start
    xStop           : BOOL; // Command Stop
    xReset          : BOOL; // Command Reset (from Stopped to Idle)
    xHold           : BOOL; // Command Hold (Force stop conveyor on fault)
    xUnhold         : BOOL; // Command Unhold (Recover from Held)
    xAbort          : BOOL; // Command Abort (Emergency E-stop)
    xClear          : BOOL; // Command Clear (Recover from Aborted)
    xStateComplete  : BOOL; // State Execution Complete (Resetting/Starting/Stopping)
    eRequestedMode  : E_PackML_Mode; // Commanded Mode
END_VAR
VAR_OUTPUT
    eCurrentState   : E_PackML_State := E_PackML_State.STOPPED;
    eCurrentMode    : E_PackML_Mode  := E_PackML_Mode.AUTO;
    xStateActive    : BOOL; // Transition state active flag
END_VAR
VAR
    eNextState      : E_PackML_State := E_PackML_State.STOPPED;
END_VAR

// 1. GLOBAL ABORT CHECK
IF xAbort AND (eCurrentState <> E_PackML_State.ABORTED) THEN
    eCurrentState := E_PackML_State.ABORTED;
    RETURN;
END_IF

// 2. MODE MANAGEMENT (Only allow mode switch in Idle, Stopped, or Aborted)
IF (eCurrentState = E_PackML_State.IDLE) OR (eCurrentState = E_PackML_State.STOPPED) OR (eCurrentState = E_PackML_State.ABORTED) THEN
    eCurrentMode := eRequestedMode;
END_IF

// 3. PACKML STATE MACHINE TRANSITIONS
CASE eCurrentState OF

    E_PackML_State.STOPPED:
        xStateActive := FALSE;
        IF xReset THEN
            eCurrentState := E_PackML_State.RESETTING;
        END_IF;

    E_PackML_State.RESETTING:
        xStateActive := TRUE;
        // Logic for clearing errors occurs here. Transition once actions complete.
        IF xStateComplete THEN
            eCurrentState := E_PackML_State.IDLE;
        END_IF;
        IF xStop THEN
            eCurrentState := E_PackML_State.STOPPING;
        END_IF;

    E_PackML_State.IDLE:
        xStateActive := FALSE;
        IF xStart THEN
            eCurrentState := E_PackML_State.STARTING;
        END_IF;
        IF xStop THEN
            eCurrentState := E_PackML_State.STOPPING;
        END_IF;

    E_PackML_State.STARTING:
        xStateActive := TRUE;
        // Logic to spin up conveyors and verify systems.
        IF xStateComplete THEN
            eCurrentState := E_PackML_State.EXECUTE;
        END_IF;
        IF xStop THEN
            eCurrentState := E_PackML_State.STOPPING;
        END_IF;

    E_PackML_State.EXECUTE:
        xStateActive := FALSE;
        IF xStop THEN
            eCurrentState := E_PackML_State.STOPPING;
        END_IF;
        IF xHold THEN
            eCurrentState := E_PackML_State.HOLDING;
        END_IF;

    E_PackML_State.HOLDING:
        xStateActive := TRUE;
        // Conveyor deceleration and actuator safe-state logic.
        IF xStateComplete THEN
            eCurrentState := E_PackML_State.HELD;
        END_IF;

    E_PackML_State.HELD:
        xStateActive := FALSE;
        IF xUnhold THEN
            eCurrentState := E_PackML_State.UNHOLDING;
        END_IF;
        IF xStop THEN
            eCurrentState := E_PackML_State.STOPPING;
        END_IF;

    E_PackML_State.UNHOLDING:
        xStateActive := TRUE;
        // Restart sequence verification.
        IF xStateComplete THEN
            eCurrentState := E_PackML_State.EXECUTE;
        END_IF;
        IF xStop THEN
            eCurrentState := E_PackML_State.STOPPING;
        END_IF;

    E_PackML_State.SUSPENDED:
        xStateActive := FALSE;
        // Idle running (downstream block). Will auto-recover when input block clears.
        IF NOT xHold AND xStart THEN
            eCurrentState := E_PackML_State.EXECUTE;
        END_IF;
        IF xStop THEN
            eCurrentState := E_PackML_State.STOPPING;
        END_IF;

    E_PackML_State.STOPPING:
        xStateActive := TRUE;
        // Controlled spin down and queue saving.
        IF xStateComplete THEN
            eCurrentState := E_PackML_State.STOPPED;
        END_IF;

    E_PackML_State.ABORTED:
        xStateActive := FALSE;
        IF xClear THEN
            eCurrentState := E_PackML_State.STOPPED;
        END_IF;

END_CASE;
END_FUNCTION_BLOCK

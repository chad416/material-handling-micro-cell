// ==========================================
// STATION CONTROLLER MODULE FOR MHMC-01
// File: FB_StationController.st
// Standard: IEC 61131-3 Structured Text
// Purpose: PackML station control and symbolic PLCopen motion command adapter.
// ==========================================

TYPE E_StationControllerState :
(
    STATION_UNINITIALISED := 0,
    STATION_STOPPED       := 10,
    STATION_RESETTING     := 20,
    STATION_IDLE          := 30,
    STATION_STARTING      := 40,
    STATION_EXECUTE       := 50,
    STATION_SUSPENDED     := 60,
    STATION_HOLDING       := 70,
    STATION_HELD          := 80,
    STATION_UNHOLDING     := 90,
    STATION_STOPPING      := 100,
    STATION_ABORTED       := 900
) INT;
END_TYPE

TYPE ST_PLCopenMotionCommand :
STRUCT
    xPowerEnable       : BOOL; // Map to MC_Power.Enable in the axis adapter.
    xMoveVelocity      : BOOL; // Map to MC_MoveVelocity.Execute.
    xStop              : BOOL; // Map to MC_Stop.Execute.
    xReset             : BOOL; // Map to MC_Reset.Execute.
    rVelocity_mps      : REAL; // Symbolic velocity setpoint before drive scaling.
END_STRUCT
END_TYPE

TYPE ST_StationControllerConfig :
STRUCT
    rDefaultSpeed_mps       : REAL; // FDS recipe speed fallback.
    rMinimumSpeed_mps       : REAL; // Engineering lower bound.
    rMaximumSpeed_mps       : REAL; // Engineering upper bound.
    rTransitionTimeout_s    : REAL; // Generic transition watchdog for skeleton.
END_STRUCT
END_TYPE

TYPE ST_StationControllerInput :
STRUCT
    xStart             : BOOL;          // From LineSupervisor StartCell.
    xStop              : BOOL;          // From LineSupervisor StopCell.
    xReset             : BOOL;          // Reset faults/STOPPED to IDLE.
    xHold              : BOOL;          // Manual or diagnostic hold.
    xUnhold            : BOOL;          // Recover from HELD.
    xClear             : BOOL;          // Clear ABORTED to STOPPED.
    eRequestedMode     : E_PackML_Mode; // AUTO, MANUAL, MAINTENANCE.
    rTargetSpeed_mps   : REAL;          // Recipe command from supervisor.
    xSafetyLoopOK      : BOOL;          // Safety relay healthy.
    xAirPressureOK     : BOOL;          // Pneumatic pressure switch healthy.
    xVfdReady          : BOOL;          // Drive ready/no fault.
    xDiverter1Faulted  : BOOL;          // Diverter 1 diagnostic fault.
    xDiverter2Faulted  : BOOL;          // Diverter 2 diagnostic fault.
    xJamAlarm          : BOOL;          // Jam watchdog request to hold.
    xDownstreamBlocked : BOOL;          // Lane full or downstream unavailable.
    rCycleTime_s       : REAL;          // PLC task interval for unit tests.
END_STRUCT
END_TYPE

TYPE ST_StationControllerOutput :
STRUCT
    ePackMLState       : E_PackML_State;        // OPC UA ControlState.CurrentState.
    eCurrentMode       : E_PackML_Mode;         // OPC UA ControlState.CurrentMode.
    xPermissivesOK     : BOOL;                  // FDS start permissive expression.
    xRunRouting        : BOOL;                  // Enable package tracking/routing.
    xResetAlarms       : BOOL;                  // One-cycle alarm reset request.
    xConveyorRunEnable : BOOL;                  // Symbolic VFD run command.
    xConveyorQuickStop : BOOL;                  // Controlled quick stop request.
    rConveyorSpeed_mps : REAL;                  // Symbolic conveyor setpoint.
    stMotionCommand    : ST_PLCopenMotionCommand; // PLCopen command intent.
    sStatusText        : STRING(80);            // Diagnostic text.
END_STRUCT
END_TYPE

TYPE ST_StationControllerContext :
STRUCT
    eState              : E_StationControllerState;
    ePackMLState        : E_PackML_State;
    eCurrentMode        : E_PackML_Mode;
    xInitialized        : BOOL;
    xResetLast          : BOOL;
    rTransitionElapsed_s: REAL;
END_STRUCT
END_TYPE

FUNCTION F_StationController_Init : BOOL
VAR_INPUT
    stConfig : ST_StationControllerConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_StationControllerContext;
    stOut     : ST_StationControllerOutput;
END_VAR

// Initialisation function. Forces the mechanical safe state.
stContext.eState := E_StationControllerState.STATION_STOPPED;
stContext.ePackMLState := E_PackML_State.STOPPED;
stContext.eCurrentMode := E_PackML_Mode.AUTO;
stContext.xInitialized := TRUE;
stContext.xResetLast := FALSE;
stContext.rTransitionElapsed_s := 0.0;

stOut.ePackMLState := E_PackML_State.STOPPED;
stOut.eCurrentMode := E_PackML_Mode.AUTO;
stOut.xPermissivesOK := FALSE;
stOut.xRunRouting := FALSE;
stOut.xResetAlarms := FALSE;
stOut.xConveyorRunEnable := FALSE;
stOut.xConveyorQuickStop := TRUE;
stOut.rConveyorSpeed_mps := 0.0;
stOut.stMotionCommand.xPowerEnable := FALSE;
stOut.stMotionCommand.xMoveVelocity := FALSE;
stOut.stMotionCommand.xStop := TRUE;
stOut.stMotionCommand.xReset := FALSE;
stOut.stMotionCommand.rVelocity_mps := 0.0;
stOut.sStatusText := 'Station controller initialised';

F_StationController_Init := TRUE;
END_FUNCTION

FUNCTION F_StationController_Cyclic : BOOL
VAR_INPUT
    stIn     : ST_StationControllerInput;
    stConfig : ST_StationControllerConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_StationControllerContext;
    stOut     : ST_StationControllerOutput;
END_VAR
VAR
    xTransitionComplete : BOOL;
    rCommandSpeed_mps   : REAL;
END_VAR

// Cyclic execution function. Implements PackML sequencing with symbolic outputs.
IF stIn.rCycleTime_s > 0.0 THEN
    stContext.rTransitionElapsed_s := stContext.rTransitionElapsed_s + stIn.rCycleTime_s;
END_IF;

xTransitionComplete := stContext.rTransitionElapsed_s >= stConfig.rTransitionTimeout_s;
stOut.xResetAlarms := stIn.xReset AND NOT stContext.xResetLast;
stOut.xPermissivesOK := stIn.xSafetyLoopOK
                        AND stIn.xAirPressureOK
                        AND stIn.xVfdReady
                        AND NOT stIn.xDiverter1Faulted
                        AND NOT stIn.xDiverter2Faulted;

rCommandSpeed_mps := stIn.rTargetSpeed_mps;
IF rCommandSpeed_mps < stConfig.rMinimumSpeed_mps THEN
    rCommandSpeed_mps := stConfig.rDefaultSpeed_mps;
END_IF;
IF rCommandSpeed_mps > stConfig.rMaximumSpeed_mps THEN
    rCommandSpeed_mps := stConfig.rMaximumSpeed_mps;
END_IF;

IF NOT stContext.xInitialized THEN
    stContext.eState := E_StationControllerState.STATION_UNINITIALISED;
    stContext.ePackMLState := E_PackML_State.STOPPED;
ELSIF NOT stIn.xSafetyLoopOK THEN
    stContext.eState := E_StationControllerState.STATION_ABORTED;
    stContext.ePackMLState := E_PackML_State.ABORTED;
    stContext.rTransitionElapsed_s := 0.0;
ELSE
    CASE stContext.ePackMLState OF
        E_PackML_State.STOPPED:
            stContext.eState := E_StationControllerState.STATION_STOPPED;
            IF stIn.xReset THEN
                stContext.ePackMLState := E_PackML_State.RESETTING;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.RESETTING:
            stContext.eState := E_StationControllerState.STATION_RESETTING;
            IF xTransitionComplete THEN
                stContext.ePackMLState := E_PackML_State.IDLE;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.IDLE:
            stContext.eState := E_StationControllerState.STATION_IDLE;
            IF stIn.xStop THEN
                stContext.ePackMLState := E_PackML_State.STOPPING;
                stContext.rTransitionElapsed_s := 0.0;
            ELSIF stIn.xStart AND stOut.xPermissivesOK THEN
                stContext.ePackMLState := E_PackML_State.STARTING;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.STARTING:
            stContext.eState := E_StationControllerState.STATION_STARTING;
            IF stIn.xStop THEN
                stContext.ePackMLState := E_PackML_State.STOPPING;
                stContext.rTransitionElapsed_s := 0.0;
            ELSIF xTransitionComplete AND stOut.xPermissivesOK THEN
                stContext.ePackMLState := E_PackML_State.EXECUTE;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.EXECUTE:
            stContext.eState := E_StationControllerState.STATION_EXECUTE;
            IF stIn.xStop THEN
                stContext.ePackMLState := E_PackML_State.STOPPING;
                stContext.rTransitionElapsed_s := 0.0;
            ELSIF stIn.xJamAlarm OR stIn.xHold OR NOT stOut.xPermissivesOK THEN
                stContext.ePackMLState := E_PackML_State.HOLDING;
                stContext.rTransitionElapsed_s := 0.0;
            ELSIF stIn.xDownstreamBlocked THEN
                stContext.ePackMLState := E_PackML_State.SUSPENDED;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.SUSPENDED:
            stContext.eState := E_StationControllerState.STATION_SUSPENDED;
            IF stIn.xStop THEN
                stContext.ePackMLState := E_PackML_State.STOPPING;
                stContext.rTransitionElapsed_s := 0.0;
            ELSIF NOT stIn.xDownstreamBlocked THEN
                stContext.ePackMLState := E_PackML_State.EXECUTE;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.HOLDING:
            stContext.eState := E_StationControllerState.STATION_HOLDING;
            IF xTransitionComplete THEN
                stContext.ePackMLState := E_PackML_State.HELD;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.HELD:
            stContext.eState := E_StationControllerState.STATION_HELD;
            IF stIn.xStop THEN
                stContext.ePackMLState := E_PackML_State.STOPPING;
                stContext.rTransitionElapsed_s := 0.0;
            ELSIF stIn.xUnhold AND stOut.xPermissivesOK AND NOT stIn.xJamAlarm THEN
                stContext.ePackMLState := E_PackML_State.UNHOLDING;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.UNHOLDING:
            stContext.eState := E_StationControllerState.STATION_UNHOLDING;
            IF stIn.xStop THEN
                stContext.ePackMLState := E_PackML_State.STOPPING;
                stContext.rTransitionElapsed_s := 0.0;
            ELSIF xTransitionComplete THEN
                stContext.ePackMLState := E_PackML_State.EXECUTE;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.STOPPING:
            stContext.eState := E_StationControllerState.STATION_STOPPING;
            IF xTransitionComplete THEN
                stContext.ePackMLState := E_PackML_State.STOPPED;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;

        E_PackML_State.ABORTED:
            stContext.eState := E_StationControllerState.STATION_ABORTED;
            IF stIn.xClear THEN
                stContext.ePackMLState := E_PackML_State.STOPPED;
                stContext.rTransitionElapsed_s := 0.0;
            END_IF;
    END_CASE;
END_IF;

IF (stContext.ePackMLState = E_PackML_State.STOPPED)
   OR (stContext.ePackMLState = E_PackML_State.IDLE)
   OR (stContext.ePackMLState = E_PackML_State.ABORTED) THEN
    stContext.eCurrentMode := stIn.eRequestedMode;
END_IF;

stOut.ePackMLState := stContext.ePackMLState;
stOut.eCurrentMode := stContext.eCurrentMode;
stOut.xRunRouting := stContext.ePackMLState = E_PackML_State.EXECUTE;
stOut.xConveyorRunEnable := (stContext.ePackMLState = E_PackML_State.STARTING)
                            OR (stContext.ePackMLState = E_PackML_State.EXECUTE)
                            OR (stContext.ePackMLState = E_PackML_State.UNHOLDING);
stOut.xConveyorQuickStop := (stContext.ePackMLState = E_PackML_State.HOLDING)
                            OR (stContext.ePackMLState = E_PackML_State.HELD)
                            OR (stContext.ePackMLState = E_PackML_State.ABORTED)
                            OR (stContext.ePackMLState = E_PackML_State.STOPPING);

IF stOut.xConveyorRunEnable THEN
    stOut.rConveyorSpeed_mps := rCommandSpeed_mps;
ELSE
    stOut.rConveyorSpeed_mps := 0.0;
END_IF;

// PLCopen motion sequence intent; a target-specific adapter binds these to MC_* FBs.
stOut.stMotionCommand.xPowerEnable := stOut.xPermissivesOK AND (stContext.ePackMLState <> E_PackML_State.ABORTED);
stOut.stMotionCommand.xMoveVelocity := stOut.xConveyorRunEnable;
stOut.stMotionCommand.xStop := stOut.xConveyorQuickStop;
stOut.stMotionCommand.xReset := stOut.xResetAlarms;
stOut.stMotionCommand.rVelocity_mps := stOut.rConveyorSpeed_mps;
stOut.sStatusText := 'Station PackML sequence evaluated';

stContext.xResetLast := stIn.xReset;
F_StationController_Cyclic := stContext.xInitialized;
END_FUNCTION

FUNCTION_BLOCK FB_StationController
VAR_INPUT
    stIn     : ST_StationControllerInput;  // Typed symbolic inputs.
    stConfig : ST_StationControllerConfig; // Testable configuration.
    xInit    : BOOL;                       // Pulse to re-run initialisation.
END_VAR
VAR_OUTPUT
    stOut        : ST_StationControllerOutput; // Typed symbolic outputs.
    eState       : E_StationControllerState;   // Exposed module state.
    xInitialized : BOOL;                       // Module initialisation complete.
END_VAR
VAR
    stContext : ST_StationControllerContext;
    xInitLast : BOOL;
END_VAR

IF (NOT stContext.xInitialized) OR (xInit AND NOT xInitLast) THEN
    F_StationController_Init(stConfig := stConfig, stContext := stContext, stOut := stOut);
END_IF;

F_StationController_Cyclic(stIn := stIn, stConfig := stConfig, stContext := stContext, stOut := stOut);

eState := stContext.eState;
xInitialized := stContext.xInitialized;
xInitLast := xInit;
END_FUNCTION_BLOCK


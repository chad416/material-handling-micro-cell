// ==========================================
// DIVERTER CONTROLLER MODULE FOR MHMC-01
// File: FB_DiverterController.st
// Standard: IEC 61131-3 Structured Text
// Purpose: Pneumatic pusher sequencing for Diverter 1 and Diverter 2.
// ==========================================

TYPE E_DiverterControllerState :
(
    DIVERTER_UNINITIALISED := 0,
    DIVERTER_HOME          := 10,
    DIVERTER_EXTENDING     := 20,
    DIVERTER_WORK          := 30,
    DIVERTER_VERIFY        := 40,
    DIVERTER_RETRACTING    := 50,
    DIVERTER_FAULT         := 900
) INT;
END_TYPE

TYPE ST_DiverterControllerConfig :
STRUCT
    tActuatorName          : STRING(40); // Symbolic device name for diagnostics.
    rExtendTimeout_s       : REAL;       // Max time to reach work switch.
    rRetractTimeout_s      : REAL;       // Max time to return home.
    rWorkDwell_s           : REAL;       // Hold time after work switch.
    rVerificationTimeout_s : REAL;       // Max time to see lane PE confirmation.
END_STRUCT
END_TYPE

TYPE ST_DiverterControllerInput :
STRUCT
    xAutoEnable          : BOOL; // True when PackML EXECUTE permits automatic firing.
    xExtendRequest       : BOOL; // Routing sequence asks this diverter to fire.
    xManualExtend        : BOOL; // Maintenance/manual symbolic override.
    xHomeSensor          : BOOL; // LSx_Home magnetic switch.
    xWorkSensor          : BOOL; // LSx_Work magnetic switch.
    xVerificationSensor  : BOOL; // PE4 or PE5 lane confirmation.
    xResetFault          : BOOL; // Reset local actuator fault.
    rCycleTime_s         : REAL; // PLC task interval for test harness.
END_STRUCT
END_TYPE

TYPE ST_DiverterControllerOutput :
STRUCT
    xCommandExtend       : BOOL; // Symbolic solenoid command. Bind externally to field I/O.
    xBusy                : BOOL; // Actuator sequence active.
    xDone                : BOOL; // One-cycle sequence complete.
    xFaulted             : BOOL; // Travel or verification timeout.
    xHome                : BOOL; // Mirrored home switch.
    xWork                : BOOL; // Mirrored work switch.
    xVerified            : BOOL; // Lane verification latched for this cycle.
    uiFaultCode          : UINT; // 0 none, 1 extend, 2 retract, 3 verify.
    sStatusText          : STRING(80);
END_STRUCT
END_TYPE

TYPE ST_DiverterControllerContext :
STRUCT
    eState               : E_DiverterControllerState;
    xInitialized         : BOOL;
    xRequestLast         : BOOL;
    xDoneLatch           : BOOL;
    rStateElapsed_s      : REAL;
END_STRUCT
END_TYPE

FUNCTION F_DiverterController_Init : BOOL
VAR_INPUT
    stConfig : ST_DiverterControllerConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_DiverterControllerContext;
    stOut     : ST_DiverterControllerOutput;
END_VAR

// Initialisation function. De-energises the valve and clears local sequence memory.
stContext.eState := E_DiverterControllerState.DIVERTER_HOME;
stContext.xInitialized := TRUE;
stContext.xRequestLast := FALSE;
stContext.xDoneLatch := FALSE;
stContext.rStateElapsed_s := 0.0;

stOut.xCommandExtend := FALSE;
stOut.xBusy := FALSE;
stOut.xDone := FALSE;
stOut.xFaulted := FALSE;
stOut.xHome := FALSE;
stOut.xWork := FALSE;
stOut.xVerified := FALSE;
stOut.uiFaultCode := 0;
stOut.sStatusText := 'Diverter controller initialised';

F_DiverterController_Init := TRUE;
END_FUNCTION

FUNCTION F_DiverterController_Cyclic : BOOL
VAR_INPUT
    stIn     : ST_DiverterControllerInput;
    stConfig : ST_DiverterControllerConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_DiverterControllerContext;
    stOut     : ST_DiverterControllerOutput;
END_VAR
VAR
    xFireRequest : BOOL;
END_VAR

// Cyclic execution function. Sequence states are deterministic and unit-test friendly.
IF stIn.rCycleTime_s > 0.0 THEN
    stContext.rStateElapsed_s := stContext.rStateElapsed_s + stIn.rCycleTime_s;
END_IF;

stOut.xDone := FALSE;
stOut.xHome := stIn.xHomeSensor;
stOut.xWork := stIn.xWorkSensor;
xFireRequest := ((stIn.xAutoEnable AND stIn.xExtendRequest) OR stIn.xManualExtend);

IF stIn.xResetFault THEN
    stOut.xFaulted := FALSE;
    stOut.uiFaultCode := 0;
    stOut.xVerified := FALSE;
    stContext.eState := E_DiverterControllerState.DIVERTER_HOME;
    stContext.rStateElapsed_s := 0.0;
END_IF;

IF NOT stContext.xInitialized THEN
    stContext.eState := E_DiverterControllerState.DIVERTER_UNINITIALISED;
    stOut.xFaulted := TRUE;
    stOut.uiFaultCode := 99;
ELSIF stOut.xFaulted THEN
    stContext.eState := E_DiverterControllerState.DIVERTER_FAULT;
ELSIF xFireRequest AND NOT stContext.xRequestLast
      AND (stContext.eState = E_DiverterControllerState.DIVERTER_HOME) THEN
    stContext.eState := E_DiverterControllerState.DIVERTER_EXTENDING;
    stContext.rStateElapsed_s := 0.0;
    stOut.xVerified := FALSE;
ELSIF stContext.eState = E_DiverterControllerState.DIVERTER_EXTENDING THEN
    IF stIn.xWorkSensor THEN
        stContext.eState := E_DiverterControllerState.DIVERTER_WORK;
        stContext.rStateElapsed_s := 0.0;
    ELSIF stContext.rStateElapsed_s >= stConfig.rExtendTimeout_s THEN
        stOut.xFaulted := TRUE;
        stOut.uiFaultCode := 1;
    END_IF;
ELSIF stContext.eState = E_DiverterControllerState.DIVERTER_WORK THEN
    IF stContext.rStateElapsed_s >= stConfig.rWorkDwell_s THEN
        stContext.eState := E_DiverterControllerState.DIVERTER_VERIFY;
        stContext.rStateElapsed_s := 0.0;
    END_IF;
ELSIF stContext.eState = E_DiverterControllerState.DIVERTER_VERIFY THEN
    IF stIn.xVerificationSensor THEN
        stOut.xVerified := TRUE;
        stContext.eState := E_DiverterControllerState.DIVERTER_RETRACTING;
        stContext.rStateElapsed_s := 0.0;
    ELSIF stContext.rStateElapsed_s >= stConfig.rVerificationTimeout_s THEN
        stOut.xFaulted := TRUE;
        stOut.uiFaultCode := 3;
    END_IF;
ELSIF stContext.eState = E_DiverterControllerState.DIVERTER_RETRACTING THEN
    IF stIn.xHomeSensor THEN
        stContext.eState := E_DiverterControllerState.DIVERTER_HOME;
        stContext.rStateElapsed_s := 0.0;
        stOut.xDone := TRUE;
    ELSIF stContext.rStateElapsed_s >= stConfig.rRetractTimeout_s THEN
        stOut.xFaulted := TRUE;
        stOut.uiFaultCode := 2;
    END_IF;
ELSE
    stContext.eState := E_DiverterControllerState.DIVERTER_HOME;
END_IF;

stOut.xCommandExtend := (stContext.eState = E_DiverterControllerState.DIVERTER_EXTENDING)
                        OR (stContext.eState = E_DiverterControllerState.DIVERTER_WORK)
                        OR (stContext.eState = E_DiverterControllerState.DIVERTER_VERIFY);
stOut.xBusy := (stContext.eState = E_DiverterControllerState.DIVERTER_EXTENDING)
               OR (stContext.eState = E_DiverterControllerState.DIVERTER_WORK)
               OR (stContext.eState = E_DiverterControllerState.DIVERTER_VERIFY)
               OR (stContext.eState = E_DiverterControllerState.DIVERTER_RETRACTING);

IF stOut.xFaulted THEN
    stOut.xCommandExtend := FALSE;
    stOut.xBusy := FALSE;
    stOut.sStatusText := 'Diverter fault active';
ELSIF stOut.xBusy THEN
    stOut.sStatusText := 'Diverter sequence active';
ELSE
    stOut.sStatusText := 'Diverter ready at home';
END_IF;

stContext.xRequestLast := xFireRequest;
F_DiverterController_Cyclic := stContext.xInitialized;
END_FUNCTION

FUNCTION_BLOCK FB_DiverterController
VAR_INPUT
    stIn     : ST_DiverterControllerInput;  // Typed symbolic inputs.
    stConfig : ST_DiverterControllerConfig; // Testable timing configuration.
    xInit    : BOOL;                        // Pulse to re-run initialisation.
END_VAR
VAR_OUTPUT
    stOut        : ST_DiverterControllerOutput; // Typed symbolic outputs.
    eState       : E_DiverterControllerState;   // Exposed module state.
    xInitialized : BOOL;                        // Module initialisation complete.
END_VAR
VAR
    stContext : ST_DiverterControllerContext;
    xInitLast : BOOL;
END_VAR

IF (NOT stContext.xInitialized) OR (xInit AND NOT xInitLast) THEN
    F_DiverterController_Init(stConfig := stConfig, stContext := stContext, stOut := stOut);
END_IF;

F_DiverterController_Cyclic(stIn := stIn, stConfig := stConfig, stContext := stContext, stOut := stOut);

eState := stContext.eState;
xInitialized := stContext.xInitialized;
xInitLast := xInit;
END_FUNCTION_BLOCK


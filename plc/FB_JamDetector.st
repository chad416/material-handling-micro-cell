// ==========================================
// JAM DETECTOR MODULE FOR MHMC-01
// File: FB_JamDetector.st
// Standard: IEC 61131-3 Structured Text
// Purpose: Dynamic PE1/PE2/PE3 blockage watchdogs.
// ==========================================

TYPE E_JamDetectorState :
(
    JAM_DET_UNINITIALISED := 0,
    JAM_DET_CLEAR         := 10,
    JAM_DET_MONITORING    := 20,
    JAM_DET_WARNING       := 30,
    JAM_DET_WAIT_CLEAR    := 40,
    JAM_DET_RECOVERING    := 50,
    JAM_DET_JAMMED        := 900
) INT;
END_TYPE

TYPE ST_JamDetectorConfig :
STRUCT
    rReferenceSpeed_mps : REAL; // Speed used for nominal 3.0 s FDS limit.
    rBaseJamLimit_s     : REAL; // Nominal jam threshold at reference speed.
    rMaximumJamLimit_s  : REAL; // Slow-speed upper watchdog bound.
    rWarningRatio       : REAL; // Warning before full jam, e.g. 0.80.
END_STRUCT
END_TYPE

TYPE ST_JamDetectorInput :
STRUCT
    xRawPE1            : BOOL; // PE1 infeed blocked.
    xRawPE2            : BOOL; // PE2 scan trigger blocked.
    xRawPE3            : BOOL; // PE3 diverter in-range blocked.
    xConveyorRunning   : BOOL; // Conveyor feedback.
    rConveyorSpeed_mps : REAL; // Conveyor feedback speed.
    xResetJam          : BOOL; // ResetJam RPC/HMI command.
    xRecoveryRequest    : BOOL; // StationController is requesting jam recovery/unhold.
    xAllowAutoRecovery  : BOOL; // TRUE if PackML permissives allow unhold.
    ePackMLState        : E_PackML_State; // Station state for recovery rules.
    rCycleTime_s       : REAL; // PLC task interval for unit tests.
END_STRUCT
END_TYPE

TYPE ST_JamDetectorOutput :
STRUCT
    xJamAlarm          : BOOL; // Fault flag to StationController.
    xRequestHold       : BOOL; // One-shot/latched request to force PackML HOLDING.
    xWarning           : BOOL; // Pre-alarm for HMI and beacon logic.
    xSensorsClear      : BOOL; // All PE watchdog sensors are clear.
    xRecoveryReady     : BOOL; // Jam alarm is latched but field conditions allow reset.
    xInRecovery        : BOOL; // Jam recovery sequence is executing.
    xResetAcceptedPulse: BOOL; // One-cycle confirmation that ResetJam was accepted.
    xBeaconYellowFlash : BOOL; // Symbolic stack light request.
    uiJamSource        : UINT; // 0 none, 1 PE1, 2 PE2, 3 PE3.
    uiTotalJams        : UINT; // OPC UA KPI TotalJams node.
    rActiveLimit_s     : REAL; // Dynamic watchdog threshold in use.
    sStatusText        : STRING(80);
END_STRUCT
END_TYPE

TYPE ST_JamDetectorContext :
STRUCT
    eState          : E_JamDetectorState;
    xInitialized    : BOOL;
    xJamLatchedLast : BOOL;
    rPE1Blocked_s   : REAL;
    rPE2Blocked_s   : REAL;
    rPE3Blocked_s   : REAL;
END_STRUCT
END_TYPE

FUNCTION F_JamDetector_DynamicLimit_s : REAL
VAR_INPUT
    rConveyorSpeed_mps : REAL;
    stConfig           : ST_JamDetectorConfig;
END_VAR
VAR
    rLimit_s     : REAL;
    rBaseLimit_s : REAL;
    rMaxLimit_s  : REAL;
    rRefSpeed_mps: REAL;
END_VAR

// Dynamic limit increases as conveyor speed drops. It is clamped for slow jog cases.
rBaseLimit_s := stConfig.rBaseJamLimit_s;
IF rBaseLimit_s <= 0.0 THEN
    rBaseLimit_s := 3.0;
END_IF;
rMaxLimit_s := stConfig.rMaximumJamLimit_s;
IF rMaxLimit_s < rBaseLimit_s THEN
    rMaxLimit_s := rBaseLimit_s * 2.0;
END_IF;
rRefSpeed_mps := stConfig.rReferenceSpeed_mps;
IF rRefSpeed_mps <= 0.0 THEN
    rRefSpeed_mps := 0.5;
END_IF;

IF rConveyorSpeed_mps <= 0.01 THEN
    rLimit_s := rMaxLimit_s;
ELSE
    rLimit_s := rBaseLimit_s * rRefSpeed_mps / rConveyorSpeed_mps;
END_IF;

IF rLimit_s < rBaseLimit_s THEN
    rLimit_s := rBaseLimit_s;
END_IF;
IF rLimit_s > rMaxLimit_s THEN
    rLimit_s := rMaxLimit_s;
END_IF;

F_JamDetector_DynamicLimit_s := rLimit_s;
END_FUNCTION

FUNCTION F_JamDetector_Init : BOOL
VAR_INPUT
    stConfig : ST_JamDetectorConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_JamDetectorContext;
    stOut     : ST_JamDetectorOutput;
END_VAR

// Initialisation function. Clears watchdog accumulators and alarm outputs.
stContext.eState := E_JamDetectorState.JAM_DET_CLEAR;
stContext.xInitialized := TRUE;
stContext.xJamLatchedLast := FALSE;
stContext.rPE1Blocked_s := 0.0;
stContext.rPE2Blocked_s := 0.0;
stContext.rPE3Blocked_s := 0.0;

stOut.xJamAlarm := FALSE;
stOut.xRequestHold := FALSE;
stOut.xWarning := FALSE;
stOut.xSensorsClear := TRUE;
stOut.xRecoveryReady := FALSE;
stOut.xInRecovery := FALSE;
stOut.xResetAcceptedPulse := FALSE;
stOut.xBeaconYellowFlash := FALSE;
stOut.uiJamSource := 0;
stOut.uiTotalJams := 0;
stOut.rActiveLimit_s := stConfig.rBaseJamLimit_s;
stOut.sStatusText := 'Jam detector initialised';

F_JamDetector_Init := TRUE;
END_FUNCTION

FUNCTION F_JamDetector_Cyclic : BOOL
VAR_INPUT
    stIn     : ST_JamDetectorInput;
    stConfig : ST_JamDetectorConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_JamDetectorContext;
    stOut     : ST_JamDetectorOutput;
END_VAR
VAR
    rWarnLimit_s : REAL;
    rWarningRatio: REAL;
    xAnyBlocked  : BOOL;
    xResetAllowed: BOOL;
END_VAR

// Cyclic execution function. PE watchdogs are independent and symbolic.
stOut.rActiveLimit_s := F_JamDetector_DynamicLimit_s(rConveyorSpeed_mps := stIn.rConveyorSpeed_mps, stConfig := stConfig);
rWarningRatio := stConfig.rWarningRatio;
IF (rWarningRatio <= 0.0) OR (rWarningRatio >= 1.0) THEN
    rWarningRatio := 0.8;
END_IF;
rWarnLimit_s := stOut.rActiveLimit_s * rWarningRatio;
xAnyBlocked := stIn.xRawPE1 OR stIn.xRawPE2 OR stIn.xRawPE3;
stOut.xSensorsClear := NOT xAnyBlocked;
stOut.xResetAcceptedPulse := FALSE;
stOut.xRequestHold := stOut.xJamAlarm;
stOut.xInRecovery := FALSE;
stOut.xRecoveryReady := stOut.xJamAlarm AND stOut.xSensorsClear;
xResetAllowed := stIn.xResetJam
                 AND stOut.xSensorsClear
                 AND (stIn.xAllowAutoRecovery
                      OR stIn.xRecoveryRequest
                      OR (stIn.ePackMLState = E_PackML_State.HELD));

IF xResetAllowed THEN
    stOut.xJamAlarm := FALSE;
    stOut.xRequestHold := FALSE;
    stOut.xWarning := FALSE;
    stOut.xBeaconYellowFlash := FALSE;
    stOut.uiJamSource := 0;
    stContext.rPE1Blocked_s := 0.0;
    stContext.rPE2Blocked_s := 0.0;
    stContext.rPE3Blocked_s := 0.0;
    stContext.eState := E_JamDetectorState.JAM_DET_RECOVERING;
    stOut.xInRecovery := TRUE;
    stOut.xResetAcceptedPulse := TRUE;
END_IF;

IF NOT stIn.xRawPE1 THEN
    stContext.rPE1Blocked_s := 0.0;
ELSIF stIn.xConveyorRunning THEN
        stContext.rPE1Blocked_s := stContext.rPE1Blocked_s + stIn.rCycleTime_s;
END_IF;

IF NOT stIn.xRawPE2 THEN
    stContext.rPE2Blocked_s := 0.0;
ELSIF stIn.xConveyorRunning THEN
        stContext.rPE2Blocked_s := stContext.rPE2Blocked_s + stIn.rCycleTime_s;
END_IF;

IF NOT stIn.xRawPE3 THEN
    stContext.rPE3Blocked_s := 0.0;
ELSIF stIn.xConveyorRunning THEN
        stContext.rPE3Blocked_s := stContext.rPE3Blocked_s + stIn.rCycleTime_s;
END_IF;

IF NOT stContext.xInitialized THEN
    stContext.eState := E_JamDetectorState.JAM_DET_UNINITIALISED;
ELSIF (stContext.rPE1Blocked_s >= stOut.rActiveLimit_s)
      OR (stContext.rPE2Blocked_s >= stOut.rActiveLimit_s)
      OR (stContext.rPE3Blocked_s >= stOut.rActiveLimit_s) THEN
    stContext.eState := E_JamDetectorState.JAM_DET_JAMMED;
    stOut.xJamAlarm := TRUE;
    stOut.xRequestHold := TRUE;
    IF stContext.rPE1Blocked_s >= stOut.rActiveLimit_s THEN
        stOut.uiJamSource := 1;
    ELSIF stContext.rPE2Blocked_s >= stOut.rActiveLimit_s THEN
        stOut.uiJamSource := 2;
    ELSE
        stOut.uiJamSource := 3;
    END_IF;
ELSIF (stContext.rPE1Blocked_s >= rWarnLimit_s)
      OR (stContext.rPE2Blocked_s >= rWarnLimit_s)
      OR (stContext.rPE3Blocked_s >= rWarnLimit_s) THEN
    stContext.eState := E_JamDetectorState.JAM_DET_WARNING;
    stOut.xWarning := TRUE;
ELSIF stOut.xJamAlarm AND stOut.xSensorsClear THEN
    stContext.eState := E_JamDetectorState.JAM_DET_WAIT_CLEAR;
    stOut.xRecoveryReady := TRUE;
ELSE
    stOut.xWarning := FALSE;
    IF xAnyBlocked AND stIn.xConveyorRunning THEN
        stContext.eState := E_JamDetectorState.JAM_DET_MONITORING;
    ELSE
        stContext.eState := E_JamDetectorState.JAM_DET_CLEAR;
    END_IF;
END_IF;

IF stOut.xJamAlarm AND NOT stContext.xJamLatchedLast THEN
    stOut.uiTotalJams := stOut.uiTotalJams + 1;
END_IF;

stOut.xBeaconYellowFlash := stOut.xWarning OR stOut.xJamAlarm;
IF stOut.xJamAlarm THEN
    IF stOut.xRecoveryReady THEN
        stOut.sStatusText := 'Jam cleared physically; waiting for ResetJam';
    ELSE
        stOut.sStatusText := 'Package jam detected on main conveyor';
    END_IF;
ELSIF stOut.xResetAcceptedPulse THEN
    stOut.sStatusText := 'Jam reset accepted; recovery sequence may unhold';
ELSIF stOut.xWarning THEN
    stOut.sStatusText := 'Photoeye blocked near jam threshold';
ELSE
    stOut.sStatusText := 'Jam detector clear';
END_IF;

stContext.xJamLatchedLast := stOut.xJamAlarm;
F_JamDetector_Cyclic := stContext.xInitialized;
END_FUNCTION

FUNCTION_BLOCK FB_JamDetector
VAR_INPUT
    stIn     : ST_JamDetectorInput;  // Typed symbolic inputs.
    stConfig : ST_JamDetectorConfig; // Testable watchdog configuration.
    xInit    : BOOL;                 // Pulse to re-run initialisation.
END_VAR
VAR_OUTPUT
    stOut        : ST_JamDetectorOutput; // Typed symbolic outputs.
    eState       : E_JamDetectorState;   // Exposed module state.
    xInitialized : BOOL;                 // Module initialisation complete.
END_VAR
VAR
    stContext : ST_JamDetectorContext;
    xInitLast : BOOL;
END_VAR

IF (NOT stContext.xInitialized) OR (xInit AND NOT xInitLast) THEN
    F_JamDetector_Init(stConfig := stConfig, stContext := stContext, stOut := stOut);
END_IF;

F_JamDetector_Cyclic(stIn := stIn, stConfig := stConfig, stContext := stContext, stOut := stOut);

eState := stContext.eState;
xInitialized := stContext.xInitialized;
xInitLast := xInit;
END_FUNCTION_BLOCK

// ==========================================
// LINE SUPERVISOR MODULE FOR MHMC-01
// File: FB_LineSupervisor.st
// Standard: IEC 61131-3 Structured Text
// Purpose: Cell-level command, mode, and recipe dispatch skeleton.
// ==========================================

TYPE E_LineSupervisorState :
(
    LINE_SUP_UNINITIALISED := 0,
    LINE_SUP_READY         := 10,
    LINE_SUP_RECIPE_LOAD   := 20,
    LINE_SUP_COMMANDING    := 30,
    LINE_SUP_FAULTED       := 900
) INT;
END_TYPE

TYPE ST_LineSupervisorConfig :
STRUCT
    rDefaultTargetSpeed_mps : REAL;       // Recipe default conveyor speed.
    rMinimumTargetSpeed_mps : REAL;       // Lower recipe validation bound.
    rMaximumTargetSpeed_mps : REAL;       // Upper recipe validation bound.
    sLaneAPattern           : STRING(40); // Symbolic barcode rule for Lane A.
    sLaneBPattern           : STRING(40); // Symbolic barcode rule for Lane B.
    sRejectPattern          : STRING(40); // Symbolic barcode rule for reject/default.
END_STRUCT
END_TYPE

TYPE ST_LineSupervisorInput :
STRUCT
    xStartCommand      : BOOL;          // HMI/OPC UA StartCell request.
    xStopCommand       : BOOL;          // HMI/OPC UA StopCell request.
    xResetCommand      : BOOL;          // HMI/OPC UA reset request.
    xHoldCommand       : BOOL;          // HMI/SCADA hold request.
    xUnholdCommand     : BOOL;          // HMI/SCADA unhold request.
    xClearCommand      : BOOL;          // Clear aborted state request.
    xLoadRecipeCommand : BOOL;          // HMI/OPC UA LoadRecipe request.
    uiRecipeSelect     : UINT;          // Symbolic recipe selector.
    rRecipeSpeed_mps   : REAL;          // Recipe speed requested by supervisor.
    eModeSelect        : E_PackML_Mode; // Requested PackML operating mode.
    xOpcUaConnected    : BOOL;          // Supervisory channel healthy.
    xStationReady      : BOOL;          // Station can accept supervisor commands.
END_STRUCT
END_TYPE

TYPE ST_LineSupervisorOutput :
STRUCT
    xStartCellPulse     : BOOL;          // One-cycle StartCell command.
    xStopCellPulse      : BOOL;          // One-cycle StopCell command.
    xResetCellPulse     : BOOL;          // One-cycle reset command.
    xHoldCell           : BOOL;          // Level hold command.
    xUnholdCellPulse    : BOOL;          // One-cycle unhold command.
    xClearCellPulse     : BOOL;          // One-cycle clear command.
    xLoadRecipePulse    : BOOL;          // One-cycle recipe load command.
    eRequestedMode      : E_PackML_Mode; // Mode written to ControlState.CurrentMode.
    uiActiveRecipe      : UINT;          // Accepted recipe ID.
    rTargetSpeed_mps    : REAL;          // Recipe speed dispatched to station.
    sLaneAPattern       : STRING(40);    // Dispatch barcode rule for Lane A.
    sLaneBPattern       : STRING(40);    // Dispatch barcode rule for Lane B.
    sRejectPattern      : STRING(40);    // Dispatch barcode rule for Reject.
    xRecipeValid        : BOOL;          // Recipe parameters accepted.
    xSupervisorHealthy  : BOOL;          // True when command channel and recipe are valid.
    sStatusText         : STRING(80);    // Diagnostic text for HMI/OPC UA.
END_STRUCT
END_TYPE

TYPE ST_LineSupervisorContext :
STRUCT
    eState              : E_LineSupervisorState;
    xInitialized        : BOOL;
    xStartLast          : BOOL;
    xStopLast           : BOOL;
    xResetLast          : BOOL;
    xUnholdLast         : BOOL;
    xClearLast          : BOOL;
    xLoadRecipeLast     : BOOL;
END_STRUCT
END_TYPE

FUNCTION F_LineSupervisor_Init : BOOL
VAR_INPUT
    stConfig : ST_LineSupervisorConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_LineSupervisorContext;
    stOut     : ST_LineSupervisorOutput;
END_VAR

// Initialisation function. Unit tests can call this directly before exercising Cyclic.
stContext.eState := E_LineSupervisorState.LINE_SUP_READY;
stContext.xInitialized := TRUE;
stContext.xStartLast := FALSE;
stContext.xStopLast := FALSE;
stContext.xResetLast := FALSE;
stContext.xUnholdLast := FALSE;
stContext.xClearLast := FALSE;
stContext.xLoadRecipeLast := FALSE;

stOut.xStartCellPulse := FALSE;
stOut.xStopCellPulse := FALSE;
stOut.xResetCellPulse := FALSE;
stOut.xHoldCell := FALSE;
stOut.xUnholdCellPulse := FALSE;
stOut.xClearCellPulse := FALSE;
stOut.xLoadRecipePulse := FALSE;
stOut.eRequestedMode := E_PackML_Mode.AUTO;
stOut.uiActiveRecipe := 0;
stOut.rTargetSpeed_mps := stConfig.rDefaultTargetSpeed_mps;
stOut.sLaneAPattern := stConfig.sLaneAPattern;
stOut.sLaneBPattern := stConfig.sLaneBPattern;
stOut.sRejectPattern := stConfig.sRejectPattern;
stOut.xRecipeValid := TRUE;
stOut.xSupervisorHealthy := TRUE;
stOut.sStatusText := 'Line supervisor initialised';

F_LineSupervisor_Init := TRUE;
END_FUNCTION

FUNCTION F_LineSupervisor_Cyclic : BOOL
VAR_INPUT
    stIn     : ST_LineSupervisorInput;
    stConfig : ST_LineSupervisorConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_LineSupervisorContext;
    stOut     : ST_LineSupervisorOutput;
END_VAR
VAR
    xSpeedInsideLimits : BOOL;
END_VAR

// Cyclic execution function. All I/O is symbolic and supplied through typed structures.
stOut.xStartCellPulse := FALSE;
stOut.xStopCellPulse := FALSE;
stOut.xResetCellPulse := FALSE;
stOut.xUnholdCellPulse := FALSE;
stOut.xClearCellPulse := FALSE;
stOut.xLoadRecipePulse := FALSE;
stOut.xHoldCell := stIn.xHoldCommand;
stOut.eRequestedMode := stIn.eModeSelect;

xSpeedInsideLimits := (stIn.rRecipeSpeed_mps >= stConfig.rMinimumTargetSpeed_mps)
                      AND (stIn.rRecipeSpeed_mps <= stConfig.rMaximumTargetSpeed_mps);

IF NOT stContext.xInitialized THEN
    stContext.eState := E_LineSupervisorState.LINE_SUP_UNINITIALISED;
    stOut.xSupervisorHealthy := FALSE;
    stOut.sStatusText := 'Line supervisor not initialised';
ELSIF NOT stIn.xOpcUaConnected THEN
    stContext.eState := E_LineSupervisorState.LINE_SUP_FAULTED;
    stOut.xSupervisorHealthy := FALSE;
    stOut.sStatusText := 'OPC UA supervisory channel not healthy';
ELSIF stIn.xLoadRecipeCommand AND NOT stContext.xLoadRecipeLast THEN
    stContext.eState := E_LineSupervisorState.LINE_SUP_RECIPE_LOAD;
    stOut.xLoadRecipePulse := TRUE;
    stOut.xRecipeValid := xSpeedInsideLimits;
    IF xSpeedInsideLimits THEN
        stOut.uiActiveRecipe := stIn.uiRecipeSelect;
        stOut.rTargetSpeed_mps := stIn.rRecipeSpeed_mps;
        stOut.sLaneAPattern := stConfig.sLaneAPattern;
        stOut.sLaneBPattern := stConfig.sLaneBPattern;
        stOut.sRejectPattern := stConfig.sRejectPattern;
        stOut.xSupervisorHealthy := TRUE;
        stOut.sStatusText := 'Recipe accepted and dispatched';
    ELSE
        stContext.eState := E_LineSupervisorState.LINE_SUP_FAULTED;
        stOut.xSupervisorHealthy := FALSE;
        stOut.sStatusText := 'Recipe speed outside configured limits';
    END_IF;
ELSIF stIn.xStationReady THEN
    stContext.eState := E_LineSupervisorState.LINE_SUP_COMMANDING;
    stOut.xStartCellPulse := stIn.xStartCommand AND NOT stContext.xStartLast;
    stOut.xStopCellPulse := stIn.xStopCommand AND NOT stContext.xStopLast;
    stOut.xResetCellPulse := stIn.xResetCommand AND NOT stContext.xResetLast;
    stOut.xUnholdCellPulse := stIn.xUnholdCommand AND NOT stContext.xUnholdLast;
    stOut.xClearCellPulse := stIn.xClearCommand AND NOT stContext.xClearLast;
    stOut.xSupervisorHealthy := stOut.xRecipeValid;
    stOut.sStatusText := 'Supervisor command interface ready';
ELSE
    stContext.eState := E_LineSupervisorState.LINE_SUP_READY;
    stOut.xSupervisorHealthy := stOut.xRecipeValid;
    stOut.sStatusText := 'Waiting for station ready';
END_IF;

stContext.xStartLast := stIn.xStartCommand;
stContext.xStopLast := stIn.xStopCommand;
stContext.xResetLast := stIn.xResetCommand;
stContext.xUnholdLast := stIn.xUnholdCommand;
stContext.xClearLast := stIn.xClearCommand;
stContext.xLoadRecipeLast := stIn.xLoadRecipeCommand;

F_LineSupervisor_Cyclic := stContext.xInitialized;
END_FUNCTION

FUNCTION_BLOCK FB_LineSupervisor
VAR_INPUT
    stIn     : ST_LineSupervisorInput;  // Typed symbolic inputs.
    stConfig : ST_LineSupervisorConfig; // Testable configuration.
    xInit    : BOOL;                    // Pulse to re-run initialisation.
END_VAR
VAR_OUTPUT
    stOut        : ST_LineSupervisorOutput; // Typed symbolic outputs.
    eState       : E_LineSupervisorState;   // Exposed module state.
    xInitialized : BOOL;                    // Module initialisation complete.
END_VAR
VAR
    stContext : ST_LineSupervisorContext;
    xInitLast : BOOL;
END_VAR

// FB wrapper: call this POU every PLC task cycle, or call Init/Cyclic functions directly in tests.
IF (NOT stContext.xInitialized) OR (xInit AND NOT xInitLast) THEN
    F_LineSupervisor_Init(stConfig := stConfig, stContext := stContext, stOut := stOut);
END_IF;

F_LineSupervisor_Cyclic(stIn := stIn, stConfig := stConfig, stContext := stContext, stOut := stOut);

eState := stContext.eState;
xInitialized := stContext.xInitialized;
xInitLast := xInit;
END_FUNCTION_BLOCK


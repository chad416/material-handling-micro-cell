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
    uiRecipeCount           : UINT;       // Number of valid entries in arrRecipeBook.
    arrRecipeBook           : ARRAY[1..8] OF ST_SortRecipe; // Local recipe/config catalog.
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
    xUseRecipePayload   : BOOL;          // TRUE when stRecipePayload contains MES recipe data.
    stRecipePayload     : ST_SortRecipe; // Explicit recipe from HMI/MES.
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
    xRecipeLoadedPulse  : BOOL;          // One-cycle successful load notification.
    xRecipeRejectedPulse: BOOL;          // One-cycle rejected load notification.
    eRequestedMode      : E_PackML_Mode; // Mode written to ControlState.CurrentMode.
    uiActiveRecipe      : UINT;          // Accepted recipe ID.
    stActiveRecipe      : ST_SortRecipe; // Full recipe dispatched to station/routing.
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
    udiRecipeLoadCount  : UDINT;
END_STRUCT
END_TYPE

FUNCTION F_LineSupervisor_DefaultRecipe : ST_SortRecipe
VAR_INPUT
    stConfig : ST_LineSupervisorConfig;
END_VAR

// Build a valid fallback recipe from legacy scalar configuration fields.
F_LineSupervisor_DefaultRecipe.uiRecipeID := 1;
F_LineSupervisor_DefaultRecipe.xEnabled := TRUE;
F_LineSupervisor_DefaultRecipe.sName := 'Default Sort';
F_LineSupervisor_DefaultRecipe.rAutoSpeed_mps := stConfig.rDefaultTargetSpeed_mps;
F_LineSupervisor_DefaultRecipe.rManualMaxSpeed_mps := stConfig.rMaximumTargetSpeed_mps;
F_LineSupervisor_DefaultRecipe.rMaintenanceSpeedLimit_mps := stConfig.rMinimumTargetSpeed_mps;
F_LineSupervisor_DefaultRecipe.sLaneAPattern := stConfig.sLaneAPattern;
F_LineSupervisor_DefaultRecipe.sLaneBPattern := stConfig.sLaneBPattern;
F_LineSupervisor_DefaultRecipe.sRejectPattern := stConfig.sRejectPattern;
F_LineSupervisor_DefaultRecipe.rScannerWindowStart_m := 1.0;
F_LineSupervisor_DefaultRecipe.rScannerWindowEnd_m := 1.4;
F_LineSupervisor_DefaultRecipe.rDiverter1WindowStart_m := 2.05;
F_LineSupervisor_DefaultRecipe.rDiverter1WindowEnd_m := 2.35;
F_LineSupervisor_DefaultRecipe.rDiverter2WindowStart_m := 3.05;
F_LineSupervisor_DefaultRecipe.rDiverter2WindowEnd_m := 3.35;
F_LineSupervisor_DefaultRecipe.rRejectExitPosition_m := 4.2;
F_LineSupervisor_DefaultRecipe.rPackageTimeout_s := 12.0;
END_FUNCTION

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
stContext.udiRecipeLoadCount := 0;

stOut.xStartCellPulse := FALSE;
stOut.xStopCellPulse := FALSE;
stOut.xResetCellPulse := FALSE;
stOut.xHoldCell := FALSE;
stOut.xUnholdCellPulse := FALSE;
stOut.xClearCellPulse := FALSE;
stOut.xLoadRecipePulse := FALSE;
stOut.xRecipeLoadedPulse := FALSE;
stOut.xRecipeRejectedPulse := FALSE;
stOut.eRequestedMode := E_PackML_Mode.AUTO;
stOut.stActiveRecipe := F_LineSupervisor_DefaultRecipe(stConfig := stConfig);
stOut.uiActiveRecipe := stOut.stActiveRecipe.uiRecipeID;
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
    xRecipeFound       : BOOL;
    xRecipeAccepted    : BOOL;
    i                  : INT;
    stCandidate        : ST_SortRecipe;
    rMinimumSpeed_mps  : REAL;
    rMaximumSpeed_mps  : REAL;
END_VAR

// Cyclic execution function. All I/O is symbolic and supplied through typed structures.
stOut.xStartCellPulse := FALSE;
stOut.xStopCellPulse := FALSE;
stOut.xResetCellPulse := FALSE;
stOut.xUnholdCellPulse := FALSE;
stOut.xClearCellPulse := FALSE;
stOut.xLoadRecipePulse := FALSE;
stOut.xRecipeLoadedPulse := FALSE;
stOut.xRecipeRejectedPulse := FALSE;
stOut.xHoldCell := stIn.xHoldCommand;
stOut.eRequestedMode := stIn.eModeSelect;

stCandidate := F_LineSupervisor_DefaultRecipe(stConfig := stConfig);
xRecipeFound := FALSE;
xRecipeAccepted := FALSE;
rMinimumSpeed_mps := stConfig.rMinimumTargetSpeed_mps;
rMaximumSpeed_mps := stConfig.rMaximumTargetSpeed_mps;
IF rMinimumSpeed_mps <= 0.0 THEN
    rMinimumSpeed_mps := 0.05;
END_IF;
IF rMaximumSpeed_mps <= rMinimumSpeed_mps THEN
    rMaximumSpeed_mps := 1.5;
END_IF;

// Prefer an explicit MES/HMI payload when commanded; otherwise search the configured recipe book.
IF stIn.xUseRecipePayload THEN
    stCandidate := stIn.stRecipePayload;
    xRecipeFound := stCandidate.xEnabled;
ELSE
    FOR i := 1 TO 8 DO
        IF (UINT_TO_INT(stConfig.uiRecipeCount) >= i)
           AND stConfig.arrRecipeBook[i].xEnabled
           AND (stConfig.arrRecipeBook[i].uiRecipeID = stIn.uiRecipeSelect) THEN
            stCandidate := stConfig.arrRecipeBook[i];
            xRecipeFound := TRUE;
            EXIT;
        END_IF;
    END_FOR;
    IF (NOT xRecipeFound) AND (stConfig.uiRecipeCount = 0)
       AND ((stIn.uiRecipeSelect = 0) OR (stIn.uiRecipeSelect = 1)) THEN
        stCandidate := F_LineSupervisor_DefaultRecipe(stConfig := stConfig);
        xRecipeFound := TRUE;
    END_IF;
END_IF;

// A legacy speed value may trim the selected recipe, but never outside engineering limits.
IF stIn.rRecipeSpeed_mps > 0.0 THEN
    stCandidate.rAutoSpeed_mps := stIn.rRecipeSpeed_mps;
END_IF;
IF stCandidate.rAutoSpeed_mps <= 0.0 THEN
    stCandidate.rAutoSpeed_mps := 0.5;
END_IF;

xSpeedInsideLimits := (stCandidate.rAutoSpeed_mps >= rMinimumSpeed_mps)
                      AND (stCandidate.rAutoSpeed_mps <= rMaximumSpeed_mps);
xRecipeAccepted := xRecipeFound AND xSpeedInsideLimits;

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
    stOut.xRecipeValid := xRecipeAccepted;
    IF xRecipeAccepted THEN
        stOut.xRecipeLoadedPulse := TRUE;
        stContext.udiRecipeLoadCount := stContext.udiRecipeLoadCount + 1;
        stOut.uiActiveRecipe := stCandidate.uiRecipeID;
        stOut.stActiveRecipe := stCandidate;
        stOut.rTargetSpeed_mps := stCandidate.rAutoSpeed_mps;
        stOut.sLaneAPattern := stCandidate.sLaneAPattern;
        stOut.sLaneBPattern := stCandidate.sLaneBPattern;
        stOut.sRejectPattern := stCandidate.sRejectPattern;
        stOut.xSupervisorHealthy := TRUE;
        stOut.sStatusText := 'Recipe accepted and dispatched';
    ELSE
        stContext.eState := E_LineSupervisorState.LINE_SUP_FAULTED;
        stOut.xRecipeRejectedPulse := TRUE;
        stOut.xSupervisorHealthy := FALSE;
        IF NOT xRecipeFound THEN
            stOut.sStatusText := 'Recipe ID not found or disabled';
        ELSE
            stOut.sStatusText := 'Recipe speed outside configured limits';
        END_IF;
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

// ==========================================
// MICRO CELL TEST HARNESS FOR MHMC-01
// File: FB_TestHarness.st
// Standard: IEC 61131-3 Structured Text
// Purpose: Deterministic software-in-the-loop harness around the production modules.
// ==========================================

TYPE E_TestHarnessState :
(
    TH_UNINITIALISED := 0,
    TH_IDLE          := 10,
    TH_ARMING        := 20,
    TH_RUNNING       := 30,
    TH_EVALUATING    := 40,
    TH_COMPLETE      := 50,
    TH_FAILED        := 900
) INT;
END_TYPE

TYPE E_TestHarnessScenario :
(
    TH_NONE                    := 0,
    TH_NORMAL_LANE_A           := 10,
    TH_JAM_PE3                 := 20,
    TH_SENSOR_STUCK_HIGH_PE2   := 30,
    TH_SENSOR_STUCK_LOW_PE2    := 40,
    TH_START_PRODUCT_PRESENT   := 50,
    TH_BARCODE_MISREAD         := 60,
    TH_NETWORK_DROPOUT         := 70,
    TH_MANUAL_OVERRIDE_ABUSE   := 80,
    TH_RECIPE_CHANGE_MID_CYCLE := 90,
    TH_THROUGHPUT_DEGRADATION  := 100
) INT;
END_TYPE

TYPE E_TestHarnessVerdict :
(
    TH_VERDICT_NOT_RUN := 0,
    TH_VERDICT_RUNNING := 10,
    TH_VERDICT_PASS    := 20,
    TH_VERDICT_FAIL    := 30
) INT;
END_TYPE

TYPE ST_TestHarnessFaultInjection :
STRUCT
    xForceJamPE3              : BOOL; // Hold PE3 high long enough to trip the jam watchdog.
    xForcePE2StuckHigh        : BOOL; // Simulate scanner trigger sensor stuck high.
    xForcePE2StuckLow         : BOOL; // Simulate broken scanner trigger sensor.
    xStartWithProductPresent  : BOOL; // Product is already blocking PE1 before Start.
    xBarcodeMisread           : BOOL; // Scanner returns a bad/no-read barcode.
    xNetworkDropout           : BOOL; // OPC UA or historian collector unavailable.
    xManualOverrideAbuse      : BOOL; // Manual diverter/jog commands asserted while AUTO is active.
    xRecipeChangeMidCycle     : BOOL; // Recipe load requested while a package is active.
    xThroughputDegradation    : BOOL; // Conveyor is intentionally slowed.
END_STRUCT
END_TYPE

TYPE ST_TestHarnessInput :
STRUCT
    xEnable          : BOOL;                  // Enables the harness scan.
    xStartScenario   : BOOL;                  // Rising edge starts selected scenario.
    xRunAll          : BOOL;                  // Runs all defined scenarios in sequence.
    xReset           : BOOL;                  // Clears harness results and module state.
    eScenarioSelect  : E_TestHarnessScenario; // Scenario to execute when xRunAll is FALSE.
    rCycleTime_s     : REAL;                  // Task period used by the deterministic simulator.
END_STRUCT
END_TYPE

TYPE ST_TestHarnessConfig :
STRUCT
    rTaskCycle_s                 : REAL; // Default cycle time when input is zero.
    rScenarioTimeout_s           : REAL; // Hard timeout for each scenario.
    rPackageReleaseDelay_s       : REAL; // Delay after EXECUTE before injecting product.
    rNominalSpeed_mps            : REAL; // Normal recipe conveyor speed.
    rDegradedSpeed_mps           : REAL; // Throughput degradation recipe speed.
    rMinThroughput_ppm           : REAL; // Expected floor for nominal throughput.
    rJamHoldStart_s              : REAL; // Start of forced jam window.
    rJamHoldDuration_s           : REAL; // Duration of forced jam window.
    rNetworkDropStart_s          : REAL; // Start of historian/OPC UA dropout.
    rNetworkDropDuration_s       : REAL; // Duration of historian/OPC UA dropout.
    rManualAbuseStart_s          : REAL; // Start of manual override abuse window.
    rManualAbuseDuration_s       : REAL; // Duration of manual override abuse window.
    rRecipeChangeTime_s          : REAL; // Mid-cycle recipe load time.
END_STRUCT
END_TYPE

TYPE ST_TestHarnessScenarioResult :
STRUCT
    eScenario             : E_TestHarnessScenario;
    eVerdict              : E_TestHarnessVerdict;
    rStartTimestamp_s     : REAL;
    rEndTimestamp_s       : REAL;
    rDuration_s           : REAL;
    udiPackagesInjected   : UDINT;
    udiTotalPackages      : UDINT;
    udiLaneAPackages      : UDINT;
    udiLaneBPackages      : UDINT;
    udiRejectPackages     : UDINT;
    uiJamCount            : UINT;
    uiAlarmCode           : UINT;
    rThroughput_ppm       : REAL;
    rOEE_percent          : REAL;
    xHistorianPublished   : BOOL;
    xOPCUAReadyObserved   : BOOL;
    sExpected             : STRING(120);
    sActual               : STRING(120);
    sDeviation            : STRING(120);
END_STRUCT
END_TYPE

TYPE ST_TestHarnessOutput :
STRUCT
    eState                : E_TestHarnessState;       // Harness state for OPC UA/HMI.
    eActiveScenario       : E_TestHarnessScenario;    // Currently running scenario.
    eVerdict              : E_TestHarnessVerdict;     // Current or final verdict.
    rRuntime_s            : REAL;                     // Harness runtime.
    rScenarioElapsed_s    : REAL;                     // Elapsed time in active scenario.
    iActiveScenarioIndex  : INT;                      // 1..10 when running all scenarios.
    uiPassCount           : UINT;                     // Passed scenario count.
    uiFailCount           : UINT;                     // Failed scenario count.
    xScenarioActive       : BOOL;                     // TRUE while scenario is executing.
    xAllScenariosComplete : BOOL;                     // TRUE when run-all matrix is complete.
    xOPCUAServerReady     : BOOL;                     // Simulated namespace readiness.
    xHistorianHealthy     : BOOL;                     // Historian connector health mirror.
    xHistorianSample      : BOOL;                     // Historian sample strobe mirror.
    xConveyorRunning      : BOOL;                     // Simulated conveyor feedback.
    rConveyorSpeed_mps    : REAL;                     // Simulated conveyor speed feedback.
    uiTotalJams           : UINT;                     // Jam detector total for HMI/OPC UA.
    xPE1                 : BOOL;                      // Simulated infeed PE.
    xPE2                 : BOOL;                      // Simulated scanner PE.
    xPE3                 : BOOL;                      // Simulated diverter approach PE.
    xPE4                 : BOOL;                      // Simulated Lane A verification PE.
    xPE5                 : BOOL;                      // Simulated Lane B verification PE.
    xPE6                 : BOOL;                      // Simulated reject verification PE.
    sScannerData          : STRING(80);               // Simulated scanner payload.
    xScannerDataValid     : BOOL;                     // Simulated scanner good-read.
    stFaults              : ST_TestHarnessFaultInjection;
    stStationOut          : ST_StationControllerOutput;
    stRoutingStatus       : ST_RoutingStatus;
    stKPI                 : ST_KPIServiceOutput;
    stAlarm               : ST_AlarmManagerOutput;
    stHistorian           : ST_HistorianConnectorOutput;
    stHarnessTimeline     : ST_MHMCEventTimeline;     // Scenario events and outcomes.
    arrScenarioResults    : ARRAY[1..10] OF ST_TestHarnessScenarioResult;
    sStatusText           : STRING(120);
END_STRUCT
END_TYPE

TYPE ST_TestHarnessContext :
STRUCT
    eState              : E_TestHarnessState;
    xInitialized        : BOOL;
    xStartLast          : BOOL;
    xRunAllActive       : BOOL;
    xScenarioStarted    : BOOL;
    xScenarioEvaluated  : BOOL;
    xPackageActive      : BOOL;
    xPackageCreated     : BOOL;
    xJamResetIssued     : BOOL;
    xUnholdIssued       : BOOL;
    xHeartbeat          : BOOL;
    xNetworkDropSeen    : BOOL;
    xNetworkRecovered   : BOOL;
    xManualAbuseBlocked : BOOL;
    xRecipeChangeSeen   : BOOL;
    xHistorianPublished : BOOL;
    xOPCUAReadyObserved : BOOL;
    xInitialProductSeeded : BOOL;
    iScenarioIndex      : INT;
    udiPackagesInjected : UDINT;
    rRuntime_s          : REAL;
    rScenarioElapsed_s  : REAL;
    rPackagePosition_m  : REAL;
    rHeartbeatElapsed_s : REAL;
    rAutoCompleteHold_s : REAL;
    eActiveScenario     : E_TestHarnessScenario;
END_STRUCT
END_TYPE

FUNCTION F_TestHarness_ScenarioName : STRING(60)
VAR_INPUT
    eScenario : E_TestHarnessScenario;
END_VAR

CASE eScenario OF
    E_TestHarnessScenario.TH_NORMAL_LANE_A:
        F_TestHarness_ScenarioName := 'Normal Lane A';
    E_TestHarnessScenario.TH_JAM_PE3:
        F_TestHarness_ScenarioName := 'Jam PE3 and recovery';
    E_TestHarnessScenario.TH_SENSOR_STUCK_HIGH_PE2:
        F_TestHarness_ScenarioName := 'PE2 stuck high';
    E_TestHarnessScenario.TH_SENSOR_STUCK_LOW_PE2:
        F_TestHarness_ScenarioName := 'PE2 stuck low';
    E_TestHarnessScenario.TH_START_PRODUCT_PRESENT:
        F_TestHarness_ScenarioName := 'Start with product present';
    E_TestHarnessScenario.TH_BARCODE_MISREAD:
        F_TestHarness_ScenarioName := 'Barcode misread';
    E_TestHarnessScenario.TH_NETWORK_DROPOUT:
        F_TestHarness_ScenarioName := 'Network dropout';
    E_TestHarnessScenario.TH_MANUAL_OVERRIDE_ABUSE:
        F_TestHarness_ScenarioName := 'Manual override abuse';
    E_TestHarnessScenario.TH_RECIPE_CHANGE_MID_CYCLE:
        F_TestHarness_ScenarioName := 'Recipe change mid cycle';
    E_TestHarnessScenario.TH_THROUGHPUT_DEGRADATION:
        F_TestHarness_ScenarioName := 'Throughput degradation';
    ELSE
        F_TestHarness_ScenarioName := 'None';
END_CASE;
END_FUNCTION

FUNCTION F_TestHarness_ScenarioFromIndex : E_TestHarnessScenario
VAR_INPUT
    iIndex : INT;
END_VAR

CASE iIndex OF
    1: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_NORMAL_LANE_A;
    2: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_JAM_PE3;
    3: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_SENSOR_STUCK_HIGH_PE2;
    4: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_SENSOR_STUCK_LOW_PE2;
    5: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_START_PRODUCT_PRESENT;
    6: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_BARCODE_MISREAD;
    7: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_NETWORK_DROPOUT;
    8: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_MANUAL_OVERRIDE_ABUSE;
    9: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_RECIPE_CHANGE_MID_CYCLE;
    10: F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_THROUGHPUT_DEGRADATION;
    ELSE F_TestHarness_ScenarioFromIndex := E_TestHarnessScenario.TH_NONE;
END_CASE;
END_FUNCTION

FUNCTION_BLOCK FB_TestHarness
VAR_INPUT
    stIn     : ST_TestHarnessInput;   // Typed harness control inputs.
    stConfig : ST_TestHarnessConfig;  // Deterministic scenario timing configuration.
    xInit    : BOOL;                  // Pulse to re-run harness initialisation.
END_VAR
VAR_OUTPUT
    stOut        : ST_TestHarnessOutput; // Typed outputs for OPC UA, HMI, historian, and tests.
    eState       : E_TestHarnessState;   // Exposed harness state.
    xInitialized : BOOL;                 // TRUE after initialisation.
END_VAR
VAR
    fbLineSupervisor     : FB_LineSupervisor;
    fbStationController  : FB_StationController;
    fbConveyor           : FB_ConveyorControl;
    fbRouting            : FB_RoutingLogic;
    fbDiverter1          : FB_DiverterController;
    fbDiverter2          : FB_DiverterController;
    fbJamDetector        : FB_JamDetector;
    fbKPIService         : FB_KPIService;
    fbAlarmManager       : FB_AlarmManager;
    fbHistorianConnector : FB_HistorianConnector;

    stLineIn             : ST_LineSupervisorInput;
    stLineConfig         : ST_LineSupervisorConfig;
    stStationIn          : ST_StationControllerInput;
    stStationConfig      : ST_StationControllerConfig;
    stManual             : ST_ManualControl;
    stJamIn              : ST_JamDetectorInput;
    stJamConfig          : ST_JamDetectorConfig;
    stKPIIn              : ST_KPIServiceInput;
    stKPIConfig          : ST_KPIServiceConfig;
    stAlarmIn            : ST_AlarmManagerInput;
    stAlarmConfig        : ST_AlarmManagerConfig;
    stHistorianIn        : ST_HistorianConnectorInput;
    stHistorianConfig    : ST_HistorianConnectorConfig;
    stDiverter1In        : ST_DiverterControllerInput;
    stDiverter2In        : ST_DiverterControllerInput;
    stDiverter1Config    : ST_DiverterControllerConfig;
    stDiverter2Config    : ST_DiverterControllerConfig;
    stDiverter1Status    : ST_Diverter_Status;
    stDiverter2Status    : ST_Diverter_Status;
    stTimelineForHistorian : ST_MHMCEventTimeline;

    stContext            : ST_TestHarnessContext;
    xInitLast            : BOOL;
    xStartEdge           : BOOL;
    xInitModules         : BOOL;
    xScenarioDone        : BOOL;
    xScenarioPass        : BOOL;
    xNetworkAvailable    : BOOL;
    xResetPulse          : BOOL;
    xStartPulse          : BOOL;
    xStopPulse           : BOOL;
    xUnholdPulse         : BOOL;
    xClearPulse          : BOOL;
    xLoadRecipePulse     : BOOL;
    xManualResetJam      : BOOL;
    xAlarmAck            : BOOL;
    xRawPE1              : BOOL;
    xRawPE2              : BOOL;
    xRawPE3              : BOOL;
    xRawPE4              : BOOL;
    xRawPE5              : BOOL;
    xRawPE6              : BOOL;
    xDiv1Home            : BOOL;
    xDiv1Work            : BOOL;
    xDiv2Home            : BOOL;
    xDiv2Work            : BOOL;
    rCycleTime_s         : REAL;
    rScenarioTimeout_s   : REAL;
    rPackageDelay_s      : REAL;
    rNominalSpeed_mps    : REAL;
    rDegradedSpeed_mps   : REAL;
    rJamStart_s          : REAL;
    rJamDuration_s       : REAL;
    rNetworkStart_s      : REAL;
    rNetworkDuration_s   : REAL;
    rManualAbuseStart_s  : REAL;
    rManualAbuseDuration_s : REAL;
    rRecipeChange_s      : REAL;
    rPositionStep_m      : REAL;
    rCommandedSpeed_mps  : REAL;
    i                    : INT;
END_VAR

// =========================================================
// 1. CONFIGURATION NORMALISATION AND INITIALISATION
// =========================================================
rCycleTime_s := stIn.rCycleTime_s;
IF rCycleTime_s <= 0.0 THEN
    rCycleTime_s := stConfig.rTaskCycle_s;
END_IF;
IF rCycleTime_s <= 0.0 THEN
    rCycleTime_s := 0.05;
END_IF;

rScenarioTimeout_s := stConfig.rScenarioTimeout_s;
IF rScenarioTimeout_s <= 0.0 THEN
    rScenarioTimeout_s := 18.0;
END_IF;
rPackageDelay_s := stConfig.rPackageReleaseDelay_s;
IF rPackageDelay_s <= 0.0 THEN
    rPackageDelay_s := 3.0;
END_IF;
rNominalSpeed_mps := stConfig.rNominalSpeed_mps;
IF rNominalSpeed_mps <= 0.0 THEN
    rNominalSpeed_mps := 0.50;
END_IF;
rDegradedSpeed_mps := stConfig.rDegradedSpeed_mps;
IF rDegradedSpeed_mps <= 0.0 THEN
    rDegradedSpeed_mps := 0.18;
END_IF;
rJamStart_s := stConfig.rJamHoldStart_s;
IF rJamStart_s <= 0.0 THEN
    rJamStart_s := 4.5;
END_IF;
rJamDuration_s := stConfig.rJamHoldDuration_s;
IF rJamDuration_s <= 0.0 THEN
    rJamDuration_s := 4.0;
END_IF;
rNetworkStart_s := stConfig.rNetworkDropStart_s;
IF rNetworkStart_s <= 0.0 THEN
    rNetworkStart_s := 4.0;
END_IF;
rNetworkDuration_s := stConfig.rNetworkDropDuration_s;
IF rNetworkDuration_s <= 0.0 THEN
    rNetworkDuration_s := 7.0;
END_IF;
rManualAbuseStart_s := stConfig.rManualAbuseStart_s;
IF rManualAbuseStart_s <= 0.0 THEN
    rManualAbuseStart_s := 3.2;
END_IF;
rManualAbuseDuration_s := stConfig.rManualAbuseDuration_s;
IF rManualAbuseDuration_s <= 0.0 THEN
    rManualAbuseDuration_s := 2.0;
END_IF;
rRecipeChange_s := stConfig.rRecipeChangeTime_s;
IF rRecipeChange_s <= 0.0 THEN
    rRecipeChange_s := 4.0;
END_IF;

IF (NOT stContext.xInitialized) OR (xInit AND NOT xInitLast) OR stIn.xReset THEN
    stContext.eState := E_TestHarnessState.TH_IDLE;
    stContext.xInitialized := TRUE;
    stContext.xStartLast := FALSE;
    stContext.xRunAllActive := FALSE;
    stContext.xScenarioStarted := FALSE;
    stContext.xScenarioEvaluated := FALSE;
    stContext.xPackageActive := FALSE;
    stContext.xPackageCreated := FALSE;
    stContext.xJamResetIssued := FALSE;
    stContext.xUnholdIssued := FALSE;
    stContext.xHeartbeat := FALSE;
    stContext.xNetworkDropSeen := FALSE;
    stContext.xNetworkRecovered := FALSE;
    stContext.xManualAbuseBlocked := FALSE;
    stContext.xRecipeChangeSeen := FALSE;
    stContext.xHistorianPublished := FALSE;
    stContext.xOPCUAReadyObserved := FALSE;
    stContext.xInitialProductSeeded := FALSE;
    stContext.iScenarioIndex := 0;
    stContext.udiPackagesInjected := 0;
    stContext.rRuntime_s := 0.0;
    stContext.rScenarioElapsed_s := 0.0;
    stContext.rPackagePosition_m := 0.0;
    stContext.rHeartbeatElapsed_s := 0.0;
    stContext.rAutoCompleteHold_s := 0.0;
    stContext.eActiveScenario := E_TestHarnessScenario.TH_NONE;

    stOut.eState := E_TestHarnessState.TH_IDLE;
    stOut.eActiveScenario := E_TestHarnessScenario.TH_NONE;
    stOut.eVerdict := E_TestHarnessVerdict.TH_VERDICT_NOT_RUN;
    stOut.uiPassCount := 0;
    stOut.uiFailCount := 0;
    stOut.xScenarioActive := FALSE;
    stOut.xAllScenariosComplete := FALSE;
    stOut.sStatusText := 'Test harness initialised';
    F_EventTimeline_Clear(stTimeline := stOut.stHarnessTimeline);

    FOR i := 1 TO 10 DO
        stOut.arrScenarioResults[i].eScenario := F_TestHarness_ScenarioFromIndex(iIndex := i);
        stOut.arrScenarioResults[i].eVerdict := E_TestHarnessVerdict.TH_VERDICT_NOT_RUN;
        stOut.arrScenarioResults[i].rStartTimestamp_s := 0.0;
        stOut.arrScenarioResults[i].rEndTimestamp_s := 0.0;
        stOut.arrScenarioResults[i].rDuration_s := 0.0;
        stOut.arrScenarioResults[i].udiPackagesInjected := 0;
        stOut.arrScenarioResults[i].udiTotalPackages := 0;
        stOut.arrScenarioResults[i].udiLaneAPackages := 0;
        stOut.arrScenarioResults[i].udiLaneBPackages := 0;
        stOut.arrScenarioResults[i].udiRejectPackages := 0;
        stOut.arrScenarioResults[i].uiJamCount := 0;
        stOut.arrScenarioResults[i].uiAlarmCode := 0;
        stOut.arrScenarioResults[i].rThroughput_ppm := 0.0;
        stOut.arrScenarioResults[i].rOEE_percent := 0.0;
        stOut.arrScenarioResults[i].xHistorianPublished := FALSE;
        stOut.arrScenarioResults[i].xOPCUAReadyObserved := FALSE;
        stOut.arrScenarioResults[i].sExpected := '';
        stOut.arrScenarioResults[i].sActual := '';
        stOut.arrScenarioResults[i].sDeviation := '';
    END_FOR;
END_IF;

IF stIn.xEnable THEN
    stContext.rRuntime_s := stContext.rRuntime_s + rCycleTime_s;
END_IF;
stOut.stHarnessTimeline.xNewEvent := FALSE;

// =========================================================
// 2. START AND SCENARIO SELECTION
// =========================================================
xStartEdge := stIn.xStartScenario AND NOT stContext.xStartLast;
IF stContext.xInitialized AND stIn.xEnable AND xStartEdge THEN
    stContext.xRunAllActive := stIn.xRunAll;
    IF stIn.xRunAll THEN
        stContext.iScenarioIndex := 1;
        stContext.eActiveScenario := F_TestHarness_ScenarioFromIndex(iIndex := 1);
    ELSE
        stContext.iScenarioIndex := 1;
        stContext.eActiveScenario := stIn.eScenarioSelect;
        IF stContext.eActiveScenario = E_TestHarnessScenario.TH_NONE THEN
            stContext.eActiveScenario := E_TestHarnessScenario.TH_NORMAL_LANE_A;
        END_IF;
    END_IF;
    stContext.eState := E_TestHarnessState.TH_ARMING;
    stContext.xScenarioStarted := FALSE;
    stContext.xScenarioEvaluated := FALSE;
    stOut.xAllScenariosComplete := FALSE;
END_IF;

IF (stContext.eState = E_TestHarnessState.TH_ARMING) AND NOT stContext.xScenarioStarted THEN
    stContext.xScenarioStarted := TRUE;
    stContext.xScenarioEvaluated := FALSE;
    stContext.xPackageActive := FALSE;
    stContext.xPackageCreated := FALSE;
    stContext.xJamResetIssued := FALSE;
    stContext.xUnholdIssued := FALSE;
    stContext.xHeartbeat := FALSE;
    stContext.xNetworkDropSeen := FALSE;
    stContext.xNetworkRecovered := FALSE;
    stContext.xManualAbuseBlocked := FALSE;
    stContext.xRecipeChangeSeen := FALSE;
    stContext.xHistorianPublished := FALSE;
    stContext.xOPCUAReadyObserved := FALSE;
    stContext.xInitialProductSeeded := FALSE;
    stContext.udiPackagesInjected := 0;
    stContext.rScenarioElapsed_s := 0.0;
    stContext.rPackagePosition_m := 0.0;
    stContext.rHeartbeatElapsed_s := 0.0;
    stContext.rAutoCompleteHold_s := 0.0;
    stOut.eVerdict := E_TestHarnessVerdict.TH_VERDICT_RUNNING;
    stOut.xScenarioActive := TRUE;
    xInitModules := TRUE;
    F_EventTimeline_Append(
        rTimestamp_s := stContext.rRuntime_s,
        eClass := E_MHMCEventClass.EVENT_COMMAND,
        uiCode := 100,
        uiSeverity := 0,
        ePackMLState := E_PackML_State.STOPPED,
        eMode := E_PackML_Mode.AUTO,
        udiPackageID := 0,
        eRouteTarget := E_RouteTarget.ROUTE_NONE,
        sMessage := F_TestHarness_ScenarioName(eScenario := stContext.eActiveScenario),
        stTimeline := stOut.stHarnessTimeline
    );
    stContext.eState := E_TestHarnessState.TH_RUNNING;
ELSE
    xInitModules := FALSE;
END_IF;

IF stContext.eState = E_TestHarnessState.TH_RUNNING THEN
    stContext.rScenarioElapsed_s := stContext.rScenarioElapsed_s + rCycleTime_s;
END_IF;

// =========================================================
// 3. FAULT INJECTION AND FIELD DEVICE SIMULATION
// =========================================================
stOut.stFaults.xForceJamPE3 := stContext.eActiveScenario = E_TestHarnessScenario.TH_JAM_PE3;
stOut.stFaults.xForcePE2StuckHigh := stContext.eActiveScenario = E_TestHarnessScenario.TH_SENSOR_STUCK_HIGH_PE2;
stOut.stFaults.xForcePE2StuckLow := stContext.eActiveScenario = E_TestHarnessScenario.TH_SENSOR_STUCK_LOW_PE2;
stOut.stFaults.xStartWithProductPresent := stContext.eActiveScenario = E_TestHarnessScenario.TH_START_PRODUCT_PRESENT;
stOut.stFaults.xBarcodeMisread := stContext.eActiveScenario = E_TestHarnessScenario.TH_BARCODE_MISREAD;
stOut.stFaults.xNetworkDropout := stContext.eActiveScenario = E_TestHarnessScenario.TH_NETWORK_DROPOUT;
stOut.stFaults.xManualOverrideAbuse := stContext.eActiveScenario = E_TestHarnessScenario.TH_MANUAL_OVERRIDE_ABUSE;
stOut.stFaults.xRecipeChangeMidCycle := stContext.eActiveScenario = E_TestHarnessScenario.TH_RECIPE_CHANGE_MID_CYCLE;
stOut.stFaults.xThroughputDegradation := stContext.eActiveScenario = E_TestHarnessScenario.TH_THROUGHPUT_DEGRADATION;

xResetPulse := stContext.rScenarioElapsed_s <= (rCycleTime_s * 1.5);
xStartPulse := (stContext.rScenarioElapsed_s >= 1.20) AND (stContext.rScenarioElapsed_s < (1.20 + rCycleTime_s * 1.5));
xStopPulse := FALSE;
xClearPulse := FALSE;
xUnholdPulse := FALSE;
xLoadRecipePulse := FALSE;
xManualResetJam := FALSE;
xAlarmAck := FALSE;

xNetworkAvailable := TRUE;
IF stOut.stFaults.xNetworkDropout THEN
    IF (stContext.rScenarioElapsed_s >= rNetworkStart_s)
       AND (stContext.rScenarioElapsed_s < (rNetworkStart_s + rNetworkDuration_s)) THEN
        xNetworkAvailable := FALSE;
        stContext.xNetworkDropSeen := TRUE;
    ELSIF stContext.xNetworkDropSeen AND (stContext.rScenarioElapsed_s >= (rNetworkStart_s + rNetworkDuration_s)) THEN
        stContext.xNetworkRecovered := TRUE;
    END_IF;
END_IF;

IF xNetworkAvailable THEN
    stContext.rHeartbeatElapsed_s := stContext.rHeartbeatElapsed_s + rCycleTime_s;
    IF stContext.rHeartbeatElapsed_s >= 0.50 THEN
        stContext.xHeartbeat := NOT stContext.xHeartbeat;
        stContext.rHeartbeatElapsed_s := 0.0;
    END_IF;
END_IF;

IF stContext.eState = E_TestHarnessState.TH_RUNNING THEN
    IF stOut.stFaults.xStartWithProductPresent AND NOT stContext.xInitialProductSeeded THEN
        stContext.xPackageActive := TRUE;
        stContext.xPackageCreated := TRUE;
        stContext.xInitialProductSeeded := TRUE;
        stContext.udiPackagesInjected := stContext.udiPackagesInjected + 1;
        stContext.rPackagePosition_m := 0.22;
    ELSIF (NOT stContext.xPackageCreated)
          AND (stContext.rScenarioElapsed_s >= rPackageDelay_s)
          AND (stContext.eActiveScenario <> E_TestHarnessScenario.TH_NETWORK_DROPOUT)
          AND (stContext.eActiveScenario <> E_TestHarnessScenario.TH_MANUAL_OVERRIDE_ABUSE) THEN
        stContext.xPackageActive := TRUE;
        stContext.xPackageCreated := TRUE;
        stContext.udiPackagesInjected := stContext.udiPackagesInjected + 1;
        stContext.rPackagePosition_m := 0.00;
    END_IF;
END_IF;

xRawPE1 := stContext.xPackageActive
           AND (stContext.rPackagePosition_m >= 0.10)
           AND (stContext.rPackagePosition_m <= 0.35);
xRawPE2 := stContext.xPackageActive
           AND (stContext.rPackagePosition_m >= 1.05)
           AND (stContext.rPackagePosition_m <= 1.25);
xRawPE3 := stContext.xPackageActive
           AND (stContext.rPackagePosition_m >= 1.95)
           AND (stContext.rPackagePosition_m <= 2.20);
xRawPE4 := stContext.xPackageActive
           AND (stContext.rPackagePosition_m >= 2.35)
           AND (stContext.rPackagePosition_m <= 2.55)
           AND (stContext.eActiveScenario <> E_TestHarnessScenario.TH_BARCODE_MISREAD)
           AND (stContext.eActiveScenario <> E_TestHarnessScenario.TH_SENSOR_STUCK_LOW_PE2)
           AND (stContext.eActiveScenario <> E_TestHarnessScenario.TH_START_PRODUCT_PRESENT);
xRawPE5 := FALSE;
xRawPE6 := stContext.xPackageActive
           AND (stContext.rPackagePosition_m >= 3.85)
           AND (stContext.rPackagePosition_m <= 4.10)
           AND ((stContext.eActiveScenario = E_TestHarnessScenario.TH_BARCODE_MISREAD)
                OR (stContext.eActiveScenario = E_TestHarnessScenario.TH_SENSOR_STUCK_LOW_PE2));

IF stOut.stFaults.xForcePE2StuckHigh
   AND (stContext.rScenarioElapsed_s >= rJamStart_s)
   AND (stContext.rScenarioElapsed_s < (rJamStart_s + rJamDuration_s)) THEN
    xRawPE2 := TRUE;
END_IF;
IF stOut.stFaults.xForcePE2StuckLow THEN
    xRawPE2 := FALSE;
END_IF;
IF stOut.stFaults.xForceJamPE3
   AND (stContext.rScenarioElapsed_s >= rJamStart_s)
   AND (stContext.rScenarioElapsed_s < (rJamStart_s + rJamDuration_s)) THEN
    xRawPE3 := TRUE;
END_IF;

IF stOut.stFaults.xBarcodeMisread THEN
    stOut.sScannerData := 'BAD-SCAN-001';
    stOut.xScannerDataValid := FALSE;
ELSIF stOut.stFaults.xRecipeChangeMidCycle THEN
    stOut.sScannerData := 'SKU-LANE-A-RECIPE-CHANGE';
    stOut.xScannerDataValid := TRUE;
ELSE
    stOut.sScannerData := 'SKU-LANE-A-001';
    stOut.xScannerDataValid := TRUE;
END_IF;

IF stOut.stFaults.xRecipeChangeMidCycle
   AND (stContext.rScenarioElapsed_s >= rRecipeChange_s)
   AND (stContext.rScenarioElapsed_s < (rRecipeChange_s + rCycleTime_s * 1.5)) THEN
    xLoadRecipePulse := TRUE;
    stContext.xRecipeChangeSeen := TRUE;
END_IF;

IF stOut.stFaults.xManualOverrideAbuse
   AND (stContext.rScenarioElapsed_s >= rManualAbuseStart_s)
   AND (stContext.rScenarioElapsed_s < (rManualAbuseStart_s + rManualAbuseDuration_s)) THEN
    stManual.xJogConveyorForward := TRUE;
    stManual.rJogSpeed_mps := 1.25;
    stManual.xDiverter1Extend := TRUE;
    stManual.xDiverter2Extend := TRUE;
ELSE
    stManual.xJogConveyorForward := FALSE;
    stManual.rJogSpeed_mps := 0.20;
    stManual.xDiverter1Extend := FALSE;
    stManual.xDiverter2Extend := FALSE;
END_IF;

IF (fbJamDetector.stOut.xJamAlarm OR fbConveyor.xJamAlarm)
   AND NOT stContext.xJamResetIssued
   AND (stContext.rScenarioElapsed_s > (rJamStart_s + rJamDuration_s + 0.40)) THEN
    xManualResetJam := TRUE;
    xAlarmAck := TRUE;
    stContext.xJamResetIssued := TRUE;
END_IF;

IF fbJamDetector.stOut.xResetAcceptedPulse AND NOT stContext.xUnholdIssued THEN
    xUnholdPulse := TRUE;
    stContext.xUnholdIssued := TRUE;
END_IF;

xDiv1Home := NOT fbDiverter1.stOut.xCommandExtend;
xDiv1Work := fbDiverter1.stOut.xCommandExtend;
xDiv2Home := NOT fbDiverter2.stOut.xCommandExtend;
xDiv2Work := fbDiverter2.stOut.xCommandExtend;

// =========================================================
// 4. PRODUCTION MODULE CONFIGURATION AND EXECUTION
// =========================================================
stLineConfig.rDefaultTargetSpeed_mps := rNominalSpeed_mps;
stLineConfig.rMinimumTargetSpeed_mps := 0.05;
stLineConfig.rMaximumTargetSpeed_mps := 1.50;
stLineConfig.uiRecipeCount := 3;
stLineConfig.sLaneAPattern := 'LANE-A';
stLineConfig.sLaneBPattern := 'LANE-B';
stLineConfig.sRejectPattern := 'REJECT';

stLineConfig.arrRecipeBook[1].uiRecipeID := 1;
stLineConfig.arrRecipeBook[1].xEnabled := TRUE;
stLineConfig.arrRecipeBook[1].sName := 'Harness Default';
IF stOut.stFaults.xThroughputDegradation THEN
    stLineConfig.arrRecipeBook[1].rAutoSpeed_mps := rDegradedSpeed_mps;
ELSE
    stLineConfig.arrRecipeBook[1].rAutoSpeed_mps := rNominalSpeed_mps;
END_IF;
stLineConfig.arrRecipeBook[1].rManualMaxSpeed_mps := 0.40;
stLineConfig.arrRecipeBook[1].rMaintenanceSpeedLimit_mps := 0.15;
stLineConfig.arrRecipeBook[1].sLaneAPattern := 'LANE-A';
stLineConfig.arrRecipeBook[1].sLaneBPattern := 'LANE-B';
stLineConfig.arrRecipeBook[1].sRejectPattern := 'REJECT';
stLineConfig.arrRecipeBook[1].rScannerWindowStart_m := 1.00;
stLineConfig.arrRecipeBook[1].rScannerWindowEnd_m := 1.40;
stLineConfig.arrRecipeBook[1].rDiverter1WindowStart_m := 2.05;
stLineConfig.arrRecipeBook[1].rDiverter1WindowEnd_m := 2.35;
stLineConfig.arrRecipeBook[1].rDiverter2WindowStart_m := 3.05;
stLineConfig.arrRecipeBook[1].rDiverter2WindowEnd_m := 3.35;
stLineConfig.arrRecipeBook[1].rRejectExitPosition_m := 4.20;
stLineConfig.arrRecipeBook[1].rPackageTimeout_s := 12.0;

stLineConfig.arrRecipeBook[2] := stLineConfig.arrRecipeBook[1];
stLineConfig.arrRecipeBook[2].uiRecipeID := 2;
stLineConfig.arrRecipeBook[2].sName := 'Harness Alt';
stLineConfig.arrRecipeBook[2].sLaneAPattern := 'ALT-A';
stLineConfig.arrRecipeBook[2].sLaneBPattern := 'ALT-B';
stLineConfig.arrRecipeBook[2].sRejectPattern := 'ALT-R';
stLineConfig.arrRecipeBook[3] := stLineConfig.arrRecipeBook[1];
stLineConfig.arrRecipeBook[3].uiRecipeID := 3;
stLineConfig.arrRecipeBook[3].sName := 'Harness Slow';
stLineConfig.arrRecipeBook[3].rAutoSpeed_mps := 0.30;

stStationConfig.rDefaultSpeed_mps := rNominalSpeed_mps;
stStationConfig.rMinimumSpeed_mps := 0.05;
stStationConfig.rMaximumSpeed_mps := 1.50;
stStationConfig.rManualMaxSpeed_mps := 0.40;
stStationConfig.rMaintenanceMaxSpeed_mps := 0.15;
stStationConfig.rTransitionTimeout_s := 1.00;

stDiverter1Config.tActuatorName := 'Harness Diverter 1';
stDiverter1Config.rExtendTimeout_s := 0.75;
stDiverter1Config.rRetractTimeout_s := 0.75;
stDiverter1Config.rWorkDwell_s := 0.10;
stDiverter1Config.rVerificationTimeout_s := 2.00;
stDiverter1Config.rManualHoldLimit_s := 1.00;
stDiverter1Config.xRequireHomeBeforeFire := TRUE;
stDiverter1Config.xRequireVerification := TRUE;
stDiverter2Config := stDiverter1Config;
stDiverter2Config.tActuatorName := 'Harness Diverter 2';

stJamConfig.rReferenceSpeed_mps := rNominalSpeed_mps;
stJamConfig.rBaseJamLimit_s := 3.00;
stJamConfig.rMaximumJamLimit_s := 8.00;
stJamConfig.rWarningRatio := 0.80;

stKPIConfig.rPerformanceFactor := 0.96;
stKPIConfig.rTargetRate_ppm := 60.0;
stKPIConfig.xUseRoutePulses := TRUE;

stAlarmConfig.rFlashPeriod_s := 0.50;
stHistorianConfig.tOpcUaNamespaceUri := 'urn:mhmc:test-harness';
stHistorianConfig.rSamplePeriod_s := 0.50;
stHistorianConfig.rHeartbeatTimeout_s := 1.00;
stHistorianConfig.uiMaxMissedHeartbeats := 3;

stManual.xScannerTrigger := FALSE;
stManual.xResetJam := xManualResetJam;
stManual.xResetCounters := FALSE;
stManual.xMaintenanceKey := FALSE;

stLineIn.xStartCommand := xStartPulse;
stLineIn.xStopCommand := xStopPulse;
stLineIn.xResetCommand := xResetPulse;
stLineIn.xHoldCommand := FALSE;
stLineIn.xUnholdCommand := xUnholdPulse;
stLineIn.xClearCommand := xClearPulse;
stLineIn.xLoadRecipeCommand := xLoadRecipePulse;
IF xLoadRecipePulse THEN
    stLineIn.uiRecipeSelect := 3;
ELSE
    stLineIn.uiRecipeSelect := 1;
END_IF;
stLineIn.rRecipeSpeed_mps := 0.0;
stLineIn.xUseRecipePayload := FALSE;
stLineIn.eModeSelect := E_PackML_Mode.AUTO;
stLineIn.xOpcUaConnected := xNetworkAvailable;
stLineIn.xStationReady := fbStationController.xInitialized OR fbStationController.stOut.xPermissivesOK;
fbLineSupervisor(stIn := stLineIn, stConfig := stLineConfig, xInit := xInitModules);

stJamIn.xRawPE1 := xRawPE1;
stJamIn.xRawPE2 := xRawPE2;
stJamIn.xRawPE3 := xRawPE3;
stJamIn.xConveyorRunning := fbConveyor.stStatus.xIsRunning;
stJamIn.rConveyorSpeed_mps := fbConveyor.stStatus.rSpeedFeedback;
stJamIn.xResetJam := xManualResetJam;
stJamIn.xRecoveryRequest := xUnholdPulse;
stJamIn.xAllowAutoRecovery := fbStationController.stOut.xPermissivesOK;
stJamIn.ePackMLState := fbStationController.stOut.ePackMLState;
stJamIn.rCycleTime_s := rCycleTime_s;
fbJamDetector(stIn := stJamIn, stConfig := stJamConfig, xInit := xInitModules);

stStationIn.xStart := fbLineSupervisor.stOut.xStartCellPulse;
stStationIn.xStop := fbLineSupervisor.stOut.xStopCellPulse;
stStationIn.xReset := fbLineSupervisor.stOut.xResetCellPulse;
stStationIn.xHold := fbLineSupervisor.stOut.xHoldCell OR fbJamDetector.stOut.xRequestHold OR fbRouting.xRouteFault;
stStationIn.xUnhold := fbLineSupervisor.stOut.xUnholdCellPulse OR fbJamDetector.stOut.xResetAcceptedPulse;
stStationIn.xClear := fbLineSupervisor.stOut.xClearCellPulse;
stStationIn.eRequestedMode := fbLineSupervisor.stOut.eRequestedMode;
stStationIn.stRecipe := fbLineSupervisor.stOut.stActiveRecipe;
stStationIn.stManual := stManual;
stStationIn.rTargetSpeed_mps := fbLineSupervisor.stOut.rTargetSpeed_mps;
stStationIn.xSafetyLoopOK := TRUE;
stStationIn.xAirPressureOK := TRUE;
stStationIn.xVfdReady := NOT fbConveyor.stStatus.xFaulted;
stStationIn.xDiverter1Faulted := fbDiverter1.stOut.xFaulted;
stStationIn.xDiverter2Faulted := fbDiverter2.stOut.xFaulted;
stStationIn.xJamAlarm := fbJamDetector.stOut.xJamAlarm OR fbConveyor.xJamAlarm;
stStationIn.xDownstreamBlocked := fbRouting.xRouteFault;
stStationIn.rCycleTime_s := rCycleTime_s;
fbStationController(stIn := stStationIn, stConfig := stStationConfig, xInit := xInitModules);

rCommandedSpeed_mps := fbStationController.stOut.rConveyorSpeed_mps;
fbConveyor(
    xRunCmd := fbStationController.stOut.xConveyorRunEnable
               AND NOT fbStationController.stOut.xConveyorQuickStop
               AND NOT fbRouting.xRouteFault
               AND NOT fbJamDetector.stOut.xJamAlarm,
    rCmdSpeed := rCommandedSpeed_mps,
    xRawPE1 := xRawPE1,
    xRawPE2 := xRawPE2,
    xRawPE3 := xRawPE3,
    tJamLimit := T#3S,
    xResetAlarms := fbStationController.stOut.xResetAlarms
);

fbRouting(
    xConveyorRunning := fbConveyor.stStatus.xIsRunning,
    rConveyorSpeed := fbConveyor.stStatus.rSpeedFeedback,
    sScannerString := stOut.sScannerData,
    xScannerReadSuccess := stOut.xScannerDataValid,
    xRawPE4 := xRawPE4,
    xRawPE5 := xRawPE5,
    xRawPE6 := xRawPE6,
    xResetAlarms := fbStationController.stOut.xResetAlarms,
    xPE1 := xRawPE1,
    xPE2 := xRawPE2,
    xPE3 := xRawPE3,
    tCycleTime := rCycleTime_s,
    eCurrentMode := fbStationController.stOut.eCurrentMode,
    stActiveRecipe := fbLineSupervisor.stOut.stActiveRecipe,
    stManual := stManual,
    xAutoEnable := fbStationController.stOut.xRunRouting,
    xMaintenanceSafeguardsOK := fbStationController.stOut.xMaintenanceSafe,
    xDiverter1Ready := xDiv1Home AND NOT fbDiverter1.stOut.xBusy AND NOT fbDiverter1.stOut.xFaulted,
    xDiverter2Ready := xDiv2Home AND NOT fbDiverter2.stOut.xBusy AND NOT fbDiverter2.stOut.xFaulted,
    xDiverter1Done := fbDiverter1.stOut.xDone,
    xDiverter2Done := fbDiverter2.stOut.xDone,
    xDiverter1Faulted := fbDiverter1.stOut.xFaulted,
    xDiverter2Faulted := fbDiverter2.stOut.xFaulted
);

stDiverter1In.xAutoEnable := fbStationController.stOut.xAutoModeActive;
stDiverter1In.xExtendRequest := fbRouting.stDiverter1.xCommandExtend;
stDiverter1In.xManualExtend := fbStationController.stOut.xManualDivert1;
stDiverter1In.eMode := fbStationController.stOut.eCurrentMode;
stDiverter1In.xManualEnable := fbStationController.stOut.xManualModeActive;
stDiverter1In.xMaintenanceEnable := fbStationController.stOut.xMaintenanceActive;
stDiverter1In.xInterlockOK := fbStationController.stOut.xPermissivesOK;
stDiverter1In.xInhibit := fbJamDetector.stOut.xJamAlarm OR fbRouting.xRouteFault;
stDiverter1In.xForceRetract := fbStationController.stOut.xConveyorQuickStop OR NOT fbStationController.stOut.xPermissivesOK;
stDiverter1In.xHomeSensor := xDiv1Home;
stDiverter1In.xWorkSensor := xDiv1Work;
stDiverter1In.xVerificationSensor := xRawPE4;
stDiverter1In.xResetFault := fbStationController.stOut.xResetAlarms;
stDiverter1In.rCycleTime_s := rCycleTime_s;
fbDiverter1(stIn := stDiverter1In, stConfig := stDiverter1Config, xInit := xInitModules);

stDiverter2In := stDiverter1In;
stDiverter2In.xExtendRequest := fbRouting.stDiverter2.xCommandExtend;
stDiverter2In.xManualExtend := fbStationController.stOut.xManualDivert2;
stDiverter2In.xHomeSensor := xDiv2Home;
stDiverter2In.xWorkSensor := xDiv2Work;
stDiverter2In.xVerificationSensor := xRawPE5;
fbDiverter2(stIn := stDiverter2In, stConfig := stDiverter2Config, xInit := xInitModules);

stKPIIn.xPE4LaneA := xRawPE4;
stKPIIn.xPE5LaneB := xRawPE5;
stKPIIn.xPE6Reject := xRawPE6;
stKPIIn.xLaneAVerifiedPulse := fbRouting.xLaneAVerifiedPulse;
stKPIIn.xLaneBVerifiedPulse := fbRouting.xLaneBVerifiedPulse;
stKPIIn.xRejectVerifiedPulse := fbRouting.xRejectVerifiedPulse;
stKPIIn.xPackageRegisteredPulse := fbRouting.xPackageRegisteredPulse;
stKPIIn.xScanGoodPulse := fbRouting.xScanGoodPulse;
stKPIIn.xScanBadPulse := fbRouting.xScanBadPulse;
stKPIIn.ePackMLState := fbStationController.stOut.ePackMLState;
stKPIIn.xFaultDowntime := fbAlarmManager.stOut.xAnyAlarmActive
                          OR fbJamDetector.stOut.xJamAlarm
                          OR fbRouting.xRouteFault
                          OR (fbStationController.stOut.ePackMLState = E_PackML_State.HELD);
stKPIIn.xResetCounters := FALSE;
stKPIIn.rCycleTime_s := rCycleTime_s;
fbKPIService(stIn := stKPIIn, stConfig := stKPIConfig, xInit := xInitModules);

stAlarmIn.xSafetyLoopOK := TRUE;
stAlarmIn.xAirPressureOK := TRUE;
stAlarmIn.xVfdFault := fbConveyor.stStatus.xFaulted;
stAlarmIn.xJamAlarm := fbJamDetector.stOut.xJamAlarm OR fbConveyor.xJamAlarm;
stAlarmIn.xJamWarning := fbJamDetector.stOut.xWarning;
stAlarmIn.xDiverter1Faulted := fbDiverter1.stOut.xFaulted;
stAlarmIn.xDiverter2Faulted := fbDiverter2.stOut.xFaulted;
stAlarmIn.xRouteFault := fbRouting.xRouteFault;
stAlarmIn.ePackMLState := fbStationController.stOut.ePackMLState;
stAlarmIn.eCurrentMode := fbStationController.stOut.eCurrentMode;
stAlarmIn.xAcknowledge := xAlarmAck;
stAlarmIn.xReset := fbStationController.stOut.xResetAlarms;
stAlarmIn.rCycleTime_s := rCycleTime_s;
fbAlarmManager(stIn := stAlarmIn, stConfig := stAlarmConfig, xInit := xInitModules);

stDiverter1Status.xHomeSensor := fbDiverter1.stOut.xHome;
stDiverter1Status.xWorkSensor := fbDiverter1.stOut.xWork;
stDiverter1Status.xCommandExtend := fbDiverter1.stOut.xCommandExtend;
stDiverter1Status.xVerificationSensor := xRawPE4;
stDiverter1Status.xFaulted := fbDiverter1.stOut.xFaulted;
stDiverter2Status.xHomeSensor := fbDiverter2.stOut.xHome;
stDiverter2Status.xWorkSensor := fbDiverter2.stOut.xWork;
stDiverter2Status.xCommandExtend := fbDiverter2.stOut.xCommandExtend;
stDiverter2Status.xVerificationSensor := xRawPE5;
stDiverter2Status.xFaulted := fbDiverter2.stOut.xFaulted;

stTimelineForHistorian := fbAlarmManager.stOut.stTimeline;
IF stOut.stHarnessTimeline.xNewEvent THEN
    stTimelineForHistorian := stOut.stHarnessTimeline;
END_IF;

stHistorianIn.xEnable := TRUE;
stHistorianIn.xOpcUaServerReady := xNetworkAvailable;
stHistorianIn.xCollectorHeartbeat := stContext.xHeartbeat;
stHistorianIn.xLastWriteOK := xNetworkAvailable;
stHistorianIn.stConveyor := fbConveyor.stStatus;
stHistorianIn.stDiverter1 := stDiverter1Status;
stHistorianIn.stDiverter2 := stDiverter2Status;
stHistorianIn.udiTotalCount := fbKPIService.stOut.udiTotalPackages;
stHistorianIn.udiLaneACount := fbKPIService.stOut.udiLaneAPackages;
stHistorianIn.udiLaneBCount := fbKPIService.stOut.udiLaneBPackages;
stHistorianIn.udiRejectCount := fbKPIService.stOut.udiRejectPackages;
stHistorianIn.uiTotalJams := fbJamDetector.stOut.uiTotalJams;
stHistorianIn.rOEE_percent := fbKPIService.stOut.rOEE_percent;
stHistorianIn.xActiveAlarm := fbAlarmManager.stOut.xAnyAlarmActive;
stHistorianIn.sActiveAlarmMessage := fbAlarmManager.stOut.sActiveMessage;
stHistorianIn.stTimeline := stTimelineForHistorian;
stHistorianIn.rCycleTime_s := rCycleTime_s;
fbHistorianConnector(stIn := stHistorianIn, stConfig := stHistorianConfig, xInit := xInitModules);

IF fbHistorianConnector.stOut.xSampleStrobe OR fbHistorianConnector.stOut.xPublishEvent THEN
    stContext.xHistorianPublished := TRUE;
END_IF;
IF xNetworkAvailable THEN
    stContext.xOPCUAReadyObserved := TRUE;
END_IF;
IF stOut.stFaults.xManualOverrideAbuse
   AND (stManual.xDiverter1Extend OR stManual.xDiverter2Extend)
   AND NOT fbDiverter1.stOut.xCommandExtend
   AND NOT fbDiverter2.stOut.xCommandExtend THEN
    stContext.xManualAbuseBlocked := TRUE;
END_IF;

// Update the simulated package after modules have consumed this scan's sensors.
IF stContext.xPackageActive AND fbConveyor.stStatus.xIsRunning THEN
    rPositionStep_m := fbConveyor.stStatus.rSpeedFeedback * rCycleTime_s;
    stContext.rPackagePosition_m := stContext.rPackagePosition_m + rPositionStep_m;
END_IF;
IF stContext.xPackageActive AND (stContext.rPackagePosition_m > 4.60) THEN
    stContext.xPackageActive := FALSE;
END_IF;

// =========================================================
// 5. SCENARIO EVALUATION
// =========================================================
xScenarioDone := FALSE;
xScenarioPass := FALSE;
CASE stContext.eActiveScenario OF
    E_TestHarnessScenario.TH_NORMAL_LANE_A:
        xScenarioDone := (fbKPIService.stOut.udiLaneAPackages >= 1) OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := (fbKPIService.stOut.udiLaneAPackages >= 1)
                         AND NOT fbAlarmManager.stOut.xAnyAlarmActive
                         AND stContext.xHistorianPublished;
    E_TestHarnessScenario.TH_JAM_PE3:
        xScenarioDone := (stContext.xJamResetIssued AND (fbStationController.stOut.ePackMLState = E_PackML_State.EXECUTE))
                         OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := (fbJamDetector.stOut.uiTotalJams >= 1)
                         AND stContext.xJamResetIssued
                         AND stContext.xUnholdIssued
                         AND NOT fbJamDetector.stOut.xJamAlarm;
    E_TestHarnessScenario.TH_SENSOR_STUCK_HIGH_PE2:
        xScenarioDone := fbJamDetector.stOut.xJamAlarm OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := fbJamDetector.stOut.xJamAlarm AND (fbJamDetector.stOut.uiJamSource = 2);
    E_TestHarnessScenario.TH_SENSOR_STUCK_LOW_PE2:
        xScenarioDone := fbRouting.xRouteFault OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := fbRouting.xRouteFault AND (fbAlarmManager.stOut.uiActiveAlarmCode = 250);
    E_TestHarnessScenario.TH_START_PRODUCT_PRESENT:
        xScenarioDone := fbRouting.xRouteFault OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := fbRouting.xRouteFault AND (fbKPIService.stOut.udiTotalPackages = 0);
    E_TestHarnessScenario.TH_BARCODE_MISREAD:
        xScenarioDone := (fbKPIService.stOut.udiRejectPackages >= 1) OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := (fbKPIService.stOut.udiRejectPackages >= 1)
                         AND (fbKPIService.stOut.udiBadScans >= 1);
    E_TestHarnessScenario.TH_NETWORK_DROPOUT:
        xScenarioDone := (stContext.xNetworkDropSeen AND stContext.xNetworkRecovered AND fbHistorianConnector.stOut.xHistorianHealthy)
                         OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := stContext.xNetworkDropSeen
                         AND stContext.xNetworkRecovered
                         AND fbHistorianConnector.stOut.xHistorianHealthy
                         AND NOT fbAlarmManager.stOut.xAnyAlarmActive;
    E_TestHarnessScenario.TH_MANUAL_OVERRIDE_ABUSE:
        xScenarioDone := (stContext.rScenarioElapsed_s >= (rManualAbuseStart_s + rManualAbuseDuration_s + 1.0))
                         OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := stContext.xManualAbuseBlocked AND NOT fbAlarmManager.stOut.xAnyAlarmActive;
    E_TestHarnessScenario.TH_RECIPE_CHANGE_MID_CYCLE:
        xScenarioDone := (stContext.xRecipeChangeSeen AND (fbKPIService.stOut.udiLaneAPackages >= 1))
                         OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := stContext.xRecipeChangeSeen
                         AND (fbLineSupervisor.stOut.uiActiveRecipe = 3)
                         AND (fbKPIService.stOut.udiLaneAPackages >= 1)
                         AND NOT fbRouting.xRouteFault;
    E_TestHarnessScenario.TH_THROUGHPUT_DEGRADATION:
        xScenarioDone := (stContext.rScenarioElapsed_s >= 10.0) OR (stContext.rScenarioElapsed_s >= rScenarioTimeout_s);
        xScenarioPass := (fbKPIService.stOut.rThroughput_ppm < stConfig.rMinThroughput_ppm)
                         AND stContext.xHistorianPublished
                         AND NOT fbAlarmManager.stOut.xAnyAlarmActive;
    ELSE
        xScenarioDone := TRUE;
        xScenarioPass := FALSE;
END_CASE;

IF (stContext.eState = E_TestHarnessState.TH_RUNNING) AND xScenarioDone AND NOT stContext.xScenarioEvaluated THEN
    stContext.xScenarioEvaluated := TRUE;
    stContext.eState := E_TestHarnessState.TH_EVALUATING;
    stOut.xScenarioActive := FALSE;
    IF xScenarioPass THEN
        stOut.eVerdict := E_TestHarnessVerdict.TH_VERDICT_PASS;
        stOut.uiPassCount := stOut.uiPassCount + 1;
        stOut.sStatusText := 'Scenario passed';
        F_EventTimeline_Append(
            rTimestamp_s := stContext.rRuntime_s,
            eClass := E_MHMCEventClass.EVENT_KPI,
            uiCode := 200,
            uiSeverity := 0,
            ePackMLState := fbStationController.stOut.ePackMLState,
            eMode := fbStationController.stOut.eCurrentMode,
            udiPackageID := fbRouting.stRoutingStatus.udiLastCompletedID,
            eRouteTarget := fbRouting.stRoutingStatus.eLastRouteTarget,
            sMessage := 'Test scenario passed',
            stTimeline := stOut.stHarnessTimeline
        );
    ELSE
        stOut.eVerdict := E_TestHarnessVerdict.TH_VERDICT_FAIL;
        stOut.uiFailCount := stOut.uiFailCount + 1;
        stOut.sStatusText := 'Scenario failed';
        F_EventTimeline_Append(
            rTimestamp_s := stContext.rRuntime_s,
            eClass := E_MHMCEventClass.EVENT_ALARM,
            uiCode := 900,
            uiSeverity := 750,
            ePackMLState := fbStationController.stOut.ePackMLState,
            eMode := fbStationController.stOut.eCurrentMode,
            udiPackageID := fbRouting.stRoutingStatus.udiLastCompletedID,
            eRouteTarget := fbRouting.stRoutingStatus.eLastRouteTarget,
            sMessage := 'Test scenario deviation',
            stTimeline := stOut.stHarnessTimeline
        );
    END_IF;

    IF (stContext.iScenarioIndex >= 1) AND (stContext.iScenarioIndex <= 10) THEN
        stOut.arrScenarioResults[stContext.iScenarioIndex].eScenario := stContext.eActiveScenario;
        stOut.arrScenarioResults[stContext.iScenarioIndex].eVerdict := stOut.eVerdict;
        stOut.arrScenarioResults[stContext.iScenarioIndex].rStartTimestamp_s := stContext.rRuntime_s - stContext.rScenarioElapsed_s;
        stOut.arrScenarioResults[stContext.iScenarioIndex].rEndTimestamp_s := stContext.rRuntime_s;
        stOut.arrScenarioResults[stContext.iScenarioIndex].rDuration_s := stContext.rScenarioElapsed_s;
        stOut.arrScenarioResults[stContext.iScenarioIndex].udiPackagesInjected := stContext.udiPackagesInjected;
        stOut.arrScenarioResults[stContext.iScenarioIndex].udiTotalPackages := fbKPIService.stOut.udiTotalPackages;
        stOut.arrScenarioResults[stContext.iScenarioIndex].udiLaneAPackages := fbKPIService.stOut.udiLaneAPackages;
        stOut.arrScenarioResults[stContext.iScenarioIndex].udiLaneBPackages := fbKPIService.stOut.udiLaneBPackages;
        stOut.arrScenarioResults[stContext.iScenarioIndex].udiRejectPackages := fbKPIService.stOut.udiRejectPackages;
        stOut.arrScenarioResults[stContext.iScenarioIndex].uiJamCount := fbJamDetector.stOut.uiTotalJams;
        stOut.arrScenarioResults[stContext.iScenarioIndex].uiAlarmCode := fbAlarmManager.stOut.uiActiveAlarmCode;
        stOut.arrScenarioResults[stContext.iScenarioIndex].rThroughput_ppm := fbKPIService.stOut.rThroughput_ppm;
        stOut.arrScenarioResults[stContext.iScenarioIndex].rOEE_percent := fbKPIService.stOut.rOEE_percent;
        stOut.arrScenarioResults[stContext.iScenarioIndex].xHistorianPublished := stContext.xHistorianPublished;
        stOut.arrScenarioResults[stContext.iScenarioIndex].xOPCUAReadyObserved := stContext.xOPCUAReadyObserved;
        stOut.arrScenarioResults[stContext.iScenarioIndex].sActual := fbAlarmManager.stOut.sActiveMessage;
        IF xScenarioPass THEN
            stOut.arrScenarioResults[stContext.iScenarioIndex].sDeviation := 'None';
        ELSE
            stOut.arrScenarioResults[stContext.iScenarioIndex].sDeviation := 'Expected condition not met before timeout';
        END_IF;
        CASE stContext.eActiveScenario OF
            E_TestHarnessScenario.TH_NORMAL_LANE_A:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'Lane A package sorted without alarm and historian publishes';
            E_TestHarnessScenario.TH_JAM_PE3:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'PE3 jam detected, reset accepted, and station unholds';
            E_TestHarnessScenario.TH_SENSOR_STUCK_HIGH_PE2:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'PE2 stuck high creates jam source 2';
            E_TestHarnessScenario.TH_SENSOR_STUCK_LOW_PE2:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'PE2 stuck low creates route fault';
            E_TestHarnessScenario.TH_START_PRODUCT_PRESENT:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'Start with occupied PE produces route fault and no KPI count';
            E_TestHarnessScenario.TH_BARCODE_MISREAD:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'Misread routes package to reject and increments bad scan';
            E_TestHarnessScenario.TH_NETWORK_DROPOUT:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'Historian drops unhealthy then recovers without process alarm';
            E_TestHarnessScenario.TH_MANUAL_OVERRIDE_ABUSE:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'AUTO-mode manual abuse is blocked';
            E_TestHarnessScenario.TH_RECIPE_CHANGE_MID_CYCLE:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'Recipe load logs while active package still completes';
            E_TestHarnessScenario.TH_THROUGHPUT_DEGRADATION:
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'Slow speed lowers throughput KPI and historian publishes';
            ELSE
                stOut.arrScenarioResults[stContext.iScenarioIndex].sExpected := 'No scenario';
        END_CASE;
    END_IF;
END_IF;

IF stContext.eState = E_TestHarnessState.TH_EVALUATING THEN
    stContext.rAutoCompleteHold_s := stContext.rAutoCompleteHold_s + rCycleTime_s;
    IF stContext.rAutoCompleteHold_s >= 0.50 THEN
        stContext.rAutoCompleteHold_s := 0.0;
        IF stContext.xRunAllActive AND (stContext.iScenarioIndex < 10) THEN
            stContext.iScenarioIndex := stContext.iScenarioIndex + 1;
            stContext.eActiveScenario := F_TestHarness_ScenarioFromIndex(iIndex := stContext.iScenarioIndex);
            stContext.xScenarioStarted := FALSE;
            stContext.xScenarioEvaluated := FALSE;
            stContext.eState := E_TestHarnessState.TH_ARMING;
        ELSE
            IF stOut.uiFailCount = 0 THEN
                stContext.eState := E_TestHarnessState.TH_COMPLETE;
            ELSE
                stContext.eState := E_TestHarnessState.TH_FAILED;
            END_IF;
            stOut.xAllScenariosComplete := TRUE;
        END_IF;
    END_IF;
END_IF;

// =========================================================
// 6. OUTPUT MIRRORS FOR OPC UA, HISTORIAN, AND HMI
// =========================================================
stOut.eState := stContext.eState;
stOut.eActiveScenario := stContext.eActiveScenario;
stOut.rRuntime_s := stContext.rRuntime_s;
stOut.rScenarioElapsed_s := stContext.rScenarioElapsed_s;
stOut.iActiveScenarioIndex := stContext.iScenarioIndex;
stOut.xOPCUAServerReady := xNetworkAvailable;
stOut.xHistorianHealthy := fbHistorianConnector.stOut.xHistorianHealthy;
stOut.xHistorianSample := fbHistorianConnector.stOut.xSampleStrobe;
stOut.xConveyorRunning := fbConveyor.stStatus.xIsRunning;
stOut.rConveyorSpeed_mps := fbConveyor.stStatus.rSpeedFeedback;
stOut.uiTotalJams := fbJamDetector.stOut.uiTotalJams;
stOut.xPE1 := xRawPE1;
stOut.xPE2 := xRawPE2;
stOut.xPE3 := xRawPE3;
stOut.xPE4 := xRawPE4;
stOut.xPE5 := xRawPE5;
stOut.xPE6 := xRawPE6;
stOut.stStationOut := fbStationController.stOut;
stOut.stRoutingStatus := fbRouting.stRoutingStatus;
stOut.stKPI := fbKPIService.stOut;
stOut.stAlarm := fbAlarmManager.stOut;
stOut.stHistorian := fbHistorianConnector.stOut;

eState := stContext.eState;
xInitialized := stContext.xInitialized;
stContext.xStartLast := stIn.xStartScenario;
xInitLast := xInit;
END_FUNCTION_BLOCK

PROGRAM TestHarness
VAR
    // Symbolic controls for TwinCAT/CODESYS online testing. Bind these to HMI/OPC UA if desired.
    xTH_Enable         : BOOL := TRUE;
    xTH_Start          : BOOL := FALSE;
    xTH_RunAll         : BOOL := TRUE;
    xTH_Reset          : BOOL := FALSE;
    eTH_ScenarioSelect : E_TestHarnessScenario := E_TestHarnessScenario.TH_NORMAL_LANE_A;
    rTH_CycleTime_s    : REAL := 0.05;

    stTH_In            : ST_TestHarnessInput;
    stTH_Config        : ST_TestHarnessConfig;
    fbTH               : FB_TestHarness;
    stTH_Out           : ST_TestHarnessOutput;

    // Operator-facing mirrors. These are semantic tags, not raw I/O addresses.
    eTH_State          : E_TestHarnessState;
    eTH_Verdict        : E_TestHarnessVerdict;
    uiTH_PassCount     : UINT;
    uiTH_FailCount     : UINT;
    xTH_AllComplete    : BOOL;
    rTH_Throughput_ppm : REAL;
    uiTH_JamCount      : UINT;
    uiTH_AlarmCode     : UINT;
    sTH_StatusText     : STRING(120);
END_VAR

// Default harness timings. The FB normalises any zero value, but explicit values aid reviews.
stTH_Config.rTaskCycle_s := 0.05;
stTH_Config.rScenarioTimeout_s := 18.0;
stTH_Config.rPackageReleaseDelay_s := 3.0;
stTH_Config.rNominalSpeed_mps := 0.50;
stTH_Config.rDegradedSpeed_mps := 0.18;
stTH_Config.rMinThroughput_ppm := 8.0;
stTH_Config.rJamHoldStart_s := 4.5;
stTH_Config.rJamHoldDuration_s := 4.0;
stTH_Config.rNetworkDropStart_s := 4.0;
stTH_Config.rNetworkDropDuration_s := 7.0;
stTH_Config.rManualAbuseStart_s := 3.2;
stTH_Config.rManualAbuseDuration_s := 2.0;
stTH_Config.rRecipeChangeTime_s := 4.0;

stTH_In.xEnable := xTH_Enable;
stTH_In.xStartScenario := xTH_Start;
stTH_In.xRunAll := xTH_RunAll;
stTH_In.xReset := xTH_Reset;
stTH_In.eScenarioSelect := eTH_ScenarioSelect;
stTH_In.rCycleTime_s := rTH_CycleTime_s;

fbTH(stIn := stTH_In, stConfig := stTH_Config);
stTH_Out := fbTH.stOut;

eTH_State := fbTH.eState;
eTH_Verdict := stTH_Out.eVerdict;
uiTH_PassCount := stTH_Out.uiPassCount;
uiTH_FailCount := stTH_Out.uiFailCount;
xTH_AllComplete := stTH_Out.xAllScenariosComplete;
rTH_Throughput_ppm := stTH_Out.stKPI.rThroughput_ppm;
uiTH_JamCount := stTH_Out.uiTotalJams;
uiTH_AlarmCode := stTH_Out.stAlarm.uiActiveAlarmCode;
sTH_StatusText := stTH_Out.sStatusText;
END_PROGRAM

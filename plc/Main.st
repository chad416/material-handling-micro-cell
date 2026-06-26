PROGRAM Main
VAR
    // =========================================================
    // SYMBOLIC FIELD / SUPERVISORY INTERFACE
    // Bind these names to EtherCAT, OPC UA, HMI, or simulation I/O outside this program.
    // =========================================================
    xSafetyLoopOK           : BOOL := TRUE;  // Safety relay feedback.
    xAirPressureOK          : BOOL := TRUE;  // Pneumatic pressure switch.
    xVfdReady               : BOOL := TRUE;  // VFD ready/no-drive-fault feedback.
    xVfdFault               : BOOL := FALSE; // VFD fault feedback.

    xRemoteStart            : BOOL := FALSE; // HMI/OPC UA Start.
    xRemoteStop             : BOOL := FALSE; // HMI/OPC UA Stop.
    xRemoteReset            : BOOL := FALSE; // HMI/OPC UA Reset.
    xRemoteHold             : BOOL := FALSE; // HMI/OPC UA Hold.
    xRemoteUnhold           : BOOL := FALSE; // HMI/OPC UA Unhold.
    xRemoteClear            : BOOL := FALSE; // HMI/OPC UA Clear aborted.
    xAlarmAcknowledge       : BOOL := FALSE; // HMI/SCADA alarm acknowledge.

    xLoadRecipeCommand      : BOOL := FALSE; // HMI/MES recipe load request.
    uiRecipeSelect          : UINT := 1;     // Recipe selector.
    rRecipeSpeed_mps        : REAL := 0.0;   // Optional speed trim. 0.0 = recipe default.
    xUseRecipePayload       : BOOL := FALSE; // TRUE when stRecipePayload is valid.
    stRecipePayload         : ST_SortRecipe; // MES/HMI payload recipe.

    xManualJogForward       : BOOL := FALSE; // Hold-to-run manual conveyor jog.
    rManualJogSpeed_mps     : REAL := 0.20;  // Manual/maintenance jog speed request.
    xManualDiverter1Extend  : BOOL := FALSE; // Hold-to-run Diverter 1.
    xManualDiverter2Extend  : BOOL := FALSE; // Hold-to-run Diverter 2.
    xManualScannerTrigger   : BOOL := FALSE; // Manual scanner trigger.
    xManualResetJam         : BOOL := FALSE; // Operator confirms jam removed.
    xManualResetCounters    : BOOL := FALSE; // KPI reset.
    xMaintenanceKey         : BOOL := FALSE; // Maintenance key switch / role grant.
    eSelectedMode           : E_PackML_Mode := E_PackML_Mode.AUTO;

    xPE1_Infeed             : BOOL := FALSE; // Infeed package PE.
    xPE2_ScannerTrigger     : BOOL := FALSE; // Scanner trigger PE.
    xPE3_DiverterApproach   : BOOL := FALSE; // Diverter approach PE.
    xPE4_LaneAVerify        : BOOL := FALSE; // Lane A verification PE.
    xPE5_LaneBVerify        : BOOL := FALSE; // Lane B verification PE.
    xPE6_RejectVerify       : BOOL := FALSE; // Reject verification PE.
    xDivLaneA_HomeSensor    : BOOL := TRUE;  // Diverter Lane A home switch.
    xDivLaneA_WorkSensor    : BOOL := FALSE; // Diverter Lane A work switch.
    xDivLaneB_HomeSensor    : BOOL := TRUE;  // Diverter Lane B home switch.
    xDivLaneB_WorkSensor    : BOOL := FALSE; // Diverter Lane B work switch.

    sScannerData            : STRING(80) := '';    // Scanner payload.
    xScannerDataValid       : BOOL := FALSE;       // Scanner good-read flag.
    xHistorianEnable        : BOOL := TRUE;        // Enable historian handshake.
    xOpcUaServerReady       : BOOL := TRUE;        // OPC UA namespace ready.
    xCollectorHeartbeat     : BOOL := FALSE;       // Collector heartbeat bit.
    xHistorianLastWriteOK   : BOOL := TRUE;        // Collector write feedback.

    // =========================================================
    // SYMBOLIC OUTPUTS
    // =========================================================
    xVfdRunCmd              : BOOL := FALSE;
    rVfdSpeedCmd            : REAL := 0.0;
    xSolDiverter1Extend     : BOOL := FALSE;
    xSolDiverter2Extend     : BOOL := FALSE;
    xScannerTriggerCommand  : BOOL := FALSE;
    xStackGreen             : BOOL := FALSE;
    xStackYellow            : BOOL := FALSE;
    xStackRed               : BOOL := FALSE;
    xSounder                : BOOL := FALSE;

    // HMI/OPC UA mirrors retained for compatibility with earlier project revisions.
    xPermissivesOK          : BOOL := FALSE;
    uiHeartbeat             : UINT := 0;
    uiJamEventCounter       : UINT := 0;
    rTargetConveyorSpeed    : REAL := 0.50;
    rAvailability           : REAL := 1.0;
    rPerformance            : REAL := 1.0;
    rQuality                : REAL := 1.0;
    rOEEPercentage          : REAL := 100.0;
    stEventTimeline         : ST_MHMCEventTimeline;

    // =========================================================
    // MODULE INSTANCES
    // =========================================================
    fbLineSupervisor        : FB_LineSupervisor;
    fbStationController     : FB_StationController;
    fbConveyor              : FB_ConveyorControl;
    fbRouting               : FB_RoutingLogic;
    fbDiverter1             : FB_DiverterController;
    fbDiverter2             : FB_DiverterController;
    fbJamDetector           : FB_JamDetector;
    fbKPIService            : FB_KPIService;
    fbAlarmManager          : FB_AlarmManager;
    fbHistorianConnector    : FB_HistorianConnector;

    // Typed module contracts. Keeping inputs/configs explicit makes each module unit-testable.
    stLineIn                : ST_LineSupervisorInput;
    stLineConfig            : ST_LineSupervisorConfig;
    stStationIn             : ST_StationControllerInput;
    stStationConfig         : ST_StationControllerConfig;
    stManual                : ST_ManualControl;
    stDiverter1In           : ST_DiverterControllerInput;
    stDiverter2In           : ST_DiverterControllerInput;
    stDiverter1Config       : ST_DiverterControllerConfig;
    stDiverter2Config       : ST_DiverterControllerConfig;
    stJamIn                 : ST_JamDetectorInput;
    stJamConfig             : ST_JamDetectorConfig;
    stKPIIn                 : ST_KPIServiceInput;
    stKPIConfig             : ST_KPIServiceConfig;
    stAlarmIn               : ST_AlarmManagerInput;
    stAlarmConfig           : ST_AlarmManagerConfig;
    stHistorianIn           : ST_HistorianConnectorInput;
    stHistorianConfig       : ST_HistorianConnectorConfig;
    stDiverter1Status       : ST_Diverter_Status;
    stDiverter2Status       : ST_Diverter_Status;

    // Debounced sensor path. Raw I/O is never consumed directly by sequencing logic.
    tonPE1Debounce          : TON;
    tonPE2Debounce          : TON;
    tonPE3Debounce          : TON;
    tonPE4Debounce          : TON;
    tonPE5Debounce          : TON;
    tonPE6Debounce          : TON;
    tSensorDebounce         : TIME := T#30MS;
    xPE1Debounced           : BOOL := FALSE;
    xPE2Debounced           : BOOL := FALSE;
    xPE3Debounced           : BOOL := FALSE;
    xPE4Debounced           : BOOL := FALSE;
    xPE5Debounced           : BOOL := FALSE;
    xPE6Debounced           : BOOL := FALSE;

    rCycleTime_s            : REAL := 0.05; // 50 ms PLC task contract.
    xConveyorRunCmd         : BOOL := FALSE;
END_VAR

// =========================================================
// 1. SENSOR DEBOUNCE
// =========================================================
tonPE1Debounce(IN := xPE1_Infeed, PT := tSensorDebounce);
tonPE2Debounce(IN := xPE2_ScannerTrigger, PT := tSensorDebounce);
tonPE3Debounce(IN := xPE3_DiverterApproach, PT := tSensorDebounce);
tonPE4Debounce(IN := xPE4_LaneAVerify, PT := tSensorDebounce);
tonPE5Debounce(IN := xPE5_LaneBVerify, PT := tSensorDebounce);
tonPE6Debounce(IN := xPE6_RejectVerify, PT := tSensorDebounce);
xPE1Debounced := tonPE1Debounce.Q;
xPE2Debounced := tonPE2Debounce.Q;
xPE3Debounced := tonPE3Debounce.Q;
xPE4Debounced := tonPE4Debounce.Q;
xPE5Debounced := tonPE5Debounce.Q;
xPE6Debounced := tonPE6Debounce.Q;

// =========================================================
// 2. CELL CONFIGURATION AND RECIPE BOOK
// =========================================================
stLineConfig.rDefaultTargetSpeed_mps := 0.50;
stLineConfig.rMinimumTargetSpeed_mps := 0.05;
stLineConfig.rMaximumTargetSpeed_mps := 1.50;
stLineConfig.uiRecipeCount := 3;
stLineConfig.sLaneAPattern := 'LANE-A';
stLineConfig.sLaneBPattern := 'LANE-B';
stLineConfig.sRejectPattern := 'REJECT';

stLineConfig.arrRecipeBook[1].uiRecipeID := 1;
stLineConfig.arrRecipeBook[1].xEnabled := TRUE;
stLineConfig.arrRecipeBook[1].sName := 'Default Sort';
stLineConfig.arrRecipeBook[1].rAutoSpeed_mps := 0.50;
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
stLineConfig.arrRecipeBook[2].sName := 'SKU Color Sort';
stLineConfig.arrRecipeBook[2].rAutoSpeed_mps := 0.60;
stLineConfig.arrRecipeBook[2].sLaneAPattern := 'RED';
stLineConfig.arrRecipeBook[2].sLaneBPattern := 'BLUE';
stLineConfig.arrRecipeBook[2].sRejectPattern := 'REJ';

stLineConfig.arrRecipeBook[3] := stLineConfig.arrRecipeBook[1];
stLineConfig.arrRecipeBook[3].uiRecipeID := 3;
stLineConfig.arrRecipeBook[3].sName := 'Fragile Slow Sort';
stLineConfig.arrRecipeBook[3].rAutoSpeed_mps := 0.30;
stLineConfig.arrRecipeBook[3].rManualMaxSpeed_mps := 0.25;
stLineConfig.arrRecipeBook[3].rMaintenanceSpeedLimit_mps := 0.10;
stLineConfig.arrRecipeBook[3].sLaneAPattern := 'FRAG-A';
stLineConfig.arrRecipeBook[3].sLaneBPattern := 'FRAG-B';
stLineConfig.arrRecipeBook[3].sRejectPattern := 'FRAG-R';

stStationConfig.rDefaultSpeed_mps := 0.50;
stStationConfig.rMinimumSpeed_mps := 0.05;
stStationConfig.rMaximumSpeed_mps := 1.50;
stStationConfig.rManualMaxSpeed_mps := 0.40;
stStationConfig.rMaintenanceMaxSpeed_mps := 0.15;
stStationConfig.rTransitionTimeout_s := 1.00;

stDiverter1Config.tActuatorName := 'Diverter 1';
stDiverter1Config.rExtendTimeout_s := 0.75;
stDiverter1Config.rRetractTimeout_s := 0.75;
stDiverter1Config.rWorkDwell_s := 0.15;
stDiverter1Config.rVerificationTimeout_s := 2.00;
stDiverter1Config.rManualHoldLimit_s := 2.00;
stDiverter1Config.xRequireHomeBeforeFire := TRUE;
stDiverter1Config.xRequireVerification := TRUE;
stDiverter2Config := stDiverter1Config;
stDiverter2Config.tActuatorName := 'Diverter 2';

stJamConfig.rReferenceSpeed_mps := 0.50;
stJamConfig.rBaseJamLimit_s := 3.00;
stJamConfig.rMaximumJamLimit_s := 8.00;
stJamConfig.rWarningRatio := 0.80;

stKPIConfig.rPerformanceFactor := 0.96;
stKPIConfig.rTargetRate_ppm := 60.0;
stKPIConfig.xUseRoutePulses := TRUE;

stAlarmConfig.rFlashPeriod_s := 0.50;

stHistorianConfig.tOpcUaNamespaceUri := 'urn:mhmc:runtime';
stHistorianConfig.rSamplePeriod_s := 1.00;
stHistorianConfig.rHeartbeatTimeout_s := 5.00;
stHistorianConfig.uiMaxMissedHeartbeats := 3;

// =========================================================
// 3. SUPERVISOR, MANUAL CONTRACT, AND JAM WATCHDOG
// =========================================================
stManual.xJogConveyorForward := xManualJogForward;
stManual.rJogSpeed_mps := rManualJogSpeed_mps;
stManual.xDiverter1Extend := xManualDiverter1Extend;
stManual.xDiverter2Extend := xManualDiverter2Extend;
stManual.xScannerTrigger := xManualScannerTrigger;
stManual.xResetJam := xManualResetJam OR xRemoteReset;
stManual.xResetCounters := xManualResetCounters;
stManual.xMaintenanceKey := xMaintenanceKey;

stLineIn.xStartCommand := xRemoteStart;
stLineIn.xStopCommand := xRemoteStop;
stLineIn.xResetCommand := xRemoteReset;
stLineIn.xHoldCommand := xRemoteHold;
stLineIn.xUnholdCommand := xRemoteUnhold;
stLineIn.xClearCommand := xRemoteClear;
stLineIn.xLoadRecipeCommand := xLoadRecipeCommand;
stLineIn.uiRecipeSelect := uiRecipeSelect;
stLineIn.rRecipeSpeed_mps := rRecipeSpeed_mps;
stLineIn.xUseRecipePayload := xUseRecipePayload;
stLineIn.stRecipePayload := stRecipePayload;
stLineIn.eModeSelect := eSelectedMode;
stLineIn.xOpcUaConnected := xOpcUaServerReady;
stLineIn.xStationReady := fbStationController.xInitialized OR fbStationController.stOut.xPermissivesOK;
fbLineSupervisor(stIn := stLineIn, stConfig := stLineConfig);

stJamIn.xRawPE1 := xPE1Debounced;
stJamIn.xRawPE2 := xPE2Debounced;
stJamIn.xRawPE3 := xPE3Debounced;
stJamIn.xConveyorRunning := fbConveyor.stStatus.xIsRunning;
stJamIn.rConveyorSpeed_mps := fbConveyor.stStatus.rSpeedFeedback;
stJamIn.xResetJam := stManual.xResetJam;
stJamIn.xRecoveryRequest := xRemoteUnhold;
stJamIn.xAllowAutoRecovery := fbStationController.stOut.xPermissivesOK;
stJamIn.ePackMLState := fbStationController.stOut.ePackMLState;
stJamIn.rCycleTime_s := rCycleTime_s;
fbJamDetector(stIn := stJamIn, stConfig := stJamConfig);

// =========================================================
// 4. PACKML STATION, CONVEYOR, ROUTING, AND DIVERTERS
// =========================================================
stStationIn.xStart := fbLineSupervisor.stOut.xStartCellPulse;
stStationIn.xStop := fbLineSupervisor.stOut.xStopCellPulse;
stStationIn.xReset := fbLineSupervisor.stOut.xResetCellPulse;
stStationIn.xHold := fbLineSupervisor.stOut.xHoldCell
                     OR fbJamDetector.stOut.xRequestHold
                     OR fbRouting.xRouteFault;
stStationIn.xUnhold := fbLineSupervisor.stOut.xUnholdCellPulse OR fbJamDetector.stOut.xResetAcceptedPulse;
stStationIn.xClear := fbLineSupervisor.stOut.xClearCellPulse;
stStationIn.eRequestedMode := fbLineSupervisor.stOut.eRequestedMode;
stStationIn.stRecipe := fbLineSupervisor.stOut.stActiveRecipe;
stStationIn.stManual := stManual;
stStationIn.rTargetSpeed_mps := fbLineSupervisor.stOut.rTargetSpeed_mps;
stStationIn.xSafetyLoopOK := xSafetyLoopOK;
stStationIn.xAirPressureOK := xAirPressureOK;
stStationIn.xVfdReady := xVfdReady AND NOT xVfdFault AND NOT fbConveyor.stStatus.xFaulted;
stStationIn.xDiverter1Faulted := fbDiverter1.stOut.xFaulted;
stStationIn.xDiverter2Faulted := fbDiverter2.stOut.xFaulted;
stStationIn.xJamAlarm := fbJamDetector.stOut.xJamAlarm OR fbConveyor.xJamAlarm;
stStationIn.xDownstreamBlocked := fbRouting.xRouteFault;
stStationIn.rCycleTime_s := rCycleTime_s;
fbStationController(stIn := stStationIn, stConfig := stStationConfig);

xConveyorRunCmd := fbStationController.stOut.xConveyorRunEnable
                   AND NOT fbStationController.stOut.xConveyorQuickStop
                   AND NOT fbRouting.xRouteFault
                   AND NOT fbJamDetector.stOut.xJamAlarm
                   AND NOT fbAlarmManager.stOut.xAnyAlarmActive;
fbConveyor(
    xRunCmd := xConveyorRunCmd,
    rCmdSpeed := fbStationController.stOut.rConveyorSpeed_mps,
    xRawPE1 := xPE1Debounced,
    xRawPE2 := xPE2Debounced,
    xRawPE3 := xPE3Debounced,
    tJamLimit := T#3S,
    xResetAlarms := fbStationController.stOut.xResetAlarms
);

fbRouting(
    xConveyorRunning := fbConveyor.stStatus.xIsRunning,
    rConveyorSpeed := fbConveyor.stStatus.rSpeedFeedback,
    sScannerString := sScannerData,
    xScannerReadSuccess := xScannerDataValid,
    xRawPE4 := xPE4Debounced,
    xRawPE5 := xPE5Debounced,
    xRawPE6 := xPE6Debounced,
    xResetAlarms := fbStationController.stOut.xResetAlarms,
    xPE1 := xPE1Debounced,
    xPE2 := xPE2Debounced,
    xPE3 := xPE3Debounced,
    tCycleTime := rCycleTime_s,
    eCurrentMode := fbStationController.stOut.eCurrentMode,
    stActiveRecipe := fbLineSupervisor.stOut.stActiveRecipe,
    stManual := stManual,
    xAutoEnable := fbStationController.stOut.xRunRouting,
    xMaintenanceSafeguardsOK := fbStationController.stOut.xMaintenanceSafe,
    xDiverter1Ready := xDivLaneA_HomeSensor AND NOT fbDiverter1.stOut.xBusy AND NOT fbDiverter1.stOut.xFaulted,
    xDiverter2Ready := xDivLaneB_HomeSensor AND NOT fbDiverter2.stOut.xBusy AND NOT fbDiverter2.stOut.xFaulted,
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
stDiverter1In.xForceRetract := fbStationController.stOut.xConveyorQuickStop
                               OR NOT fbStationController.stOut.xPermissivesOK;
stDiverter1In.xHomeSensor := xDivLaneA_HomeSensor;
stDiverter1In.xWorkSensor := xDivLaneA_WorkSensor;
stDiverter1In.xVerificationSensor := xPE4Debounced;
stDiverter1In.xResetFault := fbStationController.stOut.xResetAlarms;
stDiverter1In.rCycleTime_s := rCycleTime_s;
fbDiverter1(stIn := stDiverter1In, stConfig := stDiverter1Config);

stDiverter2In := stDiverter1In;
stDiverter2In.xExtendRequest := fbRouting.stDiverter2.xCommandExtend;
stDiverter2In.xManualExtend := fbStationController.stOut.xManualDivert2;
stDiverter2In.xHomeSensor := xDivLaneB_HomeSensor;
stDiverter2In.xWorkSensor := xDivLaneB_WorkSensor;
stDiverter2In.xVerificationSensor := xPE5Debounced;
fbDiverter2(stIn := stDiverter2In, stConfig := stDiverter2Config);

stDiverter1Status.xHomeSensor := fbDiverter1.stOut.xHome;
stDiverter1Status.xWorkSensor := fbDiverter1.stOut.xWork;
stDiverter1Status.xCommandExtend := fbDiverter1.stOut.xCommandExtend;
stDiverter1Status.xVerificationSensor := xPE4Debounced;
stDiverter1Status.xFaulted := fbDiverter1.stOut.xFaulted;
stDiverter2Status.xHomeSensor := fbDiverter2.stOut.xHome;
stDiverter2Status.xWorkSensor := fbDiverter2.stOut.xWork;
stDiverter2Status.xCommandExtend := fbDiverter2.stOut.xCommandExtend;
stDiverter2Status.xVerificationSensor := xPE5Debounced;
stDiverter2Status.xFaulted := fbDiverter2.stOut.xFaulted;

// =========================================================
// 5. KPI, ALARMS, HISTORIAN, AND SYMBOLIC OUTPUTS
// =========================================================
stKPIIn.xPE4LaneA := xPE4Debounced;
stKPIIn.xPE5LaneB := xPE5Debounced;
stKPIIn.xPE6Reject := xPE6Debounced;
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
stKPIIn.xResetCounters := stManual.xResetCounters;
stKPIIn.rCycleTime_s := rCycleTime_s;
fbKPIService(stIn := stKPIIn, stConfig := stKPIConfig);

stAlarmIn.xSafetyLoopOK := xSafetyLoopOK;
stAlarmIn.xAirPressureOK := xAirPressureOK;
stAlarmIn.xVfdFault := xVfdFault OR fbConveyor.stStatus.xFaulted;
stAlarmIn.xJamAlarm := fbJamDetector.stOut.xJamAlarm OR fbConveyor.xJamAlarm;
stAlarmIn.xJamWarning := fbJamDetector.stOut.xWarning;
stAlarmIn.xDiverter1Faulted := fbDiverter1.stOut.xFaulted;
stAlarmIn.xDiverter2Faulted := fbDiverter2.stOut.xFaulted;
stAlarmIn.xRouteFault := fbRouting.xRouteFault;
stAlarmIn.ePackMLState := fbStationController.stOut.ePackMLState;
stAlarmIn.eCurrentMode := fbStationController.stOut.eCurrentMode;
stAlarmIn.xAcknowledge := xAlarmAcknowledge;
stAlarmIn.xReset := fbStationController.stOut.xResetAlarms;
stAlarmIn.rCycleTime_s := rCycleTime_s;
fbAlarmManager(stIn := stAlarmIn, stConfig := stAlarmConfig);

stHistorianIn.xEnable := xHistorianEnable;
stHistorianIn.xOpcUaServerReady := xOpcUaServerReady;
stHistorianIn.xCollectorHeartbeat := xCollectorHeartbeat;
stHistorianIn.xLastWriteOK := xHistorianLastWriteOK;
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
stHistorianIn.stTimeline := fbAlarmManager.stOut.stTimeline;
stHistorianIn.rCycleTime_s := rCycleTime_s;
fbHistorianConnector(stIn := stHistorianIn, stConfig := stHistorianConfig);

xVfdRunCmd := xConveyorRunCmd;
rVfdSpeedCmd := fbStationController.stOut.rConveyorSpeed_mps;
xSolDiverter1Extend := fbDiverter1.stOut.xCommandExtend;
xSolDiverter2Extend := fbDiverter2.stOut.xCommandExtend;
xScannerTriggerCommand := fbRouting.xScannerTriggerPulse OR fbStationController.stOut.xScannerTrigger;
xStackGreen := fbAlarmManager.stOut.xStackGreen;
xStackYellow := fbAlarmManager.stOut.xStackYellow;
xStackRed := fbAlarmManager.stOut.xStackRed;
xSounder := fbAlarmManager.stOut.xSounder;

xPermissivesOK := fbStationController.stOut.xPermissivesOK;
rTargetConveyorSpeed := fbStationController.stOut.rConveyorSpeed_mps;
uiJamEventCounter := fbJamDetector.stOut.uiTotalJams;
rAvailability := fbKPIService.stOut.rAvailability;
rPerformance := fbKPIService.stOut.rPerformance;
rQuality := fbKPIService.stOut.rQuality;
rOEEPercentage := fbKPIService.stOut.rOEE_percent;
stEventTimeline := fbAlarmManager.stOut.stTimeline;

uiHeartbeat := uiHeartbeat + 1;
IF uiHeartbeat > 9999 THEN
    uiHeartbeat := 0;
END_IF;

END_PROGRAM

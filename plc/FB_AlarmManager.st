// ==========================================
// ALARM MANAGER MODULE FOR MHMC-01
// File: FB_AlarmManager.st
// Standard: IEC 61131-3 Structured Text
// Purpose: Alarm categorisation, acknowledgement, and stack light control.
// ==========================================

TYPE E_AlarmManagerState :
(
    ALARM_MGR_UNINITIALISED := 0,
    ALARM_MGR_NORMAL        := 10,
    ALARM_MGR_WARNING       := 20,
    ALARM_MGR_FAULT         := 30,
    ALARM_MGR_ABORT         := 900
) INT;
END_TYPE

TYPE ST_AlarmManagerConfig :
STRUCT
    rFlashPeriod_s : REAL; // Stack light flash interval.
END_STRUCT
END_TYPE

TYPE ST_AlarmManagerInput :
STRUCT
    xSafetyLoopOK       : BOOL;          // Safety relay input.
    xAirPressureOK      : BOOL;          // Pneumatic pressure healthy.
    xVfdFault           : BOOL;          // Conveyor drive fault.
    xJamAlarm           : BOOL;          // Jam detector alarm.
    xJamWarning         : BOOL;          // Jam detector pre-alarm.
    xDiverter1Faulted   : BOOL;          // Diverter 1 fault.
    xDiverter2Faulted   : BOOL;          // Diverter 2 fault.
    xRouteFault         : BOOL;          // Routing/misroute/queue fault.
    ePackMLState        : E_PackML_State; // Station state for light logic.
    eCurrentMode        : E_PackML_Mode;  // Current station mode for event context.
    xAcknowledge        : BOOL;          // HMI/SCADA alarm acknowledge.
    xReset              : BOOL;          // Alarm reset when root cause clear.
    rCycleTime_s        : REAL;          // PLC task interval for tests.
END_STRUCT
END_TYPE

TYPE ST_AlarmManagerOutput :
STRUCT
    xAnyAlarmActive     : BOOL;          // Aggregate active alarm.
    xAnyUnacked         : BOOL;          // Active or latched unacknowledged alarm.
    eActiveAlarmCode    : E_MHMCAlarmCode; // Highest-priority active alarm.
    uiActiveAlarmCode   : UINT;          // Numeric alarm code for OPC UA/event payloads.
    uiSeverity          : UINT;          // OPC UA AlarmCondition severity 1..1000.
    xGeneralJamAlarm    : BOOL;          // OPC UA GeneralJamAlarm active state.
    xDiverter1Alarm     : BOOL;          // OPC UA Diverter1Fault active state.
    xDiverter2Alarm     : BOOL;          // OPC UA Diverter2Fault active state.
    xEStopAlarm         : BOOL;          // OPC UA EStopTripped active state.
    xStackGreen         : BOOL;          // Run indicator.
    xStackYellow        : BOOL;          // Warning/held indicator.
    xStackRed           : BOOL;          // Abort/fault indicator.
    xSounder            : BOOL;          // Audible alarm output.
    sActiveMessage      : STRING(80);    // Alarm text for SCADA.
    stTimeline          : ST_MHMCEventTimeline; // Alarm/event timeline ring buffer.
END_STRUCT
END_TYPE

TYPE ST_AlarmManagerContext :
STRUCT
    eState          : E_AlarmManagerState;
    xInitialized    : BOOL;
    xAckLatched     : BOOL;
    xAlarmActiveLast: BOOL;
    xAckLast        : BOOL;
    xResetLast      : BOOL;
    xFlashState     : BOOL;
    rFlashElapsed_s : REAL;
    rRuntime_s      : REAL;
    eLastAlarmCode  : E_MHMCAlarmCode;
END_STRUCT
END_TYPE

FUNCTION F_AlarmManager_Init : BOOL
VAR_INPUT
    stConfig : ST_AlarmManagerConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_AlarmManagerContext;
    stOut     : ST_AlarmManagerOutput;
END_VAR

// Initialisation function. Clears latched acknowledgement and drives indicators safe.
stContext.eState := E_AlarmManagerState.ALARM_MGR_NORMAL;
stContext.xInitialized := TRUE;
stContext.xAckLatched := FALSE;
stContext.xAlarmActiveLast := FALSE;
stContext.xAckLast := FALSE;
stContext.xResetLast := FALSE;
stContext.xFlashState := FALSE;
stContext.rFlashElapsed_s := 0.0;
stContext.rRuntime_s := 0.0;
stContext.eLastAlarmCode := E_MHMCAlarmCode.ALARM_NONE;

stOut.xAnyAlarmActive := FALSE;
stOut.xAnyUnacked := FALSE;
stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_NONE;
stOut.uiActiveAlarmCode := 0;
stOut.uiSeverity := 0;
stOut.xGeneralJamAlarm := FALSE;
stOut.xDiverter1Alarm := FALSE;
stOut.xDiverter2Alarm := FALSE;
stOut.xEStopAlarm := FALSE;
stOut.xStackGreen := FALSE;
stOut.xStackYellow := FALSE;
stOut.xStackRed := FALSE;
stOut.xSounder := FALSE;
stOut.sActiveMessage := 'Alarm manager initialised';
F_EventTimeline_Clear(stTimeline := stOut.stTimeline);

F_AlarmManager_Init := TRUE;
END_FUNCTION

FUNCTION F_AlarmManager_Cyclic : BOOL
VAR_INPUT
    stIn     : ST_AlarmManagerInput;
    stConfig : ST_AlarmManagerConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_AlarmManagerContext;
    stOut     : ST_AlarmManagerOutput;
END_VAR

// Cyclic execution function. Highest severity wins; acknowledgement is separated from reset.
stOut.stTimeline.xNewEvent := FALSE;
stContext.rRuntime_s := stContext.rRuntime_s + stIn.rCycleTime_s;
stContext.rFlashElapsed_s := stContext.rFlashElapsed_s + stIn.rCycleTime_s;
IF stContext.rFlashElapsed_s >= stConfig.rFlashPeriod_s THEN
    stContext.xFlashState := NOT stContext.xFlashState;
    stContext.rFlashElapsed_s := 0.0;
END_IF;

stOut.xGeneralJamAlarm := stIn.xJamAlarm;
stOut.xDiverter1Alarm := stIn.xDiverter1Faulted;
stOut.xDiverter2Alarm := stIn.xDiverter2Faulted;
stOut.xEStopAlarm := NOT stIn.xSafetyLoopOK;
stOut.xAnyAlarmActive := stOut.xGeneralJamAlarm
                         OR stOut.xDiverter1Alarm
                         OR stOut.xDiverter2Alarm
                         OR stOut.xEStopAlarm
                         OR stIn.xRouteFault
                         OR stIn.xVfdFault
                         OR NOT stIn.xAirPressureOK;

IF stIn.xAcknowledge THEN
    stContext.xAckLatched := TRUE;
END_IF;
IF stIn.xReset AND NOT stOut.xAnyAlarmActive THEN
    stContext.xAckLatched := FALSE;
END_IF;

IF NOT stContext.xInitialized THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_UNINITIALISED;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_NONE;
    stOut.uiActiveAlarmCode := 0;
    stOut.uiSeverity := 0;
    stOut.sActiveMessage := 'Alarm manager not initialised';
ELSIF NOT stIn.xSafetyLoopOK THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_ABORT;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_ESTOP;
    stOut.uiActiveAlarmCode := 1000;
    stOut.uiSeverity := 1000;
    stOut.sActiveMessage := 'Emergency stop circuit tripped';
ELSIF stIn.xDiverter1Faulted THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_FAULT;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_DIVERTER_1;
    stOut.uiActiveAlarmCode := 200;
    stOut.uiSeverity := 900;
    stOut.sActiveMessage := 'Diverter 1 pneumatic actuator fault';
ELSIF stIn.xDiverter2Faulted THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_FAULT;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_DIVERTER_2;
    stOut.uiActiveAlarmCode := 210;
    stOut.uiSeverity := 900;
    stOut.sActiveMessage := 'Diverter 2 pneumatic actuator fault';
ELSIF stIn.xRouteFault THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_FAULT;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_ROUTE_FAULT;
    stOut.uiActiveAlarmCode := 250;
    stOut.uiSeverity := 850;
    stOut.sActiveMessage := 'Routing verification or FIFO fault active';
ELSIF stIn.xJamAlarm THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_FAULT;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_GENERAL_JAM;
    stOut.uiActiveAlarmCode := 100;
    stOut.uiSeverity := 800;
    stOut.sActiveMessage := 'Package jam detected on main conveyor';
ELSIF NOT stIn.xAirPressureOK THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_FAULT;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_AIR_PRESSURE;
    stOut.uiActiveAlarmCode := 300;
    stOut.uiSeverity := 700;
    stOut.sActiveMessage := 'Pneumatic pressure below permissive threshold';
ELSIF stIn.xVfdFault THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_FAULT;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_VFD_FAULT;
    stOut.uiActiveAlarmCode := 400;
    stOut.uiSeverity := 700;
    stOut.sActiveMessage := 'Conveyor VFD fault active';
ELSIF stIn.xJamWarning OR (stIn.ePackMLState = E_PackML_State.HELD) THEN
    stContext.eState := E_AlarmManagerState.ALARM_MGR_WARNING;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_NONE;
    stOut.uiActiveAlarmCode := 0;
    stOut.uiSeverity := 300;
    stOut.sActiveMessage := 'Cell warning or held state active';
ELSE
    stContext.eState := E_AlarmManagerState.ALARM_MGR_NORMAL;
    stOut.eActiveAlarmCode := E_MHMCAlarmCode.ALARM_NONE;
    stOut.uiActiveAlarmCode := 0;
    stOut.uiSeverity := 0;
    stOut.sActiveMessage := 'No active alarms';
END_IF;

stOut.xAnyUnacked := stOut.xAnyAlarmActive AND NOT stContext.xAckLatched;
stOut.xStackGreen := (stIn.ePackMLState = E_PackML_State.EXECUTE) AND NOT stOut.xAnyAlarmActive;
stOut.xStackYellow := stContext.xFlashState
                      AND ((stContext.eState = E_AlarmManagerState.ALARM_MGR_WARNING)
                           OR stIn.xJamWarning
                           OR stIn.xJamAlarm);
stOut.xStackRed := stOut.xEStopAlarm
                   OR (stContext.eState = E_AlarmManagerState.ALARM_MGR_FAULT)
                   OR (stContext.eState = E_AlarmManagerState.ALARM_MGR_ABORT);
stOut.xSounder := stOut.xAnyUnacked AND (stOut.uiSeverity >= 800);

// Event logging: log alarm raise/change, clear, acknowledge, and reset as deterministic ring-buffer records.
IF stOut.xAnyAlarmActive AND ((stOut.eActiveAlarmCode <> stContext.eLastAlarmCode) OR NOT stContext.xAlarmActiveLast) THEN
    F_EventTimeline_Append(
        rTimestamp_s := stContext.rRuntime_s,
        eClass := E_MHMCEventClass.EVENT_ALARM,
        uiCode := stOut.uiActiveAlarmCode,
        uiSeverity := stOut.uiSeverity,
        ePackMLState := stIn.ePackMLState,
        eMode := stIn.eCurrentMode,
        udiPackageID := 0,
        eRouteTarget := E_RouteTarget.ROUTE_NONE,
        sMessage := stOut.sActiveMessage,
        stTimeline := stOut.stTimeline
    );
ELSIF (NOT stOut.xAnyAlarmActive) AND stContext.xAlarmActiveLast THEN
    F_EventTimeline_Append(
        rTimestamp_s := stContext.rRuntime_s,
        eClass := E_MHMCEventClass.EVENT_RECOVERY,
        uiCode := 0,
        uiSeverity := 0,
        ePackMLState := stIn.ePackMLState,
        eMode := stIn.eCurrentMode,
        udiPackageID := 0,
        eRouteTarget := E_RouteTarget.ROUTE_NONE,
        sMessage := 'Alarm state cleared',
        stTimeline := stOut.stTimeline
    );
END_IF;

IF stIn.xAcknowledge AND NOT stContext.xAckLast THEN
    F_EventTimeline_Append(
        rTimestamp_s := stContext.rRuntime_s,
        eClass := E_MHMCEventClass.EVENT_COMMAND,
        uiCode := 1,
        uiSeverity := 0,
        ePackMLState := stIn.ePackMLState,
        eMode := stIn.eCurrentMode,
        udiPackageID := 0,
        eRouteTarget := E_RouteTarget.ROUTE_NONE,
        sMessage := 'Alarm acknowledged',
        stTimeline := stOut.stTimeline
    );
END_IF;

IF stIn.xReset AND NOT stContext.xResetLast THEN
    F_EventTimeline_Append(
        rTimestamp_s := stContext.rRuntime_s,
        eClass := E_MHMCEventClass.EVENT_RECOVERY,
        uiCode := 2,
        uiSeverity := 0,
        ePackMLState := stIn.ePackMLState,
        eMode := stIn.eCurrentMode,
        udiPackageID := 0,
        eRouteTarget := E_RouteTarget.ROUTE_NONE,
        sMessage := 'Alarm reset requested',
        stTimeline := stOut.stTimeline
    );
END_IF;

stContext.eLastAlarmCode := stOut.eActiveAlarmCode;
stContext.xAlarmActiveLast := stOut.xAnyAlarmActive;
stContext.xAckLast := stIn.xAcknowledge;
stContext.xResetLast := stIn.xReset;

F_AlarmManager_Cyclic := stContext.xInitialized;
END_FUNCTION

FUNCTION_BLOCK FB_AlarmManager
VAR_INPUT
    stIn     : ST_AlarmManagerInput;  // Typed symbolic inputs.
    stConfig : ST_AlarmManagerConfig; // Testable alarm configuration.
    xInit    : BOOL;                  // Pulse to re-run initialisation.
END_VAR
VAR_OUTPUT
    stOut        : ST_AlarmManagerOutput; // Typed symbolic outputs.
    eState       : E_AlarmManagerState;   // Exposed module state.
    xInitialized : BOOL;                  // Module initialisation complete.
END_VAR
VAR
    stContext : ST_AlarmManagerContext;
    xInitLast : BOOL;
END_VAR

IF (NOT stContext.xInitialized) OR (xInit AND NOT xInitLast) THEN
    F_AlarmManager_Init(stConfig := stConfig, stContext := stContext, stOut := stOut);
END_IF;

F_AlarmManager_Cyclic(stIn := stIn, stConfig := stConfig, stContext := stContext, stOut := stOut);

eState := stContext.eState;
xInitialized := stContext.xInitialized;
xInitLast := xInit;
END_FUNCTION_BLOCK

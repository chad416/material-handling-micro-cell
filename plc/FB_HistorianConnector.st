// ==========================================
// HISTORIAN CONNECTOR MODULE FOR MHMC-01
// File: FB_HistorianConnector.st
// Standard: IEC 61131-3 Structured Text
// Purpose: PLC-side historian publish health and sampling handshake skeleton.
// ==========================================

TYPE E_HistorianConnectorState :
(
    HIST_UNINITIALISED := 0,
    HIST_DISABLED      := 10,
    HIST_CONNECTING    := 20,
    HIST_CONNECTED     := 30,
    HIST_PUBLISHING    := 40,
    HIST_BACKOFF       := 50,
    HIST_FAULTED       := 900
) INT;
END_TYPE

TYPE ST_HistorianConnectorConfig :
STRUCT
    tOpcUaNamespaceUri      : STRING(120); // Namespace URI, not an address binding.
    rSamplePeriod_s         : REAL;        // Historian sample strobe period.
    rHeartbeatTimeout_s     : REAL;        // Max time without collector heartbeat.
    uiMaxMissedHeartbeats   : UINT;        // Fault threshold.
END_STRUCT
END_TYPE

TYPE ST_HistorianConnectorInput :
STRUCT
    xEnable              : BOOL;               // Enable historian handshake.
    xOpcUaServerReady    : BOOL;               // OPC UA server namespace ready.
    xCollectorHeartbeat  : BOOL;               // Telegraf/collector heartbeat bit.
    xLastWriteOK         : BOOL;               // Influx write success from collector.
    stConveyor           : ST_Conveyor_Status; // Conveyor telemetry source.
    stDiverter1          : ST_Diverter_Status; // Diverter 1 telemetry source.
    stDiverter2          : ST_Diverter_Status; // Diverter 2 telemetry source.
    udiTotalCount        : UDINT;              // KPI source.
    udiLaneACount        : UDINT;              // KPI source.
    udiLaneBCount        : UDINT;              // KPI source.
    udiRejectCount       : UDINT;              // KPI source.
    uiTotalJams          : UINT;               // KPI source.
    rOEE_percent         : REAL;               // KPI source.
    xActiveAlarm         : BOOL;               // Alarm/event source.
    sActiveAlarmMessage  : STRING(80);         // Alarm/event source.
    stTimeline           : ST_MHMCEventTimeline; // Event timeline from AlarmManager.
    rCycleTime_s         : REAL;               // PLC task interval for tests.
END_STRUCT
END_TYPE

TYPE ST_HistorianConnectorOutput :
STRUCT
    xSubscribeEnable      : BOOL;       // Allows collector to subscribe/poll OPC UA.
    xSampleStrobe         : BOOL;       // One-cycle sample request.
    xHistorianHealthy     : BOOL;       // True when OPC UA and collector are healthy.
    xPublishConveyor      : BOOL;       // Sample conveyor_telemetry.
    xPublishDiverter      : BOOL;       // Sample diverter_telemetry.
    xPublishKPI           : BOOL;       // Sample cell_kpis.
    xPublishAlarm         : BOOL;       // Sample alarms_events.
    xPublishEvent         : BOOL;       // Publish one newly appended timeline event.
    uiMissedHeartbeats    : UINT;       // Collector heartbeat misses.
    sNamespaceUri         : STRING(120); // OPC UA namespace exposed to collector.
    sMeasurementClass     : STRING(40);  // Current logical measurement group.
    sLineProtocolPayload  : STRING(255); // Skeleton payload contract for collector tests.
    stLastEvent           : ST_MHMCEventRecord; // Last event for OPC UA/Influx mapping.
    sStatusText           : STRING(80);
END_STRUCT
END_TYPE

TYPE ST_HistorianConnectorContext :
STRUCT
    eState             : E_HistorianConnectorState;
    xInitialized       : BOOL;
    xHeartbeatLast     : BOOL;
    rSampleElapsed_s   : REAL;
    rHeartbeatElapsed_s: REAL;
    udiLastEventSequence : UDINT;
END_STRUCT
END_TYPE

FUNCTION F_HistorianConnector_Init : BOOL
VAR_INPUT
    stConfig : ST_HistorianConnectorConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_HistorianConnectorContext;
    stOut     : ST_HistorianConnectorOutput;
END_VAR

// Initialisation function. The actual OPC UA/Influx endpoints remain external configuration.
stContext.eState := E_HistorianConnectorState.HIST_DISABLED;
stContext.xInitialized := TRUE;
stContext.xHeartbeatLast := FALSE;
stContext.rSampleElapsed_s := 0.0;
stContext.rHeartbeatElapsed_s := 0.0;
stContext.udiLastEventSequence := 0;

stOut.xSubscribeEnable := FALSE;
stOut.xSampleStrobe := FALSE;
stOut.xHistorianHealthy := FALSE;
stOut.xPublishConveyor := FALSE;
stOut.xPublishDiverter := FALSE;
stOut.xPublishKPI := FALSE;
stOut.xPublishAlarm := FALSE;
stOut.xPublishEvent := FALSE;
stOut.uiMissedHeartbeats := 0;
stOut.sNamespaceUri := stConfig.tOpcUaNamespaceUri;
stOut.sMeasurementClass := 'none';
stOut.sLineProtocolPayload := '';
stOut.sStatusText := 'Historian connector initialised';

F_HistorianConnector_Init := TRUE;
END_FUNCTION

FUNCTION F_HistorianConnector_Cyclic : BOOL
VAR_INPUT
    stIn     : ST_HistorianConnectorInput;
    stConfig : ST_HistorianConnectorConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_HistorianConnectorContext;
    stOut     : ST_HistorianConnectorOutput;
END_VAR
VAR
    xHeartbeatEdge : BOOL;
    xNewTimelineEvent : BOOL;
END_VAR

// Cyclic execution function. Provides deterministic sample strobes for Telegraf/SCADA.
stOut.xSampleStrobe := FALSE;
stOut.xPublishConveyor := FALSE;
stOut.xPublishDiverter := FALSE;
stOut.xPublishKPI := FALSE;
stOut.xPublishAlarm := FALSE;
stOut.xPublishEvent := FALSE;
stOut.sNamespaceUri := stConfig.tOpcUaNamespaceUri;
stOut.stLastEvent := stIn.stTimeline.stLastEvent;

xHeartbeatEdge := stIn.xCollectorHeartbeat <> stContext.xHeartbeatLast;
xNewTimelineEvent := stIn.stTimeline.stLastEvent.xActive
                     AND (stIn.stTimeline.stLastEvent.udiSequence <> stContext.udiLastEventSequence);

IF xHeartbeatEdge THEN
    stContext.rHeartbeatElapsed_s := 0.0;
    stOut.uiMissedHeartbeats := 0;
ELSE
    stContext.rHeartbeatElapsed_s := stContext.rHeartbeatElapsed_s + stIn.rCycleTime_s;
END_IF;

IF stContext.rHeartbeatElapsed_s >= stConfig.rHeartbeatTimeout_s THEN
    stOut.uiMissedHeartbeats := stOut.uiMissedHeartbeats + 1;
    stContext.rHeartbeatElapsed_s := 0.0;
END_IF;

IF NOT stContext.xInitialized THEN
    stContext.eState := E_HistorianConnectorState.HIST_UNINITIALISED;
ELSIF NOT stIn.xEnable THEN
    stContext.eState := E_HistorianConnectorState.HIST_DISABLED;
ELSIF NOT stIn.xOpcUaServerReady THEN
    stContext.eState := E_HistorianConnectorState.HIST_CONNECTING;
ELSIF stOut.uiMissedHeartbeats >= stConfig.uiMaxMissedHeartbeats THEN
    stContext.eState := E_HistorianConnectorState.HIST_BACKOFF;
ELSIF NOT stIn.xLastWriteOK THEN
    stContext.eState := E_HistorianConnectorState.HIST_FAULTED;
ELSE
    stContext.eState := E_HistorianConnectorState.HIST_CONNECTED;
END_IF;

stOut.xSubscribeEnable := stIn.xEnable AND stIn.xOpcUaServerReady;
stOut.xHistorianHealthy := stOut.xSubscribeEnable
                           AND (stOut.uiMissedHeartbeats < stConfig.uiMaxMissedHeartbeats)
                           AND stIn.xLastWriteOK;

IF stOut.xHistorianHealthy THEN
    stContext.rSampleElapsed_s := stContext.rSampleElapsed_s + stIn.rCycleTime_s;
    IF stContext.rSampleElapsed_s >= stConfig.rSamplePeriod_s THEN
        stContext.rSampleElapsed_s := 0.0;
        stContext.eState := E_HistorianConnectorState.HIST_PUBLISHING;
        stOut.xSampleStrobe := TRUE;
        stOut.xPublishConveyor := TRUE;
        stOut.xPublishDiverter := TRUE;
        stOut.xPublishKPI := TRUE;
        stOut.xPublishAlarm := stIn.xActiveAlarm;
    END_IF;
    IF xNewTimelineEvent THEN
        stOut.xPublishEvent := TRUE;
        stContext.udiLastEventSequence := stIn.stTimeline.stLastEvent.udiSequence;
    END_IF;
END_IF;

IF stOut.xPublishEvent THEN
    stOut.sMeasurementClass := 'event_timeline';
    stOut.sLineProtocolPayload := 'event_timeline new_event=true';
ELSIF stOut.xPublishAlarm THEN
    stOut.sMeasurementClass := 'alarms_events';
    stOut.sLineProtocolPayload := 'alarms_events active=true';
ELSIF stOut.xPublishKPI THEN
    stOut.sMeasurementClass := 'cell_kpis';
    stOut.sLineProtocolPayload := 'cell_kpis sample=true';
ELSIF stOut.xPublishDiverter THEN
    stOut.sMeasurementClass := 'diverter_telemetry';
    stOut.sLineProtocolPayload := 'diverter_telemetry sample=true';
ELSIF stOut.xPublishConveyor THEN
    stOut.sMeasurementClass := 'conveyor_telemetry';
    stOut.sLineProtocolPayload := 'conveyor_telemetry sample=true';
ELSE
    stOut.sMeasurementClass := 'idle';
    stOut.sLineProtocolPayload := '';
END_IF;

IF stOut.xHistorianHealthy THEN
    stOut.sStatusText := 'Historian connector healthy';
ELSE
    stOut.sStatusText := 'Historian connector waiting for healthy collector';
END_IF;

stContext.xHeartbeatLast := stIn.xCollectorHeartbeat;
F_HistorianConnector_Cyclic := stContext.xInitialized;
END_FUNCTION

FUNCTION_BLOCK FB_HistorianConnector
VAR_INPUT
    stIn     : ST_HistorianConnectorInput;  // Typed symbolic inputs.
    stConfig : ST_HistorianConnectorConfig; // Testable historian configuration.
    xInit    : BOOL;                        // Pulse to re-run initialisation.
END_VAR
VAR_OUTPUT
    stOut        : ST_HistorianConnectorOutput; // Typed symbolic outputs.
    eState       : E_HistorianConnectorState;   // Exposed module state.
    xInitialized : BOOL;                        // Module initialisation complete.
END_VAR
VAR
    stContext : ST_HistorianConnectorContext;
    xInitLast : BOOL;
END_VAR

IF (NOT stContext.xInitialized) OR (xInit AND NOT xInitLast) THEN
    F_HistorianConnector_Init(stConfig := stConfig, stContext := stContext, stOut := stOut);
END_IF;

F_HistorianConnector_Cyclic(stIn := stIn, stConfig := stConfig, stContext := stContext, stOut := stOut);

eState := stContext.eState;
xInitialized := stContext.xInitialized;
xInitLast := xInit;
END_FUNCTION_BLOCK

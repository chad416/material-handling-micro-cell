// ==========================================
// EVENT TIMELINE HELPERS FOR MHMC-01
// File: F_EventTimeline.st
// Standard: IEC 61131-3 Structured Text
// Purpose: Deterministic fixed-size event ring buffer utilities.
// ==========================================

FUNCTION F_EventTimeline_Clear : BOOL
VAR_IN_OUT
    stTimeline : ST_MHMCEventTimeline;
END_VAR
VAR
    i : INT;
END_VAR

// Clear all event slots. Used on cold initialisation or explicit engineering reset.
FOR i := 1 TO 50 DO
    stTimeline.arrEvents[i].xActive := FALSE;
    stTimeline.arrEvents[i].xAcknowledged := FALSE;
    stTimeline.arrEvents[i].udiSequence := 0;
    stTimeline.arrEvents[i].rTimestamp_s := 0.0;
    stTimeline.arrEvents[i].eClass := E_MHMCEventClass.EVENT_INFO;
    stTimeline.arrEvents[i].uiCode := 0;
    stTimeline.arrEvents[i].uiSeverity := 0;
    stTimeline.arrEvents[i].ePackMLState := E_PackML_State.STOPPED;
    stTimeline.arrEvents[i].eMode := E_PackML_Mode.AUTO;
    stTimeline.arrEvents[i].udiPackageID := 0;
    stTimeline.arrEvents[i].eRouteTarget := E_RouteTarget.ROUTE_NONE;
    stTimeline.arrEvents[i].sMessage := '';
END_FOR;

stTimeline.iWriteIndex := 1;
stTimeline.iCount := 0;
stTimeline.udiNextSequence := 1;
stTimeline.xNewEvent := FALSE;
stTimeline.stLastEvent.xActive := FALSE;
stTimeline.stLastEvent.xAcknowledged := FALSE;
stTimeline.stLastEvent.udiSequence := 0;
stTimeline.stLastEvent.rTimestamp_s := 0.0;
stTimeline.stLastEvent.eClass := E_MHMCEventClass.EVENT_INFO;
stTimeline.stLastEvent.uiCode := 0;
stTimeline.stLastEvent.uiSeverity := 0;
stTimeline.stLastEvent.ePackMLState := E_PackML_State.STOPPED;
stTimeline.stLastEvent.eMode := E_PackML_Mode.AUTO;
stTimeline.stLastEvent.udiPackageID := 0;
stTimeline.stLastEvent.eRouteTarget := E_RouteTarget.ROUTE_NONE;
stTimeline.stLastEvent.sMessage := '';

F_EventTimeline_Clear := TRUE;
END_FUNCTION

FUNCTION F_EventTimeline_Append : BOOL
VAR_INPUT
    rTimestamp_s : REAL;
    eClass       : E_MHMCEventClass;
    uiCode       : UINT;
    uiSeverity   : UINT;
    ePackMLState : E_PackML_State;
    eMode        : E_PackML_Mode;
    udiPackageID : UDINT;
    eRouteTarget : E_RouteTarget;
    sMessage     : STRING(120);
END_VAR
VAR_IN_OUT
    stTimeline : ST_MHMCEventTimeline;
END_VAR
VAR
    iIndex : INT;
END_VAR

// Append one event into a fixed ring buffer. No dynamic memory, no file I/O, deterministic scan time.
IF (stTimeline.iWriteIndex < 1) OR (stTimeline.iWriteIndex > 50) THEN
    stTimeline.iWriteIndex := 1;
END_IF;
IF stTimeline.udiNextSequence = 0 THEN
    stTimeline.udiNextSequence := 1;
END_IF;

iIndex := stTimeline.iWriteIndex;

stTimeline.arrEvents[iIndex].xActive := TRUE;
stTimeline.arrEvents[iIndex].xAcknowledged := FALSE;
stTimeline.arrEvents[iIndex].udiSequence := stTimeline.udiNextSequence;
stTimeline.arrEvents[iIndex].rTimestamp_s := rTimestamp_s;
stTimeline.arrEvents[iIndex].eClass := eClass;
stTimeline.arrEvents[iIndex].uiCode := uiCode;
stTimeline.arrEvents[iIndex].uiSeverity := uiSeverity;
stTimeline.arrEvents[iIndex].ePackMLState := ePackMLState;
stTimeline.arrEvents[iIndex].eMode := eMode;
stTimeline.arrEvents[iIndex].udiPackageID := udiPackageID;
stTimeline.arrEvents[iIndex].eRouteTarget := eRouteTarget;
stTimeline.arrEvents[iIndex].sMessage := sMessage;

stTimeline.stLastEvent := stTimeline.arrEvents[iIndex];
stTimeline.xNewEvent := TRUE;
stTimeline.udiNextSequence := stTimeline.udiNextSequence + 1;

IF stTimeline.iCount < 50 THEN
    stTimeline.iCount := stTimeline.iCount + 1;
END_IF;

IF stTimeline.iWriteIndex >= 50 THEN
    stTimeline.iWriteIndex := 1;
ELSE
    stTimeline.iWriteIndex := stTimeline.iWriteIndex + 1;
END_IF;

F_EventTimeline_Append := TRUE;
END_FUNCTION


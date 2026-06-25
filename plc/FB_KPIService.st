// ==========================================
// KPI SERVICE MODULE FOR MHMC-01
// File: FB_KPIService.st
// Standard: IEC 61131-3 Structured Text
// Purpose: Throughput counters and OEE calculation skeleton.
// ==========================================

TYPE E_KPIServiceState :
(
    KPI_UNINITIALISED := 0,
    KPI_IDLE          := 10,
    KPI_ACCUMULATING  := 20,
    KPI_HELD          := 30,
    KPI_RESETTING     := 40
) INT;
END_TYPE

TYPE ST_KPIServiceConfig :
STRUCT
    rPerformanceFactor : REAL; // FDS target sorting velocity efficiency, e.g. 0.96.
    rTargetRate_ppm    : REAL; // Target packages per minute for throughput trending.
    xUseRoutePulses    : BOOL; // TRUE uses route verified pulses instead of raw PE edges.
END_STRUCT
END_TYPE

TYPE ST_KPIServiceInput :
STRUCT
    xPE4LaneA        : BOOL;          // Lane A verification sensor.
    xPE5LaneB        : BOOL;          // Lane B verification sensor.
    xPE6Reject       : BOOL;          // Reject verification sensor.
    xLaneAVerifiedPulse : BOOL;       // Route module verified Lane A package.
    xLaneBVerifiedPulse : BOOL;       // Route module verified Lane B package.
    xRejectVerifiedPulse: BOOL;       // Route module verified reject package.
    xPackageRegisteredPulse : BOOL;   // Package entered FIFO.
    xScanGoodPulse    : BOOL;         // Scanner returned a valid barcode.
    xScanBadPulse     : BOOL;         // Scanner failed or forced reject.
    ePackMLState     : E_PackML_State; // Station state for availability.
    xFaultDowntime   : BOOL;          // Fault/held downtime active.
    xResetCounters   : BOOL;          // KPI reset command.
    rCycleTime_s     : REAL;          // PLC task interval for tests.
END_STRUCT
END_TYPE

TYPE ST_KPIServiceOutput :
STRUCT
    udiTotalPackages     : UDINT; // Total package count.
    udiLaneAPackages     : UDINT; // Lane A count.
    udiLaneBPackages     : UDINT; // Lane B count.
    udiRejectPackages    : UDINT; // Reject count.
    udiRegisteredPackages: UDINT; // Packages registered at PE1.
    udiGoodScans         : UDINT; // Scanner good-read count.
    udiBadScans          : UDINT; // Scanner bad-read count.
    rAvailability        : REAL;  // Execute / scheduled time.
    rPerformance         : REAL;  // Target sorting velocity efficiency.
    rQuality             : REAL;  // (Total - Reject) / Total.
    rOEE_percent         : REAL;  // Availability * Performance * Quality * 100.
    rThroughput_ppm      : REAL;  // Recent average from total/scheduled time.
    sStatusText          : STRING(80);
END_STRUCT
END_TYPE

TYPE ST_KPIServiceContext :
STRUCT
    eState            : E_KPIServiceState;
    xInitialized      : BOOL;
    xPE4Last          : BOOL;
    xPE5Last          : BOOL;
    xPE6Last          : BOOL;
    xRegisteredLast    : BOOL;
    xGoodScanLast      : BOOL;
    xBadScanLast       : BOOL;
    rExecuteTime_s    : REAL;
    rFaultDowntime_s  : REAL;
    rScheduledTime_s  : REAL;
END_STRUCT
END_TYPE

FUNCTION F_KPIService_Init : BOOL
VAR_INPUT
    stConfig : ST_KPIServiceConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_KPIServiceContext;
    stOut     : ST_KPIServiceOutput;
END_VAR

// Initialisation function. Clears counters and restores default OEE factors.
stContext.eState := E_KPIServiceState.KPI_IDLE;
stContext.xInitialized := TRUE;
stContext.xPE4Last := FALSE;
stContext.xPE5Last := FALSE;
stContext.xPE6Last := FALSE;
stContext.xRegisteredLast := FALSE;
stContext.xGoodScanLast := FALSE;
stContext.xBadScanLast := FALSE;
stContext.rExecuteTime_s := 0.0;
stContext.rFaultDowntime_s := 0.0;
stContext.rScheduledTime_s := 0.0;

stOut.udiTotalPackages := 0;
stOut.udiLaneAPackages := 0;
stOut.udiLaneBPackages := 0;
stOut.udiRejectPackages := 0;
stOut.udiRegisteredPackages := 0;
stOut.udiGoodScans := 0;
stOut.udiBadScans := 0;
stOut.rAvailability := 1.0;
stOut.rPerformance := stConfig.rPerformanceFactor;
stOut.rQuality := 1.0;
stOut.rOEE_percent := stOut.rAvailability * stOut.rPerformance * stOut.rQuality * 100.0;
stOut.rThroughput_ppm := 0.0;
stOut.sStatusText := 'KPI service initialised';

F_KPIService_Init := TRUE;
END_FUNCTION

FUNCTION F_KPIService_Cyclic : BOOL
VAR_INPUT
    stIn     : ST_KPIServiceInput;
    stConfig : ST_KPIServiceConfig;
END_VAR
VAR_IN_OUT
    stContext : ST_KPIServiceContext;
    stOut     : ST_KPIServiceOutput;
END_VAR
VAR
    xPE4Rise : BOOL;
    xPE5Rise : BOOL;
    xPE6Rise : BOOL;
    xLaneAEvent : BOOL;
    xLaneBEvent : BOOL;
    xRejectEvent: BOOL;
    xRegisteredRise : BOOL;
    xGoodScanRise   : BOOL;
    xBadScanRise    : BOOL;
    rRawPerformance : REAL;
END_VAR

// Cyclic execution function. Sensor edges drive counters; PackML state drives availability.
IF stIn.xResetCounters THEN
    stContext.eState := E_KPIServiceState.KPI_RESETTING;
    stContext.rExecuteTime_s := 0.0;
    stContext.rFaultDowntime_s := 0.0;
    stContext.rScheduledTime_s := 0.0;
    stOut.udiTotalPackages := 0;
    stOut.udiLaneAPackages := 0;
    stOut.udiLaneBPackages := 0;
    stOut.udiRejectPackages := 0;
    stOut.udiRegisteredPackages := 0;
    stOut.udiGoodScans := 0;
    stOut.udiBadScans := 0;
END_IF;

xPE4Rise := stIn.xPE4LaneA AND NOT stContext.xPE4Last;
xPE5Rise := stIn.xPE5LaneB AND NOT stContext.xPE5Last;
xPE6Rise := stIn.xPE6Reject AND NOT stContext.xPE6Last;
xLaneAEvent := xPE4Rise;
xLaneBEvent := xPE5Rise;
xRejectEvent := xPE6Rise;
IF stConfig.xUseRoutePulses THEN
    xLaneAEvent := stIn.xLaneAVerifiedPulse;
    xLaneBEvent := stIn.xLaneBVerifiedPulse;
    xRejectEvent := stIn.xRejectVerifiedPulse;
END_IF;

xRegisteredRise := stIn.xPackageRegisteredPulse AND NOT stContext.xRegisteredLast;
xGoodScanRise := stIn.xScanGoodPulse AND NOT stContext.xGoodScanLast;
xBadScanRise := stIn.xScanBadPulse AND NOT stContext.xBadScanLast;

IF xLaneAEvent THEN
    stOut.udiLaneAPackages := stOut.udiLaneAPackages + 1;
    stOut.udiTotalPackages := stOut.udiTotalPackages + 1;
END_IF;
IF xLaneBEvent THEN
    stOut.udiLaneBPackages := stOut.udiLaneBPackages + 1;
    stOut.udiTotalPackages := stOut.udiTotalPackages + 1;
END_IF;
IF xRejectEvent THEN
    stOut.udiRejectPackages := stOut.udiRejectPackages + 1;
    stOut.udiTotalPackages := stOut.udiTotalPackages + 1;
END_IF;
IF xRegisteredRise THEN
    stOut.udiRegisteredPackages := stOut.udiRegisteredPackages + 1;
END_IF;
IF xGoodScanRise THEN
    stOut.udiGoodScans := stOut.udiGoodScans + 1;
END_IF;
IF xBadScanRise THEN
    stOut.udiBadScans := stOut.udiBadScans + 1;
END_IF;

IF stIn.ePackMLState = E_PackML_State.EXECUTE THEN
    stContext.eState := E_KPIServiceState.KPI_ACCUMULATING;
    stContext.rExecuteTime_s := stContext.rExecuteTime_s + stIn.rCycleTime_s;
    stContext.rScheduledTime_s := stContext.rScheduledTime_s + stIn.rCycleTime_s;
ELSIF stIn.xFaultDowntime OR (stIn.ePackMLState = E_PackML_State.HELD) THEN
    stContext.eState := E_KPIServiceState.KPI_HELD;
    stContext.rFaultDowntime_s := stContext.rFaultDowntime_s + stIn.rCycleTime_s;
    stContext.rScheduledTime_s := stContext.rScheduledTime_s + stIn.rCycleTime_s;
ELSE
    stContext.eState := E_KPIServiceState.KPI_IDLE;
END_IF;

IF stContext.rScheduledTime_s > 0.0 THEN
    stOut.rAvailability := stContext.rExecuteTime_s / stContext.rScheduledTime_s;
    stOut.rThroughput_ppm := UDINT_TO_REAL(stOut.udiTotalPackages) / (stContext.rScheduledTime_s / 60.0);
ELSE
    stOut.rAvailability := 1.0;
    stOut.rThroughput_ppm := 0.0;
END_IF;

IF stConfig.rTargetRate_ppm > 0.0 THEN
    rRawPerformance := stOut.rThroughput_ppm / stConfig.rTargetRate_ppm;
    IF rRawPerformance > 1.0 THEN
        rRawPerformance := 1.0;
    END_IF;
    stOut.rPerformance := rRawPerformance * stConfig.rPerformanceFactor;
ELSE
    stOut.rPerformance := stConfig.rPerformanceFactor;
END_IF;

IF stOut.udiTotalPackages > 0 THEN
    stOut.rQuality := (UDINT_TO_REAL(stOut.udiTotalPackages) - UDINT_TO_REAL(stOut.udiRejectPackages))
                      / UDINT_TO_REAL(stOut.udiTotalPackages);
ELSE
    stOut.rQuality := 1.0;
END_IF;

stOut.rOEE_percent := stOut.rAvailability * stOut.rPerformance * stOut.rQuality * 100.0;
stOut.sStatusText := 'KPI service calculated counters and OEE';

stContext.xPE4Last := stIn.xPE4LaneA;
stContext.xPE5Last := stIn.xPE5LaneB;
stContext.xPE6Last := stIn.xPE6Reject;
stContext.xRegisteredLast := stIn.xPackageRegisteredPulse;
stContext.xGoodScanLast := stIn.xScanGoodPulse;
stContext.xBadScanLast := stIn.xScanBadPulse;
F_KPIService_Cyclic := stContext.xInitialized;
END_FUNCTION

FUNCTION_BLOCK FB_KPIService
VAR_INPUT
    stIn     : ST_KPIServiceInput;  // Typed symbolic inputs.
    stConfig : ST_KPIServiceConfig; // Testable KPI configuration.
    xInit    : BOOL;                // Pulse to re-run initialisation.
END_VAR
VAR_OUTPUT
    stOut        : ST_KPIServiceOutput; // Typed symbolic outputs.
    eState       : E_KPIServiceState;   // Exposed module state.
    xInitialized : BOOL;                // Module initialisation complete.
END_VAR
VAR
    stContext : ST_KPIServiceContext;
    xInitLast : BOOL;
END_VAR

IF (NOT stContext.xInitialized) OR (xInit AND NOT xInitLast) THEN
    F_KPIService_Init(stConfig := stConfig, stContext := stContext, stOut := stOut);
END_IF;

F_KPIService_Cyclic(stIn := stIn, stConfig := stConfig, stContext := stContext, stOut := stOut);

eState := stContext.eState;
xInitialized := stContext.xInitialized;
xInitLast := xInit;
END_FUNCTION_BLOCK

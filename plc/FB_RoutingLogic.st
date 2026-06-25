// ==========================================
// ROUTING LOGIC MODULE FOR MHMC-01
// File: FB_RoutingLogic.st
// Standard: IEC 61131-3 Structured Text
// Purpose: Recipe-aware automatic routing, manual test commands, and FIFO tracking.
// ==========================================

FUNCTION_BLOCK FB_RoutingLogic
VAR_INPUT
    xConveyorRunning    : BOOL;         // Conveyor feedback running.
    rConveyorSpeed      : REAL;         // Speed in m/s.
    sScannerString      : STRING(80);   // String returned from Scanner 1.
    xScannerReadSuccess : BOOL;         // Scanner good-read flag.
    xRawPE4             : BOOL;         // Physical exit sensor Lane A (PE4).
    xRawPE5             : BOOL;         // Physical exit sensor Lane B (PE5).
    xRawPE6             : BOOL;         // Physical exit sensor Reject (PE6).
    xResetAlarms        : BOOL;         // Reset faults and routing queue.
    xPE1                : BOOL;         // Infeed sensor to register package.
    xPE2                : BOOL;         // Scan trigger sensor.
    xPE3                : BOOL;         // Diverter 1 checkpoint.
    tCycleTime          : REAL := 0.05; // Task cycle time in seconds.

    // Extended symbolic interface. Existing callers may omit these named inputs.
    eCurrentMode             : E_PackML_Mode := E_PackML_Mode.AUTO; // Routing mode.
    stActiveRecipe           : ST_SortRecipe;  // Active sort pattern and geometry.
    stManual                 : ST_ManualControl; // Manual/maintenance test commands.
    xAutoEnable              : BOOL := TRUE;   // StationController permits automatic routing.
    xMaintenanceSafeguardsOK : BOOL := FALSE;  // Maintenance key/permissive validated.
    xDiverter1Ready          : BOOL := TRUE;   // Diverter 1 can accept request.
    xDiverter2Ready          : BOOL := TRUE;   // Diverter 2 can accept request.
    xDiverter1Done           : BOOL := FALSE;  // Diverter 1 completed the active request.
    xDiverter2Done           : BOOL := FALSE;  // Diverter 2 completed the active request.
    xDiverter1Faulted        : BOOL := FALSE;  // Diverter 1 fault feedback.
    xDiverter2Faulted        : BOOL := FALSE;  // Diverter 2 fault feedback.
END_VAR
VAR_OUTPUT
    sLastBarcode        : STRING(80);
    xReadSuccess        : BOOL;
    udiTotalCount       : UDINT := 0;
    udiLaneACount       : UDINT := 0;
    udiLaneBCount       : UDINT := 0;
    udiRejectCount      : UDINT := 0;
    stDiverter1         : ST_Diverter_Status;
    stDiverter2         : ST_Diverter_Status;
    xManualTrigger      : BOOL;         // Remote override scan trigger.

    // Unit-test and integration outputs.
    stRoutingStatus          : ST_RoutingStatus;
    xScannerTriggerPulse     : BOOL;
    xPackageRegisteredPulse  : BOOL;
    xScanGoodPulse           : BOOL;
    xScanBadPulse            : BOOL;
    xLaneAVerifiedPulse      : BOOL;
    xLaneBVerifiedPulse      : BOOL;
    xRejectVerifiedPulse     : BOOL;
    xRouteFault              : BOOL;
END_VAR
VAR
    arrQueue            : ARRAY[1..10] OF ST_Package; // FIFO package tracking.
    uiNextPackageID     : UDINT := 1;
    xPE1_Last           : BOOL := FALSE;
    xPE2_Last           : BOOL := FALSE;
    xPE3_Last           : BOOL := FALSE;
    xPE4_Last           : BOOL := FALSE;
    xPE5_Last           : BOOL := FALSE;
    xPE6_Last           : BOOL := FALSE;
    xManualScannerLast  : BOOL := FALSE;
    i                   : INT;
    iSlot               : INT;
    iMatch              : INT;
    udiActiveCount      : UDINT;
    rScannerStart_m     : REAL;
    rScannerEnd_m       : REAL;
    rDiv1Start_m        : REAL;
    rDiv1End_m          : REAL;
    rDiv2Start_m        : REAL;
    rDiv2End_m          : REAL;
    rRejectExit_m       : REAL;
    rPackageTimeout_s   : REAL;
    sLaneAPattern       : STRING(40);
    sLaneBPattern       : STRING(40);
    sRejectPattern      : STRING(40);
    xAutoRouteActive    : BOOL;
    xManualRouteActive  : BOOL;
    xMaintenanceActive  : BOOL;
    xBarcodeGood        : BOOL;
    eAssignedRoute      : E_RouteTarget;
END_VAR

// ==========================================
// 1. DEFAULTS, RECIPE NORMALISATION, AND MODE GATING
// ==========================================
xScannerTriggerPulse := FALSE;
xPackageRegisteredPulse := FALSE;
xScanGoodPulse := FALSE;
xScanBadPulse := FALSE;
xLaneAVerifiedPulse := FALSE;
xLaneBVerifiedPulse := FALSE;
xRejectVerifiedPulse := FALSE;
xManualTrigger := FALSE;
stDiverter1.xCommandExtend := FALSE;
stDiverter2.xCommandExtend := FALSE;
stDiverter1.xVerificationSensor := xRawPE4;
stDiverter2.xVerificationSensor := xRawPE5;
stDiverter1.xFaulted := xDiverter1Faulted;
stDiverter2.xFaulted := xDiverter2Faulted;
stRoutingStatus.xScannerTriggerPulse := FALSE;
stRoutingStatus.xQueueOverflow := FALSE;
stRoutingStatus.xScannerTimeout := FALSE;
stRoutingStatus.xLaneAVerifiedPulse := FALSE;
stRoutingStatus.xLaneBVerifiedPulse := FALSE;
stRoutingStatus.xRejectVerifiedPulse := FALSE;

// Route faults latch until reset, allowing the AlarmManager to see short misroute events.
IF xResetAlarms THEN
    xRouteFault := FALSE;
    stRoutingStatus.xRouteFault := FALSE;
    stRoutingStatus.sLastRouteMessage := 'Routing queue reset';
    FOR i := 1 TO 10 DO
        arrQueue[i].xActive := FALSE;
        arrQueue[i].xComplete := FALSE;
        arrQueue[i].xScanned := FALSE;
        arrQueue[i].xDivertIssued := FALSE;
        arrQueue[i].uID := 0;
        arrQueue[i].rPosition := 0.0;
        arrQueue[i].rAge_s := 0.0;
        arrQueue[i].iRouteTarget := 0;
        arrQueue[i].eRouteTarget := E_RouteTarget.ROUTE_NONE;
        arrQueue[i].sBarcode := '';
    END_FOR;
END_IF;

// If no recipe is loaded, use FDS geometry and barcode patterns as safe defaults.
rScannerStart_m := stActiveRecipe.rScannerWindowStart_m;
rScannerEnd_m := stActiveRecipe.rScannerWindowEnd_m;
rDiv1Start_m := stActiveRecipe.rDiverter1WindowStart_m;
rDiv1End_m := stActiveRecipe.rDiverter1WindowEnd_m;
rDiv2Start_m := stActiveRecipe.rDiverter2WindowStart_m;
rDiv2End_m := stActiveRecipe.rDiverter2WindowEnd_m;
rRejectExit_m := stActiveRecipe.rRejectExitPosition_m;
rPackageTimeout_s := stActiveRecipe.rPackageTimeout_s;
sLaneAPattern := stActiveRecipe.sLaneAPattern;
sLaneBPattern := stActiveRecipe.sLaneBPattern;
sRejectPattern := stActiveRecipe.sRejectPattern;

IF rScannerEnd_m <= rScannerStart_m THEN
    rScannerStart_m := 1.0;
    rScannerEnd_m := 1.4;
END_IF;
IF rDiv1End_m <= rDiv1Start_m THEN
    rDiv1Start_m := 2.05;
    rDiv1End_m := 2.35;
END_IF;
IF rDiv2End_m <= rDiv2Start_m THEN
    rDiv2Start_m := 3.05;
    rDiv2End_m := 3.35;
END_IF;
IF rRejectExit_m <= 0.0 THEN
    rRejectExit_m := 4.2;
END_IF;
IF rPackageTimeout_s <= 0.0 THEN
    rPackageTimeout_s := 12.0;
END_IF;
IF sLaneAPattern = '' THEN
    sLaneAPattern := 'LANE-A';
END_IF;
IF sLaneBPattern = '' THEN
    sLaneBPattern := 'LANE-B';
END_IF;

xAutoRouteActive := xAutoEnable AND (eCurrentMode = E_PackML_Mode.AUTO);
xManualRouteActive := eCurrentMode = E_PackML_Mode.MANUAL;
xMaintenanceActive := (eCurrentMode = E_PackML_Mode.MAINTENANCE) AND xMaintenanceSafeguardsOK;

// Manual and maintenance modes are explicit, hold-to-run, and do not alter the automatic FIFO.
IF xManualRouteActive OR xMaintenanceActive THEN
    stDiverter1.xCommandExtend := stManual.xDiverter1Extend;
    stDiverter2.xCommandExtend := stManual.xDiverter2Extend;
    xManualTrigger := stManual.xScannerTrigger;
    xScannerTriggerPulse := stManual.xScannerTrigger AND NOT xManualScannerLast;
    stRoutingStatus.xScannerTriggerPulse := xScannerTriggerPulse;
    stRoutingStatus.sLastRouteMessage := 'Manual or maintenance routing command active';
END_IF;

// ==========================================
// 2. AUTOMATIC FIFO INGESTION AND PACKAGE TRACKING
// ==========================================
IF xAutoRouteActive THEN
    IF xPE1 AND NOT xPE1_Last THEN
        iSlot := 0;
        FOR i := 1 TO 10 DO
            IF NOT arrQueue[i].xActive THEN
                iSlot := i;
                EXIT;
            END_IF;
        END_FOR;

        IF iSlot > 0 THEN
            arrQueue[iSlot].uID := uiNextPackageID;
            arrQueue[iSlot].sBarcode := '';
            arrQueue[iSlot].iRouteTarget := 0;
            arrQueue[iSlot].eRouteTarget := E_RouteTarget.ROUTE_NONE;
            arrQueue[iSlot].rPosition := 0.2;
            arrQueue[iSlot].rAge_s := 0.0;
            arrQueue[iSlot].xScanned := FALSE;
            arrQueue[iSlot].xDivertIssued := FALSE;
            arrQueue[iSlot].xComplete := FALSE;
            arrQueue[iSlot].xActive := TRUE;
            stRoutingStatus.udiLastPackageID := uiNextPackageID;
            uiNextPackageID := uiNextPackageID + 1;
            xPackageRegisteredPulse := TRUE;
            stRoutingStatus.sLastRouteMessage := 'Package registered at PE1';
        ELSE
            stRoutingStatus.xQueueOverflow := TRUE;
            stRoutingStatus.xRouteFault := TRUE;
            xRouteFault := TRUE;
            stRoutingStatus.sLastRouteMessage := 'Routing FIFO overflow';
        END_IF;
    END_IF;

    IF xConveyorRunning AND (rConveyorSpeed > 0.0) THEN
        FOR i := 1 TO 10 DO
            IF arrQueue[i].xActive THEN
                arrQueue[i].rPosition := arrQueue[i].rPosition + (rConveyorSpeed * tCycleTime);
                arrQueue[i].rAge_s := arrQueue[i].rAge_s + tCycleTime;

                IF arrQueue[i].rAge_s > rPackageTimeout_s THEN
                    arrQueue[i].xActive := FALSE;
                    stRoutingStatus.xRouteFault := TRUE;
                    xRouteFault := TRUE;
                    stRoutingStatus.sLastRouteMessage := 'Package timed out in routing queue';
                END_IF;
            END_IF;
        END_FOR;
    END_IF;
END_IF;

// ==========================================
// 3. SCANNER TRIGGER AND RECIPE-BASED ROUTE ASSIGNMENT
// ==========================================
IF xAutoRouteActive AND xPE2 AND NOT xPE2_Last THEN
    xScannerTriggerPulse := TRUE;
    stRoutingStatus.xScannerTriggerPulse := TRUE;
    iMatch := 0;

    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive
           AND NOT arrQueue[i].xScanned
           AND (arrQueue[i].rPosition >= rScannerStart_m)
           AND (arrQueue[i].rPosition <= rScannerEnd_m) THEN
            iMatch := i;
            EXIT;
        END_IF;
    END_FOR;

    IF iMatch > 0 THEN
        sLastBarcode := sScannerString;
        arrQueue[iMatch].sBarcode := sScannerString;
        arrQueue[iMatch].xScanned := TRUE;
        xBarcodeGood := xScannerReadSuccess AND (FIND(sScannerString, 'BAD-SCAN') = 0);
        xReadSuccess := xBarcodeGood;

        IF xBarcodeGood THEN
            IF FIND(sScannerString, sLaneAPattern) > 0 THEN
                eAssignedRoute := E_RouteTarget.ROUTE_LANE_A;
            ELSIF FIND(sScannerString, sLaneBPattern) > 0 THEN
                eAssignedRoute := E_RouteTarget.ROUTE_LANE_B;
            ELSIF (sRejectPattern <> '') AND (FIND(sScannerString, sRejectPattern) > 0) THEN
                eAssignedRoute := E_RouteTarget.ROUTE_REJECT;
            ELSE
                eAssignedRoute := E_RouteTarget.ROUTE_REJECT;
            END_IF;
            xScanGoodPulse := TRUE;
        ELSE
            eAssignedRoute := E_RouteTarget.ROUTE_REJECT;
            xScanBadPulse := TRUE;
            stRoutingStatus.xScannerTimeout := TRUE;
        END_IF;

        arrQueue[iMatch].eRouteTarget := eAssignedRoute;
        CASE eAssignedRoute OF
            E_RouteTarget.ROUTE_LANE_A:
                arrQueue[iMatch].iRouteTarget := 1;
            E_RouteTarget.ROUTE_LANE_B:
                arrQueue[iMatch].iRouteTarget := 2;
            E_RouteTarget.ROUTE_REJECT:
                arrQueue[iMatch].iRouteTarget := 9;
            ELSE
                arrQueue[iMatch].iRouteTarget := 0;
        END_CASE;
        stRoutingStatus.eLastRouteTarget := eAssignedRoute;
        stRoutingStatus.sLastRouteMessage := 'Barcode resolved to route target';
    ELSE
        xScanBadPulse := TRUE;
        stRoutingStatus.xScannerTimeout := TRUE;
        stRoutingStatus.xRouteFault := TRUE;
        xRouteFault := TRUE;
        stRoutingStatus.sLastRouteMessage := 'PE2 trigger without matching package';
    END_IF;
END_IF;

// Packages that pass the scanner window unassigned are forced to reject and reported.
IF xAutoRouteActive THEN
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive
           AND NOT arrQueue[i].xScanned
           AND (arrQueue[i].rPosition > rScannerEnd_m) THEN
            arrQueue[i].xScanned := TRUE;
            arrQueue[i].eRouteTarget := E_RouteTarget.ROUTE_REJECT;
            arrQueue[i].iRouteTarget := 9;
            stRoutingStatus.xScannerTimeout := TRUE;
            stRoutingStatus.xRouteFault := TRUE;
            xRouteFault := TRUE;
            xScanBadPulse := TRUE;
            stRoutingStatus.sLastRouteMessage := 'Package missed scanner window and was rejected';
        END_IF;
    END_FOR;
END_IF;

// ==========================================
// 4. DIVERTER REQUEST GENERATION
// ==========================================
IF xAutoRouteActive THEN
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive THEN
            IF arrQueue[i].eRouteTarget = E_RouteTarget.ROUTE_LANE_A THEN
                IF (arrQueue[i].rPosition >= rDiv1Start_m)
                   AND (arrQueue[i].rPosition <= rDiv1End_m) THEN
                    IF xDiverter1Faulted THEN
                        stRoutingStatus.xRouteFault := TRUE;
                        xRouteFault := TRUE;
                        stRoutingStatus.sLastRouteMessage := 'Diverter 1 faulted during firing window';
                    ELSIF xDiverter1Ready OR arrQueue[i].xDivertIssued THEN
                        stDiverter1.xCommandExtend := NOT xDiverter1Done;
                        arrQueue[i].xDivertIssued := TRUE;
                    ELSE
                        stRoutingStatus.xRouteFault := TRUE;
                        xRouteFault := TRUE;
                        stRoutingStatus.sLastRouteMessage := 'Diverter 1 not ready at firing window';
                    END_IF;
                ELSIF (arrQueue[i].rPosition > rDiv1End_m) AND NOT arrQueue[i].xDivertIssued THEN
                    stRoutingStatus.xRouteFault := TRUE;
                    xRouteFault := TRUE;
                    stRoutingStatus.sLastRouteMessage := 'Lane A package passed Diverter 1 without command';
                END_IF;
            ELSIF arrQueue[i].eRouteTarget = E_RouteTarget.ROUTE_LANE_B THEN
                IF (arrQueue[i].rPosition >= rDiv2Start_m)
                   AND (arrQueue[i].rPosition <= rDiv2End_m) THEN
                    IF xDiverter2Faulted THEN
                        stRoutingStatus.xRouteFault := TRUE;
                        xRouteFault := TRUE;
                        stRoutingStatus.sLastRouteMessage := 'Diverter 2 faulted during firing window';
                    ELSIF xDiverter2Ready OR arrQueue[i].xDivertIssued THEN
                        stDiverter2.xCommandExtend := NOT xDiverter2Done;
                    arrQueue[i].xDivertIssued := TRUE;
                    ELSE
                        stRoutingStatus.xRouteFault := TRUE;
                        xRouteFault := TRUE;
                        stRoutingStatus.sLastRouteMessage := 'Diverter 2 not ready at firing window';
                    END_IF;
                ELSIF (arrQueue[i].rPosition > rDiv2End_m) AND NOT arrQueue[i].xDivertIssued THEN
                    stRoutingStatus.xRouteFault := TRUE;
                    xRouteFault := TRUE;
                    stRoutingStatus.sLastRouteMessage := 'Lane B package passed Diverter 2 without command';
                END_IF;
            END_IF;
        END_IF;
    END_FOR;
END_IF;

// ==========================================
// 5. EXIT SENSOR VERIFICATION AND COUNTERS
// ==========================================
IF xAutoRouteActive AND xRawPE4 AND NOT xPE4_Last THEN
    iMatch := 0;
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive
           AND (arrQueue[i].eRouteTarget = E_RouteTarget.ROUTE_LANE_A)
           AND arrQueue[i].xDivertIssued
           AND (arrQueue[i].rPosition >= rDiv1Start_m) THEN
            iMatch := i;
            EXIT;
        END_IF;
    END_FOR;
    IF iMatch > 0 THEN
        arrQueue[iMatch].xActive := FALSE;
        arrQueue[iMatch].xComplete := TRUE;
        stRoutingStatus.udiLastCompletedID := arrQueue[iMatch].uID;
        udiLaneACount := udiLaneACount + 1;
        udiTotalCount := udiTotalCount + 1;
        xLaneAVerifiedPulse := TRUE;
        stRoutingStatus.sLastRouteMessage := 'Lane A verification complete';
    ELSE
        stRoutingStatus.xRouteFault := TRUE;
        xRouteFault := TRUE;
        stRoutingStatus.sLastRouteMessage := 'PE4 verification without Lane A package';
    END_IF;
END_IF;

IF xAutoRouteActive AND xRawPE5 AND NOT xPE5_Last THEN
    iMatch := 0;
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive
           AND (arrQueue[i].eRouteTarget = E_RouteTarget.ROUTE_LANE_B)
           AND arrQueue[i].xDivertIssued
           AND (arrQueue[i].rPosition >= rDiv2Start_m) THEN
            iMatch := i;
            EXIT;
        END_IF;
    END_FOR;
    IF iMatch > 0 THEN
        arrQueue[iMatch].xActive := FALSE;
        arrQueue[iMatch].xComplete := TRUE;
        stRoutingStatus.udiLastCompletedID := arrQueue[iMatch].uID;
        udiLaneBCount := udiLaneBCount + 1;
        udiTotalCount := udiTotalCount + 1;
        xLaneBVerifiedPulse := TRUE;
        stRoutingStatus.sLastRouteMessage := 'Lane B verification complete';
    ELSE
        stRoutingStatus.xRouteFault := TRUE;
        xRouteFault := TRUE;
        stRoutingStatus.sLastRouteMessage := 'PE5 verification without Lane B package';
    END_IF;
END_IF;

IF xAutoRouteActive AND xRawPE6 AND NOT xPE6_Last THEN
    iMatch := 0;
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive
           AND (arrQueue[i].eRouteTarget = E_RouteTarget.ROUTE_REJECT)
           AND arrQueue[i].xScanned
           AND (arrQueue[i].rPosition >= rScannerEnd_m) THEN
            iMatch := i;
            EXIT;
        END_IF;
    END_FOR;
    IF iMatch > 0 THEN
        arrQueue[iMatch].xActive := FALSE;
        arrQueue[iMatch].xComplete := TRUE;
        stRoutingStatus.udiLastCompletedID := arrQueue[iMatch].uID;
        udiRejectCount := udiRejectCount + 1;
        udiTotalCount := udiTotalCount + 1;
        xRejectVerifiedPulse := TRUE;
        stRoutingStatus.sLastRouteMessage := 'Reject verification complete';
    ELSE
        stRoutingStatus.xRouteFault := TRUE;
        xRouteFault := TRUE;
        stRoutingStatus.sLastRouteMessage := 'PE6 verification without reject package';
    END_IF;
END_IF;

// Any package that travels beyond the reject exit without verification is a route fault.
IF xAutoRouteActive THEN
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive AND (arrQueue[i].rPosition > (rRejectExit_m + 0.3)) THEN
            arrQueue[i].xActive := FALSE;
            stRoutingStatus.xRouteFault := TRUE;
            xRouteFault := TRUE;
            stRoutingStatus.sLastRouteMessage := 'Package left cell without exit verification';
        END_IF;
    END_FOR;
END_IF;

// ==========================================
// 6. STATUS FINALISATION
// ==========================================
udiActiveCount := 0;
FOR i := 1 TO 10 DO
    IF arrQueue[i].xActive THEN
        udiActiveCount := udiActiveCount + 1;
    END_IF;
END_FOR;

stRoutingStatus.udiActivePackages := udiActiveCount;
stRoutingStatus.xRouteFault := stRoutingStatus.xRouteFault OR xRouteFault;
stRoutingStatus.xLaneAVerifiedPulse := xLaneAVerifiedPulse;
stRoutingStatus.xLaneBVerifiedPulse := xLaneBVerifiedPulse;
stRoutingStatus.xRejectVerifiedPulse := xRejectVerifiedPulse;

xPE1_Last := xPE1;
xPE2_Last := xPE2;
xPE3_Last := xPE3;
xPE4_Last := xRawPE4;
xPE5_Last := xRawPE5;
xPE6_Last := xRawPE6;
xManualScannerLast := stManual.xScannerTrigger;
END_FUNCTION_BLOCK

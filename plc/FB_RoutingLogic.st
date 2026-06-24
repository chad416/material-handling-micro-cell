FUNCTION_BLOCK FB_RoutingLogic
VAR_INPUT
    xConveyorRunning    : BOOL;         // Conveyor feedback running
    rConveyorSpeed      : REAL;         // Speed in m/s
    sScannerString      : STRING(80);   // String returned from Scanner 1
    xScannerReadSuccess : BOOL;         // Heartbeat/success flag from scanner
    xRawPE4             : BOOL;         // Physical exit sensor Lane A (PE4)
    xRawPE5             : BOOL;         // Physical exit sensor Lane B (PE5)
    xRawPE6             : BOOL;         // Physical exit sensor Reject (PE6)
    xResetAlarms        : BOOL;         // Reset faults
    xPE1                : BOOL;         // Infeed sensor to register package
    xPE2                : BOOL;         // Scan trigger sensor
    xPE3                : BOOL;         // Diverter 1 Checkpoint
    tCycleTime          : REAL := 0.05; // Task cycle time in seconds (50ms)
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
    xManualTrigger      : BOOL;         // Remote override scan trigger
END_VAR
VAR
    arrQueue            : ARRAY[1..10] OF ST_Package; // FIFO package tracking
    uiNextPackageID     : UDINT := 1;
    xPE1_Last           : BOOL := FALSE;
    xPE2_Last           : BOOL := FALSE;
    xPE3_Last           : BOOL := FALSE;
    i                   : INT;
    tonDiverter1_Work   : TON;          // Timeout watchdog Diverter 1
    tonDiverter2_Work   : TON;          // Timeout watchdog Diverter 2
    tonPE4_DivertVerify : TON;          // Exit verification Lane A
    tonPE5_DivertVerify : TON;          // Exit verification Lane B
    tonPE6_DivertVerify : TON;          // Exit verification Reject
END_VAR

// 1. INGESTION ON INFEED (Rising edge of PE1)
IF xPE1 AND NOT xPE1_Last THEN
    // Search for empty slot in tracking queue
    FOR i := 1 TO 10 DO
        IF NOT arrQueue[i].xActive THEN
            arrQueue[i].uID := uiNextPackageID;
            arrQueue[i].sBarcode := "";
            arrQueue[i].iRouteTarget := 0;
            arrQueue[i].rPosition := 0.2; // Registered at PE1 location (0.2m)
            arrQueue[i].xActive := TRUE;
            uiNextPackageID := uiNextPackageID + 1;
            EXIT;
        END_IF;
    END_FOR;
END_IF;
xPE1_Last := xPE1;

// 2. RUNTIME SIMULATION & TRACKING UPDATE
IF xConveyorRunning AND rConveyorSpeed > 0.0 THEN
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive THEN
            // Move packages along the conveyor by integrating velocity
            arrQueue[i].rPosition := arrQueue[i].rPosition + (rConveyorSpeed * tCycleTime);
            
            // Out of bounds safety (in case divert fails mechanically and it exits default end)
            IF arrQueue[i].rPosition >= 4.2 THEN
                arrQueue[i].xActive := FALSE; // Remove package
            END_IF;
        END_IF;
    END_FOR;
END_IF;

// 3. BARCODE TRIGGER & RESOLUTION (Package passing PE2 at 1.2m)
IF xPE2 AND NOT xPE2_Last THEN
    // Find closest package to the scanning checkpoint (1.2m)
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive AND (arrQueue[i].rPosition >= 1.0) AND (arrQueue[i].rPosition <= 1.4) THEN
            // Fetch barcode information
            sLastBarcode := sScannerString;
            xReadSuccess := xScannerReadSuccess;
            arrQueue[i].sBarcode := sLastBarcode;
            
            // Decrypt Route Target using basic string matching patterns
            IF FIND(sLastBarcode, "LANE-A") > 0 THEN
                arrQueue[i].iRouteTarget := 1; // Lane A
            ELSIF FIND(sLastBarcode, "LANE-B") > 0 THEN
                arrQueue[i].iRouteTarget := 2; // Lane B
            ELSE
                arrQueue[i].iRouteTarget := 9; // Default Reject
            END_IF;
            EXIT;
        END_IF;
    END_FOR;
END_IF;
xPE2_Last := xPE2;

// 4. DIVERT SEQUENCING & ACTUATOR FIRING
// Diverter 1 (at 2.2m) - Route target = 1
stDiverter1.xCommandExtend := FALSE;
FOR i := 1 TO 10 DO
    IF arrQueue[i].xActive AND (arrQueue[i].iRouteTarget = 1) THEN
        // If package is directly in range of Diverter 1 (2.05m to 2.35m)
        IF (arrQueue[i].rPosition >= 2.05) AND (arrQueue[i].rPosition <= 2.35) THEN
            stDiverter1.xCommandExtend := TRUE;
            EXIT;
        END_IF;
    END_FOR;
END_IF;

// Diverter 2 (at 3.2m) - Route target = 2
stDiverter2.xCommandExtend := FALSE;
FOR i := 1 TO 10 DO
    IF arrQueue[i].xActive AND (arrQueue[i].iRouteTarget = 2) THEN
        // If package is in range of Diverter 2 (3.05m to 3.35m)
        IF (arrQueue[i].rPosition >= 3.05) AND (arrQueue[i].rPosition <= 3.35) THEN
            stDiverter2.xCommandExtend := TRUE;
            EXIT;
        END_IF;
    END_FOR;
END_IF;

// 5. EXIT VERIFICATION AND COUNTING
// Verify divert into Lane A (PE4)
IF xRawPE4 THEN
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive AND (arrQueue[i].iRouteTarget = 1) AND (arrQueue[i].rPosition >= 1.9) THEN
            arrQueue[i].xActive := FALSE; // Remove package
            udiLaneACount := udiLaneACount + 1;
            udiTotalCount := udiTotalCount + 1;
            EXIT;
        END_IF;
    END_FOR;
END_IF;

// Verify divert into Lane B (PE5)
IF xRawPE5 THEN
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive AND (arrQueue[i].iRouteTarget = 2) AND (arrQueue[i].rPosition >= 2.9) THEN
            arrQueue[i].xActive := FALSE; // Remove package
            udiLaneBCount := udiLaneBCount + 1;
            udiTotalCount := udiTotalCount + 1;
            EXIT;
        END_IF;
    END_FOR;
END_IF;

// Verify reject lane exit (PE6)
IF xRawPE6 THEN
    FOR i := 1 TO 10 DO
        IF arrQueue[i].xActive AND (arrQueue[i].iRouteTarget = 9) AND (arrQueue[i].rPosition >= 3.8) THEN
            arrQueue[i].xActive := FALSE; // Remove package
            udiRejectCount := udiRejectCount + 1;
            udiTotalCount := udiTotalCount + 1;
            EXIT;
        END_IF;
    END_FOR;
END_IF;

// 6. ACTUATOR TRAVEL WATCHDOG TIMERS
// Timout alarm if cylinders take too long to reach work position
tonDiverter1_Work(IN := stDiverter1.xCommandExtend AND NOT stDiverter1.xWorkSensor, PT := T#800MS);
tonDiverter2_Work(IN := stDiverter2.xCommandExtend AND NOT stDiverter2.xWorkSensor, PT := T#800MS);

IF tonDiverter1_Work.Q THEN
    stDiverter1.xFaulted := TRUE;
END_IF;

IF tonDiverter2_Work.Q THEN
    stDiverter2.xFaulted := TRUE;
END_IF;

// Reset faults
IF xResetAlarms THEN
    stDiverter1.xFaulted := FALSE;
    stDiverter2.xFaulted := FALSE;
    tonDiverter1_Work(IN := FALSE);
    tonDiverter2_Work(IN := FALSE);
END_IF;

// ==========================================
// TYPES AND STRUCTS FOR MHMC-01 CELL
// File: Types.st
// Standard: IEC 61131-3 Structured Text
// ==========================================

TYPE E_PackML_State :
(
    STOPPED     := 0,
    STARTING    := 1,
    EXECUTE     := 2,
    SUSPENDED   := 3,
    HOLDING     := 4,
    HELD        := 5,
    UNHOLDING   := 6,
    STOPPING    := 7,
    ABORTED     := 8,
    IDLE        := 9,
    RESETTING   := 10
) INT;
END_TYPE

TYPE E_PackML_Mode :
(
    MANUAL      := 0,
    AUTO        := 1,
    MAINTENANCE := 2
) INT;
END_TYPE

TYPE E_RouteTarget :
(
    ROUTE_NONE   := 0,
    ROUTE_LANE_A := 1,
    ROUTE_LANE_B := 2,
    ROUTE_REJECT := 9
) INT;
END_TYPE

TYPE E_MHMCAlarmCode :
(
    ALARM_NONE         := 0,
    ALARM_GENERAL_JAM  := 100,
    ALARM_DIVERTER_1   := 200,
    ALARM_DIVERTER_2   := 210,
    ALARM_ROUTE_FAULT  := 250,
    ALARM_AIR_PRESSURE := 300,
    ALARM_VFD_FAULT    := 400,
    ALARM_ESTOP        := 1000
) INT;
END_TYPE

TYPE E_MHMCEventClass :
(
    EVENT_INFO        := 0,
    EVENT_COMMAND     := 10,
    EVENT_RECIPE      := 20,
    EVENT_ROUTE       := 30,
    EVENT_KPI         := 40,
    EVENT_ALARM       := 50,
    EVENT_RECOVERY    := 60,
    EVENT_MAINTENANCE := 70
) INT;
END_TYPE

TYPE ST_SortRecipe :
STRUCT
    uiRecipeID                    : UINT;       // Recipe selector used by HMI/MES.
    xEnabled                      : BOOL;       // Recipe may be loaded when TRUE.
    sName                         : STRING(40); // Operator-visible recipe label.
    rAutoSpeed_mps                : REAL;       // Conveyor speed for automatic sorting.
    rManualMaxSpeed_mps           : REAL;       // Maximum manual jog speed.
    rMaintenanceSpeedLimit_mps    : REAL;       // Lower engineering jog limit.
    sLaneAPattern                 : STRING(40); // Barcode substring routed to Lane A.
    sLaneBPattern                 : STRING(40); // Barcode substring routed to Lane B.
    sRejectPattern                : STRING(40); // Optional explicit reject substring.
    rScannerWindowStart_m         : REAL;       // Position window for scanner association.
    rScannerWindowEnd_m           : REAL;
    rDiverter1WindowStart_m       : REAL;       // Position window to fire Diverter 1.
    rDiverter1WindowEnd_m         : REAL;
    rDiverter2WindowStart_m       : REAL;       // Position window to fire Diverter 2.
    rDiverter2WindowEnd_m         : REAL;
    rRejectExitPosition_m         : REAL;       // End-of-cell package cleanup threshold.
    rPackageTimeout_s             : REAL;       // Max package age before routing fault.
END_STRUCT
END_TYPE

TYPE ST_ManualControl :
STRUCT
    xJogConveyorForward  : BOOL; // Hold-to-run conveyor jog request.
    rJogSpeed_mps        : REAL; // Requested jog speed before safety limiting.
    xDiverter1Extend     : BOOL; // Hold-to-run Diverter 1 manual fire.
    xDiverter2Extend     : BOOL; // Hold-to-run Diverter 2 manual fire.
    xScannerTrigger      : BOOL; // Manual scanner trigger/test pulse.
    xResetJam            : BOOL; // Operator confirms jam cleared.
    xResetCounters       : BOOL; // Maintenance KPI reset.
    xMaintenanceKey      : BOOL; // Engineering key switch/role validation.
END_STRUCT
END_TYPE

TYPE ST_RoutingStatus :
STRUCT
    udiActivePackages      : UDINT;         // Active packages in FIFO.
    udiLastPackageID       : UDINT;         // Most recently allocated package ID.
    udiLastCompletedID     : UDINT;         // Most recently verified package ID.
    eLastRouteTarget       : E_RouteTarget; // Last route assigned by scanner.
    xQueueOverflow         : BOOL;          // FIFO has no free slot.
    xScannerTriggerPulse   : BOOL;          // One-cycle scanner trigger.
    xScannerTimeout        : BOOL;          // Package passed scanner without valid data.
    xRouteFault            : BOOL;          // Misroute, timeout, or queue fault.
    xLaneAVerifiedPulse    : BOOL;          // One-cycle verified Lane A package.
    xLaneBVerifiedPulse    : BOOL;          // One-cycle verified Lane B package.
    xRejectVerifiedPulse   : BOOL;          // One-cycle verified reject package.
    sLastRouteMessage      : STRING(80);    // Human-readable routing diagnostic.
END_STRUCT
END_TYPE

TYPE ST_MHMCEventRecord :
STRUCT
    xActive         : BOOL;             // TRUE once this slot contains valid data.
    xAcknowledged   : BOOL;             // Alarm/event acknowledgement mirror.
    udiSequence     : UDINT;            // Monotonic event sequence number.
    rTimestamp_s    : REAL;             // Runtime seconds from module start.
    eClass          : E_MHMCEventClass; // Command, alarm, recovery, recipe, etc.
    uiCode          : UINT;             // Event or alarm code.
    uiSeverity      : UINT;             // OPC UA style severity 0..1000.
    ePackMLState    : E_PackML_State;   // State at time of event.
    eMode           : E_PackML_Mode;    // Mode at time of event.
    udiPackageID    : UDINT;            // Package context when applicable.
    eRouteTarget    : E_RouteTarget;    // Route context when applicable.
    sMessage        : STRING(120);      // Compact operator/historian message.
END_STRUCT
END_TYPE

TYPE ST_MHMCEventTimeline :
STRUCT
    arrEvents       : ARRAY[1..50] OF ST_MHMCEventRecord; // Fixed ring buffer for PLC memory determinism.
    iWriteIndex     : INT;                                // Next slot, 1..50.
    iCount          : INT;                                // Number of valid slots, max 50.
    udiNextSequence : UDINT;                              // Next event sequence number.
    xNewEvent       : BOOL;                               // TRUE for one scan after append.
    stLastEvent     : ST_MHMCEventRecord;                 // Last event for OPC UA/historian.
END_STRUCT
END_TYPE

TYPE ST_Package :
STRUCT
    uID         : UDINT;        // Unique Package ID
    sBarcode    : STRING(80);   // Scanned barcode value
    iRouteTarget: INT;          // Target: 1=Lane A, 2=Lane B, 9=Reject, 0=Unassigned
    eRouteTarget: E_RouteTarget;// Typed route target for newer modules.
    rPosition   : REAL;         // Simulated position (meters from PE1)
    rAge_s       : REAL;         // Package age in active tracking queue.
    xScanned     : BOOL;         // Barcode scan has been attempted.
    xDivertIssued: BOOL;         // Diverter fire request has been issued.
    xComplete    : BOOL;         // Package was verified and removed.
    xActive     : BOOL;         // If active in tracking queue
END_STRUCT
END_TYPE

TYPE ST_Conveyor_Status :
STRUCT
    rSpeedFeedback  : REAL;     // Motor Speed (m/s)
    rSpeedSetpoint  : REAL;     // Speed Setpoint (m/s)
    rCurrent        : REAL;     // Motor Current (Amps)
    xIsRunning      : BOOL;     // VFD Running Status
    xPE1            : BOOL;     // Infeed Photocell
    xPE2            : BOOL;     // Scanner Trigger Photocell
    xPE3            : BOOL;     // Diverter 1 Checkpoint Photocell
    xFaulted        : BOOL;     // Drive or sensor watchdog fault
END_STRUCT
END_TYPE

TYPE ST_Diverter_Status :
STRUCT
    xHomeSensor            : BOOL; // Limit Switch - Retracted
    xWorkSensor            : BOOL; // Limit Switch - Extended
    xCommandExtend         : BOOL; // Output Solenoid control
    xVerificationSensor    : BOOL; // Exit photocell (PE4 or PE5)
    xFaulted               : BOOL; // Actuation timeout fault
END_STRUCT
END_TYPE

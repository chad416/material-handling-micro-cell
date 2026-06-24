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

TYPE ST_Package :
STRUCT
    uID         : UDINT;        // Unique Package ID
    sBarcode    : STRING(80);   // Scanned barcode value
    iRouteTarget: INT;          // Target: 1=Lane A, 2=Lane B, 9=Reject, 0=Unassigned
    rPosition   : REAL;         // Simulated position (meters from PE1)
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

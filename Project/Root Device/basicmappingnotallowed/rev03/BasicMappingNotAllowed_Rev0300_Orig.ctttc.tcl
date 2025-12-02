PACKAGE BasicMappingNotAllowed_Rev0300_Orig; // do not modify this line
USE Basic CMDCLASSVER = 1;
USE Supervision CMDCLASSVER = 1;

/**
 * Basic Mapping Test Script for all Z-Wave Plus V1/V2 Device Types
 * that are not allowed to support Basic Command Class.
 *
 * The Device Types MUST NOT implement Basic Command Class
 *
 * ChangeLog:
 *
 * September 10th, 2020 - Integration into 'General CTT Project' Solution of CTTv2
 *                      - Initial implementation
 * December 2nd, 2020   - Timeout of EXPECTNOT decreased from 10 to 5 seconds to avoid sleep
 * December 13th, 2021  - Version check removed; DUT could advertise controlled version for Basic CC
 *                      - Check for Supervision Status 'No_Support' added
 */

TESTSEQ CheckBasicCommandClassSupport : "Checks the support of Basic CC"

    $sessionId = 55;    // Adjust if specific Supervision Session ID is needed.

    SEND Basic.Get( );
    EXPECTNOT Basic.Report(5);

    // Supervision: Analyze NIF
    $commandClassesRoot = GETCOMMANDCLASSES();
    IF (INARRAY($commandClassesRoot, 0x6C) == true)
    {
        MSG ("Supervision CC is in the Root Device NIF.");
    }
    ELSE
    {
        MSG ("Supervision CC is not in the NIF, skipping ...");
        EXITSEQ;
    }

    MSG ("Sending Supervision Get [Basic Set (Value = 0)] ...");
    SEND Supervision.Get(
        SessionId = $sessionId,
        Reserved = 0,
        StatusUpdates = 1,
        EncapsulatedCommandLength = 3,
        EncapsulatedCommand = [0x20, 0x01, 0x00]);
    EXPECTOPT Supervision.Report(
        SessionId == $sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        ($status = Status) == 0x00, // 0x00=NO_SUPPORT, 0x01=WORKING, 0x02=FAIL, 0xFF=SUCCESS
        Duration == 0x00);

    IF (ISNULL($status))
    {
        MSG ("Warning: Supervision Get has not been answered!");
        $sessionId = $sessionId + 1;
        MSG ("Trying with another '$sessionId' ...");

        SEND Supervision.Get(
            SessionId = $sessionId,
            Reserved = 0,
            StatusUpdates = 1,
            EncapsulatedCommandLength = 3,
            EncapsulatedCommand = [0x20, 0x01, 0x00]);
        EXPECT Supervision.Report(
            SessionId == $sessionId,
            Reserved == 0,
            MoreStatusUpdates == 0,
            ($status = Status) == 0x00, // 0x00=NO_SUPPORT, 0x01=WORKING, 0x02=FAIL, 0xFF=SUCCESS
            Duration == 0x00);
    }

    IF (ISNULL($status))
    {
         MSGFAIL ("Supervision Get has not been answered!");
    }
    ELSEIF ($status == 0x00)
    {
        MSGPASS ("Supervision Status is 0x00 = 'NO_SUPPORT'.");
    }
    ELSE
    {
        MSGFAIL ("Supervision Status 0x{0:X2} is NOT 0x00 = 'NO_SUPPORT'!",  $status);
    }

TESTSEQ END

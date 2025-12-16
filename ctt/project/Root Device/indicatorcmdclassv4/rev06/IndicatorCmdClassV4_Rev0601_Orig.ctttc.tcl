PACKAGE IndicatorCmdClassV4_Rev0601_Orig; // do not modify this line
SUBREVISION = 1; // do not modify this line
USE Indicator CMDCLASSVER = 4;
USE ZwaveplusInfo CMDCLASSVER = 2;

/**
 * Indicator Command Class Version 4 Test Script
 * Command Class Specification: 2024A
 * Formatting Conventions: Version 2016-05-19
 *
 * PLEASE NOTE:
 * - The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run
 *
 * ChangeLog:
 *
 * September 21st, 2020 - First public release, derived from V3
 *                      - Indicator Description Report check added
 *                      - 'SetInitialValuesAndVariables' introduced
 * October 30th, 2020   - Migration to CTTv3 project format
 *                      - Detection of Root Device / End Point ID using CTTv3 script language features
 * December 17th, 2020  - 'IndividualValues' removed. Will be replaced by a ZATS Test Case
 *                      - 'IndividualValuesNodeIdentify' runs with the configured test data
 * February 22nd, 2021  - New Property ID of 2020C added: Timeout (hours): 0x0A
 * November 11th, 2021  - 'IndividualValuesNodeIdentify' runs without user-scripting if the
 *                        DUT supports Identify Indicator, else the sequence will be skipped
 * December 21st, 2021  - Fix in 'IndividualValuesNodeIdentify'
 * May 2nd, 2024        - Refactored 'IndividualValuesNodeIdentify' as standalone test considering recommended
 *                        report values for set value 0x00 in property 5 (On time within an On/Off period) as
 *                        clarified in spec version 2024A.
 * August 20th, 2025    - 'IndividualValuesNodeIdentify': Fixed consideration of returned Property 0x05 values when
 *                        value 0x00 (i.e. half of Property 0x03) was set.
*/


/**
 * SetInitialValuesAndVariables
 * This sequence sets the global variables and initial values for the tests of this command class.
 * This sequence MUST be executed in each test run.
 * If it is not executed, this will lead to errors in the following test sequences.
 *
 * CC versions: 1, 2, 3, 4
 */

TESTSEQ SetInitialValuesAndVariables: "Set initial Values and Variables."

    // Test environment configuration - MAY be changed
    GLOBAL $GLOBAL_sessionId = 1;      // Adjust if specific Supervision Session ID is needed.

    // Test data - MUST NOT be changed
    GLOBAL $GLOBAL_endPointId = GETENDPOINT();
    GLOBAL $GLOBAL_commandClassId = 0x87;
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Indicator";

    // Security and Supervision data - MUST NOT be changed
    GLOBAL $GLOBAL_schemeSetDelay = 0; // Testers only: Adjust temporarily, if the DUT needs a longer time for activating a Security Scheme
    GLOBAL #GLOBAL_supportedSchemes = GETSUPPORTEDSCHEMES();
    GLOBAL #GLOBAL_highestGrantedScheme = #GLOBAL_supportedSchemes[0];
    GLOBAL $GLOBAL_commandClasses = GETEPCOMMANDCLASSES($GLOBAL_endPointId);
    GLOBAL $GLOBAL_secureCommandClasses = GETEPSECURECOMMANDCLASSES($GLOBAL_endPointId);
    GLOBAL $GLOBAL_svIsInNIF = 0;
    GLOBAL $GLOBAL_ccIsInNIF = 0;
    GLOBAL $GLOBAL_lastSessionId = 63;

    GLOBAL #GLOBAL_endPointName = "Root Device";
    IF ($GLOBAL_endPointId != 0)
    {
        $msg = GETSTRINGBYTES("End Point ", "ascii");
        IF ($GLOBAL_endPointId >= 100) { $msg = ARRAYAPPEND($msg, ($GLOBAL_endPointId / 100) + 0x30); }
        IF ($GLOBAL_endPointId >= 10)  { $msg = ARRAYAPPEND($msg, (($GLOBAL_endPointId % 100) / 10 )+ 0x30); }
        $msg = ARRAYAPPEND($msg, ($GLOBAL_endPointId % 10) + 0x30);
        #GLOBAL_endPointName = GETBYTESTRING($msg, "ascii");
    }

    MSG ("Script tests the {0}.", #GLOBAL_endPointName);

    // Initialize Security Scheme
    MSG ("Assure to use the highest granted security scheme {0}.", #GLOBAL_highestGrantedScheme);
    IF (STRCMP(#GLOBAL_highestGrantedScheme, GETCURRENTSCHEME()) == false)
    {
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);
    }

    // Supervision: Analyze NIF
    MSG ("Supervision: Analyze Root Device NIF.");
    $commandClassesRoot = GETCOMMANDCLASSES();
    IF (INARRAY($commandClassesRoot, 0x6C) == true)
    {
        $GLOBAL_svIsInNIF = 1;
        MSG ("Supervision CC is in the Root Device NIF.");
    }
    ELSE
    {
        $GLOBAL_svIsInNIF = 0;
        MSG ("Supervision CC is NOT in the Root Device NIF.");
    }

    // Command Class Support: Analyze NIF / Supported Report of Root Device or End Point
    IF (INARRAY($GLOBAL_commandClasses, $GLOBAL_commandClassId) == true)
    {
        $GLOBAL_ccIsInNIF = 1;
        MSG ("{0} CC is non-securely supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }
    ELSEIF (INARRAY($GLOBAL_secureCommandClasses, $GLOBAL_commandClassId) == true)
    {
        $GLOBAL_ccIsInNIF = 1;
        MSG ("{0} CC is securely supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }
    IF ($GLOBAL_ccIsInNIF == 0)
    {
        MSG ("{0} CC is NOT advertised as supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }

TESTSEQ END


/**
 * SupportedIndicators
 * Lists all supported indicators and their properties
 * Checks support of Node Identify Indicator ID and Properties, mandatory for Z-Wave+ v2 nodes
 *
 * CC versions: 4 (CC Version 1...4)
 */

TESTSEQ SupportedIndicators: "Lists all supported indicators and their properties"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    $supportsNodeIdentifyID = 0;

    SEND ZwaveplusInfo.Get( );
    EXPECT ZwaveplusInfo.Report(
        $zwaveVersion = ZWaveVersion in (1, 2));

    // A controlling node SHOULD set the IndicatorId field to zero to discover the supported Indicator IDs.
    // A supporting node receiving this field set to 0x00 MUST advertise the first supported Indicator ID in response.
    SEND Indicator.SupportedGet(IndicatorId = 0);
    EXPECT Indicator.SupportedReport(
        $nextIndicatorId = IndicatorId in (1 ... 255),
        NextIndicatorId in (0 ... 255),
        $bitMaskLength = PropertySupportedBitMaskLength in (0 ... 31),
        Reserved == 0,
        $bitMask = PropertySupportedBitMask);

    IF ($nextIndicatorId == 0)    // No indicator IDs supported
    {
        MSGFAIL ("No Indicators supported.");
        EXITSEQ;
    }
    LOOP ($done; 0; 1)
    {
        MSG ("--- Indicator ID: {0} (0x{0:X2}) ---", UINT($nextIndicatorId));
        SEND Indicator.SupportedGet(IndicatorId = $nextIndicatorId);
        EXPECT Indicator.SupportedReport(
            $indicatorId = IndicatorId in (1 ... 255),
            $nextIndicatorId = NextIndicatorId in (0 ... 255),
            $bitMaskLength = PropertySupportedBitMaskLength in (0 ... 31),
            Reserved == 0,
            $bitMask = PropertySupportedBitMask);

        // List indicator data
        IF     ($indicatorId == 0x01) { MSG ("Indicator ID: {0} (0x{0:X2}): Armed", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x02) { MSG ("Indicator ID: {0} (0x{0:X2}): Not armed / disarmed", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x03) { MSG ("Indicator ID: {0} (0x{0:X2}): Ready", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x04) { MSG ("Indicator ID: {0} (0x{0:X2}): Fault", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x05) { MSG ("Indicator ID: {0} (0x{0:X2}): Busy", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x06) { MSG ("Indicator ID: {0} (0x{0:X2}): Enter ID", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x07) { MSG ("Indicator ID: {0} (0x{0:X2}): Enter PIN", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x08) { MSG ("Indicator ID: {0} (0x{0:X2}): Code Accepted", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x09) { MSG ("Indicator ID: {0} (0x{0:X2}): Code not accepted", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x0A) { MSG ("Indicator ID: {0} (0x{0:X2}): Armed Stay", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x0B) { MSG ("Indicator ID: {0} (0x{0:X2}): Armed Away", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x0C) { MSG ("Indicator ID: {0} (0x{0:X2}): Alarming", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x0D) { MSG ("Indicator ID: {0} (0x{0:X2}): Alarming: Burglar", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x0E) { MSG ("Indicator ID: {0} (0x{0:X2}): Alarming: Smoke / Fire", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x0F) { MSG ("Indicator ID: {0} (0x{0:X2}): Alarming: Carbon Monoxide", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x10) { MSG ("Indicator ID: {0} (0x{0:X2}): Bypass challenge", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x11) { MSG ("Indicator ID: {0} (0x{0:X2}): Entry delay", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x12) { MSG ("Indicator ID: {0} (0x{0:X2}): Exit delay", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x13) { MSG ("Indicator ID: {0} (0x{0:X2}): Alarming: Medical", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x14) { MSG ("Indicator ID: {0} (0x{0:X2}): Alarming: freeze warning", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x15) { MSG ("Indicator ID: {0} (0x{0:X2}): Alarming: Water leak", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x16) { MSG ("Indicator ID: {0} (0x{0:X2}): Alarming: Panic", UINT($indicatorId)); }

        ELSEIF (($indicatorId >= 0x20) && ($indicatorId <= 0x27)) { MSG ("Indicator ID: {0} (0x{0:X2}): Zone {1} armed", UINT($indicatorId), UINT($indicatorId - 0x1F)); }
        ELSEIF ($indicatorId == 0x30) { MSG ("Indicator ID: {0} (0x{0:X2}): LCD backlight", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x40) { MSG ("Indicator ID: {0} (0x{0:X2}): Button backlight letters", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x41) { MSG ("Indicator ID: {0} (0x{0:X2}): Button backlight digits", UINT($indicatorId)); }
        ELSEIF ($indicatorId == 0x42) { MSG ("Indicator ID: {0} (0x{0:X2}): Button backlight command", UINT($indicatorId)); }
        ELSEIF (($indicatorId >= 0x43) && ($indicatorId <= 0x4E)) { MSG ("Indicator ID: {0} (0x{0:X2}): Button {1} indication", UINT($indicatorId), UINT($indicatorId - 0x42)); }
        ELSEIF ($indicatorId == 0x50) { MSG ("Indicator ID: {0} (0x{0:X2}): Node Identify", UINT($indicatorId)); }
        ELSEIF (($indicatorId >= 0x60) && ($indicatorId <= 0x7F)) { MSG ("Indicator ID: {0} (0x{0:X2}): Generic event sound notification {1}", UINT($indicatorId), UINT($indicatorId - 0x5F)); }
        ELSEIF (($indicatorId >= 0x80) && ($indicatorId <= 0x9F)) { MSG ("Indicator ID: {0} (0x{0:X2}): Manufacturer defined indicator {1}", UINT($indicatorId), UINT($indicatorId - 0x7F)); }
        ELSEIF ($indicatorId == 0xF0) { MSG ("Indicator ID: {0} (0x{0:X2}): Buzzer", UINT($indicatorId)); }
        ELSE { MSG ("Unknown Indicator ID {0} (0x{0:X2}).", UINT($indicatorId)); }

        // Check Description (V4+) for Manufacturer defined indicators
        SEND Indicator.DescriptionGet(IndicatorId = $indicatorId);
        EXPECT Indicator.DescriptionReport(
            IndicatorId == $indicatorId,
            $descrLength = DescriptionLength in (0 ... 255),
            ANYBYTE(Description) in (0x00 ... 0xFF),
            $descr = Description);
        IF (UINT($descrLength) != LENGTH($descr))
        {
            MSGFAIL ("Invalid Description length. Reported: {0} - Real: {1}", UINT($descrLength), LENGTH($descr));
        }
        IF (($indicatorId >= 0x80) && ($indicatorId <= 0x9F))
        {
            #descr = GETBYTESTRING($descr, "utf-8");
            MSG ("Description (Length={0}): {1}", UINT($descrLength), $descr);
            MSG ("Description Text: {0}", #descr);
        }
        ELSE
        {
            IF ($descrLen != 0 || LENGTH($descr) != 0)
            {
                MSGFAIL ("Description MUST be empty (Length 0). Reported length: {0}", UINT($descrLength));
            }
        }

        MSG ("BitMask Length: {0} - BitMask (hex): {1}", UINT($bitMaskLength), $bitMask);
        IF ($bitMaskLength == 0)
        {
            MSGFAIL ("No BitMask received for Indicator {0} (0x{0:X2})", UINT($indicatorId));
        }
        IF ($bitMaskLength > 0)
        {
            IF (($bitMask[0] & 0x01) != 0) { MSGFAIL ("Bit 0 in bit Mask 1 is not allocated and MUST be set to 0"); }
            IF (($bitMask[0] & 0x02) != 0) { MSG ("Property 0x01: Multilevel / Indicating a specific level"); }
            IF (($bitMask[0] & 0x04) != 0) { MSG ("Property 0x02: Binary / Turning the indicator On or Off"); }
            IF (($bitMask[0] & 0x08) != 0) { MSG ("Property 0x03: Toggling / On/Off Periods"); }
            IF (($bitMask[0] & 0x10) != 0) { MSG ("Property 0x04: Toggling / On/Off Cycles"); }
            IF (($bitMask[0] & 0x20) != 0) { MSG ("Property 0x05: Toggling / On time within an On/Off period"); }
            IF (($bitMask[0] & 0x40) != 0) { MSG ("Property 0x06: Timeout / Timeout (minutes)"); }
            IF (($bitMask[0] & 0x80) != 0) { MSG ("Property 0x07: Timeout / Timeout (seconds)"); }
        }
        IF ($bitMaskLength > 1)
        {
            IF (($bitMask[1] & 0x01) != 0) { MSG ("Property 0x08: Timeout / Timeout (1/100 of seconds)"); }
            IF (($bitMask[1] & 0x02) != 0) { MSG ("Property 0x09: Multilevel Sound level / Indicating using a specific volume"); }
            IF (($bitMask[1] & 0x04) != 0) { MSG ("Property 0x0A: Timeout / Timeout (hours)"); }
            IF (($bitMask[1] & 0x08) != 0) { MSGFAIL ("Property invalid: 0x0B"); }
            IF (($bitMask[1] & 0x10) != 0) { MSGFAIL ("Property invalid: 0x0C"); }
            IF (($bitMask[1] & 0x20) != 0) { MSGFAIL ("Property invalid: 0x0D"); }
            IF (($bitMask[1] & 0x40) != 0) { MSGFAIL ("Property invalid: 0x0E"); }
            IF (($bitMask[1] & 0x80) != 0) { MSGFAIL ("Property invalid: 0x0F"); }
        }
        IF ($bitMaskLength > 2)
        {
            IF (($bitMask[2] & 0x01) != 0) { MSG ("Property 0x10: Advertise Low power / The supporting node can return to sleep even if the indicator ID is still active"); }
        }

        MSG ("NextIndicator ID: {0} (0x{0:X2})", UINT($nextIndicatorId));

        // Checking DT:00.11.0007.1 of SDS14224 (requirement for Root Device only)
        IF ($indicatorId == 0x50 && (($bitMask[0] & 0x08) != 0) && (($bitMask[0] & 0x10) != 0) && (($bitMask[0] & 0x20) != 0))
        {
            $supportsNodeIdentifyID = 1;
            MSG ("Node Identify Indicator is supported.");
        }

        IF ($nextIndicatorId == 0)    // Is it the last Indicator Supported Report?
        {
            BREAK;    // exit LOOP immediately (no more indicators)
        }
        $done = 0;    // continue LOOP with next valid indicator number
    } // LOOP ($done; 0; 1)

    IF ($zwaveVersion >= 2 && $supportsNodeIdentifyID == 0) { MSGFAIL ("Node Identify Indicator is not supported."); }

TESTSEQ END


/**
 * InitialValues
 * Lists the current values for each indicator
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ InitialValues: "Lists the current values for each indicator"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND Indicator.SupportedGet(IndicatorId = 0);
    EXPECT Indicator.SupportedReport(
        $nextIndicatorId = IndicatorId in (1 ... 255),
        NextIndicatorId in (0 ... 255),
        $bitMaskLength = PropertySupportedBitMaskLength in (0 ... 31),
        Reserved == 0,
        $bitMask = PropertySupportedBitMask);

    IF ($nextIndicatorId == 0)    // No indicator IDs supported?
    {
        MSGFAIL ("No Indicators supported.");
    }
    ELSE
    {
        LOOP ($done; 0; 1)
        {
            SEND Indicator.SupportedGet(IndicatorId = $nextIndicatorId);
            EXPECT Indicator.SupportedReport(
                $indicatorId = IndicatorId in (1 ... 255),
                $nextIndicatorId = NextIndicatorId in (0 ... 255),
                $bitMaskLength = PropertySupportedBitMaskLength in (0 ... 31),
                Reserved == 0,
                $bitMask = PropertySupportedBitMask);

            // Get current value
            SEND Indicator.Get(IndicatorId = $indicatorId);
            EXPECT Indicator.Report(
                $value0 = Indicator0Value in (0x00 ... 0xFF),
                $objCount = IndicatorObjectCount in (0x01 ... 0x1F),
                Reserved == 0,
                ANYBYTE(vg1) in (0x00 ... 0xFF),
                $objects = vg1);
            MSG ("Indicator 0 Value: {0} (0x{0:X2}) - ObjectCount: {1}", UINT($value0), UINT($objCount));
            LOOP ($obj; 0; $objCount - 1)
            {
                MSG ("Indicator ID: {0} (0x{0:X2}) - Property ID: {1} - Value: {2} (0x{3:X2})", $objects[3 * $obj], $objects[3 * $obj + 1], UINT($objects[3 * $obj + 2]), $objects[3 * $obj + 2]);
            }

            IF ($nextIndicatorId == 0)    // Is it the last Indicator Supported Report?
            {
                $done = 1;    // exit LOOP immediately (no more indicators)
            }
            ELSE
            {
                $done = 0;    // continue LOOP with next valid indicator number
            }
        } // LOOP ($done)
    } // Indicators advertised

TESTSEQ END


/**
 * IndividualValues
 * Try to set some individual values for some indicators
 *
 * PLEASE NOTE:
 * You MUST comment in and adjust the array variables $indicatorIds, $indicatorValuesN and $expectedValuesN
 * with DUT specific values. Check the DUT specification for valid values for the field 'Value'.
 *
 * CC versions: 2, 3, 4
 */

/*
TESTSEQ IndividualValues: "Try to set individual values"

    // Comment in and adjust the arrays $indicatorIds, $indicatorValuesN and $expectedValuesN
    // with values  according to the implemented Indicator functionality of the DUT.
    // Adjust the expected values according to the DUT specification. They may be identical
    // to $indicatorValues, but this is not mandatory.
    // It is possible and allowed to configure invalid $indicatorValuesN. The matching
    // $expectedValuesN MUST be set to the $indicatorValues of the previous valid step.

    // This test sequence is not applicable for the change of more than one Indicator values.

//    $indicatorIds     = [  8,   240,    3];
//    $propertyIds      = [0x02, 0x09, 0x05];
//    $indicatorValues1 = [0x00, 0x00, 0x00];
//    $expectedValues1  = [0x00, 0x00, 0x00];
//    $indicatorValues2 = [0xFF, 0xFF, 0xFF];
//    $expectedValues2  = [0xFF, 0xFF, 0xFF];
//    $indicatorValues3 = [0x00, 0x00, 0x00];
//    $expectedValues3  = [0x00, 0x00, 0x00];
//    $indicatorValues4 = [0x63, 0xC0, 0x80];
//    $expectedValues4  = [0x63, 0xC0, 0x80];
//    $indicatorValues5 = [0x00, 0x00, 0x00];
//    $expectedValues5  = [0x00, 0x00, 0x00];
    $numberOfSteps = 5; // This value MUST match the number of configured test steps

    $otherIdsThanIdentifyAvailable = 0;

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

        LOOP ($done; 0; 1)
        {
            SEND Indicator.SupportedGet(IndicatorId = 0);
            EXPECT Indicator.SupportedReport(
                $indicatorId = IndicatorId in (1 ... 255),
                $nextIndicatorId = NextIndicatorId in (0 ... 255),
                $bitMaskLength = PropertySupportedBitMaskLength in (0 ... 31),
                Reserved == 0,
                $bitMask = PropertySupportedBitMask);

            IF ($nextIndicatorId == 0)    // Is it the last Indicator Supported Report?
            {

                IF ($otherIdsThanIdentifyAvailable == 0)
                {
                    MSG ("No other indicator IDs than Identify supported. Skipping test sequence.");
                    EXITSEQ;
                }
                $done = 1;    // exit LOOP immediately (no more indicators)
            }
            ELSE
            {
                IF ($nextIndicatorId != 0x50)    // Other indicator IDs than Identify supported?
                {
                    $otherIdsThanIdentifyAvailable = 1;
                    MSG ("Other indicator IDs than Identify supported.");
                }
                $done = 0;    // continue LOOP with next valid indicator number
            }
        } // LOOP ($done)


    // Check for correct initialization of the test run
    IF (ISNULL($indicatorIds) || ISNULL($indicatorValues1) || ISNULL($expectedValues1))
    {
        MSGFAIL ("You MUST comment in and adjust the $indicatorIds, $indicatorValuesN and $expectedValuesN variables before running this test sequence!");
        EXITSEQ;
    }
    IF (LENGTH($indicatorValues1) != LENGTH($indicatorIds) || LENGTH($expectedValues1) != LENGTH($indicatorIds))
    {
        MSGFAIL ("The test sequence is not correctly configured (value mismatch). For details see header comment.");
        EXITSEQ;
    }

    LOOP ($indId; 0; LENGTH($indicatorIds) - 1) // LOOP for each configured Indicator ID
    {
        LOOP ($indValueStep; 1; $numberOfSteps) // LOOP for each configured test step
        {
            IF ($indValueStep == 1) { $indValues = $indicatorValues1; $expectedValues = $expectedValues1; }
            IF ($indValueStep == 2) { $indValues = $indicatorValues2; $expectedValues = $expectedValues2; }
            IF ($indValueStep == 3) { $indValues = $indicatorValues3; $expectedValues = $expectedValues3; }
            IF ($indValueStep == 4) { $indValues = $indicatorValues4; $expectedValues = $expectedValues4; }
            IF ($indValueStep == 5) { $indValues = $indicatorValues5; $expectedValues = $expectedValues5; }
            // MSG ("IndId {0} - PropId {1} - Value {2}", $indicatorIds[$indId], $propertyIds[$indId], $indValues[$indId]);
            SEND Indicator.Set(
                Indicator0Value = 0,
                IndicatorObjectCount = 1,
                Reserved = 1,
                vg1 = [$indicatorIds[$indId], $propertyIds[$indId], $indValues[$indId]]);

            WAIT (1000); // node reaction time and for tester's inspection

            SEND Indicator.Get(IndicatorId = $indicatorIds[$indId]);
            EXPECT Indicator.Report(
                $value0 = Indicator0Value in (0x00 ... 0xFF),
                $objCount = IndicatorObjectCount in (0x01 ... 0x1F),
                Reserved == 0,
                ANYBYTE(vg1) in (0x00 ... 0xFF),
                $objects = vg1);
            MSG ("Indicator 0 Value: {0} (0x{0:X2}) - ObjectCount: {1}", UINT($value0), UINT($objCount));
            LOOP ($obj; 0; $objCount - 1)
            {
                MSG ("Indicator ID: {0} - Property ID: {1} - Value: {2} (0x{3:X2})", $objects[3 * $obj], $objects[3 * $obj + 1], UINT($objects[3 * $obj + 2]), $objects[3 * $obj + 2]);
            }
            IF ($objCount == 1)
            {
                IF ($objects[2] != $expectedValues[$indId])
                {
                    MSGFAIL ("Reported value does not match expected value");
                }
            }
            ELSE
            {
                MSG ("Warning: IndicatorObjectCount > 1: Check value fields in report manually!");
            }

        } // LOOP ($indValueStep; 1; $numberOfSteps)
    } // LOOP ($indId; 0; LENGTH($indicatorIds) - 1)

TESTSEQ END
*/


/**
 * IndividualValuesNodeIdentify
 * Set individual values for properties 0x03, 0x04, 0x05 of Indicator ID 0x50 (Node Identify)
 *
 * CC versions: 3, 4
 */

TESTSEQ IndividualValuesNodeIdentify: "Set individual values for properties 0x03, 0x04, 0x05 of Indicator ID 0x50 (Node Identify)"

    // Each 'column' of the below arrays represents one test step.
    //
    // Step 1+2: Indicator is 0.5 seconds on and 0.5 seconds off for 3 times.
    // Step  3 : Indicator is 0.45 seconds on and 0.45 seconds off for 3 times.
    // Step  4 : Indicator is 0.8 seconds on and 0.2 seconds off for 4 times.
    // Step 5+6: Indicator is 1.0 seconds on and 1.0 seconds off for 2 times.
    // Step  7 : Indicator is 0.1 seconds on and 0.3 seconds off for 7 times.
    //
    // The following values MUST NOT be changed! Additional values MAY be added.

    // Toggling: On/Off Periods
    $property03Values = [0x0A, 0x0A, 0x09, 0x0A, 0x14, 0x14, 0x04];

    // Toggling: On/Off Cycles
    $property04Values = [0x03, 0x03, 0x03, 0x04, 0x02, 0x02, 0x07];

    // Toggling: On time within an On/Off period
    $property05Values = [0x05, 0x00, 0x00, 0x08, 0x0A, 0x00, 0x01];

    // Check if the Identify Indicator is supported, else skip test sequence
    SEND Indicator.SupportedGet(IndicatorId = 0x50);
    EXPECT Indicator.SupportedReport(
        $indicatorId = IndicatorId in (1 ... 255),
        NextIndicatorId in (0 ... 255),
        $bitMaskLength = PropertySupportedBitMaskLength in (0 ... 31),
        Reserved == 0);

    IF ($indicatorId == 0x50 && $bitMaskLength != 0)
    {
        MSG ("Node Identify Indicator is supported.");
    }
    ELSE
    {
        MSG ("Node Identify Indicator is not supported. Skipping test sequence.");
        EXITSEQ;
    }

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    IF ( ISNULL($property03Values) || LENGTH($property03Values) == 0 || LENGTH($property04Values) != LENGTH($property03Values) || LENGTH($property05Values) != LENGTH($property03Values) )
    {
        MSGFAIL ("The test sequence is not correctly configured (value mismatch in Indicator / Properties arrays).");
        EXITSEQ;
    }

    LOOP ($i; 0; LENGTH($property03Values) - 1) // LOOP for each configured Indicator ID
    {
        $vg1 = [0x50, 0x03, $property03Values[$i],
                0x50, 0x04, $property04Values[$i],
                0x50, 0x05, $property05Values[$i] ];

        SEND Indicator.Set(
            Indicator0Value = 0,
            IndicatorObjectCount = 3,
            Reserved = 1,
            vg1 = $vg1);

        WAIT (100); // node reaction time

        SEND Indicator.Get(IndicatorId = 0x50);
        EXPECT Indicator.Report(
            $value0 = Indicator0Value in (0x00 ... 0xFF),
            $objCount = IndicatorObjectCount in (0x01 ... 0x1F),
            Reserved == 0,
            ANYBYTE(vg1) in (0x00 ... 0xFF),
            $objects = vg1);

        MSG ("Indicator 0 Value: {0} (0x{0:X2}) - ObjectCount: {1} - Objects: {2}", UINT($value0), UINT($objCount), $objects);

        $prop3IsPresent = 0;
        $prop4IsPresent = 0;
        $prop5IsPresent = 0;

        LOOP ($obj; 0; $objCount - 1)
        {
            MSG ("Indicator ID: {0} (0x{0:X2}) - Property ID: {1} - Value: {2} (0x{3:X2})", $objects[3 * $obj], $objects[3 * $obj + 1], UINT($objects[3 * $obj + 2]), $objects[3 * $obj + 2]);

            IF ($objects[3 * $obj + 1] == 0x03)
            {
                $prop3IsPresent = 1;

                IF ($objects[3 * $obj + 2] != $property03Values[$i])
                {
                    MSGFAIL ("Mismatch in Property 0x03 values detected. Expected was: 0x{0:X2}", UINT($property03Values[$i]));
                }
            }

            IF ($objects[3 * $obj + 1] == 0x04)
            {
                $prop4IsPresent = 1;

                IF ($objects[3 * $obj + 2] != $property04Values[$i])
                {
                    MSGFAIL ("Mismatch in Property 0x04 values detected. Expected was: 0x{0:X2}", UINT($property04Values[$i]));
                }
            }

            IF ($objects[3 * $obj + 1] == 0x05)
            {
                $prop5IsPresent = 1;

                // This property is used to set the length of the On time during an On/Off period. It allows asymetic On/Off periods.

                $prop5ObjValue = UINT($objects[3 * $obj + 2]);

                IF ($property05Values[$i] == 0x00)
                {
                    // The set value 0x00 MUST represent symmetric On/Off period (On time equal to Off time).
                    // In this case, the actual value (half the On/Off period: Property 0x03 / 2) SHOULD be reported.

                    $prop03IsEven = 1;
                    $expProp05Values = ARRAYINIT(1);
                    $expProp05Values[0] = $property03Values[$i] / 2;
                    IF (($property03Values[$i] % 2) != 0)
                    {
                        // On/Off Period has an uneven value.
                        $prop03IsEven = 0;
                        $expProp05Values = ARRAYAPPEND($expProp05Values, $expProp05Values[0] + 1);
                    }

                    MSG ("Property 0x05 - On time within an On/Off period:");
                    MSG ("The set value 0x00 MUST represent symmetric On/Off period (On time equal to Off time).");
                    MSG ("In this case, the actual value (half the On/Off period, i.e. Property 03 value / 2) SHOULD be reported. Alternatively, 0x00 MAY be reported.");

                    IF ($prop5ObjValue == 0x00) // Alternatively, 0x00 MAY be reported.
                    {
                        MSG ("Warning: Property 0x05: The received value 0x00 is ALLOWED but NOT RECOMMENDED.");

                        IF ($prop03IsEven == 1)
                        {
                            MSG ("Warning: Property 0x05: Expected: 0x{0:X2}", UINT($expProp05Values[0]));
                        }
                        ELSE
                        {
                            MSG ("Warning: Property 0x05: Expected: 0x{0:X2} or 0x{1:X2}", UINT($expProp05Values[0]),  UINT($expProp05Values[1]));
                        }
                    }
                    ELSEIF (INARRAY($expProp05Values, $prop5ObjValue) != true)
                    {
                        MSGFAIL ("Property 0x05: The received value (0x{0:x2}) is wrong!", UINT($prop5ObjValue));

                        IF ($prop03IsEven == 1)
                        {
                            MSGFAIL ("Property 0x05: Expected: 0x{0:X2}", UINT($expProp05Values[0]));
                        }
                        ELSE
                        {
                            MSGFAIL ("Property 0x05: Expected: 0x{0:X2} or 0x{1:X2}", UINT($expProp05Values[0]),  UINT($expProp05Values[1]));
                        }
                    }
                }
                ELSEIF ($prop5ObjValue != $property05Values[$i])
                {
                    MSGFAIL ("Mismatch in Property 0x05 values detected. Expected: 0x{0:X2}", UINT($property05Values[$i]));
                }
            }
        }

        IF ($prop3IsPresent == 0) { MSGFAIL ("Property 0x03 value missing!"); }
        IF ($prop4IsPresent == 0) { MSGFAIL ("Property 0x04 value missing!"); }
        IF ($prop5IsPresent == 0) { MSGFAIL ("Property 0x05 value missing!"); }

        // Wait a time calculated from configured properties 03 and 04
        WAIT ($property03Values[$i] * 100 * $property04Values[$i]);

    } // LOOP ($i; 0; LENGTH($property03Values) - 1)

    MSG ("Finished.");

TESTSEQ END

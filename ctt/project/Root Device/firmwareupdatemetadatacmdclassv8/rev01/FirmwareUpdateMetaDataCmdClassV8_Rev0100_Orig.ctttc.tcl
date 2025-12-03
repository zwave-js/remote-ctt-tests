PACKAGE FirmwareUpdateMetaDataCmdClassV8_Rev0100_Orig; // do not modify this line
USE FirmwareUpdateMd CMDCLASSVER = 8;
USE Version CMDCLASSVER = 2;

/**
 * Firmware Update Meta Data Command Class Version 8 Test Script
 * Command Class Specification
 * Formatting Conventions: Version 2016-05-19
 *
 * PLEASE NOTE: This script cannot test the update process itself and the commands
 *              Firmware Update Activation Set Command/Status Report.
 *              Testers MUST perform additional tests with the Z-Wave PC Controller
 *              program and DUT-related firmware files.
 *
 * ChangeLog:
 *
 * May 11th, 2022      - Initial release, derived from V7_rev05.
 *                     - Reworked sequence 'InvalidFirmwareChecksum' into 'InvalidFwChecksumAndResumingAnUpdate' with two sub-tests:
 *                       #1 'Invalid Firmware Update' and #2 'Resuming a Firmware Update' for each upgradable target.
 *                     - Added sequence 'Interactive_NonSecureFirmwareUpdate'.
 * June 29th, 2022     - Consider if FW target is not upgradeable in 'InvalidFwChecksumAndResumingAnUpdate' and
 *                       'Interactive_NonSecureFirmwareUpdate'.
 */


/**
 * SetInitialValuesAndVariables
 * This sequence sets the global variables and initial values for the tests of this command class.
 * If it is not executed, this can lead to errors in the following test sequences.
 *
 * CC versions: 5, 6, 7, 8
 */

TESTSEQ SetInitialValuesAndVariables: "Set initial Values and Variables."

    // Test data - MUST NOT be changed
    GLOBAL $GLOBAL_commandClassId = 0x7A;
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Firmware Update Md";

    GLOBAL $GLOBAL_timeoutStatusReport = 200;    // Timeout for StatusReport in seconds (see header comment of sequence 'AbortedFirmwareUpdate')
                                                 // if update process was initiated.

    // Test environment configuration - MAY be changed

    // Device configuration - MAY be changed
    GLOBAL $GLOBAL_recoveryTime = 0;                    // Recovery Time in seconds. Some devices need a recovery time after this test.
    GLOBAL $GLOBAL_preparationTimeUpdate = 1;           // Time (in seconds) to prepare the firmware for update. MUST NOT be 0.
    GLOBAL $GLOBAL_preparationTimeRetrieve = 1;         // Time (in seconds) to prepare the firmware for retrieval. MUST NOT be 0.
    GLOBAL $GLOBAL_timeoutGetCommand = 25;              // Timeout (in seconds) for FirmwareUpdateMd.Get command.
    GLOBAL $GLOBAL_retrieveNumberOfReportsPerGet = 50;  // Range: 1...255  Default: 50

    // Device configuration - MUST NOT be changed
    GLOBAL $GLOBAL_waitTimeRetrieve = 0;         // Time (in milliseconds) before EXPECTing a report during retrieval. Default: 0 ms

    IF ($GLOBAL_preparationTimeUpdate   < 1) { MSGFAIL ("$GLOBAL_preparationTimeUpdate must be set to at least 1 (second)."); }
    IF ($GLOBAL_preparationTimeRetrieve < 1) { MSGFAIL ("$GLOBAL_preparationTimeRetrieve must be set to at least 1 (second)."); }

    // Security data - MUST NOT be changed
    GLOBAL $GLOBAL_schemeSetDelay = 0; // Testers only: Adjust temporarily, if the DUT needs a longer time for activating a Security Scheme
    GLOBAL #GLOBAL_supportedSchemes = GETSUPPORTEDSCHEMES();
    GLOBAL #GLOBAL_highestGrantedScheme = #GLOBAL_supportedSchemes[0];

    // Initialize Security Scheme
    MSG ("Assure to use the highest granted security scheme: {0}", #GLOBAL_highestGrantedScheme);
    IF (STRCMP(#GLOBAL_highestGrantedScheme, GETCURRENTSCHEME()) == false)
    {
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);
    }

TESTSEQ END


/**
 * GetCurrentFirmwareData
 * Report the meta data of the current firmware
 *
 * CC versions: 8
 */

TESTSEQ GetCurrentFirmwareData: "Report current firmware meta data"

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the SetInitialValuesAndVariables Test Sequence.");
        EXITSEQ;
    }

    SEND Version.Get( );
    EXPECT Version.Report(
        ZWaveLibraryType        in (0x01 ... 0x0B),
        ZWaveProtocolVersion    in (0x01 ... 0xFF),
        ZwaveProtocolSubVersion in (0x00 ... 0xFF),
        Firmware0Version        in (0x00 ... 0xFF),
        Firmware0SubVersion     in (0x00 ... 0xFF),
        $hardwareVersionV = HardwareVersion         in (0x00 ... 0xFF),
        $firmwareTargetsV = NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
        vg*/);

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion == $hardwareVersionV,
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    IF (ISNULL($manufacturerId)) { MSGFAIL ("Report missing"); }
    ELSE
    {
        MSG ("Manufacturer ID:      0x{0:X4}", UINT($manufacturerId));
        MSG ("Firmware 0 ID:        0x{0:X4}", UINT($firmware0Id));
        MSG ("Firmware 0 Checksum:  0x{0:X4}", UINT($firmware0Checksum));
        IF     ($firmwareUpgradable == 0xFF) { MSG     ("Firmware Upgradable:  0x{0:X2} (yes)", $firmwareUpgradable); }
        ELSEIF ($firmwareUpgradable == 0x00) { MSG     ("Firmware Upgradable:  0x{0:X2} (no)", $firmwareUpgradable); }
        ELSE                                 { MSGFAIL ("Firmware Upgradable:  0x{0:X2} (invalid, must be 0xFF or 0x00)", $firmwareUpgradable); }
        MSG ("Number of Fw Targets: 0x{0:X2} = {0}", UINT($numberOfFirmwareTargets));
        MSG ("Max Fragment Size:    0x{0:X4} = {0}", UINT($maxFragmentSize));
        MSG ("Hardware Version:     0x{0:X4} = {0}", $hardwareVersionF);
        MSG ("CC:                   0x{0:X2} = {0}", $cc);
        MSG ("Activation:           0x{0:X2} = {0}", $activation);
        IF ($hardwareVersionF != $hardwareVersionV)
        {
            MSGFAIL ("Hardware Version in Version Report (0x{0:X2}) does not match Hardware Version in Firmware Meta Data Report (0x{1:X2})",
                $hardwareVersionV, $hardwareVersionF);
        }
        IF ($numberOfFirmwareTargets != $firmwareTargetsV)
        {
            MSGFAIL ("Number Of Firmware Targets in Version Report (0x{0:X2}) does not match Number Of Firmware Targets in Firmware Meta Data Report (0x{1:X2})",
                $firmwareTargetsV, $numberOfFirmwareTargets);
        }
        IF ($numberOfFirmwareTargets > 0)
        {
            LOOP ($n; 0; $numberOfFirmwareTargets - 1)
            {
                $firmwareNId = UINT($firmwareIds[2 * $n])* 256 + UINT($firmwareIds[(2 * $n) + 1]);
                MSG ("Firmware {0} ID:        0x{1:X4}", $n + 1, UINT($firmwareNId));
                IF (UINT($firmware0Id) == UINT($firmwareNId))
                {
                    MSG ("Firmware {0} ID (0x{1:X4}) == Firmware 0 ID (0x{2:X4})", $n + 1, UINT($firmwareNId), UINT($firmware0Id));
                }
            }
        }
    }

TESTSEQ END


/**
 * InvalidTarget
 * Checks if the DUT sends a RequestReport with Status 0x03 target (not upgradable), if invalid
 * targets are addressed.
 *
 * CC versions: 8
 */

TESTSEQ InvalidTarget: "Check for correct behavior if invalid targets are addressed"

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the SetInitialValuesAndVariables Test Sequence.");
        EXITSEQ;
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    $firmwareTargets = [$numberOfFirmwareTargets + 1, $numberOfFirmwareTargets + 4];

    LOOP ($targetIdx; 0; LENGTH($firmwareTargets) - 1)
    {
        $firmwareTarget = $firmwareTargets[$targetIdx];
        IF (($firmwareTarget == 0x00) && ($firmwareUpgradable == 0x00))
        {
            MSG ("Test is not applicable for Firmware Target 0.");
        }
        ELSE
        {
            $testFirmwareId = $firmware0Id;
            // IF ($targetIdx == 0) { $testFirmwareId = $firmware0Id; }
            // ELSE                 { $testFirmwareId = $firmwareIds[($firmwareTargets[$targetIdx] - 1) * 2] * 256 + $firmwareIds[(($firmwareTargets[$targetIdx] - 1) * 2) + 1]; }

            LOOP ($i; 0; 0)
            {
                // Testing RequestGet (Firmware Update from controller to node)
                MSG ("Send RequestGet with invalid target 0x{0:X2}...", $firmwareTarget);
                SEND FirmwareUpdateMd.RequestGet(
                    ManufacturerId = CONV($manufacturerId, 2),
                    FirmwareId = CONV($testFirmwareId, 2),
                    Checksum = CONV(0x0001, 2),
                    FirmwareTarget = $firmwareTarget,
                    FragmentSize = CONV($maxFragmentSize, 2),
                    Activation = 0,
                    NonSecure = 0,
                    Resume = 0,
                    Reserved = 0x1F, // bit 3..7: 0b11111
                    HardwareVersion = $hardwareVersionF);
                EXPECT FirmwareUpdateMd.RequestReport(
                    $status = Status in (0x00, 0x03),
                    Reserved == 0,
                    NonSecure == 0,
                    Resume == 0,
                    Reserved1 == 0);

                IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: RequestReport frame missing", $firmwareTarget); }
                ELSEIF ($status == 0xFF) { MSGFAIL ("Target 0x{0:X2} Status 0xFF: Firmware update is initiated with invalid ID: Waiting {1} seconds for timeout...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport)); }
                ELSEIF ($status == 0x00) { MSGPASS ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
                ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
                ELSEIF ($status == 0x02) { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment size invalid", $firmwareTarget); }
                ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget); }
                ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
                ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
                ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
                ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

                // If the DUT starts the firmware update process, it must be lead to it's timeout to perform further tests
                IF ($status == 0xFF)
                {
                    MSG ("Cancelling the initiated Update for target 0x{0:X2} and the whole test. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                    EXPECT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        Status == 0x01,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));

                    IF (ISNULL($waitTime) || $waitTime == [])
                    {
                        MSGFAIL ("Status Report frame or Wait Time field missing");

                        MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                    }
                    ELSE
                    {
                        IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                        ELSE
                        {
                            MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                            WAIT (UINT($waitTime) * 1000);
                        }
                    }

                    $i = 99;                                  // exiting the inner LOOP
                    $targetIdx = LENGTH($firmwareTargets);    // exiting the outer LOOP
                }

                WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

                // Check whether DUT is alive
                SEND Version.Get( );
                EXPECT Version.Report(
                    $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                    ZWaveProtocolVersion    in (0x01 ... 0xFF),
                    ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                    Firmware0Version        in (0x00 ... 0xFF),
                    Firmware0SubVersion     in (0x00 ... 0xFF),
                    HardwareVersion         in (0x00 ... 0xFF),
                    NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                    vg*/);
                IF (ISNULL($versionLibraryType))
                {
                    MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }

                // Testing PrepareGet (Firmware Retrieve from node to controller)
                MSG ("Send PrepareGet with invalid Manufacturer ID and Firmware ID to target 0x{0:X2}...", $firmwareTarget);

                SEND FirmwareUpdateMd.PrepareGet(
                    ManufacturerId = CONV($manufacturerId, 2),
                    FirmwareId = CONV($testFirmwareId, 2),
                    FirmwareTarget = $firmwareTarget,
                    FragmentSize = CONV($maxFragmentSize, 2),
                    HardwareVersion = $hardwareVersionF);
                EXPECT FirmwareUpdateMd.PrepareReport($GLOBAL_preparationTimeUpdate,
                    $status = Status in (0x00, 0x03),
                    $firmwareChecksum = FirmwareChecksum in (0x0000 ... 0xFFFF));

                IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: PrepareReport frame missing", $firmwareTarget); }
                ELSEIF ($status == 0xFF) { MSGFAIL ("Target 0x{0:X2} Status 0xFF: Firmware transfer is initiated with invalid Fragment Size", $firmwareTarget, $fragmentSize); }
                ELSEIF ($status == 0x00) { MSGPASS ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
                ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
                ELSEIF ($status == 0x02) { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
                ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not downloadable", $firmwareTarget); }
                ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
                ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
                ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
                ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

                // If the DUT starts the firmware update process, it must be lead to it's timeout to perform further tests
                IF ($status == 0xFF)
                {
                    MSG ("Cancelling the initiated transfer for target 0x{0:X2} and the whole test. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                    EXPECT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        Status == 0x01,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));

                    IF (ISNULL($waitTime) || $waitTime == [])
                    {
                        MSGFAIL ("Status Report frame or Wait Time field missing");

                        MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                    }
                    ELSE
                    {
                        IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                        ELSE
                        {
                            MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                            WAIT (UINT($waitTime) * 1000);
                        }
                    }

                    $i = 99;                                  // exiting the inner LOOP
                    $targetIdx = LENGTH($firmwareTargets);    // exiting the outer LOOP
                } // IF ($status == 0xFF)

                WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

                // Check whether DUT is alive
                SEND Version.Get( );
                EXPECT Version.Report(
                    $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                    ZWaveProtocolVersion    in (0x01 ... 0xFF),
                    ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                    Firmware0Version        in (0x00 ... 0xFF),
                    Firmware0SubVersion     in (0x00 ... 0xFF),
                    HardwareVersion         in (0x00 ... 0xFF),
                    NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                    vg*/);
                IF (ISNULL($versionLibraryType))
                {
                    MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }

            } // LOOP ($i)
        } // Firmware target is upgradable
    } // LOOP ($targetIdx)

TESTSEQ END


/**
 * InvalidID
 * Checks if the DUT sends a RequestReport with Status 0x00 (Invalid IDs), if invalid Manufacturer ID and/or
 * Firmware ID and/or Hardware Version is provided:
 * The Firmware Update Meta Data Request Report Command MUST be returned in response to the Get command.
 * The DUT should return the status code 0x00, but we tolerate any ERROR status in that case, as long as it does not return 0xFF=OK.
 *
 * CC versions: 8
 */

TESTSEQ InvalidID: "Check for correct behavior if invalid IDs are provided"

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the SetInitialValuesAndVariables Test Sequence.");
        EXITSEQ;
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    IF     ($numberOfFirmwareTargets == 0) { $firmwareTargets = [0x00]; }
    ELSEIF ($numberOfFirmwareTargets == 1) { $firmwareTargets = [0x00, 0x01]; }
    ELSE                                   { $firmwareTargets = [0x00, 0x01, $numberOfFirmwareTargets]; }

    LOOP ($targetIdx; 0; LENGTH($firmwareTargets) - 1)
    {
        $firmwareTarget = $firmwareTargets[$targetIdx];
        IF (($firmwareTarget == 0x00) && ($firmwareUpgradable == 0x00))
        {
            MSG ("Test is not applicable for Firmware Target 0.");
        }
        ELSE
        {
            IF ($targetIdx == 0) { $testFirmwareId = $firmware0Id; }
            ELSE                 { $testFirmwareId = $firmwareIds[($firmwareTargets[$targetIdx] - 1) * 2] * 256 + $firmwareIds[(($firmwareTargets[$targetIdx] - 1) * 2) + 1]; }

            $testManufIds = [$manufacturerId + 1, $manufacturerId, $manufacturerId + 1, $manufacturerId, $manufacturerId];
            $testFirmwIds = [$testFirmwareId + 1, $testFirmwareId + 1, $testFirmwareId, $testFirmwareId, $testFirmwareId];
            $testHardVers = [$hardwareVersionF, $hardwareVersionF, $hardwareVersionF, (($hardwareVersionF + 1) & 0xFF), (($hardwareVersionF - 1) & 0xFF)];

            LOOP ($i; 0; LENGTH($testManufIds) - 1)
            {
                // Testing RequestGet (Firmware Update from controller to node)
                IF     ($i >= 3) { MSG ("Send RequestGet with invalid Hardware Version to target 0x{0:X2}...", $firmwareTarget); }
                ELSEIF ($i == 2) { MSG ("Send RequestGet with invalid Manufacturer ID to target 0x{0:X2}...", $firmwareTarget); }
                ELSEIF ($i == 1) { MSG ("Send RequestGet with invalid Firmware ID to target 0x{0:X2}...", $firmwareTarget); }
                ELSE             { MSG ("Send RequestGet with invalid Manufacturer ID and Firmware ID to target 0x{0:X2}...", $firmwareTarget); }

                SEND FirmwareUpdateMd.RequestGet(
                    ManufacturerId = CONV($testManufIds[$i], 2),
                    FirmwareId = CONV($testFirmwIds[$i], 2),
                    Checksum = CONV(0x0001, 2),
                    FirmwareTarget = $firmwareTarget,
                    FragmentSize = CONV($maxFragmentSize, 2),
                    Activation = 0,
                    NonSecure = 0,
                    Resume = 0,
                    Reserved = 0x1F, // bit 3..7: 0b11111
                    HardwareVersion = $testHardVers[$i]);
                EXPECT FirmwareUpdateMd.RequestReport(
                    $status = Status in (0x00, 0x03, 0x04),
                    Reserved == 0,
                    NonSecure == 0,
                    Resume == 0,
                    Reserved1 == 0);

                IF (ISNULL($status))                { MSGFAIL ("Target 0x{0:X2}: RequestReport frame missing", $firmwareTarget); }
                ELSEIF ($status == 0xFF)            { MSGFAIL ("Target 0x{0:X2} Status 0xFF: Firmware update is initiated with invalid ID: Waiting {1} seconds for timeout...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport)); }
                ELSEIF ($i <= 2 && $status == 0x00) { MSGPASS ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
                ELSEIF ($status == 0x01)            { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
                ELSEIF ($status == 0x02)            { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment size invalid", $firmwareTarget); }
                ELSEIF ($status == 0x03)            { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget); }
                ELSEIF ($i >= 3 && $status == 0x04) { MSGPASS ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
                ELSEIF ($status == 0x05)            { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
                ELSEIF ($status == 0x06)            { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
                ELSE                                { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

                // If the DUT starts the firmware update process, it must be lead to it's timeout to perform further tests
                IF ($status == 0xFF)
                {
                    MSG ("Cancelling the initiated Update for target 0x{0:X2} and the whole test. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                    EXPECT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        Status == 0x01,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));

                    IF (ISNULL($waitTime) || $waitTime == [])
                    {
                        MSGFAIL ("Status Report frame or Wait Time field missing");

                        MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                    }
                    ELSE
                    {
                        IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                        ELSE
                        {
                            MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                            WAIT (UINT($waitTime) * 1000);
                        }
                    }

                    $i = LENGTH($testManufIds);               // exiting the inner LOOP
                    $targetIdx = LENGTH($firmwareTargets);    // exiting the outer LOOP
                }

                WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

                // Check whether DUT is alive
                SEND Version.Get( );
                EXPECT Version.Report(
                    $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                    ZWaveProtocolVersion    in (0x01 ... 0xFF),
                    ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                    Firmware0Version        in (0x00 ... 0xFF),
                    Firmware0SubVersion     in (0x00 ... 0xFF),
                    HardwareVersion         in (0x00 ... 0xFF),
                    NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                    vg*/);
                IF (ISNULL($versionLibraryType))
                {
                    MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }

                // Testing PrepareGet (Firmware Retrieve from node to controller)
                IF     ($i >= 3) { MSG ("Send PrepareGet with invalid Hardware Version to target 0x{0:X2}...", $firmwareTarget); }
                ELSEIF ($i == 2) { MSG ("Send PrepareGet with invalid Manufacturer ID to target 0x{0:X2}...", $firmwareTarget); }
                ELSEIF ($i == 1) { MSG ("Send PrepareGet with invalid Firmware ID to target 0x{0:X2}...", $firmwareTarget); }
                ELSE             { MSG ("Send PrepareGet with invalid Manufacturer ID and Firmware ID to target 0x{0:X2}...", $firmwareTarget); }

                SEND FirmwareUpdateMd.PrepareGet(
                    ManufacturerId = CONV($testManufIds[$i], 2),
                    FirmwareId = CONV($testFirmwIds[$i], 2),
                    FirmwareTarget = $firmwareTarget,
                    FragmentSize = CONV($maxFragmentSize, 2),
                    HardwareVersion = $testHardVers[$i]);
                EXPECT FirmwareUpdateMd.PrepareReport($GLOBAL_preparationTimeUpdate,
                    $status = Status in (0x00, 0x03, 0x04),
                    $firmwareChecksum = FirmwareChecksum in (0x0000 ... 0xFFFF));

                IF (ISNULL($status))                { MSGFAIL ("Target 0x{0:X2}: PrepareReport frame missing", $firmwareTarget); }
                ELSEIF ($status == 0xFF)            { MSGFAIL ("Target 0x{0:X2} Status 0xFF: Firmware transfer is initiated with invalid Fragment Size", $firmwareTarget, $fragmentSize); }
                ELSEIF ($i <= 2 && $status == 0x00) { MSGPASS ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
                ELSEIF ($status == 0x01)            { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
                ELSEIF ($status == 0x02)            { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
                ELSEIF ($status == 0x03)            { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not downloadable", $firmwareTarget); }
                ELSEIF ($i >= 3 && $status == 0x04) { MSGPASS ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
                ELSEIF ($status == 0x05)            { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
                ELSEIF ($status == 0x06)            { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
                ELSE                                { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

                // If the DUT starts the firmware update process, it must be lead to it's timeout to perform further tests
                IF ($status == 0xFF)
                {
                    MSG ("Cancelling the initiated transfer for target 0x{0:X2} and the whole test. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                    EXPECT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        Status == 0x01,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));

                    IF (ISNULL($waitTime) || $waitTime == [])
                    {
                        MSGFAIL ("Status Report frame or Wait Time field missing");

                        MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                    }
                    ELSE
                    {
                        IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                        ELSE
                        {
                            MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                            WAIT (UINT($waitTime) * 1000);
                        }
                    }

                    $i = LENGTH($testManufIds);               // exiting the inner LOOP
                    $targetIdx = LENGTH($firmwareTargets);    // exiting the outer LOOP
                } // IF ($status == 0xFF)

                WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

                // Check whether DUT is alive
                SEND Version.Get( );
                EXPECT Version.Report(
                    $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                    ZWaveProtocolVersion    in (0x01 ... 0xFF),
                    ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                    Firmware0Version        in (0x00 ... 0xFF),
                    Firmware0SubVersion     in (0x00 ... 0xFF),
                    HardwareVersion         in (0x00 ... 0xFF),
                    NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                    vg*/);
                IF (ISNULL($versionLibraryType))
                {
                    MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }

            } // LOOP ($i)
        } // Firmware target is upgradable
    } // LOOP ($targetIdx)

TESTSEQ END


/**
 * InvalidFragmentSize
 * Checks if the DUT sends a RequestReport with Status 0x02, if invalid Fragment Size is provided
 *
 * CC versions: 8
 */

TESTSEQ InvalidFragmentSize: "Check for correct behavior if invalid Fragment Size is provided"

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the SetInitialValuesAndVariables Test Sequence.");
        EXITSEQ;
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    IF     ($numberOfFirmwareTargets == 0) { $firmwareTargets = [0x00]; }
    ELSEIF ($numberOfFirmwareTargets == 1) { $firmwareTargets = [0x00, 0x01]; }
    ELSE                                   { $firmwareTargets = [0x00, 0x01, $numberOfFirmwareTargets]; }

    LOOP ($targetIdx; 0; LENGTH($firmwareTargets) - 1)
    {
        $firmwareTarget = $firmwareTargets[$targetIdx];
        IF (($firmwareTarget == 0x00) && ($firmwareUpgradable == 0x00))
        {
            MSG ("Test is not applicable for Firmware Target 0.");
        }
        ELSE
        {
            $invFragmentSizes = [$maxFragmentSize + 1, 0xFFFF, 0];
            IF ($targetIdx == 0) { $testFirmwareId = $firmware0Id; }
            ELSE                 { $testFirmwareId = $firmwareIds[($firmwareTargets[$targetIdx] - 1) * 2] * 256 + $firmwareIds[(($firmwareTargets[$targetIdx] - 1) * 2) + 1]; }

            LOOP ($i; 0; LENGTH($invFragmentSizes) - 1)
            {
                $fragmentSize = $invFragmentSizes[$i];

                // Testing RequestGet (Firmware Update from controller to node)
                MSG ("Send RequestGet with invalid Fragment Size {0} to target 0x{1:X2}...", UINT($fragmentSize), $firmwareTarget);
                SEND FirmwareUpdateMd.RequestGet(
                    ManufacturerId = CONV($manufacturerId, 2),
                    FirmwareId = CONV($testFirmwareId, 2),
                    Checksum = CONV(0x0001, 2),
                    FirmwareTarget = $firmwareTarget,
                    FragmentSize = CONV($fragmentSize, 2),
                    Activation = 0,
                    NonSecure = 0,
                    Resume = 0,
                    Reserved = 0x1F, // bit 3..7: 0b11111
                    HardwareVersion = $hardwareVersionF);
                EXPECT FirmwareUpdateMd.RequestReport(
                    $status = Status in (0x02, 0x03),
                    Reserved == 0,
                    NonSecure == 0,
                    Resume == 0,
                    Reserved1 == 0);

                IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: RequestReport frame missing", $firmwareTarget); }
                ELSEIF ($status == 0xFF) { MSGFAIL ("Target 0x{0:X2} Status 0xFF: Firmware transfer is initiated with invalid Fragment Size", $firmwareTarget, $fragmentSize); }
                ELSEIF ($status == 0x00) { MSGFAIL ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
                ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
                ELSEIF ($status == 0x02) { MSGPASS ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
                ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget); }
                ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
                ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
                ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
                ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

                // If the DUT starts the firmware update process, it must be lead to it's timeout to perform further tests
                IF ($status == 0xFF)
                {
                    MSG ("Cancelling the initiated Update for target 0x{0:X2} and the whole test. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                    EXPECT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        Status == 0x01,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));

                    IF (ISNULL($waitTime) || $waitTime == [])
                    {
                        MSGFAIL ("Status Report frame or Wait Time field missing");

                        MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                    }
                    ELSE
                    {
                        IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                        ELSE
                        {
                            MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                            WAIT (UINT($waitTime) * 1000);
                        }
                    }

                    $i = LENGTH($invFragmentSizes);           // exiting the inner LOOP
                    $targetIdx = LENGTH($firmwareTargets);    // exiting the outer LOOP
                }

                WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

                // Check whether DUT is alive
                SEND Version.Get( );
                EXPECT Version.Report(
                    $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                    ZWaveProtocolVersion    in (0x01 ... 0xFF),
                    ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                    Firmware0Version        in (0x00 ... 0xFF),
                    Firmware0SubVersion     in (0x00 ... 0xFF),
                    HardwareVersion         in (0x00 ... 0xFF),
                    NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                    vg*/);
                IF (ISNULL($versionLibraryType))
                {
                    MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }

                // Testing PrepareGet (Firmware Retrieve from node to controller)
                MSG ("Send PrepareGet with invalid Fragment Size {0} to target 0x{1:X2}...", UINT($invFragmentSize), $firmwareTarget);
                SEND FirmwareUpdateMd.PrepareGet(
                    ManufacturerId = CONV($manufacturerId, 2),
                    FirmwareId = CONV($testFirmwareId, 2),
                    FirmwareTarget = $firmwareTarget,
                    FragmentSize = CONV($fragmentSize, 2),
                    HardwareVersion = $hardwareVersionF);
                EXPECT FirmwareUpdateMd.PrepareReport($GLOBAL_preparationTimeUpdate,
                    $status = Status in (0x02, 0x03),
                    $firmwareChecksum = FirmwareChecksum in (0x0000 ... 0xFFFF));

                IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: PrepareReport frame missing", $firmwareTarget); }
                ELSEIF ($status == 0xFF) { MSGFAIL ("Target 0x{0:X2} Status 0xFF: Firmware transfer is initiated with invalid Fragment Size", $firmwareTarget, $fragmentSize); }
                ELSEIF ($status == 0x00) { MSGFAIL ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
                ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
                ELSEIF ($status == 0x02) { MSGPASS ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
                ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not downloadable", $firmwareTarget); }
                ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
                ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
                ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
                ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

                // If the DUT starts the firmware update process, it must be lead to it's timeout to perform further tests
                IF ($status == 0xFF)
                {
                    MSG ("Cancelling the initiated transfer for target 0x{0:X2} and the whole test. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                    EXPECT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        Status == 0x01,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));

                    IF (ISNULL($waitTime) || $waitTime == [])
                    {
                        MSGFAIL ("Status Report frame or Wait Time field missing");

                        MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                    }
                    ELSE
                    {
                        IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                        ELSE
                        {
                            MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                            WAIT (UINT($waitTime) * 1000);
                        }
                    }

                    $i = LENGTH($invFragmentSizes);           // exiting the inner LOOP
                    $targetIdx = LENGTH($firmwareTargets);    // exiting the outer LOOP
                } // IF ($status == 0xFF)

                WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

                // Check whether DUT is alive
                SEND Version.Get( );
                EXPECT Version.Report(
                    $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                    ZWaveProtocolVersion    in (0x01 ... 0xFF),
                    ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                    Firmware0Version        in (0x00 ... 0xFF),
                    Firmware0SubVersion     in (0x00 ... 0xFF),
                    HardwareVersion         in (0x00 ... 0xFF),
                    NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                    vg*/);
                IF (ISNULL($versionLibraryType))
                {
                    MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }

            } // LOOP ($i)
        } // Firmware target is upgradable
    } // LOOP ($targetIdx)

TESTSEQ END


/**
 * InvalidTarget0Upgrade
 * Checks if the DUT sends a RequestReport with Status 0x03, if target 0 is not upgradable
 *
 * CC versions: 8
 */

TESTSEQ InvalidTarget0Upgrade: "Check behavior if target 0 is not upgradable"

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the SetInitialValuesAndVariables Test Sequence.");
        EXITSEQ;
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    IF ($firmwareUpgradable == 0x00)
    {
        $firmwareTarget = 0;
        MSG ("Try to upgrade a non-upgradable target 0...");
        SEND FirmwareUpdateMd.RequestGet(
            ManufacturerId = CONV($manufacturerId, 2),
            FirmwareId = CONV($firmware0Id, 2),
            Checksum = CONV(0x0001, 2),
            FirmwareTarget = $firmwareTarget,
            FragmentSize = CONV($maxFragmentSize, 2),
            Activation = 0,
            NonSecure = 0,
            Resume = 0,
            Reserved = 0x1F, // bit 3..7: 0b11111
            HardwareVersion = $hardwareVersionF);
        EXPECT FirmwareUpdateMd.RequestReport(
            $status = Status == 0x03,
            Reserved == 0,
            NonSecure == 0,
            Resume == 0,
            Reserved1 == 0);

        IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: RequestReport frame missing", $firmwareTarget); }
        ELSEIF ($status == 0xFF) { MSGFAIL ("Target 0x{0:X2} Status 0xFF: Firmware update is initiated", $firmwareTarget); }
        ELSEIF ($status == 0x00) { MSGFAIL ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
        ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
        ELSEIF ($status == 0x02) { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
        ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget); }
        ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
        ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
        ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
        ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

        // If the DUT starts the update process, it must be lead to it's timeout to perform further tests
        IF ($status == 0xFF)
        {
            MSG ("Cancelling the initiated update for target 0x{0:X2} and the whole test. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
            EXPECT FirmwareUpdateMd.StatusReport(
                $GLOBAL_timeoutStatusReport,
                Status == 0x01,
                $waitTime = Waittime in (0x0000 ... 0xFFFE));

            IF (ISNULL($waitTime) || $waitTime == [])
            {
                MSGFAIL ("Status Report frame or Wait Time field missing");

                MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
            }
            ELSE
            {
                IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                ELSE
                {
                    MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                    WAIT (UINT($waitTime) * 1000);
                }
            }
        }

        WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

        // Check whether DUT is alive
        SEND Version.Get( );
        EXPECT Version.Report(
            $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
            ZWaveProtocolVersion    in (0x01 ... 0xFF),
            ZwaveProtocolSubVersion in (0x00 ... 0xFF),
            Firmware0Version        in (0x00 ... 0xFF),
            Firmware0SubVersion     in (0x00 ... 0xFF),
            HardwareVersion         in (0x00 ... 0xFF),
            NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
            vg*/);
        IF (ISNULL($versionLibraryType))
        {
            MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

            MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
        }
    }
    ELSE
    {
        MSG ("Test is not applicable.");
    }

TESTSEQ END


/**
 * AbortedFirmwareUpdate
 * Checks if the DUT sends a StatusReport with Status 'Aborted', if transmission fails:
 * A device receiving data SHOULD stop retransmitting Firmware Update Meta Data Get commands 2 minutes
 * after the last successful reception of a Firmware Update Meta Data Report Command.
 *
 * CC versions: 8
 */

TESTSEQ AbortedFirmwareUpdate: "Check for correct behavior if transmission fails"

    $firmwareChecksum = 0x0002;        // This is a checksum for RequestGet.

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the SetInitialValuesAndVariables Test Sequence.");
        EXITSEQ;
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    IF     ($numberOfFirmwareTargets == 0) { $firmwareTargets = [0x00]; }
    ELSEIF ($numberOfFirmwareTargets == 1) { $firmwareTargets = [0x00, 0x01]; }
    ELSE                                   { $firmwareTargets = [0x00, 0x01, $numberOfFirmwareTargets]; }

    LOOP ($targetIdx; 0; LENGTH($firmwareTargets) - 1)
    {
        $firmwareTarget = $firmwareTargets[$targetIdx];
        IF (($firmwareTarget == 0x00) && ($firmwareUpgradable == 0x00))
        {
            MSG ("Test is not applicable for Firmware Target 0.");
        }
        ELSE
        {
            IF ($targetIdx == 0) { $testFirmwareId = $firmware0Id; }
            ELSE                 { $testFirmwareId = $firmwareIds[($firmwareTargets[$targetIdx] - 1) * 2] * 256 + $firmwareIds[(($firmwareTargets[$targetIdx] - 1) * 2) + 1]; }

            MSG ("Send RequestGet to target 0x{0:X2}...", $firmwareTarget);
            SEND FirmwareUpdateMd.RequestGet(
                ManufacturerId = CONV($manufacturerId, 2),
                FirmwareId = CONV($testFirmwareId, 2),
                Checksum = CONV($firmwareChecksum, 2),
                FirmwareTarget = $firmwareTarget,
                FragmentSize = CONV($maxFragmentSize, 2),
                Activation = 0,
                NonSecure = 0,
                Resume = 0,
                Reserved = 0x1F, // bit 3..7: 0b11111,
                HardwareVersion = $hardwareVersionF);
            EXPECT FirmwareUpdateMd.RequestReport(
                $status = Status in (0xFF, 0x03),
                Reserved == 0,
                NonSecure == 0,
                Resume == 0,
                Reserved1 == 0);

            IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: RequestReport frame missing", $firmwareTarget); }
            ELSEIF ($status == 0xFF) { MSGPASS ("Target 0x{0:X2} Status 0xFF: Firmware update is initiated", $firmwareTarget); }
            ELSEIF ($status == 0x00) { MSGFAIL ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
            ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
            ELSEIF ($status == 0x02) { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
            ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget); }
            ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
            ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
            ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
            ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

            IF ($status == 0xFF)
            {
                MSG ("Expecting a Get command for 1st firmware fragment of target 0x{0:X2}...", $firmwareTarget);
                EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                    $numberOfReports = NumberOfReports in (0 ... 255),
                    $reportNumber1 = ReportNumber1 == 0,
                    Res == 0,
                    $reportNumber2 = ReportNumber2 == 1);
                $reportNumber = $reportNumber1 * 256 + $reportNumber2;

                MSG ("Number of requested reports: {0} - Requested starting report number: {1}", UINT($numberOfReports), UINT($reportNumber));

                MSG ("End of test for target 0x{0:X2}. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                EXPECT FirmwareUpdateMd.StatusReport(
                    $GLOBAL_timeoutStatusReport,
                    Status == 0x01,
                    $waitTime = Waittime in (0x0000 ... 0xFFFE));

                IF (ISNULL($waitTime) || $waitTime == [])
                {
                    MSGFAIL ("Status Report frame or Wait Time field missing");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }
                ELSE
                {
                    IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                    ELSE
                    {
                        MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                        WAIT (UINT($waitTime) * 1000);
                    }
                }
                // USE NoOperation CMDCLASSVER = 1;
                // SENDRAW NoOperation( )

            } // IF ($status == 0xFF)

            WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

            // Check whether DUT is alive
            SEND Version.Get( );
            EXPECT Version.Report(
                $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                ZWaveProtocolVersion    in (0x01 ... 0xFF),
                ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                Firmware0Version        in (0x00 ... 0xFF),
                Firmware0SubVersion     in (0x00 ... 0xFF),
                HardwareVersion         in (0x00 ... 0xFF),
                NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                vg*/);
            IF (ISNULL($versionLibraryType))
            {
                MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
            }

        } // Firmware target is upgradable
    } // LOOP ($targetIdx)

TESTSEQ END


/**
 * InvalidChecksumAndFragment
 * Checks the behavior if an invalid checksum and/or an invalid fragment number is provided.
 *
 * CRC calculator: https://www.lammertbies.nl/comm/info/crc-calculation.html
 * Another CRC calculator: www.zorc.breitbandkatze.de/crc.html
 *
 * CC versions: 8
 */

TESTSEQ InvalidChecksumAndFragment: "Check for correct behavior if invalid checksum or fragment number is provided"

    $firmwareDataBytes = [0x30, 0x30, 0x30];
    $validFirmwareChecksum = 0xE76F;   // This is the valid checksum in RequestGet for the used firmware data bytes (3 bytes in 1 report).
    $invalidFirmwareChecksum = 0xFFFF; // This is an invalid checksum in RequestGet for the used firmware data bytes (3 bytes in 1 report).
    //$validReportChecksum = 0x626B;     // This is the valid checksum for the used Report Command: report #1 with Last=0 (7A 06 00 01  30 30 30)
    $validReport2Checksum = 0xF9B7;    // This is the valid checksum for the used Report Command: report #2 with Last=0 (7A 06 00 02  30 30 30)
    $invalidReportChecksum = 0xEEEE;   // This is an invalid checksum for the used Report Command.
    $recoveryRequestGet =  2;          // Timeout before RequestGet command (in seconds). You MAY increase this value.

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the SetInitialValuesAndVariables Test Sequence.");
        EXITSEQ;
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    IF     ($numberOfFirmwareTargets == 0) { $firmwareTargets = [0x00]; }
    ELSEIF ($numberOfFirmwareTargets == 1) { $firmwareTargets = [0x00, 0x01]; }
    ELSE                                   { $firmwareTargets = [0x00, 0x01, $numberOfFirmwareTargets]; }

    LOOP ($targetIdx; 0; LENGTH($firmwareTargets) - 1)
    {
        $firmwareTarget = $firmwareTargets[$targetIdx];
        IF (($firmwareTarget == 0x00) && ($firmwareUpgradable == 0x00))
        {
            MSG ("Test is not applicable for Firmware Target 0.");
        }
        ELSE
        {
            IF ($targetIdx == 0) { $testFirmwareId = $firmware0Id; }
            ELSE                 { $testFirmwareId = $firmwareIds[($firmwareTargets[$targetIdx] - 1) * 2] * 256 + $firmwareIds[(($firmwareTargets[$targetIdx] - 1) * 2) + 1]; }

            MSG ("Send RequestGet to target 0x{0:X2}...", $firmwareTarget);
            SEND FirmwareUpdateMd.RequestGet(
                ManufacturerId = CONV($manufacturerId, 2),
                FirmwareId = CONV($testFirmwareId, 2),
                Checksum = CONV($invalidFirmwareChecksum, 2),
                FirmwareTarget = $firmwareTarget,
                FragmentSize = CONV(LENGTH($firmwareDataBytes), 2),
                Activation = 0,
                NonSecure = 0,
                Resume = 0,
                Reserved = 0x1F, // bit 3..7: 0b11111
                HardwareVersion = $hardwareVersionF);
            EXPECT FirmwareUpdateMd.RequestReport(
                $status = Status in (0xFF, 0x03),
                Reserved == 0,
                NonSecure == 0,
                Resume == 0,
                Reserved1 == 0);

            IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: RequestReport frame missing", $firmwareTarget); }
            ELSEIF ($status == 0xFF) { MSGPASS ("Target 0x{0:X2} Status 0xFF: Firmware update is initiated", $firmwareTarget); }
            ELSEIF ($status == 0x00) { MSGFAIL ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
            ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
            ELSEIF ($status == 0x02) { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
            ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget); }
            ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
            ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
            ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
            ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

            IF ($status == 0xFF)
            {
                MSG ("Expecting a Get command for 1st firmware fragment (Report Number = 1) of target 0x{0:X2}...", $firmwareTarget);
                EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                    $numberOfReports = NumberOfReports in (0 ... 255),
                    $reportNumber1 = ReportNumber1 == 0,
                    Res == 0,
                    $reportNumber2 = ReportNumber2 == 1);
                $reportNumber = $reportNumber1 * 256 + $reportNumber2;
                MSG ("Number of requested reports: {0} - Requested starting report number: {1}", UINT($numberOfReports), UINT($reportNumber));
                IF ($reportNumber != 1)
                {
                    MSGFAIL ("Requested starting report number {0} is invalid (expected: 1)", UINT($reportNumber));
                }

                // part 1: firmware fragment with valid fragment number 1 and invalid checksum
                MSG ("TEST 1: Sending a firmware fragment with valid fragment number and invalid checksum...");
                SEND FirmwareUpdateMd.Report(
                    ReportNumber1 = $reportNumber1,
                    Last = 0,
                    ReportNumber2 = $reportNumber2,
                    Data = $firmwareDataBytes,
                    Checksum = CONV($invalidReportChecksum, 2));

                // DUT must answer with a FirmwareUpdateMd.Get (retry) or FirmwareUpdateMd.StatusReport (if it implements retries=0)
                MSG ("Expecting a Status Report or a Get command for 1st firmware fragment (Report Number = 1) again...");
                $reportedStatus = 999999;
                EXPECTOPT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                    $numberOfReports = NumberOfReports in (0 ... 255),
                    $reportNumber1 = ReportNumber1 == 0,
                    Res == 0,
                    $reportNumber2 = ReportNumber2 == 1);
                IF (ISNULL($reportNumber2))
                {
                    EXPECTOPT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        $reportedStatus = Status == 0x00,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));
                }
                ELSE
                {
                    $reportNumber = $reportNumber1 * 256 + $reportNumber2;
                    MSG ("Number of requested reports: {0} - Requested starting report number: {1}", UINT($numberOfReports), UINT($reportNumber));
                    IF ($reportNumber != 1)
                    {
                        MSGFAIL ("Requested starting report number {0} is invalid (expected: 1)", UINT($reportNumber));
                    }
                }

                // part 2: firmware fragment with invalid fragment number (Report Number = 2) and invalid checksum
                // Restart firmware transfer if necessary (retries == 0)
                IF ($reportedStatus != 999999)
                {
                    IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                    ELSE
                    {
                        MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                        WAIT (UINT($waitTime) * 1000);
                    }

                    WAIT ($recoveryRequestGet * 1000);
                    MSG ("Send RequestGet to target 0x{0:X2}...", $firmwareTarget);
                    SEND FirmwareUpdateMd.RequestGet(
                        ManufacturerId = CONV($manufacturerId, 2),
                        FirmwareId = CONV($testFirmwareId, 2),
                        Checksum = CONV($invalidFirmwareChecksum, 2),
                        FirmwareTarget = $firmwareTarget,
                        FragmentSize = CONV(LENGTH($firmwareDataBytes), 2),
                        Activation = 0,
                        NonSecure = 0,
                        Resume = 0,
                        Reserved = 0x1F, // bit 3..7: 0b11111
                        HardwareVersion = $hardwareVersionF);
                    EXPECT FirmwareUpdateMd.RequestReport(
                        $status = Status in (0xFF, 0x03),
                        Reserved == 0,
                        NonSecure == 0,
                        Resume == 0,
                        Reserved1 == 0);

                    $reportNumber1 = 0;
                    $reportNumber2 = 1;
                }
                MSG ("TEST 2: Sending a firmware fragment with invalid fragment number (Report Number = 2) and invalid checksum...");
                SEND FirmwareUpdateMd.Report(
                    ReportNumber1 = $reportNumber1,
                    Last = 0,
                    ReportNumber2 = $reportNumber2 + 1,
                    Data = $firmwareDataBytes,
                    Checksum = CONV($invalidReportChecksum, 2));

                // DUT must answer with a FirmwareUpdateMd.Get (retry) or FirmwareUpdateMd.StatusReport (if it implements retries=0)
                MSG ("Expecting a Status Report or a Get command for 1st firmware fragment (Report Number = 1) again...");
                $reportedStatus = 999999;
                EXPECTOPT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                    $numberOfReports = NumberOfReports in (0 ... 255),
                    $reportNumber1 = ReportNumber1 == 0,
                    Res == 0,
                    $reportNumber2 = ReportNumber2 == 1);
                IF (ISNULL($reportNumber2))
                {
                    EXPECTOPT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        $reportedStatus = Status in (0x00, 0x01),
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));
                }
                ELSE
                {
                    $reportNumber = $reportNumber1 * 256 + $reportNumber2;
                    MSG ("Number of requested reports: {0} - Requested starting report number: {1}", UINT($numberOfReports), UINT($reportNumber));
                    IF ($reportNumber != 1)
                    {
                        MSGFAIL ("Requested starting report number {0} is invalid (expected: 1)", UINT($reportNumber));
                    }
                }

                // part 3: firmware fragment with invalid fragment number (Report Number = 2) and valid checksum
                // Restart firmware transfer if necessary (retries == 0)
                IF ($reportedStatus != 999999)
                {
                    IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                    ELSE
                    {
                        MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                        WAIT (UINT($waitTime) * 1000);
                    }

                    WAIT ($recoveryRequestGet * 1000);
                    MSG ("Send RequestGet to target 0x{0:X2}...", $firmwareTarget);
                    SEND FirmwareUpdateMd.RequestGet(
                        ManufacturerId = CONV($manufacturerId, 2),
                        FirmwareId = CONV($testFirmwareId, 2),
                        Checksum = CONV($invalidFirmwareChecksum, 2),
                        FirmwareTarget = $firmwareTarget,
                        FragmentSize = CONV(LENGTH($firmwareDataBytes), 2),
                        Activation = 0,
                        NonSecure = 0,
                        Resume = 0,
                        Reserved = 0x1F, // bit 3..7: 0b11111,
                        HardwareVersion = $hardwareVersionF);
                    EXPECT FirmwareUpdateMd.RequestReport(
                        $status = Status in (0xFF, 0x03),
                        Reserved == 0,
                        NonSecure == 0,
                        Resume == 0,
                        Reserved1 == 0);

                    $reportNumber1 = 0;
                    $reportNumber2 = 1;
                }

                MSG ("TEST 3: Sending a firmware fragment with invalid fragment number (Report Number = 2) and valid checksum...");
                SEND FirmwareUpdateMd.Report(
                    ReportNumber1 = $reportNumber1,
                    Last = 0,
                    ReportNumber2 = $reportNumber2 + 1,
                    Data = $firmwareDataBytes,
                    Checksum = CONV($validReport2Checksum, 2));

                // DUT must answer with a FirmwareUpdateMd.Get (retry) or FirmwareUpdateMd.StatusReport (if it implements retries=0)
                MSG ("Expecting a Status Report or a Get command for 1st firmware fragment (Report Number = 1) again...");
                $reportedStatus = 999999;
                EXPECTOPT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                    $numberOfReports = NumberOfReports in (0 ... 255),
                    $reportNumber1 = ReportNumber1 == 0,
                    Res == 0,
                    $reportNumber2 = ReportNumber2 == 1);
                IF (ISNULL($reportNumber2))
                {
                    EXPECTOPT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        $reportedStatus = Status in (0x00, 0x01),
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));
                }
                ELSE
                {
                    $reportNumber = $reportNumber1 * 256 + $reportNumber2;
                    MSG ("Number of requested reports: {0} - Requested starting report number: {1}", UINT($numberOfReports), UINT($reportNumber));
                    IF ($reportNumber != 1)
                    {
                        MSGFAIL ("Requested starting report number {0} is invalid (expected: 1)", UINT($reportNumber));
                    }
                }

                // final: wait for Status Report, if pending
                IF ($reportedStatus == 999999)
                {
                    MSG ("End of test for target 0x{0:X2}. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                    EXPECT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        Status == 0x01,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));

                    IF (ISNULL($waitTime) || $waitTime == [])
                    {
                        MSGFAIL ("Status Report frame or Wait Time field missing");

                        MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                    }
                    ELSE
                    {
                        IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                        ELSE
                        {
                            MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                            WAIT (UINT($waitTime) * 1000);
                        }
                    }
                }
                // USE NoOperation CMDCLASSVER = 1;
                // SENDRAW NoOperation( )
            } // IF ($status == 0xFF)

            WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

            // Check whether DUT is alive
            SEND Version.Get( );
            EXPECT Version.Report(
                $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                ZWaveProtocolVersion    in (0x01 ... 0xFF),
                ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                Firmware0Version        in (0x00 ... 0xFF),
                Firmware0SubVersion     in (0x00 ... 0xFF),
                HardwareVersion         in (0x00 ... 0xFF),
                NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                vg*/);
            IF (ISNULL($versionLibraryType))
            {
                MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
            }

        } // Firmware target is upgradable
    } // LOOP ($targetIdx)

TESTSEQ END


/**
 * InvalidFwChecksumAndResumingAnUpdate
 * Sub-test #1 'Invalid Firmware Checksum': Verifies behavior if firmware checksum is invalid.
 * Sub-test #2 'Resuming a Firmware Update': Verifies behavior regarding the 'Resume' flag after a previously aborted update.
 *
 * CRC calculator: https://www.lammertbies.nl/comm/info/crc-calculation.html
 * Another CRC calculator: www.zorc.breitbandkatze.de/crc.html
 *
 * CC versions: 8
 */

TESTSEQ InvalidFwChecksumAndResumingAnUpdate: "Verify behavior if firmware checksum is invalid and resuming a previously aborted update"

    $validFirmwareChecksum = 0xE76F;   // This is the valid checksum in RequestGet for the used firmware data bytes (3 bytes in 1 report).
    $invalidFirmwareChecksum = 0xFFFF; // This is an invalid checksum in RequestGet for the used firmware data bytes (3 bytes in 1 report).
    $validReportChecksum = 0x626B;     // This is the valid checksum for the used Report Command: report #1 with Last=0 (7A 06 00 01  30 30 30)
    $invalidReportChecksum = 0xEEEE;   // This is an invalid checksum for the used Report Command.

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the 'SetInitialValuesAndVariables' Test Sequence.");
        EXITSEQ;
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    IF     ($numberOfFirmwareTargets == 0) { $firmwareTargets = [0x00]; }
    ELSEIF ($numberOfFirmwareTargets == 1) { $firmwareTargets = [0x00, 0x01]; }
    ELSE                                   { $firmwareTargets = [0x00, 0x01, $numberOfFirmwareTargets]; }

    LOOP ($targetIdx; 0; LENGTH($firmwareTargets) - 1)
    {
        $firmwareTarget = $firmwareTargets[$targetIdx];
        IF (($firmwareTarget == 0x00) && ($firmwareUpgradable == 0x00))
        {
            MSG ("Test is not applicable for Firmware Target 0.");

            CONTINUE;
        }


        // SUB-TEST #1: INVALID FIRMWARE CHECKSUM

        MSG ("SUB-TEST #1: INVALID FIRMWARE CHECKSUM");

        IF ($targetIdx == 0) { $testFirmwareId = $firmware0Id; }
        ELSE                 { $testFirmwareId = $firmwareIds[($firmwareTargets[$targetIdx] - 1) * 2] * 256 + $firmwareIds[(($firmwareTargets[$targetIdx] - 1) * 2) + 1]; }

        // Here we try to give two fragments, both with the correct fragment checksum, but not matching
        // the actual Firmware Update checksum given initially in FirmwareUpdateMd.RequestGet. In that case,
        // the DUT is expected to return a FirmwareUpdateMd.StatusReport(Status=0x00), but we tolerate 0x01.
        // The checksum covers the fields Command Class, Command, RepNr1+Last, RepNr2, and Data (7A 06 nn nn xx xx xx ...).
        // The checksum algorithm is CRC-CCITT with initial value 0x1D0F and polynomium 0x1021.
        //
        // First  Report (Last=0):  7A 06 00 01 30 30 30    62 6B
        // First  Report (Last=1):  7A 06 80 01 30 30 30    40 BB
        // Second Report (Last=1):  7A 06 80 02 30 30 30    DB 67
        // Complete firmware checksum: 30 30 30 30 30 30    C8 D6
        $data = [0x30, 0x30, 0x30];
        $usedFirmwareChecksum = 0x0055; // This is an invalid checksum in RequestGet for the used firmware data bytes (all bytes of all reports).
     // $usedFirmwareChecksum = 0xC8D6; // This is the valid checksum! Handle with care!

        MSG ("Send RequestGet to target 0x{0:X2}...", $firmwareTarget);
        MSG ("Used firmware checksum 0x{0:X4} is invalid.", $usedFirmwareChecksum);

        SEND FirmwareUpdateMd.RequestGet(
            ManufacturerId = CONV($manufacturerId, 2),
            FirmwareId = CONV($testFirmwareId, 2),
            Checksum = CONV($usedFirmwareChecksum, 2),
            FirmwareTarget = $firmwareTarget,
            FragmentSize = CONV(LENGTH($data), 2),
            Activation = 0,
            NonSecure = 0,
            Resume = 0,
            Reserved = 0x1F, // bit 3..7: 0b11111,
            HardwareVersion = $hardwareVersionF);
        EXPECT FirmwareUpdateMd.RequestReport(
            $status = Status in (0xFF, 0x03),
            Reserved == 0,
            NonSecure == 0,
            Resume == 0,
            Reserved1 == 0);

        IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: RequestReport frame missing", $firmwareTarget); }
        ELSEIF ($status == 0xFF) { MSGPASS ("Target 0x{0:X2} Status 0xFF: Firmware update is initiated", $firmwareTarget); }
        ELSEIF ($status == 0x00) { MSGFAIL ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
        ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
        ELSEIF ($status == 0x02) { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
        ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget); }
        ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
        ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
        ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
        ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

        IF ($status == 0xFF)
        {
            // Handle first report (of 2)
            MSG ("Expecting a Get command for 1st firmware fragment (Report Number = 1) of target 0x{0:X2}...", $firmwareTarget);
            EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                $numberOfReports = NumberOfReports in (0 ... 255),
                $reportNumber1 = ReportNumber1 == 0,
                Res == 0,
                $reportNumber2 = ReportNumber2 == 1);
            $reportNumber = $reportNumber1 * 256 + $reportNumber2;

            MSG ("Number of requested reports: {0} - Requested starting report number: {1}", UINT($numberOfReports), UINT($reportNumber));
            IF ($reportNumber != 1)
            {
                MSGFAIL ("Requested starting report number {0} is invalid (expected: 1)", UINT($reportNumber));
            }
            $last = 0;
            $reportChecksum = 0x626B;    // this $reportChecksum is for the current Report (including command header)
            MSG ("Sending 1st firmware fragment (Last={0}) with valid fragment number and valid report checksum...", $last);

            SEND FirmwareUpdateMd.Report(
                ReportNumber1 = $reportNumber1,
                Last = $last,
                ReportNumber2 = $reportNumber2,
                Data = $data,
                Checksum = CONV($reportChecksum, 2));

            $reportedStatus = 999999;

            // Handle second (=last) report
            IF ($numberOfReports < 2)
            {
                //    MSG ("Expecting a Get command for 2nd firmware fragment (Report Number = 2) of target 0x{0:X2}...", $firmwareTarget);
                //    EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                //        $numberOfReports = NumberOfReports in (0 ... 255),
                //        $reportNumber1 = ReportNumber1 == 0,
                //        Res == 0,
                //        $reportNumber2 = ReportNumber2 == 2);
                //    $reportNumber = $reportNumber1 * 256 + $reportNumber2;
                //    MSG ("Number of requested reports: {0} - Requested starting report number: {1}", UINT($numberOfReports), UINT($reportNumber));
                //    IF ($reportNumber != 2)
                //    {
                //        MSGFAIL ("Requested starting report number {0} is invalid (expected: 2)", UINT($reportNumber));
                //    }
                MSG ("Expecting a Status Report or a Get command for 2nd firmware fragment (Report Number = 2)...");
                EXPECTOPT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                    $numberOfReports = NumberOfReports in (0 ... 255),
                    $reportNumber1 = ReportNumber1 == 0,
                    Res == 0,
                    $reportNumber2 = ReportNumber2 == 2);
                IF (ISNULL($reportNumber2))
                {
                    EXPECTOPT FirmwareUpdateMd.StatusReport(
                        $GLOBAL_timeoutStatusReport,
                        $reportedStatus = Status == 0x00,
                        $waitTime = Waittime in (0x0000 ... 0xFFFE));
                }
                ELSE
                {
                    $reportNumber = $reportNumber1 * 256 + $reportNumber2;
                    MSG ("Number of requested reports: {0} - Requested starting report number: {1}", UINT($numberOfReports), UINT($reportNumber));
                    IF ($reportNumber != 2)
                    {
                        MSGFAIL ("Requested starting report number {0} is invalid (expected: 2)", UINT($reportNumber));
                    }
                }
            }
            ELSE
            {
                $reportNumber2 = 2;
            }

            IF ($reportedStatus == 999999)
            {
                $last = 1;
                $reportChecksum = 0xDB67;    // this $reportChecksum is for the current Report (including command header)
                MSG ("Sending 2nd firmware fragment (Last={0}) with valid fragment number and valid report checksum...", $last);
                SEND FirmwareUpdateMd.Report(
                    ReportNumber1 = $reportNumber1,
                    Last = $last,
                    ReportNumber2 = $reportNumber2,
                    Data = $data,
                    Checksum = CONV($reportChecksum, 2));

                // Ignore further FirmwareUpdateMd.Get commands and send no more FirmwareUpdateMd.Report (if NumberOfReports > 1)

                // Wait for final status report
                MSG ("End of sub-test #1, Invalid Firmware Checksum, for target 0x{0:X2}. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                EXPECT FirmwareUpdateMd.StatusReport(
                    $GLOBAL_timeoutStatusReport,
                    Status in (0x00, 0x01),    // 0x00 = checksum error, 0x01 = unable to receive
                    $waitTime = Waittime in (0x0000 ... 0xFFFE));

                IF (ISNULL($waitTime) || $waitTime == [])
                {
                    MSGFAIL ("Status Report frame or Wait Time field missing");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }
                ELSE
                {
                    IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                    ELSE
                    {
                        MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                        WAIT (UINT($waitTime) * 1000);
                    }
                }
            }

            WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

            // Check whether DUT is alive
            SEND Version.Get( );
            EXPECT Version.Report(
                $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                ZWaveProtocolVersion    in (0x01 ... 0xFF),
                ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                Firmware0Version        in (0x00 ... 0xFF),
                Firmware0SubVersion     in (0x00 ... 0xFF),
                HardwareVersion         in (0x00 ... 0xFF),
                NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                vg*/);
            IF (ISNULL($versionLibraryType))
            {
                MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

                MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
            }


            // SUB-TEST #2: RESUMING A FIRMWARE UPDATE

            MSG ("SUB-TEST #2: RESUMING A FIRMWARE UPDATE");

            IF ($reportNumber < 2)
            {
                MSG("Latest Report Number was < 2. Testing resuming the firmware update is skipped...");

                CONTINUE;
            }

            IF ($resume == 0)
            {
                MSG ("According to the Firmware MD Report the DUT does NOT support resuming a Firmware Update. Double-checking...");
            }
            ELSE
            {
                MSG ("According to the Firmware MD Report the DUT supports resuming a Firmware Update.");
            }

            SEND FirmwareUpdateMd.RequestGet(
                ManufacturerId = CONV($manufacturerId, 2),
                FirmwareId = CONV($testFirmwareId, 2),
                Checksum = CONV($usedFirmwareChecksum, 2),
                FirmwareTarget = $firmwareTarget,
                FragmentSize = CONV(LENGTH($data), 2),
                Activation = 0,
                NonSecure = 0,
                Resume = 1, // Attempt to resume
                Reserved = 0x1F, // bit 3..7: 0b11111,
                HardwareVersion = $hardwareVersionF);

            IF ($resume == 0)
            {
                EXPECT FirmwareUpdateMd.RequestReport(
                    $status = Status == 0xFF,
                    Reserved == 0,
                    NonSecure == 0,
                    $requRepResume = Resume == 0, // because "Resume" is not advertised as supported
                    Reserved1 == 0);
            }
            ELSE
            {
                EXPECT FirmwareUpdateMd.RequestReport(
                    $status = Status == 0xFF,
                    Reserved == 0,
                    NonSecure == 0,
                    $requRepResume = Resume in (0, 1), // because resuming is a SHOULD
                    Reserved1 == 0);

                IF ($requRepResume == 0)
                {
                    MSG ("Warning: The DUT did NOT agree on resuming the previous firmware update!");

                    MSGBOXYES ("The DUT has advertised support for resuming firmware updates but has rejected to resume the previously aborted update process. Is this intended?");
                }
            }

            IF($status != 0xFF)
            {
                MSGFAIL ("No matter whether the DUT accepts resuming the previous update or not, it is expected to accept another firmware update. However, it has NOT returned Status = 0xFF in the Request Report!");
            }
            ELSE // $status == 0xFF: Testing another FW update, either from the beginning or resuming the previous one.
            {
                IF ($requRepResume == 0) // Expect the DUT to start the firmware update from the beginning
                {
                    MSG ("Expecting a Get command for the very 1st firmware fragment (Report Number = 1) of target 0x{0:X2}...", $firmwareTarget);
                    EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                        $numberOfReports = NumberOfReports in (0 ... 255),
                        $newReportNumber1 = ReportNumber1 == 0,
                        Res == 0,
                        $newReportNumber2 = ReportNumber2 == 1);

                    $newReportNumber = $newReportNumber1 * 256 + $newReportNumber2;

                    IF ($newReportNumber == 1)
                    {
                        MSGPASS ("The DUT started the firmware update from the beginning.");
                    }
                    ELSE
                    {
                        MSGFAIL ("The DUT die NOT start the firmware update from the beginning!");
                    }
                }
                ELSE // $requRepResume == 1: Expect the DUT to resume the previous the firmware update
                {
                    MSG ("Expecting the DUT to resume the previous firmware update: Expecting a Get command for the last firmware fragment of the previous attempt (Report Number = {0}) of target 0x{1:X2}...", $reportNumber2, $firmwareTarget);
                    EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                        $numberOfReports = NumberOfReports in (0 ... 255),
                        $newReportNumber1 = ReportNumber1 == $reportNumber1,
                        Res == 0,
                        $newReportNumber2 = ReportNumber2 == $reportNumber2);

                    $newReportNumber = $newReportNumber1 * 256 + $newReportNumber2;

                    IF ($newReportNumber == $reportNumber)
                    {
                        MSGPASS ("The DUT resumed the firmware update with requesting the latest fragment from the previous firmware update attempt.");
                    }
                    ELSE
                    {
                        MSGFAIL ("The DUT did NOT resume the firmware update with requesting the latest fragment from the previous firmware update attempt!");
                    }
                }

                // Aborting update again ...

                // The checksum algorithm is CRC-CCITT with initial value 0x1D0F and polynomium 0x1021.
                IF ($newReportNumber == 1)
                {
                    // First Report (Last=1):   7A 06 80 01 30 30 30    40 BB
                    $reportChecksum = 0x40BB;
                }
                ELSEIF ($newReportNumber == 2)
                {
                    // Second Report (Last=1):  7A 06 80 02 30 30 30    DB 67
                    $reportChecksum = 0xDB67;
                }
                ELSE
                {
                    $reportChecksum = 0xEEEE; // invalid
                }

                MSG ("Sending a firmware fragment with Last = 1 in order to abort the update again...");
                SEND FirmwareUpdateMd.Report(
                    ReportNumber1 = $newReportNumber1,
                    Last = 1,
                    ReportNumber2 = $newReportNumber2,
                    Data = $data,
                    Checksum = CONV($reportChecksum, 2));

                // Ignore further FirmwareUpdateMd.Get commands and send no more FirmwareUpdateMd.Report

                // Wait for final status report
                MSG ("End of sub-test #2, Resuming a Firmware Update, for target 0x{0:X2}. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
                EXPECT FirmwareUpdateMd.StatusReport(
                    $GLOBAL_timeoutStatusReport,
                    Status in (0x00, 0x01),    // 0x00 = checksum error, 0x01 = unable to receive
                    $waitTime = Waittime in (0x0000 ... 0xFFFE));

                IF (ISNULL($waitTime) || $waitTime == [])
                {
                    MSGFAIL ("Status Report frame or Wait Time field missing");

                    MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
                }
                ELSE
                {
                    IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                    ELSE
                    {
                        MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                        WAIT (UINT($waitTime) * 1000);
                    }
                }
            } // $status == 0xFF (Testing another FW update, either from the beginning or resuming the previous one.)

        } // IF ($status == 0xFF)

        WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

        // Check whether DUT is alive
        SEND Version.Get( );
        EXPECT Version.Report(
            $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
            ZWaveProtocolVersion    in (0x01 ... 0xFF),
            ZwaveProtocolSubVersion in (0x00 ... 0xFF),
            Firmware0Version        in (0x00 ... 0xFF),
            Firmware0SubVersion     in (0x00 ... 0xFF),
            HardwareVersion         in (0x00 ... 0xFF),
            NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
            vg*/);
        IF (ISNULL($versionLibraryType))
        {
            MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

            MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
        }

    } // LOOP ($targetIdx)

TESTSEQ END


/**
 * FirmwareRetrieve
 * Checks the firmware transfer process from node to controller
 *
 * CC versions: 8
 */

TESTSEQ FirmwareRetrieve: "Checks the firmware transfer process from node to controller"

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the SetInitialValuesAndVariables Test Sequence.");
        EXITSEQ;
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    // Define a maximum fragment size to avoid Transport Service for testing purposes
    IF ($maxFragmentSize > 28) { $maxFragmentSize = 28; }

    LOOP ($targetIdx; 0; $numberOfFirmwareTargets)
    {
        $firmwareTarget = $targetIdx;
        IF ($targetIdx == 0) { $testFirmwareId = $firmware0Id; }
        ELSE                 { $testFirmwareId = $firmwareIds[($targetIdx - 1) * 2] * 256 + $firmwareIds[(($targetIdx - 1) * 2) + 1]; }

        MSG ("Sending PrepareGet to Firmware Target 0x{0:X2} with Firmware Id {1}", $firmwareTarget, $testFirmwareId);
        SEND FirmwareUpdateMd.PrepareGet(
            ManufacturerId = CONV($manufacturerId, 2),
            FirmwareId = CONV($testFirmwareId, 2),
            FirmwareTarget = $firmwareTarget,
            FragmentSize = CONV($maxFragmentSize, 2),
            HardwareVersion = $hardwareVersionF);
        EXPECT FirmwareUpdateMd.PrepareReport($GLOBAL_preparationTimeRetrieve,
            $status = Status in (0xFF, 0x03),
            $firmwareChecksum = FirmwareChecksum in (0x0000 ... 0xFFFF));

        IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: PrepareReport frame missing", $firmwareTarget); }
        ELSEIF ($status == 0xFF) { MSGPASS ("Target 0x{0:X2}: Firmware transfer is initiated", $firmwareTarget); }
        ELSEIF ($status == 0x00) { MSGFAIL ("Target 0x{0:X2}: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
        ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2}: Device expected an authentication event", $firmwareTarget); }
        ELSEIF ($status == 0x02) { MSGFAIL ("Target 0x{0:X2}: Fragment Size invalid", $firmwareTarget); }
        ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2}: Firmware target is not downloadable", $firmwareTarget); }
        ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2}: Invalid Hardware Version", $firmwareTarget); }
        ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
        ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
        ELSE                     { MSGFAIL ("Target 0x{0:X2}: Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

        IF ($status == 0xFF)    // Firmware retrieve can start
        {
            $firstExpectedReport = 1;        // Default: 1
            $lastExpectedReport = 9999999;   // Default: 9999999 (until 'Last' flag)

            $repeatCounter = 0;
            $validReports = 0;
            $repeatThis = 0;
            LOOP ($reportNumber; $firstExpectedReport; $lastExpectedReport)
            {
                LOOP ($reportsPerGet; 1; $GLOBAL_retrieveNumberOfReportsPerGet) // may not run from 0 to $GLOBAL_retrieveNumberOfReportsPerGet-1 !
                {
                    $reportNumber1 = $reportNumber / 256;
                    $reportNumber2 = $reportNumber % 256;

                    IF ( ((($reportNumber - 1) % $GLOBAL_retrieveNumberOfReportsPerGet) == 0) || ($reportNumber == $firstExpectedReport) )
                    {
                        IF ($repeatThis == 0)
                        {
                            IF ($GLOBAL_retrieveNumberOfReportsPerGet > 1)
                            {
                                MSG ("===== Requesting Reports {0} to {1} =====", $reportNumber, $reportNumber + $GLOBAL_retrieveNumberOfReportsPerGet - 1);
                            }
                            ELSE
                            {
                                MSG ("Requesting Report {0}", $reportNumber);
                            }
                            SEND FirmwareUpdateMd.Get(
                                NumberOfReports = $GLOBAL_retrieveNumberOfReportsPerGet - (($reportNumber - 1) % $GLOBAL_retrieveNumberOfReportsPerGet),
                                ReportNumber1 = $reportNumber1,
                                Res = 0,
                                ReportNumber2 = $reportNumber2);
                        }
                    }

                    MSG ("Expecting Report {0}", $reportNumber);

                    IF ($GLOBAL_waitTimeRetrieve > 0) { WAIT($GLOBAL_waitTimeRetrieve); }

                    EXPECTOPT FirmwareUpdateMd.Report(
                        $reportNumber1 = ReportNumber1 in (0x00 ... 0x7F),
                        $last = Last in (0, 1),
                        $reportNumber2 = ReportNumber2 in (0x00 ... 0xFF),
                        $data = Data,
                        $reportChecksum = Checksum);

                    IF (ISNULL($last))
                    {
                        IF ($repeatThis < 2)
                        {
                            $repeatThis = $repeatThis + 1;
                            $repeatCounter = $repeatCounter + 1;
                            MSG ("Warning: Report frame missing. Report Number: {0}.", $reportNumber);
                            $reportsPerGet = $reportsPerGet - 1; // prepare CONTINUE
                            CONTINUE; // inner LOOP
                        }
                        MSGFAIL ("Report frame missing. Report Number: {0}.", $reportNumber);
                        $reportNumber = $lastExpectedReport + 1;    // exiting the outer LOOP
                        BREAK;                                      // exiting the inner LOOP
                    }
                    ELSE
                    {
                        $reportNumberReceived = $reportNumber1 * 256 + $reportNumber2;
                        IF ($reportNumber != $reportNumberReceived)
                        {
                            MSGFAIL ("Unexpected Report Number {0} received.", $reportNumberReceived);
                            $reportNumber = $lastExpectedReport + 1;    // exiting the outer LOOP
                            BREAK;                                      // exiting the inner LOOP
                        }
                        $validReports = $validReports + 1;
                        IF ($reportNumber >= $lastExpectedReport)
                        {
                            MSG ("Configured test end at Report {0} reached.", $reportNumber);
                            $reportNumber = $lastExpectedReport + 1;    // exiting the outer LOOP
                            BREAK;                                      // exiting the inner LOOP
                        }
                        IF ($last == 1)
                        {
                            MSG ("Last flag is set in Report {0}.", $reportNumber);
                            $reportNumber = $lastExpectedReport + 1;    // exiting the outer LOOP
                            BREAK;                                      // exiting the inner LOOP
                        }
                        $reportNumber = $reportNumber + 1;
                    }
                    $repeatThis = 0;
                } // LOOP ($reportsPerGet; 1; $GLOBAL_retrieveNumberOfReportsPerGet)
                // $reportNumber = $reportNumber + $GLOBAL_retrieveNumberOfReportsPerGet;
                $reportNumber = $reportNumber - 1; // prepare $reportNumber for following LOOP increment
            } // LOOP ($reportNumber; 1; $lastExpectedReport)

            MSG ("{0} Reports received, {1} retransmission occured.", $validReports, $repeatCounter);
            IF ($last == 0)
            {
                MSG ("Test ends after {0} of {1} expected Reports without reaching the last Report.", $validReports, $lastExpectedReport);
            }

        } // IF ($status == 0xFF)

        WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

        // Check whether DUT is alive
        SEND Version.Get( );
        EXPECT Version.Report(
                    $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
                    ZWaveProtocolVersion    in (0x01 ... 0xFF),
                    ZwaveProtocolSubVersion in (0x00 ... 0xFF),
                    Firmware0Version        in (0x00 ... 0xFF),
                    Firmware0SubVersion     in (0x00 ... 0xFF),
                    HardwareVersion         in (0x00 ... 0xFF),
                    NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
                    vg*/);
                IF (ISNULL($versionLibraryType))
        {
            MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

            MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
        }

    } // LOOP ($targetIdx)

TESTSEQ END


/**
 * Interactive_NonSecureFirmwareUpdate
 * Verifies behavior regarding the 'Non-secure' flag.
 * There is only user interaction needed (Zniffer observation for double-checking) if non-secure updates are supported.
 *
 * CC versions: 8
 */

TESTSEQ Interactive_NonSecureFirmwareUpdate: "Verify behavior in regards to a non-secure firmware update"

    $data = [0x30, 0x30, 0x30];
    $usedFirmwareChecksum = 0xC8D6; // This is the valid checksum in RequestGet for the used firmware data bytes (all bytes of all (2) reports)
                                    // 30 30 30 30 30 30  -->  C8 D6

    IF (ISNULL($GLOBAL_commandClassId))
    {
        MSGFAIL("Please execute the 'SetInitialValuesAndVariables' Test Sequence.");
        EXITSEQ;
    }

    MSG ("Assure to use the highest granted security scheme: {0}", #GLOBAL_highestGrantedScheme);
    IF (STRCMP(#GLOBAL_highestGrantedScheme, GETCURRENTSCHEME()) == false)
    {
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        IF ($GLOBAL_schemeSetDelay != 0) { WAIT ($GLOBAL_schemeSetDelay); }
    }

    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $firmware0Id = Firmware0Id in (0x0000 ... 0xFFFF),
        $firmware0Checksum = Firmware0Checksum in (0x0000 ... 0xFFFF),
        $firmwareUpgradable = FirmwareUpgradable in (0x00, 0xFF),
        $numberOfFirmwareTargets = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $maxFragmentSize = MaxFragmentSize in (0x0000 ... 0xFFFF),
        $firmwareIds = vg1,
        $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF),
        $cc = Cc in (0, 1),
        $activation = Activation in (0, 1),
        $nonSecure = NonSecure in (0, 1),
        $resume = Resume in (0, 1),
        Reserved1 == 0);
    MSG ("Firmware IDs = {0}", $firmwareIds);

    IF     ($numberOfFirmwareTargets == 0) { $firmwareTargets = [0x00]; }
    ELSEIF ($numberOfFirmwareTargets == 1) { $firmwareTargets = [0x00, 0x01]; }
    ELSE                                   { $firmwareTargets = [0x00, 0x01, $numberOfFirmwareTargets]; }

    LOOP ($targetIdx; 0; LENGTH($firmwareTargets) - 1)
    {
        $firmwareTarget = $firmwareTargets[$targetIdx];
        IF (($firmwareTarget == 0x00) && ($firmwareUpgradable == 0x00))
        {
            MSG ("Test is not applicable for Firmware Target 0.");

            CONTINUE;
        }


        IF ($targetIdx == 0)
        {
            $testFirmwareId = $firmware0Id;
        }
        ELSE
        {
            $testFirmwareId = $firmwareIds[($firmwareTargets[$targetIdx] - 1) * 2] * 256 + $firmwareIds[(($firmwareTargets[$targetIdx] - 1) * 2) + 1];
        }

        IF ($nonSecure == 0)
        {
            MSG ("According to the Firmware MD Report the DUT does NOT support non-secure firmware updates. Double-checking...");
        }
        ELSE
        {
            MSG ("According to the Firmware MD Report the DUT supports non-secure firmware updates.");
        }

        SEND FirmwareUpdateMd.RequestGet(
            ManufacturerId = CONV($manufacturerId, 2),
            FirmwareId = CONV($testFirmwareId, 2),
            Checksum = CONV($usedFirmwareChecksum, 2),
            FirmwareTarget = $firmwareTarget,
            FragmentSize = CONV(LENGTH($data), 2),
            Activation = 0,
            NonSecure = 1, // Attempt non-secure update
            Resume = 0,
            Reserved = 0x1F, // bit 3..7: 0b11111,
            HardwareVersion = $hardwareVersionF);

        IF ($nonSecure == 0)
        {
            EXPECT FirmwareUpdateMd.RequestReport(
                $status = Status in (0x03, 0xFF),
                Reserved == 0,
                $requRepNonSecure = NonSecure == 0, // because "Non-secure" is not advertised as supported
                Resume == 0,
                Reserved1 == 0);
        }
        ELSE
        {
            EXPECT FirmwareUpdateMd.RequestReport(
                $status = Status in (0x03, 0xFF),
                Reserved == 0,
                $requRepNonSecure = NonSecure in (0, 1), // because "Non-secure" is a SHOULD
                Resume == 0,
                Reserved1 == 0);

            IF ($requRepNonSecure == 0)
            {
                MSG ("Warning: The DUT did NOT agree on performing a non-secure firmware update!");

                MSGBOXYES ("The DUT has advertised support for non-secure firmware updates but has rejected to perform a non-secure update. Is this intended?");
            }
        }

        IF (ISNULL($status))     { MSGFAIL ("Target 0x{0:X2}: RequestReport frame missing", $firmwareTarget); }
        ELSEIF ($status == 0xFF) { MSGPASS ("Target 0x{0:X2} Status 0xFF: Firmware update is initiated", $firmwareTarget); }
        ELSEIF ($status == 0x00) { MSGFAIL ("Target 0x{0:X2} Status 0x00: Invalid combination of Manufacturer ID and Firmware ID", $firmwareTarget); }
        ELSEIF ($status == 0x01) { MSGFAIL ("Target 0x{0:X2} Status 0x01: Device expected an authentication event", $firmwareTarget); }
        ELSEIF ($status == 0x02) { MSGFAIL ("Target 0x{0:X2} Status 0x02: Fragment Size invalid", $firmwareTarget); }
        ELSEIF ($status == 0x03) { MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget); }
        ELSEIF ($status == 0x04) { MSGFAIL ("Target 0x{0:X2} Status 0x04: Invalid Hardware Version", $firmwareTarget); }
        ELSEIF ($status == 0x05) { MSGFAIL ("Target 0x{0:X2} Status 0x05: Another firmware image is current being transferred", $firmwareTarget); }
        ELSEIF ($status == 0x06) { MSGFAIL ("Target 0x{0:X2} Status 0x06: Insufficient battery level", $firmwareTarget); }
        ELSE                     { MSGFAIL ("Target 0x{0:X2} Invalid Status 0x{1:X2}", $firmwareTarget, $status); }

        IF($status == 0x03)
        {
             //MSGPASS ("Target 0x{0:X2} Status 0x03: Firmware target is not upgradable", $firmwareTarget);
             MSG ("Further test steps are skipped...");
        }
        ELSEIF($status != 0xFF)
        {
            MSGFAIL ("No matter whether the DUT accepts performing a non-secure update or not, it is expected to accept another firmware update. However, it has NOT returned Status = 0xFF (nor 0x03) in the Request Report!");
            MSG ("Further test steps are skipped...");
        }
        ELSE // $status == 0xFF: Testing FW update, either securely or non-securely.
        {
            // FIRST FIRMWARE FRAGMENT

            IF ($requRepNonSecure == 0) // Expect the DUT to perform the firmware update on the highest granted security level
            {
                MSG ("Keep CTT security scheme in accordance with the DUT's highest granted scheme: {0}", #GLOBAL_highestGrantedScheme);

                // CTT will detect on highest granted level only
                MSG ("Expecting a SECURE Get command for the 1st firmware fragment (Report Number = 1) of target 0x{0:X2}...", $firmwareTarget);

                // first try
                EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                $numberOfReports = NumberOfReports in (0 ... 255),
                $reportNumber1 = ReportNumber1 == 0,
                Res == 0,
                $reportNumber2 = ReportNumber2 == 1);

                MSG ("Setting CTT security scheme to: NONE");
                SETCURRENTSCHEME("NONE");
                IF ($GLOBAL_schemeSetDelay != 0) { WAIT ($GLOBAL_schemeSetDelay); }

                MSG ("Sending 1st firmware fragment using security scheme 'NONE' and expecting the DUT to ignore it...");
                SEND FirmwareUpdateMd.Report(
                    ReportNumber1 = 0,
                    Last = 0,
                    ReportNumber2 = 1,
                    Data = $data,
                    Checksum = CONV(0x626B, 2)); // The checksum algorithm is CRC-CCITT with initial value 0x1D0F and polynomium 0x1021.
                                                 // First Report (Last = 0):  7A 06 00 01 30 30 30  -->  62 6B

                MSG ("Setting CTT security scheme to the DUT's highest granted scheme: {0}", #GLOBAL_highestGrantedScheme);
                SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
                IF ($GLOBAL_schemeSetDelay != 0) { WAIT ($GLOBAL_schemeSetDelay); }

                MSG ("Sending a NOP in order to clear the CTT script engine's EXPECT cache after having set the security scheme...");
                SENDRAW([0x00]); // Send NOP in order to clear the CTT script engine's EXPECT cache
                                 // after having set the security scheme back to the DUT's highest granted scheme.

                // Now CTT will again detect on highest granted level only
                MSG ("Again, expecting a SECURE Get command for the 1st firmware fragment (Report Number = 1) of target 0x{0:X2}...", $firmwareTarget);

                MSG ("Note: If - after having ignored the non-secure Report - the DUT is sending the second try of the FW Update MD Get command");
                MSG ("  for the 1st fragment very quickly (i.e. before the CTT's NOP) (however, this is not expected), then setting the");
                MSG ("  CTT security scheme may be slower than the second try. DUT is expected to try again. CTT will then catch it.");
                MSG ("  In this case the Zniffer may also be observed...");
            }
            ELSE // $requRepNonSecure == 1: // Expect the DUT to perform the firmware update non-securely
            {
                MSG ("Setting CTT security scheme to: NONE");
                SETCURRENTSCHEME("NONE");
                IF ($GLOBAL_schemeSetDelay != 0) { WAIT ($GLOBAL_schemeSetDelay); }

                MSG ("Sending a NOP in order to clear the CTT script engine's EXPECT cache after having set the security scheme...");
                SENDRAW([0x00]); // Send NOP in order to clear the CTT script engine's EXPECT cache after having set the security scheme to "NONE"

                // Now CTT will detect on non-secure level only
                MSG ("Expecting a NON-SECURE Get command for the 1st firmware fragment (Report Number = 1) of target 0x{0:X2}...", $firmwareTarget);

                MSG ("Note: If the FW Update MD Get command is sent right away after the Request Report (i.e. before the NOP) (is expected behavior),");
                MSG ("  setting the CTT security scheme may be slower than the first try. DUT is expected to try again. CTT will then catch it.");
                MSG ("  Thus, also observe the Zniffer...");
            }

            // if secure update: is second (third) try
            EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                $numberOfReports = NumberOfReports in (0 ... 255),
                $reportNumber1 = ReportNumber1 == 0,
                Res == 0,
                $reportNumber2 = ReportNumber2 == 1);

            MSG ("Sending 1st firmware fragment using security scheme: {0}", GETCURRENTSCHEME());
            SEND FirmwareUpdateMd.Report(
                ReportNumber1 = 0,
                Last = 0,
                ReportNumber2 = 1,
                Data = $data,
                Checksum = CONV(0x626B, 2)); // The checksum algorithm is CRC-CCITT with initial value 0x1D0F and polynomium 0x1021.
                                             // First Report (Last = 0):  7A 06 00 01 30 30 30  -->  62 6B

            // SECOND FIRMWARE FRAGMENT

            IF ($requRepNonSecure == 0)
            {
                MSG ("Expecting a SECURE Get command for the 2nd firmware fragment (Report Number = 2) of target 0x{0:X2}...", $firmwareTarget);
            }
            ELSE
            {
                MSG ("Expecting a NON-SECURE Get command for the 2nd firmware fragment (Report Number = 2) of target 0x{0:X2}...", $firmwareTarget);
            }

            EXPECT FirmwareUpdateMd.Get($GLOBAL_timeoutGetCommand,
                $numberOfReports = NumberOfReports in (0 ... 255),
                $reportNumber1 = ReportNumber1 == 0,
                Res == 0,
                $reportNumber2 = ReportNumber2 == 2);

            MSG ("Sending 2nd firmware fragment (with Last = 1 in order to end the update again) using security scheme: {0}", GETCURRENTSCHEME());
            SEND FirmwareUpdateMd.Report(
                ReportNumber1 = 0,
                Last = 1,
                ReportNumber2 = 2,
                Data = $data,
                Checksum = CONV(0xDB67, 2)); // The checksum algorithm is CRC-CCITT with initial value 0x1D0F and polynomium 0x1021.
                                             // Second Report (Last = 1):  7A 06 80 02 30 30 30  -->  DB 67

            // Consider FW update finished.

            MSG ("Assure to use the highest granted security scheme: {0}", #GLOBAL_highestGrantedScheme);
            IF (STRCMP(#GLOBAL_highestGrantedScheme, GETCURRENTSCHEME()) == false)
            {
                SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
                IF ($GLOBAL_schemeSetDelay != 0) { WAIT ($GLOBAL_schemeSetDelay); }
            }

            // Double-check for non-secure frames
            IF ($requRepNonSecure == 1)
            {
                MSGBOXYES ("Double-check: Observe the Zniffer trace: Has the DUT sent the 'Firmware Update Md Get' commands NON-SECURELY?");
            }

            // Wait for final status report
            MSG ("End of test for target 0x{0:X2}. Wait {1} seconds for the Status Report...", $firmwareTarget, UINT($GLOBAL_timeoutStatusReport));
            EXPECT FirmwareUpdateMd.StatusReport(
                $GLOBAL_timeoutStatusReport,
                //Status in (0x00, 0x01),    // 0x00 = checksum error, 0x01 = unable to receive
                Status == 0x04,              // 0x04 = does not match the Firmware Target
                $waitTime = Waittime in (0x0000 ... 0xFFFE));

            IF (ISNULL($waitTime) || $waitTime == [])
            {
                MSGFAIL ("Status Report frame or Wait Time field missing");

                MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
            }
            ELSE
            {
                IF (UINT($waitTime) == 0) { MSG ("Device is ready after aborted Firmware Update"); }
                ELSE
                {
                    MSG ("Waiting the reported time: {0} seconds", UINT($waitTime));
                    WAIT (UINT($waitTime) * 1000);
                }
            }
        } // $status == 0xFF Testing FW update, either securely or non-securely.)

        WAIT ($GLOBAL_recoveryTime * 1000);    // Some devices need a recovery time after this test

        // Check whether DUT is alive
        SEND Version.Get( );
        EXPECT Version.Report(
            $versionLibraryType = ZWaveLibraryType in (0x01 ... 0x0B),
            ZWaveProtocolVersion    in (0x01 ... 0xFF),
            ZwaveProtocolSubVersion in (0x00 ... 0xFF),
            Firmware0Version        in (0x00 ... 0xFF),
            Firmware0SubVersion     in (0x00 ... 0xFF),
            HardwareVersion         in (0x00 ... 0xFF),
            NumberOfFirmwareTargets in (0x00 ... 0xFF)/*,
            vg*/);
        IF (ISNULL($versionLibraryType))
        {
            MSGFAIL("DUT is not responding! '$GLOBAL_recoveryTime' may be increased.");

            MSGBOXYES ("Wait until the DUT is ready. Then click 'Yes' to continue.");
        }

    } // LOOP ($targetIdx)

TESTSEQ END
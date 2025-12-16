PACKAGE ZWavePlusInfoCmdClassV2_Rev0900_Orig; // do not modify this line
USE ZwaveplusInfo CMDCLASSVER = 2;
USE Supervision CMDCLASSVER = 1;
USE DeviceResetLocally CMDCLASSVER = 1;
USE MultiChannel CMDCLASSVER = 3;
USE WakeUp CMDCLASSVER = 1;

/**
 * Z-Wave Plus Info Command Class Version 2 Test Script
 * Command Class Specification: 2020B
 * Formatting Conventions: Version 2016-05-19
 *
 * PLEASE NOTE:
 * - The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run
 *
 * ChangeLog:
 *
 * Unknown              - Initial version
 * June 8th, 2016       - Refactoring, minor improvements
 *                      - New test sequence 'GetEndpoints' to inform the tester about necessary tests with these End Points
 * September 28th, 2016 - Minor improvements in 'GetEndpoints'
 * November 21st, 2016  - Clarification for securely included devices in 'VerifyVersion' and 'GetEndpoints'
 * June 27th, 2018      - Compatibility improvements for executing with enabled Multichannel encapsulation
 *                      - New test sequence 'SupervisionHighestSecurityForDeviceResetLocally'
 * January 19th, 2019   - New test sequence 'SupervisionAtLowerSecurityLevelForDeviceResetLocally'
 *                      - New test sequence 'SetInitialValuesAndVariables'
 *                      - edit test sequence 'SupervisionHighestSecurity'
 * March 12th, 2019     - New test sequence 'SupervisionHighestSecurityForBasic'
 * May 14th, 2019       - Small Bug Fixes at Supervision Sequences
 * August 10th, 2020    - Improvements in Supervision using current script language features
 * September 30th, 2020 - Checks for execution of 'SetInitialValuesAndVariables' added
 * October 21st, 2020   - Migration to CTTv3 project format
 *                      - Detection of Root Device / End Point ID using CTTv3 script language features
 * November 4th, 2020   - Version/CommandClassGet(cc) replaced by GETCOMMANDCLASSVERSION(cc)
 * November 11th, 2021  - Reworking of all non-security and lower security Supervision sequences.
 *                        Applied EXPECTOPT for Supervision Report.
 * June 26th, 2023      - Considered sleep timer for Wake Up nodes. Additionally sending NOPs.
 *                      - Fixed analyzing advertisement of ZWP Info CC.
 */


/**
 * SetInitialValuesAndVariables
 * This sequence sets the global variables and initial values for the tests of this command class.
 * This sequence MUST be executed in each test run.
 * If it is not executed, this will lead to errors in the following test sequences.
 *
 * CC versions: 2
 */

TESTSEQ SetInitialValuesAndVariables: "Set initial Values and Variables."

    // Test environment configuration - MAY be changed
    GLOBAL $GLOBAL_sessionId = 1;      // Adjust if specific Supervision Session ID is needed.

    // Test data - MUST NOT be changed
    GLOBAL $GLOBAL_endPointId = GETENDPOINT();
    GLOBAL $GLOBAL_commandClassId = 0x5E; // ZWP Info
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Z-Wave Plus Info";
    GLOBAL $GLOBAL_commandClassIdDrl = 0x5A; // Device Reset Locally
    GLOBAL #GLOBAL_commandClassNameDrl = GETCOMMANDCLASSNAME($GLOBAL_commandClassIdDrl);
    GLOBAL #GLOBAL_commandClassTextDlr = "Device Reset Locally";
    GLOBAL $GLOBAL_commandClassIdBasic = 0x20; // Basic
    GLOBAL #GLOBAL_commandClassNameBasic = GETCOMMANDCLASSNAME($GLOBAL_commandClassIdBasic);
    GLOBAL #GLOBAL_commandClassTextBasic = "Basic";
    GLOBAL $GLOBAL_lastSessionId = 63;

    // Security and Supervision data - MUST NOT be changed
    GLOBAL $GLOBAL_schemeSetDelay = 0; // Testers only: Adjust temporarily, if the DUT needs a longer time for activating a Security Scheme
    GLOBAL #GLOBAL_supportedSchemes = GETSUPPORTEDSCHEMES();
    GLOBAL #GLOBAL_highestGrantedScheme = #GLOBAL_supportedSchemes[0];
    GLOBAL $GLOBAL_commandClassesRoot = GETCOMMANDCLASSES();
    GLOBAL $GLOBAL_secureCommandClassesRoot = GETSECURECOMMANDCLASSES();
    GLOBAL $GLOBAL_commandClasses = GETEPCOMMANDCLASSES($GLOBAL_endPointId);
    GLOBAL $GLOBAL_secureCommandClasses = GETEPSECURECOMMANDCLASSES($GLOBAL_endPointId);
    GLOBAL $GLOBAL_svIsInNIF = 0;
    GLOBAL $GLOBAL_wakeUpCCIsSupported = 0;
    GLOBAL $GLOBAL_ccIsAdvertised = 0;
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
    IF (INARRAY($GLOBAL_commandClassesRoot, 0x6C) == true)
    {
        $GLOBAL_svIsInNIF = 1;
        MSG ("Supervision CC is in the Root Device NIF.");
    }
    ELSE
    {
        $GLOBAL_svIsInNIF = 0;
        MSG ("Supervision CC is NOT in the Root Device NIF!");
    }

    // Command Class Support: Analyze NIF / MC Cap Report / Supported Report of Root Device or End Point
    IF (INARRAY($GLOBAL_commandClasses, $GLOBAL_commandClassId) == true)
    {
        $GLOBAL_ccIsAdvertised = 1;
        MSG ("{0} CC is non-securely supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }
    ELSEIF (INARRAY($GLOBAL_secureCommandClasses, $GLOBAL_commandClassId) == true)
    {
        $GLOBAL_ccIsAdvertised = 1;
        MSG ("{0} CC is securely supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }

    IF ($GLOBAL_ccIsAdvertised == 0)
    {
        MSGFAIL ("{0} CC is not advertised as supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }

    // Looking for Wake Up CC
    $wakeUpCCId = 0x84;
    IF ( (INARRAY($GLOBAL_commandClassesRoot, $wakeUpCCId) == true) || (INARRAY($GLOBAL_secureCommandClassesRoot, $wakeUpCCId) == true) )
    {
        $GLOBAL_wakeUpCCIsSupported = 1;
        MSG ("Wake Up CC is supported.");
    }

TESTSEQ END


/**
 * Interactive_ZWavePlusInfoReport
 * Verifies general content of Z-Wave Plus Info Report
 *
 * Please note: This Test Sequence must be run with every End Point of the device, too.
 *
 * Defined Role Types for V2+: see <SDK>\Z-Wave\include\ZW_cmdclass.h and search for "ROLE_TYPE_*_V2"
 * Defined Node Types for V2+: see <SDK>\Z-Wave\include\ZW_cmdclass.h and search for "ZWAVEPLUS_INFO_REPORT_NODE_TYPE_ZWAVEPLUS_*_V2"
 * Defined Icon Types: see <SDK>\Z-Wave\include\ZW_cmdclass.h and search for "ICON_TYPE"
 *
 * CC versions: 2
 */

TESTSEQ Interactive_ZWavePlusInfoReport: "Verifies general content of Z-Wave Plus Info Report"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND ZwaveplusInfo.Get( );
    EXPECT ZwaveplusInfo.Report(
        ZWaveVersion in (1, 2),
        RoleType in (0x00 ... 0x07),
        NodeType in (0x00, 0x02),
        $installerIcon = InstallerIconType in (0x0000 ... 0xFFFF),
        $userIcon = UserIconType in (0x0000 ... 0xFFFF) );

    MSG ("Refer to document 'Z-Wave Plus Assigned Icon Types' to verify the following items:");
    MSG ("- Verify that Installer Icon Type 0x{0:X4} is a valid icon type", UINT($installerIcon));
    MSG ("- Verify that User Icon Type 0x{0:X4} is a valid icon type", UINT($userIcon));
    MSGBOXYES ("Refer to document 'Z-Wave Plus Assigned Icon Types'. Are the reported Icon Types (Installer: 0x{0:X4} - User: 0x{1:X4}) valid?", UINT($installerIcon), UINT($userIcon));

    IF ($GLOBAL_wakeUpCCIsSupported == 1)
    {
        SEND ZwaveplusInfo.Get( );
        EXPECTOPT ZwaveplusInfo.Report(
            $zwVersion = ZWaveVersion);

        IF (ISNULL($zwVersion))
        {
            MSG ("Warning: DUT is sleeping! Waiting for Wake Up Notification ...");
            EXPECT WakeUp.Notification(0);
        }
    }

TESTSEQ END


/**
 * VerifyVersion
 * Verify DUT is implementing at least version 2 of Z-Wave Plus Info Command Class
 *
 * PLEASE NOTE: If the DUT is securely included, and this test sequence runs without 'Enable Security' setting, and the
 * DUT does not send a Version Command Class Report, this test will not fail, and the test sequence may be deactivated.
 *
 * CC versions: 2
 */

TESTSEQ VerifyVersion: "Verify device is implementing at least version 2 of Z-Wave Plus Info Command Class"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    $version = GETCOMMANDCLASSVERSION(0x5E);
    IF ($version == 0)
    {
        MSGFAIL ("Device does not implement version 2 or later of the Z-Wave Plus Info Command Class.");
    }
    ELSEIF ($version == 1)
    {
        MSGFAIL ("Device implements version 1 of the Z-Wave Plus Info Command Class - this version is obsoleted and not allowed.");
    }
    ELSE
    {
        MSGPASS ("Device implements version {0} of the Z-Wave Plus Info Command Class", UINT($version));
    }

TESTSEQ END


/**
 * GetEndpoints
 * Shows number of device End Points to inform the tester about rules for the test sequence 'ZWavePlusInfoReport' in CTTv2
 *
 * PLEASE NOTE: If the DUT is securely included, and this test sequence runs without 'Enable Security' setting, and the
 * DUT does not send a Version Command Class Report, this test will not fail, and the test sequence may be deactivated.
 *
 * CC versions: 2
 */

TESTSEQ GetEndPoints: "Gets number of End Points"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    IF ($GLOBAL_endPointId != 0)
    {
        MSGPASS ("Script tests a Multichannel End Point, test sequence skipped.");
        EXITSEQ;
    }

    $version = GETCOMMANDCLASSVERSION(0x60);    // Multi Channel CC
    IF ($version >= 3)
    {
        SEND MultiChannel.EndPointGet( );
        EXPECT MultiChannel.EndPointReport(
            Res1 == 0,
            Identical in (0, 1),
        $dynamic = Dynamic in (0, 1),
        $endpoints = EndPoints in (0 ... 127),
        Res2 == 0);

        IF ($endpoints > 0)
        {
            IF ($dynamic == 0) { MSG ("This device has a static number of {0} Multichannel End Points.", UINT($endpoints)); }
            ELSE               { MSG ("This device has a dynamic number of at least {0} Multichannel End Points.", UINT($endpoints)); }

            MSG ("Please note that the Test Sequence 'ZWavePlusInfoReport' must be run with every End Point of the device.");
            MSG ("Select 'Enable Multichannel' and the matching End Points in the CTT Encapsulation Toolbar.");
        }
        ELSE
        {
            MSGPASS ("This device has no Multichannel End Points. No further actions required.");
        }
    }
    ELSE
    {
        MSGPASS ("This device doesn't support Multi Channel Command Class V3+. No further actions required.");
    }

TESTSEQ END


/**
 * SupervisionHighestSecurityForDeviceResetLocally
 * Device Reset Locally CC: Supervision Status Codes at the Highest Security Level
 *
 * CC versions: 2
 */

TESTSEQ SupervisionHighestSecurityForDeviceResetLocally: "Supervision Status Codes at the Highest Security Level"

    IF (ISNULL($GLOBAL_sessionId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Step 1
    // All security classes are enabled on the including Controller.
    // Add the DUT to its network and grant all requested security keys to the DUT.
    MSG ("___ Step 1 ___");
    MSG ("Assure to use the highest granted key.");
    IF (STRCMP(#GLOBAL_highestGrantedScheme, GETCURRENTSCHEME()) == false)
    {
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);
    }

    MSG ("___ Step 2 ___");
    MSG ("Checking NIF.");
    IF ($GLOBAL_svIsInNIF == 0)
    {
        MSG ("Supervision CC is not in the NIF, skipping...");
        EXITSEQ;
    }

    // Step 3
    // Issue a Supervision Get [Device Reset Locally Notification] to the DUT.
    MSG ("___ Step 3 ___");
    MSG ("Send Supervision Get [Device Reset Locally Notification]");

    SEND Supervision.Get(
        SessionId = $GLOBAL_sessionId,
        Reserved = 0,
        StatusUpdates = 0,
        EncapsulatedCommandLength = 2,
        EncapsulatedCommand = [0x5A, 0x01]);
    EXPECT Supervision.Report(
        SessionId == $GLOBAL_sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        Status in (0x00, 0xFF), // 0x00=NO_SUPPORT, 0xFF=SUCCESS
        Duration == 0);
    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

    // Step 4
    // Issue a Supervision Get [Command Class = $GLOBAL_commandClassIdDrl, Command = 0xFF] to the DUT.
    // Note: This command does not exist in Device Reset Locally CC.
    MSG ("___ Step 4 ___");
    MSG ("Send Supervision Get [Command Class = 0x{0}, Command = 0xFF]", CONV($GLOBAL_commandClassIdDrl, 1));

    SEND Supervision.Get(
        SessionId = $GLOBAL_sessionId,
        Reserved = 0,
        StatusUpdates = 0,
        EncapsulatedCommandLength = 2,
        EncapsulatedCommand = [$GLOBAL_commandClassIdDrl, 0xFF]);
    EXPECT Supervision.Report(
        SessionId == $GLOBAL_sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        Status == 0x00, // 0x00=NO_SUPPORT
        Duration == 0);
    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

TESTSEQ END


/**
 * SupervisionAtLowerSecurityLevelForDeviceResetLocally
 * Device Reset Locally CC: Supervision Status Codes at Lower Security Level
 *
 * If the script is intended to be run for Multi Channel endpoints ("enable Multi Channel" is checked),
 * please deselect the Supervision Lower Security test sequences. Explanation: As long as the DUT is included securely,
 * the Multi Channel endpoints can only be reached using secure communication on the highest supported level.
 * The DUT won't respond to lower security requests for the endpoint.
 *
 * CC versions: 2
 */

TESTSEQ SupervisionAtLowerSecurityLevelForDeviceResetLocally: "Supervision Status Codes at Lower Security Level"

    IF (ISNULL($GLOBAL_sessionId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    IF ($GLOBAL_endPointId != 0)
    {
        MSGPASS ("Script tests a Multichannel End Point, test sequence skipped.");
        EXITSEQ;
    }

    MSG ("Supervision Status Codes: 0x00=NO_SUPPORT, 0x01=WORKING, 0x02=FAIL, 0xFF=SUCCESS");


    MSG ("Repeat steps 3 and 4 for each security level that is not the highest granted level.");

    LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)
    {
        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        WAIT ($GLOBAL_schemeSetDelay);

        // Step 3
        // Issue a Supervision Get [Device Reset Locally Notification] to the DUT.
        MSG ("___ Step 3 ___");
        MSG ("Send Supervision Get [Device Reset Locally Notification]");

        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = 2,
            EncapsulatedCommand = [$GLOBAL_commandClassIdDrl, 0x01]);

        IF ($GLOBAL_svIsInNIF == 1)
        {
            EXPECTOPT Supervision.Report(
                SessionId == $GLOBAL_sessionId,
                Reserved == 0,
                MoreStatusUpdates == 0,
                Status == 0x00, // 0x00=NO_SUPPORT
                Duration == 0);
            SETCURRENTSCHEME("NONE");
            SENDRAW([0x00]); // NOP
            SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        }
        ELSE
        {
            EXPECTNOT Supervision.Report;
        }

        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

        // Step 4
        // Issue a Supervision Get [Command Class = $GLOBAL_commandClassIdDrl, Command = 0xFF] to the DUT.
        // Note: This command does not exist in Device Reset Locally CC.
        MSG ("___ Step 4 ___");
        MSG ("Send Supervision Get [Command Class = 0x{0}, Command = 0xFF]", CONV($GLOBAL_commandClassIdDrl, 1));
        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = 2,
            EncapsulatedCommand = [$GLOBAL_commandClassIdDrl, 0xFF]);

        IF ($GLOBAL_svIsInNIF == 1)
        {
            EXPECTOPT Supervision.Report(
                SessionId == $GLOBAL_sessionId,
                Reserved == 0,
                MoreStatusUpdates == 0,
                Status == 0x00, // 0x00=NO_SUPPORT
                Duration == 0);
            SETCURRENTSCHEME("NONE");
            SENDRAW([0x00]); // NOP
            SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        }
        ELSE
        {
            EXPECTNOT Supervision.Report;
        }

        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

    } // LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)

    SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
    WAIT ($GLOBAL_schemeSetDelay);

TESTSEQ END


/**
 * SupervisionHighestSecurityForBasic
 * Basic CC: Supervision Status Codes at the Highest Security Level
 *
 * CC versions: 2
 */

TESTSEQ SupervisionHighestSecurityForBasic: "Supervision Status Codes at the Highest Security Level"

    $currentValues = [0x63, 0x00, 0xFF, 0x0A, 0xF0]; // Test values must be in range 0x00 ... 0xFF. Order might matter.
    $runs = 2;          // Amount of consecutive test runs for each value; should be left to 2.
    $onOffTime = 1000;  // This value may only be changed for testing purposes (if WORKING duration is unknown).

    IF (ISNULL($GLOBAL_sessionId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // MSG ("Supervision Status Codes: 0x00=NO_SUPPORT, 0x01=WORKING, 0x02=FAIL, 0xFF=SUCCESS");

    // Step 1
    // All security classes are enabled on the including Controller.
    // Add the DUT to its network and grant all requested security keys to the DUT.
    MSG ("___ Step 1 ___");
    MSG ("Assure to use the highest granted key.");
    IF (STRCMP(#GLOBAL_highestGrantedScheme, GETCURRENTSCHEME()) == false)
    {
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);
    }

    MSG ("___ Step 2 ___");
    MSG ("Checking NIF.");
    IF ($GLOBAL_svIsInNIF == 0)
    {
        MSG ("Supervision CC is not in the NIF, skipping...");
        EXITSEQ;
    }

    // Check if Basic CC is supported and skip test sequence if not
    MSG ("___ Check Basic Support ___");

    SEND Basic.Get( );
    EXPECTOPT Basic.Report(2, // 2 seconds expect timeout,
        $tempValue = Value in (0x00 ... 0xFF) ); // For Sound Switch and future proof all values 0x00 ... 0xFF are allowed.
    SETCURRENTSCHEME("NONE");
    SENDRAW([0x00]); // NOP
    SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);

    //$tempValue = 1; // Remove comment double slash to force executing this test, anyway.

    IF (LENGTH($tempValue) == 0) // No Basic Report has been received.
    {
        MSG ("No Basic Report has been received. Trying again ...");

        SEND Basic.Get( );
        EXPECTOPT Basic.Report(2, // 2 seconds expect timeout,
            $tempValue = Value in (0x00 ... 0xFF) ); // For Sound Switch and future proof all values 0x00 ... 0xFF are allowed.
        SETCURRENTSCHEME("NONE");
        SENDRAW([0x00]); // NOP
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);

        IF (LENGTH($tempValue) == 0) // No Basic Report has been received.
        {
            $skipBasic = 1;
            MSG ("No Basic Report has been received.");
            MSG ("___ TEST SKIPPED ___");
            MSG ("No further action is required.");
            EXITSEQ;
        }
    }

    // Step 2
    // Repeat steps 3 and 4 for each of the following Basic values denoted currentValue:
    // 0x00, 0xFF, 0x0A, 0x63, 0xF0
    MSG ("___ Step 2 ___");
    MSG ("Test values (hex): {0}", $currentValues);

    // Supervision Test starts here
    LOOP ($i; 0; LENGTH($currentValues) - 1)
    {
        // Test with several consecutive runs
        LOOP ($run; 1; $runs)
        {
            // Step 3
            // Issue a Supervision Get [Basic Set (Value = currentValue)] to the DUT.
            MSG ("___ Step 3 ({0}/{1}): run {2} for value 0x{3}  ___",
                (($i+1)*$runs) - ($runs-$run), $runs*LENGTH($currentValues), UINT($run), CONV($currentValues[$i], 1) );

            MSG ("Send Supervision Get [Basic Set (Value = 0x{0})]", CONV($currentValues[$i], 1));
            SEND Supervision.Get(
                SessionId = $GLOBAL_sessionId,
                Reserved = 0,
                StatusUpdates = 1,
                EncapsulatedCommandLength = 3,
                EncapsulatedCommand = [0x20, 0x01, $currentValues[$i]]);
            EXPECT Supervision.Report(
                SessionId == $GLOBAL_sessionId,
                Reserved == 0,
                ($moreStatusUpdates = MoreStatusUpdates) in (0, 1),
                ($status = Status) in (0xFF, 0x01, 0x02), // 0xFF=SUCCESS, 0x01=WORKING, 0x02=FAIL
                ($duration = Duration) in 0x00 ... 0xFE); // 0xFF = Reserved

            // Step 4
            // If the last received Supervision status is WORKING, wait for subsequent(s) Supervision Report.
            IF ($status == 0x01) // 0x01=WORKING
            {
                MSG ("Supervision Status: 0x01=WORKING");

                MSG ("___ Step 4 ({0}/{1}): run {2} for value 0x{3}  ___",
                    (($i+1)*$runs) - ($runs-$run), $runs*LENGTH($currentValues), UINT($run), CONV($currentValues[$i], 1) );
                LOOP ($j; 0; 1)
                {
                    IF ($moreStatusUpdates != 1)
                    {
                        MSGFAIL ("The More Status Updates field of the Supervison Report is {0} but MUST be 1.", UINT($moreStatusUpdates));
                    }
                    IF ($duration == 0)
                    {
                        MSGFAIL ("The Duration field of the Supervison Report MUST NOT be 0.");
                        $durationInSeconds = $onOffTime / 1000;
                    }
                    ELSEIF ($duration == 0xFE)
                    {
                        MSG ("The Duration is field of the Supervison Report states 0xFE = Unknown State.");
                        $durationInSeconds = $onOffTime / 1000;
                    }
                    ELSEIF ($duration >= 0x80)
                    {
                        $durationInSeconds = $duration * 60;
                    }
                    ELSE
                    {
                        $durationInSeconds = $duration;
                    }

                    $durationInSeconds = $durationInSeconds + 1;

                    EXPECT Supervision.Report($durationInSeconds,
                        SessionId == $GLOBAL_sessionId,
                        Reserved == 0,
                        ($moreStatusUpdates = MoreStatusUpdates) in (0, 1),
                        ($status = Status) in (0xFF, 0x01, 0x02), // 0xFF=SUCCESS, 0x01=WORKING, 0x02=FAIL
                        ($duration = Duration) in 0x00 ... 0xFE); // 0xFF = Reserved

                    IF ($status == 0x01) // 0x00=WORKING
                    {
                        MSG ("Supervision Status: 0x01=WORKING");
                        $j = 0; // expect next Supervision Report with same SessionID
                    }
                    ELSE // 0xFF=SUCCESS or 0x02=FAIL after "WORKING"
                    {
                        IF ($status == 0xFF)
                        {
                            MSG ("Supervision Status: 0xFF=SUCCESS");
                        }
                        ELSE // IF ($status == 0x02)
                        {
                            MSG ("Supervision Status: 0x02=FAIL");
                        }
                        $j = 1; // end loop
                    }
                } // LOOP ($j; 0; 1)
            } // IF ($status == 0x01) // 0x01=WORKING
            ELSE // 0xFF=SUCCESS or 0x02=FAIL without "WORKING" before
            {
                IF ($status == 0xFF)
                {
                    MSG ("Supervision Status: 0xFF=SUCCESS --> Step 4 skipped for value 0x{0}", CONV($currentValues[$i], 1));
                }
                ELSE // IF ($status == 0x02)
                {
                    MSG ("Supervision Status: 0x02=FAIL --> Step 4 skipped for value 0x{0}", CONV($currentValues[$i], 1));
                }
            }

            // finally 0xFF=SUCCESS or 0x02=FAIL
            IF ($moreStatusUpdates != 0)
            {
                MSGFAIL ("The More Status Updates field of the Supervison Report is {0} but MUST be 0.", UINT($moreStatusUpdates));
            }
            IF ($duration != 0)
            {
                MSGFAIL ("The Duration field of the Supervison Report is 0x{0} but MUST be 0.", CONV($duration, 1));
            }

            // SessionID for steps 3 and 4
            $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

            // Step 5
            // Issue a Basic Get to the DUT.
            MSG ("___ Step 5 ({0}/{1}): run {2} for value 0x{3}  ___",
                (($i+1)*$runs) - ($runs-$run), $runs*LENGTH($currentValues), UINT($run), CONV($currentValues[$i], 1) );
            SEND Basic.Get( );
            IF ( ($status == 0xFF) && ($currentValues[$i] == 0x00) ) // 0xFF=SUCCESS
            {
                EXPECT Basic.Report(Value == 0x00);
            }
            ELSEIF ( ($status == 0xFF) && ($currentValues[$i] > 0x00) ) // 0xFF=SUCCESS
            {
                EXPECT Basic.Report(Value in (0x01 ... 0xFF)); // For Sound Switch and future proof all values 0x00 (here 0x01) ... 0xFF are allowed.
            }
            ELSEIF ($status == 0x02) // 0x02=FAIL
            {
                EXPECT Basic.Report(Value != $currentValues[$i]);
            }

        } //LOOP ($run; 1; $runs)

    } // LOOP ($i; 0; LENGTH($currentValues) - 1)

    // Step 6
    // Issue a Supervision Get [Command Class = 0x20, Command = 0xFF] to the DUT.
    // Note: This command does not exist in Basic CC.
    MSG ("___ Step 6 ___");
    MSG ("Send Supervision Get [Command Class = 0x20, Command = 0xFF]");
    SEND Supervision.Get(
        SessionId = $GLOBAL_sessionId,
        Reserved = 0,
        StatusUpdates = 0,
        EncapsulatedCommandLength = 2,
        EncapsulatedCommand = [0x20, 0xFF]);
    EXPECT Supervision.Report(
        SessionId == $GLOBAL_sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        Status == 0x00, // 0x00=NO_SUPPORT
        Duration == 0);
    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

TESTSEQ END


/**
 * SupervisionAtLowerSecurityForBasic
 * Basic CC: Supervision Status Codes at Lower Security Level
 *
 * CC versions: 2
 */

TESTSEQ SupervisionAtLowerSecurityForBasic: "Supervision Status Codes at Lower Security Level"

    $onOffTime = 1000;  // This value may only be changed for testing purposes (if WORKING duration is unknown).

    IF (ISNULL($GLOBAL_sessionId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    IF ($GLOBAL_endPointId != 0)
    {
        MSGPASS ("Script tests a Multichannel End Point, test sequence skipped.");
        EXITSEQ;
    }

    // MSG ("Supervision Status Codes: 0x00=NO_SUPPORT, 0x01=WORKING, 0x02=FAIL, 0xFF=SUCCESS");

    // Step 1
    // All security classes are enabled on the including Controller.
    // Add the DUT to its network and grant all requested security keys to the DUT.
    MSG ("___ Step 1 ___");
    MSG ("Assure to use the highest granted key.");
    IF (STRCMP(#GLOBAL_highestGrantedScheme, "NONE") == true)
    {
        MSG ("The DUT is not securely included, skipping...");
        EXITSEQ;
    }
    IF (STRCMP(#GLOBAL_highestGrantedScheme, GETCURRENTSCHEME()) == false)
    {
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);
    }

    MSG ("___ Step 2 ___");
    MSG ("Checking NIF.");
    IF ($GLOBAL_svIsInNIF == 0)
    {
        MSG ("Supervision CC is not in the NIF, skipping...");
        EXITSEQ;
    }

    // Check if Basic CC is supported and skip test sequence if not
    MSG ("___ Check Basic Support ___");

    SEND Basic.Get( );
    EXPECTOPT Basic.Report(2, // 2 seconds expect timeout,
        $tempValue = Value in (0x00 ... 0xFF) ); // For Sound Switch and future proof all values 0x00 ... 0xFF are allowed.
    SETCURRENTSCHEME("NONE");
    SENDRAW([0x00]); // NOP
    SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);

    //$tempValue = 1; // Remove comment double slash to force executing this test, anyway.

    IF (LENGTH($tempValue) == 0) // No Basic Report has been received.
    {
        MSG ("No Basic Report has been received. Trying again ...");

        SEND Basic.Get( );
        EXPECTOPT Basic.Report(2, // 2 seconds expect timeout,
            $tempValue = Value in (0x00 ... 0xFF) ); // For Sound Switch and future proof all values 0x00 ... 0xFF are allowed.
        SETCURRENTSCHEME("NONE");
        SENDRAW([0x00]); // NOP
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);

        IF (LENGTH($tempValue) == 0) // No Basic Report has been received.
        {
            $skipBasic = 1;
            MSG ("No Basic Report has been received.");
            MSG ("___ TEST SKIPPED ___");
            MSG ("No further action is required.");
            EXITSEQ;
        }
    }

    // Step 3
    // Repeat steps 3 and 4 for each of the following Basic values denoted currentValue:
    // 0x00, 0xFF, 0x0A, 0x63, 0xF0
    MSG ("___ Step 3 ___");
    MSG ("Set start Values");

    SEND Basic.Set(Value = 0x00);

    WAIT ($onOffTime);

    MSG ("Repeat steps 4 ... 6 for each security level that is not the highest granted level.");

    LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)
    {
        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        WAIT ($GLOBAL_schemeSetDelay);

        // Step 4
        // Issue a Supervision Get [Basic Set (Value = currentValue)] to the DUT.
        MSG ("___ Step 4  ___");
        MSG ("Send Supervision Get [Basic Set (Value = 0x{0})]", CONV(0x01,1));
        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 1,
            EncapsulatedCommandLength = 3,
            EncapsulatedCommand = [0x20, 0x01, 0x01]);
        EXPECTOPT Supervision.Report(
            SessionId == $GLOBAL_sessionId,
            Reserved == 0,
            MoreStatusUpdates == 0,
            Status == 0x00, // 0x00=NO_SUPPORT
            Duration == 0);
        SETCURRENTSCHEME("NONE");
        SENDRAW([0x00]); // NOP
        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);

        // SessionID for steps 3 and 4
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

        // Step 5
        // Issue a Basic Get to the DUT.
        MSG ("___ Step 5 ___" );
        MSG ("Issue a Basic Get to the DUT." );

        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);

        SEND Basic.Get( );
        EXPECT Basic.Report(Value == 0x00);

        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        WAIT ($GLOBAL_schemeSetDelay);

        // Step 6
        // Issue a Supervision Get [Command Class = 0x20, Command = 0xFF] to the DUT.
        // Note: This command does not exist in Basic CC.
        MSG ("___ Step 6 ___");
        MSG ("Send Supervision Get [Command Class = 0x20, Command = 0xFF]");
        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = 2,
            EncapsulatedCommand = [0x20, 0xFF]);
        EXPECTOPT Supervision.Report(
            SessionId == $GLOBAL_sessionId,
            Reserved == 0,
            MoreStatusUpdates == 0,
            Status == 0x00, // 0x00=NO_SUPPORT
            Duration == 0);
        SETCURRENTSCHEME("NONE");
        SENDRAW([0x00]); // NOP
        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);
    } // LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)

    SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
    WAIT ($GLOBAL_schemeSetDelay);

    MSG ("Finished.");

TESTSEQ END

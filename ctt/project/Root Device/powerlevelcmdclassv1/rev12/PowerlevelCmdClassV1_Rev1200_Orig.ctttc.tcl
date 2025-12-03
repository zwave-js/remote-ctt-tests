PACKAGE PowerlevelCmdClassV1_Rev1200_Orig; // do not modify this line
USE Powerlevel CMDCLASSVER = 1;
USE Supervision CMDCLASSVER = 1;

/**
 * Powerlevel Command Class Version 1 Test Script
 * Command Class Specification: SDS13784 2020C
 * Formatting Conventions: Version 2016-05-19
 *
 * PLEASE NOTE:
 * - The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run
 * - The 'Interactive_SupervisionHighestSecurity' requires preparation. See header comment.
 *
 * ChangeLog:
 *
 * October 23rd, 2013   - First release
 * April 4th, 2016      - Refactoring, new Test Sequences for LinkTests
 * April 15th, 2016     - Refactoring
 * April 27th, 2016     - USB disconnect message fixed
 * May 25th, 2016       - Minor improvements
 * June 1st, 2016       - Minor improvements
 * June 16th, 2016      - Timing and user guidance changed in 'LinkTestDisconnectedNode'
 * September 28th, 2016 - User guidance for battery devices added in 'LinkTestDisconnectedNode'
 * November 18th, 2016  - Timeout $timeToWait increased in 'LinkTestDisconnectedNode'
 * May 17th, 2017       - Support for unsolicited TestNodeReport in 'LinkTestValidNode' and 'LinkTestInvalidNode'
 * November 1st, 2017   - Check for countdown of Timeout in 'TimeoutTest'
 * December 21st, 2017  - Bugfix 'LinkTestValidNode' and 'LinkTestInvalidNode': EXPECTOPT-Timeout in seconds.
 * January 24th, 2018   - Check for unsolicited frame additionally with ISNULL in 'LinkTestValidNode' and 'LinkTestInvalidNode'
 * June 27th, 2018      - New Test Sequence 'SupervisionHighestSecurityForPowerlevel'
 * December 15th, 2018  - New Test Sequence 'SupervisionLowerSecurityForPowerlevel'
 * December 21st, 2018  - New Test Sequence 'SupervisionNoneSecureInclusionForPowerlevel'
 * Januar 7th, 2019     - New Test Sequence 'SupervisionLowerSecurityForPowerlevel'
 *                      - New test sequence 'SetInitialValuesAndVariables'
 *                      - Edit test sequence 'SupervisionHighestSecurityForPowerlevel'
 * March 5th, 2019      - Bug-Fix 'SupervisionLowerSecurityForPowerlevel'
 * May 15th, 2019       - Small Bug-Fix at 'SupervisionLowerSecurityForPowerlevel'
 * November 5th, 2020   - Migration to CTTv3 project format
 *                      - Detection of Root Device / End Point ID using CTTv3 script language features
 *                      - Improvements in Supervision using current script language features
 *                      - Renamed: Prefix 'Interactive_...' added to 'LinkTestDisconnectedNode',
 *                        'SupervisionHighestSecurity' and 'SupervisionLowerSecurityLevel'
 * December 4th, 2020   - 'Interactive_LinkTestDisconnectedNode' removed (commented out) due to problems in CTTv3.
 *                        The test will be replaced by a ZATS test case.
 * March 1st, 2021      - 'TimeoutTest' redesigned based on GETTIMEMS() to get better expectations for FLiRS nodes (CS-149)
 *                      - Number of frames (100->80) and wait time (10->8) decreased in 'LinkTestValidNode'
 *                      - Check for battery device (support of Wake Up CC) added to avoid unnecessary and
 *                        force necessary user interactions (CS-149)
 * August 25th, 2021    - Global variable for CTT Controller Node ID added.
 *                      - Sequences 'LinkTestValidNode', 'LinkTestInvalidNode', 'Interactive_SupervisionHighestSecurity' and
 *                        'Interactive_SupervisionLowerSecurityLevel' removed. Replaced by ZATS Test Case.
 * November 11th, 2021  - Reworking of all non-security and lower security Supervision sequences. Applied EXPECTOPT for Supervision Report.
 * October 13th, 2022   - Removed offensive terminology.
 *
 */


/**
 * SetInitialValuesAndVariables
 * This sequence sets the global variables and initial values for the tests of this command class.
 * This sequence MUST be executed in each test run.
 * If it is not executed, this will lead to errors in the following test sequences.
 *
 * CC versions: 1
 */

TESTSEQ SetInitialValuesAndVariables: "Set initial Values and Variables."

    // Test environment configuration - MAY be changed
    GLOBAL $GLOBAL_sessionId = 1;           // Adjust if specific Supervision Session ID is needed.
    //GLOBAL $GLOBAL_cttControllerId = 1;     // For removed sequences only. Adjust if the DUT has included the CTT Controller.

    // Test data - MUST NOT be changed
    GLOBAL $GLOBAL_endPointId = GETENDPOINT();
    GLOBAL $GLOBAL_commandClassId = 0x73;
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Powerlevel";
    GLOBAL $GLOBAL_invalidCommand = 0xFF;
    GLOBAL $GLOBAL_isBatteryDevice = 0;

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
        MSG ("Supervision CC is not in the Root Device NIF.");
    }

    // Command Class Support: Analyze NIF / Supported Report of Root Device or End Point
    IF (INARRAY($GLOBAL_commandClasses, $GLOBAL_commandClassId) == true)
    {
        $GLOBAL_ccIsInNIF = 1;
        MSG ("{0} CC is unsecure supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }
    ELSEIF (INARRAY($GLOBAL_secureCommandClasses, $GLOBAL_commandClassId) == true)
    {
        $GLOBAL_ccIsInNIF = 1;
        MSG ("{0} CC is secure supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }
    IF ($GLOBAL_ccIsInNIF == 0)
    {
        MSG ("{0} CC is not announced as supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }

    IF ($GLOBAL_endPointId != 0 && $GLOBAL_ccIsInNIF != 0)
    {
        MSG ("Warning: {0} CC SHOULD NOT be supported on Multichannel End Points.", #GLOBAL_commandClassText);
    }

    // Command Class Support: Analyze NIF / Supported Report of Root Device or End Point for Wake Up CC
    IF (INARRAY($GLOBAL_commandClasses, 0x84) == true)
    {
        $GLOBAL_isBatteryDevice = 1;
        MSG ("Wake Up CC is unsecure supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }
    ELSEIF (INARRAY($GLOBAL_secureCommandClasses, 0x84) == true)
    {
        $GLOBAL_isBatteryDevice = 1;
        MSG ("Wake Up CC is secure supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }
    ELSE
    {
        MSG ("Wake Up CC is not announced as supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
    }

TESTSEQ END


/**
 * InitialValues
 * Validates the current powerlevel values
 *
 * CC versions: 1
 */

TESTSEQ InitialValues: "Check initial values"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        $powerLevel = PowerLevel in (0x00 ... 0x09),
        $timeout    = Timeout);

    IF ($powerLevel == 0x00)
    {
        MSGPASS ("PowerLevel: NormalPower");
    }
    ELSEIF (($powerLevel >= 0x01) && ($powerLevel <= 0x09))
    {
        IF ($timeout > 0)
        {
            MSGPASS ("PowerLevel: minus{0}dBm   Timeout: {1} seconds", UINT($powerLevel), UINT($timeout));
        }
        ELSE
        {
            MSGFAIL ("PowerLevel: minus{0}dBm   Timeout: 0. It MUST be greater than 0 if the PowerLevel is not 'NormalPower'", UINT($powerLevel));
        }
    }
    ELSE
    {
        MSGFAIL ("PowerLevel: {0} - Not allowed   Timeout: {1} seconds", UINT($powerLevel), UINT($timeout));
    }

TESTSEQ END


/**
 * TimeoutTest
 * Tests the timeout functionality
 * Checks the reported timeout value 0, 3, 8, 13 and 21 seconds after setting a lower powerlevel
 *
 * CC versions: 1
 */

TESTSEQ TimeoutTest: "Tests the timeout functionality"

    $powerLevel = 7;
    $timeoutInSeconds = 20;   // Timeout value
    $sendDelay = 100;         // Configured 'Delay after Send' option of CTT (default: 100 ms)
    $tol = 2;                 // Tolerance in seconds

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Expect NormalPower and wake up Listening Sleeping End Node for the correct timing of following commands
    SEND Powerlevel.Get( );
    MSG ("Expecting NormalPower...");
    EXPECT Powerlevel.Report(
        PowerLevel == 0,
        Timeout == 0);

    MSG ("Configure a Powerlevel of minus{0}dBm for {1} seconds", UINT($powerLevel), UINT($timeoutInSeconds));
    SEND Powerlevel.Set(
        PowerLevel = $powerLevel,
        Timeout = $timeoutInSeconds);

    $time0 = GETTIMEMS();
    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == $powerLevel,
        Timeout > ($timeoutInSeconds - $tol));

    WAIT (3000 - $sendDelay);
    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == $powerLevel,
        $reportedTimeout = Timeout in (1 ... $timeoutInSeconds));
    $time1 = GETTIMEMS();
    $expectedMinTimeout = $timeoutInSeconds - (($time1 - $time0) / 1000) - $tol;
    $expectedMaxTimeout = $timeoutInSeconds - (($time1 - $time0) / 1000) + $tol;
    MSG ("Status #1: time0={0}, time1={1}, diff={2}, expected: 0x{3:X2} to 0x{4:X2}, received: 0x{5:X2}", $time0, $time1, $time1 - $time0, $expectedMinTimeout, $expectedMaxTimeout, $reportedTimeout);
    IF ($reportedTimeout < $expectedMinTimeout)
    {
        MSGFAIL ("Reported Timeout value 0x{0:X2} is too small.", $reportedTimeout);
    }
    IF ($reportedTimeout > $expectedMaxTimeout)
    {
        MSGFAIL ("Reported Timeout value 0x{0:X2} is too big.", $reportedTimeout);
    }

    WAIT (5000 - $sendDelay);
    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == $powerLevel,
        $reportedTimeout = Timeout in (1 ... $timeoutInSeconds));
    $time2 = GETTIMEMS();
    $expectedMinTimeout = $timeoutInSeconds - (($time2 - $time0) / 1000) - $tol;
    $expectedMaxTimeout = $timeoutInSeconds - (($time2 - $time0) / 1000) + $tol;
    MSG ("Status #2: time0={0}, time2={1}, diff={2}, expected: 0x{3:X2} to 0x{4:X2}, received: 0x{5:X2}", $time0, $time2, $time2 - $time0, $expectedMinTimeout, $expectedMaxTimeout, $reportedTimeout);
    IF ($reportedTimeout < $expectedMinTimeout)
    {
        MSGFAIL ("Reported Timeout value 0x{0:X2} is too small.", $reportedTimeout);
    }
    IF ($reportedTimeout > $expectedMaxTimeout)
    {
        MSGFAIL ("Reported Timeout value 0x{0:X2} is too big.", $reportedTimeout);
    }

    WAIT (5000 - $sendDelay);
    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == $powerLevel,
        $reportedTimeout = Timeout in (1 ... $timeoutInSeconds));
    $time3 = GETTIMEMS();
    $expectedMinTimeout = $timeoutInSeconds - (($time3 - $time0) / 1000) - $tol;
    $expectedMaxTimeout = $timeoutInSeconds - (($time3 - $time0) / 1000) + $tol;
    MSG ("Status #3: time0={0}, time3={1}, diff={2}, expected: 0x{3:X2} to 0x{4:X2}, received: 0x{5:X2}", $time0, $time3, $time3 - $time0, $expectedMinTimeout, $expectedMaxTimeout, $reportedTimeout);
    IF ($reportedTimeout < $expectedMinTimeout)
    {
        MSGFAIL ("Reported Timeout value 0x{0:X2} is too small.", $reportedTimeout);
    }
    IF ($reportedTimeout > $expectedMaxTimeout)
    {
        MSGFAIL ("Reported Timeout value 0x{0:X2} is too big.", $reportedTimeout);
    }

    // make sure to wait longer than the timeout
    WAIT (($timeoutInSeconds - 3 - 5 -5 + 1) * 1000);

    // expect NormalPower
    SEND Powerlevel.Get( );
    MSG ("Expecting NormalPower after timeout elapsed...");
    EXPECT Powerlevel.Report(
        PowerLevel == 0,
        Timeout == 0);

TESTSEQ END


/**
 * TimeoutIgnore
 * Verifies that timeout is ignored with powerlevel 0
 *
 * CC versions: 1
 */

TESTSEQ TimeoutIgnore: "Check that timeout is ignored with powerlevel = 0"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    $timeoutInSeconds = 120;
    MSG ("Configure a Powerlevel of 0 for {0} seconds", UINT($timeoutInSeconds));
    SEND Powerlevel.Set(
        PowerLevel = 0,
        Timeout    = $timeoutInSeconds);
    SEND Powerlevel.Get( );
    MSG ("Expecting NormalPower immediately...");
    EXPECT Powerlevel.Report(
        PowerLevel == 0,
        Timeout    == 0);

TESTSEQ END


/**
 * InvalidPowerlevel
 * Checks handling of invalid powerlevel values
 *
 * CC versions: 1
 */

TESTSEQ InvalidPowerlevel: "Check invalid powerlevel"

    $invalidPowerLevel = 20;
    $timeoutInSeconds = 60;

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Set to NormalPower
    MSG ("Set to NormalPower");
    SEND Powerlevel.Set(
        PowerLevel = 0,
        Timeout    = 0);
    WAIT (1000);
    // Set to an invalid power level
    MSG ("Configure an invalid Powerlevel of minus{0}dBm for {1} seconds", UINT($invalidPowerLevel), UINT($timeoutInSeconds));
    SEND Powerlevel.Set(
        PowerLevel = $invalidPowerLevel,
        Timeout    = $timeoutInSeconds);
    SEND Powerlevel.Get( );
    MSG ("Expecting NormalPower immediately...");
    // Expecting power level 0 (timeout will be ignored)
    EXPECT Powerlevel.Report(
        $powerLevel = PowerLevel == 0x00,
        $currentTimeout = Timeout);
    // This check is only necessary, if a DUT interpolates the invalid power level value to minus9dBm (not specified so!)
    /*IF (($powerLevel != 0) && ($currentTimeout != 0) && ($currentTimeout < $timeoutInSeconds - 2))
    {
        MSGFAIL ("Invalid Timeout Value {0} reported.", UINT($currentTimeout));
    }*/

TESTSEQ END


/**
 * InitialTestReport
 * Checks the initial Test Report for valid values
 *
 * CC versions: 1
 */

TESTSEQ InitialTestReport: "Check initial Test Report"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND Powerlevel.TestNodeGet( );
    EXPECT Powerlevel.TestNodeReport(
        $testNodeId        = TestNodeId        in (0 ... 232),
        $statusOfOperation = StatusOfOperation in (0, 1, 2),
        $testFrameCount    = TestFrameCount    in (0x00 ... 0xFFFF));

    IF (ISNULL($testNodeId))
    {
        MSGFAIL ("The DUT does not respond a Test Node Report");
    }
    ELSE
    {
        MSG ("Test NodeID:       0x{0:X2}", $testNodeId);
        MSG ("Test frame count:  {0}", UINT($testFrameCount));

        IF     ($statusOfOperation == 0) { MSG ("Status of operation: ZW_TEST_FAILED"); }
        ELSEIF ($statusOfOperation == 1) { MSG ("Status of operation: ZW_TEST_SUCCESS"); }
        ELSEIF ($statusOfOperation == 2) { MSG ("Status of operation: ZW_TEST_INPROGRESS"); }
        ELSE                             { MSGFAIL ("Status of operation: 0x{0:X2} - Reserved", $statusOfOperation); }
    }

TESTSEQ END


/**
 * LinkTestValidNode
 * Checks the Test Node functionality with a valid node ID
 *
 * CAUTION: Please check the value of the variable $testNodeId (below).
 *          It MUST be set to the node ID of your Static Controller.
 *          The Static Controller normally has the node ID 0x01.
 *
 * CC versions: 1
 */

/*
TESTSEQ LinkTestValidNode: "Check Test Node functionality with a valid node ID"

    $testNodeId = $GLOBAL_cttControllerId;     // MUST be an existing Node ID (e.g. the CTT Controller’s Node ID)
    $powerLevel = 3;        // power level for this test
    $framesToSend = 80;     // number of frames to send
    $delay1 = 2000;         // delay for Get Report DURING the powerlevel test; may be decreased
    $timeToWait = 10;       // wait time until end of test

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    MSG ("TestNodeSet for node 0x{0:X2} with {2} frames and power level {1}.", $testNodeId, UINT($powerLevel), UINT($framesToSend));
    MSG ("May be the node ID (variable $testNodeId) has to be altered.");
    SEND Powerlevel.TestNodeSet(
        TestNodeId = $testNodeId,
        PowerLevel = $powerLevel,
        TestFrameCount = CONV($framesToSend, 2));

    WAIT ($delay1);

    // verify the DUT answers correctly to a Test Node Get commands DURING a powerlevel test
    SEND Powerlevel.TestNodeGet( );
    EXPECT Powerlevel.TestNodeReport(
        TestNodeId == $testNodeId,
        StatusOfOperation == 2,
        TestFrameCount in (0 ... $framesToSend));

    MSG ("Wait {0} seconds until the test is completed. (May be this interval has to be altered)", UINT($timeToWait));

    // waiting for recommended unsolicited report
    $statusOfOperation = 0xBB;
    EXPECTOPT Powerlevel.TestNodeReport($timeToWait,
        TestNodeId == $testNodeId,
        $statusOfOperation = StatusOfOperation == 0x01,
        TestFrameCount in (0 ... $framesToSend));
    // issue the subsequent TestNodeGet only if no unsolicited report with the result received
    IF (ISNULL($statusOfOperation))
    {
        SEND Powerlevel.TestNodeGet( );
        EXPECT Powerlevel.TestNodeReport(
            $testNodeId        = TestNodeId        == $testNodeId,
            $statusOfOperation = StatusOfOperation == 0x01,
            $testFrameCount    = TestFrameCount    in (0 ... $framesToSend));
    }
    ELSEIF ($statusOfOperation == 0xBB)
    {
        SEND Powerlevel.TestNodeGet( );
        EXPECT Powerlevel.TestNodeReport(
            $testNodeId        = TestNodeId        == $testNodeId,
            $statusOfOperation = StatusOfOperation == 0x01,
            $testFrameCount    = TestFrameCount    in (0 ... $framesToSend));
    }

    MSG ("Test NodeID:       0x{0:X2}", $testNodeId);
    MSG ("Test frame count:    {0}", UINT($testFrameCount));

    IF     ($statusOfOperation == 0) { MSGFAIL ("Status of operation: ZW_TEST_FAILED (try to alter node ID)"); }
    ELSEIF ($statusOfOperation == 1) { MSGPASS ("Status of operation: ZW_TEST_SUCCESS"); }
    ELSEIF ($statusOfOperation == 2) { MSGFAIL ("Status of operation: ZW_TEST_INPROGRESS (try to increase variable $timeToWait)"); }
    ELSE                             { MSGFAIL ("Status of operation: 0x{0:X2} - Reserved", $statusOfOperation); }

    // After the powerlevel test the RF power level has to be reset to normal power level
    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == 0,
        Timeout    == 0);

TESTSEQ END // LinkTestValidNode
*/


/**
 * LinkTestInvalidNode
 * Checks the Test Node functionality with an invalid node ID
 *
 * CAUTION: Please check the value of the variable $testNodeId (below).
 *          It MUST be set to an invalid node ID.
 *
 * CC versions: 1
 */

/*
TESTSEQ LinkTestInvalidNode: "Check Test Node functionality with an invalid node ID"

    $testNodeId = 0xAA;     // MUST be an invalid node ID
    $powerLevel = 3;        // power level for this test
    $framesToSend = 10;     // number of frames to send
    $delay1 = 1000;         // delay for Get Report DURING the powerlevel test. May be decreased.
    $timeToWait = 5;        // wait time until end of test

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    MSG ("TestNodeSet for node 0x{0:X2} with {2} frames and power level {1}.", $testNodeId, UINT($powerLevel), UINT($framesToSend));
    MSG ("May be the node ID (variable $testNodeId) has to be altered.");
    SEND Powerlevel.TestNodeSet(
        TestNodeId = $testNodeId,
        PowerLevel = $powerLevel,
        TestFrameCount = CONV($framesToSend, 2));

    WAIT ($delay1);

    // verify the DUT answers correctly to a Test Node Get commands DURING the powerlevel test
    SEND Powerlevel.TestNodeGet( );
    EXPECT Powerlevel.TestNodeReport(
        TestNodeId == $testNodeId,
        StatusOfOperation == 2,
        TestFrameCount == 0);

    MSG ("Wait {0} seconds until the test is completed. (May be this interval has to be altered)", UINT($timeToWait));

    // waiting for recommended unsolicited report
    $statusOfOperation = 0xBB;
    EXPECTOPT Powerlevel.TestNodeReport($timeToWait,
        TestNodeId == $testNodeId,
        $statusOfOperation = StatusOfOperation == 0x00,
        TestFrameCount in (0 ... $framesToSend));
    // issue the subsequent TestNodeGet only if no unsolicited report with the result received
    IF (ISNULL($statusOfOperation))
    {
        SEND Powerlevel.TestNodeGet( );
        EXPECT Powerlevel.TestNodeReport(
            $testNodeId        = TestNodeId        == $testNodeId,
            $statusOfOperation = StatusOfOperation == 0x00,
            $testFrameCount    = TestFrameCount    in (0 ... $framesToSend));
    }
    ELSEIF ($statusOfOperation == 0xBB)
    {
        SEND Powerlevel.TestNodeGet( );
        EXPECT Powerlevel.TestNodeReport(
            $testNodeId        = TestNodeId        == $testNodeId,
            $statusOfOperation = StatusOfOperation == 0x00,
            $testFrameCount    = TestFrameCount    in (0 ... $framesToSend));
    }

    MSG ("Test NodeID:       0x{0:X2}", $testNodeId);
    MSG ("Test frame count:  {0}", UINT($testFrameCount));

    IF     ($statusOfOperation == 0) { MSGPASS ("Status of operation: ZW_TEST_FAILED"); }
    ELSEIF ($statusOfOperation == 1) { MSGFAIL ("Status of operation: ZW_TEST_SUCCESS (try to alter node ID)"); }
    ELSEIF ($statusOfOperation == 2) { MSGFAIL ("Status of operation: ZW_TEST_INPROGRESS (try to increase variable $timeToWait)"); }
    ELSE                             { MSGFAIL ("Status of operation: 0x{0:X2} - Reserved", $statusOfOperation); }

    // After the powerlevel test the RF power level has to be reset to normal power level
    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == 0,
        Timeout    == 0);

TESTSEQ END // LinkTestInvalidNode
*/


/**
 * Interactive_LinkTestDisconnectedNode
 * Checks the Test Node functionality with a further valid node ID. This node is disconnected during the test.
 *
 * CAUTION: Please check the values of the variables $controllerNodeId and $testNodeId (below).
 *          Variable $controllerNodeId MUST be set to the node ID of your Static Controller.
 *          The Static Controller normally has the node ID 0x01.
 *          Variable $testNodeId MUST be set to the node ID of a Z-Wave Developer Board with a
 *          Z-Wave 'Switch On/Off' Sample Application loaded, which is already included in the
 *          network. This is not the node ID of the DUT!
 *
 *          Test sequence preparation:
 *          - Prepare a Z-Wave Developer Board with the 'Switch On/Off' Sample Application
 *          - Include this device into the Z-Wave network (as additional device)
 *          - Set the variable $testNodeId to the node ID of this device
 *          - Check the value of the variable $cntrlNodeId (your Static Controller)
 *          Test sequence execution:
 *          - Start this Test Sequence
 *          - The preparation check takes approximately 12 seconds
 *          - Ensure that a battery device is awake before clicking 'Yes' in the confirmation window
 *          - You will see the following demand message in the Output Window of CTT:
 *            "----- Now disconnect the Developer Board from USB port for 2 seconds! -----"
 *            Disconnect the Developer Board from it's USB port for 2 seconds.
 *          - After 2 seconds you will see the following demand message in the Output Window of CTT:
 *            "----- Now connect the Developer Board to USB port again! -----"
 *            Connect the Developer Board to it's USB port again.
 *          - After finishing the test successful exclude the Developer Board from the network
 *          Note: You MAY change the timing of the Test Sequence according to your DUT.
 *          Suggestion: You MAY run this Test Sequence separately.
 *
 * CC versions: 1
 */

/*
TESTSEQ Interactive_LinkTestDisconnectedNode: "Check Test Node functionality with a further valid node ID, the node is disconnected during the test"

    $cntrlNodeId = $GLOBAL_cttControllerId;    // MUST be the Static Controller node ID
    $testNodeId = 0x03;     // MUST be the node ID of a Z-Wave Developer Board with a Z-Wave 'Switch On/Off' Sample Application
                            //   loaded, which is already included in the network. Not the DUT node ID!
    $powerLevel = 3;        // power level for this test
    $framesToSend = 150;    // number of frames to send

    $delayInCheck = 5000;           // delay for Get Report in the check of Test Sequence preparation. May be increased.
    $delayBeforeDisconnect = 2000;  // wait time before 'disconnect device' message
    $delayBeforeReconnect = 6000;   // wait time before 'reconnect device' message = time to disconnect the Developer Board

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Try to check the Test Sequence preparation of the customer
    MSG ("Check for correct Test Sequence preparation");
    IF ($cntrlNodeId == $testNodeId)
    {
        MSGFAIL ("The Test Sequence is not correctly configured. Please read Test Sequence header comment.");
    }
    MSG ("Check access to Z-Wave Developer Board (node ID 0x{0:X2})", $testNodeId);
    SEND Powerlevel.TestNodeSet(
        TestNodeId = $testNodeId,
        PowerLevel = $powerLevel,
        TestFrameCount = CONV(5, 2));
    WAIT ($delayInCheck);
    SEND Powerlevel.TestNodeGet( );
    EXPECT Powerlevel.TestNodeReport(
        TestNodeId == $testNodeId,
        $status1 = StatusOfOperation == 1,
        ($testFrameCount1 = TestFrameCount) > 0);
    MSG ("Check access to Static Controller (node ID 0x{0:X2})", $cntrlNodeId);
    SEND Powerlevel.TestNodeSet(
        TestNodeId = $cntrlNodeId,
        PowerLevel = $powerLevel,
        TestFrameCount = CONV(5, 2));
    WAIT ($delayInCheck);
    SEND Powerlevel.TestNodeGet( );
    EXPECT Powerlevel.TestNodeReport(
        TestNodeId == $cntrlNodeId,
        $status2 = StatusOfOperation == 1,
        ($testFrameCount2 = TestFrameCount) > 0);
    IF (($status1 != 1) || (UINT($testFrameCount1) == 0))
    {
        MSGFAIL ("Developer Board with 'Switch On/Off' Sample App (testNodeId 0x{0:X2}) not reached or StatusOfOperation is not 'Success'. Is the Test Sequence correctly configured? Please read Test Sequence header comment.", $testNodeId);
    }
    ELSEIF (($status2 != 1) || (UINT($testFrameCount2) == 0))
    {
        MSGFAIL ("Controller (cntrlNodeId 0x{0:X2}) not reached or StatusOfOperation is not 'Success'. Is the Test Sequence correctly configured? Please read Test Sequence header comment.", $cntrlNodeId);
    }
    ELSE
    {
        // the test itself starts here
        MSGBOXYES ("LinkTestDisconnectedNode - this test requires tester interaction. Please refer to the Test Sequence header comment. Are you ready (battery device is awake) ?");

        MSG ("TestNodeSet for node 0x{0:X2} with {2} frames and power level {1}.", $testNodeId, UINT($powerLevel), UINT($framesToSend));
        SEND Powerlevel.TestNodeSet(
            TestNodeId = $testNodeId,
            PowerLevel = $powerLevel,
            TestFrameCount = CONV($framesToSend, 2));

        WAIT ($delayBeforeDisconnect);
        MSG ("----- Now disconnect the Developer Board from USB port for {0} seconds! -----", UINT($delayBeforeReconnect / 1000));
        MSG ("----- You will see a message here if this time has expired.");
        WAIT ($delayBeforeReconnect);
        MSG ("----- Now connect the Developer Board to USB port again! -----");

        $timeToWait = 20000;    // may be increased if final operation status is ZW_TEST_INPROGRESS
        MSG ("Wait {0} seconds until the test is completed. You may increase this interval ($timeToWait) if necessary.", UINT($timeToWait / 1000));
        MSG ("Be sure to wake up a battery powered device in time.");
        WAIT ($timeToWait);

        SEND Powerlevel.TestNodeGet( );
        EXPECT Powerlevel.TestNodeReport(
            $testNodeId        = TestNodeId        == $testNodeId,
            $statusOfOperation = StatusOfOperation in (0 ... 2),
            $testFrameCount    = TestFrameCount    in (0 ... $framesToSend));

        MSG ("Test NodeID:       0x{0:X2}", $testNodeId);
        MSG ("Test frame count:  {0} of {1}", UINT($testFrameCount), UINT($framesToSend));

        IF     ($testFrameCount == 0)             { MSGFAIL ("Test node not reached. Check the Test Sequence configuration."); }
        ELSEIF ($testFrameCount == $framesToSend) { MSGFAIL ("Test node has received all frames. Try to decrease $delayBeforeDisconnect."); }
        ELSE                                      { MSGPASS ("Test node was replying during it's connection with USB power."); }

        IF     ($statusOfOperation == 0) { MSGFAIL ("Received status of operation: ZW_TEST_FAILED"); }
        ELSEIF ($statusOfOperation == 1) { MSGPASS ("Received status of operation: ZW_TEST_SUCCESS"); }
        ELSEIF ($statusOfOperation == 2) { MSGFAIL ("Received status of operation: ZW_TEST_INPROGRESS (try to increase variable $timeToWait)"); }
        ELSE                             { MSGFAIL ("Status of operation: 0x{0:X2} - Reserved", $statusOfOperation); }
    } // IF (preparation was ok)

    // After the powerlevel test the RF power level has to be reset to normal power level
    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == 0,
        Timeout    == 0);

TESTSEQ END // LinkTestDisconnectedNode
*/


/**
 * Interactive_SupervisionHighestSecurity
 * Powerlevel CC: Supervision Status Codes at the Highest Security Level
 *
 * CAUTION: This test requires tester interaction.
 *
 *          Test sequence preparation:
 *          - Check the value of the variable $testNodeId (below). This is not the NodeID of the DUT!
 *            It should be set to the NodeID of your Static Controller which normally is NodeID=0x01.
 *          - Start capturing frames with the Z-Wave Zniffer.
 *          - Start this Test Sequence.
 *          - You will see 3 confirmation windows during the test.
 *          - Ensure that a battery device is awake before clicking 'Yes' in the confirmation windows.
 *
 *          Suggestion: It is recommended to run this Test Sequence separately because it won't
 *                      complete without user interaction.
 *
 * CC versions: 1
 */

/*
TESTSEQ Interactive_SupervisionHighestSecurity: "Supervision Status Codes at the Highest Security Level"

    $testNodeId = $GLOBAL_cttControllerId; // MUST be an available NodeID, e.g. the Static Controller NodeID

    IF (ISNULL($GLOBAL_sessionId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    IF ($GLOBAL_isBatteryDevice == 1)
    {
        MSGBOXYES ("Ensure battery device is awake before clicking 'Yes'! (Interactive_SupervisionHighestSecurity)");
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

    IF ($GLOBAL_ccIsInNIF == 0 && $GLOBAL_endPointId == 0)
    {
        // Step 3 (CC is not in NIF)
        // Issue a Supervision Get [Powerlevel Set (Powerlevel=0xF0, Timeout=10)] to the DUT.
        MSG ("___ Step 3 ___");
        MSG ("Send Supervision Get [Powerlevel Set (Powerlevel=0xF0, Timeout=10=0x0A)]");

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Powerlevel
                        0x01,    // Command Powerlevel.Set
                        0xF0,    // PowerLevel
                        0x0A     // Timeout
                        ];

        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = LENGTH($auxEncapCmd),
            EncapsulatedCommand = $auxEncapCmd);
        EXPECT Supervision.Report(
            SessionId == $GLOBAL_sessionId,
            Reserved == 0,
            MoreStatusUpdates == 0,
            Status == 0x00, // 0x00=NO_SUPPORT
            Duration == 0);
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

        EXITSEQ;
    } // IF ($GLOBAL_ccIsInNIF == 0 && $GLOBAL_endPointId == 0)

    // Step 3 (CC is in NIF)
    // Issue a Supervision Get [Powerlevel Set (Powerlevel=0xF0, Timeout=10)] to the DUT.
    MSG ("___ Step 3 ___");
    MSG ("Send Supervision Get [Powerlevel Set (Powerlevel=0xF0, Timeout=10=0x0A)]");

    $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Powerlevel
                    0x01,    // Command Powerlevel.Set
                    0xF0,    // PowerLevel
                    0x0A     // Timeout
                    ];

    SEND Supervision.Get(
        SessionId = $GLOBAL_sessionId,
        Reserved = 0,
        StatusUpdates = 0,
        EncapsulatedCommandLength = LENGTH($auxEncapCmd),
        EncapsulatedCommand = $auxEncapCmd);
    EXPECT Supervision.Report(
        SessionId == $GLOBAL_sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        Status == 0x02, // 0x02=FAIL
        Duration == 0);
    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

    // Step 4
    // Issue a Powerlevel Get to the DUT.
    MSG ("___ Step 4 ___");

    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == 0,
        Timeout == 0);

    // Step 5
    // Issue a Supervision Get [Powerlevel Set (Powerlevel=0x03, Timeout=08)] to the DUT.
    MSG ("___ Step 5 ___");
    MSG ("Send Supervision Get [Powerlevel Set (Powerlevel=0x03, Timeout=8=0x08)]");

    $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Powerlevel
                    0x01,    // Command Powerlevel.Set
                    0x03,    // PowerLevel
                    0x08     // Timeout
                    ];

    SEND Supervision.Get(
        SessionId = $GLOBAL_sessionId,
        Reserved = 0,
        StatusUpdates = 0,
        EncapsulatedCommandLength = LENGTH($auxEncapCmd),
        EncapsulatedCommand = $auxEncapCmd);
    EXPECT Supervision.Report(
        SessionId == $GLOBAL_sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        Status == 0xFF, // 0xFF=SUCCESS
        Duration == 0);
    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

    // Step 6
    // Issue a Powerlevel Get to the DUT.
    MSG ("___ Step 6 ___");

    SEND Powerlevel.Get( );
    EXPECT Powerlevel.Report(
        PowerLevel == 0x03,
        Timeout in 1 ... 8);

    MSG ("Wait for 8 seconds to reach normal Powerlevel=0x00 again.");
    WAIT (8000);


    // Zniffer frame capturing is needed for steps 6 to 9
    MSG ("Supervision [Powerlevel Test Node Set] - This test requires tester interaction. Please refer to the test sequence header comment.");
    MSGBOXYES ("Has the Zniffer frame capturing been started?     Ensure battery device is awake before clicking 'Yes'!");

    // Step 7
    // Issue a Supervision Get [Powerlevel Test Node Set (TestNodeID=$testNodeId, Powerlevel=0x01, TestFrameCount=0x0000)] to the DUT.
    MSG ("___ Step 7 ___");
    MSG ("Send Supervision Get [Powerlevel Test Node Set (TestNodeID=0x{0:X2}, Powerlevel=0x01, TestFrameCount=0x0000)]", $testNodeId);

    $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Powerlevel
                    0x04,    // Command Powerlevel.TestNodeSet
                    $testNodeId,
                    0x01,    // PowerLevel
                    0x00,    // Test Frame Count MSB
                    0x00     // Test Frame Count LSB
                    ];

    SEND Supervision.Get(
        SessionId = $GLOBAL_sessionId,
        Reserved = 0,
        StatusUpdates = 0,
        EncapsulatedCommandLength = LENGTH($auxEncapCmd),
        EncapsulatedCommand = $auxEncapCmd);
    EXPECT Supervision.Report(
        SessionId == $GLOBAL_sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        Status == 0x02, // 0x02=FAIL
        Duration == 0);
    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

    // Step 8
    // Zniffer trace is checked for NOP Power frames after the Supervision Report command
    MSG ("___ Step 8 ___");
    MSGBOXNO ("Have any NOP Power frames been detected in the Zniffer trace?     Ensure battery device is awake before clicking 'Yes' or 'No'!");

    // Step 9
    // Issue a Supervision Get [Powerlevel Test Node Set (TestNodeID=$testNodeId, Powerlevel=0x01, TestFrameCount=0x0003)] to the DUT.
    MSG ("___ Step 9 ___");
    MSG ("Send Supervision Get [Powerlevel Test Node Set (TestNodeID=0x{0:X2}, Powerlevel=0x01, TestFrameCount=0x0003)]", $testNodeId, 1);

    $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Powerlevel
                    0x04,    // Command Powerlevel.TestNodeSet
                    $testNodeId,
                    0x01,    // PowerLevel
                    0x00,    // Test Frame Count MSB
                    0x03     // Test Frame Count LSB
                    ];

    SEND Supervision.Get(
        SessionId = $GLOBAL_sessionId,
        Reserved = 0,
        StatusUpdates = 0,
        EncapsulatedCommandLength = LENGTH($auxEncapCmd),
        EncapsulatedCommand = $auxEncapCmd);
    EXPECT Supervision.Report(
        SessionId == $GLOBAL_sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        Status == 0xFF, // 0xFF=SUCCESS
        Duration == 0);
    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

    // Step 10
    // Zniffer trace is checked for NOP Power frames after the Supervision Report command
    MSG ("___ Step 10 ___");
    MSGBOXYES ("Have three NOP Power frames been detected in the Zniffer trace? (Ensure battery device is awake before clicking 'Yes' or 'No'!)");

    // Step 11
    // Issue a Supervision Get [Command Class = $GLOBAL_commandClassId, Command = $GLOBAL_invalidCommand] to the DUT.
    // Note: This command does not exist in this CC.
    MSG ("___ Step 11 ___");
    MSG ("Send Supervision Get [Command Class = 0x{0:X2}, Command = 0x{1:X2}]", $GLOBAL_commandClassId, $GLOBAL_invalidCommand);

    SEND Supervision.Get(
        SessionId = $GLOBAL_sessionId,
        Reserved = 0,
        StatusUpdates = 0,
        EncapsulatedCommandLength = 2,
        EncapsulatedCommand = [$GLOBAL_commandClassId, $GLOBAL_invalidCommand]);
    EXPECT Supervision.Report(
        SessionId == $GLOBAL_sessionId,
        Reserved == 0,
        MoreStatusUpdates == 0,
        Status == 0x00, // 0x00=NO_SUPPORT
        Duration == 0);
    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

TESTSEQ END
*/


/**
 * Interactive_SupervisionLowerSecurityLevel
 * Powerlevel CC: Supervision Status Codes at Lower Security Level
 *
 * CC versions: 1
 */

/*
TESTSEQ Interactive_SupervisionLowerSecurityLevel: "Supervision Status Codes at Lower Security Level"

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

    IF ($GLOBAL_isBatteryDevice == 1)
    {
        MSGBOXYES ("Ensure battery device is awake before clicking 'Yes'! (Interactive_SupervisionLowerSecurityLevel)");
    }

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

    MSG ("Repeat steps 3 to 7 for each security level that is not the highest granted level.");

    LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)
    {
        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        WAIT ($GLOBAL_schemeSetDelay);

        // Step 3
        // Issue a Supervision Get [Powerlevel Set (Powerlevel=3, Timeout=10)] to the DUT.
        MSG ("___ Step 3 ___");
        MSG ("Send Supervision Get [Powerlevel Set (Powerlevel=3, Timeout=10)]");

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Powerlevel
                        0x01,    // Command Powerlevel.Set
                        0x03,    // PowerLevel
                        0x0A     // Timeout
                        ];

        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = LENGTH($auxEncapCmd),
            EncapsulatedCommand = $auxEncapCmd);
        EXPECTOPT Supervision.Report(
            SessionId == $GLOBAL_sessionId,
            Reserved == 0,
            MoreStatusUpdates == 0,
            Status == 0x00, // 0x00=NO_SUPPORT
            Duration == 0);
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

        // Step 4
        // Issue Powerlevel Get to the DUT.
        MSG ("___ Step 4 ___");
        MSG ("Send Powerlevel Get at highest granted security level.");

        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);

        SEND Powerlevel.Get( );
        EXPECT Powerlevel.Report(
            PowerLevel == 0x00,
            Timeout == 0);

        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        WAIT ($GLOBAL_schemeSetDelay);

        // Step 5
        // Issue a Supervision Get [Powerlevel Test Node Set (TestNodeID=0x01, TesFrameCount=0x0003, Powerlevel=0x01)] to the DUT.
        MSG ("___ Step 5 ___");
        MSG ("Send Supervision Get [Powerlevel Test Node Set (TestNodeID=0x01, TesFrameCount=0x0003, Powerlevel=0x01)]");

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Powerlevel
                        0x04,    // Command Powerlevel.TestNodeSet
                        $GLOBAL_cttControllerId,    // TestNodeid
                        0x01,    // PowerLevel
                        0x00,    // TestFrameCount MSB
                        0x03     // TestFrameCount LSB
                        ];

        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = LENGTH($auxEncapCmd),
            EncapsulatedCommand = $auxEncapCmd);
        EXPECTOPT Supervision.Report(
            SessionId == $GLOBAL_sessionId,
            Reserved == 0,
            MoreStatusUpdates == 0,
            Status == 0x00, // 0x00=NO_SUPPORT
            Duration == 0);
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

        // Step 6
        // Zniffer trace is checked for NOP Power frames after the Supervision Report command
        MSG ("___ Step 6 ___");
        MSGBOXNO ("Have any NOP Power frames been detected in the Zniffer trace?     Ensure battery device is awake before clicking 'Yes' or 'No'!");

        // Step 7
        // Issue a Supervision Get [Command Class = $GLOBAL_commandClassId, Command = $GLOBAL_invalidCommand] to the DUT.
        // Note: This command does not exist in Window Covering CC.
        MSG ("___ Step 7 ___");
        MSG ("Send Supervision Get [Command Class = 0x{0:X2}, Command = 0x{1:X2}]", $GLOBAL_commandClassId, $GLOBAL_invalidCommand);

        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = 2,
            EncapsulatedCommand = [$GLOBAL_commandClassId, $GLOBAL_invalidCommand]);
        EXPECTOPT Supervision.Report(
            SessionId == $GLOBAL_sessionId,
            Reserved == 0,
            MoreStatusUpdates == 0,
            Status == 0x00, // 0x00=NO_SUPPORT
            Duration == 0);
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);
    } // LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)

    SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
    WAIT ($GLOBAL_schemeSetDelay);

    MSG ("Finished.");

TESTSEQ END
*/
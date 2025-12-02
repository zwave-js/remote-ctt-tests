PACKAGE AssociationGrpInfoCmdClassV3_Rev0200_Orig; // do not modify this line
USE AssociationGrpInfo CMDCLASSVER = 3;
USE Association CMDCLASSVER = 1;

/**
 * Association Group Info Command Class Version 3 Test Script
 * Command Class Specification: SDS13782 2020B
 * Formatting Conventions: Version 2016-05-04
 *
 * PLEASE NOTE:
 * - The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run
 *
 * ChangeLog:
 *
 * October 15th, 2015   - VerifyGroupInfoListMode is able to deal with multiple group info reports
 *                      - VerifyGroupInfo prints profile categories
 *                      - VerifyGroupInfo checks for correct profile bytes for group 1 (Lifeline)
 *                      - Newly added with same content as Association Group Info Command Class Version 1 Test Script
 *                      - Added additional profile category Meter from CC version 2.
 * April 13th, 2016     - Refactoring
 *                      - Bugfix in VerifyGroupInfoListMode test sequence
 *                      - Added additional profile category Irrigation from CC version 3.
 * May 19th, 2016       - Refactoring
 * June 2nd, 2016       - Minor improvements
 * February 27th, 2017  - Irrigation CC added
 * December 6th, 2017   - Bugfix in VerifyGroupInfoListMode test sequence
 * September 17th, 2020 - VerifyGroupCommandList refactored based on current language features
 *                        Manual addition of new Command Classes / Commands is no longer required
 *                      - Minor log improvements
 *                      - 'SetInitialValuesAndVariables' introduced, checks for execution added
 * October 21st, 2020   - Migration to CTTv3 project format
 *                      - Detection of Root Device / End Point ID using CTTv3 script language features
 */


/**
 * SetInitialValuesAndVariables
 * This sequence sets the global variables and initial values for the tests of this command class.
 * This sequence MUST be executed in each test run.
 * If it is not executed, this will lead to errors in the following test sequences.
 *
 * CC versions: 1, 2, 3
 */

TESTSEQ SetInitialValuesAndVariables: "Set initial Values and Variables."

    // Test environment configuration - MAY be changed
  //GLOBAL $GLOBAL_sessionId = 1;      // Adjust if specific Supervision Session ID is needed.

    // Test data - MUST NOT be changed
    GLOBAL $GLOBAL_endPointId = GETENDPOINT();
    GLOBAL $GLOBAL_commandClassId = 0x59;
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Association Group Information";

    // Security and Supervision data - MUST NOT be changed
    GLOBAL $GLOBAL_schemeSetDelay = 0; // Testers only: Adjust temporarily, if the DUT needs a longer time for activating a Security Scheme
    GLOBAL #GLOBAL_supportedSchemes = GETSUPPORTEDSCHEMES();
    GLOBAL #GLOBAL_highestGrantedScheme = #GLOBAL_supportedSchemes[0];
    GLOBAL $GLOBAL_commandClasses = GETEPCOMMANDCLASSES($GLOBAL_endPointId);
    GLOBAL $GLOBAL_secureCommandClasses = GETEPSECURECOMMANDCLASSES($GLOBAL_endPointId);
    GLOBAL $GLOBAL_svIsInNIF = 0;
    GLOBAL $GLOBAL_ccIsInNIF = 0;
  //GLOBAL $GLOBAL_lastSessionId = 63;

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
    /*MSG ("Supervision: Analyze Root Device NIF.");
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
    }*/

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

TESTSEQ END


/**
 * VerifyGroupNames
 * Verifies the Association Group names
 *
 * CC versions: 1, 2, 3
 */

TESTSEQ VerifyGroupNames: "Verify Association Group Names"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND Association.GroupingsGet();
    EXPECT Association.GroupingsReport($supportedGroupings = SupportedGroupings);

    LOOP ($grp; 1; $supportedGroupings)
    {
        SEND AssociationGrpInfo.AssociationGroupNameGet(GroupingIdentifier = $grp);
        EXPECT AssociationGrpInfo.AssociationGroupNameReport(
            GroupingIdentifier == $grp,
            $length = LengthOfName,
            ANYBYTE(Name) in (0x00... 0xFF),
            $name = Name);
        IF (LENGTH($name) != $length)
        {
            MSGFAIL ("Error in length field of Assocation Group Name Report for group {0}. Reported 'LengthOfName' is {1}, real length is {2}.", UINT($grp), UINT($length), UINT(LENGTH($name)));
        }
        MSG ("UTF-8 encoded name of Group {0} is: {1} = {2}", UINT($grp), $name, GETBYTESTRING($name, "utf-8"));
    }

TESTSEQ END


/**
 * VerifyGroupInfoListModeOff
 * Verifies the Association Group Info with List Mode = 0
 *
 * CC versions: 3
 */

TESTSEQ VerifyGroupInfoListModeOff: "Verify Association Group Info with List Mode = 0"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND Association.GroupingsGet();
    EXPECT Association.GroupingsReport($supportedGroupings = SupportedGroupings);

    LOOP ($grp; 1; $supportedGroupings)
    {
        SEND AssociationGrpInfo.AssociationGroupInfoGet(
            Reserved = 0,
            ListMode = 0,
            RefreshCache = 0,
            GroupingIdentifier = $grp);
        EXPECT AssociationGrpInfo.AssociationGroupInfoReport(
            GroupCount == 1,
            DynamicInfo in (0, 1),
            ListMode == 0,
            $payload = vg1);

        IF (LENGTH($payload) != 7)
        {
            MSGFAIL ("Error in payload length Assocation Group Info Report for group {0}. Received {1}, expected 7.", UINT($grp), UINT(LENGTH($payload)));
        }
        IF ($payload[0] != UINT($grp))
        {
            MSGFAIL ("Expected Group Info for Group {0} received {1}", UINT($grp), UINT($payload[0]));
        }
        IF ($payload[1] != 0)
        {
            MSGFAIL ("Mode = 0 not set to 0. Received: {0}", UINT($payload[1]));
        }

        MSG ("Association Group {0} has profile byte MSB 0x{1:X2} and LSB 0x{2:X2} referencing the following categories:", UINT($grp), $payload[2], $payload[3]);

        IF ($payload[2] == 0x00)
        {
            IF     ($payload[3] == 0x00) { MSG ("General:Not Applicable - There is no specific class of events for this association group."); }
            ELSEIF ($payload[3] == 0x01) { MSG ("General:Lifeline - This association group is intended for all events relevant for the Lifeline group."); }
            ELSE                         { MSGFAIL ("General:Unknown - Invalid Profile LSB ({0:X2}).", $payload[3]); }
        }
        ELSEIF ($payload[2] == 0x20)
        {
            MSG ("Control Key 0x{0:X2} - Members of this association group are controlled in response to user input for key 0x{0:X2}.", $payload[3]);
        }
        ELSEIF ($payload[2] == 0x31)
        {
            MSG ("Sensor Type 0x{0:X2} - Members of this association group are controlled when the sensor value changes or receives a sensor report of the given sensor type.", $payload[3]);
        }
        ELSEIF ($payload[2] == 0x71)
        {
            MSG ("Notification Type 0x{0:X2} - Members of this association group are controlled when an event is detected or receives a notification of the given notification type.", $payload[3]);
        }
        ELSEIF ($payload[2] == 0x32)  // new in CC V2
        {
            MSG ("Meter Type 0x{0:X2} - Members of this association group receive meter reports or they are controlled when a metering event is detected.", $payload[3]);
        }
        ELSEIF ($payload[2] == 0x6B)  // new in CC V3
        {
            MSG ("Irrigation Channel 0x{0:X2} - Members of this association group are controlled by channel 0x{0:X2} of an irrigation control device.", $payload[3]);
        }
        ELSE
        {
            MSGFAIL ("Invalid or unknown Profile Bytes: MSB {0:X2}, LSB {1:X2}.", $payload[2], $payload[3]);
        }

        IF ($grp == 1) // lifeline group
        {
            IF ($payload[2] != 0x00 || $payload[3] != 0x01)
            {
                MSGFAIL ("Wrong profile bytes for group 1 (Lifeline): required values: MSB 0x00, LSB 0x01");
            }
        }

        IF ($payload[4] != 0)
        {
            MSGFAIL ("Reserved field not set to 0. Received: 0x{0:X2}", $payload[4]);
        }

        IF (($payload[5] != 0) || ($payload[6] != 0))
        {
            MSGFAIL ("Event Code MSB and LSB not set to 0. Received: 0x{0:X2}{1:X2}", $payload[5], $payload[6]);
        }
    }

TESTSEQ END


/**
 * VerifyGroupInfoListeModeOn
 * Verifies the Association Group Info with List Mode = 1
 *
 * CC versions: 1, 2, 3
 */

TESTSEQ VerifyGroupInfoListModeOn: "Verify Association Group Info in List Mode"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND Association.GroupingsGet();
    EXPECT Association.GroupingsReport($supportedGroupings = SupportedGroupings);
    MSG ("Suppored groupings: {0}", UINT($supportedGroupings));

    SEND AssociationGrpInfo.AssociationGroupInfoGet(
        Reserved = 0,
        ListMode = 1,
        RefreshCache = 0,
        GroupingIdentifier = 0);
    EXPECT AssociationGrpInfo.AssociationGroupInfoReport(
        $groupCount = GroupCount in (1 ... $supportedGroupings),
        DynamicInfo in (0, 1),
        ListMode == 1,
        $payload = vg1);
    $receivedGroupCount = $groupCount;

    IF ($receivedGroupCount == $supportedGroupings)
    {
        MSG ("All group infos have been received in first report.");
        IF (LENGTH($payload) != $supportedGroupings * 7)
        {
            MSGFAIL ("Error in payload length. Received {0} expected {1}.", UINT(LENGTH($payload)), UINT($supportedGroupings * 7));
        }
    }
    // if first report did not contain all groups: expect the remaining group info reports in a loop
    ELSEIF ($receivedGroupCount < $supportedGroupings)
    {
        MSG ("{0} of {1} group infos have been received in first report.", UINT($receivedGroupCount), UINT($supportedGroupings));
        IF (LENGTH($payload) != $groupCount * 7)
        {
            MSGFAIL ("Error in payload length. Received {0} expected {1}.", UINT(LENGTH($payload)), UINT($groupCount * 7));
        }

        MSG ("Expecting reports for {0} remaining groups...", UINT($supportedGroupings - $receivedGroupCount));
        LOOP ($loopCounter; $receivedGroupCount + 1; $supportedGroupings)
        {
            EXPECT AssociationGrpInfo.AssociationGroupInfoReport(
                $groupCount = GroupCount in (1 ... $supportedGroupings - $receivedGroupCount),
                DynamicInfo in (0, 1),
                ListMode == 1,
                $payload = vg1);
            $receivedGroupCount = $receivedGroupCount + $groupCount;
            $loopCounter = $loopCounter + $groupCount - 1; // adjust LOOP
            IF ($groupCount > 0)
            {
                MSG ("{0} group info(s) have been received in next report.", UINT($groupCount));
            }
            IF (LENGTH($payload) != $groupCount * 7)
            {
                MSGFAIL ("Error in payload length. Received {0} expected {1}.", UINT(LENGTH($payload)), UINT($groupCount * 7));
            }
            IF ($receivedGroupCount < $supportedGroupings)
            {
                MSG ("Expecting reports for {0} remaining groups...", UINT($supportedGroupings - $receivedGroupCount));
            }
        }
    }
    ELSE
    {
        MSGFAIL ("Number of received group infos ({0}) exceeds number of supported groups ({1}).", UINT($groupCount), UINT($supportedGroupings));
    }

TESTSEQ END


/**
 * VerifyGroupCommandList
 * Verifies the Association Group Command List
 *
 * CC versions: 1, 2, 3
 */

TESTSEQ VerifyGroupCommandList: "Verify Association Group Command List"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND Association.GroupingsGet();
    EXPECT Association.GroupingsReport($supportedGroupings = SupportedGroupings);

    LOOP ($grp; 1; $supportedGroupings)
    {
        SEND AssociationGrpInfo.AssociationGroupCommandListGet(
            Reserved = 0,
            AllowCache = 0,
            GroupingIdentifier = $grp);

        EXPECT AssociationGrpInfo.AssociationGroupCommandListReport(
            GroupingIdentifier == $grp,
            $listLength = ListLength in (0 ... 255),
            ANYBYTE(Command) in (0x00... 0xFF),
            $commands = Command);

        $numberOfCommands = $listLength / 2; // We do not support extended Command Classes yet

        LOOP ($n; 0; $numberOfCommands - 1)
        {
            $commandClass = $commands[$n * 2];
            $command = $commands[($n * 2) + 1];
            #commandClassName = GETCOMMANDCLASSNAME($commandClass);
            #commandName = GETCOMMANDNAME($commandClass, $command);
            IF (ISNULL(#commandClassName)) { #commandClassName = "Unknown Command Class"; }
            IF (ISNULL(#commandName))      { #commandName = "Unknown"; }
            IF ($commandClass == 0x71)
            {
                #commandClassName = "COMMAND_CLASS_NOTIFICATION";
                IF     ($command == 0x01) { #commandName = "EVENT_SUPPORTED_GET"; }
                IF     ($command == 0x02) { #commandName = "EVENT_SUPPORTED_REPORT"; }
                IF     ($command == 0x04) { #commandName = "NOTIFICATION_GET"; }
                IF     ($command == 0x05) { #commandName = "NOTIFICATION_REPORT"; }
                IF     ($command == 0x06) { #commandName = "NOTIFICATION_SET"; }
                IF     ($command == 0x07) { #commandName = "NOTIFICATION_SUPPORTED_GET"; }
                IF     ($command == 0x08) { #commandName = "NOTIFICATION_SUPPORTED_REPORT"; }
            }
            MSG ("Association Group {0} can send {1} (0x{2:X2}) - {3} command (0x{4:X2})", UINT($grp), #commandClassName, $commandClass, #commandName, $command);
        } // LOOP ($n; 0; $numberOfCommands - 1)
    } // LOOP ($grp; 1; $supportedGroupings)

    MSG ("Finished.");

TESTSEQ END

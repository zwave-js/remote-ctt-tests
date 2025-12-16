PACKAGE MultiChannelAssociationCmdClassV5_Rev0100_Orig; // do not modify this line
USE MultiChannelAssociation CMDCLASSVER = 5;
USE Association CMDCLASSVER = 4;
USE Version CMDCLASSVER = 1;
USE Supervision CMDCLASSVER = 1;

/**
 * Multi Channel Association Command Class Version 5 Test Script
 * Command Class Specification: 2024A
 * Formatting Conventions: Version 2016-05-19
 *
 * PLEASE NOTE:
 * - The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run
 * - The certification item will NOT FAIL, if only the Test Sequence 'InvalidGroupID' fails
 * - The Test Sequence 'BasicAddRemoveTests' contains all examples from the Multi Channel Association command class spec.
 *
 * ChangeLog:
 *
 * March 20th, 2024     - Initial script, derived from V4 Rev06.
 *
 */


/**
 * SetInitialValuesAndVariables
 * This sequence sets the global variables and initial values for the tests of this command class.
 * This sequence MUST be executed in each test run.
 * If it is not executed, this will lead to errors in the following test sequences.
 *
 * CC versions: 3, 4, 5
 */

TESTSEQ SetInitialValuesAndVariables: "Set initial Values and Variables."

    // Test environment configuration - MAY be changed
    GLOBAL $GLOBAL_sessionId = 1;      // Adjust if specific Supervision Session ID is needed.
    GLOBAL $GLOBAL_waitFolReport = 100;// Adjust the wait time in milliseconds before each following report (ReportsToFollow>0) if necessary.

    // Test data - MUST NOT be changed
    GLOBAL $GLOBAL_endPointId = GETENDPOINT();
    GLOBAL $GLOBAL_commandClassId = 0x8E;
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Multi Channel Association";

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

TESTSEQ END


/**
 * CheckAssociationCC
 * Checks support of Association CC V3 or newer
 *
 * CC versions: 4, 5
 */

TESTSEQ CheckAssociationCC: "Checks the support of Association CC"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    $version = GETCOMMANDCLASSVERSION(0x85); // Association CC
    IF ($version >= 3)
    {
        MSG ("Association Command Class version {0} is supported.", UINT($version));
    }
    ELSE
    {
        MSGFAIL ("Association Command Class V3 or newer is not supported.");
    }

TESTSEQ END


/**
 * SetGetSequence
 * Verifies that MaxNodesSupported Node ID's can be added to each supported Multi Channel Association Group.
 * This test checks due to performance reasons only up to 10 Node ID's, but can be improved to
 * test up to 232 Node ID's per Multi Channel Association Group.
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ SetGetSequence: "Verify Set/Get sequences"

    $testNodesPerAG = 10;   // We will test only up to 10 nodes per Association Group
    $startNodeId = 0x11;    // We start with Node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    MSG ("Try to get number of supported Multi Channel Association Groups");
    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all Node ID's in all Multi Channel Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Verify Multi Channel Association Group: {0}", UINT($grp));

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);
        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }
        MSG ("Multi Channel Association Group: {0}. Max Nodes Supported: {1}. Testing with {2} Node IDs.", UINT($grp), UINT($maxNodes), UINT($testedNodes));

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }
        ELSEIF ($maxNodes == 0)
        {
            CONTINUE;
        }

        // Try to set $maxNodes (or 10) plus 1 more Node ID's into current empty Association Group
        MSG ("Multi Channel Association Group: {0}. Try to add {1} Node IDs plus 1 more", UINT($grp), UINT($testedNodes));
        LOOP ($node; $startNodeId; $startNodeId + $testedNodes)
        {
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = $node,
                Marker = [ ],
                Vg = [ ]);
        }

        // Expect $testedNodes nodes (not $testedNodes + 1) with correct IDs (if $testedNodes <= 5)
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);

        IF ($testedNodes == 1)
        {
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);
        }
        ELSEIF ($testedNodes == 2)
        {
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);
        }
        ELSEIF ($testedNodes == 3)
        {
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12, 0x13],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);
        }
        ELSEIF ($testedNodes == 4)
        {
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12, 0x13, 0x14],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);
        }
        ELSEIF ($testedNodes == 5)
        {
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12, 0x13, 0x14, 0x15],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);
        }
        ELSE
        {
            // Expect a correct summation for the tested number of Node IDs
            // This test could be enhanced to test up to 232 Node IDs
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                $nodeIds = NodeId,
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);
            $expectedSum = 0;
            $receivedSum = 0;
            LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
            {
                $expectedSum = $expectedSum + $node;
            }
            // correct $expectedSum (expect $testesNodes + 1 nodes), if DUT supports more than $testedNodes Node IDs
            IF ($maxNodes > $testedNodes)
            {
                $expectedSum = $expectedSum + $startNodeId + $testedNodes;
            }

            $receivedNodes = LENGTH($nodeIds);
            IF ($receivedNodes != 0)
            {
                LOOP ($node; 0; $receivedNodes - 1)
                {
                    $receivedSum = $receivedSum + $nodeIds[$node];
                }
            }

            // correct $testedNodes, if DUT supports more than $testedNodes Node IDs
            IF ($maxNodes > $testedNodes)
            {
                $testedNodes = $testedNodes + 1;
            }
            IF ($receivedNodes == $testedNodes)
            {
                MSGPASS ("Expected number of Node ID's '{0}' received.", UINT($receivedNodes));
            }
            ELSE
            {
                MSGFAIL ("Expected number of Node ID's: '{0}' Received: '{1}'.", UINT($testedNodes), UINT($receivedNodes));
            }
            IF ($expectedSum == $receivedSum)
            {
                MSGPASS ("Expected Node ID's summation '{0}' received.", UINT($receivedSum));
            }
            ELSE
            {
                MSGFAIL ("Expected Node ID's summation: '{0}' Received: '{1}'.", UINT($expectedSum), UINT($receivedSum));
            }
        }

        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
    }

    // Restore current lifeline associations (group 1 is already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveCommand
 * Tests possibility to remove one or two nodes from an Association Group.
 * Has three paths for MaxNodesSupported = 1 or 2 or >=3 with different Add/Remove actions.
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveCommand: "Verify Multi Channel Remove Command"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    MSG ("Try to get number of supported Multi Channel Association Groups");
    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Clear all Node ID's in Multi Channel Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg == [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        MSG ("Add and remove Node ID(s) in Multi Channel Association Group {0}", UINT($grp));
        IF ($maxNodes == 1) {
            // Test sequence: Add 11  Expect [11]  Remove 11  Expect [ ]  Add 11  Remove All
            MSG ("DUT supports 1 node in Multi Channel Association Group {0}", UINT($grp));

            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x11],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ ],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);

            // Add Node 11 again for the final Remove All test
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);
        }
        ELSEIF ($maxNodes == 2)
        {
            // Test sequence: Add 11+12  Expect 11+12  Remove 11+12  Expect [ ]  Add 11+12  Remove 12  Expect 11  Add 12  Remove All
            MSG ("DUT supports 2 nodes in Multi Channel Association Group {0}", UINT($grp));

            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x12],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x12],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ ],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);

            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x12],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x12],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);

            // Add Node 12 again for the final Remove All test
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x12],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);
        }
        ELSEIF ($maxNodes >= 3)
        {
            // Test sequence: Add 11+12  Expect 11+12  Remove 11  Expect 12  Add 11+13  Remove 12,13  Expect 11  Add 12+13  Remove All
            MSG ("DUT supports more than 2 nodes in Multi Channel Association Group {0}", UINT($grp));

            MSG ("Add Node ID's 0x11, 0x12 to Multi Channel Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x12],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);
            MSG ("Remove Node ID 0x11 from Multi Channel Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x11],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x12],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);
            MSG ("Add Node ID's 0x11, 0x13 to Multi Channel Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x13],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg = [ ]);
            MSG ("Remove Node ID 0x12 from Multi Channel Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x12, 0x13],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);

            // Add Node 12+13 again for the final Remove All test
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x12, 0x13],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12, 0x13],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);
        }

        // Test sequence: Remove All (from test steps above)  Expect [ ]
        MSG ("Remove all nodes from Multi Channel Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg == [ ]);
    }

    // Restore current lifeline associations (group 1 is already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * DuplicateNodeIDs
 * Verify that an already added Node ID cannot be added to the same Association Group again.
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ DuplicateNodeIDs: "Verify that an already added Node ID cannot be added to the same Multi Channel Association Group again."

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    MSG ("Try to get number of supported Multi Channel Association Groups");
    SEND MultiChannelAssociation.GroupingsGet();
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Clear all Node ID's in Multi Channel Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0...0xFF),
            ReportsToFollow in (0...0xFF),
            NodeId eq [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg == [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        IF ($maxNodes > 1)
        {
            MSG ("Try to add Node ID 0x11 to Multi Channel Association Group {0} twice", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow in (0...0xFF),
                $initNodes = NodeId == [0x11],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow in (0...0xFF),
                NodeId == $initNodes,
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);

            MSG ("Try to add Node ID 0x11 with End Point 0x01 to Multi Channel Association Group {0} twice", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [0x11, 0x01]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow in (0...0xFF),
                $initNodes = NodeId == [0x11],
                Marker == 0x00,
                $initEndp = Vg == [0x11, 0x01]);
            MSG ("$initNodes = {0}  $initEndp = {1}", $initNodes, $initEndp);
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [0x11, 0x01]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow in (0...0xFF),
                NodeId == $initNodes,
                Marker == 0x00,
                Vg == $initEndp);

            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = [ ],
                Vg = [ ]);
        }
    }
    // Restore current lifeline associations (group 1 is already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * InvalidGroupId
 * Check for returning report for Association Group 1 if report for an unsupported AG is requested.
 * This feature is marked as SHOULD in the AG CC spec.
 * The certification item will NOT FAIL, if this test sequence fails.
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ InvalidGroupId: "Check for returning report for Association Group 1 if report for an unsupported AG is requested"

    $testNodesPerAG = 5;    // We will test only up to 5 nodes per Association Group
    $grp = 0x01;

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 0xFF));
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all Node ID's in Multi Channel Association Group {0}", UINT($grp));
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = $grp,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
    EXPECT MultiChannelAssociation.Report(
        GroupingIdentifier == $grp,
        ($maxNodes = MaxNodesSupported) in (0x00 ... 0xFF),
        ReportsToFollow in (0 ... 0xFF),
        NodeId eq [ ],
      //Marker == [ ],    // Marker MAY be 0x00
        Vg == [ ]);

    IF ($supgroups == 1 && $maxNodes == 0)
    {
        MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
        MSG ("Test Sequence skipped...");
        EXITSEQ;
    }

    IF ($maxNodes > $testNodesPerAG)
    {
        $maxNodes = $testNodesPerAG;
    }

    MSG ("Set {0} Node ID's in Multi Channel Association Group {1}", UINT($maxNodes), UINT($grp));
    LOOP ($node; 1; $maxNodes)
    {
        SEND MultiChannelAssociation.Set(
            GroupingIdentifier = $grp,
            NodeId = $node,
            Marker = [ ],
            Vg = [ ]);
    }

    MSG ("Get report for Multi Channel Association Group {0}", UINT($grp));
    SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
    EXPECT MultiChannelAssociation.Report(
        GroupingIdentifier == $grp,
        MaxNodesSupported in (0 ... 0xFF),
        ReportsToFollow in (0 ... 0xFF),
        $nodeIDs = NodeId,
      //Marker == [ ],    // Marker MAY be 0x00
        Vg == [ ]);

    MSG ("Get report for Multi Channel Association Group {0}", UINT(0x00));
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x00);
    EXPECT MultiChannelAssociation.Report(
        ($grpReceived = GroupingIdentifier) == $grp,
        MaxNodesSupported in (0 ... 0xFF),
        ReportsToFollow in (0 ... 0xFF),
        NodeId eq $nodeIDs,
      //Marker == [ ],    // Marker MAY be 0x00
        Vg == [ ]);
    IF ($grpReceived != $grp)
    {
        MSG ("A receiving node that receives an unsupported Grouping Identifier SHOULD return");
        MSG ("information relating to Grouping Identifier 1.");
        MSG ("The certification item will NOT FAIL, if this test sequence fails.");
    }

    IF ($supgroups < 0xFF)
    {
        MSG ("Get report for Multi Channel Association Group {0}", UINT(0xFF));
        SEND MultiChannelAssociation.Get(GroupingIdentifier = 0xFF);
        EXPECT MultiChannelAssociation.Report(
            ($grpReceived = GroupingIdentifier) == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow in (0 ... 0xFF),
            NodeId eq $nodeIDs,
          //Marker == [ ],    // Marker MAY be 0x00
            Vg == [ ]);
        IF ($grpReceived != $grp)
        {
            MSG ("A receiving node that receives an unsupported Grouping Identifier SHOULD return");
            MSG ("information relating to Grouping Identifier 1.");
            MSG ("The certification item will not fail, if this test sequence fails.");
        }
    }

    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = $grp,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (group 1 is already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveAllNodesInSpecificGroup
 * Test sequence:
 * - Fill each AG with MaxNodesSupported (or 5)
 * - Remove all nodes in one specific AG
 * - Check if this AG is empty and all other AGs are filled correctly.
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveAllNodesInSpecificGroup: "Clear all Node IDs in a specific Association Group"

    $testNodesPerAG = 5;    // We will test only up to 5 nodes per Association Group
    $startNodeId = 0x11;    // We start with Node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport($supgroups = SupportedGroupings);
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all Node ID's in all Multi Channel Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Fill each group with max count of supported Node ID's.
    // If a group supports more than 5 Node ID's only associate 5 Node ID's
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report($maxNodes = MaxNodesSupported);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }

        MSG ("Fill Multi Channel Association Group {0} with {1} Node ID's", UINT($grp), UINT($maxNodes));
        LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
        {
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [$node],
                Marker = [ ],
                Vg = [ ]);
        }

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report($nodeIds = NodeId);

        IF (LENGTH($nodeIds) != $testedNodes)
        {
            MSGFAIL ("Tried to associate {0} nodes, DUT reports {1} nodes associated", UINT($testedNodes), UINT(LENGTH($nodeIds)));
        }
        ELSE
        {
            MSGPASS ("Multi Channel Association Group {0} filled with {1} Node ID's", UINT($grp), UINT($testedNodes));
        }
    }

    MSG ("Clear all Multi Channel Association Groups separately");
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report($nodeIds = NodeId);

        MSG ("Clear all Node ID's from Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);

        // Check that the group of this iteration is empty,
        // all other groups still should be filled with max count of supported Node ID's
        MSG ("Only Association Group {0} should be empty", UINT($grp));
        LOOP ($j; 1; $supgroups)
        {
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $j);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $j,
                $maxNodes = MaxNodesSupported,
                $tmpNodeIds = NodeId,
              //Marker == [ ],    // Marker MAY be 0x00
                Vg == [ ]);

            MSG ("Group {0}, associated Node ID's (hex): {1}", UINT($j), $tmpNodeIds);

            $testedNodes = $testNodesPerAG;
            IF ($maxNodes < $testedNodes)
            {
                $testedNodes = $maxNodes;
            }

            IF ($j == $grp)
            {
                IF (LENGTH($tmpNodeIds) != 0)
                {
                    MSGFAIL ("Association Group {0} not fully cleared", UINT($j));
                }
                ELSE
                {
                    MSGPASS ("Association Group {0} fully cleared", UINT($j));
                }
            }
            ELSE
            {
                IF (LENGTH($tmpNodeIds) != $testedNodes)
                {
                    MSGFAIL ("Node ID's removed from Association Group {0}", UINT($j));
                }
            }
        }

        MSG ("Refill the cleared Association Group {0} to recreate the initial state", UINT($grp));
        SEND MultiChannelAssociation.Set(
            GroupingIdentifier = $grp,
            NodeId = $nodeIds,
            Marker = [ ],
            Vg = [ ]);
    }

    MSG ("Test sequence processed. Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveSpecificNodeInAllGroups
 * Test sequence:
 * - Fill each AG with MaxNodesSupported (or 5)
 * - Determine a Node ID, which is available in all AGs
 * - Verify that this Node ID has been removed from all AGs
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveSpecificNodeInAllGroups: "Clear specified Node ID in all Multi Channel Association Groups"

    $testNodesPerAG = 5;    // We will test only up to 5 nodes per Association Group
    $startNodeId = 0x11;    // We start with Node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport($supgroups = SupportedGroupings);
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all Node ID's in all Multi Channel Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Fill each group with max count of supported Node ID's.
    // If a group supports more than 5 Node ID's only associate 5 Node ID's
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report($maxNodes = MaxNodesSupported);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }
        ELSEIF ($maxNodes == 0)
        {
            CONTINUE;
        }

        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }

        MSG ("Fill Multi Channel Association Group {0} with {1} Node ID's", UINT($grp), UINT($maxNodes));
        LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
        {
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [$node],
                Marker = [ ],
                Vg = [ ]);
        }

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report($nodeIds = NodeId);

        IF (LENGTH($nodeIds) != $testedNodes)
        {
            MSGFAIL ("Tried to associate {0} nodes, DUT reports {1} nodes associated", UINT($testedNodes), UINT(LENGTH($nodeIds)));
        }
        ELSE
        {
            MSGPASS ("Multi Channel Association Group {0} is filled with {1} Node ID's (hex): {2}", UINT($grp), UINT($testedNodes), $nodeIds);
        }
    }

    // determine a Node ID which is available in each Association Group
    $minNodes = 0xFF;
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            $maxNodes = MaxNodesSupported);

        IF ($maxNodes > $testNodesPerAG)
        {
            $maxNodes = $testNodesPerAG;
        }

        IF (($maxNodes > 0) && ($maxNodes < $minNodes))
        {
            $minNodes = $maxNodes;
        }
    }
    $removeNode = (($minNodes + 1) / 2) + $startNodeId - 1;

    // Clear specific Node ID in all Multi Channel Association Groups
    MSG ("Remove Node ID 0x{0:X2} in each Association Group", $removeNode);
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = $removeNode,
        Marker = [ ],
        Vg = [ ]);

    // Verify $removeNode has been removed from all Association Groups
    LOOP ($grp; 1; $supgroups)
    {
        IF ($GLOBAL_endPointId != 0)
        {
            CONTINUE;    // skip End Point Lifeline Group with MaxNodesSupported == 0
        }

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            $maxNodes = MaxNodesSupported,
            $nodeIds = NodeId,
          //Marker == [ ],    // Marker MAY be 0x00
            Vg == [ ]);

        IF ($maxNodes > $testNodesPerAG)
        {
            $maxNodes = $testNodesPerAG;
            MSG ("Testing with {0} nodes only.", UINT($maxNodes));
        }

        IF ($maxNodes == 0)
        {
            MSGFAIL ("Reported MaxNodesSupported is 0");
        }
        ELSE
        {
            MSG ("Association Group {0} (maxNodes = {1}): {2}", UINT($grp), UINT($maxNodes), $nodeIds);
            IF (($maxNodes - 1) != (LENGTH($nodeIds)))
            {
                MSGFAIL ("Expected {0} Node ID's in Association Group {1}, {2} Node ID's reported", UINT($maxNodes - 1), UINT($grp), UINT(LENGTH($nodeIds)));
            }
            ELSE
            {
                MSG ("Expected number of Node ID's: {0}, reported number of Node ID's: {1} ", UINT($maxNodes - 1), UINT(LENGTH($nodeIds)));
            }
            IF (LENGTH($nodeIds) > 0)
            {
                LOOP ($j; 0; LENGTH($nodeIds) - 1)
                {
                    IF ($removeNode == $nodeIds[$j])
                    {
                        MSGFAIL ("Node ID 0x{0:X2} not removed from Association Group {1}", $removeNode, UINT($grp));
                    }
                }
            }
        }
    }

    MSG ("Test sequence processed. Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveAllNodesInAllGroups
 * Test sequence:
 * - Fill each AG with MaxNodesSupported (or 5)
 * - Remove all Node IDs from all AGs
 * - Verify that all Node IDs has been removed from all AGs
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveAllNodesInAllGroups: "Clear all Node IDs in all Association Groups"

    $testNodesPerAG = 5;    // We will test only up to 5 nodes per Association Group
    $startNodeId = 0x11;    // We start with Node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport($supgroups = SupportedGroupings);
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all Node ID's in all Multi Channel Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Fill each group with max count of supported Node ID's.
    // If a group supports more than 5 Node ID's only associate 5 Node ID's
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report($maxNodes = MaxNodesSupported);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }
        ELSEIF ($maxNodes == 0)
        {
            CONTINUE;
        }

        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }

        MSG ("Fill Multi Channel Association Group {0} with {1} Node ID's", UINT($grp), UINT($maxNodes));
        LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
        {
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [$node],
                Marker = [ ],
                Vg = [ ]);
        }

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report($nodeIds = NodeId);

        IF (LENGTH($nodeIds) != $testedNodes)
        {
            MSGFAIL ("Tried to associate {0} nodes, DUT reports {1} nodes associated", UINT($testedNodes), UINT(LENGTH($nodeIds)));
        }
        ELSE
        {
            MSGPASS ("Association Group {0} is filled with {1} Node ID's (hex): {2}", UINT($grp), UINT($testedNodes), $nodeIds);
        }
    }

    MSG ("Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Verify all Node ID's are removed from all groups
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            $nodeIds = NodeId,
          //Marker == [ ],    // Marker MAY be 0x00
            Vg == [ ]);

        IF (LENGTH($nodeIds) == 0)
        {
            MSGPASS ("Association Group {0} is empty", UINT($grp));
        }
        ELSE
        {
            MSGFAIL ("Association Group {0} is not empty", UINT($grp));
        }
    }

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveAllNodesInAllGroupsLegacy
 * Test sequence (for Association Groups with MaxNodesSupported > 1 only):
 * - Fill each AG with one Node ID and one End Point ID
 * - Remove all Node IDs from all AGs with the legacy Association Remove Command
 * - Verify that the Node IDs has been removed from all AGs, but not the End Point ID
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveAllNodesInAllGroupsLegacy: "Clear all Node IDs in all Association Groups (legacy)"

    $startNodeId = 0x11;    // We start with Node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport($supgroups = SupportedGroupings);
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all Node ID's in all Multi Channel Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Fill each group with one Node ID and one End Point ID
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(($maxNodes = MaxNodesSupported) in (0 ... 256));

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }
        ELSEIF ($maxNodes == 0)
        {
            CONTINUE;
        }

        IF ($maxNodes > 1)
        {
            MSG ("Fill Multi Channel Association Group {0} with one Node ID and one End Point ID", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [$startNodeId + 1],
                Marker = 0x00,
                Vg = [$startNodeId, 0x01]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                NodeId == [$startNodeId + 1],
                Marker == 0x00,
                Vg == [$startNodeId, 0x01]);
        }
    }

    MSG ("Clear all Node ID's in all Association Groups by legacy Association Remove Command");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Verify that the Node ID is removed from all groups, but not the End Point ID
    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Verify that Node ID is removed from all Association Groups, but not the End Point ID");
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report($maxNodes = MaxNodesSupported);

        IF ($maxNodes > 1)
        {
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                NodeId == [ ],
                Marker == 0x00,
                Vg == [$startNodeId, 0x01]);
        }
    }

    MSG ("Test sequence processed. Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveAllNodesInSpecificGroupLegacy
 * Test sequence (for Association Groups with MaxNodesSupported > 1 only):
 * - Fill each AG with one Node ID and one End Point ID
 * - Remove all Node IDs from each AG separately with the legacy Association Remove Command
 * - Verify that the Node ID has been removed from all AGs, but not the End Point ID
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveAllNodesInSpecificGroupLegacy: "Clear all Node IDs in one Association Group (legacy)"

    $startNodeId = 0x11;    // We start with Node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport($supgroups = SupportedGroupings);
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all Node ID's in all Multi Channel Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Fill each group with one Node ID and one End Point ID
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(($maxNodes = MaxNodesSupported) in (0 ... 256));

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        IF ($maxNodes > 1)
        {
            MSG ("Fill Multi Channel Association Group {0} with one Node ID and one End Point ID", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [$startNodeId + 1],
                Marker = 0x00,
                Vg = [$startNodeId, 0x01]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                NodeId == [$startNodeId + 1],
                Marker == 0x00,
                Vg == [$startNodeId, 0x01]);

            MSG ("Clear all Node ID's in Association Group {0} by legacy Association Remove Command", UINT($grp));
            SEND Association.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ]);

            // Verify that the Node ID is removed from this group, but not the End Point ID
            MSG ("Verify that Node ID is removed from Association Group {0}, but not the End Point ID", UINT($grp));
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report($maxNodes = MaxNodesSupported);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                NodeId == [ ],
                Marker == 0x00,
                Vg == [$startNodeId, 0x01]);
        }
    }

    MSG ("Test sequence processed. Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * LegacySupport
 * Checks for compatibility to Association Command Class
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ LegacySupport: "Checks legacy Association Command Class support"

    $testNodesPerAG = 2;    // We will test only up to 2 nodes per Association Group (before the marker)
    $startNodeId = 0x11;    // We start with Node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);
    // MSG ("Lifeline: Node IDs: {0}  Marker: {1} Vg: {2}", $nodesInLifeline, $markerInLifeline, $vgInLifeline);

    // Check number of supported AG via both CC
    MSG ("Try to get number of supported Multi Channel Association Groups");
    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Try to get number of supported Legacy Association Groups");
    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($supgroupsL = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Legacy Association Groups: {0}", UINT($supgroupsL));

    IF ($supgroupsL != $supgroups)
    {
        MSGFAIL ("Different number of supported Association Groups");
    }

    MSG ("Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Verify Association Group: {0}", UINT($grp));

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }
        ELSEIF ($maxNodes == 0)
        {
            CONTINUE;
        }

        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }
        MSG ("Association Group: {0}. Max Nodes Supported: {1}. Testing with {2} Node IDs.", UINT($grp), UINT($maxNodes), UINT($testedNodes));

        $nodeIds = [$startNodeId];
        IF ($testedNodes > 1)
        {
            $nodeIds = [$startNodeId, $startNodeId + 1];
        }

        // Add 1 or 2 Node IDs by Association Set Command (legacy)
        SEND Association.Set(
            GroupingIdentifier = $grp,
            NodeId = $nodeIds);

        // Check Multi Channel Association Report Command
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq $nodeIds,
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);

        // check Association Report Command (legacy)
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq $nodeIds);

        // remove all associations in this group (cleanup)
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);

        // Add 1 or 2 Node IDs by Multi Channel Association Set Command
        // If more than 2 Node IDs are supported, additionally set one End Point ID
        $marker = [ ];
        $endpIds = [ ];
        IF ($maxNodes > 2)
        {
            $marker = 0x00;
            $endpIds = [$startNodeId, 0x01];
        }
        SEND MultiChannelAssociation.Set(
            GroupingIdentifier = $grp,
            NodeId = $nodeIds,
            Marker = $marker,
            Vg = $endpIds);

        // Check Multi Channel Association Report Command
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq $nodeIds,
          //Marker == $marker,    // if MaxNodes <= 2: Marker MAY be 0x00;  if MaxNodes > 2: Marker MUST be 0x00
            Vg eq $endpIds);

        // Check Association Report Command (legacy)
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq $nodeIds);

        // Remove all associations in this group (cleanup)
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);

        // Verify that legacy Association Remove Command does not remove End Point destinations
        // Add 1 Node ID and 1 End Point ID by Multi Channel Association Set Command
        IF ($maxNodes > 1)
        {
            $marker = 0x00;
            $endpIds = [$startNodeId, 0x01];
            $nodeId1 = [$startNodeId];

            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = $nodeId1,
                Marker = $marker,
                Vg = $endpIds);
            // Check Multi Channel Association Report Command
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq $nodeId1,
                Marker == $marker,
                Vg eq $endpIds);
            // Check Association Report Command (legacy)
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq $nodeId1);
            // Remove the Node ID (before the marker) legacy
            SEND Association.Remove(
                GroupingIdentifier = $grp,
                NodeId = $nodeId1);
            // Check Association Report Command (legacy)
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ ]);
            // Check Multi Channel Association Report Command: End Point ID must not be removed
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ ],
                Marker == $marker,
                Vg eq $endpIds);

            // Remove all associations in this group (cleanup)
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = [ ],
                Vg = [ ]);
        } // ($maxNodes > 1)
    } // loop ($supgroups)

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * Overflow
 * Verifies the MaxNodesSupported behavior
 * This Test Sequence tests every Association Group
 * 1. Fills the Association Group completely (until MaxNodesSupported):
      Lower half with Node IDs, higher half with End Points.
 * 2. Try to add one more End Point. This must fail.
 * 3. If MaxNodeSupported > 1: Removes one Node ID from group
 * 4. If MaxNodeSupported > 1: Try to add one more End Point. This must be possible.
 * 5. Removes one End Point from group
 * 6. Try to add one more Node ID. This must be possible.
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ Overflow: "Checks Association Group overflow behavior (MaxNodesSupported)"

    $startNodeId = 0x11;    // We start with Node ID 0x11
    $testNodesPerAG = 232 - $startnodeId;  // We will test ALL supported NODES (=MaxNodesSupported) per Association Group.
                                           // This may increase test duration!

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    MSG ("Try to get number of supported Multi Channel Association Groups");
    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Verify Association Group: {0}", UINT($grp));
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }
        MSG ("Multi Channel Association Group: {0}. Max Nodes Supported: {1}. Testing with {2} Node IDs.", UINT($grp), UINT($maxNodes), UINT($testedNodes));

        IF (($maxNodes > 0) && ($maxNodes < $testNodesPerAG))
        {
            // Try to set $testedNodes into current empty Association Group: lower half as Node IDs, higher half as End Points
            $startEndpId = $startNodeId + ($testedNodes / 2);
            MSG ("Multi Channel Association Group: {0}. Try to add {1} Node IDs and {2} End Points.", UINT($grp), UINT($startEndpId - $startNodeId), UINT($testedNodes - ($startEndpId - $startNodeId)));
            // MSG ("Multi Channel Association Group: {0}. startNodeId: {1}. startEndpId: {2}. testedNodes: {3}", UINT($grp), UINT($startNodeId), UINT($startEndpId), UINT($testedNodes));
            $expectedNodes = 0;
            LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
            {
                IF ($node < $startEndpId)    // set node as Node ID
                {
                    SEND MultiChannelAssociation.Set(
                        GroupingIdentifier = $grp,
                        NodeId = $node,
                        Marker = [ ],
                        Vg = [ ]);
                    $expectedNodes = $expectedNodes + 1;
                }
                ELSE                        // set node with End Point
                {
                    SEND MultiChannelAssociation.Set(
                        GroupingIdentifier = $grp,
                        NodeId = [ ],
                        Marker = 0x00,
                        Vg = [$node, 0x01]);
                }
            }
            // Try to add one End Point. This MUST fail.
            MSG ("Multi Channel Association Group: {0}. Try to add one End Point.", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [$startNodeId, 0x01]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported == $maxNodes,
                ($repstf = ReportsToFollow) in (0...255),
                $nodeIds = NodeId,
              //Marker == 0x00,    // Marker could come in a following report
                $endIds = Vg);
            MSG ("NodeId = {0}  Vg = {1}", $nodeIds, $endIds);

            IF ($repstf > 0)
            {
                MSG ("ReportsToFollow in 1st report: {0}", $repstf);
                LOOP ($n; 1; $repstf)
                {
                    WAIT ($GLOBAL_waitFolReport);
                    EXPECT MultiChannelAssociation.Report(
                        GroupingIdentifier == $grp,
                        MaxNodesSupported == $maxNodes,
                        ReportsToFollow == ($repstf - $n),
                        $tempNodeIds = NodeId,
                      //Marker == 0x00,    // Marker could come in a following report
                        $tempEndIds = vg,
                        ANYBYTE(vg) in (0x00 ... 0xFF));
                    MSG ("Following Report {0}: NodeId = {1}  Vg = {2}", $n, $tempNodeIds, $tempEndIds);
                    IF (LENGTH($tempNodeIds) > 0)
                    {
                        LOOP ($l; 0; LENGTH($tempNodeIds) - 1)
                        {
                            $nodeIds = ARRAYAPPEND($nodeIds, $tempNodeIds[$l]);
                        }
                    }
                    IF (LENGTH($tempEndIds) > 0)
                    {
                        LOOP ($l; 0; LENGTH($tempEndIds) - 2)
                        {
                            $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                            $l = $l + 1;
                            $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                        }
                    }
                }
            }

            $expectedSum = 0;
            $expectedEndpoints = $testedNodes - $expectedNodes;
            $receivedSum = 0;
            $receivedNodes = LENGTH($nodeIds);
            $receivedEndpoints = LENGTH($endIds) / 2;
            LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
            {
                $expectedSum = $expectedSum + $node;
            }
            IF ($receivedNodes > 0)
            {
                LOOP ($node; 0; $receivedNodes - 1)
                {
                    $receivedSum = $receivedSum + $nodeIds[$node];
                }
            }
            IF ($receivedEndpoints > 0)
            {
                LOOP ($node; 0; (2 * $receivedEndpoints) - 1)
                {
                    $receivedSum = $receivedSum + $endIds[$node];
                    $node = $node + 1;
                }
            }
            IF ($receivedNodes == $expectedNodes)
            {
                MSGPASS ("Expected number of Node ID's '{0}' received.", UINT($receivedNodes));
            }
            ELSE
            {
                MSGFAIL ("Expected number of Node ID's: '{0}' Received: '{1}'.", UINT($expectedNodes), UINT($receivedNodes));
            }
            IF ($receivedEndpoints == $expectedEndpoints)
            {
                MSGPASS ("Expected number of End Points '{0}' received.", UINT($receivedEndpoints));
            }
            ELSE
            {
                MSGFAIL ("Expected number of End Points: '{0}' Received: '{1}'.", UINT($expectedEndpoints), UINT($receivedEndpoints));
            }
            IF ($expectedSum == $receivedSum)
            {
                MSGPASS ("Expected Node ID's summation '{0}' received.", UINT($receivedSum));
            }
            ELSE
            {
                MSGFAIL ("Expected Node ID's summation: '{0}' Received: '{1}'.", UINT($expectedSum), UINT($receivedSum));
            }

            IF ($expectedNodes > 0)
            {
                // Remove one Node ID from group
                MSG ("Multi Channel Association Group: {0}. Removing one Node ID.", UINT($grp));
                SEND MultiChannelAssociation.Remove(
                    GroupingIdentifier = $grp,
                    NodeId = [$startNodeId],
                    Marker = [ ],
                    Vg = [ ]);

                // Try to add one End Point. This must not fail.
                MSG ("Multi Channel Association Group: {0}. Try to add one End Point.", UINT($grp));
                SEND MultiChannelAssociation.Set(
                    GroupingIdentifier = $grp,
                    NodeId = [ ],
                    Marker = 0x00,
                    Vg = [$startNodeId, 0x01]);
                SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $grp,
                    MaxNodesSupported == $maxNodes,
                    ($repstf = ReportsToFollow) in (0...255),
                    $nodeIds = NodeId,
                  //Marker == 0x00,    // Marker could come in a following report
                    $endIds = Vg);
                MSG ("NodeId = {0}  Vg = {1}", $nodeIds, $endIds);

                IF ($repstf > 0)
                {
                    MSG ("ReportsToFollow in 1st report: {0}", $repstf);
                    LOOP ($n; 1; $repstf)
                    {
                        WAIT ($GLOBAL_waitFolReport);
                        EXPECT MultiChannelAssociation.Report(
                            GroupingIdentifier == $grp,
                            MaxNodesSupported == $maxNodes,
                            ReportsToFollow == ($repstf - $n),
                            $tempNodeIds = NodeId,
                          //Marker == 0x00,    // Marker could come in a following report
                            $tempEndIds = vg,
                            ANYBYTE(vg) in (0x00 ... 0xFF));
                        MSG ("Following Report {0}: NodeId = {1}  Vg = {2}", $n, $tempNodeIds, $tempEndIds);
                        IF (LENGTH($tempNodeIds) > 0)
                        {
                            LOOP ($l; 0; LENGTH($tempNodeIds) - 1)
                            {
                                $nodeIds = ARRAYAPPEND($nodeIds, $tempNodeIds[$l]);
                            }
                        }
                        IF (LENGTH($tempEndIds) > 0)
                        {
                            LOOP ($l; 0; LENGTH($tempEndIds) - 2)
                            {
                                $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                                $l = $l + 1;
                                $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                            }
                        }
                    }
                }

                $expectedSum = 0;
                $expectedNodes = $expectedNodes - 1;
                $expectedEndpoints = $testedNodes - $expectedNodes;
                $receivedSum = 0;
                $receivedNodes = LENGTH($nodeIds);
                $receivedEndpoints = LENGTH($endIds) / 2;
                LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
                {
                    $expectedSum = $expectedSum + $node;
                }
                IF ($receivedNodes > 0)
                {
                    LOOP ($node; 0; $receivedNodes - 1)
                    {
                        $receivedSum = $receivedSum + $nodeIds[$node];
                    }
                }
                IF ($receivedEndpoints > 0)
                {
                    LOOP ($node; 0; (2 * $receivedEndpoints) - 1)
                    {
                        $receivedSum = $receivedSum + $endIds[$node];
                        $node = $node + 1;
                    }
                }
                IF ($receivedNodes == $expectedNodes)
                {
                    MSGPASS ("Expected number of Node ID's '{0}' received.", UINT($receivedNodes));
                }
                ELSE
                {
                    MSGFAIL ("Expected number of Node ID's: '{0}' Received: '{1}'.", UINT($expectedNodes), UINT($receivedNodes));
                }
                IF ($receivedEndpoints == $expectedEndpoints)
                {
                    MSGPASS ("Expected number of End Points '{0}' received.", UINT($receivedEndpoints));
                }
                ELSE
                {
                    MSGFAIL ("Expected number of End Points: '{0}' Received: '{1}'.", UINT($expectedEndpoints), UINT($receivedEndpoints));
                }
                IF ($expectedSum == $receivedSum)
                {
                    MSGPASS ("Expected Node ID's summation '{0}' received.", UINT($receivedSum));
                }
                ELSE
                {
                    MSGFAIL ("Expected Node ID's summation: '{0}' Received: '{1}'.", UINT($expectedSum), UINT($receivedSum));
                }
            } // ($expectedNodes > 0)

            // Remove one End Point from group
            MSG ("Multi Channel Association Group: {0}. Removing one End Point.", UINT($grp));
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [$startNodeId, 0x01]);

            // Try to add one Node ID. This must not fail.
            MSG ("Multi Channel Association Group: {0}. Try to add one Node ID.", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [$startNodeId],
                Marker = [ ],
                Vg = [ ]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported == $maxNodes,
                ($repstf = ReportsToFollow) in (0...255),
                $nodeIds = NodeId,
              //Marker == 0x00,    // Marker could come in a following report
                $mk = Marker,
                $endIds = Vg);
            MSG ("NodeId = {0}  Vg = {1}  Marker = {2}", $nodeIds, $endIds, $mk);

            IF ($repstf > 0)
            {
                MSG ("ReportsToFollow in 1st report: {0}", $repstf);
                LOOP ($n; 1; $repstf)
                {
                    WAIT ($GLOBAL_waitFolReport);
                    EXPECT MultiChannelAssociation.Report(
                        GroupingIdentifier == $grp,
                        MaxNodesSupported == $maxNodes,
                        ReportsToFollow == ($repstf - $n),
                        $tempNodeIds = NodeId,
                      //Marker == 0x00,    // Marker could come in a following report
                        $tempEndIds = vg,
                        ANYBYTE(vg) in (0x00 ... 0xFF));
                    MSG ("Following Report {0}: NodeId = {1}  Vg = {2}", $n, $tempNodeIds, $tempEndIds);
                    IF (LENGTH($tempNodeIds) > 0)
                    {
                        LOOP ($l; 0; LENGTH($tempNodeIds) - 1)
                        {
                            $nodeIds = ARRAYAPPEND($nodeIds, $tempNodeIds[$l]);
                        }
                    }
                    IF (LENGTH($tempEndIds) > 0)
                    {
                        LOOP ($l; 0; LENGTH($tempEndIds) - 2)
                        {
                            $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                            $l = $l + 1;
                            $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                        }
                    }
                }
            }

            $expectedSum = 0;
            $expectedNodes = $expectedNodes + 1;
            $expectedEndpoints = $testedNodes - $expectedNodes;
            $receivedSum = 0;
            $receivedNodes = LENGTH($nodeIds);
            $receivedEndpoints = LENGTH($endIds) / 2;
            LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
            {
                $expectedSum = $expectedSum + $node;
            }
            IF ($receivedNodes > 0)
            {
                LOOP ($node; 0; $receivedNodes - 1)
                {
                    $receivedSum = $receivedSum + $nodeIds[$node];
                }
            }
            IF ($receivedEndpoints > 0)
            {
                LOOP ($node; 0; (2 * $receivedEndpoints) - 1)
                {
                    $receivedSum = $receivedSum + $endIds[$node];
                    $node = $node + 1;
                }
            }
            IF ($receivedNodes == $expectedNodes)
            {
                MSGPASS ("Expected number of Node ID's '{0}' received.", UINT($receivedNodes));
            }
            ELSE
            {
                MSGFAIL ("Expected number of Node ID's: '{0}' Received: '{1}'.", UINT($expectedNodes), UINT($receivedNodes));
            }
            IF ($receivedEndpoints == $expectedEndpoints)
            {
                MSGPASS ("Expected number of End Points '{0}' received.", UINT($receivedEndpoints));
            }
            ELSE
            {
                MSGFAIL ("Expected number of End Points: '{0}' Received: '{1}'.", UINT($expectedEndpoints), UINT($receivedEndpoints));
            }
            IF ($expectedSum == $receivedSum)
            {
                MSGPASS ("Expected Node ID's summation '{0}' received.", UINT($receivedSum));
            }
            ELSE
            {
                MSGFAIL ("Expected Node ID's summation: '{0}' Received: '{1}'.", UINT($expectedSum), UINT($receivedSum));
            }


    /*        MSG ("Set nodes for Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B, 0x0C],
                Marker = 0x00,
                Vg = [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);*/
        } // IF (($maxNodes > 0) && ($maxNodes < $testNodesPerAG))

    }

    MSG ("Test sequence processed. Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * BasicAddRemoveTests
 * Checks the examples given in Multi Channel Association Command Class Specification
 * Note: This Test Sequence requires a MaxNodesSupported of at least 5 nodes for the tested group
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ BasicAddRemoveTests: "Basic Add/Remove Tests"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 0xFF));

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Get current association settings for Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ($reps = ReportsToFollow) in (0 ... 0xFF),
            ANYBYTE(NodeId) in (0 ... 232),     // only for message log
            ANYBYTE(Marker) in 0x00,            // only for message log
            ANYBYTE(Vg) in (0x00 ... 0xFF));    // only for message log

        IF ($reps > 0)
        {
            LOOP ($n; 1; $reps)
            {
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $grp,
                    MaxNodesSupported in (0 ... 0xFF),
                    ReportsToFollow in (0 ... 0xFF),
                    ANYBYTE(NodeId) in (0 ... 232),     // only for message log
                    ANYBYTE(Marker) in 0x00,            // only for message log
                    ANYBYTE(Vg) in (0x00 ... 0xFF));    // only for message log
            }
        }

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        // remove all associations in this group
        MSG ("Remove all associations from Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId == [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);

        IF ($maxNodes >= 5)
        {
            // set/remove single node
            MSG ("Set nodes for Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B, 0x0C],
                Marker = 0x00,
                Vg = [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
            Marker == 0x00,
            Vg eq [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);

            MSG ("Remove single node from Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = 0x0C,
                Marker = [ ],
                Vg = [ ]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B],
                Marker == 0x00,
                Vg eq [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);

            // remove node with End Point
            MSG ("Remove node with End Point from Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [0x10, 0x03]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B],
                Marker == 0x00,
                Vg eq [0x10, 0x02, 0x11, 0x02]);

            // set/remove bitset values
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = [ ],
                Vg = [ ]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId == [ ],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);

            MSG ("Add node with bit addressable End Points to Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B, 0x0C],
                Marker = 0x00,
                Vg = [0x10, 0x86, 0x11, 0x2]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
                Marker == 0x00,
                Vg eq [0x10, 0x86, 0x11, 0x02]);

            MSG ("Try to remove an End Point belonging to the addressable End Point destination from Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [0x10, 0x02]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
                Marker == 0x00,
                Vg eq [0x10, 0x86, 0x11, 0x02]);

            MSG ("Remove bit addressable End Points from Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [0x10, 0x86]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
                Marker == 0x00,
                Vg eq [0x11, 0x02]);

            // remove single node and node with End Point
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = [ ],
                Vg = [ ]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId == [ ],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);

            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B, 0x0C],
                Marker = 0x00,
                Vg = [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
                Marker == 0x00,
                Vg eq [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);

            MSG ("Remove single node and node with End Point from Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $grp,
                NodeId = 0x0C,
                Marker = 0x00,
                Vg = [0x10, 0x03]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B],
                Marker == 0x00,
                Vg eq [0x10, 0x02, 0x11, 0x02]);
        } // ($maxNodes >= 5)
    }

    MSG ("Test sequence processed. Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveSingleNodeFromAllGroups
 * Verifies Removing of one single Node ID
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveSingleNodeFromAllGroups: "Remove single node from all Association Groups"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 0xFF));

    LOOP ($grp; 1; $supgroups)
    {
        // remove all associations in this group
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        // check for empty group and get number of supperted nodes in this group
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId == [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        IF ($maxNodes >= 2)
        {
            MSG ("Add nodes with and without End Points to Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B],
                Marker = 0x00,
                Vg = [0x10, 0x02]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B],
                Marker == 0x00,
                Vg eq [0x10, 0x02]);
        }
        ELSE
        {
            MSG ("Add node without End Point to Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B],
                Marker = [ ],
                Vg = [ ]);
        }
    }

    MSG ("Remove node 0x0B from all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = 0x0B,
        Marker = [ ],
        Vg = [ ]);

    LOOP ($grp; 1; $supgroups)
    {
        // get number of supperted nodes in this group
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF));

        MSG ("Check node 0x0B removed in Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        IF ($maxNodes >= 2)
        {
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq  [ ],
                Marker == 0x00,
                Vg eq [0x10, 0x02]);
        }
        ELSE
        {
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq  [ ],
              //Marker == [ ],    // Marker MAY be 0x00
                Vg eq [ ]);
        }
    }

    MSG ("Test sequence processed. Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveNodeWithEndpointFromAllGroups
 * Verifies
 * Verifies Removing of one node with End Point
 * Note: This Test Sequence requires a MaxNodesSupported of at least 5 nodes for the tested group
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveNodeWithEndpointFromAllGroups: "Remove node with End Point from all Association Groups"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 0xFF));

    LOOP ($grp; 1; $supgroups)
    {
        // remove all associations in this group
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        // check for empty group and get number of supperted nodes in this group
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId == [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        IF ($maxNodes >= 5)
        {
            MSG ("Add nodes with and without End Points to Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B, 0x0C],
                Marker = 0x00,
                Vg = [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
                Marker == 0x00,
                Vg eq [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);
        }
    }

    MSG ("Remove Node 0x10 with End Point 0x03 from all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = 0x00,
        Vg = [0x10, 0x03]);

    LOOP ($grp; 1; $supgroups)
    {
        // get number of supperted Nodes in this group
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF));

        IF ($maxNodes >= 5)
        {
            MSG ("Check Node 0x10 with End Point 0x03 removed in Association Group {0}", UINT($grp));
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
                Marker == 0x00,
                Vg eq [0x10, 0x02, 0x11, 0x02]);
        }
    }

    MSG ("Test sequence processed. Clear all Node ID's in all Association Groups");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * RemoveAllNodesFromAllGroups
 * Verifies Removing of all nodes from all groups
 *
 * CC versions: 2, 3, 4, 5
 */

TESTSEQ RemoveAllNodesFromAllGroups: "Remove all nodes from all Association Groups"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 0xFF));

    MSG ("Associate nodes to all supported Association Groups");
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        // get number of supported nodes in this group
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
          //NodeId == [ ],
          //Marker == [ ],    // Marker MAY be 0x00
          //Vg eq [ ]
            ReportsToFollow == 0);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }
        ELSEIF ($maxNodes == 0)
        {
            CONTINUE;
        }

        // remove all associations in this group
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
        IF ($maxNodes >= 5)
        {
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B, 0x0C],
                Marker = 0x00,
                Vg = [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
                Marker == 0x00,
                Vg eq [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);
        }
        ELSE
        {
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [0x10, 0x02]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ ],
                Marker == 0x00,
                Vg eq [0x10, 0x02]);
        }
    }

    MSG ("Remove all associated nodes at once, Grouping Identifier set to 0x00");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    MSG ("Check all Association Groups are empty");
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);
    }


    MSG ("Associate nodes to all supported Association Groups");
    LOOP ($grp; 1; $supgroups)
    {
        // remove all associations in this group
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        // check for empty group and get number of supperted nodes in this group
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId == [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg eq [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }
        ELSEIF ($maxNodes == 0)
        {
            CONTINUE;
        }

        IF ($maxNodes >= 5)
        {
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x0B, 0x0C],
                Marker = 0x00,
                Vg = [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x0B, 0x0C],
                Marker == 0x00,
                Vg eq [0x10, 0x02, 0x10, 0x03, 0x11, 0x02]);
        }
        ELSE
        {
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = $grp,
                NodeId = [ ],
                Marker = 0x00,
                Vg = [0x10, 0x02]);
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ ],
                Marker == 0x00,
                Vg eq [0x10, 0x02]);
        }
    }

    MSG ("Remove all associated nodes at once, Grouping Identifier omitted");
    SEND MultiChannelAssociation.Remove(
        GroupingIdentifier = [ ],
        NodeId = [ ],
        Marker = [ ],
        Vg = [ ]);

    MSG ("Check all Association Groups are empty");
    $fail = 0;
    LOOP ($grp; 1; $supgroups)
    {
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow == 0,
            $nodeId = NodeId,
          //Marker == [ ],    // Marker MAY be 0x00
            $vg = Vg);

        IF ($nodeId eq [ ] == false || $vg eq [ ] == false)
        {
            $fail = $fail + 1;
            MSG ("Association Group {0} is not empty.", $grp);
        }
    }

    IF ($fail != 0)
    {
        MSG ("Warning: {0} Association Groups are not empty.", $fail);
        MSG ("A receiving node MAY interpret the empty command as an instruction to Remove all destinations from all association groups.");
        MSG ("The certification item will not fail, if this single test fails.");
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = 0,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
    }

    // Restore current lifeline associations (all groups are already empty)
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * Endpoint0
 * Try to set a MultiChannel NodeId with End Point 0, which is not allowed in V2, but in V3 (SDS12657-10 chapter 4.83.4)
 *
 * CC versions: 3, 4, 5
 */

TESTSEQ Endpoint0: "Check behavior if End Point is 0"

    $grp = 0x01;

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 0x01);
    EXPECT MultiChannelAssociation.Report(
        $nodesInLifeline = NodeId,
        $markerInLifeline = Marker,
        $vgInLifeline = Vg);

    SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
    EXPECT MultiChannelAssociation.Report(
        ($maxNodes = MaxNodesSupported) in (0x00 ... 0xFF));
    IF ($maxNodes >= 2)
    {
        SEND MultiChannelAssociation.GroupingsGet( );
        EXPECT MultiChannelAssociation.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 0xFF));
        MSG ("Supported Multi Channel Association Groups: {0}", UINT($supgroups));

        MSG ("Clear all Node ID's in Multi Channel Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0x00 ... 0xFF),
            ReportsToFollow in (0 ... 0xFF),
            NodeId eq [ ],
          //Marker == [ ],    // Marker MAY be 0x00
            Vg == [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        MSG ("Try to set Node ID 0x11 with End Point 0x00 in Multi Channel Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Set(
            GroupingIdentifier = $grp,
            NodeId = 0x12,
            Marker = 0x00,
            Vg = [0x11, 0x00]);

        MSG ("Get report for Multi Channel Association Group {0}", UINT($grp));
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow in (0 ... 0xFF),
            NodeId == 0x12,
            Marker == 0x00,
            Vg == [0x11, 0x00]);

        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
    }

    // Restore current lifeline associations
    SEND MultiChannelAssociation.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline,
        Marker = $markerInLifeline,
        Vg = $vgInLifeline);

TESTSEQ END


/**
 * SupervisionHighestSecurity
 * Multi Channel Association CC: Supervision Status Codes at the Highest Security Level
 *
 * CC versions: 3, 4, 5
 */

TESTSEQ SupervisionHighestSecurity: "Supervision Status Codes at the Highest Security Level"

    $groupA = 1;            // Should be 1. Will be increased automatically, if MaxNodesSupported(Group=1) = 0.

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

    IF ($GLOBAL_ccIsInNIF == 0 && $GLOBAL_endPointId == 0)
    {
        // Step 3 (CC is not in NIF)
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID=01)] to the DUT.
        MSG ("___ Step 3 ___");
        MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID=1)]", $groupA);

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, 0x01, 0x00];
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

    // Backup Lifeline associations (will not work if MaxNodesSupported(Group=1) = 0, no ReportsToFollow support)
    MSG ("___ Backup Lifeline ___");
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 1);
    EXPECT MultiChannelAssociation.Report(
        GroupingIdentifier == 1,
        ($lifelineMaxNodes = MaxNodesSupported) in 0 ... 255, // 0 for Lifeline at endpoints only
        ReportsToFollow == 0,
        $lifelineNodeId = NodeId,
        ANYBYTE(NodeId) in 0 ... 232,
      //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
        $lifelineVg = vg,
        ANYBYTE(vg) in 0 ... 232);
    // If Lifeline contains no associations, NodeID = 1 is used for Lifeline backup.
    IF (($lifelineNodeId == [ ]) && ($lifelineVg == [ ]))
    {
        MSG ("Lifeline is empty. NodeID = 1 is used for Lifeline backup.");
            $lifelineNodeId = 1;
    }

    // Step 3 (CC is in NIF)
    // Issue a Multi Channel Association Groupings Get Command to the DUT
    // and store the SupportedGroupings value in the returned Multi Channel Association Groupings Report Command.
    MSG ("___ Step 3 ___");
    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($groupings = SupportedGroupings) in 1 ... 255);

    // Step 4
    // Issue a Multi Channel Association Get Command (Grouping Identifier = $groupA) to the DUT
    // and store the MaxNodesSupported in the returned Association Report Command.
    MSG ("___ Step 4 ___");
    SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
    EXPECT MultiChannelAssociation.Report(
        GroupingIdentifier == $groupA,
        ($maxNodes = MaxNodesSupported) in 0 ... 255, // 0 for Lifeline at endpoints only
        ReportsToFollow == 0,
        ANYBYTE(NodeId) in 0 ... 232,
      //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
        ANYBYTE(vg) in 0 ... 232);

    IF ($maxNodes == 0) // for end point support
    {
        MSG ("For Association Group 1 the MaxNodesSupported Value is 0.");

        IF ($groupings == 1)
        {
            MSG ("No more Association Groups are supported. The Test will be skipped.");
            $skipEp = 1;
        }
        ELSE
        {
            LOOP ($i; $groupA + 1; $groupings)
            {
                $grp = $i;

                SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $grp,
                    ($maxNodes = MaxNodesSupported) in 0 ... 255, // 0 for Lifeline at endpoints only
                    ReportsToFollow == 0,
                    ANYBYTE(NodeId) in 0 ... 232,
                  //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                    ANYBYTE(vg) in 0 ... 232);

                MSG ("MaxNodesSupported(Group={0}) = {1}.", UINT($groupA), UINT($maxNodes));

                IF ($maxNodes > 0)
                {
                    $i = UINT($groupings);
                }
                ELSE
                {
                    MSG ("For Association Group {0} the MaxNodesSupported Value is 0.", UINT($grp));
                }
            }

            IF ($maxNodes == 0)
            {
                MSG ("Warning: All Association Groups report a MaxNodesSupported Value of 0.");
                $skipEp = 1;
                MSG ("___ TEST SKIPPED FOR THIS ENDPOINT ___");
                MSG ("The Lifeline should not have been affected executing this test sequence.");
                MSG ("No further action is required.");
            }
            ELSE
            {
                $groupA = $grp;
                $groupB = $groupA + 1;
                MSG ("The Test will run for Group {0}.", UINT($groupA));
            }
        }
    }
    ELSE
    {
        MSG ("MaxNodesSupported(Group={0}) = {1}.", UINT($groupA), UINT($maxNodes));
        $groupB = $groupA + 1;
    }

    IF ($groupB > $groupings)
    {
        $groupB = 0;
    }

    IF ($skipEp == 0)
    {
        // Step 5
        // Issue an Association Remove Command (Grouping Identifier = 0, Node ID field omitted) to the DUT in order to remove all associations.
        IF ($lifelineMaxNodes != 0)
        {
            MSG ("___ Step 5 ___");
            // Clear all groups.
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = 0,
                NodeId = [ ],
                Marker = [ ],
                vg = [ ]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $groupA,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow == 0,
                NodeId == [ ],
              //ANYBYTE(Marker) == [ ],    // Marker is either 0x00 or omitted = []
                vg == [ ]);
        }
        ELSE // For end point support: IF ($lifelineMaxNodes == 0)
             // If Multichannel encapsulation is activated in the CTT and the MaxNodesSupported field of an end point's Lifeline is 0, it cannot be set or removed any
             // specific nodes into or from the Lifeline. Only with a Remove command for all groups (GroupID = 0) the Lifeline would also be affected. But then the
             // Lifeline could not be restored anymore which might have impact on executing the following tests. So this test only clears the tested groups in this case.
        {
            MSG ("___ Step 5 on EndPoints ___");
            // Clear tested groups only.
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = $groupA,
                NodeId = [ ],
                Marker = [ ],
                vg = [ ]);

            SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $groupA,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow == 0,
                NodeId == [ ],
              //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                vg == [ ]);

            IF ($groupB != 0)
            {
                SEND MultiChannelAssociation.Remove(
                    GroupingIdentifier = $groupB,
                    NodeId = [ ],
                    Marker = [ ],
                    vg = [ ]);
                SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupB);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $groupB,
                    MaxNodesSupported in 1 ... 255,
                    ReportsToFollow == 0,
                    NodeId == [ ],
                  //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                    vg == [ ]);
            }
        }

        // Step 6
        // If SupportedGroupings < 255:
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=SupportedGroupings+1, NodeID=1)] to the DUT.
        IF ($groupings < 255)
        {
            MSG ("___ Step 6 ___");
            MSG ("Send Supervision Get [Multi Channel Association Set (GroupID=SupportedGroupings+1={0}, NodeID=1)]", $groupings+1);

            $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupings + 1, 0x01, 0x00];
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
        }
        ELSE
        {
            MSG ("SupportedGroupings = 255, Step 6 was skipped");
        }

        // Step 7
        // If SupportedGroupings < 255:
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=SupportedGroupings+1, NodeID field omitted, MultichannelNodeID[0]=5, EndPoint[0]=1)] to the DUT.
        IF ($groupings < 255)
        {
            MSG ("___ Step 7 ___");
            MSG ("Send Supervision Get [Multi Channel Association Set (GroupID=SupportedGroupings+1={0}, NodeID field omitted, MultichannelNodeID[0]=5, EndPoint[0]=1)]", $groupings+1);

            $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupings + 1, 0x00, 0x05, 0x01];
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
        }
        ELSE
        {
            MSG ("SupportedGroupings = 255, Step 7 was skipped");
        }

        // Step 8
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID=1, no multichannel nodes)] to the DUT.
        MSG ("___ Step 8 ___");
        MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID=1, no multichannel nodes)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, 0x01, 0x00];
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

        // Step 9
        // Issue a Multi Channel Association Get(GroupID=$groupA) to the DUT.
        MSG ("___ Step 9 ___");
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == 1,
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);

        // Step 10
        // Issue a Supervision Get [Multi Channel Association Remove (GroupID=$groupA, NodeID=1, multichannel nodes fields omitted)] to the DUT.
        MSG ("___ Step 10 ___");
        MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID=1, multichannel nodes fields omitted)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, $groupA, 0x01, 0x00];
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

        // Step 11
        // Issue a Multi Channel Association Get(Group ID=$groupA) to the DUT.
        MSG ("___ Step 11 ___");
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ],
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);

        // Step 12
        // Issue a Supervision Get [Multi Channel Association Remove (GroupID=$groupA, NodeID=1, multichannel nodes fields omitted)] to the DUT.
        // This is like step 9 repeated but this time NodeID=1 is already NOT part of the group before. Result must be the same.
        MSG ("___ Step 12 ___");
        MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID=1, multichannel nodes fields omitted)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, $groupA, 0x01, 0x00];
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

        // Step 13
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID omitted, MultichannelNodeID[0]=5, EndPoint[0]=1)] to the DUT.
        MSG ("___ Step 13 ___");
        MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID omitted, MultichannelNodeID[0]=5, EndPoint[0]=1)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, 0x00, 0x05, 0x01];
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

        // Step 14
        // Issue a Multi Channel Association Get(GroupID=$groupA) to the DUT.
        MSG ("___ Step 14 ___");
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ],
            ANYBYTE(Marker) == 0,
            vg == [5, 1]);

        // Step 15
        // Issue a Supervision Get [Multi Channel Association Remove (GroupID=$groupA, NodeID omitted, MultichannelNodeID[0]=5, EndPoint[0]=1)] to the DUT.
        MSG ("___ Step 15 ___");
        MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID omitted, MultichannelNodeID[0]=5, EndPoint[0]=1)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, $groupA, 0x00, 0x05, 0x01];
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

        // Step 16
        // Issue a Multi Channel Association Get(Group ID=$groupA) to the DUT.
        MSG ("___ Step 16 ___");
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ],
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);

        // Step 17
        // Fill tested group with an amount of MaxNodesSupported-1 NodeIDs
        // by issuing Multi Channel Supervision Get [Association Set (GroupID=$groupA, NodeID=1, no multichannel nodes)], ...,
        // Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID=MaxNodesSupported-1, no multichannel nodes)] commands to the DUT.
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID=MaxNodesSupported, MaxNodesSupported+1, no multichannel nodes)] to the DUT.
        MSG ("___ Step 17 ___");
        MSG ("Fill Group = {0} with an amount of MaxNodesSupported+1 = {1} NodeIDs", UINT($groupA), UINT($maxNodes) + 1);
        LOOP ($node; 1; $maxNodes + 1)
        {
            MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID={1}, no multichannel nodes)]", UINT($groupA), UINT($node));

            $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, $node, 0x00];
            SEND Supervision.Get(
                SessionId = $GLOBAL_sessionId,
                Reserved = 0,
                StatusUpdates = 0,
                EncapsulatedCommandLength = LENGTH($auxEncapCmd),
                EncapsulatedCommand = $auxEncapCmd);
            IF ($node <= $maxNodes)
            {
                EXPECT Supervision.Report(
                    SessionId == $GLOBAL_sessionId,
                    Reserved == 0,
                    MoreStatusUpdates == 0,
                    Status == 0xFF, // 0xFF=SUCCESS
                    Duration == 0);
            }
            ELSE
            {
                EXPECT Supervision.Report(
                    SessionId == $GLOBAL_sessionId,
                    Reserved == 0,
                    MoreStatusUpdates == 0,
                    Status == 0x02, // 0x02=FAIL
                    Duration == 0);
            }
            $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);
        }

        // Step 18
        // Check if Group=$groupA is filled with an amount of MaxNodesSupported NodeIDs.
        MSG ("___ Step 18 ___");
        MSG ("Check if Group = {0} is filled with an amount of {1} NodeIDs.", UINT($groupA), UINT($maxNodes));

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported in 0 ... 255,
            ($repstf = ReportsToFollow) in 0 ... 0xFF,
            $nodeIds = NodeId,
            ANYBYTE(NodeId) in 1 ... ($maxNodes),
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT ($GLOBAL_waitFolReport);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported in 0 ... 255,
                    ReportsToFollow == ($repstf - $n),
                    $tempNodeIds = NodeId,
                    ANYBYTE(NodeId) in 1 ... ($maxNodes),
                  //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                    vg == [ ]);
                IF (LENGTH($tempNodeIds) > 0)
                {
                    LOOP ($l; 0; LENGTH($tempNodeIds) - 1)
                    {
                        $nodeIds = ARRAYAPPEND($nodeIds, $tempNodeIds[$l]);
                    }
                }
            }
        }

        MSG ("{0} NodeIDs reported: {1}", LENGTH($nodeIds), $nodeIds);

        IF (LENGTH($nodeIds) != $maxNodes)
        {
            MSGFAIL ("There are {0} NodeIDs in Group = {1} which is not equal to its MaxNodesSupported = {2}.", LENGTH($nodeIds), UINT($groupA), UINT($maxNodes));
        }
        ELSE
        {
            MSGPASS ("There are {0} NodeIDs in Group = {1} which is equal to its MaxNodesSupported = {2}.", LENGTH($nodeIds), UINT($groupA), UINT($maxNodes));
        }

        // Step 19
        MSG ("___ Step 19 ___");
        MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID=1, multichannel nodes fields omitted)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, $groupA, 0x01, 0x00];
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

        // Step 20
        // Check if Group=$groupA is filled from NodeID = 2 to NodeID = MaxNodesSupported.
        MSG ("___ Step 20 ___");
        MSG ("Check if Group = {0} is filled from NodeID = 2 to NodeID = {1}.", UINT($groupA), UINT($maxNodes));

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported in 0 ... 255,
            ($repstf = ReportsToFollow) in 0 ... 0xFF,
            $nodeIds = NodeId,
            ANYBYTE(NodeId) in 2 ... $maxNodes,
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT ($GLOBAL_waitFolReport);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported in 0 ... 255,
                    ReportsToFollow == ($repstf - $n),
                    $tempNodeIds = NodeId,
                    ANYBYTE(NodeId) in 2 ... $maxNodes,
                  //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                    vg == [ ]);
                IF (LENGTH($tempNodeIds) > 0)
                {
                    LOOP ($l; 0; LENGTH($tempNodeIds) - 1)
                    {
                        $nodeIds = ARRAYAPPEND($nodeIds, $tempNodeIds[$l]);
                    }
                }
            }
        }

        MSG ("{0} NodeIDs reported: {1}", LENGTH($nodeIds), $nodeIds);

        IF (LENGTH($nodeIds) != ($maxNodes - 1))
        {
            MSGFAIL ("There are {0} NodeIDs in Group = {1} which is not equal to its MaxNodesSupported-1 = {2}.", LENGTH($nodeIds), UINT($groupA), UINT($maxNodes) - 1);
        }
        ELSE
        {
            MSGPASS ("There are {0} NodeIDs in Group = {1} which is equal to its MaxNodesSupported-1 = {2}.", LENGTH($nodeIds), UINT($groupA), UINT($maxNodes) - 1);
        }

        // Overflow test begins here
        // Step 21
        MSG ("___ Step 21 ___");
        MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID=MaxNodesSupported+1={1}, MaxNodesSupported+2={2}, no multichannel nodes)]",
            UINT($groupA), UINT($maxNodes) + 1, UINT($maxNodes) + 2);

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, $maxNodes + 1, $maxNodes + 2, 0x00];
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

        // Step 22
        // Issue a Multi Channel Association Get(Group ID=$groupA) to the DUT.
        MSG ("___ Step 22 ___");
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ($repstf = ReportsToFollow) in 0 ... 0xFF,
            $nodeIds = NodeId,
            ANYBYTE(NodeId) in 2 ... ($maxNodes + 2),
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT ($GLOBAL_waitFolReport);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported == $maxNodes,
                    ReportsToFollow == ($repstf - $n),
                    $tempNodeIds = NodeId,
                    ANYBYTE(NodeId) in 2 ... ($maxNodes + 2),
                  //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                    vg == [ ]);
                IF (LENGTH($tempNodeIds) > 0)
                {
                    LOOP ($l; 0; LENGTH($tempNodeIds) - 1)
                    {
                        $nodeIds = ARRAYAPPEND($nodeIds, $tempNodeIds[$l]);
                    }
                }
            }
        }

        MSG ("{0} NodeIDs reported: {1}", LENGTH($nodeIds), $nodeIds);

        IF ($sumLength > $maxNodes)
        {
            MSGFAIL ("There are {0} NodeIDs in the Association Group which is more than its {1} MaxNodesSupported.", UINT($sumLength), UINT($maxNodes));
        }
        ELSEIF ($sumLength == $maxNodes)
        {
            MSG ("The DUT partially executed the order.");
        }

        // Step 23
        // Issue a Supervision Get [Multi Channel Association Remove Command (GroupID=0, NodeID and multichannel node fields omitted)]
        // to the DUT in order to remove all associations.
        IF ($lifelineMaxNodes != 0)
        {
            MSG ("___ Step 23 ___");
            // Clear all groups.
            MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID=0, NodeID and multichannel node fields omitted)]");

            $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, 0x00, 0x00];
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
        } // IF ($lifelineMaxNodes != 0)
        ELSE // For end point support: IF ($lifelineMaxNodes == 0)
             // If Multichannel encapsulation is activated in the CTT and the MaxNodesSupported field of an end point's Lifeline is 0, it cannot be set or removed any
             // specific nodes into or from the Lifeline. Only with a Remove command for all groups (GroupID = 0) the Lifeline would also be affected. But then the
             // Lifeline could not be restored anymore which might have impact on executing the following tests. So this test only clears the tested group in this case.
        {
            MSG ("___ Step 23 on EndPoints ___");
            // Clear tested group only
            MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID and multichannel node fields omitted)]", UINT($groupA));

            $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, $groupA, 0x00];
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
        } // IF ($lifelineMaxNodes == 0)

        // Verify that the tested group is empty
        MSG ("Check if Group = {0} is empty", UINT($groupA));

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ],
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);

        // Step 24
        // Fill Group=$groupA with an amount of MaxNodesSupported+1 MultiChannelNodeIDs and EndPoints
        // by issuing Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID omitted, MultichannelNodeID=1, EndPoint=1)], ...,
        // Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID omitted, MultiChannelNodeID=MaxNodesSupported-1, EndPoint=MaxNodesSupported-1)] commands to the DUT.
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID omitted, MultiChannelNodeID[0]=MaxNodesSupported, EndPoint[0]=MaxNodesSupported,
        // MultiChannelNodeID[1]=MaxNodesSupported+1, EndPoint[1]=MaxNodesSupported+1)] to the DUT.
        MSG ("___ Step 24 ___");
        MSG ("Fill Group = {0} with an amount of MaxNodesSupported+1 = {1} MultiChannelNodeIDs and EndPoints", UINT($groupA), UINT($maxNodes) + 1);

        LOOP ($node; 1; $maxNodes + 1)
        {
            MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID omitted, MultichannelNodeID={1}, EndPoint={2})]", UINT($groupA), UINT($node), UINT($node));

            $endP = $node;    // use Node ID as End Point ID too
            $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, 0x00, $node, $endP];
            SEND Supervision.Get(
                SessionId = $GLOBAL_sessionId,
                Reserved = 0,
                StatusUpdates = 0,
                EncapsulatedCommandLength = LENGTH($auxEncapCmd),
                EncapsulatedCommand = $auxEncapCmd);
            IF ($node <= $maxNodes)
            {
                EXPECT Supervision.Report(
                    SessionId == $GLOBAL_sessionId,
                    Reserved == 0,
                    MoreStatusUpdates == 0,
                    Status == 0xFF, // 0xFF=SUCCESS
                    Duration == 0);
            }
            ELSE
            {
                EXPECT Supervision.Report(
                    SessionId == $GLOBAL_sessionId,
                    Reserved == 0,
                    MoreStatusUpdates == 0,
                    Status == 0x02, // 0x02=FAIL
                    Duration == 0);
            }
            $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);
        }

        // Step 25
        // Check if Group=$groupA is filled with an amount of MaxNodesSupported NodeIDs.
        MSG ("___ Step 25 ___");
        MSG ("Check if Group=$groupA is filled with an amount of MaxNodesSupported NodeIDs.");
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ($repstf = ReportsToFollow) in 0 ... 255,
            NodeId == [ ],
            Marker == 0x00,
            $endIds = vg,
            ANYBYTE(vg) in 1 ... $maxNodes);

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT ($GLOBAL_waitFolReport);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported == $maxNodes,
                    ReportsToFollow == ($repstf - $n),
                    NodeId == [ ],
                    Marker == 0x00,
                    $tempEndIds = vg,
                    ANYBYTE(vg) in 1 ... $maxNodes);
                IF (LENGTH($tempEndIds) > 0)
                {
                    LOOP ($l; 0; LENGTH($tempEndIds) - 2)
                    {
                        $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                        $l = $l + 1;
                        $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                    }
                }
            }
        }

        MSG ("Reported MultiChannelNodeIDs + EndPoints: {0}", $endIds);
        MSG ("Amount of EndPoints: {0}", LENGTH($endIds) / 2);

        // Step 26
        // Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID omitted, MultiChannelNodeID=1, EndPoint=1]
        MSG ("___ Step 26 ___");
        MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID omitted, MultiChannelNodeID=1, EndPoint=1]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, $groupA, 0x00, 0x01, 0x01];
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

        // Step 27
        //"Check if Group=$groupA is filled with MultichannelNodeID=2 / EndPoint=2 ... MultichannelNodeID=MaxNodesSupported / EndPoint=MaxNodesSupported."
        MSG ("___ Step 27 ___");
        MSG ("Check if Group = {0} is filled with MultichannelNodeID=2 / EndPoint=2 ... MultichannelNodeID={1} / EndPoint={2}.", UINT($groupA), UINT($maxNodes), UINT($maxNodes));

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ($repstf = ReportsToFollow) in 0 ... 0xFF,
            NodeId == [ ],
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            $endIds = vg,
            ANYBYTE(vg) in 2 ... $maxNodes);

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT ($GLOBAL_waitFolReport);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported == $maxNodes,
                    ReportsToFollow == ($repstf - $n),
                    NodeId == [ ],
                  //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                    $tempEndIds = vg,
                    ANYBYTE(vg) in 2 ... $maxNodes);
                IF (LENGTH($tempEndIds) > 0)
                {
                    LOOP ($l; 0; LENGTH($tempEndIds) - 2)
                    {
                        $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                        $l = $l + 1;
                        $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                    }
                }
            }
        }

        MSG ("Reported MultiChannelNodeIDs + EndPoints: {0}", $endIds);
        MSG ("Amount of EndPoints: {0}", (LENGTH($endIds)) / 2);

        IF ((LENGTH($endIds) / 2) != $maxNodes - 1)
        {
            MSGFAIL ("There are {0} EndPoints in Association Group = {1} which is not equal to its MaxNodesSupported-1 = {2}.", LENGTH($endIds) / 2, UINT($groupA), UINT($maxNodes) - 1);
        }
        ELSE
        {
            MSGPASS ("There are {0} EndPoints in Association Group = {1} which is equal to its MaxNodesSupported-1 = {2}.", LENGTH($endIds) / 2, UINT($groupA), UINT($maxNodes) - 1);
        }

        // Overflow test begins here
        // Step 28
        MSG ("___ Step 28 ___");
        MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID omitted,", UINT($groupA));
        MSG ("MultiChannelNodeID[0]=MaxNodesSupported+1={0}, EndPoint[0]=MaxNodesSupported+1={0})", UINT($maxNodes) + 1);
        MSG ("MultiChannelNodeID[1]=MaxNodesSupported+2={0}, EndPoint[1]=MaxNodesSupported+2={0})]", UINT($maxNodes) + 2);

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, 0x00, $maxNodes + 1, $maxNodes + 1, $maxNodes + 2, $maxNodes + 2];
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

        // Step 29
        // Issue a Multi Channel Association Get(GroupID=$groupA) to the DUT.
        MSG ("___ Step 29 ___");
        MSG ("Verify that there are less than MaxNodesSupported+1 NodeIDs associated to the group and no multichannel nodes.");

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ($repstf = ReportsToFollow) in 0 ... 0xFF,
            NodeId == [ ],
            ANYBYTE(Marker) == 0,
            $endIds = vg,
            ANYBYTE(vg) in 2 ... ($maxNodes + 2));

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT ($GLOBAL_waitFolReport);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported == $maxNodes,
                    ReportsToFollow == ($repstf - $n),
                    NodeId == [ ],
                    ANYBYTE(Marker) == 0,
                    $tempEndIds = vg,
                    ANYBYTE(vg) in 2 ... ($maxNodes + 2));
                IF (LENGTH($tempEndIds) > 0)
                {
                    LOOP ($l; 0; LENGTH($tempEndIds) - 2)
                    {
                        $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                        $l = $l + 1;
                        $endIds = ARRAYAPPEND($endIds, $tempEndIds[$l]);
                    }
                }
            }
        }

        MSG ("Reported MultiChannelNodeIDs + EndPoints: {0}", $endIds);
        MSG ("Amount of EndPoints: {0}", (LENGTH($endIds)) / 2);

        IF ((LENGTH($endIds) / 2) > $maxNodes)
        {
            MSGFAIL ("There are {0} EndPoints in Association Group = {1} which is more than its {2} MaxNodesSupported.", (LENGTH($endIds) / 2), UINT($groupA), UINT($maxNodes));
        }
        ELSEIF ($sumLength == $maxNodes)
        {
            MSG ("The DUT partially executed the order.");
        }

        // Step 30
        // If other Group ($groupB) <= SupportedGroupings:
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=$groupB, NodeID=1, no multichannel nodes)] to the DUT.
        IF ($groupB != 0)
        {
            MSG ("___ Step 30 ___");
            IF ($groupB <= $groupA)
            {
                MSG ("The group identifiers have been modified manually.");
                MSGFAIL ("$groupB={0} must be greater than $groupA={1}. Please adjust accordingly.", UINT($groupB), UINT($groupA));
            }
            ELSE
            {
                // Check if still clear
                SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupB);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $groupB,
                    ($maxNodesB = MaxNodesSupported) in 1 ... 255,
                    ReportsToFollow == 0,
                    NodeId == [ ],
                  //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                    vg == [ ]);

                IF ($maxNodesB > 0)
                {
                    // Supervision Test
                    MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID=1, no multichannel nodes)]", UINT($groupB));

                    $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupB, 0x01, 0x00];
                    SEND Supervision.Get(
                        SessionId = $GLOBAL_sessionId,
                        Reserved = 0,
                        StatusUpdates = 0,
                        EncapsulatedCommandLength = LENGTH($auxEncapCmd),
                        EncapsulatedCommand = $auxEncapCmd);
                    EXPECT Supervision.Report(
                        SessionId == $GLOBAL_sessionId,
                        Status == 0xFF, // 0xFF=SUCCESS
                        Duration == 0);
                    $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

                    // Check if it has been set correctly
                    SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupB);
                    EXPECT MultiChannelAssociation.Report(
                        GroupingIdentifier == $groupB,
                        MaxNodesSupported == $maxNodesB,
                        ReportsToFollow == 0,
                        NodeId == 1,
                      //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                        vg == [ ]);
                } // ($maxNodesB > 0)
                ELSE
                {
                    MSG ("Step 30 has been skipped, $groupB MaxNodesSupported=0");
                }
            } // IF ($groupB > $groupA)
        } // IF ($groupB <= $groupings)
        ELSE
        {
            MSG ("(Step 30 skipped)");
        }

        // Step 31
        // Issue a Supervision Get [Multi Channel Association Remove Command (GroupID=0, NodeID and multichannel node fields omitted)]
        // to the DUT in order to remove all associations.
        IF ($lifelineMaxNodes != 0)
        {
            MSG ("___ Step 31 ___");
            // Clear all groups.
            MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID=0, NodeID and multichannel node fields omitted)]");

            $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, 0x00, 0x00];
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
        } // IF ($lifelineMaxNodes != 0)
        ELSE // For end point support: IF ($lifelineMaxNodes == 0)
             // If Multichannel encapsulation is activated in the CTT and the MaxNodesSupported field of an end point's Lifeline is 0, it cannot be set or removed any
             // specific nodes into or from the Lifeline. Only with a Remove command for all groups (GroupID = 0) the Lifeline would also be affected. But then the
             // Lifeline could not be restored anymore which might have impact on executing the following tests. So this test only clears the tested groups in this case.
        {
            MSG ("___ Step 31 on EndPoints ___");
            // Clear tested groups only
            MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID and multichannel node fields omitted)]", UINT($groupA));

            $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, $groupA, 0x00];
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

            // Clear Group=$groupB if available
            IF ($groupB <= $groupings)
            {
                IF ($maxNodesB > 0)
                {
                    MSG ("Send Supervision Get [Multi Channel Association Remove (GroupID={0}, NodeID and multichannel node fields omitted)]", UINT($groupB));

                    $auxEncapCmd = [$GLOBAL_commandClassId, 0x04, $groupB, 0x00];
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
                } // ($maxNodesB > 0)
            } // IF ($groupB <= $groupings)
        } // IF ($lifelineMaxNodes == 0)

        // Check if Group=$groupA is empty
        MSG ("Check if Group = {0} is empty", UINT($groupA));
        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ],
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);


        // Check if Group=$groupB is empty if available
        IF ($groupB <= $groupings)
        {
            IF ($maxNodesB > 0)
            {
            MSG ("Check if Group = {0} is empty", UINT($groupB));
            SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupB);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == $groupB,
                MaxNodesSupported == $maxNodesB,
                ReportsToFollow == 0,
                NodeId == [ ],
              //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                vg == [ ]);
            } // ($maxNodesB > 0)
        }

        // Step 32
        // Issue a Supervision Get [Command Class = 0x8E, Command = 0xFF] to the DUT.
        // Note: This command does not exist in this CC.
        MSG ("___ Step 32 ___");
        MSG ("Send Supervision Get [Command Class = 0x8E, Command = 0xFF]");
        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = 2,
            EncapsulatedCommand = [0x8E, 0xFF]);
        EXPECT Supervision.Report(
            SessionId == $GLOBAL_sessionId,
            Reserved == 0,
            MoreStatusUpdates == 0,
            Status == 0x00, // 0x00=NO_SUPPORT
            Duration == 0);
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

        // Restore Lifeline
        MSG ("___ Restore Lifeline ___");
        IF ($lifelineMaxNodes > 0)
        {
            IF ($groupA != 1)
            {
                SEND MultiChannelAssociation.Remove(
                    GroupingIdentifier = 1,
                    NodeId = [ ],
                    Marker = [ ],
                    vg = [ ]);
            }
            SEND MultiChannelAssociation.Set(
                GroupingIdentifier = 1,
                NodeId = $lifelineNodeId,
                Marker = 0,
                vg = $lifelineVg);
            // Check Lifeline
            SEND MultiChannelAssociation.Get(GroupingIdentifier = 1);
            EXPECT MultiChannelAssociation.Report(
                GroupingIdentifier == 1,
                NodeId == $lifelineNodeId,
              //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                vg == $lifelineVg);
        }
        ELSE // $lifelineMaxNodes = 0
        {
            MSG ("MaxNodesSupported(Group=1) = 0. Lifeline cannot be restored from this end point.");
            MSG ("However, the Lifeline should not have been affected executing this test sequence on endpoints with MaxNodesSupported(Group=1) = 0.");
        }

    } // IF ($skipEp == 0)

TESTSEQ END


/**
 * SupervisionLowerSecurity
 * Multi Channel Association CC: Supervision Status Codes at Lower Security Level
 *
 * If the script is intended to be run for Multi Channel endpoints ("enable Multi Channel" is checked),
 * please deselect the Supervision Lower Security test sequences. Explanation: As long as the DUT is included securely,
 * the Multi Channel endpoints can only be reached using secure communication on the highest supported level.
 * The DUT will not respond to lower security requests for the end point.
 *
 * CC versions: 3, 4, 5
 */

TESTSEQ SupervisionLowerSecurity: "Supervision Status Codes at Lower Security Level"

    $groupA = 1;            // Should be 1. Will be increased automatically, if MaxNodesSupported(Group=1) = 0.

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

    IF ($GLOBAL_ccIsInNIF == 0)
    {
        // Step 3 (CC is not in NIF)
        // Issue a Supervision Get [Multi Channel Association Set (GroupID=$groupA, NodeID=01)] to the DUT.
        MSG ("___ Step 3 ___");
        MSG ("Send Supervision Get [Multi Channel Association Set (GroupID={0}, NodeID=1)]", $groupA);

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, 0x01, 0x00];
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
    } // IF ($GLOBAL_ccIsInNIF == 0)

    // Backup Lifeline associations (will not work if MaxNodesSupported(Group=1) = 0, no ReportsToFollow support)
    MSG ("___ Backup Lifeline ___");
    SEND MultiChannelAssociation.Get(GroupingIdentifier = 1);
    EXPECT MultiChannelAssociation.Report(
        GroupingIdentifier == 1,
        ($lifelineMaxNodes = MaxNodesSupported) in 0 ... 255, // 0 for Lifeline at endpoints only
        ReportsToFollow == 0,
        $lifelineNodeId = NodeId,
        ANYBYTE(NodeId) in 0 ... 232,
      //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
        $lifelineVg = vg,
        ANYBYTE(vg) in 0 ... 232);
    // If Lifeline contains no associations, NodeID = 1 is used for Lifeline backup.
    IF (($lifelineNodeId == [ ]) && ($lifelineVg == [ ]))
    {
        MSG ("Lifeline is empty. NodeID = 1 is used for Lifeline backup.");
            $lifelineNodeId = 1;
    }

    $testNodeId = $lifelineNodeId;

    // Step 3 (CC is in NIF)
    // Issue a Multi Channel Association Groupings Get Command to the DUT
    // and store the SupportedGroupings value in the returned Multi Channel Association Groupings Report Command.
    MSG ("___ Step 3 ___");
    SEND MultiChannelAssociation.GroupingsGet( );
    EXPECT MultiChannelAssociation.GroupingsReport(($groupings = SupportedGroupings) in 1 ... 255);

    // Step 4
    // Issue a Multi Channel Association Get Command (Grouping Identifier = $groupA) to the DUT
    // and store the MaxNodesSupported in the returned Association Report Command.
    MSG ("___ Step 4 ___");
    SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
    EXPECT MultiChannelAssociation.Report(
        GroupingIdentifier == $groupA,
        ($maxNodes = MaxNodesSupported) in 0 ... 255, // 0 for Lifeline at endpoints only
        ReportsToFollow == 0,
        ANYBYTE(NodeId) in 0 ... 232,
      //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
        ANYBYTE(vg) in 0 ... 232);

    IF ($maxNodes == 0) // for end point support
    {
        MSG ("For Association Group 1 the MaxNodesSupported Value is 0.");

        IF ($groupings == 1)
        {
            MSG ("No more Association Groups are supported. The Test will be skipped.");
            EXITSEQ;
        }
        ELSE
        {
            LOOP ($i; $groupA + 1; $groupings)
            {
                $grp = $i;

                SEND MultiChannelAssociation.Get(GroupingIdentifier = $grp);
                EXPECT MultiChannelAssociation.Report(
                    GroupingIdentifier == $grp,
                    ($maxNodes = MaxNodesSupported) in 0 ... 255, // 0 for Lifeline at endpoints only
                    ReportsToFollow == 0,
                    $testNodeId = NodeId,
                    ANYBYTE(NodeId) in 0 ... 232,
                  //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
                    ANYBYTE(vg) in 0 ... 232);

                MSG ("MaxNodesSupported(Group={0}) = {1}.", UINT($grp), UINT($maxNodes));

                IF ($maxNodes > 0)
                {
                    $i = UINT($groupings);
                }
                ELSE
                {
                    MSG ("For Association Group {0} the MaxNodesSupported Value is 0.", UINT($grp));
                }
            }

            IF ($maxNodes == 0)
            {
                MSG ("Warning: All Association Groups report a MaxNodesSupported Value of 0.");
                $skipEp = 1;
                MSG ("___ TEST SKIPPED FOR THIS ENDPOINT ___");
                MSG ("The Lifeline should not have been affected executing this test sequence.");
                MSG ("No further action is required.");
            }
            ELSE
            {
                $groupA = $grp;
                $groupB = $groupA + 1;
                MSG ("The Test will run for Group {0}.", UINT($groupA));
            }
        }
    }
    ELSE
    {
        MSG ("MaxNodesSupported(Group={0}) = {1}.", UINT($groupA), UINT($maxNodes));
        $groupB = $groupA + 1;
    }

    // Step 5
    // Issue an Association Remove Command (Grouping Identifier = 0, Node ID field omitted) to the DUT in order to remove all associations.
    IF ($GLOBAL_endPointId == 0)
    {
        MSG ("___ Step 5 ___");
        // Clear all groups.
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = 0,
            NodeId = [ ],
            Marker = [ ],
            vg = [ ]);

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ],
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);
    }
    ELSE // For end point support: IF ($lifelineMaxNodes == 0)
         // If Multichannel encapsulation is activated in the CTT and the MaxNodesSupported field of an end point's Lifeline is 0, it cannot be set or removed any
         // specific nodes into or from the Lifeline. Only with a Remove command for all groups (GroupID = 0) the Lifeline would also be affected. But then the
         // Lifeline could not be restored anymore which might have impact on executing the following tests. So this test only clears the tested groups in this case.
    {
        MSG ("___ Step 5 on EndPoints ___");
        // Clear tested groups only.
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = $groupA,
            NodeId = [ ],
            Marker = [ ],
            vg = [ ]);

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ],
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);
    }

    MSG ("Repeat steps 6 to 8 for each security level that is not the highest granted level.");

    LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)
    {
        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        WAIT ($GLOBAL_schemeSetDelay);

        // Step 6
        // Issue a Supervision Get [ Multi Channel Association Set (GroupID=$groupA, NodeID=01) ] to the DUT.
        MSG ("___ Step 6 ___");
        MSG ("Issue a Supervision Get [ Multi Channel Association Set (GroupID = {0}, NodeID = 01) ] to the DUT.", $groupA);

        $auxEncapCmd = [$GLOBAL_commandClassId, 0x01, $groupA, 0x01, 0x00];
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
        SETCURRENTSCHEME("NONE");
        SENDRAW([0x00]); // NOP
        //SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        //WAIT ($GLOBAL_schemeSetDelay);
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

        // Step 7
        // Issue a Multi Channel Association Get(GroupID = $groupA) to the DUT.
        MSG ("___ Step 7 ___");
        MSG ("Issue a Multi Channel Association Get(GroupID = {0}) to the DUT.", $groupA);

        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);

        SEND MultiChannelAssociation.Get(GroupingIdentifier = $groupA);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ],
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == [ ]);

        SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        WAIT ($GLOBAL_schemeSetDelay);

        // Step 8
        // Issue a Supervision Get[ Command Class = 8E, Command = 0xFF ] to the DUT.
        MSG ("___ Step 8 ___");
        MSG ("Issue a Supervision Get [ Command Class = Multi Channel Association, Command = 0xFF ] to the DUT.");

        $auxEncapCmd = [$GLOBAL_commandClassId, 0xFF, 0x01, 0x01, 0x00];
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
        SETCURRENTSCHEME("NONE");
        SENDRAW([0x00]); // NOP
        //SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
        //WAIT ($GLOBAL_schemeSetDelay);
        $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);
    } // LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)

    // Restore Lifeline
    MSG ("___ Restore Lifeline ___");

    SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
    WAIT ($GLOBAL_schemeSetDelay);

    IF ($lifelineMaxNodes > 0)
    {
        IF ($groupA != 1)
        {
            SEND MultiChannelAssociation.Remove(
                GroupingIdentifier = 1,
                NodeId = [ ],
                Marker = [ ],
                vg = [ ]);
        }
        SEND MultiChannelAssociation.Set(
            GroupingIdentifier = 1,
            NodeId = $lifelineNodeId,
            Marker = 0,
            vg = $lifelineVg);
        // Check Lifeline
        SEND MultiChannelAssociation.Get(GroupingIdentifier = 1);
        EXPECT MultiChannelAssociation.Report(
            GroupingIdentifier == 1,
            NodeId == $lifelineNodeId,
          //ANYBYTE(Marker) == 0,    // Marker is either 0x00 or omitted = []
            vg == $lifelineVg);
    }
    ELSE // $lifelineMaxNodes = 0
    {
        MSG ("MaxNodesSupported(Group=1) = 0. Lifeline cannot be restored from this end point.");
        MSG ("However, the Lifeline should not have been affected executing this test sequence on endpoints with MaxNodesSupported(Group=1) = 0.");
    }

    MSG ("Finished.");

TESTSEQ END

PACKAGE AssociationCmdClassV4_Rev0100_Orig; // do not modify this line
USE Association CMDCLASSVER = 4;
USE Version CMDCLASSVER = 1;
USE Supervision CMDCLASSVER = 1;
USE MultiChannelAssociation CMDCLASSVER = 5;

/**
 * Association Command Class Version 4 Test Script
 * Command Class Specification: 2024A
 * Formatting Conventions: Version 2016-05-19
 *
 * PLEASE NOTE:
 * - The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run
 * - The certification item will NOT FAIL, if only the Test Sequence 'InvalidGroupID' fails
 *
 * ChangeLog:
 *
 * March 19th, 2024     - Initial script, derived from V3 Rev04.
 *
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
    GLOBAL $GLOBAL_waitFolReport = 100;// Adjust the wait time in milliseconds before each following report (ReportsToFollow>0) if necessary.

    // Test data - MUST NOT be changed
    GLOBAL $GLOBAL_endPointId = GETENDPOINT();
    GLOBAL $GLOBAL_commandClassId = 0x85;
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Association";

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
 * InitLifeline
 * Initializes the lifeline Association Group 1 with the controller node id 1
 *
 * CC versions: 1, 2, 3, 4
 */

TESTSEQ InitLifeline: "Initializes the lifeline with a controller node id"

    $lifelineNodeId = 0x01;
    $lifelineGroup = 0x01;

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    MSG ("Try to get number of supported Association Groups");
    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Association Groups: {0}", UINT($supgroups));

    IF (UINT($supgroups) >= 1)
    {
        SEND Association.Get(GroupingIdentifier = $lifelineGroup);
        EXPECT Association.Report(
            GroupingIdentifier == $lifelineGroup,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF));

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        IF ($maxNodes >= 1)
        {
            MSG ("Clear all node ID's in Association Group {0}", UINT($lifelineNodeId));
            SEND Association.Remove(
                GroupingIdentifier = $lifelineGroup,
                NodeId = [ ]);
            MSG ("Set node ID 0x{0:X2} into Association Group {1}", UINT($lifelineNodeId), UINT($lifelineGroup));
            SEND Association.Set(
                GroupingIdentifier = $lifelineGroup,
                NodeId = $lifelineNodeId);
            SEND Association.Get(GroupingIdentifier = $lifelineGroup);
            EXPECT Association.Report(
                GroupingIdentifier == $lifelineGroup,
                ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ $lifelineNodeId ]);
        }
    }

TESTSEQ END


/**
 * InitialValues
 * Verifies the range of current association values (normally the initial values after inclusion process)
 * Checks support of Multi Channel Association CC V4 or newer
 * Removes all Multi Channel Associations from all groups
 *
 * CC versions: 3, 4
 */

TESTSEQ InitialValues: "Verify Initial Values"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    $version = GETCOMMANDCLASSVERSION(0x8E); // Multi Channel Association CC
    IF ($version >= 4)
    {
        MSG ("Multi Channel Association Command Class version {0} is supported.", UINT($version));
        MSG ("Remove all Node ID's from all Multi Channel Association Groups.");
        SEND MultiChannelAssociation.Remove(
            GroupingIdentifier = 0,
            NodeId = [ ],
            Marker = [ ],
            Vg = [ ]);
    }
    ELSE
    {
        MSG ("Multi Channel Association Command Class is not supported, nothing to remove.");
    }

    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 0xFF));

    LOOP ($grp; 1; $supgroups)
    {
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ($reps = ReportsToFollow) in (0 ... 0xFF),
            ANYBYTE(NodeId) in (1 ... 232));

        IF ($reps > 0)
        {
            LOOP ($n; 1; $reps)
            {
                EXPECT Association.Report(
                    GroupingIdentifier == $grp,
                    MaxNodesSupported in (0 ... 0xFF),
                    ReportsToFollow == ($reps - $n),
                    ANYBYTE(NodeId) in (1 ... 232));
            }
        }
    }

TESTSEQ END


/**
 * SetGetSequence
 * Verifies that MaxNodesSupported node ID's can be added to each supported Association Group.
 * This test checks due to performance reasons only up to 10 node ID's, but can be improved to
 * test up to 232 node ID's per Association Group.
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ SetGetSequence: "Verify Set/Get sequences"

    $testNodesPerAG = 10;   // We will test only up to 10 nodes per Association Group
    $startNodeId = 0x11;    // We start with node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND Association.Get(GroupingIdentifier = 0x01);
    EXPECT Association.Report($nodesInLifeline = NodeId);

    MSG ("Try to get number of supported Association Groups");
    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all node ID's in all Association Groups (CC V2+)");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Verify Association Group: {0}", UINT($grp));

        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ]);

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
        MSG ("Association Group: {0}. Max Nodes Supported: {1}. Testing with {2} node IDs.", UINT($grp), UINT($maxNodes), UINT($testedNodes));

        // Try to set $maxNodes (or 10) plus 1 more node ID's into current empty Association Group
        MSG ("Association Group: {0}. Try to add {1} node IDs plus 1 more", UINT($grp), UINT($testedNodes));
        LOOP ($node; $startNodeId; $startNodeId + $testedNodes)
        {
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = $node);
        }

        // Expect $testedNodes nodes (not $testedNodes + 1) with correct IDs (if $testedNodes <= 5)
        SEND Association.Get(GroupingIdentifier = $grp);

        IF ($testedNodes == 1)
        {
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11]);
        }
        ELSEIF ($testedNodes == 2)
        {
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12]);
        }
        ELSEIF ($testedNodes == 3)
        {
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12, 0x13]);
        }
        ELSEIF ($testedNodes == 4)
        {
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12, 0x13, 0x14]);
        }
        ELSEIF ($testedNodes == 5)
        {
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12, 0x13, 0x14, 0x15]);
        }
        ELSE
        {
            // Expect a correct summation for the tested number of node IDs
            // This test could be enhanced to test up to 232 node IDs
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                $nodeIds = NodeId);
            $expectedSum = 0;
            $receivedSum = 0;
            LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
            {
                $expectedSum = $expectedSum + $node;
            }
            // correct $expectedSum (expect $testesNodes + 1 nodes), if DUT supports more than $testedNodes node IDs
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

            // correct $testedNodes, if DUT supports more than $testedNodes node IDs
            IF ($maxNodes > $testedNodes)
            {
                $testedNodes = $testedNodes + 1;
            }
            IF ($receivedNodes == $testedNodes)
            {
                MSGPASS ("Expected number of node ID's '{0}' received.", UINT($receivedNodes));
            }
            ELSE
            {
                MSGFAIL ("Expected number of node ID's: '{0}' Received: '{1}'.", UINT($testedNodes), UINT($receivedNodes));
            }
            IF ($expectedSum == $receivedSum)
            {
                MSGPASS ("Expected node ID's summation '{0}' received.", UINT($receivedSum));
            }
            ELSE
            {
                MSGFAIL ("Expected node ID's summation: '{0}' Received: '{1}'.", UINT($expectedSum), UINT($receivedSum));
            }
        }

        SEND Association.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ]
        );
    }

    MSG ("Test sequence processed. Clear all node ID's in all groups");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Restore current lifeline associations
    MSG ("Restore lifeline associations");
    SEND Association.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline);

TESTSEQ END


/**
 * RemoveCommand
 * Tests possibility to remove one or two nodes from an Association Group.
 * Has three paths for MaxNodesSupported = 1 or 2 or >=3 with different Add/Remove actions.
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ RemoveCommand: "Verify Remove Command"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND Association.Get(GroupingIdentifier = 0x01);
    EXPECT Association.Report($nodesInLifeline = NodeId);

    MSG ("Try to get number of supported Association Groups");
    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Association Groups: {0}", UINT($supgroups));

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Clear all node ID's in Association Group {0}", UINT($grp));
        SEND Association.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ]);
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        MSG ("Add and remove node ID(s) in Association Group {0}", UINT($grp));
        IF ($maxNodes == 1) {
            // Test sequence: Add 11  Expect [11]  Remove 11  Expect [ ]  Add 11  Remove All
            MSG ("DUT supports 1 node in Association Group {0}", UINT($grp));

            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11]);
            SEND Association.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x11]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ ]);

            // Add Node 11 again for the final Remove All test
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11]);
        }
        ELSEIF ($maxNodes == 2)
        {
            // Test sequence: Add 11+12  Remove 11+12  Expect [ ]  Add 11+12  Remove 12  Expect 11  Add 12  Remove All
            MSG ("DUT supports 2 nodes in Association Group {0}", UINT($grp));

            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x12]);
            SEND Association.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x12]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [ ]);

            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x12]);
            SEND Association.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x12]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11]);

            // Add Node 12 again for the final Remove All test
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x12]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12]);
        }
        ELSEIF ($maxNodes >= 3)
        {
            // Test sequence: Add 11+12  Remove 11  Expect 12  Add 11+13  Remove 12,13  Expect 11  Add 12+13  Remove All
            MSG ("DUT supports more than 2 nodes in Association Group {0}", UINT($grp));

            MSG ("Add node ID's 0x11, 0x12 to Association Group {0}", UINT($grp));
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x12]);
            MSG ("Remove node ID 0x11 from Association Group {0}", UINT($grp));
            SEND Association.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x11]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x12]);
            MSG ("Add node ID's 0x11, 0x13 to Association Group {0}", UINT($grp));
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11, 0x13]);
            MSG ("Remove node ID 0x12 from Association Group {0}", UINT($grp));
            SEND Association.Remove(
                GroupingIdentifier = $grp,
                NodeId = [0x12, 0x13]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11]);

            // Add Node 12+13 again for the final Remove All test
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x12, 0x13]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported in (0 ... 0xFF),
                ReportsToFollow == 0,
                NodeId eq [0x11, 0x12, 0x13]);
        }

        // Test sequence: Remove All (from test steps above)  Expect [ ]
        MSG ("Remove all nodes from Multi Channel Association Group {0}", UINT($grp));
        SEND Association.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ]);
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow == 0,
            NodeId eq [ ]);
    }

    MSG ("Test sequence processed. Clear all node ID's in all groups");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Restore current lifeline associations
    MSG ("Restore lifeline associations");
    SEND Association.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline);

TESTSEQ END


/**
 * DuplicateNodeIDs
 * Verify that an already added node ID cannot be added to the same Association Group again.
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ DuplicateNodeIDs: "Verify that an already added node ID cannot be added to the same Association Group again."

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND Association.Get(GroupingIdentifier = 0x01);
    EXPECT Association.Report($nodesInLifeline = NodeId);

    MSG ("Try to get number of supported Association Groups");
    SEND Association.GroupingsGet();
    EXPECT Association.GroupingsReport(($supgroups = SupportedGroupings) in (0 ... 0xFF));
    MSG ("Supported Association Groups: {0}", UINT($supgroups));

    LOOP ($grp; 1; $supgroups)
    {
        MSG ("Clear all node ID's in Association Group {0}", UINT($grp));
        SEND Association.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ]);

        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            ($maxNodes = MaxNodesSupported) in (0...0xFF),
            ReportsToFollow in (0...0xFF),
            NodeId eq [ ]);

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        IF ($maxNodes > 1)
        {
            MSG ("Try to add node ID 0x11 to Association Group {0} twice", UINT($grp));
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow in (0...0xFF),
                $initNodes = NodeId == [0x11]);
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [0x11]);
            SEND Association.Get(GroupingIdentifier = $grp);
            EXPECT Association.Report(
                GroupingIdentifier == $grp,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow in (0...0xFF),
                NodeId == $initNodes);
        }
    }

    MSG ("Test sequence processed. Clear all node ID's in all groups");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Restore current lifeline associations
    MSG ("Restore lifeline associations");
    SEND Association.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline);

TESTSEQ END


/**
 * InvalidGroupId
 * Check for returning report for Association Group 1 if report for an unsupported AG is requested.
 * This feature is marked as SHOULD in the Association CC spec.
 * The certification item will NOT FAIL, if only this test sequence fails.
 *
 * CC versions: 1, 2, 3, 4
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
    SEND Association.Get(GroupingIdentifier = 0x01);
    EXPECT Association.Report($nodesInLifeline = NodeId);

    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 0xFF));
    MSG ("Supported Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all node ID's in Association Group {0}", UINT($grp));
    SEND Association.Remove(
        GroupingIdentifier = $grp,
        NodeId = [ ]);

    SEND Association.Get(GroupingIdentifier = $grp);
    EXPECT Association.Report(
        GroupingIdentifier == $grp,
        ($maxNodes = MaxNodesSupported) in (0x00 ... 0xE8),
        ReportsToFollow in (0 ... 0xFF),
        NodeId eq [ ]);

    IF ($maxNodes > $testNodesPerAG)
    {
        $maxNodes = $testNodesPerAG;
    }

    IF ($supgroups == 1 && $maxNodes == 0)
    {
        MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
        MSG ("Test Sequence skipped...");
        EXITSEQ;
    }

    MSG ("Set {0} node ID's in Association Group {1}", UINT($maxNodes), UINT($grp));
    LOOP ($node; 1; $maxNodes)
    {
        SEND Association.Set(
            GroupingIdentifier = $grp,
            NodeId = $node);
    }

    MSG ("Get report for Association Group {0}", UINT($grp));
    SEND Association.Get(GroupingIdentifier = $grp);
    EXPECT Association.Report(
        GroupingIdentifier == $grp,
        MaxNodesSupported in (0 ... 0xFF),
        ReportsToFollow in (0 ... 0xFF),
        $nodeIDs = NodeId);

    MSG ("Get report for Association Group {0}", UINT(0x00));
    SEND Association.Get(GroupingIdentifier = 0x00);
    EXPECT Association.Report(
        ($grpReceived = GroupingIdentifier) == $grp,
        MaxNodesSupported in (0 ... 0xFF),
        ReportsToFollow in (0 ... 0xFF),
        NodeId eq $nodeIDs);
    IF ($grpReceived != $grp)
    {
        MSG ("A receiving node that receives an unsupported Grouping Identifier SHOULD return");
        MSG ("information relating to Grouping Identifier 1.");
        MSG ("The certification item will NOT FAIL, if this test sequence fails.");
    }

    IF ($supgroups < 0xFF)
    {
        MSG ("Get report for Association Group {0}", UINT(0xFF));
        SEND Association.Get(GroupingIdentifier = 0xFF);
        EXPECT Association.Report(
            ($grpReceived = GroupingIdentifier) == $grp,
            MaxNodesSupported in (0 ... 0xFF),
            ReportsToFollow in (0 ... 0xFF),
            NodeId eq $nodeIDs);
        IF ($grpReceived != $grp)
        {
            MSG ("A receiving node that receives an unsupported Grouping Identifier SHOULD return");
            MSG ("information relating to Grouping Identifier 1.");
            MSG ("The certification item will not fail, if this test sequence fails.");
        }
    }

    SEND Association.Remove(
        GroupingIdentifier = $grp,
        NodeId = [ ]);

    // Restore current lifeline associations
    MSG ("Restore lifeline associations");
    SEND Association.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline);

TESTSEQ END


/**
 * RemoveAllNodesInSpecificGroup
 * Test sequence:
 * - Fill each AG with MaxNodesSupported (or 5)
 * - Remove all nodes in one specific AG
 * - Check if this AG is empty and all other AGs are filled correctly.
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ RemoveAllNodesInSpecificGroup: "Clear all node IDs in a specific group"

    $testNodesPerAG = 5;    // We will test only up to 5 nodes per Association Group
    $startNodeId = 0x11;    // We start with node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND Association.Get(GroupingIdentifier = 0x01);
    EXPECT Association.Report($nodesInLifeline = NodeId);

    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport($supgroups = SupportedGroupings);
    MSG ("Supported Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all node ID's in all Association Groups (CC V2+)");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Fill each group with max count of supported node ID's.
    // If a group supports more than 5 node ID's only associate 5 node ID's
    LOOP ($grp; 1; $supgroups)
    {
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report($maxNodes = MaxNodesSupported);

        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        MSG ("Fill Association Group {0} with {1} node ID's", UINT($grp), UINT($maxNodes));
        LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
        {
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [$node]);
        }

        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report($nodeIds = NodeId);

        IF (LENGTH($nodeIds) != $testedNodes)
        {
            MSGFAIL ("Tried to associate {0} nodes, DUT reports {1} nodes associated", UINT($testedNodes), UINT(LENGTH($nodeIds)));
        }
        ELSE
        {
            MSGPASS ("Association Group {0} filled with {1} node ID's", UINT($grp), UINT($testedNodes));
        }
    }

    MSG ("Clear all Association Groups separately");
    LOOP ($grp; 1; $supgroups)
    {
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report($nodeIds = NodeId);

        MSG ("Clear all node ID's from Group {0}", UINT($grp));
        SEND Association.Remove(
            GroupingIdentifier = $grp,
            NodeId = [ ]);

        // Check that the group of this iteration is empty,
        // all other groups still should be filled with max count of supported node ID's
        MSG ("Only Group {0} should be empty", UINT($grp));
        LOOP ($j; 1; $supgroups)
        {
            SEND Association.Get(GroupingIdentifier = $j);
            EXPECT Association.Report(
                GroupingIdentifier == $j,
                $maxNodes = MaxNodesSupported,
                $tmpNodeIds = NodeId);

            MSG ("Group {0}, associated node ID's: {1}", UINT($j), $tmpNodeIds);

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
                    MSGFAIL ("Node ID's removed from group {0}", UINT($j));
                }
            }
        }

        MSG ("Refill the cleared Group {0} to recreate the initial state", UINT($grp));
        SEND Association.Set(
            GroupingIdentifier = $grp,
            NodeId = $nodeIds);
    }

    MSG ("Test sequence processed. Clear all node ID's in all Association Groups (CC V2+)");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Restore current lifeline associations
    MSG ("Restore lifeline associations");
    SEND Association.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline);

TESTSEQ END


/**
 * RemoveSpecificNodeInAllGroups
 * Test sequence:
 * - Fill each AG with MaxNodesSupported (or 5)
 * - Determine a node ID, which is available in all AGs
 * - Verify that this node ID has been removed from all AGs
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ RemoveSpecificNodeInAllGroups: "Clear specified node ID in all Association Groups"

    $testNodesPerAG = 5;    // We will test only up to 5 nodes per Association Group
    $startNodeId = 0x11;    // We start with node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND Association.Get(GroupingIdentifier = 0x01);
    EXPECT Association.Report($nodesInLifeline = NodeId);

    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport($supgroups = SupportedGroupings);
    MSG ("Supported Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all node ID's in all Association Groups");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Fill each group with max count of supported node ID's.
    // If a group supports more than 5 node ID's only associate 5 node ID's
    LOOP ($grp; 1; $supgroups)
    {
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report($maxNodes = MaxNodesSupported);

        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        MSG ("Fill Association Group {0} with {1} node ID's", UINT($grp), UINT($maxNodes));
        LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
        {
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [$node]);
        }

        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report($nodeIds = NodeId);

        IF (LENGTH($nodeIds) != $testedNodes)
        {
            MSGFAIL ("Tried to associate {0} nodes, DUT reports {1} nodes associated", UINT($testedNodes), UINT(LENGTH($nodeIds)));
        }
        ELSE
        {
            MSGPASS ("Association Group {0} filled with {1} node ID's", UINT($grp), UINT($testedNodes));
        }
    }

    // determine a node ID which is available in each Association Group
    $minNodes = 0xFF;
    LOOP ($grp; 1; $supgroups)
    {
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
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

    // Clear specific node ID in all Association Groups (CC V2+)
    MSG ("Remove node ID 0x{0:X2} in each group", $removeNode);
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = $removeNode);

    // Verify $removeNode has been removed from all Association Groups
    LOOP ($grp; 1; $supgroups)
    {
        IF ($GLOBAL_endPointId != 0)
        {
            CONTINUE;    // skip End Point Lifeline Group with MaxNodesSupported == 0
        }

        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            $maxNodes = MaxNodesSupported,
            $nodeIds = NodeId);

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
                MSGFAIL ("Expected {0} node ID's in Association Group {1}, {2} node ID's reported", UINT($maxNodes - 1), UINT($grp), UINT(LENGTH($nodeIds)));
            }
            ELSE
            {
                MSG ("Expected node ID's: {0}, reported node ID's: {1} ", UINT($maxNodes - 1), UINT(LENGTH($nodeIds)));
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

    MSG ("Test sequence processed. Clear all node ID's in all groups");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Restore current lifeline associations
    MSG ("Restore lifeline associations");
    SEND Association.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline);

TESTSEQ END


/**
 * RemoveAllNodesInAllGroups
 * Test sequence:
 * - Fill each AG with MaxNodesSupported (or 5)
 * - Remove all node IDs from all AGs (CC V2+)
 * - Verify that all node IDs has been removed from all AGs
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ RemoveAllNodesInAllGroups: "Clear all node IDs in all groupings"

    $testNodesPerAG = 5;    // We will test only up to 5 nodes per Association Group
    $startNodeId = 0x11;    // We start with node ID 0x11

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    // Back up current lifeline associations
    SEND Association.Get(GroupingIdentifier = 0x01);
    EXPECT Association.Report($nodesInLifeline = NodeId);

    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport($supgroups = SupportedGroupings);
    MSG ("Supported Association Groups: {0}", UINT($supgroups));

    MSG ("Clear all node ID's in all Association Groups");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Fill each group with max count of supported node ID's.
    // If a group supports more than 5 node ID's only associate 5 node ID's
    LOOP ($grp; 1; $supgroups)
    {
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report($maxNodes = MaxNodesSupported);

        $testedNodes = $testNodesPerAG;
        IF ($maxNodes < $testedNodes)
        {
            $testedNodes = $maxNodes;
        }

        IF ($supgroups == 1 && $maxNodes == 0)
        {
            MSG ("The Multi Channel Endpoint supports only ONE Association Group (mapped to Root Device Lifeline).");
            MSG ("Test Sequence skipped...");
            EXITSEQ;
        }

        MSG ("Fill Association Group {0} with {1} node ID's", UINT($grp), UINT($maxNodes));
        LOOP ($node; $startNodeId; $startNodeId + $testedNodes - 1)
        {
            SEND Association.Set(
                GroupingIdentifier = $grp,
                NodeId = [$node]);
        }

        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report($nodeIds = NodeId);

        IF (LENGTH($nodeIds) != $testedNodes)
        {
            MSGFAIL ("Tried to associate {0} nodes, DUT reports {1} nodes associated", UINT($testedNodes), UINT(LENGTH($nodeIds)));
        }
        ELSE
        {
            MSGPASS ("Association Group {0} filled with {1} node ID's", UINT($grp), UINT($testedNodes));
        }
    }

    MSG ("Clear all node ID's in all groups");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Verify all node ID's are removed from all group ID's
    LOOP ($grp; 1; $supgroups)
    {
        SEND Association.Get(GroupingIdentifier = $grp);
        EXPECT Association.Report(
            GroupingIdentifier == $grp,
            $nodeIds = NodeId);

        IF (LENGTH($nodeIds) == 0)
        {
            MSGPASS ("Association Group {0} is empty", UINT($grp));
        }
        ELSE
        {
            MSGFAIL ("Association Group {0} is not empty", UINT($grp));
        }
    }

    MSG ("Test sequence processed. Clear all node ID's in all groups");
    SEND Association.Remove(
        GroupingIdentifier = 0,
        NodeId = [ ]);

    // Restore current lifeline associations
    MSG ("Restore lifeline associations");
    SEND Association.Set(
        GroupingIdentifier = 0x01,
        NodeId = $nodesInLifeline);

TESTSEQ END


/**
 * GetSpecificGroup
 * Checks for formal valid reply in report
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ GetSpecificGroup: "Test Association Specific Group Command"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($supgroups = SupportedGroupings) in (1 ... 255));

    SEND Association.SpecificGroupGet();
    // first check how many groups are supports and then check that the number is in the range (0 ... $supgroups)
    EXPECT Association.SpecificGroupReport(($grp = Group) in (0 ... $supgroups));
    MSG ("Specific Group is {0}", UINT($grp));

TESTSEQ END


/**
 * SupervisionHighestSecurityForAssociation
 * Supervision Status Codes For Association at the Highest Security Level
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ SupervisionHighestSecurityForAssociation: "Supervision Status Codes For Association at the Highest Security Level"

    // Adjust here if other groups shall be tested. Both must be in range 1 ... 255.
    $groupA = 1;  // Should be 1.

    // Check for correct initialization of the test run
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
        // Issue a Supervision Get [Association Set (GroupID=$groupA, NodeID=01)] to the DUT.
        MSG ("___ Step 3 ___");
        MSG ("Send Supervision Get [Association Set (GroupID={0}, NodeID=1)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                        0x01,                      // Command Association.Set
                        $groupA,                   // Group ID
                        0x01                       // Node ID
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

    // Backup current lifeline associations (not for endpoints, no ReportsToFollow support!)
    SEND Association.Get(GroupingIdentifier = 1);
    EXPECT Association.Report(
        GroupingIdentifier == 1,
        ($lifelineMaxNodes = MaxNodesSupported) in 0 ... 255, // 0 for Lifeline at endpoints only
        ReportsToFollow in (0 ... 255),
        ANYBYTE(NodeId) in 0 ... 232,
        $lifelineNodeId = NodeId);
    IF ($repstf > 0)
    {
        MSG ("Warning: ReportsToFollow ({0}) was ignored.", UINT($repstf));
    }

    // Step 3 (CC is in NIF)
    // Issue an Association Groupings Get Command to the DUT
    // and store the SupportedGroupings value in the returned Association Groupings Report Command.
    MSG ("___ Step 3 ___");

    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($groupings = SupportedGroupings) in (1 ... 255));

    // Step 4
    // Issue an Association Get Command (Grouping Identifier = 1) to the DUT
    // and store the MaxNodesSupported in the returned Association Report Command.
    MSG ("___ Step 4 ___");

    SEND Association.Get(GroupingIdentifier = $groupA);
    EXPECT Association.Report(
        GroupingIdentifier == $groupA,
        ($maxNodes = MaxNodesSupported) in (0 ... 232)); // 0 for Lifeline at endpoints only
    MSG ("MaxNodesSupported: {0}", UINT($maxNodes));

    IF ($maxNodes == 0)
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

                SEND Association.Get(GroupingIdentifier = $grp);
                EXPECT Association.Report(
                    GroupingIdentifier == $grp,
                    ($maxNodes = MaxNodesSupported) in (0 ... 232)); // 0 for Lifeline at endpoints only
                MSG ("MaxNodesSupported: {0}", UINT($maxNodes));

                IF ($maxNodes > 0)
                {
                    $i = UINT($groupings);
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
        IF ($lifelineMaxNodes != 0)
        {
            // Issue an Association Remove Command (Grouping Identifier = 0, Node ID field omitted) to the DUT in order to remove all associations.
            MSG ("___ Step 5 ___");
            MSG ("Clear all node ID's in all Association Groups (CC V2+)");

            SEND Association.Remove(
                GroupingIdentifier = 0,
                NodeId = [ ]);

            SEND Association.Get(GroupingIdentifier = $groupA);
            EXPECT Association.Report(
                GroupingIdentifier == $groupA,
                ReportsToFollow == 0,
                NodeId == [ ]);
        }
        ELSE // For end point support: IF ($lifelineMaxNodes == 0)
         // If Multichannel encapsulation is activated in the CTT and the MaxNodesSupported field of an end point's Lifeline is 0, it cannot be set or removed any
         // specific nodes into or from the Lifeline. Only with a Remove command for all groups (GroupID = 0) the Lifeline would also be affected. But then the
         // Lifeline could not be restored anymore which might have impact on executing the following tests. So this test only clears the tested groups in this case.
        {
            MSG ("___ Step 5 on EndPoints ___");
            // Clear tested groups only.
            SEND Association.Remove(
                GroupingIdentifier = $groupA,
                NodeId = [ ]);

            SEND Association.Get(GroupingIdentifier = $groupA);
            EXPECT Association.Report(
                GroupingIdentifier == $groupA,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow == 0,
                NodeId == [ ]);

            IF ($groupB != 0)
            {
                SEND Association.Remove(
                    GroupingIdentifier = $groupB,
                    NodeId = [ ]);

                SEND Association.Get(GroupingIdentifier = $groupB);
                EXPECT Association.Report(
                    GroupingIdentifier == $groupB,
                    MaxNodesSupported in 1 ... 255,
                    ReportsToFollow == 0,
                    NodeId == [ ]);
            }
        }

        // Step 6
        // If SupportedGroupings < 255:
        // Issue a Supervision Get [Association Set (GroupID=SupportedGroupings+1, NodeID=1)] to the DUT.

        IF ($groupings < 255)
        {
            MSG ("___ Step 6 ___");
            MSG ("Send Supervision Get [Association Set (GroupID=SupportedGroupings+1, NodeID=1)]");

            $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                            0x01,                      // Command Association.Set
                            $groupings + 1,            // Group ID
                            0x01                       // Node ID
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
        }
        ELSE
        {
            MSG ("SupportedGroupings = 255, Step 6 was skipped");
        }

        // Step 7/1
        // Issue a Supervision Get [Association Set (GroupID=$groupA, NodeID=01)] to the DUT.
        MSG ("___ Step 7/1 ___");
        MSG ("Send Supervision Get [Association Set (GroupID={0}, NodeID=1)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                        0x01,                      // Command Association.Set
                        $groupA,                   // Group ID
                        0x01                       // Node ID
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

        // Step 8/1
        // Issue an Association Get(Group ID=$groupA) to the DUT.
        MSG ("___ Step 8/1 ___");
        MSG ("Send Association Get (GroupID={0})", UINT($groupA));

        SEND Association.Get(GroupingIdentifier = $groupA);
        EXPECT Association.Report(
            GroupingIdentifier == $groupA,
            ReportsToFollow == 0,
            NodeId == 1);

        // Step 7/2
        // Issue a Supervision Get [Association Set (GroupID=$groupA, NodeID=01)] to the DUT.
        MSG ("___ Step 7/2 ___");
        MSG ("Send Supervision Get [Association Set (GroupID={0}, NodeID=1)] again", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                        0x01,                      // Command Association.Set
                        $groupA,                   // Group ID
                        0x01                       // Node ID
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

        // Step 8/2
        // Issue an Association Get(Group ID=$groupA) to the DUT.
        MSG ("___ Step 8/2 ___");
        MSG ("Send Association Get (GroupID={0})", UINT($groupA));

        SEND Association.Get(GroupingIdentifier = $groupA);
        EXPECT Association.Report(
            GroupingIdentifier == $groupA,
            ReportsToFollow == 0,
            NodeId == 1);

        // Step 9
        // Issue a Supervision Get [Association Remove (GroupID=$groupA, NodeID=01] to the DUT
        MSG ("___ Step 9 ___");
        MSG ("Send Supervision Get [Association Remove (GroupID={0}, NodeID=01]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                        0x04,                      // Command Association.Remove
                        $groupA,                   // Group ID
                        0x01                       // Node ID
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
        // Issue an Association Get(Group ID=$groupA) to the DUT
        MSG ("___ Step 10 ___");
        MSG ("Send Association Get (GroupID={0})", UINT($groupA));
        SEND Association.Get(GroupingIdentifier = $groupA);
        EXPECT Association.Report(
            GroupingIdentifier == $groupA,
            ReportsToFollow == 0,
            NodeId == [ ]);

        // Step 11
        // Issue a Supervision Get [Association Remove (GroupID=$groupA, NodeID=01] to the DUT
        MSG ("___ Step 11 ___");
        MSG ("Send Supervision Get [Association Remove (GroupID={0}, NodeID=01]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                        0x04,                      // Command Association.Remove
                        $groupA,                   // Group ID
                        0x01                       // Node ID
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

        // Step 12
        // Fill tested group with an amount of MaxNodesSupported+1 NodeIDs
        // by issuing Supervision Get [Association Set (GroupID=$groupA, NodeID=1)], ...,
        // Supervision Get [Association Set (GroupID=$groupA, NodeID=MaxNodesSupported+1)] commands to the DUT.
        // Check Supervision Report:
        //     If currentNodeID <= MaxNodesSupported: Supervision Report is received with Status=SUCCESS.
        //     If currentNodeID > MaxNodesSupported: Supervision Report is received with Status=FAIL.
        MSG ("___ Step 12 ___");
        MSG ("Fill Group = {0} with an amount of MaxNodesSupported+1 = {1} NodeIDs", UINT($groupA), $maxNodes + 1);

        LOOP ($node; 1; $maxNodes + 1)
        {
            MSG ("Send Supervision Get [Association Set (GroupID={0}, NodeID={1})]", UINT($groupA), UINT($node));

            $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                            0x01,                      // Command Association.Set
                            $groupA,                   // Group ID
                            $node                      // Node ID
                            ];

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

        } // LOOP ($node; 1; $maxNodes)


        // Step 13
        // Check if Group=$groupA is filled with an amount of MaxNodesSupported NodeIDs.
        MSG ("___ Step 13 ___");
        MSG ("Check if Group = {0} is filled with an amount of {1} NodeIDs.", UINT($groupA), UINT($maxNodes));

        SEND Association.Get(GroupingIdentifier = $groupA);
        EXPECT Association.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ($repstf = ReportsToFollow) in (0 ... 0xFF),
            $nodeIds = NodeId,
            ANYBYTE(NodeId) in (1 ... $maxNodes));
        MSG ("NodeId = {0}", $nodeIds);

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT($GLOBAL_waitFolReport);
                EXPECT Association.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported in (0 ... 0xFF),
                    ReportsToFollow == ($repstf - $n),
                    $tempNodeIds = NodeId,
                    ANYBYTE(NodeId) in (1 ... $maxNodes));
                MSG ("Following report {0}: NodeId = {1}", $n, $tempNodeIds);
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
            MSGFAIL ("There are {0} Nodes in Association Group = {1} which is not equal to its MaxNodesSupported = {2}.", LENGTH($nodeIds), UINT($groupA), UINT($maxNodes));
        }
        ELSE
        {
            MSGPASS ("There are {0} Nodes in Association Group = {1} which is equal to its MaxNodesSupported = {2}.", LENGTH($nodeIds), UINT($groupA), UINT($maxNodes));
        }

        // Step 14
        // Send Supervision Get [Association Remove (GroupID={0}, NodeID=01]
        MSG ("___ Step 14 ___");
        MSG ("Send Supervision Get [Association Remove (GroupID={0}, NodeID=01]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                        0x04,                      // Command Association.Remove
                        $groupA,                   // Group ID
                        0x01                       // Node ID
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

        // Check if Group=$groupA contains MaxNodesSupported - 1 NodeIDs, without NodeID = 1.
        MSG ("Check if Group = {0} contains {1} NodeIDs, without NodeID = 1.", UINT($groupA), UINT($maxNodes) - 1);

        SEND Association.Get(GroupingIdentifier = $groupA);
        EXPECT Association.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ($repstf = ReportsToFollow) in (0 ... 0xFF),
            $nodeIds = NodeId,
            ANYBYTE(NodeId) in 2 ... $maxNodes);

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT($GLOBAL_waitFolReport);
                EXPECT Association.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported == $maxNodes,
                    ReportsToFollow == ($repstf - $n),
                    $tempNodeIds = NodeId,
                    ANYBYTE(NodeId) in 2 ... $maxNodes);
                MSG ("Following report {0}: NodeId = {1}", $n, $tempNodeIds);
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

        IF (LENGTH($nodeIds) > $maxNodes)
        {
            MSGFAIL ("There are {0} NodeIDs in the Association Group which is more than its {1} MaxNodesSupported.", LENGTH($nodeIds), UINT($maxNodes));
        }
        ELSE
        {
            MSGPASS ("There are {0} NodeIDs in the Association Group which is {1} MaxNodesSupported.", LENGTH($nodeIds), UINT($maxNodes));
        }

        // Overflow test begins here
        // Step 15
        MSG ("___ Step 15 ___");
        MSG ("Send Supervision Get [Association Set (GroupID={0}, NodeID=MaxNodesSupported+1={1}, MaxNodesSupported+2={2}]",
            UINT($groupA), UINT($maxNodes + 1), $maxNodes + 2);

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                        0x01,                      // Command Association.Set
                        $groupA,                   // Group ID
                        $maxNodes + 1,             // Node ID
                        $maxNodes + 2              // Node ID
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

        // Step 16
        // Issue an Association Get(Group $groupA) to the DUT. Verify that there are less than MaxNodesSupported+1 NodeIDs associated to the group.
        MSG ("___ Step 16 ___");
        MSG ("Verify that there are less than MaxNodesSupported+1 NodeIDs associated to the group.");

        SEND Association.Get(GroupingIdentifier = $groupA);
        EXPECT Association.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ($repstf = ReportsToFollow) in (0 ... 0xFF),
            $nodeIds = NodeId,
            ANYBYTE(NodeId) in 2 ... ($maxNodes + 2));

        IF ($repstf > 0)
        {
            LOOP ($n; 1; $repstf)
            {
                WAIT($GLOBAL_waitFolReport);
                EXPECT Association.Report(
                    GroupingIdentifier == $groupA,
                    MaxNodesSupported == $maxNodes,
                    ReportsToFollow == ($repstf - $n),
                    $tempNodeIds = NodeId,
                    ANYBYTE(NodeId) in 2 ... ($maxNodes+2));
                MSG ("Following report {0}: NodeId = {1}", $n, $tempNodeIds);
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

        IF (LENGTH($nodeIds) > $maxNodes)
        {
            MSGFAIL ("There are {0} NodeIDs in the Association Group which is more than its {1} MaxNodesSupported.", UINT($sumLength), UINT($maxNodes));
        }
        ELSEIF (LENGTH($nodeIds) == $maxNodes)
        {
            MSG ("The DUT partially executed the order.");
        }

        // Step 17
        // If SupportedGroupings > 1:
        // Issue a Supervision Get [Association Set(Group ID=2, NodeID=1)] to the DUT.
        MSG ("___ Step 17 ___");

        //IF ($groupings > 1)

        IF ($groupB != 0)
        {
            MSG ("Send Association Get (GroupID={0}, NodeID=1)", UINT($groupB));

            // Check if still clear
            SEND Association.Get(GroupingIdentifier = $groupB);
            EXPECT Association.Report(
                GroupingIdentifier == $groupB,
                ($maxNodesB = MaxNodesSupported) in (0 ... 232),
                ReportsToFollow == 0,
                NodeId == [ ]);

            MSG ("MaxNodesSupported(Group={0}) = {1}.", UINT($groupB), UINT($maxNodesB));

            IF ($maxNodesB > 0)
            {
                MSG ("Send Supervision Get [Association Set (GroupID={0}, NodeID=1)]", UINT($groupB));

                $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                                0x01,                      // Command Association.Set
                                $groupB,                   // Group ID
                                0x01                       // Node ID
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

                // Check if it has been set correctly
                SEND Association.Get(GroupingIdentifier = $groupB);
                EXPECT Association.Report(
                    GroupingIdentifier == $groupB,
                    ReportsToFollow == 0,
                    NodeId == 1);
            } // ($maxNodesB > 0)
            ELSE
            {
                MSG ("(Step 17 skipped)");
            }
        }

        // Step 18
        // Issue a Supervision Get [Association Remove(Group ID=0, NodeID field omitted)]to the DUT.
        IF ($lifelineMaxNodes != 0)
        {
            MSG ("___ Step 18 ___");
            MSG ("Send Supervision Get [Association Remove (GroupID=0, NodeID=[ ])]");

            $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                            0x04,                      // Command Association.Remove
                            0x00                       // Group ID
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
        }
        ELSE // For end point support: IF ($lifelineMaxNodes == 0)
        {
            MSG ("___ Step 18 on EndPoints ___");
            // Clear tested group only
            MSG ("Send Supervision Get [Association Remove (GroupID={0}, NodeID)]", UINT($groupA));

            $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                            0x04,                      // Command Association.Remove
                            $groupA                    // Group ID
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

            // Clear Group=$groupB if available
            IF ($groupB <= $groupings)
            {
                MSG ("Send Supervision Get [Association Remove (GroupID={0}, NodeID)]", UINT($groupB));

                $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                                0x04,                      // Command Association.Remove
                                $groupB                    // Group ID
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
            }
        } // IF ($lifelineMaxNodes == 0)

        // Step 19
        // Issue an Association Get(Group ID=01) to the DUT.
        MSG ("___ Step 19 ___");
        MSG ("Send Association Get (GroupID={0}, NodeID=[ ])]", UINT($groupA));

        SEND Association.Get(GroupingIdentifier = $groupA);
        EXPECT Association.Report(
            GroupingIdentifier == $groupA,
            MaxNodesSupported == $maxNodes,
            ReportsToFollow == 0,
            NodeId == [ ]);

        MSG ("Send Association Get (GroupID={0}, NodeID=[ ])]", UINT($groupB));

        IF ($groupB != 0)
        {
            SEND Association.Get(GroupingIdentifier = $groupB);
            EXPECT Association.Report(
                GroupingIdentifier == $groupB,
                MaxNodesSupported == $maxNodesB,
                ReportsToFollow == 0,
                NodeId == [ ]);
        } // IF ($groupings > 1)

        // Step 20
        // Issue a Supervision Get [Command Class = $GLOBAL_commandClassId, Command = 0xFF] to the DUT.
        // Note: This command does not exist in this CC.
        MSG ("___ Step 20 ___");
        MSG ("Send Supervision Get [Command Class = 0x{0}, Command = 0xFF]", CONV($GLOBAL_commandClassId,1));
        SEND Supervision.Get(
            SessionId = $GLOBAL_sessionId,
            Reserved = 0,
            StatusUpdates = 0,
            EncapsulatedCommandLength = 2,
            EncapsulatedCommand = [$GLOBAL_commandClassId, 0xFF]);
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
                SEND Association.Remove(
                    GroupingIdentifier = 1,
                    NodeId = [ ]);
            }
            SEND Association.Set(
                GroupingIdentifier = 1,
                NodeId = $lifelineNodeId);
            // Check Lifeline
            SEND Association.Get(GroupingIdentifier = 1);
            EXPECT Association.Report(
                GroupingIdentifier == 1,
                NodeId == $lifelineNodeId);
        }
        ELSE // $lifelineMaxNodes = 0
        {
            MSG ("MaxNodesSupported(Group=1) = 0. Lifeline cannot be restored from this end point.");
            MSG ("However, the Lifeline should not have been affected executing this test sequence on endpoints with MaxNodesSupported(Group=1) = 0.");
        }
    }

TESTSEQ END


/**
 * SupervisionLowerSecurityForAssociation
 * Supervision Status Codes for Association at Lower Security Level
 *
 * If the script is intended to be run for Multi Channel endpoints ("enable Multi Channel" is checked),
 * the Supervision Lower Security test sequence is not performed. Explanation: As long as the DUT is included securely,
 * the Multi Channel endpoints can only be reached using secure communication on the highest supported level.
 * The DUT will not respond to lower security requests for the end point.
 *
 * CC versions: 2, 3, 4
 */

TESTSEQ SupervisionLowerSecurityForAssociation: "Supervision Status Codes for Association at Lower Security Level"

    // Adjust here if other groups shall be tested. Both must be in range 1 ... 255.
    $groupA = 1;  // Should be 1.

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
        // Issue a Supervision Get [Association Set (GroupID=$groupA, NodeID=01)] to the DUT.
        MSG ("___ Step 3 ___");
        MSG ("Send Supervision Get [Association Set (GroupID={0}, NodeID=1)]", UINT($groupA));

        $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                        0x01,                      // Command Association.Set
                        $groupA,                   // Group ID
                        0x01                       // Node ID
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
    } // IF ($GLOBAL_ccIsInNIF == 0)

    // Backup current lifeline associations (not for endpoints, no ReportsToFollow support)
    SEND Association.Get(GroupingIdentifier = 1);
    EXPECT Association.Report(
        GroupingIdentifier == 1,
        ($lifelineMaxNodes = MaxNodesSupported) in 0 ... 255, // 0 for Lifeline at endpoints only
        ReportsToFollow == 0,
        ANYBYTE(NodeId) in 0 ... 232,
        $lifelineNodeId = NodeId);

    // Step 3 (CC is in NIF)
    // Issue an Association Groupings Get Command to the DUT
    // and store the SupportedGroupings value in the returned Association Groupings Report Command.
    MSG ("___ Step 3 ___");

    SEND Association.GroupingsGet( );
    EXPECT Association.GroupingsReport(($groupings = SupportedGroupings) in (1 ... 255));

    // Step 4
    // Issue an Association Get Command (Grouping Identifier = 1) to the DUT
    // and store the MaxNodesSupported in the returned Association Report Command.
    MSG ("___ Step 4 ___");

    SEND Association.Get(GroupingIdentifier = $groupA);
    EXPECT Association.Report(
        GroupingIdentifier == $groupA,
        ($maxNodes = MaxNodesSupported) in (0 ... 232)); // 0 for Lifeline at endpoints only
    MSG ("MaxNodesSupported: {0}", UINT($maxNodes));

    IF ($maxNodes == 0)
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

                SEND Association.Get(GroupingIdentifier = $grp);
                EXPECT Association.Report(
                    GroupingIdentifier == $grp,
                    ($maxNodes = MaxNodesSupported) in (0 ... 232)); // 0 for Lifeline at endpoints only
                MSG ("MaxNodesSupported: {0}", UINT($maxNodes));

                IF ($maxNodes > 0)
                {
                    $i = UINT($groupings);
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
                $groupB = $groupA+1;
                MSG ("The Test will run for Group {0}.", UINT($groupA));
            }
        }
    }
    ELSE
    {
        MSG ("MaxNodesSupported(Group={0}) = {1}.", UINT($groupA), UINT($maxNodes));
        $groupB = $groupA+1;
    }

    IF ($GLOBAL_endPointId == 0)
    {
        // Step 5
        IF ($lifelineMaxNodes != 0)
        {
            // Issue an Association Remove Command (Grouping Identifier = 0, Node ID field omitted) to the DUT in order to remove all associations.
            MSG ("___ Step 5 ___");
            MSG ("Clear all node ID's in all Association Groups (CC V2+)");

            SEND Association.Remove(
                GroupingIdentifier = 0,
                NodeId = [ ]);

            SEND Association.Get(GroupingIdentifier = $groupA);
            EXPECT Association.Report(
                GroupingIdentifier == $groupA,
                ReportsToFollow == 0,
                NodeId == [ ]);
        }
        ELSE // For end point support: IF ($lifelineMaxNodes == 0)
             // If Multichannel encapsulation is activated in the CTT and the MaxNodesSupported field of an end point's Lifeline is 0, it cannot be set or removed any
             // specific nodes into or from the Lifeline. Only with a Remove command for all groups (GroupID = 0) the Lifeline would also be affected. But then the
             // Lifeline could not be restored anymore which might have impact on executing the following tests. So this test only clears the tested groups in this case.
        {
            MSG ("___ Step 5 on EndPoints ___");
            // Clear tested groups only.
            SEND Association.Remove(
                GroupingIdentifier = $groupA,
                NodeId = [ ]);

            SEND Association.Get(GroupingIdentifier = $groupA);
            EXPECT Association.Report(
                GroupingIdentifier == $groupA,
                MaxNodesSupported == $maxNodes,
                ReportsToFollow == 0,
                NodeId == [ ]);

            IF ($groupB <= $groupings)
            {
                SEND Association.Remove(
                    GroupingIdentifier = $groupB,
                    NodeId = [ ]);

                SEND Association.Get(GroupingIdentifier = $groupB);
                EXPECT Association.Report(
                    GroupingIdentifier == $groupB,
                    MaxNodesSupported in 1 ... 255,
                    ReportsToFollow == 0,
                    NodeId == [ ]);
            }
        }

        // Step 6
        MSG ("___ Step 6 ___ (obsolete)");


        MSG ("Repeat steps 7 to 11 for each security level that is not the highest granted level.");

        LOOP ($j; 1; LENGTH(#GLOBAL_supportedSchemes) - 1)
        {
            SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
            WAIT ($GLOBAL_schemeSetDelay);

            // Step 7
            // Issue a Supervision Get [Association Set (GroupID=$groupA, NodeID=01)] to the DUT.
            MSG ("___ Step 7 ___");
            MSG ("Send Supervision Get [Association Set (GroupID={0}, NodeID=01)]", UINT($groupA));

            $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                            0x01,                      // Command Association.Set
                            $groupA,                   // Group ID
                            0x01                       // Node ID
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
            SETCURRENTSCHEME("NONE");
            SENDRAW([0x00]); // NOP
            //SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
            //WAIT ($GLOBAL_schemeSetDelay);
            $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

            // Step 8
            // Issue an Association Get(Group ID=$groupA) to the DUT.
            MSG ("___ Step 8 ___");
            MSG ("Send Association Get (GroupID={0}) at  highest granted security level.", UINT($groupA));

            SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
            WAIT ($GLOBAL_schemeSetDelay);

            SEND Association.Get(GroupingIdentifier = $groupA);
            EXPECT Association.Report(
                GroupingIdentifier == $groupA,
                ReportsToFollow == 0,
                NodeId == [ ]);

            SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
            WAIT ($GLOBAL_schemeSetDelay);

            // Step 9
            // Issue a Supervision Get [Association Remove (GroupID=$groupA, NodeID=01] to the DUT
            MSG ("___ Step 9 ___");
            MSG ("Send Supervision Get [Association Remove (GroupID={0}, NodeID=01]", UINT($groupA));

            $auxEncapCmd = [$GLOBAL_commandClassId,    // Command Class Association
                            0x04,                      // Command Association.Remove
                            $groupA,                   // Group ID
                            0x01                       // Node ID
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
            SETCURRENTSCHEME("NONE");
            SENDRAW([0x00]); // NOP
            SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
            WAIT ($GLOBAL_schemeSetDelay);
            $GLOBAL_sessionId = ($GLOBAL_sessionId + 1) % ($GLOBAL_lastSessionId + 1);

            // Step 10
            // Issue an Association Get(Group ID=$groupA) to the DUT
            MSG ("___ Step 10 ___");
            MSG ("Send Association Get (GroupID={0})", UINT($groupA));
            SEND Association.Get(GroupingIdentifier = $groupA);
            EXPECTNOT Association.Report;
            SETCURRENTSCHEME("NONE");
            SENDRAW([0x00]); // NOP
            SETCURRENTSCHEME(#GLOBAL_supportedSchemes[$j]);
            WAIT ($GLOBAL_schemeSetDelay);

            // Step 11
            // Issue a Supervision Get [Command Class = $GLOBAL_commandClassId, Command = 0xFF] to the DUT.
            // Note: This command does not exist in this CC.
            MSG ("___ Step 11 ___");
            MSG ("Send Supervision Get [Command Class = 0x{0}, Command = 0xFF]", CONV($GLOBAL_commandClassId,1));
            SEND Supervision.Get(
                SessionId = $GLOBAL_sessionId,
                Reserved = 0,
                StatusUpdates = 0,
                EncapsulatedCommandLength = 2,
                EncapsulatedCommand = [$GLOBAL_commandClassId, 0xFF]);
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

        // Restore Security Scheme
        SETCURRENTSCHEME(#GLOBAL_highestGrantedScheme);
        WAIT ($GLOBAL_schemeSetDelay);

        // Step 12
        // Restore Lifeline
        MSG ("___ Step 12 ___");
        MSG ("___ Restore Lifeline ___");
        IF ($lifelineMaxNodes > 0)
        {
            IF ($groupA != 1)
            {
                SEND Association.Remove(
                    GroupingIdentifier = 1,
                    NodeId = [ ]);
            }
            SEND Association.Set(
                GroupingIdentifier = 1,
                NodeId = $lifelineNodeId);
            // Check Lifeline
            SEND Association.Get(GroupingIdentifier = 1);
            EXPECT Association.Report(
                GroupingIdentifier == 1,
                NodeId == $lifelineNodeId);
        }
        ELSE // $lifelineMaxNodes = 0
        {
            MSG ("MaxNodesSupported(Group=1) = 0. Lifeline cannot be restored from this end point.");
            MSG ("However, the Lifeline should not have been affected executing this test sequence on endpoints with MaxNodesSupported(Group=1) = 0.");
        }
    } // IF ($GLOBAL_endPointId == 0)

    MSG ("Finished.");

TESTSEQ END

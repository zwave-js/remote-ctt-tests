PACKAGE MultiCommandCmdClassV1_Rev0400_Orig; // do not modify this line
USE MultiCmd CMDCLASSVER = 1;
USE Version CMDCLASSVER = 2;
USE ZwaveplusInfo CMDCLASSVER = 2;
USE ManufacturerSpecific CMDCLASSVER = 1;
USE AssociationGrpInfo CMDCLASSVER = 1;

/* MultiCommand Command Class Version 1 Test Script
 * Command Class Specification
 * Formatting Conventions: Version 2016-05-19
 *
 * ChangeLog:
 *
 * October 20th, 2015   - Initial release.
 * June 8th, 2016       - Version numbers updated. Log output and test instructions improved.
 * September 28th, 2016 - Adjustment note added in 'ExceedingResponsePayload'.
 * February 16th, 2017  - Check for Byte0 in 'AnswerAsAsked' supports multiple firmware targets.
 * February 24th, 2017  - USE MultiCMD changed to USE MultiCmd (for CTT Wizard).
 * December 15th, 2017  - 'AnswerAsAsked' removed (OpenReview 09/2017).
 * March 5th, 2019      - Change the expected response from Multi Command to the Command Class reports.
 * April 4th, 2019      - Bug-Fix at the used Command Class versions and Report Parameters.
 * July 17th, 2023      - Removed Zniffer observation.
 *
 * PLEASE NOTE:
 *
 * This script needs to be adjusted according to the supported Command Classes of the DUT.
 * It should run on most Z-Wave Plus devices without modification but it is highly recommened
 * to add other commands to the Multi Command encapsulated messages as well.
 *
 * Responses to the Multi Command encapsulated messages are not checked in this script. They must
 * be observed manually in the Zniffer or in the message log. Howeever, since the answer-as-asked
 * rule for Multi Command is obsoleted and the CTT Controller does not advertise support for the
 * Multi Command CC, the DUT must answer Multi Command-encapsulated requests WITHOUT Multi Command
 * encapsulation.
 *
 */


/**
 * MultipleEncapCommands
 * Verifies returns the correct number of encapsulated responses
 *
 * CC versions: 1
 */

TESTSEQ MultipleEncapCommands: "Verifies returns the correct number of encapsulated responses"

    $numberOfCommands = 3;

    SEND MultiCmd.Encap(
        NumberOfCommands = $numberOfCommands,
        EncapsulatedCommand = [
            0x02, 0x5E, 0x01,       // Z-Wave Plus Info Get
            0x02, 0x86, 0x11,       // Version Get
            0x02, 0x72, 0x04]);     // Manufacturer Specific Get

    MSG ("Expected reports:");
    MSG ("Z-Wave Plus Info Report, Version Report, Manufacturer Specific Report");

    EXPECT ZwaveplusInfo.Report(
        ZWaveVersion in (1, 2),
        RoleType in 0 ... 255,
        NodeType in 0 ... 255,
        InstallerIconType in 0 ... 65535,
        UserIconType in 0 ... 65535);



    EXPECT Version.Report(
        ZWaveLibraryType in 0 ... 11,
        ZWaveProtocolVersion in 0 ... 255,
        ZWaveProtocolSubVersion in 0 ... 255,
        Firmware0Version in 0 ... 255,
        Firmware0SubVersion in 0 ... 255,
        HardwareVersion in 0 ... 255,
        NumberOfFirmwareTargets in 0 ... 255
        );


    EXPECT ManufacturerSpecific.Report(
        ManufacturerId in 0 ... 65535,
        ProductTypeId in 0 ... 65535,
        ProductId in 0 ... 65535);

    //EXPECT MultiCmd.Encap(
    //NumberOfCommands == $numberOfCommands,
    //ANYBYTE(EncapsulatedCommand) in (0 ... 255));

    // Since it is not defined in which sequence the encapsulated commands have to be returned the payload
    // cannot be checked automatically. Possible response bytes are:
    // Z-Wave Plus Info Report: 5E 02 01 05 00 08 00 08 00
    // Version Report: 86 12 03 04 0E 01 11 FF 00
    // Manufacturer Specific Get: 72 05 00 00 00 03 00 0B

    //MSG ("Expected reports:");
    //MSG ("Z-Wave Plus Info Report, Version Report, Manufacturer Specific Report");

    //MSGBOXYES("Check Zniffer - Did the node send all of the listed {0} reports (see Output window of CTT) ?", UINT($numberOfCommands));

TESTSEQ END


/**
 * ExceedingResponsePayload
 * Verifies what happens if the responses do not fit in one Z-Wave message
 * PLEASE NOTE: Zniffer is required for this Test Sequence
 *
 * CC versions: 1
 */

TESTSEQ ExceedingResponsePayload: "Verifies what happens if the responses do not fit in one Z-Wave message"

    $numberOfCommands = 6;

    IF (ISNULL($numberOfCommands))
    {
        MSGFAIL ("Please adjust and comment in the variable $numberOfCommands and the EncapsulatedCommand field matching the capabilities of the DUT.");
    }
    ELSE
    {
        SEND MultiCmd.Encap(
            NumberOfCommands = $numberOfCommands,
            EncapsulatedCommand = [
                0x02, 0x5E, 0x01,               // Z-Wave Plus Info Get
                0x02, 0x86, 0x11,               // Version Get
                0x02, 0x72, 0x04,               // Manufacturer Specific Get
                0x03, 0x59, 0x01, 0x01,         // Association Group Name Get
                0x04, 0x59, 0x03, 0x00, 0x01,   // Association Group Info Get
                0x04, 0x59, 0x05, 0x00, 0x01]); // Association Group Command List Get

        EXPECT ZwaveplusInfo.Report(
            ZWaveVersion in (1, 2),
            RoleType in 0 ... 255,
            NodeType in 0 ... 255,
            InstallerIconType in 0 ... 65535,
            UserIconType in 0 ... 65535);

        EXPECT Version.Report(
            ZWaveLibraryType in 0 ... 11,
            ZWaveProtocolVersion in 0 ... 255,
            ZWaveProtocolSubVersion in 0 ... 255,
            Firmware0Version in 0 ... 255,
            Firmware0SubVersion in 0 ... 255,
            HardwareVersion in 0 ... 255,
            NumberOfFirmwareTargets in 0 ... 255
            );

        EXPECT ManufacturerSpecific.Report(
            ManufacturerId in 0 ... 65535,
            ProductTypeId in 0 ... 65535,
            ProductId in 0 ... 65535);


        EXPECT AssociationGrpInfo.AssociationGroupNameReport(
            GroupingIdentifier in 0 ... 255,
            LengthOfName in 0 ... 42,
            ANYBYTE(Name) in (0 ... 255));

        EXPECT AssociationGrpInfo.AssociationGroupInfoReport(
            GroupCount in 0 ... 31,
            DynamicInfo in (0,1),
            ListMode == 0,
            ANYBYTE(vg1) in (0 ... 255));

        EXPECT AssociationGrpInfo.AssociationGroupCommandListReport(
            GroupingIdentifier in 0 ... 255,
            ListLength in 0 ... 255,
            ANYBYTE(Command) in (0 ... 255));

        //Transport service would actually make the CTT believe it was only 1 frame
        //EXPECT MultiCmd.Encap(
        //    NumberOfCommands in (1 ... $numberOfCommands),
        //    ANYBYTE(EncapsulatedCommand) in (0 ... 255));

        //MSG ("Expected reports:");
        //MSG ("Z-Wave Plus Info Report, Version Report, Manufacturer Specific Report, ");
        //MSG ("Device Specific Report, Association Group Name Report, ");
        //MSG ("Association Group Info Report, Association Group Command List Report");

        //MSGBOXYES("Check Zniffer - Did the node send all of the listed {0} reports (see Output window of CTT) ?", UINT($numberOfCommands));
    }

TESTSEQ END

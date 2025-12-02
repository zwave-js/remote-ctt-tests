PACKAGE VersionCmdClassV3_Rev0900_Orig; // do not modify this line
USE Version CMDCLASSVER = 3;

/**
 * Version Command Class Version 3 Test Script
 * Command Class Specification: SDS13782 2020B
 * Formatting Conventions: Version 2016-05-19
 *
 * PLEASE NOTE:
 * - The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run
 *
 * ChangeLog:
 *
 * October 20th, 2017   - Initial release, derived from V2
 *                      - Version Capabilities commands and Version Z-Wave Software commands added in 'VersionParameters'
 * November 1st, 2017   - MSGBOX for check of Version String for Firmware Targets removed
 *                      - Checks for version numbers in 'VersionParameters' added
 * November 17th, 2017  - Adaptations to current XML file in 'VersionParameters'
 * November 22nd, 2017  - Refactoring of Command Classes list in 'CmdClassVersionNumber'
 * January 24th, 2018   - Bugfix in 'CmdClassVersionNumber' (if frame missing)
 * October 9th, 2018    - Bugfix in 'CmdClassVersionNumber' Move Indicator CC from the Application CCs Section to the Management CCs Section
 * August 9th, 2019     - Command Class list in 'CmdClassVersionNumber' updated to Spec 2019B
 * September 14th, 2020 - AdjustAnnouncement test sequence removed, moved to 'CmdClassVersionNumber'
 *                      - New test sequence 'CheckFirmwareData' (CS-8)
 * September 25th, 2020 - Command Class list in 'CmdClassVersionNumber' updated to Spec 2020B
 *                      - 'SetInitialValuesAndVariables' introduced, checks for execution added
 * October 21st, 2020   - Migration to CTTv3 project format
 *                      - Detection of Root Device / End Point ID using CTTv3 script language features
 * November 2nd, 2020   - Avoid running test sequences against End Point, if CC is not supported
 * December 8th, 2021   - Test sequence 'CmdClassVersionNumber' disabled; has been replaced by ZATS Test Case
 *                        'CCM_VersionCmdClassCCVersions_Rev01'
 * December 21st, 2021  - Messages fixed: FW Meta Data Report
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
    GLOBAL $GLOBAL_commandClassId = 0x86;
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Version";

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

    IF ($GLOBAL_endPointId != 0 && $GLOBAL_ccIsInNIF != 0)
    {
        MSG ("Warning: {0} CC SHOULD NOT be supported on Multichannel End Points.", #GLOBAL_commandClassText);
    }

TESTSEQ END


/**
 * VersionParameters
 * Validates the range of Report values and the V3 capabilities
 *
 * CC versions: 3
 */

TESTSEQ VersionParameters: "Check Version Report parameters"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    IF ($GLOBAL_endPointId != 0)
    {
        IF ($GLOBAL_ccIsInNIF == 0)
        {
            MSG ("{0} CC is not announced as supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
            EXITSEQ;
        }
        MSG ("Warning: {0} CC SHOULD NOT be supported on Multichannel End Points.", #GLOBAL_commandClassText);
    }

    SEND Version.Get( );
    EXPECT Version.Report(
        $zWaveLibraryType          = ZWaveLibraryType        in (0x01 ... 0x0B),
        $zWaveProtocolVersion1     = ZWaveProtocolVersion    in (0x01 ... 0xFF),
        $zWaveProtocolSubVersion1  = ZwaveProtocolSubVersion in (0x00 ... 0xFF),
        $firmware0Version1         = Firmware0Version        in (0x00 ... 0xFF),
        $firmware0SubVersion1      = Firmware0SubVersion     in (0x00 ... 0xFF),
        $hardwareVersion           = HardwareVersion         in (0x00 ... 0xFF),
        $firmwareTargets           = NumberOfFirmwareTargets in (0x00 ... 0xFF),
        $remainingFirmwareVersions = vg );

    MSG ("Z-Wave Library Type: 0x{0:X2}", $zWaveLibraryType);

    // See <SDK>\Z-Wave\include\config_lib.h for Protocol Version and Protocol SubVersion of your SDK
    // See http://zts.sigmadesigns.com Software Release Note chapter 2 for actual SDK versions
    // See http://zts.sigmadesigns.com/maintained-and-monitored-z-wave-sdks for older SDK versions
    MSG ("Z-Wave Protocol Version:     0x{0:X2} = {1}", $zWaveProtocolVersion1, UINT($zWaveProtocolVersion1));
    MSG ("Z-Wave Protocol Sub Version: 0x{0:X2} = {1}", $zWaveProtocolSubVersion1, UINT($zWaveProtocolSubVersion1));

    MSG ("Firmware 0 Version:      0x{0:X2} = {1}", $firmware0Version1, UINT($firmware0Version1));
    MSG ("Firmware 0 Sub Version:  0x{0:X2} = {1}", $firmware0SubVersion1, UINT($firmware0SubVersion1));

    MSG ("Hardware Version: 0x{0:X2}", $hardwareVersion);

    MSG ("Number of Firmware Targets in devices: {0}", UINT($firmwareTargets));
    IF (UINT($firmwareTargets) * 2 != LENGTH($remainingFirmwareVersions))
    {
        MSGFAIL ("Reported NumberOfFirmwareTargets ({0}) requires {1} subsequent bytes with Firmware Version and Sub Version. Reported Firmware Targets length is {2}.",
            UINT($firmwareTargets), UINT($firmwareTargets) * 2, LENGTH($remainingFirmwareVersions));
    }

    MSG ("Version String for Firmware Targets: {0}", $remainingFirmwareVersions);
    MSG ("Warning: You MUST verify manually that the string above has correct Version and Sub Version for the intended number of targets ({0})", UINT($firmwareTargets));
//  MSGBOXYES ("Check Output tab in Message Log window: Is the Version String for Firmware Targets OK?");

    SEND Version.CapabilitiesGet( );
    EXPECT Version.CapabilitiesReport(
        Version == 1,
        CommandClass == 1,
        $zws = ZWaveSoftware in (0, 1),
        Reserved1 == 0);

    SEND Version.ZwaveSoftwareGet( );
    IF ($zws == 0)
    {
        EXPECTNOT Version.ZwaveSoftwareReport;
    }
    IF ($zws == 1)
    {
        EXPECT Version.ZwaveSoftwareReport(
            $sdkVersion               = SdkVersion                      in (0x000000 ... 0xFFFFFF),
            $appFwApiVersion          = ApplicationFrameworkApiVersion  in (0x000000 ... 0xFFFFFF),
            $appFwBuildNumber         = ApplicationFrameworkBuildNumber in (0x0000   ... 0xFFFF),
            $hostInterfaceVersion     = HostInterfaceVersion            in (0x000000 ... 0xFFFFFF),
            $hostInterfaceBuildNumber = HostInterfaceBuildNumber        in (0x0000   ... 0xFFFF),
            $zWaveProtocolVersion3    = ZWaveProtocolVersion            in (0x000000 ... 0xFFFFFF),
            $zWaveProtocolBuildNumber = ZWaveProtocolBuildNumber        in (0x0000   ... 0xFFFF),
            $applicationVersion3      = ApplicationVersion              in (0x000000 ... 0xFFFFFF),
            $applicationBuildNumber   = ApplicationBuildNumber          in (0x0000   ... 0xFFFF));

        MSG ("SdkVersion: {0}.{1}.{2} (hex {3:X3})",           UINT($sdkVersion[0]), UINT($sdkVersion[1]), UINT($sdkVersion[2]), $sdkVersion);
        MSG ("ApplicationFrameworkApiVersion: {0}.{1}.{2} (hex {3:X3})", UINT($appFwApiVersion[0]), UINT($appFwApiVersion[1]), UINT($appFwApiVersion[2]), $appFwApiVersion);
        MSG ("ApplicationFrameworkBuildNumber: {0} (hex {1:X2})",        UINT($appFwBuildNumber), $appFwBuildNumber);
        MSG ("HostInterfaceVersion: {0}.{1}.{2} (hex {3:X3})", UINT($hostInterfaceVersion[0]), UINT($hostInterfaceVersion[1]), UINT($hostInterfaceVersion[2]), $hostInterfaceVersion);
        MSG ("HostInterfaceBuildNumber: {0} (hex {1:X2})",     UINT($hostInterfaceBuildNumber), $hostInterfaceBuildNumber);
        MSG ("ZWaveProtocolVersion: {0}.{1}.{2} (hex {3:X3})", UINT($zWaveProtocolVersion3[0]), UINT($zWaveProtocolVersion3[1]), UINT($zWaveProtocolVersion3[2]), $zWaveProtocolVersion3);
        MSG ("ZWaveProtocolBuildNumber: {0} (hex {1:X2})",     UINT($zWaveProtocolBuildNumber), $zWaveProtocolBuildNumber);
        MSG ("ApplicationVersion: {0}.{1}.{2} (hex {3:X3})",   UINT($applicationVersion3[0]), UINT($applicationVersion3[1]), UINT($applicationVersion3[2]), $applicationVersion3);
        MSG ("ApplicationBuildNumber: {0} (hex {1:X2})",       UINT($applicationBuildNumber), $applicationBuildNumber);

        // ZWave Protocol Version bytes MUST match the Version Report values of ZWave Protocol Version/SubVersion fields:
        // Byte 1 of this field MUST be set to the same value as the Z-Wave Protocol Version field present in the Version Report Command.
        // Byte 2 of this field MUST be set to the same value as the Z-Wave Protocol Sub Version field present in the Version Report Command
        IF ($zWaveProtocolVersion3[0] != $zWaveProtocolVersion1 || $zWaveProtocolVersion3[1] != $zWaveProtocolSubVersion1)
        {
            MSGFAIL ("ZWave Protocol Version does not match the Version Report values.");
        }
        // Application Version bytes MUST match the Version Report values of Firmware 0 Version/SubVersion fields:
        // Byte 1 of this field MUST be set to the same value as the Z-Wave Application field present in the Version Report Command.
        // Byte 2 of this field MUST be set to the same value as the Z-Wave Application Sub Version field present in the Version Report Command.
        // All 3 bytes MUST be set to 0 by a node if its application is running on a host CPU.
        IF ($applicationVersion3[0] != 0x00 && $applicationVersion3[1] != 0x00 && $applicationVersion3[2] != 0x00)
        {
            IF ($applicationVersion3[0] != $firmware0Version1 || $applicationVersion3[1] != $firmware0SubVersion1)
            {
                MSGFAIL ("Application Version does not match the Version Report values.");
            }
        }
    }

TESTSEQ END


/**
 * CheckFirmwareData
 * Check firmware meta data of Version CC and FirmwareUpdateMd CC
 *
 * CC versions: 2, 3
 */

TESTSEQ CheckFirmwareData: "Check firmware meta data of Version CC and FirmwareUpdateMd CC"

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    IF ($GLOBAL_endPointId != 0)
    {
        IF ($GLOBAL_ccIsInNIF == 0)
        {
            MSG ("{0} CC is not announced as supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
            EXITSEQ;
        }
        MSG ("Warning: {0} CC SHOULD NOT be supported on Multichannel End Points.", #GLOBAL_commandClassText);
    }

    $commandClassIdFirmUpd = 0x7A;
    SEND Version.CommandClassGet(RequestedCommandClass = $commandClassIdFirmUpd);
    EXPECT Version.CommandClassReport(
        RequestedCommandClass == $commandClassIdFirmUpd,
        $commandClassVersionF = CommandClassVersion in (0x00 ... 0xFF));
    IF (ISNULL($commandClassVersionF))
    {
        MSGFAIL ("Report Frame missing for Command Class 0x{0:X2} (FirmwareUpdateMd).", $commandClassIdFirmUpd);
        EXITSEQ;
    }

    IF ($commandClassVersionF < 3)
    {
        MSG ("Test not applicable, supported version {0} of FirmwareUpdateMd CC is too low.", $commandClassVersionF);
        EXITSEQ;
    }


    SEND Version.Get( );
    EXPECT Version.Report(
        $hardwareVersionV = HardwareVersion         in (0x00 ... 0xFF),
        $firmwareTargetsV = NumberOfFirmwareTargets in (0x00 ... 0xFF));

    USE FirmwareUpdateMd CMDCLASSVER = 3;
    SEND FirmwareUpdateMd.FirmwareMdGet( );
    EXPECT FirmwareUpdateMd.FirmwareMdReport(
        $firmwareTargetsF = NumberOfFirmwareTargets in (0x00 ... 0xFF));

    IF (ISNULL($firmwareTargetsV) || ISNULL($firmwareTargetsF))
    {
        MSGFAIL ("Report(s) missing.");
        EXITSEQ;
    }

    IF ($firmwareTargetsV != $firmwareTargetsF)
    {
        MSGFAIL ("Number Of Firmware Targets in Version Report (0x{0:X2}) does not match Number Of Firmware Targets in Firmware Meta Data Report (0x{1:X2})",
            $firmwareTargetsV, $firmwareTargetsF);
    }

    IF ($commandClassVersionF >= 5)
    {
        USE FirmwareUpdateMd CMDCLASSVER = 5;
        SEND FirmwareUpdateMd.FirmwareMdGet( );
        EXPECT FirmwareUpdateMd.FirmwareMdReport(
            $hardwareVersionF = HardwareVersion in (0x00 ... 0xFF));
        IF ($hardwareVersionV != $hardwareVersionF)
        {
            MSGFAIL ("Hardware Version in Version Report (0x{0:X2}) does not match Hardware Version in Firmware Meta Data Report (0x{1:X2})",
                $hardwareVersionV, $hardwareVersionF);
        }
    }

TESTSEQ END


/**
 * CmdClassVersionNumber
 * Checks the version number of supported Command Classes
 *
 * Note: The array variable $commandClassesList of this Test Sequence
 *       configures the supported Z-Wave Command Classes of the DUT and
 *       their Version numbers.
 *       The variable contains in its initial state a list of all
 *       Z-Wave Command Classes with Version number set to 0x00, which
 *       means 'Unsupported Command Class'.
 *
 *       To sucessful run this Test Sequence the 2nd column of the array
 *       variable $commandClassesList MUST contain the correct Version
 *       number of all supported Z-Wave Command Classes.
 *       The Node Information Frame and the Certification Form should
 *       contain the necessary information to correctly fill this list.
 *       For all unsupported Command Classes the 2nd column MUST contain
 *       the value 0x00.
 *
 * CC versions: 1, 2, 3
 */

/*
TESTSEQ CmdClassVersionNumber: "Check version number of supported Command Classes"

    $delay = 100;   // Delay between Command Class Get commands in milliseconds. MAY be increased.

    // Check for correct initialization of the test run
    IF (ISNULL($GLOBAL_endPointId))
    {
        MSGFAIL ("The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run.");
        EXITSEQ;
    }

    IF ($GLOBAL_endPointId != 0)
    {
        IF ($GLOBAL_ccIsInNIF == 0)
        {
            MSG ("{0} CC is not announced as supported ({1}).", #GLOBAL_commandClassText, #GLOBAL_endPointName);
            EXITSEQ;
        }
        MSG ("Warning: {0} CC SHOULD NOT be supported on Multichannel End Points.", #GLOBAL_commandClassText);
    }

    $commandClassesList = [

    // Application Command Classes
    //   CC  Version      Command Class Name
        0x9C, 0x00,    // Alarm Sensor (deprecated in SDS13781 2019B)
        0x9D, 0x00,    // Alarm Silence
        0x27, 0x00,    // All Switch (obsoleted in SDS13781 2019B)
        0x5D, 0x00,    // Anti-Theft
        0x7E, 0x00,    // Anti-Theft Unlock
        0xA1, 0x00,    // Authentication
        0xA2, 0x00,    // Authentication Media Write
        0x66, 0x00,    // Barrier Operator
        0x20, 0x00,    // Basic
        0x36, 0x00,    // Basic Tariff Information
        0x50, 0x00,    // Basic Window Covering (obsoleted in SDS13781 2019B)
        0x30, 0x00,    // Binary Sensor (deprecated in SDS13781 2019B)
        0x25, 0x00,    // Binary Switch
        0x28, 0x00,    // Binary Toggle Switch (obsoleted in SDS13781 2019B)
        0x5B, 0x00,    // Central Scene
        0x46, 0x00,    // Climate Control Schedule (deprecated in SDS13781 2019B)
        0x81, 0x00,    // Clock
        0x33, 0x00,    // Color Switch
        0x70, 0x00,    // Configuration
        0x21, 0x00,    // Controller Replication
        0x3A, 0x00,    // Demand Control Plan Configuration
        0x3B, 0x00,    // Demand Control Plan Monitor
        0x62, 0x00,    // Door Lock
        0x4C, 0x00,    // Door Lock Logging
        0x90, 0x00,    // Energy Production
        0x6F, 0x00,    // Entry Control
        0xA3, 0x00,    // Generic Schedule
        0x8C, 0x00,    // Geographic Location
        0x37, 0x00,    // HRV Status
        0x39, 0x00,    // HRV Control
        0x6D, 0x00,    // Humidity Control Mode
        0x6E, 0x00,    // Humidity Control Operating State
        0x64, 0x00,    // Humidity Control Setpoint
        0xA0, 0x00,    // IR Repeater
        0x6B, 0x00,    // Irrigation
        0x89, 0x00,    // Language
        0x76, 0x00,    // Lock
        0x91, 0x00,    // Manufacturer Proprietary
        0x32, 0x00,    // Meter
        0x3C, 0x00,    // Meter Table Configuration
        0x3D, 0x00,    // Meter Table Monitor
        0x3E, 0x00,    // Meter Table Push
        0x51, 0x00,    // Move To Position Window Covering
        0x31, 0x00,    // Multilevel Sensor
        0x26, 0x00,    // Multilevel Switch
        0x29, 0x00,    // Multilevel Toggle Switch (deprecated in SDS13781 2019B)
        0x71, 0x00,    // Notification / Alarm
        0x3F, 0x00,    // Prepayment
        0x41, 0x00,    // Prepayment Encapsulation
        0x88, 0x00,    // Proprietary (deprecated in SDS13781 2019B)
        0x75, 0x00,    // Protection
        0x35, 0x00,    // Pulse Meter (deprecated in SDS13781 2019B)
        0x48, 0x00,    // Rate Table Configuration
        0x49, 0x00,    // Rate Table Monitor
        0x2B, 0x00,    // Scene Activation
        0x2C, 0x00,    // Scene Actuator Configuration
        0x2D, 0x00,    // Scene Controller Configuration
        0x53, 0x00,    // Schedule
        0x4E, 0x00,    // Schedule Entry Lock (deprecated in SDS13781 2019B)
        0x93, 0x00,    // Screen Attributes
        0x92, 0x00,    // Screen Meta Data
        0x9E, 0x00,    // Sensor Configuration (obsoleted in SDS13781 2019B)
        0x94, 0x00,    // Simple AV Control
        0x79, 0x00,    // Sound Switch
        0x4A, 0x00,    // Tariff Table Configuration
        0x4B, 0x00,    // Tariff Table Monitor
        0x44, 0x00,    // Thermostat Fan Mode
        0x45, 0x00,    // Thermostat Fan State
        0x40, 0x00,    // Thermostat Mode
        0x42, 0x00,    // Thermostat Operating State
        0x47, 0x00,    // Thermostat Setback
        0x43, 0x00,    // Thermostat Setpoint
        0x63, 0x00,    // User Code
        0x6A, 0x00,    // Window Covering

    // Management Command Classes
    //   CC  Version      Command Class Name
        0x57, 0x00,    // Application Capability (obsoleted in SDS13781 2019B)
        0x22, 0x00,    // Application Status
        0x85, 0x00,    // Association
        0x9B, 0x00,    // Association Command Configuration
        0x59, 0x00,    // Association Group Info
        0x80, 0x00,    // Battery
        0x5A, 0x00,    // Device Reset Locally
        0x7A, 0x00,    // Firmware Update Meta Data
        0x7B, 0x00,    // Grouping Name (deprecated in SDS13781 2019B)
        0x82, 0x00,    // Hail (obsoleted in SDS13781 2019B)
        0x87, 0x00,    // Indicator
        0x5C, 0x00,    // IP Association
        0x72, 0x00,    // Manufacturer Specific
        0x8E, 0x00,    // Multi Channel Association
        0x77, 0x00,    // Node Naming and Location
        0x7C, 0x00,    // Remote Association Activation
        0x7D, 0x00,    // Remote Association Configuration
        0x8A, 0x00,    // Time
        0x8B, 0x00,    // Time Parameters
        0x86, 0x00,    // Version
        0x84, 0x00,    // Wake up
        0x68, 0x00,    // Z/IP Naming and Location
        0x5E, 0x00,    // Z-Wave Plus Info

    // Transport-Encapsulation Command Classes
    //   CC  Version      Command Class Name
        0x56, 0x00,    // CRC-16 Encapsulation (deprecated in SDS13781 2019B)
        0x60, 0x00,    // Multi Channel
        0x8F, 0x00,    // Multi Command
        0x98, 0x00,    // Security 0
        0x9F, 0x00,    // Security 2
        0x6C, 0x00,    // Supervision
        0x55, 0x00,    // Transport Service

    // Network-Protocol Command Classes
    //   CC  Version      Command Class Name
        0x74, 0x00,    // Inclusion Controller
        0x9A, 0x00,    // IP Configuration (obsoleted in SDS13781 2019B)
        0x69, 0x00,    // Mailbox
        0x52, 0x00,    // Network Management Proxy
        0x4D, 0x00,    // Network Management Basic Node
        0x34, 0x00,    // Network Management Inclusion
        0x54, 0x00,    // Network Management Primary
        0x67, 0x00,    // Network Management Installation and Maintenance
        0x00, 0x00,    // No Operation
        0x78, 0x00,    // Node Provisioning
        0x73, 0x00,    // Powerlevel
        0x23, 0x00,    // Z/IP
        0x4F, 0x00,    // Z/IP 6LoWPAN (not in Portal)
        0x5F, 0x00,    // Z/IP Gateway
        0x58, 0x00,    // Z/IP ND
        0x61, 0x00,    // Z/IP Portal

    // Obsoleted Command Classes (no longer listed in SDS1378x)
    //   CC  Version      Command Class Name
        0x95, 0x00,    // AV Content Directory Meta Data
        0x97, 0x00,    // AV Content Search Meta Data
        0x96, 0x00,    // AV Renderer Status
        0x99, 0x00,    // AV Tagging Meta Data
        0x2A, 0x00,    // Chimney Fan
        0x65, 0x00,    // DMX
        0xF0, 0x00,    // Non Interoperable
        0x24, 0x00,    // Security Panel Mode
        0x2E, 0x00,    // Security Panel Zone
        0x2F, 0x00,    // Security Panel Zone Sensor
        0x38, 0x00     // Thermostat Heating

    ]; // end $commandClassesList


    // Check for adjustment of $commandClassesList
    $adjustCheck = 0;
    LOOP ($i; 0; LENGTH($commandClassesList) - 2)
    {
        $adjustCheck = $adjustCheck + $commandClassesList[$i + 1];
        $i = $i + 1; // adjust $i for LOOP
    } // LOOP ($i)

    IF ($adjustCheck == 0)
    {
        MSGFAIL ("To run the Version Command Class Test Script the 'CmdClassVersionNumber' Test Sequence MUST be adjusted according to supported Command Classes of the DUT.");
        MSGFAIL ("You MUST adjust the $commandClassesList array variable.");
        MSGFAIL ("For details refer to the header comment of the Test Sequence header 'CmdClassVersionNumber'.");
        EXITSEQ;
    }

    LOOP ($i; 0; LENGTH($commandClassesList) - 2)
    {
        SEND Version.CommandClassGet(RequestedCommandClass = $commandClassesList[$i]);
        EXPECT Version.CommandClassReport(
            $requestedCommandClass = RequestedCommandClass == $commandClassesList[$i],
            $commandClassVersion   = CommandClassVersion   == $commandClassesList[$i + 1]);
        IF (ISNULL($requestedCommandClass))
        {
            MSGFAIL ("Report Frame missing for Command Class 0x{0:X2}.", $commandClassesList[$i * 2]);
            $requestedCommandClass = $commandClassesList[$i];
            $commandClassVersion = 0;
        }
        // Application Command Classes
        IF     ($requestedCommandClass == 0x9C) { MSG ("Alarm Sensor V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x9D) { MSG ("Alarm Silence V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x27) { MSG ("All Switch V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x5D) { MSG ("Anti-Theft V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x7E) { MSG ("Anti-Theft Unlock V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0xA1) { MSG ("Authentication V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0xA2) { MSG ("Authentication Media Write V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x66) { MSG ("Barrier Operator V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x20) { MSG ("Basic V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x36) { MSG ("Basic Tariff Info V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x50) { MSG ("Basic Window Covering V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x30) { MSG ("Binary Sensor V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x25) { MSG ("Binary Switch V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x28) { MSG ("Binary Toggle Switch V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x5B) { MSG ("Central Scene V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x46) { MSG ("Climate Control Schedule V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x81) { MSG ("Clock V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x33) { MSG ("Color Switch V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x70) { MSG ("Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x21) { MSG ("Controller Replication V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x3A) { MSG ("Demand Control Plan Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x3B) { MSG ("Demand Control Plan Monitor V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x62) { MSG ("Door Lock V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x4C) { MSG ("Door Lock Logging V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x90) { MSG ("Energy Production V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x6F) { MSG ("Entry Control V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0xA3) { MSG ("Generic Schedule V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x8C) { MSG ("Geographic Location V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x39) { MSG ("Hrv Control V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x37) { MSG ("Hrv Status V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x6D) { MSG ("Humidity Control Mode V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x6E) { MSG ("Humidity Control Operating State V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x64) { MSG ("Humidity Control Setpoint V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x87) { MSG ("Indicator V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0xA0) { MSG ("IR Repeater V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x6B) { MSG ("Irrigation V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x89) { MSG ("Language V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x76) { MSG ("Lock V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x91) { MSG ("Manufacturer Proprietary V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x32) { MSG ("Meter V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x3C) { MSG ("Meter Table Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x3D) { MSG ("Meter Table Monitor V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x3E) { MSG ("Meter Table Push V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x51) { MSG ("Move To Position Window Covering V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x31) { MSG ("Multilevel Sensor V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x26) { MSG ("Multilevel Switch V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x29) { MSG ("Multilevel Toggle Switch V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x71) { MSG ("Notification / Alarm V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x3F) { MSG ("Prepayment V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x41) { MSG ("Prepayment Encapsulation V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x88) { MSG ("Proprietary V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x75) { MSG ("Protection V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x35) { MSG ("Pulse Meter V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x48) { MSG ("Rate Table Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x49) { MSG ("Rate Table Monitor V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x2B) { MSG ("Scene Activation V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x2C) { MSG ("Scene Actuator Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x2D) { MSG ("Scene Controller Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x53) { MSG ("Schedule V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x4E) { MSG ("Schedule Entry Lock V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x93) { MSG ("Screen Attributes V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x92) { MSG ("Screen Meta Data V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x9E) { MSG ("Sensor Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x94) { MSG ("Simple AV Control V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x79) { MSG ("Sound Switch V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x4A) { MSG ("Tariff Table Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x4B) { MSG ("Tariff Table Monitor V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x44) { MSG ("Thermostat Fan Mode V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x45) { MSG ("Thermostat Fan State V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x40) { MSG ("Thermostat Mode V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x42) { MSG ("Thermostat Operating State V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x47) { MSG ("Thermostat Setback V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x43) { MSG ("Thermostat Setpoint V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x63) { MSG ("User Code V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x6A) { MSG ("Window Covering V{0}", UINT($commandClassVersion)); }
        // Management Command Classes
        ELSEIF ($requestedCommandClass == 0x57) { MSG ("Application Capability V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x22) { MSG ("Application Status V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x85) { MSG ("Association V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x9B) { MSG ("Association Command Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x59) { MSG ("Association Group Info V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x80) { MSG ("Battery V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x5A) { MSG ("Device Reset Locally V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x7A) { MSG ("Firmware Update Meta Data V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x7B) { MSG ("Grouping Name V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x82) { MSG ("Hail V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x5C) { MSG ("IP Association V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x72) { MSG ("Manufacturer Specific V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x8E) { MSG ("Multi Channel Association V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x77) { MSG ("Node Naming And Location V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x7D) { MSG ("Remote Association Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x7C) { MSG ("Remote Association Activation V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x8A) { MSG ("Time V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x8B) { MSG ("Time Parameters V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x86) { MSG ("Version V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x84) { MSG ("Wake Up V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x68) { MSG ("Z/IP Naming V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x5E) { MSG ("Z-Wave Plus Info V{0}", UINT($commandClassVersion)); }
        // Transport-Encapsulation Command Classes
        ELSEIF ($requestedCommandClass == 0x56) { MSG ("CRC-16 Encapsulation V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x60) { MSG ("Multi Channel V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x8F) { MSG ("Multi Command V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x98) { MSG ("Security 0 V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x9F) { MSG ("Security 2 V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x6C) { MSG ("Supervision V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x55) { MSG ("Transport Service V{0}", UINT($commandClassVersion)); }
        // Network-Protocol Command Classes
        ELSEIF ($requestedCommandClass == 0x74) { MSG ("Inclusion Controller V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x9A) { MSG ("IP Configuration V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x69) { MSG ("Mailbox V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x52) { MSG ("Network Management Proxy V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x4D) { MSG ("Network Management Basic V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x34) { MSG ("Network Management Inclusion V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x54) { MSG ("Network Management Primary V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x67) { MSG ("Network Management Installation and Maintenance V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x00) { MSG ("No Operation V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x78) { MSG ("Node Provisioning V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x73) { MSG ("Powerlevel V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x23) { MSG ("Z/IP V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x4F) { MSG ("Z/IP 6LoWPAN V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x5F) { MSG ("Z/IP Gateway V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x58) { MSG ("Z/IP ND V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x61) { MSG ("Z/IP Portal V{0}", UINT($commandClassVersion)); }
        // Obsoleted Command Classes (no longer listed in SDS1378x)
        ELSEIF ($requestedCommandClass == 0x95) { MSG ("AV Content Directory Meta Data V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x97) { MSG ("AV Content Search Meta Data V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x96) { MSG ("AV Renderer Status V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x99) { MSG ("AV Tagging Meta Data V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x2A) { MSG ("Chimney Fan V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x65) { MSG ("DMX V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0xF0) { MSG ("Non Interoperable V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x24) { MSG ("Security Panel Mode V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x2E) { MSG ("Security Panel Zone V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x2F) { MSG ("Security Panel Zone Sensor V{0}", UINT($commandClassVersion)); }
        ELSEIF ($requestedCommandClass == 0x38) { MSG ("Thermostat Heating V{0}", UINT($commandClassVersion)); }

        ELSE
        {
            MSG ("Command Class: 0x{0:X2}", $requestedCommandClass);
            MSG ("Command Class Version: {0}", UINT($commandClassVersion));
        }
        WAIT ($delay);
        $i = $i + 1; // adjust $i for LOOP
    } // LOOP ($i)

    MSG ("Finished.");

TESTSEQ END
*/
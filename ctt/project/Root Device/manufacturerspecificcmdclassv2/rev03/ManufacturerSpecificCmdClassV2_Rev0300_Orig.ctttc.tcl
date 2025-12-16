PACKAGE ManufacturerSpecificCmdClassV2_Rev0300_Orig; // do not modify this line
USE ManufacturerSpecific CMDCLASSVER = 2;

/**
 * Manufacturer Specific Command Class Version 2 Test Script
 * Command Class Specification: SDS13781 2020B
 * Formatting Conventions: Version 2016-05-19
 *
 * PLEASE NOTE:
 * - The 'SetInitialValuesAndVariables' test sequence MUST be executed in each test run
 *
 * ChangeLog:
 *
 * October 15th, 2015   - Manufacturer list updated
 * October 15th, 2015   - More checks and log messages on the default Device ID Type check
 * March 18th, 2016     - Refactoring; more checks and improvements in DeviceSpecific
 * March 21th, 2016     - Manufacturer list updated
 * April 15th, 2016     - Refactoring
 * May 23th, 2016       - Improvements in 'DeviceSpecific' with EXPECTOPT
 * July 28th, 2016      - Manufacturer list updated
 * March 12th, 2020     - Manufacturer Sigma Designs renamed to Silicon Labs
 * November 2nd, 2020   - Migration to CTTv3 project format
 *                      - Detection of Root Device / End Point ID using CTTv3 script language features
 *                      - 'SetInitialValuesAndVariables' introduced
 */


/**
 * SetInitialValuesAndVariables
 * This sequence sets the global variables and initial values for the tests of this command class.
 * This sequence MUST be executed in each test run.
 * If it is not executed, this will lead to errors in the following test sequences.
 *
 * CC versions: 1, 2
 */

TESTSEQ SetInitialValuesAndVariables: "Set initial Values and Variables."

    // Test environment configuration - MAY be changed
  //GLOBAL $GLOBAL_sessionId = 1;      // Adjust if specific Supervision Session ID is needed.

    // Test data - MUST NOT be changed
    GLOBAL $GLOBAL_endPointId = GETENDPOINT();
    GLOBAL $GLOBAL_commandClassId = 0x72;
    GLOBAL #GLOBAL_commandClassName = GETCOMMANDCLASSNAME($GLOBAL_commandClassId);
    GLOBAL #GLOBAL_commandClassText = "Manufacturer Specific";

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
 * ManufacturerSpecificReport
 * Verifies data of Manufacturer Specific Report
 *
 * CC versions: 1, 2
 */

TESTSEQ ManufacturerSpecificReport: "Check the return values of the Manufacturer Specific Report"

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

    SEND ManufacturerSpecific.Get( );
    EXPECT ManufacturerSpecific.Report(
        $manufacturerId = ManufacturerId in (0x0000 ... 0xFFFF),
        $productTypeId  = ProductTypeId  in (0x0000 ... 0xFFFF),
        $productId      = ProductId      in (0x0000 ... 0xFFFF));

    IF     ($manufacturerId == 0x0028) { MSG ("Manufacturer: 2B Electronics"); }
    ELSEIF ($manufacturerId == 0x009B) { MSG ("Manufacturer: 2gig Technologies Inc."); }
    ELSEIF ($manufacturerId == 0x002A) { MSG ("Manufacturer: 3e Technologies"); }
    ELSEIF ($manufacturerId == 0x0022) { MSG ("Manufacturer: A-1 Components"); }
    ELSEIF ($manufacturerId == 0x0117) { MSG ("Manufacturer: Abilia"); }
    ELSEIF ($manufacturerId == 0x0001) { MSG ("Manufacturer: ACT - Advanced Control Technologies"); }
    ELSEIF ($manufacturerId == 0x0101) { MSG ("Manufacturer: ADOX, Inc."); }
    ELSEIF ($manufacturerId == 0x016C) { MSG ("Manufacturer: Advanced Optronic Devices Co.,Ltd"); }
    ELSEIF ($manufacturerId == 0x009E) { MSG ("Manufacturer: Adventure Interactive"); }
    ELSEIF ($manufacturerId == 0x0086) { MSG ("Manufacturer: AEON Labs"); }
    ELSEIF ($manufacturerId == 0x0111) { MSG ("Manufacturer: Airline Mechanical Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0088) { MSG ("Manufacturer: Airvent SAM S.p.A."); }
    ELSEIF ($manufacturerId == 0x0094) { MSG ("Manufacturer: Alarm.com"); }
    ELSEIF ($manufacturerId == 0x0126) { MSG ("Manufacturer: Alertme"); }
    ELSEIF ($manufacturerId == 0x003B) { MSG ("Manufacturer: Allegion"); }
    ELSEIF ($manufacturerId == 0x0230) { MSG ("Manufacturer: Alphonsus Tech"); }
    ELSEIF ($manufacturerId == 0x019C) { MSG ("Manufacturer: Amdocs"); }
    ELSEIF ($manufacturerId == 0x005A) { MSG ("Manufacturer: American Grid, Inc."); }
    ELSEIF ($manufacturerId == 0x0078) { MSG ("Manufacturer: anyCOMM Corporation"); }
    ELSEIF ($manufacturerId == 0x0144) { MSG ("Manufacturer: Applied Micro Electronics 'AME' BV"); }
    ELSEIF ($manufacturerId == 0x0029) { MSG ("Manufacturer: Asia Heading"); }
    ELSEIF ($manufacturerId == 0x0231) { MSG ("Manufacturer: ASITEQ"); }
    ELSEIF ($manufacturerId == 0x0129) { MSG ("Manufacturer: ASSA ABLOY"); }
    ELSEIF ($manufacturerId == 0x013B) { MSG ("Manufacturer: AstraLink"); }
    ELSEIF ($manufacturerId == 0x013B) { MSG ("Manufacturer: AstraLink"); }
    ELSEIF ($manufacturerId == 0x0134) { MSG ("Manufacturer: AT&T"); }
    ELSEIF ($manufacturerId == 0x002B) { MSG ("Manufacturer: Atech"); }
    ELSEIF ($manufacturerId == 0x0244) { MSG ("Manufacturer: Athom BV"); }
    ELSEIF ($manufacturerId == 0x0155) { MSG ("Manufacturer: Avadesign Technology Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0146) { MSG ("Manufacturer: Axesstel Inc"); }
    ELSEIF ($manufacturerId == 0x0018) { MSG ("Manufacturer: Balboa Instruments"); }
    ELSEIF ($manufacturerId == 0x0236) { MSG ("Manufacturer: Bandi Comm Tech Inc."); }
    ELSEIF ($manufacturerId == 0x0204) { MSG ("Manufacturer: Beijing Sino-American Boyi Software Development Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x0251) { MSG ("Manufacturer: Beijing Universal Energy Huaxia Technology Co.,Ltd"); }
    ELSEIF ($manufacturerId == 0x0196) { MSG ("Manufacturer: Bellatrix Systems, Inc."); }
    ELSEIF ($manufacturerId == 0x008A) { MSG ("Manufacturer: BeNext"); }
    ELSEIF ($manufacturerId == 0x002C) { MSG ("Manufacturer: BeSafer"); }
    ELSEIF ($manufacturerId == 0x014B) { MSG ("Manufacturer: BFT S.p.A."); }
    ELSEIF ($manufacturerId == 0x0052) { MSG ("Manufacturer: Bit7 Inc."); }
    ELSEIF ($manufacturerId == 0x0090) { MSG ("Manufacturer: Black & Decker"); }
    ELSEIF ($manufacturerId == 0x0213) { MSG ("Manufacturer: BMS Evler LTD"); }
    ELSEIF ($manufacturerId == 0x0023) { MSG ("Manufacturer: Boca Devices"); }
    ELSEIF ($manufacturerId == 0x015C) { MSG ("Manufacturer: Bosch Security Systems, Inc"); }
    ELSEIF ($manufacturerId == 0x0138) { MSG ("Manufacturer: BRK Brands, Inc."); }
    ELSEIF ($manufacturerId == 0x002D) { MSG ("Manufacturer: Broadband Energy Networks Inc."); }
    ELSEIF ($manufacturerId == 0x024A) { MSG ("Manufacturer: BTSTAR(HK) TECHNOLOGY COMPANY LIMITED"); }
    ELSEIF ($manufacturerId == 0x0145) { MSG ("Manufacturer: Buffalo Inc."); }
    ELSEIF ($manufacturerId == 0x0145) { MSG ("Manufacturer: Buffalo Inc."); }
    ELSEIF ($manufacturerId == 0x0190) { MSG ("Manufacturer: Building 36 Technologies"); }
    ELSEIF ($manufacturerId == 0x0026) { MSG ("Manufacturer: BuLogics"); }
    ELSEIF ($manufacturerId == 0x0169) { MSG ("Manufacturer: Boenig und Kallenbach oHG"); }
    ELSEIF ($manufacturerId == 0x009C) { MSG ("Manufacturer: Cameo Communications Inc."); }
    ELSEIF ($manufacturerId == 0x002E) { MSG ("Manufacturer: Carrier"); }
    ELSEIF ($manufacturerId == 0x000B) { MSG ("Manufacturer: CasaWorks"); }
    ELSEIF ($manufacturerId == 0x0243) { MSG ("Manufacturer: casenio AG"); }
    ELSEIF ($manufacturerId == 0x0166) { MSG ("Manufacturer: CBCC Domotique SAS"); }
    ELSEIF ($manufacturerId == 0x0246) { MSG ("Manufacturer: CentraLite Systems, Inc"); }
    ELSEIF ($manufacturerId == 0x014E) { MSG ("Manufacturer: Check-It Solutions Inc."); }
    ELSEIF ($manufacturerId == 0x0116) { MSG ("Manufacturer: Chromagic Technologies Corporation"); }
    ELSEIF ($manufacturerId == 0x0082) { MSG ("Manufacturer: Cisco Consumer Business Group"); }
    ELSEIF ($manufacturerId == 0x018E) { MSG ("Manufacturer: Climax Technology, Ltd."); }
    ELSEIF ($manufacturerId == 0x0200) { MSG ("Manufacturer: Cloud Media"); }
    ELSEIF ($manufacturerId == 0x0200) { MSG ("Manufacturer: Cloud Media"); }
    ELSEIF ($manufacturerId == 0x002F) { MSG ("Manufacturer: Color Kinetics Incorporated"); }
    ELSEIF ($manufacturerId == 0x0140) { MSG ("Manufacturer: Computime"); }
    ELSEIF ($manufacturerId == 0x011B) { MSG ("Manufacturer: Connected Object"); }
    ELSEIF ($manufacturerId == 0x0179) { MSG ("Manufacturer: ConnectHome"); }
    ELSEIF ($manufacturerId == 0x0019) { MSG ("Manufacturer: ControlThink LC"); }
    ELSEIF ($manufacturerId == 0x000F) { MSG ("Manufacturer: ConvergeX Ltd."); }
    ELSEIF ($manufacturerId == 0x007D) { MSG ("Manufacturer: CoolGuard"); }
    ELSEIF ($manufacturerId == 0x0079) { MSG ("Manufacturer: Cooper Lighting"); }
    ELSEIF ($manufacturerId == 0x001A) { MSG ("Manufacturer: Cooper Wiring Devices"); }
    ELSEIF ($manufacturerId == 0x009D) { MSG ("Manufacturer: Coventive Technologies Inc."); }
    ELSEIF ($manufacturerId == 0x0014) { MSG ("Manufacturer: Cyberhouse"); }
    ELSEIF ($manufacturerId == 0x0067) { MSG ("Manufacturer: CyberTAN Technology, Inc."); }
    ELSEIF ($manufacturerId == 0x0030) { MSG ("Manufacturer: Cytech Technology Pre Ltd."); }
    ELSEIF ($manufacturerId == 0x0002) { MSG ("Manufacturer: Danfoss"); }
    ELSEIF ($manufacturerId == 0x018C) { MSG ("Manufacturer: Dawon DNS"); }
    ELSEIF ($manufacturerId == 0x020A) { MSG ("Manufacturer: Decoris Intelligent System Limited"); }
    ELSEIF ($manufacturerId == 0x013F) { MSG ("Manufacturer: Defacontrols BV"); }
    ELSEIF ($manufacturerId == 0x0031) { MSG ("Manufacturer: Destiny Networks"); }
    ELSEIF ($manufacturerId == 0x0175) { MSG ("Manufacturer: Devolo"); }
    ELSEIF ($manufacturerId == 0x0103) { MSG ("Manufacturer: Diehl AKO"); }
    ELSEIF ($manufacturerId == 0x0032) { MSG ("Manufacturer: Digital 5, Inc."); }
    ELSEIF ($manufacturerId == 0x024E) { MSG ("Manufacturer: Digital Home Systems Pty Ltd,"); }
    ELSEIF ($manufacturerId == 0x0228) { MSG ("Manufacturer: DigitalZone"); }
    ELSEIF ($manufacturerId == 0x0108) { MSG ("Manufacturer: D-Link"); }
    ELSEIF ($manufacturerId == 0x0127) { MSG ("Manufacturer: DMP (Digital Monitoring Products)"); }
    ELSEIF ($manufacturerId == 0x0177) { MSG ("Manufacturer: Domino sistemi d.o.o."); }
    ELSEIF ($manufacturerId == 0x020E) { MSG ("Manufacturer: Domitech Products, LLC"); }
    ELSEIF ($manufacturerId == 0x020C) { MSG ("Manufacturer: Dongguan Zhou Da Electronics Co.,Ltd"); }
    ELSEIF ($manufacturerId == 0x017D) { MSG ("Manufacturer: DRACOR Inc."); }
    ELSEIF ($manufacturerId == 0x0184) { MSG ("Manufacturer: Dragon Tech Industrial, Ltd."); }
    ELSEIF ($manufacturerId == 0x0223) { MSG ("Manufacturer: DTV Research Unipessoal, Lda"); }
    ELSEIF ($manufacturerId == 0x0132) { MSG ("Manufacturer: DynaQuip Controls"); }
    ELSEIF ($manufacturerId == 0x0247) { MSG ("Manufacturer: EASY SAVER Co., Inc"); }
    ELSEIF ($manufacturerId == 0x017C) { MSG ("Manufacturer: EbV"); }
    ELSEIF ($manufacturerId == 0x016B) { MSG ("Manufacturer: Echostar"); }
    ELSEIF ($manufacturerId == 0x014A) { MSG ("Manufacturer: Ecolink"); }
    ELSEIF ($manufacturerId == 0x0157) { MSG ("Manufacturer: EcoNet Controls"); }
    ELSEIF ($manufacturerId == 0x010D) { MSG ("Manufacturer: e-Home AUTOMATION"); }
    ELSEIF ($manufacturerId == 0x0087) { MSG ("Manufacturer: Eka Systems"); }
    ELSEIF ($manufacturerId == 0x0033) { MSG ("Manufacturer: Electronic Solutions"); }
    ELSEIF ($manufacturerId == 0x021F) { MSG ("Manufacturer: Elexa Consumer Products Inc."); }
    ELSEIF ($manufacturerId == 0x0034) { MSG ("Manufacturer: El-Gev Electronics LTD"); }
    ELSEIF ($manufacturerId == 0x001B) { MSG ("Manufacturer: ELK Products, Inc."); }
    ELSEIF ($manufacturerId == 0x020B) { MSG ("Manufacturer: Embedded System Design Limited"); }
    ELSEIF ($manufacturerId == 0x0035) { MSG ("Manufacturer: Embedit A/S"); }
    ELSEIF ($manufacturerId == 0x014D) { MSG ("Manufacturer: Enblink Co. Ltd"); }
    ELSEIF ($manufacturerId == 0x0219) { MSG ("Manufacturer: Enwox Technologies s.r.o."); }
    ELSEIF ($manufacturerId == 0x006F) { MSG ("Manufacturer: Erone"); }
    ELSEIF ($manufacturerId == 0x0160) { MSG ("Manufacturer: Essence Security"); }
    ELSEIF ($manufacturerId == 0x0148) { MSG ("Manufacturer: Eurotronics"); }
    ELSEIF ($manufacturerId == 0x0060) { MSG ("Manufacturer: Everspring"); }
    ELSEIF ($manufacturerId == 0x0113) { MSG ("Manufacturer: Evolve"); }
    ELSEIF ($manufacturerId == 0x0036) { MSG ("Manufacturer: Exceptional Innovations"); }
    ELSEIF ($manufacturerId == 0x0004) { MSG ("Manufacturer: Exhausto"); }
    ELSEIF ($manufacturerId == 0x009F) { MSG ("Manufacturer: Exigent Sensors"); }
    ELSEIF ($manufacturerId == 0x001E) { MSG ("Manufacturer: Express Controls"); }
    ELSEIF ($manufacturerId == 0x0233) { MSG ("Manufacturer: eZEX Corporation"); }
    ELSEIF ($manufacturerId == 0x0085) { MSG ("Manufacturer: Fakro"); }
    ELSEIF ($manufacturerId == 0x016A) { MSG ("Manufacturer: Fantem"); }
    ELSEIF ($manufacturerId == 0x010F) { MSG ("Manufacturer: Fibargroup"); }
    ELSEIF ($manufacturerId == 0x018D) { MSG ("Manufacturer: Flextronics"); }
    ELSEIF ($manufacturerId == 0x0024) { MSG ("Manufacturer: Flue Sentinel"); }
    ELSEIF ($manufacturerId == 0x0037) { MSG ("Manufacturer: Foard Systems"); }
    ELSEIF ($manufacturerId == 0x018F) { MSG ("Manufacturer: Focal Point Limited"); }
    ELSEIF ($manufacturerId == 0x0137) { MSG ("Manufacturer: FollowGood Technology Company Ltd."); }
    ELSEIF ($manufacturerId == 0x0207) { MSG ("Manufacturer: Forest Group Nederland B.V"); }
    ELSEIF ($manufacturerId == 0x0084) { MSG ("Manufacturer: FortrezZ LLC"); }
    ELSEIF ($manufacturerId == 0x011D) { MSG ("Manufacturer: Foxconn"); }
    ELSEIF ($manufacturerId == 0x0110) { MSG ("Manufacturer: Frostdale"); }
    ELSEIF ($manufacturerId == 0x025A) { MSG ("Manufacturer: GES"); }
    ELSEIF ($manufacturerId == 0x022B) { MSG ("Manufacturer: GKB Security Corporation"); }
    ELSEIF ($manufacturerId == 0x018A) { MSG ("Manufacturer: Globalchina-Tech"); }
    ELSEIF ($manufacturerId == 0x0159) { MSG ("Manufacturer: Goap"); }
    ELSEIF ($manufacturerId == 0x0076) { MSG ("Manufacturer: Goggin Research"); }
    ELSEIF ($manufacturerId == 0x0068) { MSG ("Manufacturer: Good Way Technology Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x0099) { MSG ("Manufacturer: GreenWave Reality Inc."); }
    ELSEIF ($manufacturerId == 0x018B) { MSG ("Manufacturer: Grib"); }
    ELSEIF ($manufacturerId == 0x016D) { MSG ("Manufacturer: Guangzhou Ruixiang M&E Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x0158) { MSG ("Manufacturer: GuangZhou Zeewave Information Technology Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x024C) { MSG ("Manufacturer: Hankook Gas Kiki CO.,LTD. "); }
    ELSEIF ($manufacturerId == 0x025C) { MSG ("Manufacturer: Hauppauge"); }
    ELSEIF ($manufacturerId == 0x0073) { MSG ("Manufacturer: Hawking Technologies Inc."); }
    ELSEIF ($manufacturerId == 0x020F) { MSG ("Manufacturer: Herald Datanetics Limited"); }
    ELSEIF ($manufacturerId == 0x0017) { MSG ("Manufacturer: HiTech Automation"); }
    ELSEIF ($manufacturerId == 0x0181) { MSG ("Manufacturer: Holion Electronic Engineering Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x013E) { MSG ("Manufacturer: Holtec Electronics BV"); }
    ELSEIF ($manufacturerId == 0x000D) { MSG ("Manufacturer: Home Automated Living"); }
    ELSEIF ($manufacturerId == 0x009A) { MSG ("Manufacturer: Home Automation Europe"); }
    ELSEIF ($manufacturerId == 0x005B) { MSG ("Manufacturer: Home Automation Inc."); }
    ELSEIF ($manufacturerId == 0x0038) { MSG ("Manufacturer: Home Director"); }
    ELSEIF ($manufacturerId == 0x0070) { MSG ("Manufacturer: Homemanageables, Inc."); }
    ELSEIF ($manufacturerId == 0x0050) { MSG ("Manufacturer: Homepro"); }
    ELSEIF ($manufacturerId == 0x0162) { MSG ("Manufacturer: HomeScenario"); }
    ELSEIF ($manufacturerId == 0x000C) { MSG ("Manufacturer: HomeSeer Technologies"); }
    ELSEIF ($manufacturerId == 0x023D) { MSG ("Manufacturer: Honest Technology Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0039) { MSG ("Manufacturer: Honeywell"); }
    ELSEIF ($manufacturerId == 0x0059) { MSG ("Manufacturer: Horstmann Controls Limited"); }
    ELSEIF ($manufacturerId == 0x0221) { MSG ("Manufacturer: HOSEOTELNET"); }
    ELSEIF ($manufacturerId == 0x0180) { MSG ("Manufacturer: Huapin Information Technology Co.,Ltd"); }
    ELSEIF ($manufacturerId == 0x024B) { MSG ("Manufacturer: Huawei Technologies Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x007C) { MSG ("Manufacturer: Hunter Douglas"); }
    ELSEIF ($manufacturerId == 0x0218) { MSG ("Manufacturer: iAutomade Pte Ltd"); }
    ELSEIF ($manufacturerId == 0x0011) { MSG ("Manufacturer: iCOM Technology b.v."); }
    ELSEIF ($manufacturerId == 0x0106) { MSG ("Manufacturer: iControl"); }
    ELSEIF ($manufacturerId == 0x0106) { MSG ("Manufacturer: Icontrol Networks"); }
    ELSEIF ($manufacturerId == 0x0165) { MSG ("Manufacturer: ID-RF"); }
    ELSEIF ($manufacturerId == 0x019E) { MSG ("Manufacturer: iEXERGY GmbH"); }
    ELSEIF ($manufacturerId == 0x0056) { MSG ("Manufacturer: Impact Technologies and Products"); }
    ELSEIF ($manufacturerId == 0x0061) { MSG ("Manufacturer: Impact Technologies BV"); }
    ELSEIF ($manufacturerId == 0x012B) { MSG ("Manufacturer: Infusion Development"); }
    ELSEIF ($manufacturerId == 0x006C) { MSG ("Manufacturer: Ingersoll Rand (Schlage)"); }
    ELSEIF ($manufacturerId == 0x011F) { MSG ("Manufacturer: Ingersoll Rand (was Ecolink)"); }
    ELSEIF ($manufacturerId == 0x0256) { MSG ("Manufacturer: Inkel Corp."); }
    ELSEIF ($manufacturerId == 0x003A) { MSG ("Manufacturer: Inlon Srl"); }
    ELSEIF ($manufacturerId == 0x0141) { MSG ("Manufacturer: Innoband Technologies, Inc"); }
    ELSEIF ($manufacturerId == 0x0077) { MSG ("Manufacturer: INNOVUS"); }
    ELSEIF ($manufacturerId == 0x0100) { MSG ("Manufacturer: Insignia"); }
    ELSEIF ($manufacturerId == 0x0006) { MSG ("Manufacturer: Intel"); }
    ELSEIF ($manufacturerId == 0x001C) { MSG ("Manufacturer: IntelliCon"); }
    ELSEIF ($manufacturerId == 0x0072) { MSG ("Manufacturer: Interactive Electronics Systems (IES)"); }
    ELSEIF ($manufacturerId == 0x0005) { MSG ("Manufacturer: Intermatic"); }
    ELSEIF ($manufacturerId == 0x0013) { MSG ("Manufacturer: Internet Dom"); }
    ELSEIF ($manufacturerId == 0x005F) { MSG ("Manufacturer: IQ-Group"); }
    ELSEIF ($manufacturerId == 0x0212) { MSG ("Manufacturer: iRevo"); }
    ELSEIF ($manufacturerId == 0x0253) { MSG ("Manufacturer: iungo.nl B.V."); }
    ELSEIF ($manufacturerId == 0x0123) { MSG ("Manufacturer: IWATSU"); }
    ELSEIF ($manufacturerId == 0x0063) { MSG ("Manufacturer: Jasco Products"); }
    ELSEIF ($manufacturerId == 0x015A) { MSG ("Manufacturer: Jin Tao Bao"); }
    ELSEIF ($manufacturerId == 0x0164) { MSG ("Manufacturer: JSW Pacific Corporation"); }
    ELSEIF ($manufacturerId == 0x0214) { MSG ("Manufacturer: Kaipule Technology Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0091) { MSG ("Manufacturer: Kamstrup A/S"); }
    ELSEIF ($manufacturerId == 0x006A) { MSG ("Manufacturer: Kellendonk Elektronik"); }
    ELSEIF ($manufacturerId == 0x0114) { MSG ("Manufacturer: Kichler"); }
    ELSEIF ($manufacturerId == 0x0174) { MSG ("Manufacturer: Kopera Development Inc."); }
    ELSEIF ($manufacturerId == 0x023A) { MSG ("Manufacturer: KUMHO ELECTRIC, INC"); }
    ELSEIF ($manufacturerId == 0x0051) { MSG ("Manufacturer: Lagotek Corporation"); }
    ELSEIF ($manufacturerId == 0x0173) { MSG ("Manufacturer: Leak Intelligence, LLC"); }
    ELSEIF ($manufacturerId == 0x0187) { MSG ("Manufacturer: LEVION Technologies Gmbh"); }
    ELSEIF ($manufacturerId == 0x001D) { MSG ("Manufacturer: Leviton"); }
    ELSEIF ($manufacturerId == 0x0015) { MSG ("Manufacturer: Lexel"); }
    ELSEIF ($manufacturerId == 0x015B) { MSG ("Manufacturer: LG Electronics"); }
    ELSEIF ($manufacturerId == 0x0224) { MSG ("Manufacturer: LifeShield, LLC"); }
    ELSEIF ($manufacturerId == 0x003C) { MSG ("Manufacturer: Lifestyle Networks"); }
    ELSEIF ($manufacturerId == 0x0210) { MSG ("Manufacturer: Light Engine Limited"); }
    ELSEIF ($manufacturerId == 0x014F) { MSG ("Manufacturer: Linear Corp"); }
    ELSEIF ($manufacturerId == 0x017A) { MSG ("Manufacturer: Liveguard Ltd."); }
    ELSEIF ($manufacturerId == 0x013A) { MSG ("Manufacturer: Living Style Enterprises, Ltd."); }
    ELSEIF ($manufacturerId == 0x015E) { MSG ("Manufacturer: Locstar Technology Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x007F) { MSG ("Manufacturer: Logitech"); }
    ELSEIF ($manufacturerId == 0x0025) { MSG ("Manufacturer: Loudwater Technologies, LLC"); }
    ELSEIF ($manufacturerId == 0x0071) { MSG ("Manufacturer: LS Control"); }
    ELSEIF ($manufacturerId == 0x0062) { MSG ("Manufacturer: LVI Produkter AB"); }
    ELSEIF ($manufacturerId == 0x0192) { MSG ("Manufacturer: m2m Solution"); }
    ELSEIF ($manufacturerId == 0x0195) { MSG ("Manufacturer: M2M Solution"); }
    ELSEIF ($manufacturerId == 0x006E) { MSG ("Manufacturer: Manodo / KTC"); }
    ELSEIF ($manufacturerId == 0x003D) { MSG ("Manufacturer: Marmitek BV"); }
    ELSEIF ($manufacturerId == 0x003E) { MSG ("Manufacturer: Martec Access Products"); }
    ELSEIF ($manufacturerId == 0x0092) { MSG ("Manufacturer: Martin Renz GmbH"); }
    ELSEIF ($manufacturerId == 0x008F) { MSG ("Manufacturer: MB Turn Key Design"); }
    ELSEIF ($manufacturerId == 0x015F) { MSG ("Manufacturer: McoHome Technology Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x0222) { MSG ("Manufacturer: MCT CO., LTD"); }
    ELSEIF ($manufacturerId == 0x0027) { MSG ("Manufacturer: Meedio, LLC"); }
    ELSEIF ($manufacturerId == 0x0107) { MSG ("Manufacturer: MegaChips"); }
    ELSEIF ($manufacturerId == 0x022D) { MSG ("Manufacturer: Mercury Corporation"); }
    ELSEIF ($manufacturerId == 0x007A) { MSG ("Manufacturer: Merten"); }
    ELSEIF ($manufacturerId == 0x0238) { MSG ("Manufacturer: Milanity, Inc."); }
    ELSEIF ($manufacturerId == 0x0112) { MSG ("Manufacturer: MITSUMI"); }
    ELSEIF ($manufacturerId == 0x019D) { MSG ("Manufacturer: MOBILUS MOTOR Spolka z o.o. "); }
    ELSEIF ($manufacturerId == 0x0232) { MSG ("Manufacturer: MODACOM CO., LTD."); }
    ELSEIF ($manufacturerId == 0x008D) { MSG ("Manufacturer: Modstroem"); }
    ELSEIF ($manufacturerId == 0x000E) { MSG ("Manufacturer: Mohito Networks"); }
    ELSEIF ($manufacturerId == 0x0202) { MSG ("Manufacturer: Monoprice"); }
    ELSEIF ($manufacturerId == 0x007E) { MSG ("Manufacturer: Monster Cable"); }
    ELSEIF ($manufacturerId == 0x0125) { MSG ("Manufacturer: Motion Control Systems"); }
    ELSEIF ($manufacturerId == 0x003F) { MSG ("Manufacturer: Motorola"); }
    ELSEIF ($manufacturerId == 0x0122) { MSG ("Manufacturer: MSK - Miyakawa Seisakusho"); }
    ELSEIF ($manufacturerId == 0x0083) { MSG ("Manufacturer: MTC Maintronic Germany"); }
    ELSEIF ($manufacturerId == 0x0143) { MSG ("Manufacturer: myStrom"); }
    ELSEIF ($manufacturerId == 0x016E) { MSG ("Manufacturer: Nanjing Easthouse Electrical Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0121) { MSG ("Manufacturer: Napco Security Technologies, Inc."); }
    ELSEIF ($manufacturerId == 0x006D) { MSG ("Manufacturer: Nefit"); }
    ELSEIF ($manufacturerId == 0x0189) { MSG ("Manufacturer: Ness Corporation Pty Ltd"); }
    ELSEIF ($manufacturerId == 0x0133) { MSG ("Manufacturer: Netgear"); }
    ELSEIF ($manufacturerId == 0x0203) { MSG ("Manufacturer: Newland Communication Science Technology Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0178) { MSG ("Manufacturer: Nexia Home Intelligence"); }
    ELSEIF ($manufacturerId == 0x0075) { MSG ("Manufacturer: NextEnergy"); }
    ELSEIF ($manufacturerId == 0x0185) { MSG ("Manufacturer: Ningbo Sentek Electronics Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x0252) { MSG ("Manufacturer: North China University of Technology"); }
    ELSEIF ($manufacturerId == 0x0096) { MSG ("Manufacturer: NorthQ"); }
    ELSEIF ($manufacturerId == 0x0040) { MSG ("Manufacturer: Novar Electrical Devices and Systems (EDS)"); }
    ELSEIF ($manufacturerId == 0x020D) { MSG ("Manufacturer: Novateqni HK Ltd"); }
    ELSEIF ($manufacturerId == 0x0119) { MSG ("Manufacturer: Omnima Limited"); }
    ELSEIF ($manufacturerId == 0x014C) { MSG ("Manufacturer: OnSite Pro"); }
    ELSEIF ($manufacturerId == 0x0041) { MSG ("Manufacturer: OpenPeak Inc."); }
    ELSEIF ($manufacturerId == 0x0104) { MSG ("Manufacturer: Panasonic Electric Works Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0257) { MSG ("Manufacturer: PARATECH"); }
    ELSEIF ($manufacturerId == 0x0172) { MSG ("Manufacturer: PassivSystems Limited"); }
    ELSEIF ($manufacturerId == 0x013D) { MSG ("Manufacturer: Pella"); }
    ELSEIF ($manufacturerId == 0x013D) { MSG ("Manufacturer: Pella"); }
    ELSEIF ($manufacturerId == 0x0245) { MSG ("Manufacturer: permundo GmbH"); }
    ELSEIF ($manufacturerId == 0x013C) { MSG ("Manufacturer: Philio Technology Corp"); }
    ELSEIF ($manufacturerId == 0x0150) { MSG ("Manufacturer: Physical Graph Corporation"); }
    ELSEIF ($manufacturerId == 0x007B) { MSG ("Manufacturer: PiTech"); }
    ELSEIF ($manufacturerId == 0x010E) { MSG ("Manufacturer: Poly-control"); }
    ELSEIF ($manufacturerId == 0x0154) { MSG ("Manufacturer: Popp & Co"); }
    ELSEIF ($manufacturerId == 0x0170) { MSG ("Manufacturer: Powerhouse Dynamics"); }
    ELSEIF ($manufacturerId == 0x0074) { MSG ("Manufacturer: PowerLinx"); }
    ELSEIF ($manufacturerId == 0x0016) { MSG ("Manufacturer: PowerLynx"); }
    ELSEIF ($manufacturerId == 0x0042) { MSG ("Manufacturer: Pragmatic Consulting Inc."); }
    ELSEIF ($manufacturerId == 0x0128) { MSG ("Manufacturer: Prodrive Technologies"); }
    ELSEIF ($manufacturerId == 0x0161) { MSG ("Manufacturer: Promixis, LLC"); }
    ELSEIF ($manufacturerId == 0x005D) { MSG ("Manufacturer: Pulse Technologies (Aspalis)"); }
    ELSEIF ($manufacturerId == 0x0095) { MSG ("Manufacturer: Qees"); }
    ELSEIF ($manufacturerId == 0x012A) { MSG ("Manufacturer: Qolsys"); }
    ELSEIF ($manufacturerId == 0x0130) { MSG ("Manufacturer: Quby"); }
    ELSEIF ($manufacturerId == 0x0163) { MSG ("Manufacturer: Queenlock Ind. Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0142) { MSG ("Manufacturer: Rademacher Geraete-Elektronik GmbH & Co. KG"); }
    ELSEIF ($manufacturerId == 0x0098) { MSG ("Manufacturer: Radio Thermostat Company of America (RTC)"); }
    ELSEIF ($manufacturerId == 0x008E) { MSG ("Manufacturer: Raritan"); }
    ELSEIF ($manufacturerId == 0x021E) { MSG ("Manufacturer: Red Bee Co. Ltd"); }
    ELSEIF ($manufacturerId == 0x0064) { MSG ("Manufacturer: Reitz-Group.de"); }
    ELSEIF ($manufacturerId == 0x022C) { MSG ("Manufacturer: Remote Solution"); }
    ELSEIF ($manufacturerId == 0x5254) { MSG ("Manufacturer: Remotec"); }
    ELSEIF ($manufacturerId == 0x0010) { MSG ("Manufacturer: Residential Control Systems, Inc. (RCS)"); }
    ELSEIF ($manufacturerId == 0x0216) { MSG ("Manufacturer: RET Nanjing Intelligence System CO.,Ltd"); }
    ELSEIF ($manufacturerId == 0x0153) { MSG ("Manufacturer: Revolv Inc"); }
    ELSEIF ($manufacturerId == 0x0147) { MSG ("Manufacturer: R-import Ltd."); }
    ELSEIF ($manufacturerId == 0x023B) { MSG ("Manufacturer: ROC-Connect, Inc."); }
    ELSEIF ($manufacturerId == 0x0197) { MSG ("Manufacturer: RPE Ajax LLC (dbs Secur Ltd)"); }
    ELSEIF ($manufacturerId == 0x0065) { MSG ("Manufacturer: RS Scene Automation"); }
    ELSEIF ($manufacturerId == 0x023C) { MSG ("Manufacturer: SafeTech Products"); }
    ELSEIF ($manufacturerId == 0x0201) { MSG ("Manufacturer: Samsung Electronics Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x022E) { MSG ("Manufacturer: Samsung SDS"); }
    ELSEIF ($manufacturerId == 0x0093) { MSG ("Manufacturer: San Shih Electrical Enterprise Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x012C) { MSG ("Manufacturer: SANAV"); }
    ELSEIF ($manufacturerId == 0x001F) { MSG ("Manufacturer: Scientia Technologies, Inc."); }
    ELSEIF ($manufacturerId == 0x011E) { MSG ("Manufacturer: Secure Wireless"); }
    ELSEIF ($manufacturerId == 0x0167) { MSG ("Manufacturer: SecureNet Technologies"); }
    ELSEIF ($manufacturerId == 0x0182) { MSG ("Manufacturer: Securifi Ltd."); }
    ELSEIF ($manufacturerId == 0x0069) { MSG ("Manufacturer: Seluxit"); }
    ELSEIF ($manufacturerId == 0x0043) { MSG ("Manufacturer: Senmatic A/S"); }
    ELSEIF ($manufacturerId == 0x019A) { MSG ("Manufacturer: Sensative AB"); }
    ELSEIF ($manufacturerId == 0x0044) { MSG ("Manufacturer: Sequoia Technology LTD"); }
    ELSEIF ($manufacturerId == 0x0151) { MSG ("Manufacturer: Sercomm Corp"); }
    ELSEIF ($manufacturerId == 0x0215) { MSG ("Manufacturer: Shangdong Smart Life Data System Co.,Ltd"); }
    ELSEIF ($manufacturerId == 0x023E) { MSG ("Manufacturer: Shanghai Dorlink Intelligent Technologies Co.,Ltd"); }
    ELSEIF ($manufacturerId == 0x0205) { MSG ("Manufacturer: Shanghai Longchuang Eco-energy Systems Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x010B) { MSG ("Manufacturer: Sharp"); }
    ELSEIF ($manufacturerId == 0x021A) { MSG ("Manufacturer: SHENZHEN AOYA INDUSTRY CO. LTD"); }
    ELSEIF ($manufacturerId == 0x021C) { MSG ("Manufacturer: Shenzhen iSurpass Technology Co. ,Ltd"); }
    ELSEIF ($manufacturerId == 0x021D) { MSG ("Manufacturer: Shenzhen Kaadas Intelligent Technology Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x0211) { MSG ("Manufacturer: Shenzhen Liao Wang Tong Da Technology Ltd"); }
    ELSEIF ($manufacturerId == 0x0258) { MSG ("Manufacturer: Shenzhen Neo Electronics Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x0250) { MSG ("Manufacturer: Shenzhen Tripath Digital Audio Equipment Co.,Ltd"); }
    ELSEIF ($manufacturerId == 0x0081) { MSG ("Manufacturer: SIEGENIA-AUBI KG"); }
    ELSEIF ($manufacturerId == 0x0000) { MSG ("Manufacturer: Silicon Labs"); }
    ELSEIF ($manufacturerId == 0x0045) { MSG ("Manufacturer: Sine Wireless"); }
    ELSEIF ($manufacturerId == 0x0046) { MSG ("Manufacturer: Smart Products, Inc."); }
    ELSEIF ($manufacturerId == 0x024F) { MSG ("Manufacturer: Smartly AS"); }
    ELSEIF ($manufacturerId == 0x0102) { MSG ("Manufacturer: SMK Manufacturing Inc."); }
    ELSEIF ($manufacturerId == 0x0047) { MSG ("Manufacturer: Somfy"); }
    ELSEIF ($manufacturerId == 0x0254) { MSG ("Manufacturer: Spectrum Brands"); }
    ELSEIF ($manufacturerId == 0x0124) { MSG ("Manufacturer: Square Connect"); }
    ELSEIF ($manufacturerId == 0x021B) { MSG ("Manufacturer: ST&T Electric Corporation"); }
    ELSEIF ($manufacturerId == 0x0259) { MSG ("Manufacturer: Starkoff"); }
    ELSEIF ($manufacturerId == 0x0239) { MSG ("Manufacturer: Stelpro"); }
    ELSEIF ($manufacturerId == 0x0217) { MSG ("Manufacturer: Strattec Advanced Logic,LLC"); }
    ELSEIF ($manufacturerId == 0x0168) { MSG ("Manufacturer: STRATTEC Security Corporation"); }
    ELSEIF ($manufacturerId == 0x0105) { MSG ("Manufacturer: Sumitomo"); }
    ELSEIF ($manufacturerId == 0x0054) { MSG ("Manufacturer: Superna"); }
    ELSEIF ($manufacturerId == 0x0191) { MSG ("Manufacturer: Swann Communications Pty Ltd"); }
    ELSEIF ($manufacturerId == 0x0009) { MSG ("Manufacturer: Sylvania"); }
    ELSEIF ($manufacturerId == 0x0136) { MSG ("Manufacturer: Systech Corporation"); }
    ELSEIF ($manufacturerId == 0x0235) { MSG ("Manufacturer: TAEWON Lighting Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0186) { MSG ("Manufacturer: Team Digital Limited"); }
    ELSEIF ($manufacturerId == 0x0089) { MSG ("Manufacturer: Team Precision PCL"); }
    ELSEIF ($manufacturerId == 0x0240) { MSG ("Manufacturer: Technicolor"); }
    ELSEIF ($manufacturerId == 0x000A) { MSG ("Manufacturer: Techniku"); }
    ELSEIF ($manufacturerId == 0x012F) { MSG ("Manufacturer: Tecom Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x0012) { MSG ("Manufacturer: Tell It Online"); }
    ELSEIF ($manufacturerId == 0x0176) { MSG ("Manufacturer: Telldus Technologies AB"); }
    ELSEIF ($manufacturerId == 0x0048) { MSG ("Manufacturer: Telsey"); }
    ELSEIF ($manufacturerId == 0x017E) { MSG ("Manufacturer: Telular"); }
    ELSEIF ($manufacturerId == 0x005C) { MSG ("Manufacturer: Terra Optima B.V. (tidligere Primair Services)"); }
    ELSEIF ($manufacturerId == 0x010C) { MSG ("Manufacturer: There Corporation"); }
    ELSEIF ($manufacturerId == 0x019B) { MSG ("Manufacturer: ThermoFloor"); }
    ELSEIF ($manufacturerId == 0x022A) { MSG ("Manufacturer: TIMEVALVE, Inc."); }
    ELSEIF ($manufacturerId == 0x0118) { MSG ("Manufacturer: TKB Home"); }
    ELSEIF ($manufacturerId == 0x011C) { MSG ("Manufacturer: TKH Group / Eminent"); }
    ELSEIF ($manufacturerId == 0x008B) { MSG ("Manufacturer: Trane Corporation"); }
    ELSEIF ($manufacturerId == 0x0066) { MSG ("Manufacturer: TrickleStar"); }
    ELSEIF ($manufacturerId == 0x006B) { MSG ("Manufacturer: Tricklestar Ltd. (former Empower Controls Ltd.)"); }
    ELSEIF ($manufacturerId == 0x0055) { MSG ("Manufacturer: Tridium"); }
    ELSEIF ($manufacturerId == 0x0049) { MSG ("Manufacturer: Twisthink"); }
    ELSEIF ($manufacturerId == 0x0152) { MSG ("Manufacturer: UFairy G.R. Tech"); }
    ELSEIF ($manufacturerId == 0x0193) { MSG ("Manufacturer: Universal Devices, Inc"); }
    ELSEIF ($manufacturerId == 0x0020) { MSG ("Manufacturer: Universal Electronics Inc."); }
    ELSEIF ($manufacturerId == 0x0183) { MSG ("Manufacturer: Universe Future"); }
    ELSEIF ($manufacturerId == 0x0209) { MSG ("Manufacturer: UTC Fire and Security Americas Corp"); }
    ELSEIF ($manufacturerId == 0x010A) { MSG ("Manufacturer: VDA"); }
    ELSEIF ($manufacturerId == 0x0198) { MSG ("Manufacturer: Venstar Inc."); }
    ELSEIF ($manufacturerId == 0x008C) { MSG ("Manufacturer: Vera Control"); }
    ELSEIF ($manufacturerId == 0x0080) { MSG ("Manufacturer: Vero Duco"); }
    ELSEIF ($manufacturerId == 0x0237) { MSG ("Manufacturer: Vestel Elektronik Ticaret ve Sanayi A.S. "); }
    ELSEIF ($manufacturerId == 0x0053) { MSG ("Manufacturer: Viewsonic"); }
    ELSEIF ($manufacturerId == 0x005E) { MSG ("Manufacturer: ViewSonic Corporation"); }
    ELSEIF ($manufacturerId == 0x0007) { MSG ("Manufacturer: Vimar CRS"); }
    ELSEIF ($manufacturerId == 0x0188) { MSG ("Manufacturer: Vipa-Star"); }
    ELSEIF ($manufacturerId == 0x0109) { MSG ("Manufacturer: Vision Security"); }
    ELSEIF ($manufacturerId == 0x004A) { MSG ("Manufacturer: Visualize"); }
    ELSEIF ($manufacturerId == 0x0058) { MSG ("Manufacturer: Vitelec"); }
    ELSEIF ($manufacturerId == 0x0156) { MSG ("Manufacturer: Vivint"); }
    ELSEIF ($manufacturerId == 0x017B) { MSG ("Manufacturer: Vs-Safety AS"); }
    ELSEIF ($manufacturerId == 0x004B) { MSG ("Manufacturer: Watt Stopper"); }
    ELSEIF ($manufacturerId == 0x0008) { MSG ("Manufacturer: Wayne Dalton"); }
    ELSEIF ($manufacturerId == 0x019F) { MSG ("Manufacturer: Webee Life"); }
    ELSEIF ($manufacturerId == 0x0171) { MSG ("Manufacturer: WeBeHome AB"); }
    ELSEIF ($manufacturerId == 0x011A) { MSG ("Manufacturer: Wenzhou MTLC Electric Appliances Co.,Ltd."); }
    ELSEIF ($manufacturerId == 0x0057) { MSG ("Manufacturer: Whirlpool"); }
    ELSEIF ($manufacturerId == 0x0149) { MSG ("Manufacturer: wiDom"); }
    ELSEIF ($manufacturerId == 0x015D) { MSG ("Manufacturer: Willis Electric Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x012D) { MSG ("Manufacturer: Wilshine Holding Co., Ltd"); }
    ELSEIF ($manufacturerId == 0x017F) { MSG ("Manufacturer: Wink Inc."); }
    ELSEIF ($manufacturerId == 0x0097) { MSG ("Manufacturer: Wintop"); }
    ELSEIF ($manufacturerId == 0x0242) { MSG ("Manufacturer: Winytechnology"); }
    ELSEIF ($manufacturerId == 0x0199) { MSG ("Manufacturer: Wireless Maingate AB"); }
    ELSEIF ($manufacturerId == 0x004C) { MSG ("Manufacturer: Woodward Labs"); }
    ELSEIF ($manufacturerId == 0x0003) { MSG ("Manufacturer: Wr@p"); }
    ELSEIF ($manufacturerId == 0x022F) { MSG ("Manufacturer: WRT Intelligent Technology CO., LTD."); }
    ELSEIF ($manufacturerId == 0x012E) { MSG ("Manufacturer: Wuhan NWD Technology Co., Ltd."); }
    ELSEIF ($manufacturerId == 0x004D) { MSG ("Manufacturer: Xanboo"); }
    ELSEIF ($manufacturerId == 0x004E) { MSG ("Manufacturer: Zdata, LLC."); }
    ELSEIF ($manufacturerId == 0x016F) { MSG ("Manufacturer: Zhejiang Jiuxing Electric Co Ltd"); }
    ELSEIF ($manufacturerId == 0x0139) { MSG ("Manufacturer: Zhome"); }
    ELSEIF ($manufacturerId == 0x0131) { MSG ("Manufacturer: Zipato"); }
    ELSEIF ($manufacturerId == 0x0120) { MSG ("Manufacturer: Zonoff"); }
    ELSEIF ($manufacturerId == 0x004F) { MSG ("Manufacturer: Z-Wave Technologia"); }
    ELSEIF ($manufacturerId == 0x0115) { MSG ("Manufacturer: Z-Wave.Me"); }
    ELSEIF ($manufacturerId == 0x024D) { MSG ("Manufacturer: Z-works Inc."); }
    ELSEIF ($manufacturerId == 0x0021) { MSG ("Manufacturer: Zykronix"); }
    ELSEIF ($manufacturerId == 0x0135) { MSG ("Manufacturer: ZyXEL"); }

    MSG ("Manufacturer ID: {0:X4}", UINT($manufacturerId));
    MSG ("Product Type ID: {0:X4}", UINT($productTypeId));
    MSG ("Product ID:      {0:X4}", UINT($productId));

TESTSEQ END


/**
 * DeviceSpecific
 * Verifies the return values of Device Specific Get Command
 *
 * CC versions: 2
 */

TESTSEQ DeviceSpecific: "Check for support of Device Specific Get and Report (V2)"

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

    MSG ("Return OEM factory default Device ID Type");
    SEND ManufacturerSpecific.DeviceSpecificGet(
        DeviceIdType = 0,
        Reserved = 0);
    EXPECT ManufacturerSpecific.DeviceSpecificReport(
        $devIdType = DeviceIdType in (1, 2),
        Reserved == 0,
        $deviceIdDataLengthIndicator = DeviceIdDataLengthIndicator in (0x01 ... 0x1F),
        $deviceIdDataFormat = DeviceIdDataFormat in (0, 1),
        $deviceIdData = DeviceIdData);

    // validate reported values
    IF ($devIdType == 0)
    {
        MSGFAIL ("DUT returns default DeviceIdType 0x{0:X2}. This is not allowed, either Serial Number or Pseudo Random must be returned if the default Device ID Type 0 is requested.", $devIdType);
    }
    ELSEIF ($devIdType == 1)
    {
        MSGPASS ("DUT returns default DeviceIdType 0x{0:X2} - Serial Number", $devIdType);
    }
    ELSEIF ($devIdType == 2)
    {
        MSGPASS ("DUT returns default DeviceIdType 0x{0:X2} - Pseudo Random", $devIdType);
    }

    IF ($deviceIdDataLengthIndicator == 0)
    {
        MSGFAIL ("Device ID Data Length Indicator {0} must not be 0.", UINT($deviceIdDataLengthIndicator));
    }
    IF ($deviceIdDataLengthIndicator != LENGTH($deviceIdData))
    {
        MSGFAIL ("Device ID Data Length Indicator {0} has to report the count of Device ID Data fields {1}",
            UINT($deviceIdDataLengthIndicator), LENGTH($deviceIdData));
    }

    IF     ($deviceIdDataFormat == 0) { MSGPASS ("Device ID Data Format: 0x{0:X2} = UTF-8", $deviceIdDataFormat); }
    ELSEIF ($deviceIdDataFormat == 1) { MSGPASS ("Device ID Data Format: 0x{0:X2} = plain binary", $deviceIdDataFormat); }
    ELSE                              { MSGFAIL ("Device ID Data Format: 0x{0:X2}. Values 2-7 are reserved", $deviceIdDataFormat); }

    MSGPASS ("Device ID Data: {0}", $deviceIdData);

    // Not answering this request is allowed if the 'Pseudo Random Number' Device Type has been implemented.
    MSG ("Try to get report for Serial Number...");
    SEND ManufacturerSpecific.DeviceSpecificGet(
        DeviceIdType = 1,
        Reserved = 0);
    EXPECTOPT ManufacturerSpecific.DeviceSpecificReport(
        DeviceIdType in (1, 2),
        Reserved == 0,
        $deviceIdDataLengthIndicator1 = DeviceIdDataLengthIndicator in (0x01 ... 0x1F),
        $deviceIdDataFormat = DeviceIdDataFormat in (0, 1),
        $deviceIdData = DeviceIdData);

    IF (ISNULL($deviceIdDataLengthIndicator1))
    {
        MSG ("DUT sends no Device Specific Report for Serial Number. This is allowed if the Pseudo Random Number Device Type has been implemented.");
    }
    ELSE
    {
        IF ($deviceIdDataLengthIndicator1 == 0)
        {
            MSGFAIL ("Device ID Data Length Indicator {0} must not be 0.", UINT($deviceIdDataLengthIndicator1));
        }
        IF ($deviceIdDataLengthIndicator1 != LENGTH($deviceIdData))
        {
            MSGFAIL ("Device ID Data Length Indicator {0} has to report the count of Device ID Data fields {1}",
                UINT($deviceIdDataLengthIndicator1), LENGTH($deviceIdData));
        }

        IF     ($deviceIdDataFormat == 0) { MSGPASS ("Device ID Data Format: {0:X2} = UTF-8", $deviceIdDataFormat); }
        ELSEIF ($deviceIdDataFormat == 1) { MSGPASS ("Device ID Data Format: {0:X2} = plain binary", $deviceIdDataFormat); }
        ELSE                              { MSGFAIL ("Device ID Data Format: {0:X2}. Values 2-7 are reserved", $deviceIdDataFormat); }

        MSGPASS ("Device ID Data: {0}", $deviceIdData);
    }

    // Not answering this request is allowed if the 'Serial Number' Device Type has been implemented.
    MSG ("Try to get report for Pseudo Random Number...");
    SEND ManufacturerSpecific.DeviceSpecificGet(
        DeviceIdType = 2,
        Reserved = 0);
    EXPECTOPT ManufacturerSpecific.DeviceSpecificReport(
        DeviceIdType in (1,2),
        Reserved == 0,
        $deviceIdDataLengthIndicator2 = DeviceIdDataLengthIndicator in (0x01 ... 0x1F),
        $deviceIdDataFormat = DeviceIdDataFormat in (0, 1),
        $deviceIdData = DeviceIdData);

    IF (ISNULL($deviceIdDataLengthIndicator2))
    {
        MSG ("DUT sends no Device Specific Report for Pseudo Random Number. This is allowed if the Serial Number Device Type has been implemented.");
    }
    ELSE
    {
        IF ($deviceIdDataLengthIndicator2 == 0)
        {
            MSGFAIL ("Device ID Data Length Indicator {0} must not be 0.", UINT($deviceIdDataLengthIndicator2));
        }
        IF ($deviceIdDataLengthIndicator2 != LENGTH($deviceIdData))
        {
            MSGFAIL ("Device ID Data Length Indicator {0} has to report the count of Device ID Data fields {1}",
                UINT($deviceIdDataLengthIndicator2), LENGTH($deviceIdData));
        }

        IF     ($deviceIdDataFormat == 0) { MSGPASS ("Device ID Data Format: {0:X2} = UTF-8", $deviceIdDataFormat); }
        ELSEIF ($deviceIdDataFormat == 1) { MSGPASS ("Device ID Data Format: {0:X2} = plain binary", $deviceIdDataFormat); }
        ELSE                              { MSGFAIL ("Device ID Data Format: {0:X2}. Values 2-7 are reserved", $deviceIdDataFormat); }

        MSGPASS ("Device ID Data: {0}", $deviceIdData);
    }

    // one of the reports MUST come in
    IF ( (ISNULL($deviceIdDataLengthIndicator1)) && (ISNULL($deviceIdDataLengthIndicator2)) )
    {
        MSGFAIL ("DUT sends Device Specific Report neither 'Pseudo Random Number' nor 'Serial Number'. This is not allowed.");
    }

    MSG ("Finished.");

TESTSEQ END

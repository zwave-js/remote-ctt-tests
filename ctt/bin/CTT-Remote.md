# CTT-WS

The CTT-WS App is a console application which provides a WebSocket interface for the integration into an automated test system.

## Overview

The application is designed to work with a single predefined project only, which is passed by command line parameter on startup. Once this project has been loaded, there is no opportunity to switch between projects.

Controlling the CTT is done by executing Tasks via a WebSocket-based JSON RPC interface. In order to receive such Tasks, a WebSocket server is spawned by the CTT, whereas a second WebSocket connection will be established to the controlling unit to handle asynchronous events and long-lasting operations feedback.

## JSON RPC format

In the context of CTT (Certified Test Tool), the JSON-RPC format is used to facilitate remote procedure calls (RPC) over a network. JSON-RPC is a lightweight remote procedure call protocol encoded in JSON. It allows for the execution of methods on a remote server and the retrieval of results.

### JSON-RPC Request Format

A JSON-RPC request consists of the following fields:

- jsonrpc: A string specifying the version of the JSON-RPC protocol. For JSON-RPC 2.0, this value is "2.0".
- method: A string containing the name of the method to be invoked.
- params: An array or object containing the parameters to be passed to the method. This field is optional.
- id: A unique identifier for the request. This can be a string, number, or null. It is used to match the response with the request.

### Example

**Request:**

```
{
  "jsonrpc": "2.0",
  "method": "addNode",
  "params": {pin:"1234"},
  "id": 2
}
```

**Response:**

```
{
  "jsonrpc": "2.0",
  "result": "Running",
  "id": 2
}
```

**addNodeDone**

```
{
  "jsonrpc":"2.0",
  "method":"addNodeDone",
  "params":{"result":"Completed"},
  "id":3
}
```

## Available Tasks (API)

### Z-Wave Network (classic):

| Task (operation)    | Params      | Response(s) immediately                             | Response Method asynchronously | Response(s) asynchronously                                                                                    | Description                                                                |
| ------------------- | ----------- | --------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| **resetController** | -           | [MethodStatusResults](#methodstatusresults).Running | **resetControllerDone**        | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Resets the CTT controller.                                                 |
| **removeNode**      | -           | [MethodStatusResults](#methodstatusresults).Running | **removeNodeDone**             | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Removes a node from the network. Please start Exclusion of the DUT.        |
| **addNode**         | pin:"XXXXX" | [MethodStatusResults](#methodstatusresults).Running | **addNodeDone**                | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Adds a node to the network using a PIN. Please start Inclusion of the DUT. |
| **getNodeInfo**     | -           | [MethodStatusResults](#methodstatusresults).Running | **getNodeInfoDone**            | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Retrieves information about a node.                                        |

### Z-Wave Network (LongRange):

| Task (operation)      | Params                                                | Response(s) immediately                                                                                       | Response Method asynchronously | Response(s) asynchronously                                                                                    | Description                                                        |
| --------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| **resetControllerLR** | -                                                     | [MethodStatusResults](#methodstatusresults).Running                                                           | **resetControllerLRDone**      | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Resets the CTT controller.                                         |
| **removeNode**        | -                                                     | [MethodStatusResults](#methodstatusresults).Running                                                           | **removeNodeDone**             | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Removes a node from the network. Please start Exclusion of the DUT |
| **addNodeLR**         | dsk:"XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | -                              | -                                                                                                             | Adds a node to the network using a complete DSK.                   |
| **getNodeInfo**       | -                                                     | [MethodStatusResults](#methodstatusresults).Running                                                           | **getNodeInfoDone**            | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Retrieves information about a node.                                |

### Test Execution:

| Task (operation)        | Params                                                                                    | Response(s) immediately                                                                                       | Response Method asynchronously | Response(s) asynchronously | Description                                                    |
| ----------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------ | -------------------------- | -------------------------------------------------------------- |
| **getTestCases**        | testCaseRequestDTO: [TestCaseRequestDTO](#testcaserequestdto)                             | List<[TestCaseDTO](#testcasedto)>                                                                             | -                              | -                          | Retrieves a list of test cases based on the provided criteria. |
| **runTestCases**        | testCaseRequestDTO: [TestCaseRequestDTO](#testcaserequestdto)                             | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | -                              | -                          | Runs the specified test cases.                                 |
| **cancelTestRun**       | -                                                                                         | [MethodStatusResults](#methodstatusresults).Completed                                                         | -                              | -                          | Cancels the currently running test case.                       |
| **resetTestCaseResult** | testCaseRequestDTO: [TestCaseRequestDTO](#testcaserequestdto) <br> allowBulkReset: `bool` | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | -                              | -                          | Resets the result of the specified test case(s).               |

### Utility Methods

| Task (operation)           | Params                                                                                                 | Response(s) immediately                                                                                       | Response Method asynchronously | Response(s) asynchronously                                                                                    | Description                                                                                                                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **closeCTT**               | -                                                                                                      | [MethodStatusResults](#methodstatusresults).Running                                                           | **closeProjectDone**           | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Closes the CTT application.                                                                                                                                                              |
| **setupSerialDevices** | serialDevices: [SerialDevicesConfiguration](#SerialDevicesConfiguration) <br> configureDevices: `bool` | [MethodStatusResults](#methodstatusresults).Running                                                           | **setupSerialDevicesDone** | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | Setup the Serial Devices / IP Devices. If configureDevices is true, the CTT tries to set the RF Region (and Channel).                                                                    |
| **setQrCodeData**          | `string`                                                                                               | [MethodStatusResults](#methodstatusresults).Completed <br> [MethodStatusResults](#methodstatusresults).Failed | -                              | -                                                                                                             | Sets the QR Code data for the DUT. Data must be passed in string representation e.g. `9001331841355630622502121974938822296374250249138710001000000000000220000000000400004018100803003` |

## Events

### General Status Events

| Task (operation)     | Params                                                             | Expected Response(s) | Description                                                                                                                 |
| -------------------- | ------------------------------------------------------------------ | -------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **ProjectLoaded**    | state: [ProjectLoadedState](#projectloadedstate) <br> msg `string` | No direct response.  | Informs the controlling application whether loading the project succeeded or failed. "msg" contains an optional error text. |
| **TestCaseFinished** | [TestCaseDTO](#testcasedto)                                        | No direct response.  | States that a test run has finished. Detailed information is given by the TestCaseDTO                                       |

### Logging Methods

| Task (operation)   | Params                                                                                                                                                   | Expected Response(s)                          | Description                                                                |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | -------------------------------------------------------------------------- |
| **generalLogMsg**  | errorType: [ErrorType](#logmsgerrorType) <br> output: `string`                                                                                           | No direct response.                           | Forwards a (non-test-case) log message.                                    |
| **testCaseLogMsg** | testCase: [ExecutingTestCaseDTO](#executingtestcasedto) <br> logOutput: `string` <br> errorType: [ErrorType](#errortype)                                 | No direct response.                           | Forwards a test case log message to the frontend.                          |
| **testCaseMsgBox** | testCase: [ExecutingTestCaseDTO](#executingtestcasedto) <br> type: [TestCaseMsgBoxTypes](#testcasemsgboxtypes) <br> content: `string` <br> url: `string` | [TestCaseConfirmation](#testcaseconfirmation) | Forwards a test case message box to the frontend and waits for a response. |

## Data Transfer Objects (DTOs)

### TestCaseRequestDTO

<table>
  <tr><td>groups: <code>List&lt;<a href="#testcasegroup">TestCaseGroup</a>&gt;</code></td><td>A list of groups to which the test cases belong. Can be empty to select all.</td></tr>
  <tr><td>results: <code>List&lt;string&gt;</code> </td><td>A list of results that the test cases should have. Can be empty to select all.</td></tr>
  <tr><td>endPointIds: <code>List&lt;string&gt;</code></td><td>A list of endpoint IDs associated with the test cases. Can be empty to select all.</td></tr>
  <tr><td>testCaseNames: <code>List&lt;string&gt;</code></td><td>A list of names of the test cases. Can be empty to select all.</td></tr>
  <tr><td>ZWaveExecutionModes: <code>List&lt;<a href="#zwaveexecutionmode">ZWaveExecutionMode</a>&gt;</code></td><td>A list of Z-Wave execution modes (classic or long-range mode) to be used for the test cases. Can be empty to select all.</td></tr>
</table>

### TestCaseDTO

<table>
  <tr><td>IdGuid: <code>GUID</code></td><td><code>Internal Use</code> Unique identifier for the test case.</td></tr>
  <tr><td>Name: <code>string</code></td><td>Name of the test case.</td></tr>
  <tr><td>EndPointId: <code>GUID</code></td><td><code>Internal Use</code> GUID which points to project structures endpoint.</td></tr>
  <tr><td>EndPoint: <code>string</code></td><td>Human readable (Z-Wave device) End Point ID.</td></tr>
  <tr><td>Location: <code>string</code></td><td>Location of the test case.</td></tr>
  <tr><td>ItemType: <code>string</code></td><td><code>Internal Use</code> Type of the item.</td></tr>
  <tr><td>Category: <code>string</code></td><td>Category of the test case. (e.g. `Command Class Control Requirements`, `Application Command Classes`, ..., `TestCaseDesigner` for Script Test Cases)</td></tr>
  <tr><td>Group: <a href="#testcasegroup"><code>TestCaseGroup</code></a></td><td>Group to which the test case belongs.</td></tr>
  <tr><td>DateLastModified: <code>DateTime</code></td><td>Date and time when the test case was last modified.</td></tr>
  <tr><td>LastExecutionDateTime: <code>DateTime</code></td><td>Date and time when the test case was last executed.</td></tr>
  <tr><td>TestCaseLogPaths: <code>List&lt;string&gt;</code></td><td>List of paths to the log files for the test case.</td></tr>
  <tr><td>MissingHardware: <code>bool<code></td><td>Indicates whether the test case is missing hardware.</td></tr>
  <tr><td>FormItemReferenceDTO: <code>List&lt;<a href="#formitemreferencedto"></a>&gt;</code> FormItemReferences</td><td>List of form item references associated with the test case.</td></tr>
  <tr><td>IsLongRange: <code>bool</code></td><td>Indicates whether the test case shall be run for a Long Range device (in a Z-Wave Long Range star network).</td></tr>
  <tr><td>Result: <a href="#executionresults"><code>ExecutionResults</code></a><td><td>The general result of the Test Case.</td></tr>
</table>

### FormItemReferenceDTO

<table>
  <tr><td>FormItemNo: <code>string</code></td><td>Form item number.</td></tr>
  <tr><td>RefType: <code>string</code> </td><td>Reference type.</td></tr>
  <tr><td>ZatsResultKey: <code>string</code> </td><td>Key for the ZATS result.</td></tr>
</table>

### ExecutingTestCaseDTO

<table>
  <tr><td>TestCaseName: <code>string</code> </td><td>Name of the test case.</td></tr>
  <tr><td>Endpoint: <code>string</code></td><td> of the  End Point for which the Test Case is to be executed.</td></tr>
  <tr><td>ExecutionMode: <a href="#zwaveexecutionmode"><code>ZWaveExecutionMode</code></a> </td><td>Specifies whether the test is to be performed in Z-Wave execution modes (classic or long-range mode).</td></tr>
</table>

### SerialDevicesConfiguration

<table>
  <tr><td>Zniffer: <a href="#serialdevice"><code>SerialDevice</code></a> </td><td>Serial Device Configuration or NULL (left out) when not used.</td></tr>
  <tr><td>FirstController: <a href="#serialdevice"><code>SerialDevice</code></a> </td><td>Serial Device Configuration or NULL (left out) when not used.</td></tr>
  <tr><td>SecondController: <a href="#serialdevice"><code>SerialDevice</code></a> </td><td>Serial Device Configuration or NULL (left out) when not used.</td></tr>
  <tr><td>ThirdController: <a href="#serialdevice"><code>SerialDevice</code></a> </td><td>Serial Device Configuration or NULL (left out) when not used.</td></tr>
  <tr><td>FirstEndDevice: <a href="#serialdevice"><code>SerialDevice</code></a> </td><td>Serial Device Configuration or NULL (left out) when not used.</td></tr>
  <tr><td>SecondEndDevice: <a href="#serialdevice"><code>SerialDevice</code></a> </td><td>Serial Device Configuration or NULL (left out) when not used.</td></tr>
  <tr><td>ThirdEndDevice: <a href="#serialdevice"><code>SerialDevice</code></a> </td><td>Serial Device Configuration or NULL (left out) when not used.</td></tr>
  <tr><td>RfRegion: <a href="#rfregion"><code>RfRegion</code></a> </td><td>Z-Wave RF region</td></tr>
  <tr><td>LRChannel: <a href="#lrchannel"><code>LRChannel</code></a> </td><td>Z-Wave Long Range Channel</td></tr>
</table>

### SerialDevice

<table>
  <tr><td>DevType: <a href="#devtype"><code>DevType</code></a> </td><td>Enum DevType</td></tr>
  <tr><td>SName: <code>string</code> </td><td>Serial Port or IP Address</td></tr>
  <tr><td>SPort: <code>int or NULL</code> </td><td>TCP / UDP Port when using IP device</td></tr>
  <tr><td>SType: <a href="#interfacetypes"><code>InterfaceType</code></a> </td><td>Enum for interface type</td></tr>
  <tr><td>JName: <code>string</code> </td><td>JLink serial number or NULL</td></tr>
  <tr><td>ChipSeries: <code>string</code> </td><td>E.g. 'ZW070x' or 'ZW080x, ...'</td></tr>
  <tr><td>Library: <a href="#library"><code>Library</code></a> </td><td>E.g. 'ControllerBridgeLib'</td></tr>
  <tr><td>VersionNumbers: <code>string</code> </td><td>E.g. '7.18'</td></tr>
  <tr><td>ZnifferChipType: <code>int</code> </td><td>E.g. 5 or simply 0, if it is no Zniffer</td></tr>
  <tr><td>SnifferVersion: <code>int</code> </td><td>E.g. 10 or simply 0, if it is no Zniffer</td></tr>
  <tr><td>SnifferRevision: <code>int</code> </td><td>E.g. 23 or simply 0, if it is no Zniffer</td></tr>
</table>

## Enums

### MethodStatusResults

<table>
<tr><td>Running</td><td>The operation has been triggered successfully and will return its status asynchronously.</td></tr>
<tr><td>Completed</td><td>The operation has been completed successfully.</td></tr>
<tr><td>Failed</td><td>The operation has failed.</td></tr>
</table>

### ExecutionResults

<table>
<tr><td>NONE</td><td>Fallback value - considered as `PENDING`</td></tr>
<tr><td>PASSED</td><td>The Test Case has successfully been passed.</td></tr>
<tr><td>FAILED</td><td>The Test Case has been failed.</td></tr>
<tr><td>ABORTED</td><td>The Test Case has been aborted.</td></tr>
<tr><td>PENDING</td><td>The Test Case has no applicable result (e.g. never been running or reset)</td></tr>
<tr><td>NOTSELECTED</td><td>Used by Script Test Cases - considered as `PENDING` </td></tr>
</table>

### ZWaveExecutionMode

<table>
<tr><td>Classic</td><td>Classic Z-Wave</td></tr>
<tr><td>LongRangeStar</td><td>Z-Wave Long Range</td></tr>
</table>

### ErrorType

<table>
<tr><td>None</td><td>No error.</td></tr>
<tr><td>Error</td><td>A general error.</td></tr>
<tr><td>Warning</td><td>A warning indicating a potential issue.</td></tr>
<tr><td>Failed</td><td>Indicates that a test has failed.</td></tr>
<tr><td>Success</td><td>Indicates a successful operation.</td></tr>
</table>

### TestCaseGroup

<table>
<tr><td>Automatic</td><td></td></tr>
<tr><td>Interactive</td><td></td></tr>
<tr><td>Manual</td><td></td></tr>
<tr><td>Inclusion</td><td></td></tr>
<tr><td>Script</td><td></td></tr>
</table>

### TestCaseConfirmation

<table>
<tr><td>Ok</td><td>Indicates that the user confirmed the action with "OK".</td></tr>
<tr><td>Cancel</td><td>Indicates that the user cancelled the action.</td></tr>
<tr><td>Yes</td><td>Indicates that the user confirmed the action with "Yes".</td></tr>
<tr><td>No</td><td>Indicates that the user declined the action with "No".</td></tr>
<tr><td>Open</td><td>Indicates that the user chose to open a resource.</td></tr>
<tr><td>Skip</td><td>Indicates that the user chose to skip the current action.</td></tr>
</table>

### TestCaseMsgBoxTypes

<table>
<tr><td>OkCancel</td><td>A message box with "OK" and "Cancel" buttons.</td></tr>
<tr><td>Ok</td><td>A message box with only an "OK" button.</td></tr>
<tr><td>YesNo</td><td>A message box with "Yes" and "No" buttons.</td></tr>
<tr><td>UrlOpenCancel</td><td>A message box with an option to open a URL and a "Cancel" button.</td></tr>
<tr><td>Skip</td><td>A message box with an option to skip the current action.</td></tr>
<tr><td>WaitForDutResponse</td><td>A message box with a fixed timeout, which waits for a Z-Wave command from the DUT and cannot be skipped. <b>MUST</b> be directly confirmed by <a href="#testcaseconfirmation">TestCaseConfirmation</a>.Ok</td></tr>
<tr><td>CloseCurrentMsgBox</td><td>A message box that closes the current message box.</td></tr>
<tr><td>Yes</td><td>A message box with only a "Yes" button.</td></tr>
<tr><td>No</td><td>A message box with only a "No" button.</td></tr>
</table>

### ProjectLoadedState

<table>
<tr><td>Success</td><td>Project has been loaded successfully.</td></tr>
<tr><td>ProjectSystemVersionTooNew</td><td>The required project system version is newer than the version of the given project. The project can be updated by loading it with a common UI-based CTT.</td></tr>
<tr><td>Failed</td><td>General Error occurred - loading failed.</td></tr>
</table>

### RfRegion

<table>
<tr><td>EU</td><td></td></tr>
<tr><td>US</td><td></td></tr>
<tr><td>ANZ</td><td></td></tr>
<tr><td>HK</td><td></td></tr>
<tr><td>IN</td><td></td></tr>
<tr><td>IL</td><td></td></tr>
<tr><td>RU</td><td></td></tr>
<tr><td>CN</td><td></td></tr>
<tr><td>US_LR</td><td></td></tr>
<tr><td>EU_LR</td><td></td></tr>
<tr><td>JP</td><td></td></tr>
<tr><td>KR</td><td></td></tr>
</table>

### LRChannel

<table>
<tr><td>Undefined</td><td></td></tr>
<tr><td>ChannelA</td><td></td></tr>
<tr><td>ChannelB</td><td></td></tr>
<tr><td>ChannelAuto</td><td></td></tr>
</table>

### DevType

<table>
<tr><td>Controller</td><td></td></tr>
<tr><td>EndDevice</td><td></td></tr>
<tr><td>Zniffer</td><td></td></tr>
</table>

### InterfaceTypes

<table>
<tr><td>COM</td><td></td></tr>
<tr><td>TCP</td><td></td></tr>
</table>

### Library

<table>
<tr><td>ControllerBridgeLib</td><td></td></tr>
<tr><td>EndDeviceLib</td><td></td></tr>
<tr><td>ZnifferNCP</td><td></td></tr>
<tr><td>ZnifferPTI</td><td></td></tr>
</table>

### LogMsgErrorType

This has more or less an information character only. Obviously `Warning` or `Error` are the most significant types.

<table>
<tr><td>None</td><td></td></tr>
<tr><td>Verbose</td><td></td></tr>
<tr><td>Debug</td><td></td></tr>
<tr><td>Info</td><td></td></tr>
<tr><td>Output</td><td></td></tr>
<tr><td>Warning</td><td></td></tr>
<tr><td>Error</td><td></td></tr>
</table>


## Examples
### Run a Test Case
The following RPC call will run the `CSR_LifelineMandatoryReports_Rev03` Test Case.
```
{"jsonrpc": "2.0", "method": "runTestCases", "params": {"testCaseRequestDTO": {"groups": [], "results": [], "endPointIds": [0], "testCaseNames": ["CSR_LifelineMandatoryReports_Rev03"], "ZWaveExecutionModes": ["LongRangeStar"]}}, "id": 0}
```
While the Test is running, its log output will be forwarded asynchronously by the `testCaseLogMsg` JsonRPC method, see this example:
```
{"jsonrpc":"2.0","method":"testCaseLogMsg","params":{"testCase":{"TestCaseName":"CSR_LifelineMandatoryReports_Rev03","EndPoint":"0","ExecutionMode":"LongRangeStar"},"errorType":"None","logOutput":"{color:darkgray}09:52:06.893 {color}{color:darkgray}Test Run Started{color}\r\n"},"id":1}
```

Some Test Cases are able to interact using the `testCaseMsgBox` JsonRPC method. The following example shows a `OkCancel` type which is confirmed with `Ok`:
```
{"jsonrpc":"2.0","method":"testCaseMsgBox","params":{"testCase":{"TestCaseName":"CSR_LifelineMandatoryReports_Rev03","EndPoint":"0","ExecutionMode":"LongRangeStar"},"type":"OkCancel","content":"{color:darkgray}09:52:25.664 {color}{color:darkyellow}-----------------------------------------------------------------------{color}\r\n             {color:darkyellow}\t1. Click 'OK'.{color}\r\n             {color:darkyellow}\t2. Trigger the SWITCH_BINARY_REPORT for the Lifeline from the DUT's Root Device!{color}\r\n             {color:darkyellow}\r\n","url":null},"id":105}
```
Now the controlling side confirms that RPC call with `OK`:
```
{"jsonrpc": "2.0", "result": "Ok", "id": 105}
```
Once the Test Case finished, the `testCaseFinished` RPC method is sent:
```
{"jsonrpc":"2.0","method":"testCaseFinished","params":{"IdGuid":"3bee80ad-f2b1-4aa8-8982-ec2a215420ef","Name":"CSR_LifelineMandatoryReports_Rev03","EndPointId":"c047e12a-adcc-46c4-9715-91842628752f","EndPoint":"0","Location":null,"ItemType":"ZATSTestCase","Category":"Command Class Support Requirements","Group":"Interactive","DateLastModified":"2025-07-02T10:44:26+02:00","LastExecutionDateTime":"2025-07-07T09:52:07.031544+02:00","TestCaseLogPaths":[".\\Log\\250707_084045",".\\Log\\250707_090637",".\\Log\\250707_090736",".\\Log\\250707_090816",".\\Log\\250707_091815",".\\Log\\250707_095207"],"MissingHardware":false,"FormItemReferences":[],"IsLongRange":true,"Result":"PASSED"},"id":190}
```

### Setup Serial Devices

```
{"jsonrpc": "2.0", "method": "setupSerialDevices", "params": { "serialDevices": {"Zniffer":{"DevType":"Zniffer","SName":"COM8","SPort":null,"SType":"COM","JName":null,"ChipSeries":null,"Library":"ZnifferNCP","VersionNumbers":null,"ZnifferChipType":5,"SnifferVersion":2,"SnifferRevision":55},"FirstController":{"DevType":"Controller","SName":"COM4","SPort":null,"SType":"COM","JName":null,"ChipSeries":"ZW070x","Library":"ControllerBridgeLib","VersionNumbers":"7.18","ZnifferChipType":0,"SnifferVersion":0,"SnifferRevision":0},"SecondController":null,"ThirdController":null,"FirstEndDevice":{"DevType":"EndDevice","SName":"COM14","SPort":null,"SType":"COM","JName":"440046129","ChipSeries":"ZW070x","Library":"EndDeviceLib","VersionNumbers":"7.18","ZnifferChipType":0,"SnifferVersion":0,"SnifferRevision":0},"SecondEndDevice":null,"ThirdEndDevice":null,"RfRegion":"EU","LRChannel":"Undefined"}, "configureDevices": false }, "id": 0}'
```
Afterwards, the `setupSerialDevices` method will be completed by `setupSerialDevicesDone`, which reports the status of that operation:
```
{"jsonrpc":"2.0","method":"setupSerialDevicesDone","params":{"result":"Completed"},"id":9}
```

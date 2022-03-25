# Dev Tools Guide

## VS Code Remote Setup
**VSCode Remote**  
After installing [VS Code](https://code.visualstudio.com/Download), the following tutorial can be used to connect Visual Studio Code to a remote Linux system or server. [Remote Development using SSH](https://code.visualstudio.com/docs/remote/ssh)

Most commonly Amazon Linux 2 EC2 instances are used and can be setup using the following [guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html)

[C5 EC2 instances](https://aws.amazon.com/ec2/instance-types/c5/) work well for standard development. If within budget, c5.2xLarge works great.

**Fluent Bit**  
SSH to the remote instance and clone Fluent Bit's source code and build with instructions from the [Developer Guide](https://github.com/fluent/fluent-bit/blob/master/DEVELOPER_GUIDE.md#testing)

In VS Code, connect to the remote instance and open the Fluent Bit repo. This will be the workspace we will setup.

**Extensions**  
Install the following Visual Studio Code extensions on the remote instance by clicking the extension icon on the left VS Code icon bar.
- C/C++
- C/C++ Extension Pack
- CMake Tools
- CMake
- GitLens (helpful)

**Configuration**  
Copy the `aws-for-fluent-bit/troubleshooting/resources/vscode` resources folder to your Fluent Bit repository. Rename the folder from vscode to .vscode.
```
> tree ./fluent-bit/.vscode/
├── external-plugins
│   └── Readme.md
├── fluent-bit-config
│   ├── fluent-bit-cloudwatch_logs.conf
│   ├── fluent-bit.conf
│   ├── fluent-bit-go.conf
│   ├── fluent-bit-kinesis_firehose.conf
│   ├── fluent-bit-kinesis_streams.conf
│   └── fluent-bit-s3.conf
├── launch.json
├── scripts
│   ├── list-fluent-bit-plugin-args.sh
│   ├── rebuild-external.sh
│   └── rebuild.sh
├── settings.json
└── tasks.json
```
This .vscode folder does several things
1. Sets style guides
    - Indent style
    - Ruler set to 90 characters from left
    - Auto formatting Fluent Bit style preferences (shift + option + F on mac)
2. Adds build scripts used by VS Code debugging
3. Adds build tasks used by VS Code debugging
4. Adds launch configuration `launch.json` which sets up vscode to build and run Fluent Bit
5. External plugins folder, to auto build, attach, and run Go plugins if needed
6. Fluent Bit config files that are connected to the Fluent Bit launch tasks

If you wish to develop aws-for-fluent-bit go plugins, we recommend you follow the readme `./aws-for-fluent-bit/troubleshooting/resources/external-plugins/README.md` in the external plugins folder to configure these repositories.  

## Build and Run With the Debugger
Go to the VS Code left icon bar and select the Run and Debug icon. At the top, click the dropdown button on the bar with the play symbol.  
The following options will be presented
- Fluent Bit (General Config)
- Fluent Bit (CloudWatch)
- Fluent Bit (S3)
- Fluent Bit (Kinesis Streams)
- Fluent Bit (Kinesis Firehose)
- Fluent Bit (Go Plugins)
- Fluent Bit -- No Build (General Config)
- Fluent Bit -- (General Config with Valgrind)

The first 5 options build Fluent Bit, and run Fluent Bit with the corresponding config file, found in `fluent-bit/.vscode/fluent-bit-config`. Fluent Bit will be run with the debugger.

The next option "Go Plugins" will build Cloudwatch and Kinesis Streams Go Plugins found in the external-plugins folder and run the resulting `.so` lib files with Fluent Bit. Kinesis Firehose has not yet been setup to work with this launch configuration option.  Please feel free to submit a pr to add. Fluent Bit is run with the fluent-bit_go.conf file. Note: the c debugger does not break on Go code lines from the Go attached libraries.

The following option "No Build" runs Fluent Bit without building it, which may be helpful if you are running Fluent Bit and don't want to wait for it to build.

The last option (General Config with Valgrind) runs Fluent Bit with Valgrind.

**Run Fluent Bit**  
After selecting a launch option from the dropdown, press the green play button and wait for Fluent Bit to build and execute. Anywhere you with to inspect your code while executing, select the whitespace to the left of a line number to add a breakpoint which looks like a red stopsign. When this line of code is executed, the code will hault, and VS Code will switch into debug view. To the left in the Run and Debug panel, you will be able to see variables at the local scope, the call stack, various threads, and other helpful details.

You can add variable expressions to watch in the left hand panel as well which is helpful when confirming the state of a few suspect variables.

## Running Acutest
Acutest (Another C Unit Test) is the system Fluent Bit uses for unit testing.

Each Acutest test is built as a separate compilation target meaning that when CMake builds, we will have a different binary for each test, which appears in our `fluent-bit/build/bin` folder after building Fluent Bit.

To run the unit tests in VSCode, first configure CMake
```
cmake -DFLB_DEV=On -DFLB_TESTS_RUNTIME=On -DFLB_TESTS_INTERNAL=On ../
make
```

At the blue ribbon bar of VS Code, you should see a button that says Build [all]. Press that button.
When complete, click the text to the right of the debug and play button, which allows us to select our debug target. Click the unit test you would like to run. Then press the debug button.

If you insert breakpoints in you test you will notice that these breakpoints, even though we are running in debug mode ***will not be hit!***

***Debugging with Acutest (caveat)***  
It turns out that to increase performance, Acutest runs tests in parallel. This means that it is difficult for our debugger to track our code.

To resolve this, we need to replace `./fluent-bit/tests/lib/acutest/acutest.h` with `./fluent-bit/.vscode/scripts/acutest.h`.
In the unit test you are trying to debug, you will wee at the bottom a struct called TEST_LIST. Find the function entry you are testing, and copy the name. Copy that name to the replacement acutest.h file's ACUTEST_DEBUG_TARGET #define.
```

#define ACUTEST_DEBUG_TARGET "test1_name" /* See below */

/*
 * ACUTEST_DEBUG_TARGET is found in your test's TEST_LIST name. 
 *
 *   Example:
 *
 *   TEST_LIST = {
 *       { "test1_name", test1_func_ptr },
 *       { "test2_name", test2_func_ptr },
 *       ...
 *       { 0 }
 *   };
 */
```

This file ensures that the test with ACUTEST_DEBUG_TARGET as its name will be run on the original thread, meaning that we will now be able to set breakpoints within this test function, and our debugger will now work.

It may be inconvenient to have this file constantly shown as red in `git status` so if you would like, you can run the following command to ignore the acutest.h change so we don't accidentally commit the revised acutest to Fluent Bit.
```
git update-index --assume-unchanged ./tests/lib/acutest/acutest.h
```

## FireLens Datajet Holistic Testing
We have enabled 1 click Fluent Bit build/run/debugging, and 1 click Unit Test build/run/debugging. But we are still missing a way to send test data to Fluent Bit and validate results.

FireLens Datajet provides a 1 click option for routing data to Fluent Bit and validating results (validation components are currently broken and left to future development).

See the [FireLens Datajet](https://github.com/aws/firelens-datajet) project repository for information on how to set it up.

You can use FireLens Datajet in two ways
1. Manage Fluent Bit building, running, test data routing, and validating
2. Manage test data routing, and validating

Usually when using the debugger, option 2 is the best way to go. Clone FireLens datajet to the same EC2 development instance Fluent Bit is being developed on.  
Open a new Remote VS Code window and browse open the remote FireLens datajet project.

Whatever the test configuration json descibes in  `./firelens-datajet/firelens-datajet.json`, FireLens Datajet will execute. By default this is set to
```
{
    "generator": {
        "name": "increment",
        "config": {
            "batchSize": 1,
            "waitTime": 0.050
        }
    },
    "datajet": {
        "name": "forward",
        "config": {
            "logStream": "stderr"
        }
    },
    "stage": {
        "batchRate": 1000,
        "maxBatches": 10
    }
}
```
This configuration instructs Firelens datajet to generate 10 incrementing logs at a very fast rate and forward them to Fluent Bit.  

To test this, in the Fluent Bit VSCode window, press the Play button for any of the following options:
- Fluent Bit (General Config)
- Fluent Bit (CloudWatch)
- Fluent Bit (S3)
- Fluent Bit (Kinesis Streams)
- Fluent Bit (Kinesis Firehose)

These configuration options all Fluent Bit listen for Forward requests on port `24224`. The Firelens Datajet forward output sends data by default to port `24224`.  

To send the data, go to FireLens Datajet and press the Play button called "Firelens Datajet Endpoint". Note: Node and other prerequisites should first be installed as documented in the FireLens Datajet [readme](https://github.com/aws/firelens-datajet)


The [FireLens Datajet Examples](https://github.com/aws/firelens-datajet/tree/main/examples) folder shows several other test configurations FireLens Datajet can process to generate and route test data to Fluent Bit.

**Zen Testing**  
With FireLens Datajet VSCode open on one side of the screen and Fluent Bit VS Code open on the other side of the screen, all the time can be spent developing and modifying the FireLens Datajet test configuration file.  
Setting up, building, running tests, is reduced to pressing two Play buttons. Highly repeatable, portatble, and easy to view and think about. 


## Testing on Windows
For Windows Testing, you will need a Windows device or remote instance. Amazon EC2 is recommended. Follow the following tutorial to setup an [Amazon EC2 Windows instance](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/EC2_GetStarted.html).

Follow the Fluent Bit [Compile Windows From Source](https://docs.fluentbit.io/manual/installation/windows#compile-from-source) guide to learn how to build and test Fluent Bit on Windows.
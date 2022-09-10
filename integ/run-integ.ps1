# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
# 	http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

<#
    .SYNOPSIS
    Used to run integration tests on Windows.

    .DESCRIPTION
    This script can be used to run integration tests on Windows.

    .PARAMETER TestPlugin
    [Optional] Specifies the TestPlugin to be validated. Defaults to "cicd".

    .PARAMETER FluentBitImage
    [Optional] Specifies the fluent-bit image which needs to be validated. Defaults to "amazon/aws-for-fluent-bit:windowsservercore-latest"

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    None. This script does not generate an output object.

    .EXAMPLE
    PS> .\run-integ.ps1 -TestPlugin cicd
    Runs all the integration tests as would be required in CICD.

    .EXAMPLE
    PS> .\run-integ.ps1 -TestPlugin cloudwatch_logs
    Runs Cloudwatch Core plugin integration test against "amazon/aws-for-fluent-bit:windowsservercore-latest" image.

    .EXAMPLE
    PS> .\run-integ.ps1 -TestPlugin kinesis_firehose -FluentBitImage "amazon/aws-for-fluent-bit:windowsservercore-stable"
    Runs Kinesis Firehose Core plugin integration test against "amazon/aws-for-fluent-bit:windowsservercore-stable" image.
#>
Param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("cicd","cloudwatch","cloudwatch_logs","clean-cloudwatch","kinesis","kinesis_streams","firehose","kinesis_firehose","s3","clean-s3","delete")]
    [string]$TestPlugin = "cicd",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FluentBitImage = "amazon/aws-for-fluent-bit:windowsservercore-latest"
)

$ErrorActionPreference = 'Stop'
$DockerComposeVersion = "2.7.0"

# Define variables.
$IntegTestRoot = "${PSScriptRoot}"
$env:AWS_REGION = "us-west-2"
$env:PROJECT_ROOT = Resolve-Path -Path "${PSScriptRoot}\.."
$env:FLUENT_BIT_IMAGE = $FluentBitImage
# Tag is used in the s3 keys; each test run has a unique (random) tag
$env:TAG = -join ((65..90) + (97..122) | Get-Random -Count 10 | % {[char]$_})
# AWS_FOR_FLUENT_BIT_CONTAINER_NAME is the name for the fluent-bit container ran for each service.
$env:AWS_FOR_FLUENT_BIT_CONTAINER_NAME = "aws-for-fluent-bit-$($env:TAG)"

# Windows specific settings.
$env:ARCHITECTURE= "x86-64"
$env:VOLUME_MOUNT_CONTAINER="C:/out"
$env:ValidateS3Dockerfile = "Dockerfile.windows"
# For Windows, we need to specify a static IP address for the fluent-bit container.
# This is because fluent-bit container would be started first and then the other containers
# would need to connect to the fluent-bit container over a TCP socket.
# Docker-compose doesn't provide a way to configure this IP address dynamically.
# Since we are using a link-local IP over NAT, we would be able to have public access without
# any IP conflicts.
$env:DockerNetworkSubnet = "169.254.150.0/24"
$env:DockerNetworkGateway = "169.254.150.1"
$env:DockerNetworkStaticIP = "169.254.150.10"
$env:FLUENT_CONTAINER_IP = $env:DockerNetworkStaticIP

# Profiles used in docker-compose.
# Core profile contains services which should be ran before the test services.
# For integration tests, this would only have fluent-bit service.
$CoreProfile = "core"
$TestProfile = "test"

Function Install-Package {
    <#
    .SYNOPSIS
    Installs the packages required for running these integration tests.
    #>

    # Install docker-compose on the instance.
    # Use installation instructions from "https://docs.docker.com/compose/install/compose-plugin/#install-compose-on-windows-server"
    Write-Host "Installing Docker-Compose version ${DockerComposeVersion} on the instance."
    if (-Not (Test-Path -Path "$Env:ProgramFiles\Docker\docker-compose.exe" -PathType Leaf))
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest "https://github.com/docker/compose/releases/download/v${DockerComposeVersion}/docker-compose-Windows-x86_64.exe" -UseBasicParsing -OutFile $Env:ProgramFiles\Docker\docker-compose.exe
    }
    Write-Host $( docker-compose version )
}

Function Test-Command {
    <#
    .SYNOPSIS
    Tests if the previous executed method returned with an error.

    .PARAMETER TestMethod
    Specifies the name of the previous method so that it can be captured in the logs.
    #>
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TestMethod
    )

    if ($LASTEXITCODE)
    {
        throw ("Integration tests failed for Windows during {0}: Message: {1}" -f $TestMethod, $_.Exception.Message)
    }
}

Function Run-Test {
    <#
    .SYNOPSIS
    Runs the test using the docker-compose config specified for the plugin.

    .PARAMETER PluginUnderTest
    Specifies the name of the plugin which we are testing.

    .PARAMETER DockerComposeTestFilePath
    Specifies the path of the docker-compose config file which has specifications for the test.

    .PARAMETER SleepTime
    [Optional] Specifies the time in seconds which we need to sleep after the tests are completed.

    .Notes
    When running the tests, we first start the core profile. Each service in core profile has the pre-defined
    healthchecks. Once the core services are in healthy status, we start the test profile which runs the
    services performing the tests. Finally, we sleep for some time so as to enable fluent-bit to send data to the
    destination location.
    #>
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PluginUnderTest,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DockerComposeTestFilePath,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [int]$SleepTime=120
    )

    Write-Host "Running tests which generate data for ${PluginUnderTest}"

    # Build the core profile services.
    docker-compose --file $DockerComposeTestFilePath --profile $CoreProfile build
    Test-Command -TestMethod "$($MyInvocation.MyCommand): ${PluginUnderTest} - Core Build"

    # Build the test profile services.
    docker-compose --file $DockerComposeTestFilePath --profile $TestProfile build
    Test-Command -TestMethod "$($MyInvocation.MyCommand): ${PluginUnderTest} - Test Build"

    # Run the services in backgroud and wait for them to move into healthy status.
    docker-compose --file $DockerComposeTestFilePath --profile $CoreProfile up --detach --wait
    Test-Command -TestMethod "$($MyInvocation.MyCommand): ${PluginUnderTest} - Core Up"

    # Run the test services in foreground. Abort when any the test containers exit.
    docker-compose --file $DockerComposeTestFilePath --profile $TestProfile up
    Test-Command -TestMethod "$($MyInvocation.MyCommand): ${PluginUnderTest} - Test Up"

    # Giving a pause before running the validation tests.
    Start-Sleep -Seconds $SleepTime

    Write-Host "Tests completed for ${PluginUnderTest}"
}

Function Validate-Test {
    <#
    .SYNOPSIS
    Runs the validation tests using the docker-compose config specified for the plugin.

    .PARAMETER PluginUnderTest
    Specifies the name of the plugin which we are testing.

    .PARAMETER DockerComposeValidateFilePath
    Specifies the path of the docker-compose config file which has specifications for the validation test.

    .PARAMETER ValidationFileName
    Specifies the name of the file which is used in the validation tests.
    #>
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PluginUnderTest,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DockerComposeValidateFilePath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ValidationFileName
    )

    Write-Host "Running validation test for ${PluginUnderTest}"

    # Creates a file as a flag for the validation failure.
    New-Item -Path "${IntegTestRoot}\out\${ValidationFileName}" -ItemType File -Force

    # Build the validation services.
    docker-compose --file $DockerComposeValidateFilePath build
    Test-Command -TestMethod "$($MyInvocation.MyCommand): ${PluginUnderTest}"

    # Run the validation services.
    docker-compose --file $DockerComposeValidateFilePath up
    Test-Command -TestMethod "$($MyInvocation.MyCommand): ${PluginUnderTest}"

    if (Test-Path -Path "${IntegTestRoot}\out\${ValidationFileName}" -PathType Leaf) {
        throw "Test failed for ${PluginUnderTest}."
    }
    Write-Host "Validation succeeded for ${PluginUnderTest}"
}

Function Clean-Test {
    <#
    .SYNOPSIS
    Cleans up the docker-compose resources once the tests have been ran.

    .PARAMETER PluginUnderTest
    Specifies the name of the plugin which we are testing.

    .PARAMETER DockerComposeFilePath
    Specifies the path of the docker-compose config file which has specifications for the test.
    #>
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PluginUnderTest,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DockerComposeFilePath
    )

    # Run "docker-compose down" once the tests have been ran.
    docker-compose --file $DockerComposeFilePath --profile $CoreProfile --profile $TestProfile down
    Test-Command -TestMethod "$($MyInvocation.MyCommand): ${PluginUnderTest}"
}

Function Test-CloudWatch {
    <#
    .SYNOPSIS
    Runs the integration tests for Cloudwatch plugin.

    .PARAMETER CorePlugin
    [Optional] Specifies if the core plugin is being tested.
    #>
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [switch]$CorePlugin
    )

    $env:LOG_GROUP_NAME="fluent-bit-integ-test-amd64"
    $DockerComposeTestFilePath = "${IntegTestRoot}/test_cloudwatch/docker-compose.windows.test.yml"
    $DockerComposeValidateFilePath = "${IntegTestRoot}/test_cloudwatch/docker-compose.validate.yml"

    # Set the envs based on whether core plugin or Golang plugin is being tested.
    if ($CorePlugin) {
        $env:CW_PLUGIN_UNDER_TEST="cloudwatch_logs"
    } else {
        $env:CW_PLUGIN_UNDER_TEST="cloudwatch"
    }

    # Run the tests which would generate test data. Once they end, perform "docker-compose down".
    Run-Test -PluginUnderTest "Cloudwatch" -DockerComposeTestFilePath $DockerComposeTestFilePath
    Clean-Test -PluginUnderTest "Cloudwatch" -DockerComposeFilePath $DockerComposeTestFilePath

    # Perform validation of the tests.
    Validate-Test -PluginUnderTest "Cloudwatch" -DockerComposeValidateFilePath $DockerComposeValidateFilePath -ValidationFileName "cloudwatch-test"
    Clean-Test -PluginUnderTest "Cloudwatch" -DockerComposeFilePath $DockerComposeValidateFilePath
}

Function Clean-CloudWatch {
    <#
    .SYNOPSIS
    Cleans the cloudwatche resources used during the integration tests.
    #>

    $env:LOG_GROUP_NAME="fluent-bit-integ-test-amd64"
    $DockerComposeTestFilePath = "${IntegTestRoot}/test_cloudwatch/docker-compose.clean.yml"

    # Run the tests which would clean Cloudwatch logs. Once this ends, perform "docker-compose down".
    Run-Test -PluginUnderTest "Cloudwatch" -DockerComposeTestFilePath $DockerComposeTestFilePath -SleepTime 1
    Clean-Test -PluginUnderTest "Cloudwatch" -DockerComposeFilePath $DockerComposeTestFilePath
}

Function Test-Kinesis {
    <#
    .SYNOPSIS
    Runs the integration tests for Kinesis plugin.

    .PARAMETER CorePlugin
    [Optional] Specifies if the core plugin is being tested.
    #>
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [switch]$CorePlugin
    )

    $DockerComposeTestFilePath = "${IntegTestRoot}/test_kinesis/docker-compose.windows.test.yml"
    $DockerComposeValidateFilePath = "${IntegTestRoot}/test_kinesis/docker-compose.validate-and-clean-s3.yml"
    $env:S3_ACTION="validate"
    $env:S3_PREFIX="kinesis-test"
    $env:TEST_FILE="kinesis-test"
    $env:EXPECTED_EVENTS_LEN="1000"

    # Set the envs based on whether core plugin or Golang plugin is being tested.
    if ($CorePlugin) {
        $env:FluentBitConfigDir = "windows-core-config"
    } else {
        $env:FluentBitConfigDir = "windows-config"
    }

    # Run the tests which would generate test data. Once they end, perform "docker-compose down".
    Run-Test -PluginUnderTest "kinesis stream" -DockerComposeTestFilePath $DockerComposeTestFilePath
    Clean-Test -PluginUnderTest "kinesis stream" -DockerComposeFilePath $DockerComposeTestFilePath

    # Perform validation of the tests.
    Validate-Test -PluginUnderTest "kinesis stream" -DockerComposeValidateFilePath $DockerComposeValidateFilePath -ValidationFileName "kinesis-test"
    Clean-Test -PluginUnderTest "kinesis stream" -DockerComposeFilePath $DockerComposeValidateFilePath
}

Function Test-Firehose {
    <#
    .SYNOPSIS
    Runs the integration tests for Firehose plugin.

    .PARAMETER CorePlugin
    [Optional] Specifies if the core plugin is being tested.
    #>
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [switch]$CorePlugin
    )

    $DockerComposeTestFilePath = "${IntegTestRoot}/test_firehose/docker-compose.windows.test.yml"
    $DockerComposeValidateFilePath = "${IntegTestRoot}/test_firehose/docker-compose.validate-and-clean-s3.yml"
    $env:S3_ACTION="validate"
    $env:S3_PREFIX="firehose-test"
    $env:TEST_FILE="firehose-test"
    $env:EXPECTED_EVENTS_LEN="1000"

    # Set the envs based on whether core plugin or Golang plugin is being tested.
    if ($CorePlugin) {
        $env:FluentBitConfigDir = "windows-core-config"
    } else {
        $env:FluentBitConfigDir = "windows-config"
    }

    # Run the tests which would generate test data. Once they end, perform "docker-compose down".
    Run-Test -PluginUnderTest "firehose" -DockerComposeTestFilePath $DockerComposeTestFilePath
    Clean-Test -PluginUnderTest "firehose" -DockerComposeFilePath $DockerComposeTestFilePath

    # Perform validation of the tests.
    Validate-Test -PluginUnderTest "firehose" -DockerComposeValidateFilePath $DockerComposeValidateFilePath -ValidationFileName "firehose-test"
    Clean-Test -PluginUnderTest "firehose" -DockerComposeFilePath $DockerComposeValidateFilePath
}

Function Test-S3 {
    <#
    .SYNOPSIS
    Runs the S3 integration tests.
    #>

    # different S3 prefix for each test
    $env:S3_PREFIX_PUT_OBJECT="logs/${env:ARCHITECTURE}/putobject"
    $env:S3_PREFIX_MULTIPART="logs/${env:ARCHITECTURE}/multipart"
    $env:S3_ACTION="validate"
    $env:S3_PREFIX="logs"
    $env:TEST_FILE="s3-test"
    $env:EXPECTED_EVENTS_LEN="7717"

    $DockerComposeTestFilePath = "${IntegTestRoot}/test_s3/docker-compose.windows.test.yml"
    $DockerComposeValidateS3MultipartFilePath = "${IntegTestRoot}/test_s3/docker-compose.validate-s3-multipart.yml"
    $DockerComposeValidateS3PutObjectFilePath = "${IntegTestRoot}/test_s3/docker-compose.validate-s3-putobject.yml"

    # Run the tests which would generate test data. Once they end, perform "docker-compose down".
    Run-Test -PluginUnderTest "S3" -DockerComposeTestFilePath $DockerComposeTestFilePath
    Clean-Test -PluginUnderTest "S3" -DockerComposeFilePath $DockerComposeTestFilePath

    # Perform validation of the tests.
    Validate-Test -PluginUnderTest "S3" -DockerComposeValidateFilePath $DockerComposeValidateS3MultipartFilePath -ValidationFileName "s3-test"
    Clean-Test -PluginUnderTest "S3" -DockerComposeFilePath $DockerComposeValidateS3MultipartFilePath

    Validate-Test -PluginUnderTest "S3" -DockerComposeValidateFilePath $DockerComposeValidateS3PutObjectFilePath -ValidationFileName "s3-test"
    Clean-Test -PluginUnderTest "S3" -DockerComposeFilePath $DockerComposeValidateS3PutObjectFilePath
}

Function Clean-S3 {
    <#
    .SYNOPSIS
    Cleans the S3 locations where logs are stored for Kinesis, Firehose, and S3 plugins.
    #>

    $env:S3_ACTION="clean"
    $env:EXPECTED_EVENTS_LEN="1000"
    $DockerComposeKinesisTestFilePath = "${IntegTestRoot}/test_kinesis/docker-compose.validate-and-clean-s3.yml"
    $DockerComposeFirehoseTestFilePath = "${IntegTestRoot}/test_firehose/docker-compose.validate-and-clean-s3.yml"
    $DockerComposeKinesisTestFilePath = "${IntegTestRoot}/test_kinesis/docker-compose.validate-and-clean-s3.yml"
    $DockerComposeS3MultipartFilePath = "${IntegTestRoot}/test_s3/docker-compose.validate-s3-multipart.yml"
    $DockerComposeS3PutObjectFilePath = "${IntegTestRoot}/test_s3/docker-compose.validate-s3-putobject.yml"

    # Clean the S3 locations used in Kinesis tests.
    $env:S3_PREFIX="kinesis-test"
    $env:TEST_FILE="kinesis-test"
    Run-Test -PluginUnderTest "Clean-S3" -DockerComposeTestFilePath $DockerComposeKinesisTestFilePath -SleepTime 1
    Clean-Test -PluginUnderTest "Clean-S3" -DockerComposeFilePath $DockerComposeKinesisTestFilePath

    # Clean the S3 locations used in Firehose tests.
    $env:S3_PREFIX="firehose-test"
    $env:TEST_FILE="firehose-test"
    Run-Test -PluginUnderTest "Clean-S3" -DockerComposeTestFilePath $DockerComposeFirehoseTestFilePath -SleepTime 1
    Clean-Test -PluginUnderTest "Clean-S3" -DockerComposeFilePath $DockerComposeFirehoseTestFilePath

    # Clean the S3 locations used in Multipart S3 tests.
    $env:S3_PREFIX_MULTIPART="logs/${env:ARCHITECTURE}/multipart"
    $env:TEST_FILE="s3-test"
    Run-Test -PluginUnderTest "Clean-S3" -DockerComposeTestFilePath $DockerComposeS3MultipartFilePath -SleepTime 1
    Clean-Test -PluginUnderTest "Clean-S3" -DockerComposeFilePath $DockerComposeS3MultipartFilePath

    # Clean the S3 locations used in PutObject S3 tests.
    $env:S3_PREFIX_PUT_OBJECT="logs/${env:ARCHITECTURE}/putobject"
    Run-Test -PluginUnderTest "Clean-S3" -DockerComposeTestFilePath $DockerComposeS3PutObjectFilePath -SleepTime 1
    Clean-Test -PluginUnderTest "Clean-S3" -DockerComposeFilePath $DockerComposeS3PutObjectFilePath
}

# Install the required packages
Install-Package

# Select the methods to execute based on the selected test plugin.
switch ($TestPlugin) {
    "cloudwatch" {
        Test-CloudWatch
        Clean-CloudWatch
    }

    "cloudwatch_logs" {
        Test-CloudWatch -CorePlugin
        Clean-CloudWatch
    }

    "clean-cloudwatch" {
        Clean-CloudWatch
    }

    "kinesis" {
        # Create and setup test environment.
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Create"
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Setup"

        Clean-S3
        Test-Kinesis
    }

    "kinesis_streams" {
        # Create and setup test environment.
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Create"
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Setup"

        Clean-S3
        Test-Kinesis -CorePlugin
    }

    "firehose" {
        # Create and setup test environment.
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Create"
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Setup"

        Clean-S3
        Test-Firehose
    }

    "kinesis_firehose" {
        # Create and setup test environment.
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Create"
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Setup"

        Clean-S3
        Test-Firehose -CorePlugin
    }

    "s3" {
        # Create and setup test environment.
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Create"
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Setup"

        Clean-S3
        Test-S3
    }

    "clean-s3" {
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Setup"
        Clean-S3
    }

    "cicd" {
        Test-CloudWatch
        Clean-CloudWatch

        Test-CloudWatch -CorePlugin
        Clean-CloudWatch

        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Create"
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Setup"

        Clean-S3
        Test-Kinesis

        Clean-S3
        Test-Kinesis -CorePlugin

        Clean-S3
        Test-Firehose

        Clean-S3
        Test-Firehose -CorePlugin

        Clean-S3
        Test-S3

        Clean-S3
    }

    "delete" {
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Setup"
        Clean-S3
        Invoke-Expression "$IntegTestRoot\resources\manage_test_resources.ps1 -Action Delete"
    }
}

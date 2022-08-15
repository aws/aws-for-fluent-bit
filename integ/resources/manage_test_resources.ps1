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
    Used to manage the test resources used for the integration tests.

    .DESCRIPTION
    This script can be used to create, setup and delete test resources used for the integration tests.

    .PARAMETER Action
    Specifies the Action to be performed. Should be amongst "Create","Setup" or "Delete".

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    None. This script does not generate an output object.

    .EXAMPLE
    PS> .\manage_test_resources.ps1 -Action Create
    Creates the CFN stack for the test resources.

    .EXAMPLE
    PS> .\manage_test_resources.ps1 -Action Setup
    Queries the CFN stack and sets the environment variables for the same.

    .EXAMPLE
    PS> .\manage_test_resources.ps1 -Action Delete
    Deletes the CFN stack for the test resources.
#>
Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Create","Setup","Delete")]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

# Define variables.
$ResourcesRoot = "${PSScriptRoot}"
$Region = "us-west-2"
$Architecture = "x86-64"
$StackName = "integ-test-fluent-bit-windows-${Architecture}"
$MaxRetries = 10

Function Create-TestResources {
    $template = Get-Content -Path "${ResourcesRoot}\cfn-kinesis-s3-firehose.yml" -Raw
    trap {
        try
        {
            New-CFNStack -Region $Region -StackName $StackName -Capability CAPABILITY_NAMED_IAM -TemplateBody $template

            # Wait for the CFN stack to be created.
            # Stack usually takes 150 seconds to be created.
            $Retry = 1
            while ((-Not (Test-CFNStack -StackName $StackName -Status CREATE_COMPLETE)) -Or ($Retry -le 10)) {
                Write-Host "Stack is not ready yet. Sleeping for 30 seconds. Retry count: $Retry"
                $Retry++
                Start-Sleep 30
            }

            # If we spent 300 seconds and the stack is still not created then error out.
            if (-Not (Test-CFNStack -StackName $StackName -Status CREATE_COMPLETE)) {
                throw "Failed to create test resources stack."
            }
        } catch {
            # If New-CFNStack errors out and the error message is for Stack already existing then ignore the error.
            if ($_.Exception.Message -NotMatch "already exists") {
                throw $_
            }
            Write-Host "The stack already exists!"
        }
        # Use continue so that trap does not throw any error.
        continue
    }
    Get-CFNStack -Region $Region -StackName $StackName
}

Function Setup-TestResources {
    # If the stack does not exist, then we will error out here itself.
    Get-CFNStack -Region $Region -StackName $StackName
    # The logical names are as per cfn-kinesis-s3-firehose.yml
    $env:FIREHOSE_STREAM = (Get-CFNStackResourceList -StackName $StackName -LogicalResourceId "firehoseDeliveryStreamForFirehoseTest").PhysicalResourceId
    $env:KINESIS_STREAM = (Get-CFNStackResourceList -StackName $StackName -LogicalResourceId "kinesisStream").PhysicalResourceId
    $env:S3_BUCKET_NAME = (Get-CFNStackResourceList -StackName $StackName -LogicalResourceId "s3Bucket").PhysicalResourceId
}

Function Remove-TestResources {
    Remove-CFNStack -Region $Region -StackName $StackName -Force
}

switch ($Action) {
    "Create" {
        Create-TestResources
    }

    "Setup" {
        Setup-TestResources
    }

    "Delete" {
        Remove-TestResources
    }
}

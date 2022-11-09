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
    Builds the aws-for-fluent-bit Windows image for a specific platform

    .DESCRIPTION
    This script builds the aws-for-fluent-bit Windows image for a specific platform

    .PARAMETER Region
    [Optional] Specifies the region. Defaults to 'us-west-2'.

    .PARAMETER Platform
    Specifies the platform for which the image needs to be built. Valid values are 'windows2019', and 'windows2022'.

    .PARAMETER S3BaseBucket
    Specifies the S3 base bucket where the artifacts needed for the image are staged.

    .PARAMETER AccountId
    Specifies the AWS account number where the image needs to be pushed

    .PARAMETER AWSForFluentBitVersion
    Specifies the aws for fluent bit version to be used for the build

    .PARAMETER BuildNumber
    [Optional] Specifies the build number for the given version. Defaults to 1.

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    None. This script does not generate an output object.

    .EXAMPLE
    PS> .\build_windows_image.ps1 -Platform "windows2019" -S3BaseBucket "staging" -AccountId 12345 -AWSForFluentBitVersion "2.26.0"
    Builds the Windows Server 2019 based aws-for-fluent-bit image with artifacts from S3- staging/2.26.0/1. The image in ECR would then be
    "12345.dkr.ecr.us-west-2.amazonaws.com/aws-for-fluent-bit:2.26.0-ltsc2019"
#>

Param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Region = "us-west-2",

    [Parameter(Mandatory=$true)]
    [ValidateSet("windows2019","windows2022")]
    [string]$Platform,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$S3BaseBucket,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AWSForFluentBitVersion,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildNumber = "1",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryName = "amazon/aws-for-fluent-bit"
)

$ErrorActionPreference = 'Stop'

# Select the base image tag based on the platform
switch ($Platform) {
    "windows2019" {
        $BASEIMAGETAG = "ltsc2019"
    }

    "windows2022" {
        $BASEIMAGETAG = "ltsc2022"
    }
}

Write-Host ("Using tag {0} for the platform {1}" -f $BASEIMAGETAG, $Platform)

# All the certificate URLs
$AmazonRootCA1 = "https://www.amazontrust.com/repository/AmazonRootCA1.cer"
$AmazonRootCA2 = "https://www.amazontrust.com/repository/AmazonRootCA2.cer"
$AmazonRootCA3 = "https://www.amazontrust.com/repository/AmazonRootCA3.cer"
$AmazonRootCA4 = "https://www.amazontrust.com/repository/AmazonRootCA4.cer"

# Define Variables
$WorkingDir = "C:\build"
$StagingDir = "C:\staging"
$CertsDir = "${StagingDir}\certs"
$FLBStagingLocationOnHost = "${StagingDir}\fluent-bit"
$FLBPluginsStagingLocationOnHost = "${StagingDir}\fluent-bit-plugins"
$ECSConfigStagingLocationOnHost = "${StagingDir}\ecs_windows_forward_daemon"
$S3StagingKey = "${AWSForFluentBitVersion}/${BuildNumber}"
$FLBArchiveName = "fluent-bit.zip"
$FLBPluginsArchiveName = "plugins_windows.tar"
$ECSConfigArchiveName = "ecs_windows_forward_daemon.zip"
$AWSForFluentBitVersionFilename = "AWS_FOR_FLUENT_BIT_VERSION"
$EntrypointScriptName = "entrypoint.ps1"
$Dockerfile = "Dockerfile.windows"
$ecrImageName = "${AccountId}.dkr.ecr.${Region}.amazonaws.com/${RepositoryName}:${AWSForFluentBitVersion}-${BASEIMAGETAG}"

# Create all the directories
Write-Host "Creating all the required directories"
New-Item -Path $WorkingDir -ItemType Directory -Force
New-Item -Path $StagingDir -ItemType Directory -Force
New-Item -Path $CertsDir -ItemType Directory -Force
New-Item -Path $FLBStagingLocationOnHost -ItemType Directory -Force
New-Item -Path $FLBPluginsStagingLocationOnHost -ItemType Directory -Force
New-Item -Path $ECSConfigStagingLocationOnHost -ItemType Directory -Force

# Change working directory
cd $WorkingDir

# Log into ECR
Write-Host "Logging into ECR"
$command = Invoke-Expression "(Get-ECRLoginCommand -Region ${Region}).Command"
Invoke-Expression $command

# Download the artifacts to host.
Write-Host "Downloading the fluent-bit and fluent-bit plugins from S3"
Read-S3Object -BucketName "${S3BaseBucket}" -Key "${S3StagingKey}/${FLBArchiveName}" -File "${WorkingDir}\${FLBArchiveName}"
Read-S3Object -BucketName "${S3BaseBucket}" -Key "${S3StagingKey}/${FLBPluginsArchiveName}" -File "${WorkingDir}\${FLBPluginsArchiveName}"
Read-S3Object -BucketName "${S3BaseBucket}" -Key "${S3StagingKey}/${ECSConfigArchiveName}" -File "${WorkingDir}\${ECSConfigArchiveName}"
Read-S3Object -BucketName "${S3BaseBucket}" -Key "${S3StagingKey}/${AWSForFluentBitVersionFilename}" -File "${StagingDir}\${AWSForFluentBitVersionFilename}"
Read-S3Object -BucketName "${S3BaseBucket}" -Key "${S3StagingKey}/${EntrypointScriptName}" -File "${StagingDir}\${EntrypointScriptName}"
Read-S3Object -BucketName "${S3BaseBucket}" -Key "${S3StagingKey}/${Dockerfile}" -File "${StagingDir}\${Dockerfile}"
# Download the Amazon Root CA Certs.
Invoke-WebRequest -URI $AmazonRootCA1 -OutFile "${CertsDir}\AmazonRootCA1.cer"
Invoke-WebRequest -URI $AmazonRootCA2 -OutFile "${CertsDir}\AmazonRootCA2.cer"
Invoke-WebRequest -URI $AmazonRootCA3 -OutFile "${CertsDir}\AmazonRootCA3.cer"
Invoke-WebRequest -URI $AmazonRootCA4 -OutFile "${CertsDir}\AmazonRootCA4.cer"

# Extract them into the required folders.
Write-Host "Extracting the archives into the required folders"
Expand-Archive -Path "${WorkingDir}\${FLBArchiveName}" -DestinationPath $FLBStagingLocationOnHost
tar -xvf "${WorkingDir}\${FLBPluginsArchiveName}" -C $FLBPluginsStagingLocationOnHost
Expand-Archive -Path "${WorkingDir}\${ECSConfigArchiveName}" -DestinationPath $ECSConfigStagingLocationOnHost

# Build the docker image.
Write-Host "Building the docker image"
Invoke-Expression "docker build -t ${ecrImageName} --file ${StagingDir}\Dockerfile.windows --build-arg TAG=${BASEIMAGETAG} --build-arg AWS_FOR_FLUENT_BIT_VERSION=${AWSForFluentBitVersion} ${StagingDir}"

# Throw an error if docker build fails.
if ($LASTEXITCODE) {
    throw "failed to build aws-for-fluent-bit image"
}

# Push image to ECR
Write-Host "Pusing the image to ECR"
Invoke-Expression "docker push ${ecrImageName}"

# Throw an error if docker push fails.
if ($LASTEXITCODE) {
    throw "failed to push aws-for-fluent-bit image to ECR"
}

Write-Host ("Successfully built and pushed the image {0} to ECR" -f $ecrImageName)

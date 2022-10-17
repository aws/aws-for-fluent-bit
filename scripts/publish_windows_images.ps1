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
    Publishes the aws-for-fluent-bit Windows image to the target registry.

    .DESCRIPTION
    This script publishes the aws-for-fluent-bit Windows image to the target registry.

    .PARAMETER Platform
    Specifies the platform for which the image needs to be published. Valid values are 'windows2019', and 'windows2022'.

    .PARAMETER AWSForFluentBitVersion
    Specifies the aws for fluent bit version to be used.

    .PARAMETER PullFromPublicECR
    [Optional] Specifies if the source image is present in Public ECR.

    .PARAMETER PublicECRSourceRegistryAlias
    [Optional] Specifies the public ECR registry alias from where we need to pull the image.

    .PARAMETER SourceRegion
    [Optional] Specifies the source region of the regional ECR image. Defaults to 'us-west-2'.

    .PARAMETER SourceAccountID
    [Optional] Specifies the source account id of the regional ECR image.

    .PARAMETER SourceRepository
    Specifies the source repository of the image.

    .PARAMETER PushToPublicECR
    [Optional] Specifies if the target registry is Public ECR.

    .PARAMETER PushToDockerHub
    [Optional] Specifies if the target registry is DockerHub.

    .PARAMETER TargetRoleArn
    [Optional] Specifies the IAM role to be assumed for publishing the image.

    .PARAMETER TargetRegion
    [Optional] Specifies the target region of the regional ECR image. Defaults to 'us-west-2'.

    .PARAMETER TargetAccount
    [Optional] Specifies the target account of the regional ECR image.

    .PARAMETER PublicECRTargetRegistryAlias
    [Optional] Specifies the public ECR registry alias where we need to push the image.

    .PARAMETER TargetRepository
    Specifies the target repository of the image.

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    None. This script does not generate an output object.

    .EXAMPLE
    PS> .\publish_windows_images.ps1 -Platform "windows2019" -AWSForFluentBitVersion 2.28.3 -PullFromPublicECR -PublicECRSourceRegistryAlias
    abcde -SourceRepository aws-for-fluent-bit -TargetRegion us-west-2 -TargetAccount 12345 -TargetRepository aws-for-fluent-bit
    Pulls aws-for-fluent-bit image version 2.28.3 from Public ECR and pushes the same to aws-for-fluent-bit repository in 12345 and us-west-2.
#>

Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("windows2019","windows2022")]
    [string]$Platform,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AWSForFluentBitVersion,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$PullFromPublicECR,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicECRSourceRegistryAlias,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRegion = "us-west-2",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceAccountID,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRepository,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$PushToPublicECR,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$PushToDockerHub,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetRoleArn,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetRegion = "us-west-2",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetAccount,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicECRTargetRegistryAlias,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetRepository
)

$ErrorActionPreference = 'Stop'

# Tests if the required parameters and dependencies have been provided to the script.
Function Test-Parameters {
    if ($PullFromPublicECR -and (-not $PublicECRSourceRegistryAlias)) {
        throw "When specifying PullFromPublicECR flag, we need PublicECRSourceRegistryAlias as well"
    }
    elseif ((-not $PullFromPublicECR) -and (-not $SourceAccountID)) {
        throw "When the source is in private ECR, we need the SourceAccountID"
    }
    elseif ($PushToPublicECR -and (-not $PublicECRTargetRegistryAlias)) {
        throw "When specifying PushToPublicECR flag, we need PublicECRTargetRegistryAlias as well"
    }
    elseif ((-not ($PushToDockerHub -Or $PushToPublicECR)) -and (-not $TargetAccount))
    {
        throw "When pushing to private ECR, we need TargetAccount and optionally TargetRegion"
    }
}

# Tests if the current partition is the China partition.
Function Test-ChinaPartition {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Region
    )
    if (($Region -eq "cn-north-1") -or ($Region -eq "cn-northwest-1")) {
        return $true
    } else {
        return $false
    }
}

# Login into dockerhub account.
Function Login-DockerHub {
    Write-Host "Logging into dockerhub"

    # Secret name in SecretManager which stores the username and password for dockerhub account.
    $DockerHubSecret = "com.amazonaws.dockerhub.aws-for-fluent-bit.credentials"

    # Login into Dockerhub.
    # We are piping the values of username and password in a single command so that they are not logged anywhere.
    docker login `
    --username ((Get-SECSecretValue -SecretId $DockerHubSecret).SecretString | ConvertFrom-Json).username `
    --password ((Get-SECSecretValue -SecretId $DockerHubSecret).SecretString | ConvertFrom-Json).password

    if ($LASTEXITCODE) {
        throw "failed to login into dockerhub"
    }
    Write-Host "Logged in successfully into dockerhub"
}

# Login into regional ECR of the region.
Function Login-ECR {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Region,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Registry
    )
    Write-Host "Logging into ECR ${Registry}"
    (Get-ECRLoginCommand -Region $Region).Password | docker login --username AWS --password-stdin $Registry

    if ($LASTEXITCODE) {
        throw "failed to login into ECR of ${Registry}"
    }
    Write-Host "Succefully logged into ECR of ${Registry}"
}

# Login into Public ECR where we need to publish the image.
Function Login-PublicECR {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Registry
    )
    Write-Host "Logging into Public ECR - ${Registry}"
    # Get-ECRPAuthorizationToken is only supported in us-east-1
    # Unfortunately, Public ECR doesn't have a powershell command to get the password directly.
    # Therefore, we do the required parsing from authorization token to get the password.
    # Since we are piping it all the way, password would not be logged in any log.
    Get-ECRPAuthorizationToken -Region us-east-1 |
            %{[Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($_.AuthorizationToken))} |
            %{$_.split(':')[1]} |
            docker login --username AWS --password-stdin "${Registry}"

    if ($LASTEXITCODE) {
        throw "failed to login into Public ECR - ${Registry}"
    }
    Write-Host "Succefully logged into - ${Registry}"
}

# Assume the role passed on to the method.
Function Assume-Role {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$RoleArn
    )
    Write-Host "Assuming the role ${RoleArn}"
    $Credentials = (Use-STSRole -RoleSessionName publish-image -RoleArn $RoleArn).Credentials
    $env:AWS_ACCESS_KEY_ID = $Credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $Credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $Credentials.SessionToken
}

# Retrieves the Source Image url based on the registry.
Function Get-SourceImageURL {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseImageTag
    )
    if ($PullFromPublicECR)
    {
        $SourceRegistry = "public.ecr.aws/${PublicECRSourceRegistryAlias}"
    } else {
        # For China partition, add cn suffix to regional ECR image url.
        $SourceECRImageEndpoint = "amazonaws.com"
        if (Test-ChinaPartition $SourceRegion) {
            $SourceECRImageEndpoint = "${SourceECRImageEndpoint}.cn"
        }
        $SourceRegistry = "${SourceAccountID}.dkr.ecr.${SourceRegion}.${SourceECRImageEndpoint}"
    }

    # Source image name.
    $ECRSourceImage = "${SourceRegistry}/${SourceRepository}:${AWSForFluentBitVersion}-${BaseImageTag}"
    return $ECRSourceImage
}

# Retrieves the Target Image url based on the registry.
Function Get-TargetImageURL {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseImageTag
    )
    if ($PushToDockerHub){
        # Generate target image name for dockerhub.
        $TargetImage = "${TargetRepository}:${AWSForFluentBitVersion}-${BaseImageTag}"
    }
    elseif ($PushToPublicECR)
    {
        $PublicECRTargetRegistry = "public.ecr.aws/${PublicECRTargetRegistryAlias}"
        # Generate target image name for public ECR.
        $TargetImage = "${PublicECRTargetRegistry}/${TargetRepository}:${AWSForFluentBitVersion}-${BaseImageTag}"
    }
    else{
        # For China partition, add cn suffix to private ECR image url.
        $TargetECRImageEndpoint = "amazonaws.com"
        if (Test-ChinaPartition $TargetRegion) {
            $TargetECRImageEndpoint = "${TargetECRImageEndpoint}.cn"
        }

        $PrivateECRTargetRegistry = "${TargetAccount}.dkr.ecr.${TargetRegion}.${TargetECRImageEndpoint}"
        # Generate target image name for dockerhub.
        $TargetImage = "${PrivateECRTargetRegistry}/${TargetRepository}:${AWSForFluentBitVersion}-${BaseImageTag}"
    }

    return $TargetImage
}

# Pulls the image from the source registry.
Function Pull-SourceImage {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ECRSourceImage
    )
    # Obtain source registry from the source image url.
    $SourceRegistry = $ECRSourceImage.Split("/")[0]

    if (-not $PullFromPublicECR) {
        # Login into ECR of source.
        Write-Host "Logging into ECR repository where source image is located: ${SourceRegistry}"
        Login-ECR -Region $SourceRegion -Registry $SourceRegistry
    }

    # Pull image from ECR.
    Write-Host "Pulling the image ${ECRSourceImage} from ECR"
    Invoke-Expression "docker pull ${ECRSourceImage}"

    # Throw an error if docker pull fails.
    if ($LASTEXITCODE) {
        throw "failed to pull ${ECRSourceImage} image from ECR"
    }

    # Invoke docker images to log the images which are present on the instance.
    Write-Host "Images present on the instance are-"
    Invoke-Expression "docker images"
}

# Pushes the image to the target registry.
Function Push-TargetImage {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ECRSourceImage,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetImage
    )
    # Obtain target registry from target image url.
    $TargetRegistry = $TargetImage.Split("/")[0]

    if ($PushToDockerHub){
        # Login into dockerhub.
        Login-DockerHub
    }
    elseif ($PushToPublicECR)
    {
        # Log in to Public ECR.
        Login-PublicECR -Registry $TargetRegistry
    }
    else{
        # Log in to ECR of target region and account.
        Login-ECR -Region $TargetRegion -Registry $TargetRegistry
    }

    # Tag source image to target image
    docker tag $ECRSourceImage $TargetImage
    # Throw an error if docker tag fails.
    if ($LASTEXITCODE) {
        throw "failed to tag ${TargetImage} image from ${ECRSourceImage}"
    }

    # Push image to ECR or dockerhub.
    Write-Host "Pushing the image ${TargetImage}"
    Invoke-Expression "docker push ${TargetImage}"

    # Throw an error if docker push fails.
    if ($LASTEXITCODE) {
        throw "failed to push ${TargetImage} image"
    }
}

# Validate input parameters.
Test-Parameters

# Select the base image tag based on the platform
switch ($Platform) {
    "windows2019" {
        $BaseImageTag = "ltsc2019"
    }

    "windows2022" {
        $BaseImageTag = "ltsc2022"
    }
}

# Get the source and target image urls.
$SourceImageURL = Get-SourceImageURL -BaseImageTag $BaseImageTag
$TargetImageURL = Get-TargetImageURL -BaseImageTag $BaseImageTag

# Pull the source image from source repository.
Pull-SourceImage -ECRSourceImage $SourceImageURL

# If TargetRoleArn is provided then assume that role.
if ($TargetRoleArn) {
    Assume-Role -RoleArn $TargetRoleArn
}

# Push the target image to target repository.
Push-TargetImage -ECRSourceImage $SourceImageURL -TargetImage $TargetImageURL

# Logout from docker
docker logout

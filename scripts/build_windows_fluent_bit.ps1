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
    Builds the Windows artifacts for fluent-bit supported by AWS

    .DESCRIPTION
    This script builds the Windows artifacts for fluent-bit supported by AWS

    .PARAMETER FLB_VERSION
    Specifies the fluent bit version to be used for the build

    .PARAMETER OPENSSL_VERSION
    Specifies the OpenSSL version to be used for the build

    .PARAMETER FLEX_BISON_VERSION
    Specifies the Flex Bison version to be used for the build

    .PARAMETER FLB_REPOSITORY_URL
    [Optional] Specifies the fluent bit repository to be used for the build. Defaults to 'https://github.com/fluent/fluent-bit'.

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    None. This script does not generate an output object.

    .EXAMPLE
    PS> .\build_windows_fluent_bit.ps1 -FLB_VERSION "1.9.4"
    Builds the Windows artifacts based on fluent bit 1.9.4.

    .EXAMPLE
    PS> .\build_windows_fluent_bit.ps1 -FLB_VERSION "1.9.4" -OPENSSL_VERSION 3.0.7 -FLEX_BISON_VERSION 2.5.22 -FLB_REPOSITORY_URL "https://github.com/xxxxx/fluent-bit"
    Builds the Windows artifacts based on fluent bit 1.9.4 from the xxxxx fork of fluent-bit.
    OpenSSL version used in the build would be 3.0.7 and the FlexBison version would be 2.5.22.
    Beneficial for dev testing.
#>

Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$FLB_VERSION,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OPENSSL_VERSION,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$FLEX_BISON_VERSION,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FLB_REPOSITORY_URL = "https://github.com/fluent/fluent-bit"
)

$ErrorActionPreference = 'Stop'

# Directory paths
$BaseDir = "C:\build"
$StagingDirectory = "C:\staging\fluent-bit"
$FluentBitBaseDirectory = "${BaseDir}\fluent-bit"
$AWSForFluentBitRootDir = "${PSScriptRoot}\.."
$VCRootPath = "C:\BuildTools"

# Paths of various installations
$CmakePath = "${VCRootPath}\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$VCToolsPath = "${VCRootPath}\VC\Auxiliary\Build"
$PerlPath = "C:\Strawberry\perl\bin"
$NASMPath = "${env:ProgramFiles}\NASM"
$FlexBisonPath = "C:\WinFlexBison"
$GitInstallationPath = "${env:ProgramFiles}\Git\cmd"
$OpenSSLInstallationPath = "${env:ProgramFiles}\OpenSSL"

# All the URLS.
$VisualStudioDownloadURL = "https://aka.ms/vs/16/release/vs_buildtools.exe"
$VisualStudioChannelURL = "https://aka.ms/vs/16/release/channel"
$FlexBisonDownloadURL = "https://github.com/lexxmark/winflexbison/releases/download/v${FLEX_BISON_VERSION}/win_flex_bison-${FLEX_BISON_VERSION}.zip"

# Create working directories
Write-Host "Creating the build directory"
New-Item -Path $BaseDir -ItemType Directory
New-Item -Path $OpenSSLInstallationPath -ItemType Directory
New-Item -Path "${AWSForFluentBitRootDir}\build\windows" -ItemType Directory
New-Item -Path $StagingDirectory -ItemType Directory
# Create directory structure inside staging folder
New-Item -Path "$StagingDirectory\bin" -ItemType Directory
New-Item -Path "$StagingDirectory\etc" -ItemType Directory
New-Item -Path "$StagingDirectory\log" -ItemType Directory
New-Item -Path "$StagingDirectory\parsers" -ItemType Directory
New-Item -Path "$StagingDirectory\configs" -ItemType Directory
New-Item -Path "$StagingDirectory\licenses\fluent-bit" -ItemType Directory
cd $BaseDir

# Install Chocolatey as per instructions from https://chocolatey.org/install
Set-ExecutionPolicy Bypass -Scope Process -Force;
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Git
Write-Host "Installing Git..."
choco install git -y
if ($LASTEXITCODE)
{
    throw ("Failed to install git using chocolatey")
}
Write-Host "Git installation completed."

# Download Microsoft Visual C++ to compile Fluent Bit
Write-Host "Downloading Microsoft Visual C++"
(New-Object System.Net.WebClient).DownloadFile($VisualStudioDownloadURL, "$BaseDir/vs_buildtools.exe")
(New-Object System.Net.WebClient).DownloadFile($VisualStudioChannelURL, "$BaseDir/VisualStudio.chman")

# Install Microsoft Visual C++
Write-Host "Installaing Microsoft Visual C++ ..."
Start-Process "$BaseDir/vs_buildtools.exe" `
-ArgumentList "--quiet", "--wait", "--norestart ", "--nocache", `
"--installPath $VCRootPath", `
"--channelUri $BaseDir\VisualStudio.chman", `
"--installChannelUri $BaseDir\VisualStudio.chman", `
"--add Microsoft.VisualStudio.Workload.VCTools", `
"--includeRecommended" -NoNewWindow -Wait;
if ($LASTEXITCODE)
{
    throw "Failed to install Microsoft Visual C++"
}
Write-Host "Installation of Microsoft Visual C++ completed."

# Find the version of VC and set the path for NMake
$VCVersion = (Get-ChildItem -Path "${VCRootPath}\VC\Tools\MSVC")[0].Name
$NmakePath = "${VCRootPath}\VC\Tools\MSVC\${VCVersion}\bin\Hostx64\x64"

# Download FlexBison as suggsted by https://docs.fluentbit.io/manual/installation/windows
Write-Host "Downloading Flex and Bison."
(New-Object System.Net.WebClient).DownloadFile($FlexBisonDownloadURL, "$BaseDir/win_flex_bison.zip")

# Expand and copy the flex and bison binaries
Write-Host "Setting up Flex and Bison on the instance."
Expand-Archive "$BaseDir/win_flex_bison.zip" -Destination "${FlexBisonPath}";
Copy-Item -Path "C:/WinFlexBison/win_bison.exe" "${FlexBisonPath}\bison.exe";
Copy-Item -Path "C:/WinFlexBison/win_flex.exe" "${FlexBisonPath}\flex.exe";

# Install strawberry perl which is a requirement for building OpenSSL
choco install strawberryperl -y
# Install NASM which required for building OpenSSL
choco install nasm -y

# Initialize environment for VC
$tempFile = [IO.Path]::GetTempFileName()
# Store the output of cmd.exe.  We also ask cmd.exe to output
# the environment table after the batch file completes.
# Borrowed from Powershell Community Extensions
# https://github.com/Pscx/Pscx
cmd.exe /c " `"${VCToolsPath}\vcvars64.bat`" && set > `"$tempFile`" "
if ($LASTEXITCODE)
{
    throw "Failed to initialize environment for Microsoft Visual C++"
}

# Go through the environment variables in the temp file.
# For each of them, set the variable in our local environment.
Get-Content $tempFile | Foreach-Object {
    if ($_ -match "^(.*?)=(.*)$")
    {
        Set-Content "env:\$($matches[1])" $matches[2]
    }
}
Remove-Item $tempFile

# Set the environment variables
Write-Host "Setting up the required environment variables."
$env:Path=$env:Path + ";${GitInstallationPath};${CmakePath};${NmakePath};${VCToolsPath};${PerlPath};${NASMPath};${FlexBisonPath}"

# Configure git config
git config --global user.email "aws-firelens@amazon.com"
git config --global user.name "FireLens Team"

# Clone and build OpenSSL
# https://github.com/openssl/openssl/blob/master/NOTES-WINDOWS.md
Write-Host "Cloning OpenSSL repository"
cd $BaseDir
git clone https://github.com/openssl/openssl.git
cd openssl

# Fetch the required version
git fetch --all --tags
git checkout tags/"openssl-${OPENSSL_VERSION}" -b "openssl-${OPENSSL_VERSION}"
git describe --tags

# Run perl configure as mentioned in the docs
perl Configure VC-WIN64A enable-fips no-shared
if ($LASTEXITCODE)
{
    throw "Failed to initialize environment for Openssl"
}

# Build the target in the makefile
nmake /S
if ($LASTEXITCODE)
{
    throw "Failed to build release for Openssl"
}

# Run test target
nmake test VERBOSE_FAILURE=yes HARNESS_JOBS=4
if ($LASTEXITCODE)
{
    throw "Failed to run test target"
}

# Install the openssl artifacts
nmake install
if ($LASTEXITCODE)
{
    throw "Failed to install the openssl"
}

# Clone the fluent-bit repository
Write-Host "Cloning fluent-bit upstream repository."
cd $BaseDir
git clone $FLB_REPOSITORY_URL
cd fluent-bit

# Fetch the required version
git fetch --all --tags
git checkout tags/v${FLB_VERSION} -b v${FLB_VERSION}
git describe --tags
cd build

# Apply fluent-bit patches, if any.
$content = Get-Content -Path "${AWSForFluentBitRootDir}\AWS_FLB_CHERRY_PICKS"
$lines = $content | Select-String -Pattern "^#" -NotMatch
if ($lines.length -gt 0)
{
    $lines | ForEach-Object {
        $token = $_ -split '\s+'
        git fetch $token[0] $token[1]
        git cherry-pick $token[2]
    }
    Write-Host "Cherry Pick Patch Summary:"
    git log --oneline -$($lines.length + 1)
}

# Build fluent-bit
cmake -G "Visual Studio 16 2019" -DCMAKE_BUILD_TYPE=Release -DFLB_RELEASE=On -DOPENSSL_ROOT_DIR="${OpenSSLInstallationPath}" ../
cmake --build . --config Release
if ($LASTEXITCODE)
{
    throw "Failed to build fluent-bit artifacts"
}

# Copy the built binaries to the staging folder
Copy-Item -Path "${FluentBitBaseDirectory}\build\bin\Release\fluent-bit.exe" -Destination "${StagingDirectory}\bin"
Copy-Item -Path "${FluentBitBaseDirectory}\build\bin\Release\fluent-bit.dll" -Destination "${StagingDirectory}\bin"
Copy-Item -Path "${FluentBitBaseDirectory}\build\bin\Release\fluent-bit.pdb" -Destination "${StagingDirectory}\bin"

# Copy various configurations
Copy-Item -Path "${FluentBitBaseDirectory}\conf\parsers*.conf" -Destination "${StagingDirectory}\etc"
# /fluent-bit/etc is overwritten by FireLens, so its users will use /fluent-bit/parsers/
Copy-Item -Path "${FluentBitBaseDirectory}\conf\parsers*.conf" -Destination "${StagingDirectory}\parsers"

Copy-Item -Path "${AWSForFluentBitRootDir}\fluent-bit.conf" -Destination "${StagingDirectory}\etc"
Copy-Item -Path "${AWSForFluentBitRootDir}\configs\parse-json.conf" -Destination "${StagingDirectory}\configs"
Copy-Item -Path "${AWSForFluentBitRootDir}\configs\minimize-log-loss.conf" -Destination "${StagingDirectory}\configs"

# Copy license
Copy-Item -Path "${AWSForFluentBitRootDir}\THIRD-PARTY" -Destination "${StagingDirectory}\licenses\fluent-bit"

# Compress the folder
Compress-Archive -Path "${StagingDirectory}\*" -Destination "${AWSForFluentBitRootDir}\build\windows\fluent-bit.zip"

# Compress ecs_windows_forward_daemon folder which needs to be added to the image
Compress-Archive -Path "${AWSForFluentBitRootDir}\ecs_windows_forward_daemon\*" -Destination "${AWSForFluentBitRootDir}\build\windows\ecs_windows_forward_daemon.zip"

# Copy the version of aws-for-fluent-bit
Copy-Item -Path "${AWSForFluentBitRootDir}\AWS_FOR_FLUENT_BIT_VERSION" -Destination "${AWSForFluentBitRootDir}\build\windows\AWS_FOR_FLUENT_BIT_VERSION"

# Copy the entrypoint script which needs to be added to the image
Copy-Item -Path "${AWSForFluentBitRootDir}\scripts\entrypoint.ps1" -Destination "${AWSForFluentBitRootDir}\build\windows\entrypoint.ps1"

# Copy the dockerfile used to build an image. This would ensure that the images remains constant in time.
Copy-Item -Path "${AWSForFluentBitRootDir}\scripts\dockerfiles\Dockerfile.windows" -Destination "${AWSForFluentBitRootDir}\build\windows\Dockerfile.windows"

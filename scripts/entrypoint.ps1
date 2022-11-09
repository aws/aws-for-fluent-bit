<#
    .SYNOPSIS
    Runs the aws-for-fluent-bit Windows image with the provided config.

    .DESCRIPTION
    This script runs the aws-for-fluent-bit Windows image with the provided config.

    .PARAMETER ConfigFile
    [Optional] Specifies the region. Defaults to 'C:\fluent-bit\etc\fluent-bit.conf'.

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    None. This script does not generate an output object.

    .EXAMPLE
    PS> .\entrypoint.ps1 -ConfigFile "C:\ecs_windows\cloudwatch.conf"
    Runs the aws-for-fluent-bit Windows image with the CloudWatch config baked into the image.
#>
Param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigFile = "C:\fluent-bit\etc\fluent-bit.conf"
)

$version = Get-Content -Path "C:\AWS_FOR_FLUENT_BIT_VERSION"
Write-Host "AWS for Fluent Bit Container Image Version ${version}"

C:\fluent-bit\bin\fluent-bit.exe -e C:\fluent-bit\kinesis.dll -e C:\fluent-bit\firehose.dll -e C:\fluent-bit\cloudwatch.dll -c "${ConfigFile}"
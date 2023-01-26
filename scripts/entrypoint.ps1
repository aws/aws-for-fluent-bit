<#
    .SYNOPSIS
    Runs the aws-for-fluent-bit Windows image with the provided config.

    .DESCRIPTION
    This script runs the aws-for-fluent-bit Windows image with the provided config.

    .PARAMETER ConfigFile
    [Optional] Specifies the region. Defaults to 'C:\fluent-bit\etc\fluent-bit.conf'.

    .PARAMETER EnableCoreDump
    [Optional] Specifies if the core dump needs to be generated on Fluent Bit crash. Defaults to false.
    The dump is generated at location 'C:\fluent-bit\CrashDumps' inside the container and needs to be bind-mounted to the host to retrieve the same.

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    None. This script does not generate an output object.

    .EXAMPLE
    PS> .\entrypoint.ps1 -ConfigFile "C:\ecs_windows_forward_daemon\cloudwatch.conf"
    Runs the aws-for-fluent-bit Windows image with the CloudWatch config baked into the image.
#>
Param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigFile = "C:\fluent-bit\etc\fluent-bit.conf",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableCoreDump
)

$version = Get-Content -Path "C:\AWS_FOR_FLUENT_BIT_VERSION"
Write-Host "AWS for Fluent Bit Container Image Version ${version}"

$PluginsToBindParams = "-e C:\fluent-bit\kinesis.dll -e C:\fluent-bit\firehose.dll -e C:\fluent-bit\cloudwatch.dll"

if ($EnableCoreDump) {
    Write-Host "Setting the registry keys to collect dumps"

    # Setting registry keys based on https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "LocalDumps"
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" -Name "DumpFolder" -Value "C:\fluent-bit\CrashDumps" -PropertyType ExpandString
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" -Name "DumpType" -Value 2 -PropertyType DWord

    # On Windows, the external plugins which we bind are Golang based. Golang presently has an issue wherein it
    # disables the WER and itercepts all the exceptions. However, crashing in native way is not yet supported.
    # This leads to crash dumps not generated,
    # Github issue: https://github.com/golang/go/issues/20498
    # Therefore, we will not bind the Golang plugins when in debug mode.
    # We recommend that the corresponding core plugins are used instead of the Golang plugins.
    $PluginsToBindParams = ""
}

C:\fluent-bit\bin\fluent-bit.exe "${PluginsToBindParams}" -c "${ConfigFile}"
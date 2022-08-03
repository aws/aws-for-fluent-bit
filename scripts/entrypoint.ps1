$version = Get-Content -Path "C:\AWS_FOR_FLUENT_BIT_VERSION"
Write-Host "AWS for Fluent Bit Container Image Version ${version}"

C:\fluent-bit\bin\fluent-bit.exe -e C:\fluent-bit\kinesis.dll -e C:\fluent-bit\firehose.dll -e C:\fluent-bit\cloudwatch.dll -c C:\fluent-bit\etc\fluent-bit.conf
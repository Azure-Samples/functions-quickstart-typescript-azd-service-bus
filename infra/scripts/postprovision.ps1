$ErrorActionPreference = "Stop"

Write-Host "Running post-provision script..." -ForegroundColor Yellow

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is required to update src/local.settings.json."
}

$outputJson = azd env get-values --output json
if ($LASTEXITCODE -ne 0) {
    throw "Failed to get environment values from azd."
}

Write-Host "Creating/updating src/local.settings.json..." -ForegroundColor Yellow

# The helper validates the azd output and merges into any existing file so user-added settings are preserved.
$helper = Join-Path $PSScriptRoot "update-local-settings.mjs"
$settingsPath = Join-Path "src" "local.settings.json"
$serviceBusValues = @(($outputJson -join "`n") | node $helper $settingsPath)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to update $settingsPath."
}
$ServiceBusNamespace = $serviceBusValues[0]
$ServiceBusQueueName = $serviceBusValues[1]

Write-Host "src/local.settings.json has been created/updated successfully!" -ForegroundColor Green
Write-Host "Creating/updating send-message.ps1..." -ForegroundColor Yellow

@"
az rest --method POST --uri 'https://$ServiceBusNamespace/$ServiceBusQueueName/messages' --headers 'Content-Type=application/atom+xml;type=entry;charset=utf-8' --body 'Hello from the CLI' --resource 'https://servicebus.azure.net'
exit `$LASTEXITCODE
"@ | Out-File -FilePath ".\send-message.ps1" -Encoding utf8 -Force

Write-Host "send-message.ps1 has been created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Service Bus Namespace: $ServiceBusNamespace" -ForegroundColor Cyan
Write-Host "Service Bus Queue: $ServiceBusQueueName" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now run the function locally with 'cd src && func start'" -ForegroundColor Green
Write-Host "Send test messages with './send-message.ps1'" -ForegroundColor Green

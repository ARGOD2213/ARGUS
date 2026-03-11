param(
    [string]$FunctionName = "argodreign-rule-engine",
    [string]$Region = "ap-south-1",
    [string]$Runtime = "python3.12",
    [string]$Handler = "handler.lambda_handler",
    [string]$RulesBucket = "iot-alert-engine-mahindra",
    [string]$RulesKey = "config/rules.json",
    [string]$RulesFilePath = "C:\Users\pavan\Desktop\ARGODREIGN\lambda\rule_engine\config\rules.json",
    [string]$CodeFilePath = "C:\Users\pavan\Desktop\ARGODREIGN\lambda\rule_engine\handler.py",
    [string]$SnsTopicArn = "arn:aws:sns:ap-south-1:061039801536:iot-alerts",
    [string]$DedupTable = "argodreign-dedup",
    [int]$Timeout = 30,
    [int]$MemorySize = 256,
    [string]$RoleArn = "",
    [switch]$CreateIfMissing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $RulesFilePath)) {
    throw "Rules file not found: $RulesFilePath"
}
if (-not (Test-Path $CodeFilePath)) {
    throw "Lambda handler file not found: $CodeFilePath"
}

Write-Host "Uploading rules config to S3..."
aws s3 cp "$RulesFilePath" "s3://$RulesBucket/$RulesKey" --region "$Region"

$tmpDir = Join-Path $env:TEMP ("argodreign-rule-engine-" + [guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $tmpDir -Force
$zipPath = Join-Path $tmpDir "rule-engine.zip"

try {
    Copy-Item $CodeFilePath (Join-Path $tmpDir "handler.py") -Force
    Compress-Archive -Path (Join-Path $tmpDir "handler.py") -DestinationPath $zipPath -Force

    $exists = $true
    try {
        aws lambda get-function --function-name "$FunctionName" --region "$Region" --output json | Out-Null
    }
    catch {
        $exists = $false
    }

    if ($exists) {
        Write-Host "Updating existing Lambda function: $FunctionName"
        aws lambda update-function-code `
            --function-name "$FunctionName" `
            --zip-file "fileb://$zipPath" `
            --region "$Region" | Out-Null

        aws lambda update-function-configuration `
            --function-name "$FunctionName" `
            --handler "$Handler" `
            --runtime "$Runtime" `
            --timeout $Timeout `
            --memory-size $MemorySize `
            --environment "Variables={RULES_BUCKET=$RulesBucket,RULES_KEY=$RulesKey,SNS_TOPIC_ARN=$SnsTopicArn,DEDUP_TABLE=$DedupTable}" `
            --region "$Region" | Out-Null
    }
    else {
        if (-not $CreateIfMissing) {
            throw "Lambda function '$FunctionName' not found. Re-run with -CreateIfMissing and -RoleArn."
        }
        if ([string]::IsNullOrWhiteSpace($RoleArn)) {
            throw "RoleArn is required when creating Lambda for the first time."
        }

        Write-Host "Creating new Lambda function: $FunctionName"
        aws lambda create-function `
            --function-name "$FunctionName" `
            --runtime "$Runtime" `
            --handler "$Handler" `
            --role "$RoleArn" `
            --zip-file "fileb://$zipPath" `
            --timeout $Timeout `
            --memory-size $MemorySize `
            --environment "Variables={RULES_BUCKET=$RulesBucket,RULES_KEY=$RulesKey,SNS_TOPIC_ARN=$SnsTopicArn,DEDUP_TABLE=$DedupTable}" `
            --region "$Region" | Out-Null
    }
}
finally {
    if (Test-Path $tmpDir) {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Rule engine Lambda deployed: $FunctionName"
Write-Host "Rules source: s3://$RulesBucket/$RulesKey"
Write-Host ""
Write-Host "Next (one-time if not done):"
Write-Host "1) Ensure SQS trigger is mapped to this Lambda."
Write-Host "2) Ensure DynamoDB table '$DedupTable' exists with PK: dedup_key and TTL: expires_at."
Write-Host "3) Test with a sample event from lambda/rule_engine/test_events."

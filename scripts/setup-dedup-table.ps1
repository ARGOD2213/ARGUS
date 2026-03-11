param(
    [string]$TableName = "argodreign-dedup",
    [string]$Region = "ap-south-1",
    [string]$PartitionKey = "dedup_key",
    [string]$TtlAttribute = "expires_at"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$exists = $true
try {
    aws dynamodb describe-table --table-name "$TableName" --region "$Region" --output json | Out-Null
}
catch {
    $exists = $false
}

if (-not $exists) {
    Write-Host "Creating DynamoDB table: $TableName"
    aws dynamodb create-table `
        --table-name "$TableName" `
        --attribute-definitions "AttributeName=$PartitionKey,AttributeType=S" `
        --key-schema "AttributeName=$PartitionKey,KeyType=HASH" `
        --billing-mode PAY_PER_REQUEST `
        --region "$Region" | Out-Null

    Write-Host "Waiting for table to become ACTIVE..."
    aws dynamodb wait table-exists --table-name "$TableName" --region "$Region"
}
else {
    Write-Host "Table already exists: $TableName"
}

Write-Host "Enabling TTL on attribute: $TtlAttribute"
aws dynamodb update-time-to-live `
    --table-name "$TableName" `
    --time-to-live-specification "Enabled=true,AttributeName=$TtlAttribute" `
    --region "$Region" | Out-Null

Write-Host "Done. Table '$TableName' is ready for rule-engine dedup."

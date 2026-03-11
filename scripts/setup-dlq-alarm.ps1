param(
    [string]$Region = "ap-south-1",
    [string]$DlqName = "iot-events-dlq.fifo",
    [string]$AlarmName = "argodreign-iot-dlq-depth",
    [string]$SnsTopicArn = "arn:aws:sns:ap-south-1:061039801536:iot-alerts"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Creating/updating CloudWatch alarm: $AlarmName"
Write-Host "Queue: $DlqName"
Write-Host "Action SNS: $SnsTopicArn"

aws cloudwatch put-metric-alarm `
    --alarm-name "$AlarmName" `
    --alarm-description "ARGODREIGN: DLQ has failed safety events" `
    --namespace "AWS/SQS" `
    --metric-name "ApproximateNumberOfMessagesVisible" `
    --dimensions "Name=QueueName,Value=$DlqName" `
    --statistic "Maximum" `
    --period 60 `
    --evaluation-periods 1 `
    --datapoints-to-alarm 1 `
    --threshold 0 `
    --comparison-operator "GreaterThanThreshold" `
    --treat-missing-data "notBreaching" `
    --alarm-actions "$SnsTopicArn" `
    --region "$Region"

Write-Host "Alarm configured. Any DLQ depth > 0 will trigger SNS."

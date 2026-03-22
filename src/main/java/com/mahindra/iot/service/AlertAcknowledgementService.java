package com.mahindra.iot.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;

import java.time.Instant;
import java.util.*;

@Service
public class AlertAcknowledgementService {

    private final DynamoDbClient dynamo;
    private final SnsClient sns;
    private final String table;
    private final String snsTopicArn;

    public AlertAcknowledgementService(
            DynamoDbClient dynamo,
            SnsClient sns,
            @Value("${aws.dynamodb.table:iot-sensor-events}") String table,
            @Value("${aws.sns.topic.arn}") String snsTopicArn) {
        this.dynamo      = dynamo;
        this.sns         = sns;
        this.table       = table;
        this.snsTopicArn = snsTopicArn;
    }

    /**
     * Acknowledge an alert. Writes ack record to DynamoDB.
     * Key: "ack#" + alertId — separate from the original alert record.
     * ADR-004 compliant: DynamoDB for operational metadata, not raw sensor data.
     */
    public AckResult acknowledge(String alertId, String operatorId, String note) {
        String ackedAt = Instant.now().toString();
        long ttlEpoch  = Instant.now().plusSeconds(90L * 24 * 3600).getEpochSecond();

        Map<String, AttributeValue> item = new HashMap<>();
        item.put("alertId",        AttributeValue.fromS("ack#" + alertId));
        item.put("originalAlertId",AttributeValue.fromS(alertId));
        item.put("ackStatus",      AttributeValue.fromS("ACKNOWLEDGED"));
        item.put("acknowledgedBy", AttributeValue.fromS(operatorId));
        item.put("acknowledgedAt", AttributeValue.fromS(ackedAt));
        item.put("operatorNote",   AttributeValue.fromS(note));
        item.put("ttl",            AttributeValue.fromN(String.valueOf(ttlEpoch)));

        dynamo.putItem(PutItemRequest.builder()
            .tableName(table).item(item).build());

        return new AckResult(alertId, "ACKNOWLEDGED", operatorId, ackedAt, note);
    }

    /**
     * Escalate an unacknowledged CRITICAL alert via SNS.
     * Called when an alert has not been acknowledged within 5 minutes.
     * Rule engine retains final authority — this is operator notification only.
     */
    public void escalate(String alertId, String machineId,
                         String sensorType, String value) {
        String subject = "ESCALATION — Unacknowledged CRITICAL Alert: "
                         + machineId + "/" + sensorType;
        String message = String.format(
            """
            ARGUS ESCALATION NOTICE
            ─────────────────────────────
            Alert ID   : %s
            Machine    : %s
            Sensor     : %s
            Value      : %s
            Status     : CRITICAL — not acknowledged within 5 minutes
            Action     : Operator acknowledgement required immediately
            ─────────────────────────────
            AI ADVISORY | Not a control action | Rule engine has final authority
            """,
            alertId, machineId, sensorType, value);

        sns.publish(PublishRequest.builder()
            .topicArn(snsTopicArn)
            .subject(subject)
            .message(message)
            .build());
    }

    /**
     * Check if an alert has been acknowledged.
     */
    public boolean isAcknowledged(String alertId) {
        GetItemResponse r = dynamo.getItem(GetItemRequest.builder()
            .tableName(table)
            .key(Map.of("alertId", AttributeValue.fromS("ack#" + alertId)))
            .build());
        return r.hasItem();
    }

    /**
     * Get all CRITICAL alerts that are unacknowledged.
     * Uses scan with filter — acceptable at demo volumes.
     * For production: replace with GSI on severity + ackStatus.
     */
    public List<UnacknowledgedAlert> getUnacknowledged() {
        ScanResponse r = dynamo.scan(ScanRequest.builder()
            .tableName(table)
            .filterExpression(
                "severity = :sev AND begins_with(alertId, :prefix)")
            .expressionAttributeValues(Map.of(
                ":sev",    AttributeValue.fromS("CRITICAL"),
                ":prefix", AttributeValue.fromS("alert#")))
            .build());

        List<UnacknowledgedAlert> result = new ArrayList<>();
        for (Map<String, AttributeValue> item : r.items()) {
            String alertId = item.getOrDefault("alertId",
                AttributeValue.fromS("")).s();
            if (!isAcknowledged(alertId)) {
                String ts = item.getOrDefault("timestamp",
                    AttributeValue.fromS("")).s();
                long ageMinutes = 0;
                if (!ts.isEmpty()) {
                    ageMinutes = (Instant.now().getEpochSecond()
                        - Instant.parse(ts).getEpochSecond()) / 60;
                }
                result.add(new UnacknowledgedAlert(
                    alertId,
                    item.getOrDefault("machineId",  AttributeValue.fromS("")).s(),
                    item.getOrDefault("sensorType", AttributeValue.fromS("")).s(),
                    item.getOrDefault("value",      AttributeValue.fromS("")).s(),
                    ageMinutes
                ));
            }
        }
        result.sort(Comparator.comparingLong(UnacknowledgedAlert::ageMinutes).reversed());
        return result;
    }

    // ── Records ──────────────────────────────────────────────────────────────

    public record AckResult(
        String alertId,
        String status,
        String acknowledgedBy,
        String acknowledgedAt,
        String note
    ) {}

    public record UnacknowledgedAlert(
        String alertId,
        String machineId,
        String sensorType,
        String value,
        long   ageMinutes
    ) {}
}

package com.mahindra.iot.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;

import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Builds a chronological event timeline for a machine
 * by combining alert records and acknowledgement records
 * from DynamoDB.
 *
 * Event types:
 *   SENSOR_WARNING    — sensor breached WARNING threshold
 *   SENSOR_CRITICAL   — sensor breached CRITICAL threshold
 *   SENSOR_NORMAL     — sensor returned to normal range
 *   ALERT_ACKNOWLEDGED — operator acknowledged a CRITICAL alert
 *   AI_ADVISORY       — AI analysis was generated for the alert
 *
 * ADR-001: no threshold evaluation here — reads existing records only.
 * ADR-004: DynamoDB reads for operational events only.
 */
@Service
public class TimelineService {

    private final DynamoDbClient dynamo;
    private final String table;

    private static final DateTimeFormatter TIME_FMT =
        DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneOffset.UTC);
    private static final DateTimeFormatter DATE_FMT =
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").withZone(ZoneOffset.UTC);

    public TimelineService(
            DynamoDbClient dynamo,
            @Value("${aws.dynamodb.table:iot-sensor-events}") String table) {
        this.dynamo = dynamo;
        this.table  = table;
    }

    public MachineTimeline buildTimeline(String machineId, int hours) {
        Instant from = Instant.now().minusSeconds(hours * 3600L);
        String fromStr = from.toString();

        ScanResponse alerts = dynamo.scan(ScanRequest.builder()
            .tableName(table)
            .filterExpression(
                "machineId = :mid AND #ts >= :from " +
                "AND begins_with(alertId, :prefix)")
            .expressionAttributeNames(Map.of("#ts", "timestamp"))
            .expressionAttributeValues(Map.of(
                ":mid",    AttributeValue.fromS(machineId),
                ":from",   AttributeValue.fromS(fromStr),
                ":prefix", AttributeValue.fromS("alert#")))
            .build());

        ScanResponse acks = dynamo.scan(ScanRequest.builder()
            .tableName(table)
            .filterExpression(
                "begins_with(alertId, :ackPrefix) " +
                "AND #ts >= :from")
            .expressionAttributeNames(Map.of("#ts", "acknowledgedAt"))
            .expressionAttributeValues(Map.of(
                ":ackPrefix", AttributeValue.fromS("ack#alert#"),
                ":from",      AttributeValue.fromS(fromStr)))
            .build());

        List<TimelineEvent> events = new ArrayList<>();

        for (Map<String, AttributeValue> item : alerts.items()) {
            String severity = strVal(item, "severity");
            String ts       = strVal(item, "timestamp");
            String alertId  = strVal(item, "alertId");
            String sensor   = strVal(item, "sensorType");
            String value    = strVal(item, "value");
            String unit     = strVal(item, "unit");

            String type;
            String color;
            if ("CRITICAL".equals(severity)) {
                type  = "SENSOR_CRITICAL";
                color = "red";
            } else if ("WARNING".equals(severity)) {
                type  = "SENSOR_WARNING";
                color = "amber";
            } else {
                type  = "SENSOR_NORMAL";
                color = "green";
            }

            String detail = sensor + " " + value +
                (unit.isEmpty() ? "" : " " + unit) +
                " — " + severity;

            events.add(new TimelineEvent(
                formatTime(ts), epochOf(ts), ts,
                type, detail, color, alertId
            ));

            String aiNote = strVal(item, "aiAnalysis");
            if (!aiNote.isEmpty()) {
                events.add(new TimelineEvent(
                    formatTime(ts), epochOf(ts) + 1, ts,
                    "AI_ADVISORY",
                    "AI: " + truncate(aiNote, 120) +
                        " — AI ADVISORY | Not a control action",
                    "purple", alertId
                ));
            }
        }

        for (Map<String, AttributeValue> item : acks.items()) {
            String ts        = strVal(item, "acknowledgedAt");
            String operator  = strVal(item, "acknowledgedBy");
            String note      = strVal(item, "operatorNote");
            String origAlert = strVal(item, "originalAlertId");

            String detail = "Acknowledged by " + operator +
                (note.isEmpty() ? "" : ": " + truncate(note, 80));

            events.add(new TimelineEvent(
                formatTime(ts), epochOf(ts), ts,
                "ALERT_ACKNOWLEDGED",
                detail, "blue", origAlert
            ));
        }

        events.sort(Comparator.comparingLong(TimelineEvent::epoch));

        return new MachineTimeline(
            machineId, from.toString(),
            Instant.now().toString(),
            hours, events
        );
    }

    private String strVal(Map<String, AttributeValue> item, String key) {
        return item.getOrDefault(key, AttributeValue.fromS("")).s();
    }

    private String formatTime(String isoTs) {
        try { return TIME_FMT.format(Instant.parse(isoTs)); }
        catch (Exception e) { return isoTs.length() > 15 ? isoTs.substring(11,16) : isoTs; }
    }

    private long epochOf(String isoTs) {
        try { return Instant.parse(isoTs).getEpochSecond(); }
        catch (Exception e) { return 0L; }
    }

    private String truncate(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max) + "...";
    }

    public record TimelineEvent(
        String displayTime,
        long   epoch,
        String isoTimestamp,
        String type,
        String detail,
        String color,
        String relatedAlertId
    ) {}

    public record MachineTimeline(
        String machineId,
        String from,
        String to,
        int    hours,
        List<TimelineEvent> events
    ) {}
}

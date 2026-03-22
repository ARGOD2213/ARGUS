package com.mahindra.iot.controller;

import com.mahindra.iot.service.AlertAcknowledgementService;
import com.mahindra.iot.service.AlertAcknowledgementService.*;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/alerts")
public class AlertWorkflowController {

    private final AlertAcknowledgementService ackService;

    public AlertWorkflowController(AlertAcknowledgementService ackService) {
        this.ackService = ackService;
    }

    /**
     * POST /api/v1/alerts/{alertId}/acknowledge
     * Body: { "operatorId": "OP-01", "note": "Checked zone, NH3 at 18ppm" }
     *
     * Records operator acknowledgement in DynamoDB.
     * Cancels escalation timer for this alert.
     */
    @PostMapping("/{alertId}/acknowledge")
    public ResponseEntity<AckResult> acknowledge(
            @PathVariable String alertId,
            @RequestBody Map<String, String> body) {
        String operatorId = body.getOrDefault("operatorId", "UNKNOWN");
        String note       = body.getOrDefault("note", "");
        AckResult result  = ackService.acknowledge(alertId, operatorId, note);
        return ResponseEntity.ok(result);
    }

    /**
     * GET /api/v1/alerts/unacknowledged
     *
     * Returns all CRITICAL alerts that have not been acknowledged.
     * Sorted by age descending — oldest unacknowledged first.
     * Dashboard uses this to show the red urgency counter.
     */
    @GetMapping("/unacknowledged")
    public ResponseEntity<List<UnacknowledgedAlert>> unacknowledged() {
        return ResponseEntity.ok(ackService.getUnacknowledged());
    }

    /**
     * POST /api/v1/alerts/{alertId}/escalate
     * Body: { "machineId": "COMP-01", "sensorType": "GAS_LEAK", "value": "28.4" }
     *
     * Triggers SNS escalation notification.
     * Called by the dashboard after 5-minute unacknowledged timer expires.
     * Rule engine is NOT involved — this is operator notification only.
     */
    @PostMapping("/{alertId}/escalate")
    public ResponseEntity<Map<String, String>> escalate(
            @PathVariable String alertId,
            @RequestBody Map<String, String> body) {
        ackService.escalate(
            alertId,
            body.getOrDefault("machineId",  "UNKNOWN"),
            body.getOrDefault("sensorType", "UNKNOWN"),
            body.getOrDefault("value",      "?")
        );
        return ResponseEntity.ok(Map.of(
            "alertId", alertId,
            "action",  "ESCALATED",
            "message", "Escalation notification sent via SNS"
        ));
    }

    /**
     * GET /api/v1/alerts/{alertId}/ack-status
     *
     * Returns whether a specific alert has been acknowledged.
     * Used by dashboard to update the ACK button state on page refresh.
     */
    @GetMapping("/{alertId}/ack-status")
    public ResponseEntity<Map<String, Object>> ackStatus(
            @PathVariable String alertId) {
        boolean acked = ackService.isAcknowledged(alertId);
        return ResponseEntity.ok(Map.of(
            "alertId",       alertId,
            "acknowledged",  acked
        ));
    }
}

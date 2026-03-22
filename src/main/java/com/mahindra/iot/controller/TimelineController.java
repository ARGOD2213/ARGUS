package com.mahindra.iot.controller;

import com.mahindra.iot.service.TimelineService;
import com.mahindra.iot.service.TimelineService.*;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/timeline")
public class TimelineController {

    private final TimelineService timelineService;

    public TimelineController(TimelineService timelineService) {
        this.timelineService = timelineService;
    }

    @GetMapping
    public ResponseEntity<MachineTimeline> getTimeline(
            @RequestParam String machineId,
            @RequestParam(defaultValue = "24") int hours) {
        if (machineId == null || machineId.isBlank()) {
            throw new IllegalArgumentException("machineId is required");
        }
        if (hours < 1 || hours > 72) {
            hours = 24;
        }
        return ResponseEntity.ok(
            timelineService.buildTimeline(machineId, hours));
    }
}

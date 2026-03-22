package com.mahindra.iot.controller;

import com.mahindra.iot.service.CemsService;
import com.mahindra.iot.service.CemsService.*;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * CEMS Controller — Continuous Emission Monitoring System.
 * Provides current stack emission and effluent readings.
 * Environment Protection Act 1986 + CPCB guidelines compliance.
 */
@RestController
@RequestMapping("/api/v1/cems")
@CrossOrigin(origins = "*")
public class CemsController {

    private final CemsService cemsService;

    public CemsController(CemsService cemsService) {
        this.cemsService = cemsService;
    }

    /**
     * GET /api/v1/cems/current
     * Returns current CEMS readings with CPCB limit comparison.
     * Data is synthetic for demo mode.
     * Environment Protection Act 1986 + CPCB guidelines.
     */
    @GetMapping("/current")
    public ResponseEntity<CemsReport> getCurrent() {
        return ResponseEntity.ok(cemsService.getCurrentReadings());
    }
}

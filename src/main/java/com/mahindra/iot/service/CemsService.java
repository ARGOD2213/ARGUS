package com.mahindra.iot.service;

import org.springframework.stereotype.Service;
import java.time.Instant;
import java.util.*;

/**
 * CEMS — Continuous Emission Monitoring System service.
 * Returns current stack emission and effluent readings.
 * Data is synthetic for demo mode.
 * Real integration requires CEMS hardware API in Sprint 7+.
 *
 * Standards: Environment Protection Act 1986 (India)
 *            CPCB guidelines for fertilizer industry
 *            EP Act Section 15 — criminal liability for exceedance
 */
@Service
public class CemsService {

    public CemsReport getCurrentReadings() {
        List<CemsParameter> params = List.of(
            new CemsParameter(
                "STACK_NH3", "Stack NH3 Emission",
                18.4, "mg/Nm3", 50.0, 30.0,
                evaluateStatus(18.4, 30.0, 50.0, false),
                "CPCB limit 50 mg/Nm3",
                "Environment Protection Act 1986"),
            new CemsParameter(
                "STACK_NOX", "Stack NOx Emission",
                88.2, "ppm", 150.0, 100.0,
                evaluateStatus(88.2, 100.0, 150.0, false),
                "CPCB guideline 150 ppm",
                "Environment Protection Act 1986"),
            new CemsParameter(
                "STACK_SOX", "Stack SOx Emission",
                12.1, "ppm", 100.0, 80.0,
                evaluateStatus(12.1, 80.0, 100.0, false),
                "CPCB guideline 100 ppm",
                "Environment Protection Act 1986"),
            new CemsParameter(
                "EFFLUENT_PH", "Effluent pH",
                7.4, "pH", 6.5, 6.0,
                evaluateStatus(7.4, 6.5, 6.0, true),
                "CPCB range 6.5 to 9.0",
                "Environment Protection Act 1986"),
            new CemsParameter(
                "EFFLUENT_NH3", "Effluent NH3 Discharge",
                22.6, "mg/L", 50.0, 30.0,
                evaluateStatus(22.6, 30.0, 50.0, false),
                "CPCB limit 50 mg/L",
                "Environment Protection Act 1986"),
            new CemsParameter(
                "EFFLUENT_TDS", "Effluent TDS",
                1840.0, "mg/L", 2100.0, 2000.0,
                evaluateStatus(1840.0, 2000.0, 2100.0, false),
                "CPCB limit 2100 mg/L",
                "Environment Protection Act 1986")
        );

        long exceedances = params.stream()
            .filter(p -> "CRITICAL".equals(p.status())).count();
        long warnings    = params.stream()
            .filter(p -> "WARNING".equals(p.status())).count();
        String overallStatus = exceedances > 0 ? "NON_COMPLIANT"
                             : warnings    > 0 ? "WARNING"
                             :                   "COMPLIANT";

        return new CemsReport(
            params, overallStatus,
            exceedances, warnings,
            Instant.now().toString(),
            "SYNTHETIC_DEMO_DATA — real CEMS integration Sprint 7",
            "Monthly report due to SPCB by 7th of following month"
        );
    }

    private String evaluateStatus(double value, double warn,
                                     double crit, boolean invertedScale) {
        if (invertedScale) {
            if (value < crit) return "CRITICAL";
            if (value < warn) return "WARNING";
            return "NORMAL";
        }
        if (value >= crit) return "CRITICAL";
        if (value >= warn) return "WARNING";
        return "NORMAL";
    }

    public record CemsParameter(
        String parameterId,
        String name,
        double currentValue,
        String unit,
        double criticalLimit,
        double warningLimit,
        String status,
        String limitBasis,
        String regulation
    ) {}

    public record CemsReport(
        List<CemsParameter> parameters,
        String overallStatus,
        long   exceedanceCount,
        long   warningCount,
        String measuredAt,
        String dataNote,
        String reportingNote
    ) {}
}

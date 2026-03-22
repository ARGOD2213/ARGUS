package com.mahindra.iot.service;

import org.springframework.stereotype.Service;

@Service
public class FatigueAssessmentService {

    public FatigueResult assess(double shiftHours, int consecutiveDays,
                                int currentHour, double hoursSinceLastSleep) {
        int score = 0;
        if (shiftHours > 10) score += 35;
        else if (shiftHours > 8) score += 20;
        if (consecutiveDays > 5) score += 20;
        if (currentHour >= 2 && currentHour <= 6) score += 15;
        if (hoursSinceLastSleep < 6) score += 10;
        score = Math.min(score, 100);

        String status = score <= 50 ? "NORMAL"
                : score <= 70 ? "CAUTION"
                : score <= 85 ? "RESTRICTED" : "MANDATORY_REST";

        return new FatigueResult(
                score,
                status,
                "FAID-lite model. Supervisor approval required above score 70."
        );
    }

    public record FatigueResult(int score, String status, String message) {
    }
}

package com.dauviet.path.api;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.path.api.dto.LearnerLearningPathResponse;
import com.dauviet.path.application.LearnerPathProgressionService;

@RestController
@RequestMapping("/api/v1/me/learning-path")
public class LearnerLearningPathController {

    private final LearnerPathProgressionService service;
    private final JwtSubjectExtractor subjects;

    public LearnerLearningPathController(LearnerPathProgressionService service, JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    @GetMapping
    public LearnerLearningPathResponse learningPath(@AuthenticationPrincipal Jwt jwt) {
        return service.pathFor(subjects.userId(jwt));
    }

    @PostMapping("/periods/{periodCode}/touch")
    public LearnerLearningPathResponse.TouchPeriodResponse touchPeriod(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String periodCode) {
        return service.touchPeriod(subjects.userId(jwt), periodCode);
    }
}

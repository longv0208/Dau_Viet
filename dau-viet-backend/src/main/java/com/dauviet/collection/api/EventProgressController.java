package com.dauviet.collection.api;

import java.util.UUID;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.collection.api.dto.EventProgressResponse;
import com.dauviet.collection.application.EventProgressQueryService;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;

/**
 * Tiến độ hoàn thành event của learner hiện tại (GAME-04 §10). Path
 * user-scoped `/me/events/...` nên đặt trong collection.api — module
 * GAME-04 sở hữu, không đụng historicalevent module.
 */
@RestController
@RequestMapping("/api/v1/me/events")
public class EventProgressController {

    private final EventProgressQueryService service;
    private final HistoricalEventRepository events;
    private final JwtSubjectExtractor subjects;

    public EventProgressController(EventProgressQueryService service,
                                   HistoricalEventRepository events,
                                   JwtSubjectExtractor subjects) {
        this.service = service;
        this.events = events;
        this.subjects = subjects;
    }

    /**
     * GET /api/v1/me/events/{eventId}/progress — 404 khi event không tồn
     * tại (uniform, không lộ); NOT_CONFIGURED khi chưa publish policy.
     */
    @GetMapping("/{eventId}/progress")
    public EventProgressResponse progress(@PathVariable UUID eventId,
                                          @AuthenticationPrincipal Jwt jwt) {
        if (!events.existsById(eventId)) {
            throw new ResourceNotFoundException("event not found: " + eventId);
        }
        return service.progressOf(subjects.userId(jwt), eventId);
    }
}

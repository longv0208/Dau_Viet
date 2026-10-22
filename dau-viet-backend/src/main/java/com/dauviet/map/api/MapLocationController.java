package com.dauviet.map.api;

import java.util.List;
import java.util.UUID;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.map.api.dto.MapLocationDto;
import com.dauviet.map.application.MapLocationService;

/**
 * Learner Historical Map endpoints (FR-35..38). Authenticated; unlock state
 * computed server-side for the token subject — no client-supplied userId or
 * completion claims are honoured.
 */
@RestController
@RequestMapping("/api/v1/map/locations")
public class MapLocationController {

    private final MapLocationService service;
    private final JwtSubjectExtractor subjects;

    public MapLocationController(MapLocationService service,
                                 JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    @GetMapping
    public List<MapLocationDto> list(@AuthenticationPrincipal Jwt jwt) {
        return service.listForLearner(subjects.userId(jwt));
    }

    @GetMapping("/{locationId}")
    public MapLocationDto get(@PathVariable UUID locationId,
                              @AuthenticationPrincipal Jwt jwt) {
        return service.getForLearner(subjects.userId(jwt), locationId);
    }
}

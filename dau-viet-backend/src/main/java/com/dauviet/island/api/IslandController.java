package com.dauviet.island.api;

import java.util.UUID;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.island.api.dto.IslandPlacementRequest;
import com.dauviet.island.api.dto.IslandResponse;
import com.dauviet.island.api.dto.IslandUpgradeRequest;
import com.dauviet.island.application.IslandService;

/**
 * Đảo Di Sản của learner hiện tại (ISLAND-BE-01). Identity luôn từ JWT —
 * không nhận userId từ client, không tin expectedRevision cũ lệch.
 */
@RestController
@RequestMapping("/api/v1/me/island")
public class IslandController {

    private final IslandService service;
    private final JwtSubjectExtractor subjects;

    public IslandController(IslandService service,
                            JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /** Trạng thái đảo đầy đủ: tier + slot map + placements. */
    @GetMapping
    public IslandResponse island(@AuthenticationPrincipal Jwt jwt) {
        return service.islandOf(subjects.userId(jwt));
    }

    /** Nâng cấp lên tier kế tiếp đủ điều kiện. */
    @PostMapping("/upgrade")
    public IslandResponse upgrade(@AuthenticationPrincipal Jwt jwt,
            @RequestBody(required = false) IslandUpgradeRequest req) {
        return service.upgrade(subjects.userId(jwt),
                req == null ? null : req.expectedRevision());
    }

    /** Đặt vật phẩm vào ô đất. */
    @PutMapping("/placements/{slotId}")
    public IslandResponse place(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID slotId,
            @RequestBody IslandPlacementRequest req) {
        return service.placeItem(subjects.userId(jwt), slotId, req);
    }

    /** Gỡ vật phẩm khỏi ô đất. */
    @DeleteMapping("/placements/{slotId}")
    public IslandResponse remove(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID slotId,
            @RequestParam(required = false) Long expectedRevision) {
        return service.removePlacement(subjects.userId(jwt), slotId,
                expectedRevision);
    }
}

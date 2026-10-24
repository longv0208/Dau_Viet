package com.dauviet.collection.api;

import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.collection.api.dto.DossierDtos.DossierDetailResponse;
import com.dauviet.collection.api.dto.DossierDtos.DossierSummaryResponse;
import com.dauviet.collection.application.DossierService;
import com.dauviet.common.api.PageResponse;
import com.dauviet.common.security.JwtSubjectExtractor;

/**
 * Hồ sơ lịch sử của learner (GAME-04 §11). Literal `/dossiers` thắng
 * `/{evidenceId}` trong cùng base path nên không đụng CollectionController;
 * file tách riêng giữ controller < 200 dòng.
 */
@RestController
@RequestMapping("/api/v1/me/collection/dossiers")
public class DossierController {

    private static final int MAX_PAGE_SIZE = 50;

    private final DossierService service;
    private final JwtSubjectExtractor subjects;

    public DossierController(DossierService service,
                             JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /**
     * List dossier learner thấy được (PUBLISHED + ARCHIVED đã mở).
     * Filters: type PERSON/LOCATION/ARTIFACT/CONTEXT, eventId, unlocked.
     */
    @GetMapping
    public PageResponse<DossierSummaryResponse> list(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) UUID eventId,
            @RequestParam(required = false) Boolean unlocked,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal Jwt jwt) {
        Pageable pageable = PageRequest.of(Math.max(0, page),
                Math.min(Math.max(1, size), MAX_PAGE_SIZE));
        return service.list(subjects.userId(jwt), type, eventId, unlocked,
                pageable);
    }

    /** Chi tiết dossier — DRAFT và ARCHIVED chưa mở trả 404. */
    @GetMapping("/{dossierId}")
    public DossierDetailResponse detail(@PathVariable UUID dossierId,
                                        @AuthenticationPrincipal Jwt jwt) {
        return service.detail(subjects.userId(jwt), dossierId);
    }
}

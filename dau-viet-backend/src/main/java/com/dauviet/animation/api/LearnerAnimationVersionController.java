package com.dauviet.animation.api;

import java.util.UUID;

import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.animation.application.AnimationHtmlService;
import com.dauviet.animation.domain.AnimationSceneVersionHtml;

/**
 * Learner-facing HTML animation fetch: serves PUBLISHED version bytes to ANY
 * authenticated user (LEARNER or CONTENT_ADMIN) — same access pattern as
 * /api/v1/assets/{id}/content. Drafts are never exposed here.
 *
 * The body is consumed as DATA by the Flutter WebView (loadHtmlString) —
 * not navigated to — and carries a restrictive CSP + nosniff so it can
 * never execute in the admin/backend origin either.
 */
@RestController
@RequestMapping("/api/v1/animation-versions")
public class LearnerAnimationVersionController {

    private final AnimationHtmlService htmlService;

    public LearnerAnimationVersionController(AnimationHtmlService htmlService) {
        this.htmlService = htmlService;
    }

    @GetMapping("/{versionId}/html")
    public ResponseEntity<String> html(@PathVariable UUID versionId) {
        AnimationSceneVersionHtml v = htmlService.getPublishedHtml(versionId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/html; charset=utf-8"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                .header("X-Content-Type-Options", "nosniff")
                // Published bytes are immutable — safe to cache privately.
                .cacheControl(CacheControl.maxAge(1, java.util.concurrent.TimeUnit.HOURS)
                        .cachePrivate())
                .header("Content-Security-Policy",
                        "default-src 'none'; script-src 'unsafe-inline'; "
                                + "style-src 'unsafe-inline'; img-src data:; "
                                + "media-src data:; font-src data:; "
                                + "connect-src 'none'; frame-ancestors 'none'")
                .body(v.getContent());
    }
}

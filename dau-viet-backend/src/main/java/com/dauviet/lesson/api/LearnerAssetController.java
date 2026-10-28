package com.dauviet.lesson.api;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.lesson.application.AssetService;
import com.dauviet.lesson.application.AssetService.StoredAsset;
import java.util.UUID;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Learner-safe media endpoint: serves ACTIVE asset bytes to authenticated
 * users only when the asset is referenced by published learner content or
 * content pinned/owned by the requesting learner (while allowing CONTENT_ADMIN
 * full preview access).
 */
@RestController
@RequestMapping("/api/v1/assets")
public class LearnerAssetController {

    private static final String ADMIN_AUTHORITY = "ROLE_CONTENT_ADMIN";
    private static final String ADMIN_ROLE = "CONTENT_ADMIN";

    private final AssetService assetService;
    private final JwtSubjectExtractor subjects;

    public LearnerAssetController(AssetService assetService,
                                  JwtSubjectExtractor subjects) {
        this.assetService = assetService;
        this.subjects = subjects;
    }

    @GetMapping("/{id}/content")
    public ResponseEntity<FileSystemResource> content(
            @PathVariable UUID id,
            @AuthenticationPrincipal Jwt jwt,
            Authentication authentication) {
        StoredAsset a;
        if (isContentAdmin(jwt, authentication)) {
            a = assetService.content(id);
        } else {
            UUID userId = subjects.userId(jwt);
            a = assetService.learnerContent(id, userId);
        }
        FileSystemResource body = new FileSystemResource(a.path());
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(a.mimeType()))
                .contentLength(a.sizeBytes())
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "inline; filename=\"" + safeName(a.filename()) + "\"")
                .body(body);
    }

    private static boolean isContentAdmin(Jwt jwt, Authentication authentication) {
        if (authentication != null && authentication.getAuthorities() != null) {
            for (GrantedAuthority authority : authentication.getAuthorities()) {
                if (ADMIN_AUTHORITY.equals(authority.getAuthority())) {
                    return true;
                }
            }
        }
        return jwt != null && ADMIN_ROLE.equals(jwt.getClaimAsString("role"));
    }

    private static String safeName(String name) {
        return name == null ? "asset" : name.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}

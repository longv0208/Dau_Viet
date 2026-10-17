package com.dauviet.lesson.api;

import com.dauviet.lesson.application.AssetService;
import com.dauviet.lesson.application.AssetService.StoredAsset;
import java.util.UUID;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Learner-safe media endpoint: serves ACTIVE asset bytes to ANY authenticated
 * user (LEARNER or CONTENT_ADMIN). Admin metadata/upload stays under
 * /admin/assets — this only exposes the content stream for assets that have
 * already been referenced by published learner content.
 *
 * Route is /api/v1/assets/{id}/content — outside /admin/** so it does not
 * require CONTENT_ADMIN, and falls under SecurityConfig.anyRequest()
 * .authenticated(). Asset ids are unguessable UUIDs; state must be ACTIVE.
 */
@RestController
@RequestMapping("/api/v1/assets")
public class LearnerAssetController {

    private final AssetService assetService;

    public LearnerAssetController(AssetService assetService) {
        this.assetService = assetService;
    }

    @GetMapping("/{id}/content")
    public ResponseEntity<FileSystemResource> content(@PathVariable UUID id) {
        StoredAsset a = assetService.content(id);
        FileSystemResource body = new FileSystemResource(a.path());
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(a.mimeType()))
                .contentLength(a.sizeBytes())
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "inline; filename=\"" + safeName(a.filename()) + "\"")
                .body(body);
    }

    private static String safeName(String name) {
        return name == null ? "asset" : name.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}

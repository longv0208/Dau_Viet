package com.dauviet.lesson.api;

import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.core.io.FileSystemResource;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.common.api.PageResponse;
import com.dauviet.lesson.api.dto.AssetResponse;
import com.dauviet.lesson.application.AssetService;
import com.dauviet.lesson.application.AssetService.StoredAsset;

/**
 * Admin asset library: upload (multipart), list, detail and content serving.
 * Content is served under /admin/** so it inherits CONTENT_ADMIN auth —
 * learner-facing projection serves the same stable contentUrl downstream.
 */
@RestController
@RequestMapping("/api/v1/admin/assets")
@Validated
public class AdminAssetController {

    private static final Sort DEFAULT_SORT = Sort.by(Sort.Direction.DESC, "createdAt");

    private final AssetService service;

    public AdminAssetController(AssetService service) {
        this.service = service;
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public AssetResponse upload(@RequestPart("file") MultipartFile file,
                                @RequestParam(required = false) String altText,
                                @AuthenticationPrincipal Jwt jwt) {
        return service.upload(file, altText, adminId(jwt));
    }

    @GetMapping
    public PageResponse<AssetResponse> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "24") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String q) {
        Pageable pageable = PageRequest.of(page, size, DEFAULT_SORT);
        return PageResponse.from(service.list(q, pageable));
    }

    @GetMapping("/{id}")
    public AssetResponse get(@PathVariable UUID id) {
        return service.get(id);
    }

    @GetMapping("/{id}/content")
    public ResponseEntity<FileSystemResource> content(@PathVariable UUID id) {
        StoredAsset a = service.content(id);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(a.mimeType()))
                .contentLength(a.sizeBytes())
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "inline; filename=\"" + safeName(a.filename()) + "\"")
                .body(new FileSystemResource(a.path()));
    }

    private UUID adminId(Jwt jwt) {
        try {
            return UUID.fromString(jwt.getSubject());
        } catch (RuntimeException ex) {
            throw new AuthenticationFailedException();
        }
    }

    private String safeName(String name) {
        if (name == null) return "asset";
        return name.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}

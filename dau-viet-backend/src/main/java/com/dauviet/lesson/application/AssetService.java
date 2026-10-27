package com.dauviet.lesson.application;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.dauviet.lesson.api.dto.AssetResponse;
import com.dauviet.lesson.domain.Asset;
import com.dauviet.lesson.domain.AssetNotFoundException;
import com.dauviet.lesson.domain.InvalidAssetUploadException;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;

/**
 * Asset lifecycle: multipart upload -> local-disk storage -> ACTIVE row.
 * Dev uses a filesystem dir (dauviet.assets.dir); the serving contract
 * (contentUrl) stays stable so a future object-storage swap is invisible
 * to admin and learner clients.
 */
@Service
public class AssetService {

    private static final Map<String, String> ALLOWED_MIME_EXT = Map.of(
            "image/png", "png",
            "image/jpeg", "jpg",
            "image/webp", "webp",
            "audio/mpeg", "mp3",
            "audio/wav", "wav",
            "audio/x-wav", "wav",
            "audio/ogg", "ogg");
    private static final long MAX_BYTES = 10L * 1024 * 1024; // 10 MB dev cap
    private static final Set<String> ACTIVE = Set.of("ACTIVE");

    private final AssetRepository assets;
    private final Path storageDir;

    public AssetService(AssetRepository assets,
                        @Value("${dauviet.assets.dir:data/assets}") String dir) {
        this.assets = assets;
        this.storageDir = Path.of(dir).toAbsolutePath().normalize();
    }

    @Transactional
    public AssetResponse upload(MultipartFile file, String altText, UUID adminId) {
        if (file == null || file.isEmpty()) {
            throw new InvalidAssetUploadException("file is required and must not be empty");
        }
        if (file.getSize() > MAX_BYTES) {
            throw new InvalidAssetUploadException(
                    "file exceeds " + (MAX_BYTES / 1024 / 1024) + " MB limit");
        }
        String mime = file.getContentType() == null ? "" : file.getContentType().toLowerCase();
        String ext = ALLOWED_MIME_EXT.get(mime);
        if (ext == null) {
            throw new InvalidAssetUploadException(
                    "unsupported mime type '" + mime
                            + "' — allowed: PNG, JPEG, WebP, MP3, WAV, OGG");
        }

        UUID id = UUID.randomUUID();
        String checksum;
        try {
            Files.createDirectories(storageDir);
            checksum = writeFile(file, id, ext);
        } catch (IOException ex) {
            throw new InvalidAssetUploadException("failed to store file", ex);
        }

        Asset a = new Asset();
        a.setId(id);
        a.setStorageKey("assets/" + id + "." + ext);
        a.setOriginalFilename(file.getOriginalFilename());
        a.setMimeType(mime);
        a.setSizeBytes(file.getSize());
        a.setChecksumSha256(checksum);
        a.setState("ACTIVE");
        a.setAltText(altText);
        a.setCreatedBy(adminId);
        return toResponse(assets.saveAndFlush(a));
    }

    @Transactional(readOnly = true)
    public Page<AssetResponse> list(Pageable pageable) {
        return list(null, pageable);
    }

    @Transactional(readOnly = true)
    public Page<AssetResponse> list(String q, Pageable pageable) {
        if (q == null || q.isBlank()) {
            return assets.findAllByStateIn(ACTIVE, pageable).map(this::toResponse);
        }
        String qPattern = "%" + q.trim().toLowerCase( java.util.Locale.ROOT) + "%";
        return assets.searchActive(ACTIVE, qPattern, pageable).map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public AssetResponse get(UUID id) {
        return toResponse(load(id));
    }

    /** Locates the on-disk file for an ACTIVE asset, materializing classpath seed assets if needed. */
    @Transactional(readOnly = true)
    public StoredAsset content(UUID id) {
        Asset a = load(id);
        Path p = storageDir.resolve(id + "." + ext(a.getMimeType())).normalize();
        if (!p.startsWith(storageDir) || !Files.isRegularFile(p)) {
            materializeSeedAssetIfAvailable(a, p);
        }
        if (!p.startsWith(storageDir) || !Files.isRegularFile(p)) {
            throw new AssetNotFoundException("asset content missing: " + id);
        }
        long actualSize;
        try {
            actualSize = Files.size(p);
        } catch (IOException ex) {
            actualSize = a.getSizeBytes() == null ? 0L : a.getSizeBytes();
        }
        return new StoredAsset(p, a.getMimeType(), a.getOriginalFilename(), actualSize);
    }

    private void materializeSeedAssetIfAvailable(Asset a, Path target) {
        if (!target.startsWith(storageDir) || a.getOriginalFilename() == null) {
            return;
        }
        String filename = Path.of(a.getOriginalFilename()).getFileName().toString();
        List<String> candidates = List.of(
                "seed-assets/heritage/" + filename,
                "seed-assets/" + filename
        );
        for (String cp : candidates) {
            ClassPathResource resource = new ClassPathResource(cp);
            if (resource.exists()) {
                try (InputStream in = resource.getInputStream()) {
                    Files.createDirectories(storageDir);
                    Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
                    return;
                } catch (IOException ignored) {
                    // Fallback to standard 404 if disk copy fails
                }
            }
        }
    }

    private Asset load(UUID id) {
        return assets.findById(id)
                .filter(x -> ACTIVE.contains(x.getState()))
                .orElseThrow(() -> new AssetNotFoundException("Asset not found: " + id));
    }

    private String writeFile(MultipartFile file, UUID id, String ext) throws IOException {
        Path target = storageDir.resolve(id + "." + ext);
        try (InputStream in = file.getInputStream()) {
            Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
        }
        return sha256(target);
    }

    private String sha256(Path p) throws IOException {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(Files.readAllBytes(p)));
        } catch (NoSuchAlgorithmException ex) {
            throw new IOException("SHA-256 unavailable", ex);
        }
    }

    private String ext(String mime) {
        return ALLOWED_MIME_EXT.getOrDefault(mime, "bin");
    }

    private AssetResponse toResponse(Asset a) {
        return new AssetResponse(
                a.getId(),
                a.getOriginalFilename(),
                a.getMimeType(),
                a.getSizeBytes(),
                a.getState(),
                a.getAltText(),
                a.getCreatedAt(),
                "/api/v1/admin/assets/" + a.getId() + "/content");
    }

    /** File handle returned by {@link #content}. */
    public record StoredAsset(Path path, String mimeType, String filename, Long sizeBytes) {
    }

    /** List only ACTIVE assets (used by picker + publish validation). */
    public List<UUID> activeIds() {
        return assets.findActiveIds();
    }
}

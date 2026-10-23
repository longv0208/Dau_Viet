package com.dauviet.animation.application;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.animation.api.dto.AnimationDtos.TemplateCreateRequest;
import com.dauviet.animation.api.dto.AnimationDtos.TemplateResponse;
import com.dauviet.animation.api.dto.AnimationDtos.TemplateUpdateRequest;
import com.dauviet.animation.api.mapper.AnimationMapper;
import com.dauviet.animation.domain.AnimationExceptions.TemplateCodeTakenException;
import com.dauviet.animation.domain.AnimationExceptions.TemplateNotFoundException;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.animation.infrastructure.persistence.AnimationTemplateRepository;
import com.dauviet.animation.manifest.AnimationManifestSchema;
import com.dauviet.lesson.domain.AssetNotFoundException;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.persistence.criteria.Predicate;

/**
 * Admin-side template management. Templates are the bind point between
 * manifests and renderer codes — rendererCode itself is immutable after
 * create (changing it would invalidate every existing scene).
 */
@Service
public class AnimationTemplateService {

    private final AnimationTemplateRepository templates;
    private final AssetRepository assets;
    private final AnimationMapper mapper;
    private final ObjectMapper objectMapper;

    public AnimationTemplateService(AnimationTemplateRepository templates,
                                    AssetRepository assets,
                                    AnimationMapper mapper,
                                    ObjectMapper objectMapper) {
        this.templates = templates;
        this.assets = assets;
        this.mapper = mapper;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public TemplateResponse create(TemplateCreateRequest req) {
        if (templates.existsByCode(req.code())) {
            throw new TemplateCodeTakenException("template code taken: " + req.code());
        }
        if (!AnimationManifestSchema.RENDERER_CODES.contains(req.rendererCode())) {
            throw new IllegalArgumentException(
                    "unsupported rendererCode: " + req.rendererCode());
        }
        checkThumbnail(req.thumbnailAssetId());

        AnimationTemplate t = new AnimationTemplate();
        t.setId(UUID.randomUUID());
        t.setCode(req.code());
        t.setName(req.name());
        t.setDescription(req.description());
        t.setRendererCode(req.rendererCode());
        t.setRendererVersion(req.rendererVersion() == null ? 1 : req.rendererVersion());
        t.setSchemaVersion(req.schemaVersion() == null
                ? AnimationManifestSchema.CURRENT_SCHEMA_VERSION : req.schemaVersion());
        t.setCapabilitiesJson(requireJsonObject(req.capabilitiesJson(), "capabilitiesJson"));
        t.setDefaultConfigJson(requireJsonObject(req.defaultConfigJson(), "defaultConfigJson"));
        t.setThumbnailAssetId(req.thumbnailAssetId());
        t.setEnabled(req.enabled() == null ? Boolean.TRUE : req.enabled());
        return mapper.toTemplateResponse(templates.saveAndFlush(t));
    }

    @Transactional(readOnly = true)
    public Page<TemplateResponse> list(String rendererCode, Boolean enabled,
                                       String q, Pageable pageable) {
        Specification<AnimationTemplate> spec = (root, cq, cb) -> {
            List<Predicate> preds = new ArrayList<>();
            if (rendererCode != null) {
                preds.add(cb.equal(root.get("rendererCode"), rendererCode));
            }
            if (enabled != null) preds.add(cb.equal(root.get("enabled"), enabled));
            if (q != null && !q.isBlank()) {
                String like = "%" + q.trim().toLowerCase() + "%";
                preds.add(cb.or(
                        cb.like(cb.lower(root.get("name")), like),
                        cb.like(cb.lower(root.get("code")), like)));
            }
            return cb.and(preds.toArray(new Predicate[0]));
        };
        return templates.findAll(spec, pageable).map(mapper::toTemplateResponse);
    }

    @Transactional(readOnly = true)
    public TemplateResponse get(UUID id) {
        return templates.findById(id).map(mapper::toTemplateResponse)
                .orElseThrow(() -> new TemplateNotFoundException(
                        "Animation template not found: " + id));
    }

    @Transactional
    public TemplateResponse update(UUID id, TemplateUpdateRequest req) {
        AnimationTemplate t = load(id);
        checkVersion(t, req.expectedRowVersion());
        if (req.name() != null) t.setName(req.name());
        if (req.description() != null) t.setDescription(req.description());
        if (req.capabilitiesJson() != null) {
            t.setCapabilitiesJson(requireJsonObject(req.capabilitiesJson(), "capabilitiesJson"));
        }
        if (req.defaultConfigJson() != null) {
            t.setDefaultConfigJson(requireJsonObject(req.defaultConfigJson(), "defaultConfigJson"));
        }
        if (req.thumbnailAssetId() != null) {
            checkThumbnail(req.thumbnailAssetId());
            t.setThumbnailAssetId(req.thumbnailAssetId());
        }
        if (req.enabled() != null) t.setEnabled(req.enabled());
        return mapper.toTemplateResponse(templates.saveAndFlush(t));
    }

    public AnimationTemplate load(UUID id) {
        return templates.findById(id).orElseThrow(() -> new TemplateNotFoundException(
                "Animation template not found: " + id));
    }

    private void checkVersion(AnimationTemplate t, Long expected) {
        // Templates have no row_version column (rarely contended); guard anyway
        // via updatedAt? Keep simple: expectedRowVersion reserved for future.
        // no-op intentionally — see V14 schema.
    }

    private void checkThumbnail(UUID assetId) {
        if (assetId != null && !assets.existsByIdAndState(assetId, "ACTIVE")) {
            throw new AssetNotFoundException("thumbnail asset not active: " + assetId);
        }
    }

    private String requireJsonObject(String json, String field) {
        if (json == null) return "{}";
        try {
            JsonNode node = objectMapper.readTree(json);
            if (node == null || !node.isObject()) {
                throw new IllegalArgumentException(field + " must be a JSON object");
            }
            return objectMapper.writeValueAsString(node);
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalArgumentException(field + " is not valid JSON");
        }
    }
}

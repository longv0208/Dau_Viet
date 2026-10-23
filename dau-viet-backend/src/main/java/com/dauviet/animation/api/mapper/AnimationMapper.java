package com.dauviet.animation.api.mapper;

import org.springframework.stereotype.Component;

import com.dauviet.animation.api.dto.AnimationDtos.SceneResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneSummaryResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneVersionDetail;
import com.dauviet.animation.api.dto.AnimationDtos.SceneVersionSummary;
import com.dauviet.animation.api.dto.AnimationDtos.TemplateResponse;
import com.dauviet.animation.domain.AnimationScene;
import com.dauviet.animation.domain.AnimationSceneVersion;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneVersionRepository;

/** Entity -> admin DTO mapping. */
@Component
public class AnimationMapper {

    public TemplateResponse toTemplateResponse(AnimationTemplate t) {
        return new TemplateResponse(
                t.getId(), t.getCode(), t.getName(), t.getDescription(),
                t.getRendererCode(), t.getRendererVersion(), t.getSchemaVersion(),
                t.getCapabilitiesJson(), t.getDefaultConfigJson(),
                t.getThumbnailAssetId(), t.getEnabled(),
                t.getCreatedAt(), t.getUpdatedAt());
    }

    public SceneResponse toSceneResponse(AnimationScene s, AnimationTemplate t,
                                         AnimationSceneVersionRepository versions) {
        Integer currentNo = null;
        if (s.getCurrentVersionId() != null) {
            currentNo = versions.findById(s.getCurrentVersionId())
                    .map(AnimationSceneVersion::getVersionNo).orElse(null);
        }
        return new SceneResponse(
                s.getId(), s.getTemplateId(), t == null ? null : t.getCode(),
                t == null ? null : t.getRendererCode(),
                s.getEventId(), s.getTitle(), s.getDraftJson(),
                s.getStatus().name(), s.getCurrentVersionId(), currentNo,
                s.getRowVersion(), s.getCreatedAt(), s.getUpdatedAt());
    }

    public SceneSummaryResponse toSceneSummary(AnimationScene s, String rendererCode,
                                               AnimationSceneVersionRepository versions) {
        Integer currentNo = null;
        if (s.getCurrentVersionId() != null) {
            currentNo = versions.findById(s.getCurrentVersionId())
                    .map(AnimationSceneVersion::getVersionNo).orElse(null);
        }
        return new SceneSummaryResponse(
                s.getId(), s.getTemplateId(), rendererCode, s.getEventId(), s.getTitle(),
                s.getStatus().name(), s.getCurrentVersionId(), currentNo,
                s.getRowVersion(), s.getUpdatedAt());
    }

    public SceneVersionSummary toVersionSummary(AnimationSceneVersion v) {
        return new SceneVersionSummary(
                v.getId(), v.getVersionNo(), v.getSchemaVersion(),
                v.getRendererCode(), v.getRendererVersion(), v.getManifestChecksum(),
                v.getPublishedAt(), v.getPublishedBy());
    }

    public SceneVersionDetail toVersionDetail(AnimationSceneVersion v) {
        return new SceneVersionDetail(
                v.getId(), v.getSceneId(), v.getVersionNo(), v.getSchemaVersion(),
                v.getRendererCode(), v.getRendererVersion(),
                v.getSnapshotJson(), v.getManifestChecksum(),
                v.getPublishedAt(), v.getPublishedBy());
    }
}

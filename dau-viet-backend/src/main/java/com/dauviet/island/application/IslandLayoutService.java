package com.dauviet.island.application;

import java.util.Optional;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.island.domain.IslandLayoutDefinition;
import com.dauviet.island.domain.IslandLayoutVersion;
import com.dauviet.island.infrastructure.persistence.IslandLayoutDefinitionRepository;
import com.dauviet.island.infrastructure.persistence.IslandLayoutVersionRepository;

/**
 * Dịch vụ quản lý layout đảo có phiên bản (ISLAND-03).
 *
 * <p>Tại thời điểm V43 chỉ hỗ trợ đọc layout đã được seed sẵn
 * (heritage-village v1 PUBLISHED). Admin Island Builder (ISLAND-04) sẽ thêm
 * luồng tạo/publish/archive; service này là nền tảng để mở rộng.
 *
 * <p>Invariants:
 * <ul>
 *   <li>Tối đa 1 version PUBLISHED/definition — bảo đảm bởi partial unique index.</li>
 *   <li>Version PUBLISHED là immutable — slot/region/layer không thay đổi.</li>
 *   <li>User island pin vào layout_version_id khi tạo — không tự migrate
 *       sang version mới khi admin publish.</li>
 * </ul>
 */
@Service
public class IslandLayoutService {

    private static final Logger log =
            LoggerFactory.getLogger(IslandLayoutService.class);

    /**
     * layout_key của layout mặc định — seeded trong V43.
     * Không hard-code UUID; dùng key để resolve.
     */
    static final String DEFAULT_LAYOUT_KEY = "heritage-village";

    private final IslandLayoutDefinitionRepository definitions;
    private final IslandLayoutVersionRepository versions;

    public IslandLayoutService(IslandLayoutDefinitionRepository definitions,
                               IslandLayoutVersionRepository versions) {
        this.definitions = definitions;
        this.versions = versions;
    }

    /**
     * Tìm definition mặc định (heritage-village).
     *
     * @return Optional chứa definition nếu tồn tại
     */
    @Transactional(readOnly = true)
    public Optional<IslandLayoutDefinition> findDefaultDefinition() {
        return definitions.findByLayoutKey(DEFAULT_LAYOUT_KEY);
    }

    /**
     * Tìm version PUBLISHED mặc định để dùng khi tạo đảo mới.
     * Trả {@code Optional.empty()} nếu chưa có layout nào published —
     * caller phải xử lý graceful (island tạo mà không có layout_version_id).
     *
     * @return Optional chứa version PUBLISHED của heritage-village
     */
    @Transactional(readOnly = true)
    public Optional<IslandLayoutVersion> findDefaultPublishedVersion() {
        return versions.findPublishedByLayoutKey(DEFAULT_LAYOUT_KEY);
    }

    /**
     * Tìm version PUBLISHED theo UUID (khi island đã có layout_version_id).
     * Trả {@code Optional.empty()} nếu version không tồn tại hoặc không PUBLISHED.
     *
     * @param layoutVersionId UUID của version
     * @return Optional chứa version nếu tồn tại và PUBLISHED
     */
    @Transactional(readOnly = true)
    public Optional<IslandLayoutVersion> findPublishedVersion(UUID layoutVersionId) {
        return versions.findById(layoutVersionId)
                .filter(IslandLayoutVersion::isPublished);
    }

    /**
     * UUID của version PUBLISHED mặc định; trả null nếu chưa seed.
     * Dùng trong UserIslandRepository.insertIgnore để backfill layout_version_id.
     */
    @Transactional(readOnly = true)
    public UUID defaultPublishedVersionId() {
        return findDefaultPublishedVersion()
                .map(IslandLayoutVersion::getId)
                .orElseGet(() -> {
                    log.warn("island layout: no PUBLISHED version found "
                            + "for default layout '{}' — new islands will "
                            + "have null layout_version_id", DEFAULT_LAYOUT_KEY);
                    return null;
                });
    }
}

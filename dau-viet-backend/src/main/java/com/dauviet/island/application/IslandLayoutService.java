package com.dauviet.island.application;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.island.api.dto.AdminIslandLayoutDtos.*;
import com.dauviet.island.domain.IslandExceptions;
import com.dauviet.island.domain.IslandExceptions.IslandLayoutValidationException;
import com.dauviet.island.domain.IslandExceptions.IslandLayoutValidationException.ValidationError;
import com.dauviet.island.domain.IslandLayoutDefinition;
import com.dauviet.island.domain.IslandLayoutRegion;
import com.dauviet.island.domain.IslandLayoutVersion;
import com.dauviet.island.domain.IslandSceneLayer;
import com.dauviet.island.domain.IslandSlot;
import com.dauviet.island.domain.IslandTierPolicy;
import com.dauviet.island.infrastructure.persistence.IslandLayoutDefinitionRepository;
import com.dauviet.island.infrastructure.persistence.IslandLayoutRegionRepository;
import com.dauviet.island.infrastructure.persistence.IslandLayoutVersionRepository;
import com.dauviet.island.infrastructure.persistence.IslandSceneLayerRepository;
import com.dauviet.island.infrastructure.persistence.IslandSlotRepository;
import com.dauviet.island.infrastructure.persistence.IslandTierPolicyRepository;
import com.dauviet.island.infrastructure.persistence.UserIslandPlacementRepository;
import com.dauviet.lesson.domain.InvalidStatusTransitionException;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Dịch vụ quản lý layout đảo có phiên bản & Admin Island Builder (ISLAND-03, ISLAND-04).
 */
@Service
public class IslandLayoutService {

    private static final Logger log = LoggerFactory.getLogger(IslandLayoutService.class);

    static final String DEFAULT_LAYOUT_KEY = "heritage-village";

    private static final Set<String> SUPPORTED_LAYER_TYPES = Set.of(
            "STATIC_IMAGE", "ANIMATED_WATER", "REGION_OVERLAY",
            "ITEM_LAYER", "AMBIENT_OVERLAY", "FALLBACK_GRAPHICS"
    );

    private final IslandLayoutDefinitionRepository definitions;
    private final IslandLayoutVersionRepository versions;
    private final IslandLayoutRegionRepository regions;
    private final IslandSceneLayerRepository sceneLayers;
    private final IslandSlotRepository slots;
    private final IslandTierPolicyRepository policies;
    private final UserIslandPlacementRepository placements;
    private final AssetRepository assets;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public IslandLayoutService(IslandLayoutDefinitionRepository definitions,
                               IslandLayoutVersionRepository versions,
                               IslandLayoutRegionRepository regions,
                               IslandSceneLayerRepository sceneLayers,
                               IslandSlotRepository slots,
                               IslandTierPolicyRepository policies,
                               UserIslandPlacementRepository placements,
                               AssetRepository assets,
                               ObjectMapper objectMapper,
                               Clock clock) {
        this.definitions = definitions;
        this.versions = versions;
        this.regions = regions;
        this.sceneLayers = sceneLayers;
        this.slots = slots;
        this.policies = policies;
        this.placements = placements;
        this.assets = assets;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    public record DefaultPublishedLayout(IslandLayoutDefinition definition, IslandLayoutVersion version) {}

    @Transactional(readOnly = true)
    public Optional<DefaultPublishedLayout> findDefaultPublishedLayout() {
        Optional<IslandLayoutVersion> verOpt = versions.findDefaultPublishedVersion();
        if (verOpt.isEmpty()) {
            verOpt = versions.findPublishedByLayoutKey(DEFAULT_LAYOUT_KEY);
        }
        if (verOpt.isEmpty()) {
            return Optional.empty();
        }
        IslandLayoutVersion ver = verOpt.get();
        return definitions.findById(ver.getDefinitionId())
                .map(def -> new DefaultPublishedLayout(def, ver));
    }

    @Transactional(readOnly = true)
    public DefaultPublishedLayout requireDefaultPublishedLayout() {
        return findDefaultPublishedLayout()
                .orElseThrow(() -> new IslandExceptions.IslandConfigurationInvalidException(
                        "No valid default PUBLISHED island layout configuration found"));
    }

    @Transactional(readOnly = true)
    public Optional<IslandLayoutDefinition> findDefaultDefinition() {
        return definitions.findFirstByDefaultLayoutTrue()
                .or(() -> definitions.findByLayoutKey(DEFAULT_LAYOUT_KEY));
    }

    @Transactional(readOnly = true)
    public Optional<IslandLayoutVersion> findDefaultPublishedVersion() {
        return findDefaultPublishedLayout().map(DefaultPublishedLayout::version);
    }

    /**
     * Đọc bất kỳ version nào đã được pin cho user (cả PUBLISHED lẫn ARCHIVED).
     */
    @Transactional(readOnly = true)
    public Optional<IslandLayoutVersion> findPinnedVersion(UUID layoutVersionId) {
        if (layoutVersionId == null) return Optional.empty();
        return versions.findById(layoutVersionId)
                .filter(v -> v.isPublished() || v.isArchived());
    }

    @Transactional(readOnly = true)
    public UUID defaultPublishedVersionId() {
        return findDefaultPublishedVersion().map(IslandLayoutVersion::getId).orElse(null);
    }

    /* ==================== ADMIN ISLAND BUILDER API ==================== */

    @Transactional(readOnly = true)
    public List<LayoutSummaryResponse> listLayouts() {
        List<IslandLayoutDefinition> allDefs = definitions.findAllByOrderByCreatedAtDesc();
        return allDefs.stream().map(this::toLayoutSummary).toList();
    }

    @Transactional(readOnly = true)
    public LayoutDetailResponse getLayout(UUID layoutId) {
        IslandLayoutDefinition def = definitions.findById(layoutId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout not found: " + layoutId));
        List<VersionSummaryResponse> verList = versions.findByDefinitionIdOrderByVersionNumberDesc(layoutId)
                .stream()
                .map(this::toVersionSummary)
                .toList();
        return new LayoutDetailResponse(
                def.getId(), def.getLayoutKey(), def.getName(), def.getDescription(),
                def.getCanvasWidth(), def.getCanvasHeight(), def.getThemeKey(),
                def.isDefaultLayout(), def.getCreatedAt(), def.getUpdatedAt(), verList
        );
    }

    @Transactional
    public LayoutDetailResponse createLayout(CreateLayoutRequest req) {
        String key = req.layoutKey().trim().toLowerCase();
        if (definitions.findByLayoutKey(key).isPresent()) {
            throw new IllegalArgumentException("Layout key already exists: " + key);
        }
        Instant now = Instant.now(clock);
        UUID defId = UUID.randomUUID();
        double cw = req.canvasWidth() != null ? req.canvasWidth() : 960.0;
        double ch = req.canvasHeight() != null ? req.canvasHeight() : 720.0;
        boolean isDefault = Boolean.TRUE.equals(req.defaultLayout()) || definitions.count() == 0;

        IslandLayoutDefinition def = IslandLayoutDefinition.create(
                defId, key, req.name().trim(),
                req.description() != null ? req.description().trim() : null,
                cw, ch,
                req.themeKey() != null && !req.themeKey().isBlank() ? req.themeKey().trim() : "heritage",
                isDefault, now
        );
        definitions.saveAndFlush(def);
        if (isDefault) {
            definitions.clearOtherDefaults(defId);
        }

        // Tạo ngay Draft v1 có sẵn khung chuẩn 3 vùng, 12 slot, 4 layer để admin chỉnh sửa nhanh
        createStarterDraft(def, 1, now);
        return getLayout(defId);
    }

    @Transactional
    public LayoutDetailResponse updateLayout(UUID layoutId, UpdateLayoutRequest req) {
        IslandLayoutDefinition def = definitions.findLockedById(layoutId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout not found: " + layoutId));
        boolean hasPublishedOrArchived = versions.existsByDefinitionIdAndStatusIn(
                layoutId, List.of("PUBLISHED", "ARCHIVED"));
        Instant now = Instant.now(clock);
        def.updateMetadata(
                req.name(), req.description(),
                req.canvasWidth(), req.canvasHeight(),
                req.themeKey(), !hasPublishedOrArchived, now
        );
        if (Boolean.TRUE.equals(req.defaultLayout())) {
            def.setDefaultLayout(true, now);
            definitions.saveAndFlush(def);
            definitions.clearOtherDefaults(layoutId);
        } else {
            definitions.saveAndFlush(def);
        }
        return getLayout(layoutId);
    }

    @Transactional(readOnly = true)
    public List<VersionSummaryResponse> listVersions(UUID layoutId) {
        if (!definitions.existsById(layoutId)) {
            throw new ResourceNotFoundException("Island layout not found: " + layoutId);
        }
        return versions.findByDefinitionIdOrderByVersionNumberDesc(layoutId)
                .stream()
                .map(this::toVersionSummary)
                .toList();
    }

    @Transactional
    public VersionDetailResponse createDraft(UUID layoutId) {
        IslandLayoutDefinition def = definitions.findLockedById(layoutId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout not found: " + layoutId));
        List<IslandLayoutVersion> existing = versions.findByDefinitionIdOrderByVersionNumberDesc(layoutId);
        int nextVersionNo = existing.stream().mapToInt(IslandLayoutVersion::getVersionNumber).max().orElse(0) + 1;
        Instant now = Instant.now(clock);

        Optional<IslandLayoutVersion> published = versions.findPublishedByDefinitionId(layoutId);
        if (published.isPresent()) {
            return cloneIntoNewDraft(def, published.get(), nextVersionNo, now);
        }
        IslandLayoutVersion v = createStarterDraft(def, nextVersionNo, now);
        return getVersion(v.getId());
    }

    @Transactional
    public VersionDetailResponse cloneVersionToDraft(UUID sourceVersionId) {
        IslandLayoutVersion source = versions.findById(sourceVersionId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout version not found: " + sourceVersionId));
        IslandLayoutDefinition def = definitions.findLockedById(source.getDefinitionId())
                .orElseThrow(() -> new ResourceNotFoundException("Island layout not found: " + source.getDefinitionId()));
        List<IslandLayoutVersion> existing = versions.findByDefinitionIdOrderByVersionNumberDesc(def.getId());
        int nextVersionNo = existing.stream().mapToInt(IslandLayoutVersion::getVersionNumber).max().orElse(0) + 1;
        Instant now = Instant.now(clock);
        return cloneIntoNewDraft(def, source, nextVersionNo, now);
    }

    @Transactional(readOnly = true)
    public VersionDetailResponse getVersion(UUID versionId) {
        IslandLayoutVersion ver = versions.findById(versionId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout version not found: " + versionId));
        IslandLayoutDefinition def = definitions.findById(ver.getDefinitionId())
                .orElseThrow(() -> new ResourceNotFoundException("Island layout not found: " + ver.getDefinitionId()));

        List<RegionDto> regionDtos = regions.findByLayoutVersionIdOrderBySortOrderAsc(versionId)
                .stream()
                .map(r -> new RegionDto(r.getId(), r.getRegionCode(), r.getUnlockTier(),
                        r.getLabel(), r.getBoundsJson(), r.getSortOrder()))
                .toList();

        List<SlotDto> slotDtos = slots.findByLayoutVersionIdOrderBySlotIndex(versionId)
                .stream()
                .map(s -> new SlotDto(
                        s.getId(), s.getSlotIndex(), s.getStableSlotKey(), s.getTierRequired(),
                        s.getRegionCode(), s.getCoordX(), s.getCoordY(), s.getZIndex(),
                        s.getAnchorX(), s.getAnchorY(), s.getWidthNorm(), s.getHeightNorm(),
                        parseAllowedCategories(s.getAllowedCategoriesJson())
                ))
                .toList();

        List<SceneLayerDto> layerDtos = sceneLayers.findByLayoutVersionIdOrderByRenderOrderAsc(versionId)
                .stream()
                .map(l -> new SceneLayerDto(
                        l.getId(), l.getLayerKey(), l.getLayerType(),
                        l.getRenderOrder(), l.getAssetRef(), l.getVisibilityRuleJson()
                ))
                .toList();

        List<TierPolicySummary> policySummaries = policies.findActivePolicies().stream()
                .map(p -> new TierPolicySummary(p.getTier(), p.getSlotCount(), p.getRequiredLevel()))
                .toList();

        return new VersionDetailResponse(
                ver.getId(), def.getId(), def.getLayoutKey(), def.getName(),
                def.getCanvasWidth(), def.getCanvasHeight(), def.getThemeKey(),
                def.isDefaultLayout(),
                ver.getVersionNumber(), ver.getStatus(),
                ver.getRowVersion() != null ? ver.getRowVersion() : 0L,
                ver.getPublishedAt(), ver.getArchivedAt(),
                ver.getCreatedAt(), ver.getUpdatedAt(),
                regionDtos, slotDtos, layerDtos, policySummaries
        );
    }

    @Transactional
    public VersionDetailResponse saveDraftSnapshot(UUID versionId, UpdateDraftSnapshotRequest req) {
        IslandLayoutVersion ver = versions.findLockedById(versionId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout version not found: " + versionId));
        if (!ver.isDraft()) {
            throw new InvalidStatusTransitionException(
                    "Cannot modify island layout version in status " + ver.getStatus() + "; only DRAFT is editable");
        }
        checkRevision(ver, req.expectedRevision());

        IslandLayoutDefinition def = definitions.findById(ver.getDefinitionId())
                .orElseThrow(() -> new ResourceNotFoundException("Island layout not found: " + ver.getDefinitionId()));

        Instant now = Instant.now(clock);

        // 1. Update regions
        regions.deleteByLayoutVersionId(versionId);
        regions.flush();
        if (req.regions() != null) {
            int idx = 1;
            Set<String> seenCodes = new HashSet<>();
            for (RegionDto r : req.regions()) {
                String code = r.regionCode() != null ? r.regionCode().trim() : "REGION_" + idx;
                if (!seenCodes.add(code)) {
                    code = code + "_" + idx;
                }
                IslandLayoutRegion entity = IslandLayoutRegion.create(
                        r.id() != null ? r.id() : UUID.randomUUID(),
                        versionId, code,
                        r.unlockTier() > 0 ? r.unlockTier() : 1,
                        r.label(),
                        r.boundsJson() != null && !r.boundsJson().isBlank()
                                ? r.boundsJson()
                                : "{\"x\":0.05,\"y\":0.05,\"width\":0.9,\"height\":0.3}",
                        r.sortOrder() > 0 ? r.sortOrder() : idx,
                        now
                );
                regions.save(entity);
                idx++;
            }
            regions.flush();
        }

        // 2. Update slots safely (check placements before deleting any existing slot)
        List<IslandSlot> existingSlots = slots.findByLayoutVersionIdOrderBySlotIndex(versionId);
        Map<UUID, IslandSlot> existingById = existingSlots.stream()
                .collect(Collectors.toMap(IslandSlot::getId, s -> s));

        List<SlotDto> incomingSlots = req.slots() != null ? req.slots() : List.of();
        Set<UUID> incomingIds = incomingSlots.stream()
                .map(SlotDto::id)
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toSet());

        for (IslandSlot oldSlot : existingSlots) {
            if (!incomingIds.contains(oldSlot.getId())) {
                if (placements.existsBySlotId(oldSlot.getId())) {
                    throw new IllegalArgumentException(
                            "Không thể xóa slot '" + oldSlot.getStableSlotKey() + "' vì đang có người dùng đặt vật phẩm");
                }
                slots.delete(oldSlot);
            }
        }
        slots.flush();

        // To avoid temporary unique constraint collision on (layout_version_id, slot_index) or stable_slot_key,
        // first shift existing remaining slots to temporary negative indices/keys
        int tempIdx = -1;
        for (IslandSlot oldSlot : existingSlots) {
            if (incomingIds.contains(oldSlot.getId())) {
                oldSlot.update(tempIdx, oldSlot.getTierRequired(), oldSlot.getCoordX(), oldSlot.getCoordY(),
                        "__tmp_" + oldSlot.getId(), oldSlot.getRegionCode(), oldSlot.getZIndex(),
                        oldSlot.getAnchorX(), oldSlot.getAnchorY(), oldSlot.getWidthNorm(), oldSlot.getHeightNorm(),
                        oldSlot.getAllowedCategoriesJson());
                slots.save(oldSlot);
                tempIdx--;
            }
        }
        slots.flush();

        int slotCounter = 1;
        Set<String> usedKeys = new HashSet<>();
        for (SlotDto s : incomingSlots) {
            int slotIndex = s.slotIndex() > 0 ? s.slotIndex() : slotCounter;
            String key = s.stableSlotKey() != null && !s.stableSlotKey().isBlank()
                    ? s.stableSlotKey().trim()
                    : "slot_" + slotIndex;
            if (!usedKeys.add(key)) {
                key = key + "_" + slotCounter;
                usedKeys.add(key);
            }
            String allowedJson = serializeAllowedCategories(s.allowedCategories());
            double w = s.widthNorm() > 0 ? s.widthNorm() : 0.10;
            double h = s.heightNorm() > 0 ? s.heightNorm() : 0.12;
            double ax = s.anchorX() >= 0 && s.anchorX() <= 1 ? s.anchorX() : 0.5;
            double ay = s.anchorY() >= 0 && s.anchorY() <= 1 ? s.anchorY() : 1.0;

            if (s.id() != null && existingById.containsKey(s.id())) {
                IslandSlot existing = existingById.get(s.id());
                existing.update(
                        slotCounter, s.tierRequired(), s.coordX(), s.coordY(),
                        key, s.regionCode(), s.zIndex(), ax, ay, w, h, allowedJson
                );
                slots.save(existing);
            } else {
                IslandSlot created = IslandSlot.create(
                        UUID.randomUUID(), def.getLayoutKey(), versionId,
                        slotCounter, s.tierRequired(), s.coordX(), s.coordY(),
                        key, s.regionCode(), s.zIndex(), ax, ay, w, h, allowedJson, now
                );
                slots.save(created);
            }
            slotCounter++;
        }
        slots.flush();

        // 3. Update scene layers
        sceneLayers.deleteByLayoutVersionId(versionId);
        sceneLayers.flush();
        if (req.sceneLayers() != null) {
            int lIdx = 1;
            Set<String> seenLayerKeys = new HashSet<>();
            for (SceneLayerDto l : req.sceneLayers()) {
                String lKey = l.layerKey() != null && !l.layerKey().isBlank()
                        ? l.layerKey().trim()
                        : "layer_" + lIdx;
                if (!seenLayerKeys.add(lKey)) {
                    lKey = lKey + "_" + lIdx;
                }
                IslandSceneLayer entity = IslandSceneLayer.create(
                        l.id() != null ? l.id() : UUID.randomUUID(),
                        versionId, lKey,
                        l.layerType() != null ? l.layerType().trim().toUpperCase() : "STATIC_IMAGE",
                        l.renderOrder(),
                        l.assetRef() != null && !l.assetRef().isBlank() ? l.assetRef().trim() : null,
                        l.visibilityRuleJson() != null && !l.visibilityRuleJson().isBlank()
                                ? l.visibilityRuleJson()
                                : "{\"minTier\":1,\"maxTier\":3}",
                        now
                );
                sceneLayers.save(entity);
                lIdx++;
            }
            sceneLayers.flush();
        }

        ver.touch(now);
        versions.saveAndFlush(ver);
        def.updateMetadata(null, null, null, null, null, false, now);
        definitions.saveAndFlush(def);

        return getVersion(versionId);
    }

    @Transactional(readOnly = true)
    public ValidationReportResponse validateVersion(UUID versionId) {
        IslandLayoutVersion ver = versions.findById(versionId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout version not found: " + versionId));
        List<ValidationError> errors = computeValidationErrors(ver);
        return new ValidationReportResponse(errors.isEmpty(), errors);
    }

    @Transactional
    public VersionDetailResponse publishVersion(UUID versionId, Long expectedRevision) {
        IslandLayoutVersion ver = versions.findLockedById(versionId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout version not found: " + versionId));
        IslandLayoutDefinition def = definitions.findLockedById(ver.getDefinitionId())
                .orElseThrow(() -> new ResourceNotFoundException("Island layout not found: " + ver.getDefinitionId()));

        if (!ver.isDraft()) {
            throw new InvalidStatusTransitionException(
                    "Only DRAFT version can be published; current status is " + ver.getStatus());
        }
        checkRevision(ver, expectedRevision);

        List<ValidationError> errors = computeValidationErrors(ver);
        if (!errors.isEmpty()) {
            throw new IslandLayoutValidationException(errors);
        }

        Instant now = Instant.now(clock);

        // Chuyển version PUBLISHED cũ (nếu có) sang ARCHIVED một cách atomic
        versions.findPublishedByDefinitionId(def.getId()).ifPresent(oldPub -> {
            oldPub.archive(now);
            versions.saveAndFlush(oldPub);
        });

        ver.publish(now);
        versions.saveAndFlush(ver);

        def.updateMetadata(null, null, null, null, null, false, now);
        definitions.saveAndFlush(def);

        log.info("Published island layout version id={} layoutKey={} v={}",
                ver.getId(), def.getLayoutKey(), ver.getVersionNumber());
        return getVersion(versionId);
    }

    @Transactional
    public VersionDetailResponse archiveVersion(UUID versionId, Long expectedRevision) {
        IslandLayoutVersion ver = versions.findLockedById(versionId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout version not found: " + versionId));
        if (ver.isArchived()) {
            return getVersion(versionId);
        }
        checkRevision(ver, expectedRevision);

        Instant now = Instant.now(clock);
        ver.archive(now);
        versions.saveAndFlush(ver);
        return getVersion(versionId);
    }

    /* ==================== VALIDATION ENGINE ==================== */

    private List<ValidationError> computeValidationErrors(IslandLayoutVersion ver) {
        List<ValidationError> errors = new ArrayList<>();
        UUID versionId = ver.getId();

        List<IslandTierPolicy> activePolicies = policies.findActivePolicies();
        if (activePolicies.isEmpty()) {
            errors.add(new ValidationError("POLICY", "island_tier_policies", "policy",
                    "MISSING_TIER_POLICY", "Hệ thống chưa có cấu hình island_tier_policies đang active."));
        }
        Map<Integer, Integer> policySlotCounts = new HashMap<>();
        Set<Integer> validTiers = new HashSet<>();
        for (IslandTierPolicy p : activePolicies) {
            policySlotCounts.put(p.getTier(), p.getSlotCount());
            validTiers.add(p.getTier());
        }
        if (validTiers.isEmpty()) {
            validTiers.addAll(Set.of(1, 2, 3));
            policySlotCounts.put(1, 4);
            policySlotCounts.put(2, 8);
            policySlotCounts.put(3, 12);
        }

        List<IslandLayoutRegion> verRegions = regions.findByLayoutVersionIdOrderBySortOrderAsc(versionId);
        List<IslandSlot> verSlots = slots.findByLayoutVersionIdOrderBySlotIndex(versionId);
        List<IslandSceneLayer> verLayers = sceneLayers.findByLayoutVersionIdOrderByRenderOrderAsc(versionId);

        // 1. Validate Regions
        if (verRegions.isEmpty()) {
            errors.add(new ValidationError("REGION", "regions", "regions",
                    "MISSING_REGIONS", "Layout phải có ít nhất các vùng đất cho từng Tier."));
        }
        boolean hasTier1Region = false;
        Set<Integer> regionTiers = new HashSet<>();
        Map<String, IslandLayoutRegion> regionByCode = new HashMap<>();
        Map<String, double[]> regionBoundsMap = new HashMap<>();

        for (IslandLayoutRegion r : verRegions) {
            String code = r.getRegionCode();
            if (code == null || code.isBlank()) {
                errors.add(new ValidationError("REGION", String.valueOf(r.getId()), "regionCode",
                        "INVALID_REGION_CODE", "Mã vùng đất không được để trống."));
                continue;
            }
            if (regionByCode.containsKey(code)) {
                errors.add(new ValidationError("REGION", code, "regionCode",
                        "DUPLICATE_REGION_CODE", "Trùng mã vùng đất: " + code));
            }
            regionByCode.put(code, r);
            if (r.getUnlockTier() == 1) {
                hasTier1Region = true;
            }
            if (!validTiers.contains(r.getUnlockTier())) {
                errors.add(new ValidationError("REGION", code, "unlockTier",
                        "INVALID_REGION_TIER", "Vùng '" + code + "' có Tier mở khóa không hợp lệ: " + r.getUnlockTier()));
            }
            regionTiers.add(r.getUnlockTier());

            double[] bounds = parseBounds(r.getBoundsJson());
            if (bounds == null) {
                errors.add(new ValidationError("REGION", code, "boundsJson",
                        "INVALID_REGION_BOUNDS", "Hình học vùng '" + code + "' không hợp lệ (cần x, y, width, height trong khoảng 0..1)."));
            } else {
                regionBoundsMap.put(code, bounds);
            }
        }

        if (!hasTier1Region) {
            errors.add(new ValidationError("REGION", "TIER_1", "unlockTier",
                    "MISSING_TIER_1_REGION", "Bắt buộc phải có vùng đất mở khóa ở Tier 1 (Đảo nhỏ)."));
        }
        for (int reqTier : validTiers) {
            if (!regionTiers.contains(reqTier)) {
                errors.add(new ValidationError("REGION", "TIER_" + reqTier, "unlockTier",
                        "MISSING_TIER_REGION", "Thiếu cấu hình vùng đất hiển thị cho Tier " + reqTier + "."));
            }
        }

        // 2. Validate Slots
        if (verSlots.isEmpty()) {
            errors.add(new ValidationError("SLOT", "slots", "slots",
                    "MISSING_SLOTS", "Layout chưa có bất kỳ slot trang trí nào."));
        }
        Set<String> seenSlotKeys = new HashSet<>();
        Set<Integer> seenSlotIndices = new HashSet<>();

        for (IslandSlot s : verSlots) {
            String key = s.getStableSlotKey() != null ? s.getStableSlotKey() : "slot_" + s.getSlotIndex();
            if (!seenSlotKeys.add(key)) {
                errors.add(new ValidationError("SLOT", key, "stableSlotKey",
                        "DUPLICATE_SLOT_KEY", "Slot bị trùng khóa định danh: " + key));
            }
            if (!seenSlotIndices.add(s.getSlotIndex())) {
                errors.add(new ValidationError("SLOT", key, "slotIndex",
                        "DUPLICATE_SLOT_INDEX", "Slot '" + key + "' bị trùng chỉ mục: " + s.getSlotIndex()));
            }
            if (!validTiers.contains(s.getTierRequired())) {
                errors.add(new ValidationError("SLOT", key, "tierRequired",
                        "INVALID_SLOT_TIER", "Slot '" + key + "' yêu cầu Tier không hợp lệ: " + s.getTierRequired()));
            }
            if (s.getCoordX() < 0.0 || s.getCoordX() > 1.0 || s.getCoordY() < 0.0 || s.getCoordY() > 1.0) {
                errors.add(new ValidationError("SLOT", key, "coord",
                        "INVALID_SLOT_COORDS", "Tọa độ của slot '" + key + "' nằm ngoài phạm vi canvas (0..1)."));
            }
            if (s.getWidthNorm() <= 0.0 || s.getWidthNorm() > 1.0 || s.getHeightNorm() <= 0.0 || s.getHeightNorm() > 1.0) {
                errors.add(new ValidationError("SLOT", key, "size",
                        "INVALID_SLOT_SIZE", "Kích thước của slot '" + key + "' không hợp lệ (phải trong khoảng 0..1)."));
            }
            if (s.getAnchorX() < 0.0 || s.getAnchorX() > 1.0 || s.getAnchorY() < 0.0 || s.getAnchorY() > 1.0) {
                errors.add(new ValidationError("SLOT", key, "anchor",
                        "INVALID_SLOT_ANCHOR", "Điểm neo (anchor) của slot '" + key + "' phải nằm trong khoảng 0..1."));
            }

            String regCode = s.getRegionCode();
            if (regCode == null || !regionByCode.containsKey(regCode)) {
                errors.add(new ValidationError("SLOT", key, "regionCode",
                        "SLOT_INVALID_REGION", "Slot '" + key + "' tham chiếu vùng đất không tồn tại trong version này: " + regCode));
            } else {
                IslandLayoutRegion reg = regionByCode.get(regCode);
                if (reg.getUnlockTier() > s.getTierRequired()) {
                    errors.add(new ValidationError("SLOT", key, "tierRequired",
                            "SLOT_REGION_TIER_MISMATCH",
                            "Slot '" + key + "' mở ở Tier " + s.getTierRequired() + " nhưng nằm trong vùng '" + regCode + "' mở ở Tier " + reg.getUnlockTier() + "."));
                }
                double[] b = regionBoundsMap.get(regCode);
                if (b != null) {
                    double rx = b[0], ry = b[1], rw = b[2], rh = b[3];
                    // Cho phép sai số biên nhỏ 0.02
                    if (s.getCoordX() < rx - 0.02 || s.getCoordX() > rx + rw + 0.02
                            || s.getCoordY() < ry - 0.02 || s.getCoordY() > ry + rh + 0.02) {
                        errors.add(new ValidationError("SLOT", key, "coord",
                                "SLOT_OUTSIDE_REGION",
                                "Slot '" + key + "' (" + String.format("%.2f, %.2f", s.getCoordX(), s.getCoordY())
                                        + ") nằm ngoài ranh giới vùng '" + regCode + "'."));
                    }
                }
            }
        }

        // Kiểm tra số lượng slot cộng dồn theo policy của từng Tier
        for (Map.Entry<Integer, Integer> entry : policySlotCounts.entrySet().stream()
                .sorted(Map.Entry.comparingByKey()).toList()) {
            int tier = entry.getKey();
            int expectedCumulative = entry.getValue();
            long actualCumulative = verSlots.stream()
                    .filter(s -> s.getTierRequired() <= tier)
                    .count();
            if (actualCumulative != expectedCumulative) {
                errors.add(new ValidationError("SLOT", "TIER_" + tier, "slotCount",
                        " cumulative_slot_count_mismatch".trim().toUpperCase(),
                        "Tổng số slot mở khóa đến Tier " + tier + " là " + actualCumulative
                                + ", không khớp với cấu hình policy server (" + expectedCumulative + " slot)."));
            }
        }

        // 3. Validate Scene Layers
        if (verLayers.isEmpty()) {
            errors.add(new ValidationError("LAYER", "sceneLayers", "sceneLayers",
                    "MISSING_SCENE_LAYERS", "Layout phải có cấu hình các lớp cảnh quan (scene layers)."));
        }
        boolean hasItemLayer = false;
        Set<Integer> coveredDisplayTiers = new HashSet<>();

        for (IslandSceneLayer l : verLayers) {
            String lKey = l.getLayerKey();
            String lType = l.getLayerType();
            if (lType == null || !SUPPORTED_LAYER_TYPES.contains(lType)) {
                errors.add(new ValidationError("LAYER", lKey, "layerType",
                        "UNSUPPORTED_LAYER_TYPE", "Loại lớp cảnh quan '" + lType + "' ở layer '" + lKey + "' không được renderer hỗ trợ."));
            }
            if ("ITEM_LAYER".equals(lType)) {
                hasItemLayer = true;
            }
            if ("STATIC_IMAGE".equals(lType)) {
                String ref = l.getAssetRef();
                if (ref == null || ref.isBlank()) {
                    errors.add(new ValidationError("LAYER", lKey, "assetRef",
                            "MISSING_REQUIRED_ASSET", "Layer ảnh tĩnh '" + lKey + "' bắt buộc phải chọn asset hoặc đường dẫn ảnh."));
                } else if (ref.toLowerCase().startsWith("data:") || ref.toLowerCase().contains("<script") || ref.toLowerCase().startsWith("javascript:")) {
                    errors.add(new ValidationError("LAYER", lKey, "assetRef",
                            "INVALID_ASSET_REF", "Layer '" + lKey + "' không được phép nhúng base64 trực tiếp hoặc script."));
                } else {
                    validateAssetRefIfUuid(lKey, ref, errors);
                }
            }

            int[] minMax = parseVisibilityTiers(l.getVisibilityRuleJson());
            if (minMax == null) {
                errors.add(new ValidationError("LAYER", lKey, "visibilityRuleJson",
                        "INVALID_VISIBILITY_RULE", "Quy tắc hiển thị theo Tier của layer '" + lKey + "' không hợp lệ."));
            } else {
                for (int t = minMax[0]; t <= minMax[1]; t++) {
                    coveredDisplayTiers.add(t);
                }
            }
        }

        if (!hasItemLayer) {
            errors.add(new ValidationError("LAYER", "item_layer", "layerType",
                    "MISSING_ITEM_LAYER", "Bắt buộc phải có một lớp ITEM_LAYER để hiển thị các slot vật phẩm."));
        }
        for (int reqTier : validTiers) {
            if (!coveredDisplayTiers.contains(reqTier)) {
                errors.add(new ValidationError("LAYER", "TIER_" + reqTier, "visibilityRuleJson",
                        "MISSING_TIER_DISPLAY_CONFIG", "Thiếu cấu hình hiển thị scene layer cho Tier " + reqTier + "."));
            }
        }

        return errors;
    }

    private void validateAssetRefIfUuid(String layerKey, String assetRef, List<ValidationError> errors) {
        String candidate = assetRef.trim();
        // Nếu là /api/v1/admin/assets/{uuid}/content hoặc trực tiếp {uuid}
        if (candidate.startsWith("/api/v1/admin/assets/") && candidate.endsWith("/content")) {
            candidate = candidate.substring("/api/v1/admin/assets/".length(),
                    candidate.length() - "/content".length());
        }
        try {
            UUID assetId = UUID.fromString(candidate);
            if (!assets.existsByIdAndState(assetId, "ACTIVE")) {
                errors.add(new ValidationError("LAYER", layerKey, "assetRef",
                        "ASSET_NOT_FOUND", "Asset '" + assetId + "' gắn với layer '" + layerKey + "' không tồn tại hoặc không ở trạng thái ACTIVE."));
            }
        } catch (IllegalArgumentException ignored) {
            // Đường dẫn tương đối tĩnh (ví dụ assets/images/...) -> hợp lệ
        }
    }

    private double[] parseBounds(String boundsJson) {
        if (boundsJson == null || boundsJson.isBlank()) return null;
        try {
            JsonNode node = objectMapper.readTree(boundsJson);
            if (!node.hasNonNull("x") || !node.hasNonNull("y")
                    || !node.hasNonNull("width") || !node.hasNonNull("height")) {
                return null;
            }
            double x = node.get("x").asDouble(-1);
            double y = node.get("y").asDouble(-1);
            double w = node.get("width").asDouble(-1);
            double h = node.get("height").asDouble(-1);
            if (x < 0 || x > 1 || y < 0 || y > 1 || w <= 0 || h <= 0 || x + w > 1.05 || y + h > 1.05) {
                return null;
            }
            return new double[]{x, y, w, h};
        } catch (Exception e) {
            return null;
        }
    }

    private int[] parseVisibilityTiers(String json) {
        if (json == null || json.isBlank()) return new int[]{1, 9};
        try {
            JsonNode node = objectMapper.readTree(json);
            int minTier = node.hasNonNull("minTier") ? node.get("minTier").asInt(1) : 1;
            int maxTier = node.hasNonNull("maxTier") ? node.get("maxTier").asInt(3) : 3;
            if (minTier < 1 || maxTier < minTier || maxTier > 9) return null;
            return new int[]{minTier, maxTier};
        } catch (Exception e) {
            return null;
        }
    }

    /* ==================== INTERNAL HELPERS ==================== */

    private void checkRevision(IslandLayoutVersion ver, Long expectedRevision) {
        long actual = ver.getRowVersion() != null ? ver.getRowVersion() : 0L;
        if (expectedRevision != null && !expectedRevision.equals(actual)) {
            throw new OptimisticLockingFailureException(
                    "Draft revision mismatch: expected=" + expectedRevision + ", actual=" + actual);
        }
    }

    private VersionDetailResponse cloneIntoNewDraft(IslandLayoutDefinition def,
                                                    IslandLayoutVersion source,
                                                    int nextVersionNo,
                                                    Instant now) {
        UUID newVerId = UUID.randomUUID();
        IslandLayoutVersion draft = IslandLayoutVersion.createDraft(newVerId, def.getId(), nextVersionNo, now);
        versions.saveAndFlush(draft);

        for (IslandLayoutRegion r : regions.findByLayoutVersionIdOrderBySortOrderAsc(source.getId())) {
            regions.save(IslandLayoutRegion.create(
                    UUID.randomUUID(), newVerId, r.getRegionCode(),
                    r.getUnlockTier(), r.getLabel(), r.getBoundsJson(), r.getSortOrder(), now
            ));
        }
        regions.flush();

        for (IslandSlot s : slots.findByLayoutVersionIdOrderBySlotIndex(source.getId())) {
            slots.save(IslandSlot.create(
                    UUID.randomUUID(), def.getLayoutKey(), newVerId,
                    s.getSlotIndex(), s.getTierRequired(), s.getCoordX(), s.getCoordY(),
                    s.getStableSlotKey(), s.getRegionCode(), s.getZIndex(),
                    s.getAnchorX(), s.getAnchorY(), s.getWidthNorm(), s.getHeightNorm(),
                    s.getAllowedCategoriesJson(), now
            ));
        }
        slots.flush();

        for (IslandSceneLayer l : sceneLayers.findByLayoutVersionIdOrderByRenderOrderAsc(source.getId())) {
            sceneLayers.save(IslandSceneLayer.create(
                    UUID.randomUUID(), newVerId, l.getLayerKey(), l.getLayerType(),
                    l.getRenderOrder(), l.getAssetRef(), l.getVisibilityRuleJson(), now
            ));
        }
        sceneLayers.flush();

        def.updateMetadata(null, null, null, null, null, false, now);
        definitions.saveAndFlush(def);

        return getVersion(newVerId);
    }

    private IslandLayoutVersion createStarterDraft(IslandLayoutDefinition def, int versionNo, Instant now) {
        UUID verId = UUID.randomUUID();
        IslandLayoutVersion draft = IslandLayoutVersion.createDraft(verId, def.getId(), versionNo, now);
        versions.saveAndFlush(draft);

        regions.save(IslandLayoutRegion.create(UUID.randomUUID(), verId, "TIER_1", 1,
                "Khu Trung Tâm", "{\"x\":0.05,\"y\":0.08,\"width\":0.90,\"height\":0.44}", 1, now));
        regions.save(IslandLayoutRegion.create(UUID.randomUUID(), verId, "TIER_2", 2,
                "Khu Mở Rộng", "{\"x\":0.05,\"y\":0.38,\"width\":0.90,\"height\":0.40}", 2, now));
        regions.save(IslandLayoutRegion.create(UUID.randomUUID(), verId, "TIER_3", 3,
                "Khu Cao Cấp", "{\"x\":0.05,\"y\":0.62,\"width\":0.90,\"height\":0.34}", 3, now));
        regions.flush();

        double[][] defaultCoords = {
                {0.20, 0.22, 1}, {0.50, 0.22, 1}, {0.80, 0.22, 1}, {0.20, 0.44, 1},
                {0.50, 0.44, 2}, {0.80, 0.44, 2}, {0.20, 0.68, 2}, {0.50, 0.68, 2},
                {0.80, 0.68, 3}, {0.20, 0.88, 3}, {0.50, 0.88, 3}, {0.80, 0.88, 3}
        };
        for (int i = 0; i < defaultCoords.length; i++) {
            int idx = i + 1;
            int tier = (int) defaultCoords[i][2];
            slots.save(IslandSlot.create(
                    UUID.randomUUID(), def.getLayoutKey(), verId,
                    idx, tier, defaultCoords[i][0], defaultCoords[i][1],
                    "slot_" + idx, "TIER_" + tier, idx * 10,
                    0.5, 1.0, 0.10, 0.12, "[\"DECOR\"]", now
            ));
        }
        slots.flush();

        sceneLayers.save(IslandSceneLayer.create(UUID.randomUUID(), verId, "water_bg", "ANIMATED_WATER", 0, null, "{\"minTier\":1,\"maxTier\":3}", now));
        sceneLayers.save(IslandSceneLayer.create(UUID.randomUUID(), verId, "island_base", "STATIC_IMAGE", 10, "assets/images/dv_ISL_generic_island-base-tiers_v01.jpg", "{\"minTier\":1,\"maxTier\":3}", now));
        sceneLayers.save(IslandSceneLayer.create(UUID.randomUUID(), verId, "water_ripple", "AMBIENT_OVERLAY", 20, null, "{\"minTier\":1,\"maxTier\":3}", now));
        sceneLayers.save(IslandSceneLayer.create(UUID.randomUUID(), verId, "region_overlay", "REGION_OVERLAY", 25, null, "{\"minTier\":1,\"maxTier\":3}", now));
        sceneLayers.save(IslandSceneLayer.create(UUID.randomUUID(), verId, "item_layer", "ITEM_LAYER", 30, null, "{\"minTier\":1,\"maxTier\":3}", now));
        sceneLayers.flush();

        return draft;
    }

    public List<String> parseAllowedCategories(String json) {
        if (json == null || json.isBlank()) return List.of("DECOR");
        try {
            List<String> list = objectMapper.readValue(json, new TypeReference<List<String>>() {});
            return list == null || list.isEmpty() ? List.of("DECOR") : list;
        } catch (Exception e) {
            return List.of("DECOR");
        }
    }

    private String serializeAllowedCategories(List<String> categories) {
        List<String> clean = (categories == null || categories.isEmpty())
                ? List.of("DECOR")
                : categories.stream()
                        .filter(java.util.Objects::nonNull)
                        .map(String::trim)
                        .filter(s -> !s.isEmpty())
                        .map(String::toUpperCase)
                        .distinct()
                        .toList();
        if (clean.isEmpty()) clean = List.of("DECOR");
        try {
            return objectMapper.writeValueAsString(clean);
        } catch (Exception e) {
            return "[\"DECOR\"]";
        }
    }

    private LayoutSummaryResponse toLayoutSummary(IslandLayoutDefinition def) {
        List<IslandLayoutVersion> verList = versions.findByDefinitionIdOrderByVersionNumberDesc(def.getId());
        IslandLayoutVersion pub = verList.stream().filter(IslandLayoutVersion::isPublished).findFirst().orElse(null);
        IslandLayoutVersion draft = verList.stream().filter(IslandLayoutVersion::isDraft).findFirst().orElse(null);
        String latestStatus = pub != null ? "PUBLISHED" : (draft != null ? "DRAFT" : (verList.isEmpty() ? "EMPTY" : verList.get(0).getStatus()));
        Instant latestUpdated = verList.stream()
                .map(IslandLayoutVersion::getUpdatedAt)
                .filter(java.util.Objects::nonNull)
                .max(Comparator.naturalOrder())
                .orElse(def.getUpdatedAt());

        return new LayoutSummaryResponse(
                def.getId(), def.getLayoutKey(), def.getName(), def.getDescription(),
                def.getCanvasWidth(), def.getCanvasHeight(), def.getThemeKey(),
                def.isDefaultLayout(), verList.size(),
                pub != null ? pub.getVersionNumber() : null,
                pub != null ? pub.getId() : null,
                draft != null ? draft.getVersionNumber() : null,
                draft != null ? draft.getId() : null,
                latestStatus, latestUpdated
        );
    }

    private VersionSummaryResponse toVersionSummary(IslandLayoutVersion v) {
        return new VersionSummaryResponse(
                v.getId(), v.getDefinitionId(), v.getVersionNumber(), v.getStatus(),
                v.getRowVersion() != null ? v.getRowVersion() : 0L,
                v.getPublishedAt(), v.getArchivedAt(), v.getCreatedAt(), v.getUpdatedAt()
        );
    }
}

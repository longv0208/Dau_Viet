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
import com.dauviet.island.domain.IslandLayoutBoard;
import com.dauviet.island.domain.IslandLayoutDefinition;
import com.dauviet.island.domain.IslandLayoutRegion;
import com.dauviet.island.domain.IslandLayoutVersion;
import com.dauviet.island.domain.IslandSceneLayer;
import com.dauviet.island.domain.IslandSlot;
import com.dauviet.island.domain.IslandTierPolicy;
import com.dauviet.island.domain.IslandTile;
import com.dauviet.island.infrastructure.persistence.IslandLayoutBoardRepository;
import com.dauviet.island.infrastructure.persistence.IslandLayoutDefinitionRepository;
import com.dauviet.island.infrastructure.persistence.IslandLayoutRegionRepository;
import com.dauviet.island.infrastructure.persistence.IslandLayoutVersionRepository;
import com.dauviet.island.infrastructure.persistence.IslandSceneLayerRepository;
import com.dauviet.island.infrastructure.persistence.IslandSlotRepository;
import com.dauviet.island.infrastructure.persistence.IslandTileRepository;
import com.dauviet.island.infrastructure.persistence.IslandTierPolicyRepository;
import com.dauviet.island.infrastructure.persistence.UserIslandPlacementRepository;
import com.dauviet.lesson.domain.InvalidStatusTransitionException;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.dauviet.reward.application.AccountLevelService;
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
    private final AccountLevelService levelService;
    private final IslandLayoutBoardRepository boards;
    private final IslandTileRepository tiles;
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
                               AccountLevelService levelService,
                               IslandLayoutBoardRepository boards,
                               IslandTileRepository tiles,
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
        this.levelService = levelService;
        this.boards = boards;
        this.tiles = tiles;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    public record DefaultPublishedLayout(IslandLayoutDefinition definition, IslandLayoutVersion version) {}

    @Transactional(readOnly = true)
    public Optional<DefaultPublishedLayout> findDefaultPublishedLayout() {
        Optional<IslandLayoutVersion> verOpt = versions.findDefaultPublishedVersion();
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
        if (Boolean.TRUE.equals(req.defaultLayout())) {
            throw new IllegalArgumentException(
                    "Không thể đặt bố cục mới làm mặc định khi chưa có phiên bản PUBLISHED. Vui lòng tạo bố cục, kiểm tra và xuất bản (Publish) trước khi đặt làm mặc định.");
        }
        Instant now = Instant.now(clock);
        UUID defId = UUID.randomUUID();
        double cw = req.canvasWidth() != null ? req.canvasWidth() : 960.0;
        double ch = req.canvasHeight() != null ? req.canvasHeight() : 720.0;

        // Bố cục mới tạo chỉ có DRAFT v1 nên luôn khởi tạo với defaultLayout = false
        // để không bao giờ xóa cờ default của bố cục PUBLISHED đang hoạt động.
        IslandLayoutDefinition def = IslandLayoutDefinition.create(
                defId, key, req.name().trim(),
                req.description() != null ? req.description().trim() : null,
                cw, ch,
                req.themeKey() != null && !req.themeKey().isBlank() ? req.themeKey().trim() : "heritage",
                false, now
        );
        definitions.saveAndFlush(def);

        // Tạo ngay Draft v1 có sẵn khung chuẩn 3 vùng, 12 slot, 5 layer để admin chỉnh sửa nhanh
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
        if (Boolean.TRUE.equals(req.defaultLayout()) && !def.isDefaultLayout()) {
            // Bố cục mặc định bắt buộc phải có phiên bản PUBLISHED hợp lệ trước khi nhận cờ mặc định
            if (versions.findPublishedByDefinitionId(layoutId).isEmpty()) {
                throw new IllegalArgumentException(
                        "Chỉ có thể đặt làm bố cục mặc định sau khi bố cục này đã có phiên bản PUBLISHED");
            }
            List<IslandLayoutDefinition> currentDefaults = definitions.lockAllDefaults();
            for (IslandLayoutDefinition oldDef : currentDefaults) {
                if (!oldDef.getId().equals(layoutId)) {
                    oldDef.setDefaultLayout(false, now);
                    definitions.save(oldDef);
                }
            }
            definitions.flush();
            def.setDefaultLayout(true, now);
        } else if (Boolean.FALSE.equals(req.defaultLayout()) && def.isDefaultLayout()) {
            throw new IllegalArgumentException(
                    "Không thể tắt trạng thái mặc định trực tiếp; vui lòng chọn một bố cục khác làm mặc định thay thế.");
        }
        definitions.saveAndFlush(def);
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
                        parseAllowedCategories(s.getAllowedCategoriesJson()),
                        s.getTileId()
                ))
                .toList();

        // Board + tiles (V48): null/empty với layout rect-model legacy — admin
        // thấy sự thật, không qua adapter (adapter chỉ phục vụ /me/island).
        IslandLayoutBoard board = boards.findById(versionId).orElse(null);
        BoardDto boardDto = board == null ? null : new BoardDto(
                board.getGridRows(), board.getGridColumns(),
                board.getTileWidth(), board.getTileHeight(),
                board.getBoardOriginX(), board.getBoardOriginY(),
                board.getProjectionType(), board.isConnectivityRequired());

        List<TileDto> tileDtos = tiles
                .findByLayoutVersionIdOrderByRowIndexAscColIndexAsc(versionId)
                .stream()
                .map(t -> new TileDto(
                        t.getId(), t.getTileKey(), t.getRowIndex(), t.getColIndex(),
                        t.getTerrainType(), t.getRegionCode(), t.getUnlockTier(),
                        t.isBuildable(), t.getVisualKey(), t.getElevation()
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
                regionDtos, slotDtos, layerDtos, policySummaries,
                boardDto, tileDtos
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

        List<RegionDto> incomingRegions = req.regions() != null ? req.regions() : List.of();
        List<SlotDto> incomingSlots = req.slots() != null ? req.slots() : List.of();
        List<SceneLayerDto> incomingLayers = req.sceneLayers() != null ? req.sceneLayers() : List.of();
        // V48: null = giữ nguyên board/tiles hiện có (backward-compat admin cũ)
        BoardDto incomingBoard = req.board();
        List<TileDto> incomingTiles = req.tiles();

        // Kiểm tra trùng khóa / chỉ mục trước khi ghi để không tự ý đổi tên âm thầm làm sai lệch cấu hình Admin
        List<ValidationError> snapshotKeyErrors = new ArrayList<>();
        Set<String> checkRegionCodes = new HashSet<>();
        for (int i = 0; i < incomingRegions.size(); i++) {
            RegionDto r = incomingRegions.get(i);
            String code = r.regionCode() != null && !r.regionCode().isBlank()
                    ? r.regionCode().trim()
                    : "REGION_" + (i + 1);
            if (!checkRegionCodes.add(code)) {
                snapshotKeyErrors.add(new ValidationError(
                        "REGION", code, "regionCode", "DUPLICATE_REGION_CODE",
                        "Trùng mã vùng đất (regionCode): " + code));
            }
        }
        Set<String> checkSlotKeys = new HashSet<>();
        Set<Integer> checkSlotIndices = new HashSet<>();
        for (int i = 0; i < incomingSlots.size(); i++) {
            SlotDto s = incomingSlots.get(i);
            int slotIndex = s.slotIndex() != 0 ? s.slotIndex() : (i + 1);
            String key = s.stableSlotKey() != null && !s.stableSlotKey().isBlank()
                    ? s.stableSlotKey().trim()
                    : "slot_" + slotIndex;
            if (slotIndex < 1 || slotIndex > 64) {
                snapshotKeyErrors.add(new ValidationError(
                        "SLOT", key, "slotIndex", "INVALID_SLOT_INDEX",
                        "Chỉ mục slot (slotIndex) phải nằm trong khoảng 1..64: " + slotIndex));
            }
            if (!checkSlotKeys.add(key)) {
                snapshotKeyErrors.add(new ValidationError(
                        "SLOT", key, "stableSlotKey", "DUPLICATE_SLOT_KEY",
                        "Trùng khóa định danh slot (stableSlotKey): " + key));
            }
            if (!checkSlotIndices.add(slotIndex)) {
                snapshotKeyErrors.add(new ValidationError(
                        "SLOT", key, "slotIndex", "DUPLICATE_SLOT_INDEX",
                        "Slot '" + key + "' bị trùng chỉ mục (slotIndex): " + slotIndex));
            }
        }
        // Kiểm tra trùng khóa / tọa độ tile (V48) trước khi ghi — fail-fast,
        // không tự sửa key/tọa độ âm thầm.
        Set<String> checkTileKeys = new HashSet<>();
        Set<String> checkTileCoords = new HashSet<>();
        if (incomingTiles != null) {
            int gridRows = incomingBoard != null ? incomingBoard.gridRows() : 0;
            int gridCols = incomingBoard != null ? incomingBoard.gridColumns() : 0;
            for (int i = 0; i < incomingTiles.size(); i++) {
                TileDto t = incomingTiles.get(i);
                String tKey = t.tileKey() != null && !t.tileKey().isBlank()
                        ? t.tileKey().trim()
                        : "tile_" + (i + 1);
                if (!checkTileKeys.add(tKey)) {
                    snapshotKeyErrors.add(new ValidationError(
                            "TILE", tKey, "tileKey", "DUPLICATE_TILE_KEY",
                            "Trùng khóa định danh ô đất (tileKey): " + tKey));
                }
                String coord = t.row() + ":" + t.column();
                if (!checkTileCoords.add(coord)) {
                    snapshotKeyErrors.add(new ValidationError(
                            "TILE", tKey, "coord", "DUPLICATE_TILE_COORD",
                            "Trùng tọa độ ô đất (row=" + t.row() + ", column=" + t.column() + ")"));
                }
                if (incomingBoard != null
                        && (t.row() < 0 || t.row() >= gridRows
                            || t.column() < 0 || t.column() >= gridCols)) {
                    snapshotKeyErrors.add(new ValidationError(
                            "TILE", tKey, "coord", "TILE_OUT_OF_BOUNDS",
                            "Ô '" + tKey + "' (" + t.row() + "," + t.column()
                                    + ") nằm ngoài lưới board " + gridRows + "x" + gridCols + "."));
                }
                if (t.row() < 0 || t.column() < 0) {
                    snapshotKeyErrors.add(new ValidationError(
                            "TILE", tKey, "coord", "TILE_OUT_OF_BOUNDS",
                            "Tọa độ ô '" + tKey + "' không được âm."));
                }
            }
        }
        Set<String> checkLayerKeys = new HashSet<>();
        for (int i = 0; i < incomingLayers.size(); i++) {
            SceneLayerDto l = incomingLayers.get(i);
            String lKey = l.layerKey() != null && !l.layerKey().isBlank()
                    ? l.layerKey().trim()
                    : "layer_" + (i + 1);
            if (!checkLayerKeys.add(lKey)) {
                snapshotKeyErrors.add(new ValidationError(
                        "LAYER", lKey, "layerKey", "DUPLICATE_LAYER_KEY",
                        "Trùng khóa lớp cảnh quan (layerKey): " + lKey));
            }
            String layerType = l.layerType() != null ? l.layerType().trim().toUpperCase() : "STATIC_IMAGE";
            if ("STATIC_IMAGE".equals(layerType) && l.assetRef() != null && !l.assetRef().isBlank()) {
                validateAssetRefStrict(lKey, l.assetRef(), snapshotKeyErrors);
            }
        }
        if (!snapshotKeyErrors.isEmpty()) {
            throw new IslandLayoutValidationException(snapshotKeyErrors);
        }

        Instant now = Instant.now(clock);

        // 1. Update regions safely in-place without temporary invalid codes
        List<IslandLayoutRegion> existingRegions =
                regions.findByLayoutVersionIdOrderBySortOrderAsc(versionId);
        Map<UUID, IslandLayoutRegion> existingRegionById = existingRegions.stream()
                .collect(Collectors.toMap(IslandLayoutRegion::getId, r -> r));
        Map<String, IslandLayoutRegion> existingRegionByCode = existingRegions.stream()
                .collect(Collectors.toMap(IslandLayoutRegion::getRegionCode, r -> r, (a, b) -> a));

        Set<UUID> keptRegionIds = new HashSet<>();
        List<IslandLayoutRegion> matchedRegions = new ArrayList<>();
        for (RegionDto r : incomingRegions) {
            IslandLayoutRegion match = null;
            if (r.id() != null && existingRegionById.containsKey(r.id()) && !keptRegionIds.contains(r.id())) {
                match = existingRegionById.get(r.id());
            } else if (r.regionCode() != null) {
                IslandLayoutRegion byCode = existingRegionByCode.get(r.regionCode().trim());
                if (byCode != null && !keptRegionIds.contains(byCode.getId())) {
                    match = byCode;
                }
            }
            if (match != null) {
                keptRegionIds.add(match.getId());
            }
            matchedRegions.add(match);
        }

        for (IslandLayoutRegion oldReg : existingRegions) {
            if (!keptRegionIds.contains(oldReg.getId())) {
                regions.delete(oldReg);
            }
        }
        regions.flush();

        int idx = 1;
        for (int i = 0; i < incomingRegions.size(); i++) {
            RegionDto r = incomingRegions.get(i);
            IslandLayoutRegion existingReg = matchedRegions.get(i);
            String code = r.regionCode() != null && !r.regionCode().isBlank()
                    ? r.regionCode().trim()
                    : "REGION_" + idx;
            int unlockTier = r.unlockTier() > 0 ? r.unlockTier() : 1;
            String boundsJson = r.boundsJson() != null && !r.boundsJson().isBlank()
                    ? r.boundsJson()
                    : "{\"x\":0.05,\"y\":0.05,\"width\":0.9,\"height\":0.3}";
            int sortOrder = r.sortOrder() > 0 ? r.sortOrder() : idx;

            if (existingReg != null) {
                existingReg.update(code, unlockTier, r.label(), boundsJson, sortOrder);
                regions.save(existingReg);
            } else {
                regions.save(IslandLayoutRegion.create(
                        UUID.randomUUID(), versionId, code, unlockTier,
                        r.label(), boundsJson, sortOrder, now
                ));
            }
            idx++;
        }
        regions.flush();

        // 1b. Board config (V48): upsert khi request có board; absent = giữ nguyên.
        if (incomingBoard != null) {
            IslandLayoutBoard existingBoard = boards.findById(versionId).orElse(null);
            if (existingBoard != null) {
                existingBoard.update(
                        incomingBoard.gridRows(), incomingBoard.gridColumns(),
                        incomingBoard.tileWidth(), incomingBoard.tileHeight(),
                        incomingBoard.boardOriginX(), incomingBoard.boardOriginY(),
                        incomingBoard.projectionType() != null
                                ? incomingBoard.projectionType() : "ISOMETRIC",
                        !Boolean.FALSE.equals(incomingBoard.connectivityRequired()),
                        now);
                boards.save(existingBoard);
            } else {
                boards.save(IslandLayoutBoard.create(
                        versionId,
                        incomingBoard.gridRows(), incomingBoard.gridColumns(),
                        incomingBoard.tileWidth() > 0 ? incomingBoard.tileWidth() : 128.0,
                        incomingBoard.tileHeight() > 0 ? incomingBoard.tileHeight() : 64.0,
                        incomingBoard.boardOriginX(), incomingBoard.boardOriginY(),
                        incomingBoard.projectionType() != null
                                ? incomingBoard.projectionType() : "ISOMETRIC",
                        !Boolean.FALSE.equals(incomingBoard.connectivityRequired()),
                        now));
            }
            boards.flush();
        }

        // 1c. Tiles diff (V48): chỉ chạy khi request gửi tiles — match
        // id → tileKey → (row,column) giống cơ chế slots. Xóa tile còn slot
        // liên kết = lỗi (admin phải gỡ/unlink slot trước).
        Map<UUID, IslandTile> tileByIdAfterSave = new HashMap<>();
        if (incomingTiles != null) {
            List<IslandTile> existingTiles =
                    tiles.findByLayoutVersionIdOrderByRowIndexAscColIndexAsc(versionId);
            Map<UUID, IslandTile> existingTileById = existingTiles.stream()
                    .collect(Collectors.toMap(IslandTile::getId, t -> t));
            Map<String, IslandTile> existingTileByKey = existingTiles.stream()
                    .filter(t -> t.getTileKey() != null)
                    .collect(Collectors.toMap(IslandTile::getTileKey, t -> t, (a, b) -> a));
            Map<String, IslandTile> existingTileByCoord = existingTiles.stream()
                    .collect(Collectors.toMap(
                            t -> t.getRowIndex() + ":" + t.getColIndex(), t -> t, (a, b) -> a));

            Set<UUID> keptTileIds = new HashSet<>();
            List<IslandTile> matchedTiles = new ArrayList<>();
            for (TileDto t : incomingTiles) {
                IslandTile match = null;
                if (t.id() != null && existingTileById.containsKey(t.id()) && !keptTileIds.contains(t.id())) {
                    match = existingTileById.get(t.id());
                } else if (t.tileKey() != null) {
                    IslandTile byKey = existingTileByKey.get(t.tileKey().trim());
                    if (byKey != null && !keptTileIds.contains(byKey.getId())) {
                        match = byKey;
                    }
                }
                if (match == null) {
                    IslandTile byCoord = existingTileByCoord.get(t.row() + ":" + t.column());
                    if (byCoord != null && !keptTileIds.contains(byCoord.getId())) {
                        match = byCoord;
                    }
                }
                if (match != null) {
                    keptTileIds.add(match.getId());
                }
                matchedTiles.add(match);
            }

            // Slot đang gắn vào tile sắp xóa → chặn (admin gỡ/unlink slot trước)
            List<IslandSlot> currentSlots = slots.findByLayoutVersionIdOrderBySlotIndex(versionId);
            Map<UUID, IslandSlot> slotByTileId = new HashMap<>();
            for (IslandSlot cs : currentSlots) {
                if (cs.getTileId() != null) {
                    slotByTileId.put(cs.getTileId(), cs);
                }
            }
            for (IslandTile oldTile : existingTiles) {
                if (!keptTileIds.contains(oldTile.getId())) {
                    IslandSlot linked = slotByTileId.get(oldTile.getId());
                    if (linked != null) {
                        throw new IllegalArgumentException(
                                "Không thể xóa ô đất '" + oldTile.getTileKey()
                                        + "' vì đang chứa slot '" + linked.getStableSlotKey()
                                        + "'; gỡ liên kết slot trước.");
                    }
                    tiles.delete(oldTile);
                }
            }
            tiles.flush();

            int tIdx = 1;
            for (int i = 0; i < incomingTiles.size(); i++) {
                TileDto t = incomingTiles.get(i);
                IslandTile existingTile = matchedTiles.get(i);
                String tKey = t.tileKey() != null && !t.tileKey().isBlank()
                        ? t.tileKey().trim()
                        : "tile_" + tIdx;
                String terrain = t.terrainType() != null && !t.terrainType().isBlank()
                        ? t.terrainType().trim().toUpperCase()
                        : "GRASS";
                int elevation = t.elevation() != null ? t.elevation() : 0;

                IslandTile saved;
                if (existingTile != null) {
                    existingTile.update(tKey, t.row(), t.column(), terrain,
                            t.regionCode(), t.unlockTier() > 0 ? t.unlockTier() : 1,
                            t.buildable(), t.visualKey(), elevation);
                    saved = tiles.save(existingTile);
                } else {
                    saved = tiles.save(IslandTile.create(
                            UUID.randomUUID(), versionId, tKey,
                            t.row(), t.column(), terrain, t.regionCode(),
                            t.unlockTier() > 0 ? t.unlockTier() : 1,
                            t.buildable(), t.visualKey(), elevation, now));
                }
                tileByIdAfterSave.put(saved.getId(), saved);
                tIdx++;
            }
            tiles.flush();
        } else {
            for (IslandTile t : tiles.findByLayoutVersionIdOrderByRowIndexAscColIndexAsc(versionId)) {
                tileByIdAfterSave.put(t.getId(), t);
            }
        }

        // 2. Update slots safely in-place (preserve slot UUIDs & stableSlotKey; never write slot_index outside 1..64)
        List<IslandSlot> existingSlots = slots.findByLayoutVersionIdOrderBySlotIndex(versionId);
        Map<UUID, IslandSlot> existingById = existingSlots.stream()
                .collect(Collectors.toMap(IslandSlot::getId, s -> s));
        Map<String, IslandSlot> existingByKey = existingSlots.stream()
                .filter(s -> s.getStableSlotKey() != null)
                .collect(Collectors.toMap(IslandSlot::getStableSlotKey, s -> s, (a, b) -> a));

        Set<UUID> keptSlotIds = new HashSet<>();
        List<IslandSlot> matchedSlots = new ArrayList<>();
        for (SlotDto s : incomingSlots) {
            IslandSlot match = null;
            if (s.id() != null && existingById.containsKey(s.id()) && !keptSlotIds.contains(s.id())) {
                match = existingById.get(s.id());
            } else if (s.stableSlotKey() != null) {
                IslandSlot byKey = existingByKey.get(s.stableSlotKey().trim());
                if (byKey != null && !keptSlotIds.contains(byKey.getId())) {
                    match = byKey;
                }
            }
            if (match != null) {
                keptSlotIds.add(match.getId());
            }
            matchedSlots.add(match);
        }

        for (IslandSlot oldSlot : existingSlots) {
            if (!keptSlotIds.contains(oldSlot.getId())) {
                if (placements.existsBySlotId(oldSlot.getId())) {
                    throw new IllegalArgumentException(
                            "Không thể xóa slot '" + oldSlot.getStableSlotKey() + "' vì đang có người dùng đặt vật phẩm");
                }
                slots.delete(oldSlot);
            }
        }
        slots.flush();

        for (int i = 0; i < incomingSlots.size(); i++) {
            SlotDto s = incomingSlots.get(i);
            IslandSlot existingSlot = matchedSlots.get(i);
            int slotCounter = i + 1;
            int slotIndex = s.slotIndex() > 0 ? s.slotIndex() : slotCounter;
            String key = s.stableSlotKey() != null && !s.stableSlotKey().isBlank()
                    ? s.stableSlotKey().trim()
                    : "slot_" + slotIndex;
            String allowedJson = serializeAllowedCategories(s.allowedCategories());
            double w = s.widthNorm() > 0 ? s.widthNorm() : 0.10;
            double h = s.heightNorm() > 0 ? s.heightNorm() : 0.12;
            double ax = s.anchorX() >= 0 && s.anchorX() <= 1 ? s.anchorX() : 0.5;
            double ay = s.anchorY() >= 0 && s.anchorY() <= 1 ? s.anchorY() : 1.0;

            // Resolve tile host (V48): tileId phải trỏ tile của đúng version
            // này — tham chiếu chéo version hoặc tile không tồn tại = lỗi.
            UUID tileId = null;
            if (s.tileId() != null) {
                IslandTile linked = tileByIdAfterSave.get(s.tileId());
                if (linked == null) {
                    if (tiles.existsByIdAndLayoutVersionId(s.tileId(), versionId)) {
                        linked = tiles.findById(s.tileId()).orElse(null);
                    }
                    if (linked == null) {
                        throw new IslandLayoutValidationException(List.of(
                                new ValidationError("SLOT", key, "tileId",
                                        "SLOT_TILE_NOT_FOUND",
                                        "Slot '" + key + "' tham chiếu ô đất không tồn tại trong version này: " + s.tileId())));
                    }
                    tileByIdAfterSave.put(linked.getId(), linked);
                }
                tileId = linked.getId();
            }

            if (existingSlot != null) {
                existingSlot.update(
                        slotIndex, s.tierRequired(), s.coordX(), s.coordY(),
                        key, s.regionCode(), tileId, s.zIndex(), ax, ay, w, h, allowedJson
                );
                slots.save(existingSlot);
            } else {
                IslandSlot created = IslandSlot.create(
                        UUID.randomUUID(), def.getLayoutKey(), versionId,
                        slotIndex, s.tierRequired(), s.coordX(), s.coordY(),
                        key, s.regionCode(), tileId, s.zIndex(), ax, ay, w, h, allowedJson, now
                );
                slots.save(created);
            }
        }
        slots.flush();

        // 3. Update scene layers safely in-place without temporary keys
        List<IslandSceneLayer> existingLayers =
                sceneLayers.findByLayoutVersionIdOrderByRenderOrderAsc(versionId);
        Map<UUID, IslandSceneLayer> existingLayerById = existingLayers.stream()
                .collect(Collectors.toMap(IslandSceneLayer::getId, l -> l));
        Map<String, IslandSceneLayer> existingLayerByKey = existingLayers.stream()
                .collect(Collectors.toMap(IslandSceneLayer::getLayerKey, l -> l, (a, b) -> a));

        Set<UUID> keptLayerIds = new HashSet<>();
        List<IslandSceneLayer> matchedLayers = new ArrayList<>();
        for (SceneLayerDto l : incomingLayers) {
            IslandSceneLayer match = null;
            if (l.id() != null && existingLayerById.containsKey(l.id()) && !keptLayerIds.contains(l.id())) {
                match = existingLayerById.get(l.id());
            } else if (l.layerKey() != null) {
                IslandSceneLayer byKey = existingLayerByKey.get(l.layerKey().trim());
                if (byKey != null && !keptLayerIds.contains(byKey.getId())) {
                    match = byKey;
                }
            }
            if (match != null) {
                keptLayerIds.add(match.getId());
            }
            matchedLayers.add(match);
        }

        for (IslandSceneLayer oldLayer : existingLayers) {
            if (!keptLayerIds.contains(oldLayer.getId())) {
                sceneLayers.delete(oldLayer);
            }
        }
        sceneLayers.flush();

        int lIdx = 1;
        for (int i = 0; i < incomingLayers.size(); i++) {
            SceneLayerDto l = incomingLayers.get(i);
            IslandSceneLayer existingLayer = matchedLayers.get(i);
            String lKey = l.layerKey() != null && !l.layerKey().isBlank()
                    ? l.layerKey().trim()
                    : "layer_" + lIdx;
            String layerType = l.layerType() != null ? l.layerType().trim().toUpperCase() : "STATIC_IMAGE";
            String assetRef = normalizeLayerAssetRef(l.assetRef());
            String visRule = l.visibilityRuleJson() != null && !l.visibilityRuleJson().isBlank()
                    ? l.visibilityRuleJson()
                    : "{\"minTier\":1,\"maxTier\":3}";

            if (existingLayer != null) {
                existingLayer.update(lKey, layerType, l.renderOrder(), assetRef, visRule);
                sceneLayers.save(existingLayer);
            } else {
                sceneLayers.save(IslandSceneLayer.create(
                        UUID.randomUUID(), versionId, lKey, layerType,
                        l.renderOrder(), assetRef, visRule, now
                ));
            }
            lIdx++;
        }
        sceneLayers.flush();

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

        // Nếu toàn hệ thống chưa có bố cục mặc định nào đang sở hữu phiên bản PUBLISHED,
        // tự động đặt bố cục vừa xuất bản này làm mặc định cho người dùng mới.
        if (versions.findDefaultPublishedVersion().isEmpty()) {
            List<IslandLayoutDefinition> currentDefaults = definitions.lockAllDefaults();
            for (IslandLayoutDefinition oldDef : currentDefaults) {
                if (!oldDef.getId().equals(def.getId())) {
                    oldDef.setDefaultLayout(false, now);
                    definitions.save(oldDef);
                }
            }
            definitions.flush();
            def.setDefaultLayout(true, now);
        }

        def.updateMetadata(null, null, null, null, null, false, now);
        definitions.saveAndFlush(def);

        log.info("Published island layout version id={} layoutKey={} v={}",
                ver.getId(), def.getLayoutKey(), ver.getVersionNumber());
        return getVersion(versionId);
    }

    private String normalizeLayerAssetRef(String rawRef) {
        if (rawRef == null || rawRef.isBlank()) {
            return null;
        }
        String trimmed = rawRef.trim();
        if (trimmed.startsWith("/api/v1/admin/assets/") && trimmed.endsWith("/content")) {
            String candidate = trimmed.substring(
                    "/api/v1/admin/assets/".length(),
                    trimmed.length() - "/content".length());
            try {
                UUID id = UUID.fromString(candidate);
                return "/api/v1/assets/" + id + "/content";
            } catch (IllegalArgumentException ignored) {
                return trimmed;
            }
        }
        if (trimmed.startsWith("/api/v1/assets/") && trimmed.endsWith("/content")) {
            String candidate = trimmed.substring(
                    "/api/v1/assets/".length(),
                    trimmed.length() - "/content".length());
            try {
                UUID id = UUID.fromString(candidate);
                return "/api/v1/assets/" + id + "/content";
            } catch (IllegalArgumentException ignored) {
                return trimmed;
            }
        }
        try {
            UUID id = UUID.fromString(trimmed);
            return "/api/v1/assets/" + id + "/content";
        } catch (IllegalArgumentException ignored) {
            return trimmed;
        }
    }

    @Transactional
    public VersionDetailResponse archiveVersion(UUID versionId, Long expectedRevision) {
        IslandLayoutVersion ver = versions.findLockedById(versionId)
                .orElseThrow(() -> new ResourceNotFoundException("Island layout version not found: " + versionId));
        if (ver.isArchived()) {
            return getVersion(versionId);
        }
        checkRevision(ver, expectedRevision);

        if (ver.isPublished()) {
            IslandLayoutDefinition def = definitions.findLockedById(ver.getDefinitionId())
                    .orElseThrow(() -> new ResourceNotFoundException("Island layout not found: " + ver.getDefinitionId()));
            Optional<DefaultPublishedLayout> currentDefaultPub = findDefaultPublishedLayout();
            boolean isCurrentDefaultPublished = def.isDefaultLayout()
                    || (currentDefaultPub.isPresent()
                            && currentDefaultPub.get().version().getId().equals(versionId));
            if (isCurrentDefaultPublished) {
                throw new InvalidStatusTransitionException(
                        "Không thể lưu trữ (archive) phiên bản PUBLISHED mặc định cuối cùng khi chưa xuất bản phiên bản mới thay thế cho người dùng mới.");
            }
        }

        Instant now = Instant.now(clock);
        ver.archive(now);
        versions.saveAndFlush(ver);
        return getVersion(versionId);
    }

    /* ==================== VALIDATION ENGINE ==================== */

    private List<ValidationError> computeValidationErrors(IslandLayoutVersion ver) {
        List<ValidationError> errors = new ArrayList<>();
        UUID versionId = ver.getId();

        if (!levelService.hasValidConfiguration()) {
            errors.add(new ValidationError("POLICY", "account_level_thresholds", "levelConfig",
                    "INVALID_LEVEL_CONFIG",
                    "Hệ thống chưa có cấu hình ngưỡng cấp độ tài khoản (account_level_thresholds) hợp lệ."));
        }

        List<IslandTierPolicy> activePolicies = policies.findActivePolicies();
        if (activePolicies.isEmpty()) {
            errors.add(new ValidationError("POLICY", "island_tier_policies", "policy",
                    "MISSING_TIER_POLICY",
                    "Hệ thống chưa có cấu hình island_tier_policies đang active; không được phép xuất bản dựa trên ngưỡng tự đoán."));
        }
        Map<Integer, Integer> policySlotCounts = new HashMap<>();
        Set<Integer> validTiers = new HashSet<>();
        for (IslandTierPolicy p : activePolicies) {
            policySlotCounts.put(p.getTier(), p.getSlotCount());
            validTiers.add(p.getTier());
            Integer reqLvl = p.getRequiredLevel();
            if (reqLvl == null || reqLvl < 1) {
                errors.add(new ValidationError("POLICY", "TIER_" + p.getTier(), "requiredLevel",
                        "MISSING_REQUIRED_LEVEL",
                        "Chính sách Tier " + p.getTier() + " thiếu required_level hợp lệ."));
            } else if (!levelService.hasValidConfiguration() || levelService.minExpForLevel(reqLvl) < 0) {
                errors.add(new ValidationError("POLICY", "TIER_" + p.getTier(), "requiredLevel",
                        "MISSING_LEVEL_THRESHOLD",
                        "Chính sách Tier " + p.getTier() + " yêu cầu Level " + reqLvl
                                + " nhưng không tìm thấy ngưỡng EXP tương ứng trong account_level_thresholds."));
            }
        }

        List<IslandLayoutRegion> verRegions = regions.findByLayoutVersionIdOrderBySortOrderAsc(versionId);
        List<IslandSlot> verSlots = slots.findByLayoutVersionIdOrderBySlotIndex(versionId);
        List<IslandSceneLayer> verLayers = sceneLayers.findByLayoutVersionIdOrderByRenderOrderAsc(versionId);
        // V48: tile-mode khi có board row hoặc có tiles — áp thêm rules tile.
        IslandLayoutBoard verBoard = boards.findById(versionId).orElse(null);
        List<IslandTile> verTiles = tiles.findByLayoutVersionIdOrderByRowIndexAscColIndexAsc(versionId);
        boolean tileMode = verBoard != null || !verTiles.isEmpty();

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
                // V48: ở tile-mode bounds là optional — membership suy từ tiles.
                if (!tileMode) {
                    errors.add(new ValidationError("REGION", code, "boundsJson",
                            "INVALID_REGION_BOUNDS", "Hình học vùng '" + code + "' không hợp lệ (cần x, y, width, height trong khoảng 0..1)."));
                }
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
            if (!tileMode && (s.getCoordX() < 0.0 || s.getCoordX() > 1.0
                    || s.getCoordY() < 0.0 || s.getCoordY() > 1.0)) {
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
                if (b != null && !tileMode) {
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
                        "CUMULATIVE_SLOT_COUNT_MISMATCH",
                        "Tổng số slot mở khóa đến Tier " + tier + " là " + actualCumulative
                                + ", không khớp với cấu hình policy server (" + expectedCumulative + " slot)."));
            }
        }

        // ============ V48: Board & Tiles (chỉ khi version ở tile-mode) ============
        if (tileMode) {
            // Board phải tồn tại khi có tiles và ngược lại
            if (verBoard == null) {
                errors.add(new ValidationError("BOARD", "board", "board",
                        "MISSING_BOARD",
                        "Layout có ô đất (tiles) nhưng thiếu cấu hình board (grid/projection)."));
            }
            if (verTiles.isEmpty() && verBoard != null) {
                errors.add(new ValidationError("TILE", "tiles", "tiles",
                        "MISSING_BOARD",
                        "Layout có cấu hình board nhưng chưa có ô đất (tiles) nào."));
            }
            if (verBoard != null) {
                if (verBoard.getGridRows() < 1 || verBoard.getGridRows() > 32
                        || verBoard.getGridColumns() < 1 || verBoard.getGridColumns() > 32) {
                    errors.add(new ValidationError("BOARD", "board", "grid",
                            "INVALID_GRID_DIMS",
                            "Kích thước lưới board phải nằm trong 1..32 cho mỗi chiều."));
                }
                if (verBoard.getTileWidth() <= 0 || verBoard.getTileHeight() <= 0) {
                    errors.add(new ValidationError("BOARD", "board", "tileSize",
                            "INVALID_GRID_DIMS",
                            "Kích thước ô (tileWidth/tileHeight) phải dương."));
                }
                if (!"ISOMETRIC".equals(verBoard.getProjectionType())) {
                    errors.add(new ValidationError("BOARD", "board", "projectionType",
                            "UNSUPPORTED_PROJECTION",
                            "Renderer chỉ hỗ trợ projection ISOMETRIC: " + verBoard.getProjectionType()));
                }
            }

            Map<String, IslandTile> tileByKey = new HashMap<>();
            Map<String, IslandTile> tileByCoord = new HashMap<>();
            Map<UUID, IslandTile> tileById = new HashMap<>();
            boolean hasTier1Tile = false;
            Set<String> occupiedCoords = new HashSet<>();

            for (IslandTile t : verTiles) {
                String tKey = t.getTileKey() != null ? t.getTileKey() : "tile_" + t.getId();
                if (tileByKey.put(tKey, t) != null) {
                    errors.add(new ValidationError("TILE", tKey, "tileKey",
                            "DUPLICATE_TILE_KEY", "Trùng khóa ô đất: " + tKey));
                }
                tileById.put(t.getId(), t);
                String coord = t.getRowIndex() + ":" + t.getColIndex();
                if (tileByCoord.put(coord, t) != null) {
                    errors.add(new ValidationError("TILE", tKey, "coord",
                            "DUPLICATE_TILE_COORD",
                            "Hai ô đất cùng tọa độ (row=" + t.getRowIndex()
                                    + ", column=" + t.getColIndex() + ")."));
                }
                occupiedCoords.add(coord);

                if (verBoard != null
                        && (t.getRowIndex() < 0 || t.getRowIndex() >= verBoard.getGridRows()
                            || t.getColIndex() < 0 || t.getColIndex() >= verBoard.getGridColumns())) {
                    errors.add(new ValidationError("TILE", tKey, "coord",
                            "TILE_OUT_OF_BOUNDS",
                            "Ô '" + tKey + "' (" + t.getRowIndex() + "," + t.getColIndex()
                                    + ") nằm ngoài lưới board."));
                }
                String tType = t.getTerrainType() != null ? t.getTerrainType() : "";
                if (!"WATER".equals(tType)) {
                    String tReg = t.getRegionCode();
                    if (tReg == null || !regionByCode.containsKey(tReg)) {
                        errors.add(new ValidationError("TILE", tKey, "regionCode",
                                "TILE_MISSING_REGION",
                                "Ô '" + tKey + "' tham chiếu vùng đất không tồn tại: " + tReg));
                    } else {
                        IslandLayoutRegion reg = regionByCode.get(tReg);
                        if (t.getUnlockTier() < reg.getUnlockTier()) {
                            errors.add(new ValidationError("TILE", tKey, "unlockTier",
                                    "TILE_REGION_TIER_MISMATCH",
                                    "Ô '" + tKey + "' mở ở Tier " + t.getUnlockTier()
                                            + " nhưng thuộc vùng '" + tReg + "' mở ở Tier " + reg.getUnlockTier() + "."));
                        }
                    }
                }
                int effTier = (t.getRegionCode() != null && regionByCode.containsKey(t.getRegionCode()))
                        ? regionByCode.get(t.getRegionCode()).getUnlockTier()
                        : t.getUnlockTier();
                if (effTier == 1 && !"WATER".equals(tType)) {
                    hasTier1Tile = true;
                }
                if ("DECORATIVE".equals(tType)
                        && (t.getVisualKey() == null || t.getVisualKey().isBlank())) {
                    errors.add(new ValidationError("TILE", tKey, "visualKey",
                            "MISSING_TILE_VISUAL",
                            "Ô '" + tKey + "' thuộc loại DECORATIVE nhưng thiếu visualKey."));
                }
            }
            if (!hasTier1Tile && !verTiles.isEmpty()) {
                errors.add(new ValidationError("TILE", "TIER_1", "unlockTier",
                        "MISSING_TIER_1_TILES",
                        "Board phải có ít nhất một ô đất mở ở Tier 1."));
            }

            // Slot ↔ tile: liên kết, 1:1, buildable, tier
            Map<UUID, Integer> slotsPerTile = new HashMap<>();
            for (IslandSlot s : verSlots) {
                String key = s.getStableSlotKey() != null
                        ? s.getStableSlotKey() : "slot_" + s.getSlotIndex();
                if (s.getTileId() == null) {
                    errors.add(new ValidationError("SLOT", key, "tileId",
                            "SLOT_TILE_NOT_FOUND",
                            "Slot '" + key + "' chưa gắn ô đất (tileId null) trong layout tile-based."));
                    continue;
                }
                IslandTile host = tileById.get(s.getTileId());
                if (host == null) {
                    errors.add(new ValidationError("SLOT", key, "tileId",
                            "SLOT_TILE_NOT_FOUND",
                            "Slot '" + key + "' tham chiếu ô đất không thuộc version này: " + s.getTileId()));
                    continue;
                }
                int count = slotsPerTile.merge(s.getTileId(), 1, Integer::sum);
                if (count > 1) {
                    errors.add(new ValidationError("SLOT", key, "tileId",
                            "MULTIPLE_SLOTS_PER_TILE",
                            "Ô '" + host.getTileKey() + "' chứa nhiều hơn một buildable slot."));
                }
                if (!host.isBuildable()) {
                    errors.add(new ValidationError("SLOT", key, "tileId",
                            "SLOT_WITHOUT_BUILDABLE_TILE",
                            "Slot '" + key + "' nằm trên ô '" + host.getTileKey()
                                    + "' không được đánh dấu buildable."));
                }
                int hostTier = (host.getRegionCode() != null
                        && regionByCode.containsKey(host.getRegionCode()))
                        ? regionByCode.get(host.getRegionCode()).getUnlockTier()
                        : host.getUnlockTier();
                if (s.getTierRequired() < hostTier) {
                    errors.add(new ValidationError("SLOT", key, "tierRequired",
                            "SLOT_TILE_TIER_MISMATCH",
                            "Slot '" + key + "' mở ở Tier " + s.getTierRequired()
                                    + " nhưng nằm trên ô mở ở Tier " + hostTier + "."));
                }
            }

            // Liên thông 4-neighbor: land tiles (non-WATER) phải reachable
            // từ cụm Tier-1; bỏ qua khi board cố ý cho phép tách cụm.
            if (verBoard != null && verBoard.isConnectivityRequired()
                    && !occupiedCoords.isEmpty()) {
                Set<String> landCoords = new HashSet<>();
                Set<String> seeds = new HashSet<>();
                for (IslandTile t : verTiles) {
                    String tType = t.getTerrainType() != null ? t.getTerrainType() : "";
                    if ("WATER".equals(tType)) continue;
                    String coord = t.getRowIndex() + ":" + t.getColIndex();
                    landCoords.add(coord);
                    int effTier = (t.getRegionCode() != null
                            && regionByCode.containsKey(t.getRegionCode()))
                            ? regionByCode.get(t.getRegionCode()).getUnlockTier()
                            : t.getUnlockTier();
                    if (effTier == 1) seeds.add(coord);
                }
                // BFS từ cụm tier-1 (fallback: ô đầu tiên nếu chưa có tier-1)
                java.util.ArrayDeque<String> queue = new java.util.ArrayDeque<>(
                        seeds.isEmpty() ? Set.of(landCoords.iterator().next()) : seeds);
                Set<String> visited = new HashSet<>(queue);
                int[][] dirs = {{1,0},{-1,0},{0,1},{0,-1}};
                while (!queue.isEmpty()) {
                    String cur = queue.poll();
                    String[] rc = cur.split(":");
                    int r = Integer.parseInt(rc[0]), c = Integer.parseInt(rc[1]);
                    for (int[] d : dirs) {
                        String n = (r + d[0]) + ":" + (c + d[1]);
                        if (landCoords.contains(n) && visited.add(n)) {
                            queue.add(n);
                        }
                    }
                }
                if (!visited.containsAll(landCoords)) {
                    errors.add(new ValidationError("TILE", "connectivity", "connectivity",
                            "TILE_NOT_CONNECTED",
                            "Các ô đất không liên thông theo cạnh (4-neighbor) từ vùng Tier 1 — nếu cố ý tách đảo phụ/cầu nối, đặt connectivity_required=false trên board."));
                }
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
                } else {
                    validateAssetRefStrict(lKey, ref, errors);
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

    private void validateAssetRefStrict(String layerKey, String assetRef, List<ValidationError> errors) {
        String candidate = assetRef.trim();
        String lower = candidate.toLowerCase();
        if (lower.startsWith("data:")
                || lower.startsWith("javascript:")
                || lower.startsWith("http://")
                || lower.startsWith("https://")
                || lower.startsWith("//")
                || lower.contains("<script")
                || candidate.contains("..")
                || candidate.contains("@")
                || candidate.contains("?")
                || candidate.contains("#")) {
            errors.add(new ValidationError("LAYER", layerKey, "assetRef",
                    "INVALID_ASSET_REF",
                    "Layer '" + layerKey + "' chỉ cho phép gắn Asset trong Media Library (/api/v1/assets/{id}/content) hoặc đường dẫn ảnh nội bộ hợp lệ (assets/...), không cho phép URL ngoài."));
            return;
        }
        if (candidate.startsWith("/api/v1/admin/assets/") && candidate.endsWith("/content")) {
            candidate = candidate.substring("/api/v1/admin/assets/".length(),
                    candidate.length() - "/content".length());
        } else if (candidate.startsWith("/api/v1/assets/") && candidate.endsWith("/content")) {
            candidate = candidate.substring("/api/v1/assets/".length(),
                    candidate.length() - "/content".length());
        } else if (candidate.startsWith("assets/")) {
            if (!candidate.matches("^assets/[a-zA-Z0-9._/-]+\\.(png|jpg|jpeg|webp)$")) {
                errors.add(new ValidationError("LAYER", layerKey, "assetRef",
                        "INVALID_ASSET_REF",
                        "Đường dẫn ảnh nội bộ của layer '" + layerKey + "' không đúng định dạng cho phép (assets/.../*.png|jpg|webp)."));
            }
            return;
        }
        try {
            UUID assetId = UUID.fromString(candidate);
            if (!assets.existsByIdAndState(assetId, "ACTIVE")) {
                errors.add(new ValidationError("LAYER", layerKey, "assetRef",
                        "ASSET_NOT_FOUND", "Asset '" + assetId + "' gắn với layer '" + layerKey + "' không tồn tại hoặc không ở trạng thái ACTIVE."));
            }
        } catch (IllegalArgumentException ex) {
            errors.add(new ValidationError("LAYER", layerKey, "assetRef",
                    "INVALID_ASSET_REF",
                    "Tham chiếu asset '" + assetRef + "' của layer '" + layerKey + "' không hợp lệ (cần UUID Media Library hoặc đường dẫn assets/...)."));
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

        // Board + tiles (V48): clone trước slots để remap tileId.
        Map<UUID, UUID> tileIdRemap = new HashMap<>();
        boards.findById(source.getId()).ifPresent(srcBoard ->
                boards.save(IslandLayoutBoard.create(
                        newVerId, srcBoard.getGridRows(), srcBoard.getGridColumns(),
                        srcBoard.getTileWidth(), srcBoard.getTileHeight(),
                        srcBoard.getBoardOriginX(), srcBoard.getBoardOriginY(),
                        srcBoard.getProjectionType(),
                        srcBoard.isConnectivityRequired(), now)));
        boards.flush();

        for (IslandTile t : tiles.findByLayoutVersionIdOrderByRowIndexAscColIndexAsc(source.getId())) {
            UUID newTileId = UUID.randomUUID();
            tileIdRemap.put(t.getId(), newTileId);
            tiles.save(IslandTile.create(
                    newTileId, newVerId, t.getTileKey(),
                    t.getRowIndex(), t.getColIndex(), t.getTerrainType(),
                    t.getRegionCode(), t.getUnlockTier(), t.isBuildable(),
                    t.getVisualKey(), t.getElevation(), now
            ));
        }
        tiles.flush();

        for (IslandSlot s : slots.findByLayoutVersionIdOrderBySlotIndex(source.getId())) {
            slots.save(IslandSlot.create(
                    UUID.randomUUID(), def.getLayoutKey(), newVerId,
                    s.getSlotIndex(), s.getTierRequired(), s.getCoordX(), s.getCoordY(),
                    s.getStableSlotKey(), s.getRegionCode(),
                    s.getTileId() != null ? tileIdRemap.get(s.getTileId()) : null,
                    s.getZIndex(),
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

    /**
     * Starter draft tile-based "Làng Việt" (ISLAND-09-BE + ISLAND-10-BE):
     * đảo liền mạch trên lưới 8x10 — TIER_1 lõi quanh sân đất trung tâm với
     * đường làng PATH dẫn ra, TIER_2 vòng vườn mở rộng (tre, lúa, hoa cỏ),
     * TIER_3 nền đá di sản nâng elevation (sen, đèn đá, gạch nung).
     * Buildable 4 ô mỗi tier — phân bố rải, chừa khoảng thở quanh ô lớn;
     * cumulative 4/8/12 khớp policy hiện hành — Admin chỉnh được, không đụng
     * version PUBLISHED đã tồn tại.
     */
    private IslandLayoutVersion createStarterDraft(IslandLayoutDefinition def, int versionNo, Instant now) {
        UUID verId = UUID.randomUUID();
        IslandLayoutVersion draft = IslandLayoutVersion.createDraft(verId, def.getId(), versionNo, now);
        versions.saveAndFlush(draft);

        // Board 8x10 — ô hình thoi 128x64, gốc tọa độ logic 0,0
        boards.save(IslandLayoutBoard.create(verId, 8, 10,
                128.0, 64.0, 0.0, 0.0, "ISOMETRIC", true, now));
        boards.flush();

        regions.save(IslandLayoutRegion.create(UUID.randomUUID(), verId, "TIER_1", 1,
                "Khu Trung Tâm", null, 1, now));
        regions.save(IslandLayoutRegion.create(UUID.randomUUID(), verId, "TIER_2", 2,
                "Khu Mở Rộng", null, 2, now));
        regions.save(IslandLayoutRegion.create(UUID.randomUUID(), verId, "TIER_3", 3,
                "Khu Cao Cấp", null, 3, now));
        regions.flush();

        // Footprint: {row, col, terrain, region, buildable, visualKey, elevation}
        record StarterTile(int row, int col, String terrain, String region,
                           boolean buildable, String visualKey, int elevation) {}
        List<StarterTile> footprint = new ArrayList<>();
        java.util.function.BiConsumer<int[][], String> addCells = (cells, reg) -> {
            for (int[] c : cells) {
                footprint.add(new StarterTile(c[0], c[1], "GRASS", reg,
                        false, null, 0));
            }
        };

        // TIER_1 lõi (12 ô): r2:{c4,c5} r3:{c3..c6} r4:{c3..c6} r5:{c4,c5}
        addCells.accept(new int[][]{{2,4},{2,5},{3,3},{3,4},{3,5},{3,6},
                {4,3},{4,4},{4,5},{4,6},{5,4},{5,5}}, "TIER_1");
        // TIER_2 vòng (12 ô): r1:{c4,c5} r2:{c3,c6} r3:{c2,c7} r4:{c2,c7}
        //                      r5:{c3,c6} r6:{c4,c5}
        addCells.accept(new int[][]{{1,4},{1,5},{2,3},{2,6},{3,2},{3,7},
                {4,2},{4,7},{5,3},{5,6},{6,4},{6,5}}, "TIER_2");
        // TIER_3 rìa (12 ô): r0:{c4,c5} r1:{c3,c6} r2:{c2,c7} r5:{c2,c7}
        //                    r6:{c3,c6} r7:{c4,c5}
        addCells.accept(new int[][]{{0,4},{0,5},{1,3},{1,6},{2,2},{2,7},
                {5,2},{5,7},{6,3},{6,6},{7,4},{7,5}}, "TIER_3");

        // Terrain đặc trưng theo coord (ghi đè GRASS nền).
        // T1: sân đất DIRT quảng trường + trục PATH đi bộ; T2: vườn nông
        // thôn; T3: nền đá di sản. DECORATIVE bắt buộc kèm visualKey.
        Map<String, String> terrainAt = new HashMap<>();
        terrainAt.put("3:5", "DIRT");
        for (String coord : new String[]{"2:4","2:5","4:4","4:5","5:4"}) {
            terrainAt.put(coord, "PATH");
        }
        for (String coord : new String[]{"0:4","0:5","1:3","1:6","6:3","6:6"}) {
            terrainAt.put(coord, "STONE");
        }

        // visualKey — metadata nghệ thuật: bắt buộc trên DECORATIVE, cũng gắn
        // lên PATH/STONE để FE render đường làng/cụm đá có hồn hơn.
        Map<String, String> visualKeyAt = new HashMap<>();
        // Trang trí T1: bụi cây + đèn đá cạnh quảng trường.
        visualKeyAt.put("3:3", "shrub_cluster");
        visualKeyAt.put("4:6", "heritage_lamp");
        // Trang trí T2: vườn tre, ruộng lúa, hoa cỏ, đầm sen.
        visualKeyAt.put("1:5", "bamboo_cluster");
        visualKeyAt.put("2:3", "bamboo_cluster");
        visualKeyAt.put("5:6", "bamboo_cluster");
        visualKeyAt.put("4:2", "rice_patch");
        visualKeyAt.put("6:5", "rice_patch");
        visualKeyAt.put("3:2", "grass_flowers");
        visualKeyAt.put("2:6", "grass_flowers");
        visualKeyAt.put("3:7", "lotus_patch");
        // Trang trí T3: cây đa, gạch nung; cụm đá gắn trên nền STONE.
        visualKeyAt.put("5:7", "clay_bricks");
        visualKeyAt.put("7:5", "banyan_sapling");
        visualKeyAt.put("1:3", "stone_cluster");
        visualKeyAt.put("6:6", "stone_cluster");
        // Đường làng qua quảng trường.
        visualKeyAt.put("4:4", "village_path");
        // Ô trang trí thuần (không đường/đất/đá) → DECORATIVE.
        Set<String> decorativeAt = Set.of(
                "3:3", "4:6",
                "1:5", "2:3", "5:6", "4:2", "6:5", "3:2", "2:6", "3:7",
                "5:7", "7:5");
        for (String coord : decorativeAt) {
            terrainAt.put(coord, "DECORATIVE");
        }

        // Buildable: 4 ô mỗi tier trên nền GRASS — rải đều (khoảng cách
        // Manhattan ≥ 2), chừa clearance quanh ô lớn, không ô nào trùng
        // cảnh quan → cumulative 4/8/12 khớp policy hiện hành.
        Set<String> buildableAt = Set.of(
                "3:4", "3:6", "4:3", "5:5",        // TIER_1 quanh quảng trường
                "1:4", "4:7", "5:3", "6:4",        // TIER_2 vườn ngoài
                "2:2", "2:7", "5:2", "7:4");       // TIER_3 nền đá rìa

        Map<String, IslandTile> tileByCoord = new HashMap<>();
        for (StarterTile st : footprint) {
            String coord = st.row() + ":" + st.col();
            boolean buildable = buildableAt.contains(coord);
            String terrain = terrainAt.getOrDefault(coord, st.terrain());
            String visualKey = visualKeyAt.get(coord);
            // Chỉ GRASS host công trình — cảnh quan/đường đi không buildable.
            if (!"GRASS".equals(terrain)) {
                buildable = false;
            }
            // Vùng TIER_3 cao hơn — tạo chiều sâu thị giác cho khu di sản.
            int elevation = "TIER_3".equals(st.region()) ? 1 : 0;
            String tKey = "tile_r" + st.row() + "_c" + st.col();
            int tier = Integer.parseInt(st.region().substring("TIER_".length()));
            IslandTile tile = IslandTile.create(
                    UUID.randomUUID(), verId, tKey, st.row(), st.col(),
                    terrain, st.region(), tier, buildable, visualKey, elevation, now);
            tiles.save(tile);
            tileByCoord.put(coord, tile);
        }
        tiles.flush();

        // 12 slots gắn 1:1 vào các tile buildable — thứ tự quét hàng/cột,
        // tier suy từ region của tile chứa. coordX/Y vẫn ghi 0..1 (tương
        // thích client cũ) theo phép chiếu iso: x=(col-row)/(cols+rows-2)+0.5.
        List<Map.Entry<String, IslandTile>> buildableTiles = tileByCoord.entrySet().stream()
                .filter(e -> e.getValue().isBuildable())
                .sorted(Comparator.comparingInt((Map.Entry<String, IslandTile> e) -> e.getValue().getRowIndex())
                        .thenComparingInt(e -> e.getValue().getColIndex()))
                .toList();
        int denom = 8 + 10 - 2; // gridRows + gridCols - 2
        int slotIdx = 1;
        for (Map.Entry<String, IslandTile> e : buildableTiles) {
            IslandTile tile = e.getValue();
            int r = tile.getRowIndex(), c = tile.getColIndex();
            double cx = Math.min(1.0, Math.max(0.0,
                    0.5 + (double) (c - r) / denom));
            double cy = Math.min(1.0, Math.max(0.0,
                    (double) (c + r) / denom));
            int tier = Integer.parseInt(tile.getRegionCode().substring("TIER_".length()));
            slots.save(IslandSlot.create(
                    UUID.randomUUID(), def.getLayoutKey(), verId,
                    slotIdx, tier, cx, cy,
                    "slot_" + slotIdx, tile.getRegionCode(), tile.getId(),
                    slotIdx * 10, 0.5, 1.0, 0.10, 0.12, "[\"DECOR\"]", now
            ));
            slotIdx++;
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

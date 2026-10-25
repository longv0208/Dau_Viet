package com.dauviet.reward.application;

import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.api.PageResponse;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.reward.api.dto.AdminItemRequest;
import com.dauviet.reward.api.dto.AdminItemResponse;
import com.dauviet.reward.api.dto.AdminRuleRequest;
import com.dauviet.reward.domain.ItemCatalog;
import com.dauviet.reward.domain.ItemUnlockRule;
import com.dauviet.reward.infrastructure.persistence.ItemCatalogRepository;
import com.dauviet.reward.infrastructure.persistence.ItemUnlockRuleRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Cấu hình catalog + unlock rule phía admin (TASK-0023 — tối thiểu, không
 * CMS đầy đủ). Item chỉ tạo/sửa metadata; rule một active mỗi item —
 * tạo rule mới tự tắt rule cũ thay vì sửa lịch sử (vật phẩm đã cấp vẫn
 * giữ nguyên trong user_inventory, không revoke).
 */
@Service
public class AdminItemService {

    private final ItemCatalogRepository items;
    private final ItemUnlockRuleRepository rules;
    private final LessonRepository lessons;
    private final jakarta.persistence.EntityManager em;
    private final ObjectMapper mapper;
    private final ItemConditionParser conditionParser;
    private final ItemConditionValidator conditionValidator;
    private final ItemRuleScopeResolver scopeResolver;
    private final com.dauviet.reward.infrastructure.persistence
            .UserInventoryRepository inventory;

    public AdminItemService(ItemCatalogRepository items,
                            ItemUnlockRuleRepository rules,
                            LessonRepository lessons,
                            jakarta.persistence.EntityManager em,
                            ObjectMapper mapper,
                            ItemConditionParser conditionParser,
                            ItemConditionValidator conditionValidator,
                            ItemRuleScopeResolver scopeResolver,
                            com.dauviet.reward.infrastructure.persistence
                                    .UserInventoryRepository inventory) {
        this.items = items;
        this.rules = rules;
        this.lessons = lessons;
        this.em = em;
        this.mapper = mapper;
        this.conditionParser = conditionParser;
        this.conditionValidator = conditionValidator;
        this.scopeResolver = scopeResolver;
        this.inventory = inventory;
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminItemResponse> list(Boolean active,
                                                Pageable pageable) {
        var page = items.search(active, pageable);
        Map<UUID, ItemUnlockRule> ruleByItem = activeRules(page.getContent()
                .stream().map(ItemCatalog::getId).toList());
        return PageResponse.from(page.map(i -> toResponse(i, ruleByItem)));
    }

    @Transactional(readOnly = true)
    public AdminItemResponse get(UUID itemId) {
        ItemCatalog item = load(itemId);
        return toResponse(item, activeRules(java.util.List.of(itemId)));
    }

    @Transactional
    public AdminItemResponse create(AdminItemRequest req) {
        if (items.findByCode(req.code()).isPresent()) {
            throw new IllegalArgumentException(
                    "item code already exists: " + req.code());
        }
        ItemCatalog item = ItemCatalog.create(req.code(), req.name(),
                req.category(), req.itemType());
        apply(item, req);
        return toResponse(items.save(item), Map.of());
    }

    @Transactional
    public AdminItemResponse update(UUID itemId, AdminItemRequest req) {
        ItemCatalog item = load(itemId);
        apply(item, req);
        return toResponse(items.save(item),
                activeRules(java.util.List.of(itemId)));
    }

    /**
     * Gán/thay rule cho item. Atomic + serialize theo item:
     * pessimistic lock trên row item_catalog → deactivate mọi rule
     * active hiện có (flush trước) → insert rule mới, nên partial unique
     * index "một active rule mỗi item" không bao giờ bị vi phạm kể cả
     * khi Hibernate sắp thứ tự flush khác. Vật phẩm đã cấp trong
     * user_inventory không bị thu hồi — chỉ lịch sử rule mới đổi.
     */
    @Transactional
    public AdminItemResponse setRule(UUID itemId, AdminRuleRequest req) {
        ItemCatalog item = items.findByIdForUpdate(itemId).orElseThrow(() ->
                new ResourceNotFoundException("item not found: " + itemId));
        ItemUnlockRule rule = buildRule(itemId, req);
        // Flush UPDATE active=false trước INSERT rule mới để không đụng
        // ux_item_unlock_rule_item (chỉ một active rule/item). Rule cũ
        // append-only: không UPDATE/DELETE — version cũ ngừng áp dụng cho
        // grant MỚI, provenance user_inventory đã ghi giữ nguyên.
        for (ItemUnlockRule r : rules.findByItemIdOrderByCreatedAtAsc(itemId)) {
            r.setActive(false);
        }
        em.flush();
        if (req.active() != null && !req.active()) {
            rule.setActive(false);
        }
        rules.save(rule);
        return toResponse(item, activeRules(java.util.List.of(itemId)));
    }

    /**
     * Xây rule row từ request: có `condition` → AST v2 (parse + validate
     * nghiêm — ItemRuleException → 400); không có → rule v1 3-loại như cũ.
     *
     * FIX-5: ruleType của request chỉ được trống hoặc đúng 'RULE_V2' khi
     * kèm `condition` — chuỗi lạ (UNKNOWN_RULE, LESSON_COUNT…) đi kèm AST
     * là mâu thuẫn cấu hình → 400 trước khi chạm DB, không để constraint
     * flush bắt. rule_type cột là discriminator của hệ thống.
     *
     * FINAL FIX-2: scope CẤP ITEM — item đã bị audit 'needs-mapping'
     * (chưa minh định event) hoặc đã event-scoped thì chỉ chấp nhận rule
     * mới có leaf event-scoped; một rule đếm global mới (COLLECTION_COUNT/
     * LESSON_COUNT v1, hoặc AST không gắn event) bị 400 — không phá bảo
     * vệ sự kiện bằng rule mới không flag. Item GLOBAL thật sự vẫn dùng
     * được mọi rule hợp lệ. Không hard-code mã item — scope suy ra từ
     * audit trail (rule_metadata + eventId trong AST đã publish).
     *
     * FINAL FIX-3: revision = thứ tự publish per-item (monotonic), độc
     * lập schema rule_version — rule V1 lẫn V2 đều lấy max(revision)+1
     * nên V1→V2→V1 không lặp/giảm; rule_version chỉ mô tả payload (1=V1
     * cột phẳng, 2=AST).
     */
    private ItemUnlockRule buildRule(UUID itemId, AdminRuleRequest req) {
        if (req.condition() != null && !req.condition().isNull()) {
            String ruleType = req.ruleType();
            if (ruleType != null && !ruleType.isBlank()
                    && !ItemUnlockRule.TYPE_RULE_V2.equals(ruleType)) {
                throw new IllegalArgumentException(
                        "ruleType '" + ruleType + "' contradicts a v2 "
                                + "condition — only 'RULE_V2' (or omitted) "
                                + "is allowed alongside an AST");
            }
            ItemCondition condition = conditionParser.parse(req.condition());
            conditionValidator.validate(condition);
            if (!scopeResolver.acceptsRule(itemId, condition)) {
                throw new IllegalArgumentException(
                        "item is event-scoped/awaiting event mapping — only "
                        + "a rule with an event-scoped condition may be "
                        + "activated for this item");
            }
            int revision = rules.findMaxRevision(itemId) + 1;
            if (revision < 2) revision = 2; // publish v2 đầu rõ "không phải legacy"
            return ItemUnlockRule.v2(itemId, ItemUnlockRule.TYPE_RULE_V2,
                    req.condition().toString(), null, revision);
        }
        validateV1(req);
        // Rule V1 không bao giờ event-scoped (3 loại global/lesson) — item
        // event-scoped hoặc đang chờ mapping không được kích hoạt nó.
        ItemUnlockRule.ItemScope scope = scopeResolver.scopeOf(itemId);
        if (scope != ItemUnlockRule.ItemScope.GLOBAL) {
            throw new IllegalArgumentException(
                    "item is " + scope + " — a global v1 rule cannot be "
                    + "activated; publish an event-scoped v2 rule first");
        }
        int revision = rules.findMaxRevision(itemId) + 1;
        return switch (req.ruleType()) {
            case ItemUnlockRule.TYPE_LESSON_COMPLETED ->
                    ItemUnlockRule.lessonCompleted(itemId, req.lessonId(),
                            revision);
            default -> ItemUnlockRule.counted(itemId, req.ruleType(),
                    req.threshold(), revision);
        };
    }

    private void validateV1(AdminRuleRequest req) {
        if (req.ruleType() == null) {
            throw new IllegalArgumentException("ruleType is required");
        }
        switch (req.ruleType()) {
            case ItemUnlockRule.TYPE_LESSON_COMPLETED -> {
                if (req.lessonId() == null) {
                    throw new IllegalArgumentException(
                            "LESSON_COMPLETED requires lessonId");
                }
                // Rule phải trỏ tới bài học learner có thể truy cập: đã
                // PUBLISHED (còn hiệu lực, không archived/draft).
                Lesson lesson = lessons.findById(req.lessonId())
                        .orElseThrow(() -> new IllegalArgumentException(
                                "lesson not found: " + req.lessonId()));
                if (lesson.getStatus() != LessonStatus.PUBLISHED) {
                    throw new IllegalArgumentException(
                            "lesson not published: " + req.lessonId());
                }
            }
            case ItemUnlockRule.TYPE_COLLECTION_COUNT,
                 ItemUnlockRule.TYPE_LESSON_COUNT -> {
                if (req.threshold() == null) {
                    throw new IllegalArgumentException(
                            req.ruleType() + " requires threshold");
                }
            }
            default -> throw new IllegalArgumentException(
                    "unsupported ruleType: " + req.ruleType());
        }
    }

    /**
     * Dry-run validate rule (GAME-06 Module C) — chay dung pipeline
     * buildRule (parse -> validate -> scope) nhung KHONG ghi DB.
     * Tra errors co cau truc thay vi nem exception de UI hien tat ca
     * loi cung luc; loi tham chieu (event/lesson khong PUBLISHED) tu
     * validator duoc map sang VALIDATION_FAILED.
     */
    @Transactional(readOnly = true)
    public com.dauviet.reward.api.dto.AdminRuleValidationResponse validateRule(
            UUID itemId, AdminRuleRequest req) {
        load(itemId);
        var scope = scopeResolver.scopeOf(itemId);
        var errors = new java.util.ArrayList<
                com.dauviet.reward.api.dto.AdminRuleValidationResponse.Issue>();
        var warnings = new java.util.ArrayList<String>();
        JsonNode normalized = null;
        boolean accepts = true;

        if (scope != ItemUnlockRule.ItemScope.GLOBAL) {
            warnings.add("item is " + scope + " — a rule without an "
                    + "event-scoped leaf will be rejected on publish");
        }

        try {
            if (req.condition() != null && !req.condition().isNull()) {
                String ruleType = req.ruleType();
                if (ruleType != null && !ruleType.isBlank()
                        && !ItemUnlockRule.TYPE_RULE_V2.equals(ruleType)) {
                    errors.add(issue("RULETYPE_CONTRADICTS_AST",
                            "ruleType '" + ruleType + "' contradicts a v2 "
                            + "condition — only 'RULE_V2' (or omitted) is "
                            + "allowed alongside an AST", "ruleType"));
                } else {
                    ItemCondition condition =
                            conditionParser.parse(req.condition());
                    conditionValidator.validate(condition);
                    normalized = req.condition();
                    accepts = scopeResolver.acceptsRule(itemId, condition);
                    if (!accepts) {
                        errors.add(issue("SCOPE_REJECTED",
                                "item is " + scope + " — only a rule with "
                                + "an event-scoped leaf may be activated",
                                "condition"));
                    }
                }
            } else {
                validateV1(req);
                accepts = scope == ItemUnlockRule.ItemScope.GLOBAL;
                if (!accepts) {
                    errors.add(issue("SCOPE_REJECTED",
                            "item is " + scope + " — a global v1 rule "
                            + "cannot be activated; publish an "
                            + "event-scoped v2 rule first", "ruleType"));
                }
            }
        } catch (ItemRuleException | IllegalArgumentException e) {
            errors.add(issue("VALIDATION_FAILED",
                    e.getMessage() == null ? "invalid rule" : e.getMessage(),
                    null));
        }

        return new com.dauviet.reward.api.dto.AdminRuleValidationResponse(
                errors.isEmpty(), errors, warnings, normalized,
                scope.name(), accepts);
    }

    /**
     * Lich su revision cua item (GAME-06) — moi nhat truoc, kem
     * grantCount (user_inventory.unlock_rule_id provenance).
     */
    @Transactional(readOnly = true)
    public java.util.List<com.dauviet.reward.api.dto.AdminRuleHistoryEntry>
            ruleHistory(UUID itemId) {
        load(itemId);
        return rules.findByItemIdOrderByRevisionDesc(itemId).stream()
                .map(r -> new com.dauviet.reward.api.dto.AdminRuleHistoryEntry(
                        r.getId(), r.getRuleType(), r.getLessonId(),
                        r.getThreshold(), r.getRuleVersion(), r.getRevision(),
                        r.isActive(), parse(r.getConditionJson()),
                        parse(r.getRuleMetadata()), r.getCreatedAt(),
                        inventory.countByUnlockRuleId(r.getId())))
                .toList();
    }

    private com.dauviet.reward.api.dto.AdminRuleValidationResponse.Issue
            issue(String code, String message, String field) {
        return new com.dauviet.reward.api.dto.AdminRuleValidationResponse
                .Issue(code, message, field);
    }

    private ItemCatalog load(UUID itemId) {
        return items.findById(itemId).orElseThrow(() ->
                new ResourceNotFoundException("item not found: " + itemId));
    }

    /**
     * Partial update: field null trong request = "không thay đổi" — sửa
     * title/category/rarity không xoá assetId hay sourceMetadata hiện
     * có. Xoá có chủ đích: assetId gửi chuỗi rỗng "" (clear), sourceMetadata
     * gửi {} (object rỗng → lưu null). Giữ @Version optimistic lock trên
     * entity — hai admin sửa cùng item, người sau bị ObjectOptimisticLock
     * → 409, không ghi đè lặng lẽ.
     */
    private void apply(ItemCatalog item, AdminItemRequest req) {
        if (req.name() != null) item.setName(req.name());
        if (req.description() != null) item.setDescription(req.description());
        if (req.category() != null) item.setCategory(req.category());
        if (req.itemType() != null) item.setItemType(req.itemType());
        if (req.rarity() != null) item.setRarity(req.rarity());
        if (req.assetId() != null) item.setAssetId(req.assetId());
        if (req.clearAsset() == Boolean.TRUE) item.setAssetId(null);
        if (req.sourceMetadata() != null) {
            // {} = clear có chủ đích; object có nội dung = thay mới.
            item.setSourceMetadata(req.sourceMetadata().isEmpty()
                    ? null : req.sourceMetadata().toString());
        }
        if (req.active() != null) item.setActive(req.active());
    }

    private Map<UUID, ItemUnlockRule> activeRules(
            java.util.List<UUID> itemIds) {
        return itemIds.stream()
                .map(rules::findByItemIdAndActiveTrue)
                .flatMap(java.util.Optional::stream)
                .collect(Collectors.toMap(ItemUnlockRule::getItemId,
                        Function.identity()));
    }

    private AdminItemResponse toResponse(ItemCatalog item,
                                         Map<UUID, ItemUnlockRule> ruleByItem) {
        ItemUnlockRule r = ruleByItem.get(item.getId());
        return new AdminItemResponse(
                item.getId(), item.getCode(), item.getName(),
                item.getDescription(), item.getCategory(), item.getItemType(),
                item.getRarity(), item.getAssetId(), parse(item.getSourceMetadata()),
                item.isActive(), item.getRowVersion(),
                scopeResolver.scopeOf(item.getId()).name(),
                r == null ? null : new AdminItemResponse.Rule(
                        r.getId(), r.getRuleType(), r.getLessonId(),
                        r.getThreshold(), r.isActive(), r.getRuleVersion(),
                        parse(r.getConditionJson()),
                        parse(r.getRuleMetadata())));
    }

    private JsonNode parse(String json) {
        if (json == null || json.isBlank()) return null;
        try {
            return mapper.readTree(json);
        } catch (Exception e) {
            return null;
        }
    }
}

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

    public AdminItemService(ItemCatalogRepository items,
                            ItemUnlockRuleRepository rules,
                            LessonRepository lessons,
                            jakarta.persistence.EntityManager em,
                            ObjectMapper mapper) {
        this.items = items;
        this.rules = rules;
        this.lessons = lessons;
        this.em = em;
        this.mapper = mapper;
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
        validateRule(req);
        // Flush UPDATE active=false trước INSERT rule mới để không đụng
        // ux_item_unlock_rule_item (chỉ một active rule/item).
        for (ItemUnlockRule r : rules.findByItemIdOrderByCreatedAtAsc(itemId)) {
            r.setActive(false);
        }
        em.flush();
        ItemUnlockRule rule = switch (req.ruleType()) {
            case ItemUnlockRule.TYPE_LESSON_COMPLETED ->
                    ItemUnlockRule.lessonCompleted(itemId, req.lessonId());
            default -> ItemUnlockRule.counted(itemId, req.ruleType(),
                    req.threshold());
        };
        if (req.active() != null && !req.active()) {
            rule.setActive(false);
        }
        rules.save(rule);
        return toResponse(item, activeRules(java.util.List.of(itemId)));
    }

    private void validateRule(AdminRuleRequest req) {
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
                r == null ? null : new AdminItemResponse.Rule(
                        r.getId(), r.getRuleType(), r.getLessonId(),
                        r.getThreshold(), r.isActive()));
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

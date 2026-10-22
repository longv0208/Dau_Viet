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
    private final ObjectMapper mapper;

    public AdminItemService(ItemCatalogRepository items,
                            ItemUnlockRuleRepository rules,
                            ObjectMapper mapper) {
        this.items = items;
        this.rules = rules;
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
     * Gán rule cho item: tắt mọi rule active hiện có rồi tạo rule mới —
     * đổi điều kiện không ảnh hưởng vật phẩm đã cấp (append-only).
     */
    @Transactional
    public AdminItemResponse setRule(UUID itemId, AdminRuleRequest req) {
        ItemCatalog item = load(itemId);
        validateRule(req);
        rules.findByItemIdOrderByCreatedAtAsc(itemId)
                .forEach(r -> r.setActive(false));
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

    private void apply(ItemCatalog item, AdminItemRequest req) {
        item.setName(req.name());
        item.setDescription(req.description() == null ? "" : req.description());
        item.setCategory(req.category());
        item.setItemType(req.itemType());
        if (req.rarity() != null) item.setRarity(req.rarity());
        item.setAssetId(req.assetId());
        item.setSourceMetadata(req.sourceMetadata() == null
                ? null : req.sourceMetadata().toString());
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

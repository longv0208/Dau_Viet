package com.dauviet.reward.application;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.dauviet.reward.domain.ItemUnlockRule;
import com.dauviet.reward.infrastructure.persistence.ItemUnlockRuleRepository;

/**
 * FINAL FIX-2: phân giải scope đã duyệt của một ITEM từ LỊCH SỬ rule —
 * bảo vệ ở cấp item thay vì chỉ ở bản rule đang active, để admin không
 * thể bypass cờ needs-mapping bằng cách setRule một rule global mới.
 *
 * Quyết định lấy từ dữ liệu (rule_metadata.audit + eventId trong AST của
 * các rule đã publish), KHÔNG hard-code mã item hay tên sự kiện — một
 * item event-specific mới tự được bảo vệ ngay khi rule đầu của nó
 * event-scoped; một item global thực sự (chưa flagged, chưa có rule
 * event-scoped) vẫn dùng được rule đếm global.
 */
@Component
public class ItemRuleScopeResolver {

    private final ItemUnlockRuleRepository rules;
    private final ItemConditionParser parser;

    public ItemRuleScopeResolver(ItemUnlockRuleRepository rules,
                                 ItemConditionParser parser) {
        this.rules = rules;
        this.parser = parser;
    }

    /** Scope đã duyệt của item — xem {@link ItemUnlockRule.ItemScope}. */
    public ItemUnlockRule.ItemScope scopeOf(UUID itemId) {
        List<ItemUnlockRule> history =
                rules.findByItemIdOrderByCreatedAtAsc(itemId);
        boolean everNeedsMapping = false;
        boolean everEventScoped = false;
        for (ItemUnlockRule r : history) {
            if (ItemUnlockRule.isNeedsMapping(r.getRuleMetadata())) {
                everNeedsMapping = true;
            }
            if (isEventScoped(r)) {
                everEventScoped = true;
            }
        }
        // Một item đã có rule event-scoped hợp lệ → scope của nó là event —
        // kể cả khi trước đó từng needs-mapping (đã được minh định).
        if (everEventScoped) return ItemUnlockRule.ItemScope.EVENT_SCOPED;
        if (everNeedsMapping) return ItemUnlockRule.ItemScope.UNRESOLVED;
        return ItemUnlockRule.ItemScope.GLOBAL;
    }

    /** Rule có chứa ít nhất một leaf event-scoped trong AST không. */
    public boolean isEventScoped(ItemUnlockRule rule) {
        String json = rule.getConditionJson();
        if (json == null || json.isBlank()) return false;
        try {
            return containsEventScopedLeaf(parser.parse(json));
        } catch (ItemRuleException e) {
            return false;
        }
    }

    /** Rule mới (request) có phù hợp scope đã duyệt của item không. */
    public boolean acceptsRule(UUID itemId, ItemCondition newCondition) {
        return switch (scopeOf(itemId)) {
            // Chưa minh định event: chỉ chấp nhận rule event-scoped để mở
            // khoá audit — một rule global mới vẫn để item UNCONFIGURED.
            case UNRESOLVED, EVENT_SCOPED ->
                    containsEventScopedLeaf(newCondition);
            case GLOBAL -> true;
        };
    }

    private boolean containsEventScopedLeaf(ItemCondition c) {
        return switch (c) {
            case ItemCondition.Leaf l ->
                    ItemUnlockRule.isEventScopedLeaf(l.type())
                    && l.eventId() != null;
            case ItemCondition.All a -> a.children().stream()
                    .anyMatch(this::containsEventScopedLeaf);
            case ItemCondition.Any a -> a.children().stream()
                    .anyMatch(this::containsEventScopedLeaf);
        };
    }
}

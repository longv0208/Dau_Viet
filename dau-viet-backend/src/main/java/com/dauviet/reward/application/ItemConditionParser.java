package com.dauviet.reward.application;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Parse condition_json thành {@link ItemCondition} typed AST (GAME-05).
 *
 * Grammar (contract §2.5/§10): root là leaf | {"all":[cond…]} | {"any":[cond…]};
 * ALL/ANY chỉ được bọc leaf — depth ≤ 2 (root + một lớp operator), con của
 * ALL/ANY không được là operator khác (không arbitrary nesting, review
 * được bằng mắt). Mọi JSON lệch grammar → {@link ItemRuleException}
 * (400 tại admin endpoint), không bao giờ len lỏi parse lỏng.
 */
@Component
public class ItemConditionParser {

    /** Root là depth 0; ALL/ANY nằm depth 1 — con của chúng phải là leaf. */
    static final int MAX_DEPTH = 2;

    private final ObjectMapper mapper;

    public ItemConditionParser(ObjectMapper mapper) {
        this.mapper = mapper;
    }

    /** Parse từ chuỗi JSON lưu trong DB. */
    public ItemCondition parse(String json) {
        if (json == null || json.isBlank()) {
            throw new ItemRuleException("condition_json is empty");
        }
        try {
            return parseNode(mapper.readTree(json), 0);
        } catch (ItemRuleException e) {
            throw e;
        } catch (Exception e) {
            throw new ItemRuleException(
                    "condition_json malformed: " + e.getMessage());
        }
    }

    /** Parse từ JsonNode (admin request gửi object, không phải string). */
    public ItemCondition parse(JsonNode node) {
        return parseNode(node, 0);
    }

    private ItemCondition parseNode(JsonNode node, int depth) {
        if (node == null || !node.isObject()) {
            throw new ItemRuleException(
                    "condition must be an object at depth " + depth);
        }
        if (node.has("all")) return parseOperator(node.get("all"), true, depth);
        if (node.has("any")) return parseOperator(node.get("any"), false, depth);
        return parseLeaf(node, depth);
    }

    private ItemCondition parseOperator(JsonNode children, boolean all,
                                        int depth) {
        if (depth + 1 >= MAX_DEPTH) {
            // Con của operator depth-1 sẽ ở depth 2 = giới hạn — chỉ leaf.
        }
        if (!children.isArray() || children.isEmpty()) {
            throw new ItemRuleException(
                    (all ? "all" : "any") + " requires a non-empty array");
        }
        if (children.size() > 20) {
            throw new ItemRuleException(
                    (all ? "all" : "any") + " supports at most 20 children");
        }
        List<ItemCondition> parsed = new ArrayList<>(children.size());
        for (JsonNode child : children) {
            if (!child.isObject() || child.has("all") || child.has("any")) {
                // Nested operator — vượt depth limit của contract.
                throw new ItemRuleException(
                        "nested all/any is not allowed (depth limit 2)");
            }
            parsed.add(parseLeaf(child, depth + 1));
        }
        return all ? new ItemCondition.All(parsed)
                   : new ItemCondition.Any(parsed);
    }

    private ItemCondition.Leaf parseLeaf(JsonNode node, int depth) {
        JsonNode typeNode = node.get("type");
        if (typeNode == null || !typeNode.isTextual()) {
            throw new ItemRuleException("leaf requires a textual 'type'");
        }
        ItemCondition.LeafType type;
        try {
            type = ItemCondition.LeafType.valueOf(typeNode.asText());
        } catch (IllegalArgumentException e) {
            throw new ItemRuleException(
                    "unsupported condition type: " + typeNode.asText());
        }
        UUID eventId = uuid(node.get("eventId"), "eventId");
        UUID lessonId = uuid(node.get("lessonId"), "lessonId");
        Integer threshold = positiveInt(node.get("threshold"), "threshold");
        Integer level = positiveInt(node.get("level"), "level");
        List<UUID> evidenceIds = uuidList(node.get("evidenceIds"));
        return new ItemCondition.Leaf(type, eventId, lessonId, evidenceIds,
                threshold, level);
    }

    private UUID uuid(JsonNode node, String field) {
        if (node == null || node.isNull()) return null;
        if (!node.isTextual()) {
            throw new ItemRuleException(field + " must be a uuid string");
        }
        try {
            return UUID.fromString(node.asText());
        } catch (IllegalArgumentException e) {
            throw new ItemRuleException(field + " is not a uuid");
        }
    }

    private Integer positiveInt(JsonNode node, String field) {
        if (node == null || node.isNull()) return null;
        if (!node.isIntegralNumber() || node.asInt() <= 0) {
            throw new ItemRuleException(field + " must be a positive integer");
        }
        return node.asInt();
    }

    private List<UUID> uuidList(JsonNode node) {
        if (node == null || node.isNull()) return List.of();
        if (!node.isArray() || node.isEmpty()) {
            throw new ItemRuleException(
                    "evidenceIds must be a non-empty array");
        }
        List<UUID> out = new ArrayList<>(node.size());
        for (JsonNode n : node) {
            if (!n.isTextual()) {
                throw new ItemRuleException("evidenceIds must be uuid strings");
            }
            try {
                out.add(UUID.fromString(n.asText()));
            } catch (IllegalArgumentException e) {
                throw new ItemRuleException("evidenceIds contains a non-uuid");
            }
        }
        return out;
    }
}

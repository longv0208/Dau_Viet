package com.dauviet.reward.application;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
 *
 * STRICT SHAPE (GAME-05 FIX-2): không silent-ignore trường thừa —
 *  - node operator chỉ được đúng một key ("all" XOR "any"): {"all":…,"any":…},
 *    {"all":…,"type":…} hay {"all":…,"extra":…} đều reject;
 *  - leaf chỉ chấp nhận các trường THUỘC shape của type (ví dụ
 *    COLLECTION_COUNT không được có eventId — eventId trước đây bị bỏ
 *    qua âm thầm làm admin tưởng rule event-scoped);
 *  - trường bắt buộc phải có mặt + đúng kiểu (phân biệt thiếu/null/sai
 *    kiểu); field lạ (typo như "threshhold") bị reject thay vì bỏ qua.
 */
@Component
public class ItemConditionParser {

    /** Root là depth 0; ALL/ANY nằm depth 1 — con của chúng phải là leaf. */
    static final int MAX_DEPTH = 2;

    /**
     * Trường được phép trên leaf theo từng type (FIX-2). "type" luôn bắt
     * buộc nên không liệt kê. Trường hợp lệ nhưng không thuộc shape của
     * type khai báo → reject (không infer eventId cho rule global).
     */
    private static final Map<ItemCondition.LeafType, Set<String>>
            ALLOWED_LEAF_FIELDS = Map.ofEntries(
            Map.entry(ItemCondition.LeafType.LESSON_COMPLETED,
                    Set.of("lessonId")),
            Map.entry(ItemCondition.LeafType.LESSON_MASTERED,
                    Set.of("lessonId", "threshold")),
            Map.entry(ItemCondition.LeafType.COLLECTION_COUNT,
                    Set.of("threshold")),
            Map.entry(ItemCondition.LeafType.LESSON_COUNT,
                    Set.of("threshold")),
            Map.entry(ItemCondition.LeafType.EVENT_COMPLETED,
                    Set.of("eventId")),
            Map.entry(ItemCondition.LeafType.EVENT_MASTERED,
                    Set.of("eventId")),
            Map.entry(ItemCondition.LeafType.EVENT_EVIDENCE_COUNT,
                    Set.of("eventId", "threshold")),
            Map.entry(ItemCondition.LeafType.SPECIFIC_EVIDENCE_SET,
                    Set.of("eventId", "evidenceIds")),
            Map.entry(ItemCondition.LeafType.TOTAL_EVENTS_COMPLETED,
                    Set.of("threshold")),
            Map.entry(ItemCondition.LeafType.TOTAL_EVENTS_MASTERED,
                    Set.of("threshold")),
            Map.entry(ItemCondition.LeafType.LEVEL_AT_LEAST,
                    Set.of("level")));

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
        boolean hasAll = node.has("all");
        boolean hasAny = node.has("any");
        if (hasAll || hasAny) {
            return parseOperator(node, hasAll, depth);
        }
        return parseLeaf(node, depth);
    }

    /**
     * Node operator: chỉ được một key duy nhất ("all" hoặc "any") —
     * mọi key kèm theo (any/all còn lại, "type", hay field lạ) đều làm
     * JSON mơ hồ → reject thay vì chọn một nhánh bỏ qua phần còn lại.
     */
    private ItemCondition parseOperator(JsonNode node, boolean all,
                                        int depth) {
        String op = all ? "all" : "any";
        if (node.size() != 1) {
            List<String> keys = new ArrayList<>();
            node.fieldNames().forEachRemaining(keys::add);
            throw new ItemRuleException(
                    "operator node must have exactly the '" + op
                            + "' key — extraneous fields " + keys
                            + " are not allowed (ambiguous JSON)");
        }
        JsonNode children = node.get(op);
        if (!children.isArray() || children.isEmpty()) {
            throw new ItemRuleException(
                    op + " requires a non-empty array");
        }
        if (children.size() > 20) {
            throw new ItemRuleException(
                    op + " supports at most 20 children");
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

    /**
     * Leaf: "type" bắt buộc + textual; sau đó MỌI trường trên node phải
     * thuộc ALLOWED_LEAF_FIELDS của type (FIX-2) — trường ngoài shape
     * (eventId trên COLLECTION_COUNT, threshold trên EVENT_COMPLETED,
     * field lạ bất kỳ) → reject để admin thấy ngay rule đã khai báo sai.
     * Kiểu của từng trường được chặt qua uuid/positiveInt/uuidList.
     */
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

        // Reject mọi trường không thuộc shape của type — kể cả trường
        // hợp lệ của type khác (ambiguity) lẫn field lạ (typo).
        Set<String> allowed = ALLOWED_LEAF_FIELDS.get(type);
        List<String> extra = new ArrayList<>();
        node.fieldNames().forEachRemaining(name -> {
            if (!"type".equals(name) && !allowed.contains(name)) {
                extra.add(name);
            }
        });
        if (!extra.isEmpty()) {
            throw new ItemRuleException(type
                    + " does not accept field(s) " + extra
                    + " — allowed: " + new java.util.TreeSet<>(allowed));
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

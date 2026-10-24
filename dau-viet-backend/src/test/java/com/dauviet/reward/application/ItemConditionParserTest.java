package com.dauviet.reward.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Unit matrix cho {@link ItemConditionParser} (GAME-05): grammar AST
 * leaf | {all:[leaf…]} | {any:[leaf…]}, depth ≤ 2. Mọi JSON lệch grammar
 * → ItemRuleException (không bao giờ parse lỏng len lỏi).
 */
class ItemConditionParserTest {

    private final ItemConditionParser parser =
            new ItemConditionParser(new ObjectMapper());

    private final String ev = UUID.randomUUID().toString();
    private final String ls = UUID.randomUUID().toString();
    private final String e1 = UUID.randomUUID().toString();
    private final String e2 = UUID.randomUUID().toString();

    /* ---------- leaf hợp lệ ---------- */

    @Test
    void parsesLessonCompletedLeaf() {
        ItemCondition c = parser.parse(
                "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\"" + ls + "\"}");
        assertThat(c).isInstanceOf(ItemCondition.Leaf.class);
        ItemCondition.Leaf l = (ItemCondition.Leaf) c;
        assertThat(l.type()).isEqualTo(ItemCondition.LeafType.LESSON_COMPLETED);
        assertThat(l.lessonId()).isEqualTo(UUID.fromString(ls));
    }

    @Test
    void parsesEveryLeafType() {
        for (ItemCondition.LeafType t : ItemCondition.LeafType.values()) {
            String json = switch (t) {
                case LESSON_COMPLETED ->
                        "{\"type\":\"" + t + "\",\"lessonId\":\"" + ls
                                + "\"}";
                case LESSON_MASTERED ->
                        "{\"type\":\"" + t + "\",\"lessonId\":\"" + ls
                                + "\",\"threshold\":70}";
                case COLLECTION_COUNT, LESSON_COUNT, TOTAL_EVENTS_COMPLETED,
                     TOTAL_EVENTS_MASTERED ->
                        "{\"type\":\"" + t + "\",\"threshold\":2}";
                case EVENT_COMPLETED, EVENT_MASTERED ->
                        "{\"type\":\"" + t + "\",\"eventId\":\"" + ev + "\"}";
                case EVENT_EVIDENCE_COUNT ->
                        "{\"type\":\"" + t + "\",\"eventId\":\"" + ev
                                + "\",\"threshold\":3}";
                case SPECIFIC_EVIDENCE_SET ->
                        "{\"type\":\"" + t + "\",\"eventId\":\"" + ev
                                + "\",\"evidenceIds\":[\"" + e1 + "\"]}";
                case LEVEL_AT_LEAST ->
                        "{\"type\":\"" + t + "\",\"level\":5}";
            };
            ItemCondition parsed = parser.parse(json);
            assertThat(((ItemCondition.Leaf) parsed).type()).isEqualTo(t);
        }
    }

    /* ---------- operators ---------- */

    @Test
    void parsesAllAndAny() {
        ItemCondition all = parser.parse(
                "{\"all\":[{\"type\":\"LESSON_COUNT\",\"threshold\":2},"
              + "{\"type\":\"COLLECTION_COUNT\",\"threshold\":3}]}");
        assertThat(all).isInstanceOf(ItemCondition.All.class);
        assertThat(((ItemCondition.All) all).children()).hasSize(2);

        ItemCondition any = parser.parse(
                "{\"any\":[{\"type\":\"EVENT_COMPLETED\",\"eventId\":\""
              + ev + "\"}]}");
        assertThat(any).isInstanceOf(ItemCondition.Any.class);
        assertThat(((ItemCondition.Any) any).children()).hasSize(1);
    }

    /* ---------- malformed / depth ---------- */

    @Test
    void rejectsBlankAndMalformedJson() {
        assertThatThrownBy(() -> parser.parse(""))
                .isInstanceOf(ItemRuleException.class);
        assertThatThrownBy(() -> parser.parse((String) null))
                .isInstanceOf(ItemRuleException.class);
        assertThatThrownBy(() -> parser.parse("{not json"))
                .isInstanceOf(ItemRuleException.class);
        assertThatThrownBy(() -> parser.parse("[1,2]"))
                .isInstanceOf(ItemRuleException.class);
    }

    @Test
    void rejectsNestedOperator_beyondDepthTwo() {
        // {all:[{any:[leaf]}]} — con của all là operator → depth vượt 2.
        assertThatThrownBy(() -> parser.parse(
                "{\"all\":[{\"any\":[{\"type\":\"LESSON_COUNT\","
              + "\"threshold\":1}]}]}"))
                .isInstanceOf(ItemRuleException.class)
                .hasMessageContaining("depth");
    }

    @Test
    void rejectsEmptyOperatorArray() {
        assertThatThrownBy(() -> parser.parse("{\"all\":[]}"))
                .isInstanceOf(ItemRuleException.class);
        assertThatThrownBy(() -> parser.parse("{\"any\":[]}"))
                .isInstanceOf(ItemRuleException.class);
    }

    @Test
    void rejectsUnknownTypeAndMissingType() {
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"NOT_A_TYPE\"}"))
                .isInstanceOf(ItemRuleException.class)
                .hasMessageContaining("unsupported condition type");
        assertThatThrownBy(() -> parser.parse("{\"foo\":1}"))
                .isInstanceOf(ItemRuleException.class)
                .hasMessageContaining("type");
    }

    @Test
    void rejectsBadFieldShapes() {
        // threshold âm / không số.
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"LESSON_COUNT\",\"threshold\":-1}"))
                .isInstanceOf(ItemRuleException.class);
        // evidenceIds rỗng.
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + ev
              + "\",\"evidenceIds\":[]}"))
                .isInstanceOf(ItemRuleException.class);
        // evidenceIds chứa non-uuid.
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + ev
              + "\",\"evidenceIds\":[\"nope\"]}"))
                .isInstanceOf(ItemRuleException.class);
        // eventId không phải uuid.
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"x\"}"))
                .isInstanceOf(ItemRuleException.class);
    }

    /* ---------- FIX-2: strict shape — không silent-ignore ---------- */

    @Test
    void rejectsExtraneousFieldOnLeaf_theQa16Bug() {
        // Bug gốc: eventId trên LESSON_COUNT từng bị BỎ QUA âm thầm →
        // admin tưởng rule event-scoped nhưng evaluator đếm global.
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"LESSON_COUNT\",\"threshold\":3,"
              + "\"eventId\":\"" + ev + "\"}"))
                .isInstanceOf(ItemRuleException.class)
                .hasMessageContaining("eventId");
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"COLLECTION_COUNT\",\"threshold\":3,"
              + "\"eventId\":\"" + ev + "\"}"))
                .isInstanceOf(ItemRuleException.class);
    }

    @Test
    void rejectsUnknownField_typoDoesNotSlipThrough() {
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"LESSON_COUNT\",\"threshhold\":3}"))
                .isInstanceOf(ItemRuleException.class)
                .hasMessageContaining("threshhold");
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + ev
              + "\",\"foo\":1}"))
                .isInstanceOf(ItemRuleException.class);
    }

    @Test
    void rejectsFieldOfWrongLeafShape() {
        // threshold trên EVENT_COMPLETED (shape chỉ {eventId}).
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + ev
              + "\",\"threshold\":2}"))
                .isInstanceOf(ItemRuleException.class);
        // lessonId trên EVENT_EVIDENCE_COUNT.
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"EVENT_EVIDENCE_COUNT\",\"eventId\":\"" + ev
              + "\",\"threshold\":2,\"lessonId\":\"" + ls + "\"}"))
                .isInstanceOf(ItemRuleException.class);
        // evidenceIds trên LESSON_COMPLETED.
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\"" + ls
              + "\",\"evidenceIds\":[\"" + e1 + "\"]}"))
                .isInstanceOf(ItemRuleException.class);
    }

    @Test
    void rejectsAmbiguousOperatorNode() {
        // {"all":[…],"any":[…]} — không được chọn một nhánh bỏ qua nhánh kia.
        assertThatThrownBy(() -> parser.parse(
                "{\"all\":[{\"type\":\"LESSON_COUNT\",\"threshold\":1}],"
              + "\"any\":[{\"type\":\"LESSON_COUNT\",\"threshold\":1}]}"))
                .isInstanceOf(ItemRuleException.class)
                .hasMessageContaining("all");
        // {"all":[…],"type":…} — operator node không được mang "type".
        assertThatThrownBy(() -> parser.parse(
                "{\"all\":[{\"type\":\"LESSON_COUNT\",\"threshold\":1}],"
              + "\"type\":\"LESSON_COUNT\"}"))
                .isInstanceOf(ItemRuleException.class);
        // {"all":[…],"extra":…} — field lạ kèm theo.
        assertThatThrownBy(() -> parser.parse(
                "{\"all\":[{\"type\":\"LESSON_COUNT\",\"threshold\":1}],"
              + "\"note\":\"hi\"}"))
                .isInstanceOf(ItemRuleException.class);
    }

    @Test
    void rejectsMissingRequiredField() {
        // Type hợp lệ nhưng không field nào — parser nhận, validator
        // chặn; nhưng field SAI KIỂU thì parser phải bắt ngay.
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":123}"))
                .isInstanceOf(ItemRuleException.class)
                .hasMessageContaining("lessonId");
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"TOTAL_EVENTS_COMPLETED\","
              + "\"threshold\":\"2\"}"))
                .isInstanceOf(ItemRuleException.class)
                .hasMessageContaining("threshold");
        assertThatThrownBy(() -> parser.parse(
                "{\"type\":\"LEVEL_AT_LEAST\",\"level\":0}"))
                .isInstanceOf(ItemRuleException.class);
    }

    @Test
    void acceptsEveryLeafTypeWithExactShape() {
        // Ma trận đầy đủ: mỗi type parse được với đúng shape của nó
        // (không hơn không kém) — khoá lại contract strict-shape.
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\"" + ls
                        + "\"}")).type())
                .isEqualTo(ItemCondition.LeafType.LESSON_COMPLETED);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"LESSON_MASTERED\",\"lessonId\":\"" + ls
                        + "\",\"threshold\":70}")).type())
                .isEqualTo(ItemCondition.LeafType.LESSON_MASTERED);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"COLLECTION_COUNT\",\"threshold\":3}")).type())
                .isEqualTo(ItemCondition.LeafType.COLLECTION_COUNT);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"LESSON_COUNT\",\"threshold\":3}")).type())
                .isEqualTo(ItemCondition.LeafType.LESSON_COUNT);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + ev
                        + "\"}")).type())
                .isEqualTo(ItemCondition.LeafType.EVENT_COMPLETED);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"EVENT_MASTERED\",\"eventId\":\"" + ev
                        + "\"}")).type())
                .isEqualTo(ItemCondition.LeafType.EVENT_MASTERED);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"EVENT_EVIDENCE_COUNT\",\"eventId\":\"" + ev
                        + "\",\"threshold\":3}")).type())
                .isEqualTo(ItemCondition.LeafType.EVENT_EVIDENCE_COUNT);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + ev
                        + "\",\"evidenceIds\":[\"" + e1 + "\",\""
                        + e2 + "\"]}")).type())
                .isEqualTo(ItemCondition.LeafType.SPECIFIC_EVIDENCE_SET);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"TOTAL_EVENTS_COMPLETED\","
                        + "\"threshold\":2}")).type())
                .isEqualTo(ItemCondition.LeafType.TOTAL_EVENTS_COMPLETED);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"TOTAL_EVENTS_MASTERED\","
                        + "\"threshold\":2}")).type())
                .isEqualTo(ItemCondition.LeafType.TOTAL_EVENTS_MASTERED);
        assertThat(((ItemCondition.Leaf) parser.parse(
                "{\"type\":\"LEVEL_AT_LEAST\",\"level\":5}")).type())
                .isEqualTo(ItemCondition.LeafType.LEVEL_AT_LEAST);
    }
}

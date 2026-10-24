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
                case LESSON_COMPLETED, LESSON_MASTERED ->
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
}

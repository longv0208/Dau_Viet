package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * GAME-05 — Item Unlock Rule Engine V2 end-to-end. Requires Docker.
 *
 * Bao phủ kịch bản hợp đồng: EVENT_EVIDENCE_COUNT scope event (không
 * global), SPECIFIC_EVIDENCE_SET, EVENT_COMPLETED/TOTAL_EVENTS_* đọc
 * ledger (milestone ghi TRƯỚC item eval trong doComplete), ALL/ANY,
 * unsupported LEVEL_AT_LEAST không grant, validation chặn publish rule
 * xấu, rule append-only (v1 → v2), needs-mapping chặn grant mới.
 */
@SpringBootTest
@AutoConfigureMockMvc
class ItemRuleEngineIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String learnerId;
    private String eventId;
    private String tplId;
    private String ev1;
    private String ev2;
    private String ev3;

    private static final String MC_CONFIG =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"]}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from reward_transactions");
        jdbc.update("delete from user_inventory");
        jdbc.update("delete from item_unlock_rule");
        jdbc.update("delete from item_catalog");
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@g5.vn",
                UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@g5.vn",
                UserRole.LEARNER);
        learnerId = userIdByEmail("l@g5.vn");
        eventId = AttemptItFixture.newEvent(jdbc, "e-g5");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-g5");
        ev1 = AttemptItFixture.newEvidence(jdbc, eventId);
        ev2 = AttemptItFixture.newEvidence(jdbc, eventId);
        ev3 = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    /* ---------- helpers ---------- */

    private String userIdByEmail(String email) {
        return jdbc.queryForObject(
                "select id from users where email = ?", String.class, email);
    }

    private String publish(String draftJson) throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId,
                tplId, draftJson);
    }

    private MvcResult submit(String token, String attemptId,
                             String activityId, String answerJson)
            throws Exception {
        return mvc.perform(post("/api/v1/attempts/" + attemptId
                        + "/activities/" + activityId + "/submissions")
                        .header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":" + answerJson + "}"))
                .andReturn();
    }

    private void complete(String token, String attemptId) throws Exception {
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", token))
                .andExpect(status().isOk());
    }

    /** Draft 1 EVIDENCE_SELECT stage duy nhất — collect evidence qua submit. */
    private String draftEs(String... evIds) {
        StringBuilder vis = new StringBuilder("[");
        for (int i = 0; i < evIds.length; i++) {
            if (i > 0) vis.append(',');
            vis.append('"').append(evIds[i]).append('"');
        }
        vis.append(']');
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                    "config":{"visibleEvidenceIds":%s,"minRequired":1}}],
                    "requiredEvidenceIds":%s,
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(vis, vis);
    }

    private void collect(String token, String lessonId, String... evIds)
            throws Exception {
        String attemptId = AttemptItFixture.startAttempt(mvc, om, token,
                lessonId);
        StringBuilder sel = new StringBuilder("[");
        for (int i = 0; i < evIds.length; i++) {
            if (i > 0) sel.append(',');
            sel.append('"').append(evIds[i]).append('"');
        }
        sel.append(']');
        submit(token, attemptId, "es",
                "{\"selectedEvidenceIds\":" + sel + "}");
        complete(token, attemptId);
    }

    private String newItem(String code, String itemType) {
        String id = UUID.randomUUID().toString();
        jdbc.update("""
                insert into item_catalog (id, code, name, category, item_type,
                                          rarity, active)
                values (?::uuid, ?, ?, 'HUY_HIEU', ?, 'COMMON', true)
                """, id, code, "Item " + code, itemType);
        return id;
    }

    /** Set rule v2 qua admin API — đường duy nhất hợp lệ để publish AST. */
    private MvcResult setRuleV2(String itemId, String conditionJson)
            throws Exception {
        return mvc.perform(put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"condition\":" + conditionJson + "}"))
                .andReturn();
    }

    private void setRuleV2ExpectOk(String itemId, String conditionJson)
            throws Exception {
        MvcResult res = setRuleV2(itemId, conditionJson);
        assertThat(res.getResponse().getStatus())
                .as("setRuleV2 should succeed, body=%s",
                        res.getResponse().getContentAsString())
                .isEqualTo(200);
    }

    private long inventoryCount(String where) {
        Long n = jdbc.queryForObject(
                "select count(*) from user_inventory where " + where,
                Long.class);
        return n == null ? 0 : n;
    }

    private String completeMcLesson(String token, String lessonId)
            throws Exception {
        String attemptId = AttemptItFixture.startAttempt(mvc, om, token,
                lessonId);
        submit(token, attemptId, "r1", "{}");
        submit(token, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}");
        complete(token, attemptId);
        return attemptId;
    }

    /* ---------- A. EVENT_EVIDENCE_COUNT: scope event, không global ---------- */

    @Test
    void eventEvidenceCount_usesEventScope_notGlobal() throws Exception {
        // Item yêu cầu 3 evidence CỦA eventId — QA-16: count global của 7
        // evidence khác không được mở item này.
        String itemId = newItem("COC_BACH_DANG", "DIGITAL_EDITION");
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"EVENT_EVIDENCE_COUNT\",\"eventId\":\"" + eventId
                        + "\",\"threshold\":3}");

        // Lesson event này collect ev1 + ev2 (2/3) — chưa đạt.
        String lesson = publish(draftEs(ev1, ev2, ev3));
        collect(learnerToken, lesson, ev1, ev2);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();

        // Evidence event KHÁC — global count lên nhưng event-scope vẫn 2.
        String otherEvent = AttemptItFixture.newEvent(jdbc, "e-other");
        String otherEv = AttemptItFixture.newEvidence(jdbc, otherEvent);
        String otherLesson = AttemptItFixture.publishLesson(mvc, om,
                adminToken, otherEvent, tplId, draftEs(otherEv));
        collect(learnerToken, otherLesson, otherEv);
        // Global = 3 (ev1+ev2+otherEv) nhưng event-scope vẫn 2 → vẫn khoá.
        assertThat(jdbc.queryForObject(
                "select count(distinct evidence_id) from user_evidence "
              + "where user_id = ?::uuid", Long.class, learnerId))
                .isEqualTo(3);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();

        // Thêm ev3 của đúng event → đạt ngưỡng 3 → grant trong tx submit.
        collect(learnerToken, lesson, ev3);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    /* ---------- B. SPECIFIC_EVIDENCE_SET ---------- */

    @Test
    void specificEvidenceSet_requiresAllListedOfEvent() throws Exception {
        String itemId = newItem("BO_BANG_CHUNG", "COMMEMORATIVE_BADGE");
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev2
                        + "\"]}");

        String lesson = publish(draftEs(ev1, ev2, ev3));
        collect(learnerToken, lesson, ev1);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();
        // ev3 không thuộc set — collect thêm vẫn chưa đủ.
        collect(learnerToken, lesson, ev3);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();
        collect(learnerToken, lesson, ev2);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    /* ---------- C. EVENT_COMPLETED: ledger sau ordering fix ---------- */

    @Test
    void eventCompletedRule_grantsWhenMilestoneRecordedSameTx()
            throws Exception {
        // Policy: event complete khi required lesson done. Item điều kiện
        // EVENT_COMPLETED(eventId) — doComplete phải ghi milestone TRƯỚC
        // khi đánh giá item, cùng tx (ordering fix GAME-05).
        String lesson = publish(AttemptItFixture.draftTwoStage(ev1,
                MC_CONFIG));
        jdbc.update("""
                insert into event_completion_policies
                    (id, event_id, policy_version, status, required_lesson_ids,
                     optional_lesson_ids, mastery_threshold, published_at)
                values (?::uuid, ?::uuid, 1, 'PUBLISHED', ?::jsonb,
                        '[]'::jsonb, NULL, now())
                """, UUID.randomUUID().toString(), eventId,
                "[\"" + lesson + "\"]");

        String itemId = newItem("HUY_HIEU_EVENT_DONE", "COMMEMORATIVE_BADGE");
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + eventId
                        + "\"}");

        // Trước complete: chưa có milestone → khoá.
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();

        // Complete lesson → milestone ghi + item eval trong cùng tx → grant
        // NGAY (không cần reconcile) vì evaluator thấy milestone vừa ghi.
        completeMcLesson(learnerToken, lesson);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
        // Provenance: source_event_id = event.
        assertThat(jdbc.queryForObject(
                "select source_event_id::text from user_inventory "
              + "where user_id = ?::uuid and item_id = ?::uuid",
                String.class, learnerId, itemId))
                .isEqualTo(eventId);
    }

    /* ---------- D. ALL/ANY ---------- */

    @Test
    void allOperator_requiresEveryLeaf() throws Exception {
        String lesson = publish(AttemptItFixture.draftTwoStage(ev1,
                MC_CONFIG));
        String itemId = newItem("MO_HINH_ALL", "HISTORICAL_REPLICA");
        setRuleV2ExpectOk(itemId,
                "{\"all\":["
              + "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\"" + lesson
                        + "\"},"
              + "{\"type\":\"COLLECTION_COUNT\",\"threshold\":1}]}");

        // Chỉ complete lesson — chưa collect → ALL chưa đạt.
        completeMcLesson(learnerToken, lesson);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();

        // Collect ev1 (lesson khác, đủ 1 evidence) → cả hai leaf đạt → grant.
        String esLesson = publish(draftEs(ev1));
        collect(learnerToken, esLesson, ev1);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    @Test
    void anyOperator_oneLeafSatisfiedGrants() throws Exception {
        String lesson = publish(AttemptItFixture.draftTwoStage(ev1,
                MC_CONFIG));
        String itemId = newItem("HUY_HIEU_ANY", "COMMEMORATIVE_BADGE");
        setRuleV2ExpectOk(itemId,
                "{\"any\":["
              + "{\"type\":\"LESSON_COUNT\",\"threshold\":99},"
              + "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\"" + lesson
                        + "\"}]}");
        completeMcLesson(learnerToken, lesson);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    /* ---------- E. unsupported condition: không bao giờ satisfied ---------- */

    @Test
    void levelAtLeast_neverGrants_andPublishRejected() throws Exception {
        String itemId = newItem("HUY_HIEU_LEVEL", "COMMEMORATIVE_BADGE");
        // Validator chặn publish — LEVEL_AT_LEAST chưa đánh giá (GAME-07).
        MvcResult res = setRuleV2(itemId,
                "{\"type\":\"LEVEL_AT_LEAST\",\"level\":3}");
        assertThat(res.getResponse().getStatus()).isEqualTo(400);
        // Không rule nào được ghi → grant không xảy ra.
        completeMcLesson(learnerToken,
                publish(AttemptItFixture.draftTwoStage(ev1, MC_CONFIG)));
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();
    }

    /* ---------- F. validation: malformed + tham chiếu xấu → 400 ---------- */

    @Test
    void setRuleV2_rejectsMalformedAndBadReferences() throws Exception {
        String itemId = newItem("PHIEN_BAN_BADRULE", "DIGITAL_EDITION");
        // Malformed AST (nested operator vượt depth).
        assertThat(setRuleV2(itemId,
                "{\"all\":[{\"all\":[{\"type\":\"LESSON_COUNT\","
                        + "\"threshold\":1}]}]}")
                .getResponse().getStatus()).isEqualTo(400);
        // Type không hỗ trợ.
        assertThat(setRuleV2(itemId, "{\"type\":\"TELEPORT\"}")
                .getResponse().getStatus()).isEqualTo(400);
        // EVENT_COMPLETED trỏ event không tồn tại.
        assertThat(setRuleV2(itemId,
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\""
                        + UUID.randomUUID() + "\"}")
                .getResponse().getStatus()).isEqualTo(400);
        // EVENT_COMPLETED trỏ event NOT_CONFIGURED (chưa có policy).
        String bareEvent = AttemptItFixture.newEvent(jdbc, "e-nopolicy");
        assertThat(setRuleV2(itemId,
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + bareEvent
                        + "\"}")
                .getResponse().getStatus()).isEqualTo(400);
        // SPECIFIC_EVIDENCE_SET: evidence không thuộc event khai báo.
        String otherEvent = AttemptItFixture.newEvent(jdbc, "e-x");
        String foreignEv = AttemptItFixture.newEvidence(jdbc, otherEvent);
        assertThat(setRuleV2(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + foreignEv + "\"]}")
                .getResponse().getStatus()).isEqualTo(400);
        // Duplicate evidenceIds.
        assertThat(setRuleV2(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev1
                        + "\"]}")
                .getResponse().getStatus()).isEqualTo(400);
        // Không có rule nào được ghi sau toàn bộ rejection.
        Long rules = jdbc.queryForObject(
                "select count(*) from item_unlock_rule where item_id = ?::uuid",
                Long.class, itemId);
        assertThat(rules).isZero();
    }

    /* ---------- G. rule append-only: v1 → v2 giữ provenance ---------- */

    @Test
    void ruleVersionUpgrade_oldGrantsKept_newRuleAppliesFresh() throws Exception {
        String lesson = publish(AttemptItFixture.draftTwoStage(ev1,
                MC_CONFIG));
        // v1: LESSON_COUNT=1 → learner grant ngay.
        String itemId = newItem("HUY_HIEU_V1_TO_V2", "COMMEMORATIVE_BADGE");
        jdbc.update("""
                insert into item_unlock_rule (id, item_id, rule_type,
                                              threshold, active)
                values (?::uuid, ?::uuid, 'LESSON_COUNT', 1, true)
                """, UUID.randomUUID().toString(), itemId);
        completeMcLesson(learnerToken, lesson);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);

        // Admin nâng rule → v2 (COLLECTION_COUNT=99, không thể đạt). Rule cũ
        // deactivate — ownership của learner KHÔNG bị thu hồi.
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"COLLECTION_COUNT\",\"threshold\":99}");
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
        // Rule mới rule_version=2; rule cũ v1 vẫn nằm lại (append-only).
        assertThat(jdbc.queryForObject(
                "select count(*) from item_unlock_rule where item_id = ?::uuid",
                Long.class, itemId)).isEqualTo(2);
        assertThat(jdbc.queryForObject(
                "select rule_version from item_unlock_rule "
              + "where item_id = ?::uuid and active = true",
                Integer.class, itemId)).isEqualTo(2);
    }

    /* ---------- H. needs-mapping: audit flag chặn grant mới ---------- */

    @Test
    void needsMappingSeed_blocksNewGrant_untilV2Rule() throws Exception {
        String lesson = publish(draftEs(ev1));
        String itemId = newItem("COC_NEEDS_MAP", "DIGITAL_EDITION");
        // Giả lập seed V12 đã flag needs-mapping (V24 audit).
        jdbc.update("""
                insert into item_unlock_rule (id, item_id, rule_type,
                                              threshold, active, rule_metadata)
                values (?::uuid, ?::uuid, 'COLLECTION_COUNT', 1, true,
                        '{"audit":"needs-mapping"}'::jsonb)
                """, UUID.randomUUID().toString(), itemId);
        collect(learnerToken, lesson, ev1);
        // Audit flag → không grant dù learner đủ điều kiện V1.
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();
    }

    /* ---------- I. catalog requirement tree ---------- */

    @Test
    void catalog_returnsRequirementTreeWithBranchStatus() throws Exception {
        String lesson = publish(AttemptItFixture.draftTwoStage(ev1,
                MC_CONFIG));
        String itemId = newItem("MO_HINH_TREE", "HISTORICAL_REPLICA");
        setRuleV2ExpectOk(itemId,
                "{\"all\":["
              + "{\"type\":\"LESSON_COMPLETED\",\"lessonId\":\"" + lesson
                        + "\"},"
              + "{\"type\":\"EVENT_EVIDENCE_COUNT\",\"eventId\":\"" + eventId
                        + "\",\"threshold\":2}]}");

        MvcResult res = mvc.perform(get("/api/v1/me/inventory/catalog")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        JsonNode items = AttemptItFixture.body(om, res);
        JsonNode item = null;
        for (JsonNode i : items) {
            if (itemId.equals(i.get("itemId").asText())) item = i;
        }
        assertThat(item).isNotNull();
        JsonNode req = item.get("requirement");
        assertThat(req.get("operator").asText()).isEqualTo("ALL");
        assertThat(req.get("satisfied").asBoolean()).isFalse();
        JsonNode children = req.get("conditions");
        assertThat(children).hasSize(2);
        // Leaf 1: LESSON_COMPLETED PENDING; leaf 2: EVENT_EVIDENCE_COUNT
        // current=0/required=2 — per-branch current cho Flutter.
        assertThat(children.get(1).get("type").asText())
                .isEqualTo("EVENT_EVIDENCE_COUNT");
        assertThat(children.get(1).get("required").asLong()).isEqualTo(2);
        assertThat(children.get(1).get("current").asLong()).isZero();
    }

    /* ---------- J. v1 rule vẫn evaluate (legacy semantics) ---------- */

    @Test
    void v1Rules_stillEvaluate_afterV24Migration() throws Exception {
        // Seed v1 thủ công không condition_json → evaluator fallback cột
        // phẳng; grant vẫn xảy ra (tương thích rule đã publish trước V24).
        String itemId = newItem("HUY_HIEU_V1_LEGACY", "COMMEMORATIVE_BADGE");
        jdbc.update("""
                insert into item_unlock_rule (id, item_id, rule_type,
                                              threshold, active)
                values (?::uuid, ?::uuid, 'COLLECTION_COUNT', 1, true)
                """, UUID.randomUUID().toString(), itemId);
        String lesson = publish(draftEs(ev1));
        collect(learnerToken, lesson, ev1);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }
}

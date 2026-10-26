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
        jdbc.update("delete from island_shop_items");
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
        // Publish lesson chứa ev1+ev2+ev3 TRƯỚC — FIX-6: evidence phải
        // collectible (nằm trong snapshot PUBLISHED) mới được set rule.
        String lesson = publish(draftEs(ev1, ev2, ev3));
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev2
                        + "\"]}");
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

    /** Draft activity READ-only (không EVIDENCE_SELECT nào) nhưng tham
     *  chiếu evidence qua requiredEvidenceIds + evidenceRefs + config —
     *  evidence xuất hiện trong snapshot.evidence[] nhưng learner không
     *  thể collect (FINAL FIX-4). Cần activity non-READ required khác để
     *  qua draft validation. */
    private String draftReadOnly(String evId, String mcConfig) {
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[
                      {"id":"r1","type":"READ","required":true,
                       "config":{"text":"intro","evidenceRefs":["%s"]}},
                      {"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                       "config":%s}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(evId, mcConfig, evId);
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
        // FINAL FIX-3: revision phân biệt hai publish (v1 legacy=1, v2=2).
        assertThat(jdbc.queryForObject(
                "select revision from item_unlock_rule "
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

    /* ---------- K. FIX-1: needs-mapping → UNCONFIGURED, không fake
       satisfied ---------- */

    @Test
    void needsMapping_catalogShowsUnconfigured_neverFakeSatisfied()
            throws Exception {
        String lesson = publish(draftEs(ev1));
        String itemId = newItem("COC_UNCONF", "DIGITAL_EDITION");
        // Rule V1 đếm global + audit flag needs-mapping (V24 seed audit).
        jdbc.update("""
                insert into item_unlock_rule (id, item_id, rule_type,
                                              threshold, active, rule_metadata)
                values (?::uuid, ?::uuid, 'COLLECTION_COUNT', 1, true,
                        '{"audit":"needs-mapping"}'::jsonb)
                """, UUID.randomUUID().toString(), itemId);

        collect(learnerToken, lesson, ev1); // learner đã đủ ngưỡng V1 (1)
        // Catalog phải báo UNCONFIGURED — KHÔNG satisfied=true dù count đủ.
        MvcResult res = mvc.perform(get("/api/v1/me/inventory/catalog")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        JsonNode items = AttemptItFixture.body(om, res);
        JsonNode item = null;
        for (JsonNode i : items) {
            if (itemId.equals(i.get("itemId").asText())) item = i;
        }
        assertThat(item).isNotNull();
        assertThat(item.get("owned").asBoolean()).isFalse();
        JsonNode req = item.get("requirement");
        assertThat(req.get("status").asText()).isEqualTo("UNCONFIGURED");
        assertThat(req.get("satisfied").asBoolean()).isFalse();
        // Không có progress bar giả.
        assertThat(req.get("conditions").size()).isZero();
        // Grant path vẫn chặn.
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();

        // Admin publish rule v2 event-scoped hợp lệ → flag biến mất, rule
        // đánh giá bình thường (item UNRESOLVED chỉ chấp nhận rule gắn
        // event — FINAL FIX-2; learner đã đủ → reconcile grant).
        newPolicy(1, new String[]{lesson}, null); // policy cho EVENT_*
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"EVENT_EVIDENCE_COUNT\",\"eventId\":\"" + eventId
                        + "\",\"threshold\":1}");
        res = mvc.perform(get("/api/v1/me/inventory/catalog")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        items = AttemptItFixture.body(om, res);
        for (JsonNode i : items) {
            if (itemId.equals(i.get("itemId").asText())) item = i;
        }
        assertThat(item.get("requirement").get("status").asText())
                .isNotEqualTo("UNCONFIGURED");
        assertThat(item.get("requirement").get("satisfied").asBoolean())
                .isTrue(); // count=1 ≥ 1 — giờ mới báo đạt, không fake.
    }

    /* ---------- L. FIX-3: event reconcile → item eval ---------- */

    @Test
    void eventReconcile_writesMilestone_triggersItemUnlock() throws Exception {
        // Learner complete lesson TRƯỚC khi policy tồn tại (pre-GAME-04).
        String lesson = publish(AttemptItFixture.draftTwoStage(ev1,
                MC_CONFIG));
        completeMcLesson(learnerToken, lesson);
        String itemId = newItem("HUY_HIEU_RECONCILE", "COMMEMORATIVE_BADGE");
        // Policy mới + item rule event-scoped — learner đã đủ điều kiện.
        newPolicy(1, new String[]{lesson}, null);
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + eventId
                        + "\"}");
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();
        // Learner mở event progress → reconcile-on-read ghi milestone →
        // FIX-3 trigger item eval ngay trong cùng tx → item grant luôn.
        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
        // Đọc lại — milestone đã có, không re-eval, không dup (UNIQUE).
        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    private void newPolicy(int version, String[] lessonIds,
                           Integer threshold) {
        StringBuilder ids = new StringBuilder("[");
        for (int i = 0; i < lessonIds.length; i++) {
            if (i > 0) ids.append(',');
            ids.append('"').append(lessonIds[i]).append('"');
        }
        ids.append(']');
        jdbc.update("""
                insert into event_completion_policies
                    (id, event_id, policy_version, status, required_lesson_ids,
                     optional_lesson_ids, mastery_threshold, published_at)
                values (?::uuid, ?::uuid, ?, 'PUBLISHED', ?::jsonb,
                        '[]'::jsonb, ?, now())
                """, UUID.randomUUID().toString(), eventId, version,
                ids.toString(), threshold);
    }

    /* ---------- M. FIX-4: rule_version = per-item revision ---------- */

    @Test
    void ruleRevision_incrementsAcrossPublishes_provenanceTraces()
            throws Exception {
        String itemId = newItem("HUY_HIEU_REV", "COMMEMORATIVE_BADGE");
        // 3 publish liên tiếp — revision phải tăng dần (2, 3, 4) phân biệt
        // được ba rule khác nhau (schema rule_version đều =2 AST).
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"COLLECTION_COUNT\",\"threshold\":1}");
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"COLLECTION_COUNT\",\"threshold\":5}");
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"LESSON_COUNT\",\"threshold\":7}");
        var rows = jdbc.queryForList("""
                select rule_version, revision, active from item_unlock_rule
                where item_id = ?::uuid order by revision
                """, itemId);
        assertThat(rows).hasSize(3);
        assertThat(rows.get(0).get("revision")).isEqualTo(2);
        assertThat(rows.get(1).get("revision")).isEqualTo(3);
        assertThat(rows.get(2).get("revision")).isEqualTo(4);
        // Mọi publish đều schema AST (rule_version=2).
        assertThat(rows.get(2).get("rule_version")).isEqualTo(2);
        // Chỉ rule mới nhất active.
        assertThat(rows.get(0).get("active")).isEqualTo(false);
        assertThat(rows.get(1).get("active")).isEqualTo(false);
        assertThat(rows.get(2).get("active")).isEqualTo(true);
        // Một active rule per item tại mọi thời điểm.
        Long activeCount = jdbc.queryForObject(
                "select count(*) from item_unlock_rule where item_id = ?::uuid"
              + " and active = true", Long.class, itemId);
        assertThat(activeCount).isEqualTo(1);
    }

    /* ---------- N. FIX-5: ruleType contradiction → 400 ---------- */

    @Test
    void setRuleV2_rejectsContradictoryRuleType() throws Exception {
        String itemId = newItem("PHIEN_BAN_TYPE", "DIGITAL_EDITION");
        // ruleType UNKNOWN_RULE kèm AST hợp lệ — trước đây lọt validate,
        // fail ở DB CHECK khi flush; giờ phải 400 rõ ràng.
        MvcResult res = mvc.perform(
                put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"UNKNOWN_RULE\",\"condition\":"
                                + "{\"type\":\"COLLECTION_COUNT\","
                                + "\"threshold\":1}}"))
                .andReturn();
        assertThat(res.getResponse().getStatus()).isEqualTo(400);
        // ruleType của v1 đi kèm AST cũng là mâu thuẫn.
        res = mvc.perform(put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"LESSON_COUNT\",\"condition\":"
                                + "{\"type\":\"COLLECTION_COUNT\","
                                + "\"threshold\":1}}"))
                .andReturn();
        assertThat(res.getResponse().getStatus()).isEqualTo(400);
        // Không rule nào ghi vào DB.
        Long rules = jdbc.queryForObject(
                "select count(*) from item_unlock_rule where item_id = ?::uuid",
                Long.class, itemId);
        assertThat(rules).isZero();
    }

    /* ---------- O. FIX-6: evidence phải collectible ---------- */

    @Test
    void specificEvidenceSet_rejectsEvidenceNotInAnyPublishedSnapshot()
            throws Exception {
        String itemId = newItem("BO_CHUNG_ORPHAN", "COMMEMORATIVE_BADGE");
        // ev2 APPROVED thuộc event nhưng KHÔNG nằm trong bất kỳ lesson
        // PUBLISHED nào và chưa ai collect → rule yêu cầu nó là cấu hình
        // chết (learner không bao giờ đạt) → validator chặn publish.
        assertThat(setRuleV2(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + ev2 + "\"]}")
                .getResponse().getStatus()).isEqualTo(400);
        // ev1 có trong published snapshot → chấp nhận.
        publish(draftEs(ev1));
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + ev1 + "\"]}");
    }

    /* ---------- P. FIX-2: strict shape qua API (extraneous fields) ---------- */

    @Test
    void setRuleV2_rejectsExtraneousAndAmbiguousFields() throws Exception {
        String itemId = newItem("PHIEN_BAN_STRICT", "DIGITAL_EDITION");
        // Bug gốc FIX-2: eventId trên LESSON_COUNT bị bỏ qua âm thầm.
        assertThat(setRuleV2(itemId,
                "{\"type\":\"LESSON_COUNT\",\"threshold\":3,"
              + "\"eventId\":\"" + eventId + "\"}")
                .getResponse().getStatus()).isEqualTo(400);
        // all + any đồng thời.
        assertThat(setRuleV2(itemId,
                "{\"all\":[{\"type\":\"LESSON_COUNT\",\"threshold\":1}],"
              + "\"any\":[{\"type\":\"LESSON_COUNT\",\"threshold\":1}]}")
                .getResponse().getStatus()).isEqualTo(400);
        // Operator node mang thêm "type".
        assertThat(setRuleV2(itemId,
                "{\"all\":[{\"type\":\"LESSON_COUNT\",\"threshold\":1}],"
              + "\"type\":\"LESSON_COUNT\"}")
                .getResponse().getStatus()).isEqualTo(400);
        // Field lạ (typo).
        assertThat(setRuleV2(itemId,
                "{\"type\":\"LESSON_COUNT\",\"threshhold\":3}")
                .getResponse().getStatus()).isEqualTo(400);
        Long rules = jdbc.queryForObject(
                "select count(*) from item_unlock_rule where item_id = ?::uuid",
                Long.class, itemId);
        assertThat(rules).isZero();
    }

    /* ---------- Q. FINAL FIX-1: grant qua EVENT_* giữ attempt provenance
       cho result screen ---------- */

    @Test
    void eventMilestoneGrant_keepsAttemptProvenance_showsOnResult()
            throws Exception {
        // Lesson cuối của event → EVENT_COMPLETED ghi trong doComplete;
        // item rule EVENT_COMPLETED grant trong cùng tx phải ghi
        // source_attempt_id = attempt vừa completed để result screen thấy.
        String lesson = publish(AttemptItFixture.draftTwoStage(ev1,
                MC_CONFIG));
        newPolicy(1, new String[]{lesson}, null);
        String itemId = newItem("HUY_HIEU_PROV", "COMMEMORATIVE_BADGE");
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + eventId
                        + "\"}");

        String attemptId = completeMcLesson(learnerToken, lesson);
        // Đúng một grant, provenance = attempt vừa complete + event.
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "select source_attempt_id::text from user_inventory "
              + "where user_id = ?::uuid and item_id = ?::uuid",
                String.class, learnerId, itemId))
                .isEqualTo(attemptId);
        assertThat(jdbc.queryForObject(
                "select acquisition_source from user_inventory "
              + "where user_id = ?::uuid and item_id = ?::uuid",
                String.class, learnerId, itemId))
                .isEqualTo("RULE_UNLOCK");
        // GET /attempts/{id}/result trả badge trong itemsUnlocked.
        MvcResult res = mvc.perform(
                get("/api/v1/attempts/" + attemptId + "/result")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = AttemptItFixture.body(om, res);
        JsonNode unlocked = body.get("itemsUnlocked");
        boolean found = false;
        for (JsonNode i : unlocked) {
            if (itemId.equals(i.get("itemId").asText())) found = true;
        }
        assertThat(found)
                .as("result screen must list the event-granted item")
                .isTrue();

        // Retry complete → nhánh alreadyCompleted, không grant lần hai.
        complete(learnerToken, attemptId);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    /* ---------- R. FINAL FIX-2: item-level event scope không bypass ---------- */

    @Test
    void eventScopedItem_rejectsGlobalRuleUntilEventRule() throws Exception {
        // Item từng có rule flag needs-mapping (V24 audit) — admin KHÔNG
        // được gán rule global mới để lách bảo vệ.
        String itemId = newItem("PHIEN_BAN_SCOPE", "DIGITAL_EDITION");
        jdbc.update("""
                insert into item_unlock_rule (id, item_id, rule_type,
                                              threshold, active, rule_metadata)
                values (?::uuid, ?::uuid, 'COLLECTION_COUNT', 1, true,
                        '{"audit":"needs-mapping"}'::jsonb)
                """, UUID.randomUUID().toString(), itemId);

        // 1) setRule V1 COLLECTION_COUNT global → 400 (item chưa minh định
        //    event; một rule global mới không được phá bảo vệ).
        MvcResult res = mvc.perform(
                put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"COLLECTION_COUNT\","
                                + "\"threshold\":1}"))
                .andReturn();
        assertThat(res.getResponse().getStatus()).isEqualTo(400);

        // 2) setRule v2 global (không leaf event) → cũng 400.
        assertThat(setRuleV2(itemId,
                "{\"type\":\"COLLECTION_COUNT\",\"threshold\":1}")
                .getResponse().getStatus()).isEqualTo(400);

        // 3) Catalog vẫn UNCONFIGURED (chưa minh định event); collect
        //    evidence không grant. Lesson offer cả ev1+ev2 để attempt sau
        //    có thể chọn ev2 (visibleEvidenceIds phải chứa id được chọn).
        String lesson = publish(draftEs(ev1, ev2));
        collect(learnerToken, lesson, ev1);
        MvcResult cat = mvc.perform(get("/api/v1/me/inventory/catalog")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        for (JsonNode i : AttemptItFixture.body(om, cat)) {
            if (itemId.equals(i.get("itemId").asText())) {
                assertThat(i.get("requirement").get("status").asText())
                        .isEqualTo("UNCONFIGURED");
            }
        }
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();

        // 4) Admin gán rule v2 ĐÚNG event (EVENT_EVIDENCE_COUNT=2) → chấp
        //    nhận; item chỉ mở khi đủ evidence CỦA event — không phải
        //    evidence event khác (1 ev1 hiện có không đủ 2).
        newPolicy(1, new String[]{lesson}, null); // policy cho EVENT_*
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"EVENT_EVIDENCE_COUNT\",\"eventId\":\"" + eventId
                        + "\",\"threshold\":2}");
        // Attempt mới chỉ chọn ev2 (minRequired=1 → complete được mà
        // không cần chọn lại ev1) — đủ 2 evidence của event → grant.
        collect(learnerToken, lesson, ev2);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    @Test
    void globalItem_stillAllowsGlobalRule() throws Exception {
        // Item chưa từng flagged / chưa event-scoped → GLOBAL — rule đếm
        // global bình thường được phép (không over-block).
        String itemId = newItem("HUY_HIEU_GLOBAL", "COMMEMORATIVE_BADGE");
        MvcResult res = mvc.perform(
                put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"COLLECTION_COUNT\","
                                + "\"threshold\":1}"))
                .andReturn();
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        String lesson = publish(draftEs(ev1));
        collect(learnerToken, lesson, ev1);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    /* ---------- S. FINAL FIX-3: revision monotonic V1↔V2 ---------- */

    @Test
    void ruleRevision_monotonicAcrossV1V2V1() throws Exception {
        String itemId = newItem("HUY_HIEU_MIX", "COMMEMORATIVE_BADGE");
        String lesson = publish(AttemptItFixture.draftTwoStage(ev1,
                MC_CONFIG));
        // V1 → revision 1; V2 → 2; V2 → 3; V1 (tương thích) → 4 — không
        // lặp/giảm dù schema version quay về 1.
        mvc.perform(put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"LESSON_COUNT\","
                                + "\"threshold\":1}"))
                .andExpect(status().isOk());
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"COLLECTION_COUNT\",\"threshold\":1}");
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"LESSON_COUNT\",\"threshold\":2}");
        mvc.perform(put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"LESSON_COMPLETED\","
                                + "\"lessonId\":\"" + lesson + "\"}"))
                .andExpect(status().isOk());
        var rows = jdbc.queryForList("""
                select rule_version, revision from item_unlock_rule
                where item_id = ?::uuid order by revision
                """, itemId);
        assertThat(rows).hasSize(4);
        // schema: 1,2,2,1 ; revision: 1,2,3,4 — V1 cuối cùng KHÔNG reset về 1.
        assertThat(rows.get(0).get("rule_version")).isEqualTo(1);
        assertThat(rows.get(0).get("revision")).isEqualTo(1);
        assertThat(rows.get(1).get("rule_version")).isEqualTo(2);
        assertThat(rows.get(1).get("revision")).isEqualTo(2);
        assertThat(rows.get(2).get("rule_version")).isEqualTo(2);
        assertThat(rows.get(2).get("revision")).isEqualTo(3);
        assertThat(rows.get(3).get("rule_version")).isEqualTo(1);
        assertThat(rows.get(3).get("revision")).isEqualTo(4);
    }

    /* ---------- T. FINAL FIX-4: evidence phải thật sự collect được ---------- */

    @Test
    void specificEvidenceSet_rejectsEvidenceOnlyInNonSelectActivity()
            throws Exception {
        String itemId = newItem("BO_CHUNG_READ", "COMMEMORATIVE_BADGE");
        // ev2 chỉ nằm trong requiredEvidenceIds của stage + READ (KHÔNG có
        // EVIDENCE_SELECT nào chọn nó) → learner không thể collect → 400.
        publish(draftReadOnly(ev2, MC_CONFIG));
        assertThat(setRuleV2(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + ev2 + "\"]}")
                .getResponse().getStatus()).isEqualTo(400);
        // ev1 được EVIDENCE_SELECT offer → chấp nhận.
        publish(draftEs(ev1));
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + ev1 + "\"]}");
    }

    @Test
    void specificEvidenceSet_acceptsEvidenceCollectedFromOldVersion()
            throws Exception {
        String itemId = newItem("BO_CHUNG_OLD", "COMMEMORATIVE_BADGE");
        // ev3 collect được ở phiên bản cũ (đã có user_evidence row) — dù
        // hiện không còn EVIDENCE_SELECT nào offer → vẫn hợp lệ (giữ
        // entitlement người đã sưu tầm).
        String lesson = publish(draftEs(ev3));
        collect(learnerToken, lesson, ev3);
        // Xoá lesson → ev3 không còn trong published snapshot nào.
        jdbc.update("update lessons set status='ARCHIVED', "
                + "current_version_id=null");
        setRuleV2ExpectOk(itemId,
                "{\"type\":\"SPECIFIC_EVIDENCE_SET\",\"eventId\":\"" + eventId
                        + "\",\"evidenceIds\":[\"" + ev3 + "\"]}");
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

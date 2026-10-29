package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

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
 * GAME-02 — Hệ thống Thể lực end-to-end: GET /me/energy lazy-create 100/100,
 * penalty -10 cho graded INCORRECT (clamp về 0), ungraded/PARTIAL/payload lỗi
 * không trừ, exhausted-completed vẫn trừ một lần, zero-gate 409
 * ENERGY_DEPLETED, retry idempotent không trừ trùng, reward/collection
 * không bị ảnh hưởng. Cần Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class EnergySystemIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String learnerId;
    private String otherToken;
    private String eventId;
    private String tplId;
    private String evId;

    private static final String MC_CONFIG =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"],\"maxAttempts\":3}";

    private static final String MC_WRONG = "{\"selectedOptionIds\":[\"o2\"]}";
    private static final String MC_RIGHT = "{\"selectedOptionIds\":[\"o1\"]}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from energy_transactions");
        jdbc.update("delete from user_energy");
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@eg.vn",
                UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@eg.vn",
                UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@eg.vn",
                UserRole.LEARNER);
        learnerId = userIdByEmail("l@eg.vn");
        eventId = AttemptItFixture.newEvent(jdbc, "e-eg");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-eg");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private String userIdByEmail(String email) {
        return jdbc.queryForObject(
                "select id from users where email = ?", String.class, email);
    }

    private String publish(String draft) throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId,
                tplId, draft);
    }

    private MvcResult submit(String token, String attemptId, String activityId,
                             String answerJson, String idemKey) throws Exception {
        var req = post("/api/v1/attempts/" + attemptId
                        + "/activities/" + activityId + "/submissions")
                .header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"answer\":" + answerJson + "}");
        if (idemKey != null) req = req.header("Idempotency-Key", idemKey);
        return mvc.perform(req).andReturn();
    }

    private JsonNode energy(String token) throws Exception {
        MvcResult res = mvc.perform(get("/api/v1/me/energy")
                        .header("Authorization", token))
                .andExpect(status().isOk()).andReturn();
        return AttemptItFixture.body(om, res);
    }

    private int currentEnergy() {
        // Row chưa tồn tại = learner chưa bao giờ bị trừ/hồi → hiểu là 100
        // (lazy-create chỉ chạy khi user đụng energy API/submit penalty).
        List<Integer> rows = jdbc.query(
                "select current_energy from user_energy where user_id = ?::uuid",
                (rs, i) -> rs.getInt(1), learnerId);
        return rows.isEmpty() ? 100 : rows.get(0);
    }

    private void setEnergy(int value) {
        // Đặt trạng thái trực tiếp cho các kịch bản depletion (test fixture,
        // không phải API).
        jdbc.update("insert into user_energy (user_id, current_energy,"
                        + " last_recovery_at) values (?::uuid, ?, now())"
                        + " on conflict (user_id) do update set"
                        + " current_energy = excluded.current_energy,"
                        + " last_recovery_at = now()",
                learnerId, value);
    }

    private int txCount(String where) {
        Long n = jdbc.queryForObject(
                "select count(*) from energy_transactions where " + where,
                Long.class);
        return n == null ? 0 : n.intValue();
    }

    /* ---------- GET /me/energy ---------- */

    @Test
    void getEnergy_lazyCreates100_andStaysStable() throws Exception {
        JsonNode s = energy(learnerToken);
        assertThat(s.get("current").asInt()).isEqualTo(100);
        assertThat(s.get("max").asInt()).isEqualTo(100);
        assertThat(s.get("recoveryAmount").asInt()).isEqualTo(5);
        assertThat(s.get("recoveryIntervalSeconds").asInt()).isEqualTo(900);
        assertThat(s.get("canSubmitGraded").asBoolean()).isTrue();
        assertThat(s.get("nextRecoveryAt").isNull()).isTrue(); // đầy → null
        assertThat(s.get("serverTime").asText()).isNotBlank();
        // Gọi lại: vẫn 1 row, không reset.
        energy(learnerToken);
        assertThat(jdbc.queryForObject(
                "select count(*) from user_energy where user_id = ?::uuid",
                Long.class, learnerId)).isEqualTo(1);
    }

    @Test
    void getEnergy_requiresAuth() throws Exception {
        mvc.perform(get("/api/v1/me/energy"))
                .andExpect(status().isUnauthorized());
    }

    /* ---------- penalty ---------- */

    @Test
    void incorrectGradedSubmit_deductsTen_once() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        MvcResult res = submit(learnerToken, attemptId, "mc", MC_WRONG, null);
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        assertThat(AttemptItFixture.body(om, res).get("energyDeducted")
                .asInt()).isEqualTo(10);
        assertThat(currentEnergy()).isEqualTo(90);
        // Ledger truy vết về attempt/activity/attemptNo.
        assertThat(txCount("user_id = '" + learnerId
                + "' and direction = 'DEBIT'")).isEqualTo(1);
        JsonNode ref = om.readTree(jdbc.queryForObject(
                "select reference_json::text from energy_transactions "
              + "where user_id = ?::uuid", String.class, learnerId));
        assertThat(ref.get("activityId").asText()).isEqualTo("mc");
        assertThat(ref.get("attemptNo").asInt()).isEqualTo(1);
    }

    @Test
    void correctGradedSubmit_noDeduction() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        submit(learnerToken, attemptId, "mc", MC_RIGHT, null);
        assertThat(currentEnergy()).isEqualTo(100);
        assertThat(txCount("user_id = '" + learnerId + "'")).isZero();
    }

    @Test
    void ungradedSubmit_neverDeducts() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        assertThat(currentEnergy()).isEqualTo(100);
    }

    @Test
    void invalidPayload_neverDeducts() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        // option không khai báo → handler throw → 400, không trừ.
        MvcResult bad = submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"zz\"]}", null);
        assertThat(bad.getResponse().getStatus()).isEqualTo(400);
        assertThat(currentEnergy()).isEqualTo(100);
    }

    @Test
    void exhaustedIncorrect_stillDeductsOnce() throws Exception {
        // MC maxAttempts=1 trong draft này: submit sai một lần → exhausted,
        // completed-for-progress NHƯNG outcome INCORRECT → vẫn trừ 1 lần.
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG.replace("\"maxAttempts\":3", "\"maxAttempts\":1")));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        MvcResult res = submit(learnerToken, attemptId, "mc", MC_WRONG, null);
        JsonNode b = AttemptItFixture.body(om, res);
        assertThat(b.get("activityCompleted").asBoolean()).isTrue(); // exhausted
        assertThat(b.get("evaluation").get("outcome").asText())
                .isEqualTo("INCORRECT");
        assertThat(b.get("energyDeducted").asInt()).isEqualTo(10);
        assertThat(currentEnergy()).isEqualTo(90);
        // knowledgeScore không bị biến thành đúng — lesson hoàn thành với
        // điểm kiến thức 0, không phải 100.
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        JsonNode result = AttemptItFixture.body(om, mvc.perform(get(
                        "/api/v1/attempts/" + attemptId + "/result")
                        .header("Authorization", learnerToken)).andReturn());
        assertThat(result.get("result").get("knowledgeScore").asDouble())
                .isEqualTo(0.0);
    }

    @Test
    void evidenceSelectGraded_incorrectDeducts_ungradedDoesNot() throws Exception {
        // EVIDENCE_SELECT optional (ungraded, minRequired) + MC required.
        String lessonId = publish(AttemptItFixture.draftWithOptional(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        // Optional EVIDENCE_SELECT ungraded — không trừ dù submit "thiếu".
        MvcResult es = submit(learnerToken, attemptId, "es-opt",
                "{\"selectedEvidenceIds\":[]}", null);
        assertThat(es.getResponse().getStatus()).isEqualTo(200);
        assertThat(currentEnergy()).isEqualTo(100);
    }

    /* ---------- FIX 6: toàn bộ handler graded thực sự trừ đúng ---------- */

    /**
     * Draft một stage một activity required — stage type chọn theo type để
     * qua STAGE_ACTIVITY_MISMATCH của publish validation.
     */
    private String draftSingleActivity(String stageType, String actType,
                                       String config) {
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"s1","type":"%s","required":true,
                    "activities":[{"id":"a1","type":"%s","required":true,
                                    "config":%s}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(stageType, actType, config, evId);
    }

    private void submitWrongAndExpect(String stageType, String actType,
                                      String config, String wrongAnswer,
                                      int expectedDeducted) throws Exception {
        String lessonId = publish(draftSingleActivity(stageType, actType, config));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        MvcResult res = submit(learnerToken, attemptId, "a1", wrongAnswer, null);
        JsonNode b = AttemptItFixture.body(om, res);
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        assertThat(b.get("energyDeducted").asInt()).isEqualTo(expectedDeducted);
        if (expectedDeducted > 0) {
            assertThat(currentEnergy()).isEqualTo(100 - expectedDeducted);
        }
    }

    @Test
    void evidenceSelect_gradedIncorrect_deducts() throws Exception {
        // FIX 2 + FIX 6: graded:true + acceptedEvidenceIds hợp lệ → chấm sai
        // → trừ đúng một lần.
        String esConfig = "{\"visibleEvidenceIds\":[\"" + evId + "\"],"
                + "\"graded\":true,"
                + "\"acceptedEvidenceIds\":[\"" + evId + "\"],"
                + "\"maxAttempts\":3}";
        // Chọn rỗng → exact-match fail → INCORRECT (không PARTIAL vì
        // correctHits rỗng).
        submitWrongAndExpect("EVIDENCE", "EVIDENCE_SELECT", esConfig,
                "{\"selectedEvidenceIds\":[]}", 10);
    }

    @Test
    void reasoningConnect_gradedIncorrect_deducts() throws Exception {
        String rcConfig = "{\"nodes\":["
                + "{\"id\":\"n1\"},{\"id\":\"n2\"}],"
                + "\"allowedRelations\":[\"causes\"],"
                + "\"graded\":true,"
                + "\"expectedRelations\":[{\"from\":\"n1\",\"relation\":\"causes\",\"to\":\"n2\"}],"
                + "\"maxAttempts\":3}";
        submitWrongAndExpect("REASONING", "REASONING_CONNECT", rcConfig,
                "{\"relations\":[{\"from\":\"n2\",\"relation\":\"causes\",\"to\":\"n1\"}]}",
                10);
    }

    @Test
    void matching_incorrect_deducts() throws Exception {
        String mtConfig = "{\"pairs\":["
                + "{\"left\":{\"id\":\"l1\"},\"right\":{\"id\":\"r1\"}},"
                + "{\"left\":{\"id\":\"l2\"},\"right\":{\"id\":\"r2\"}}],"
                + "\"correctPairs\":[{\"left\":\"l1\",\"right\":\"r1\"},"
                + "{\"left\":\"l2\",\"right\":\"r2\"}],"
                + "\"maxAttempts\":3}";
        submitWrongAndExpect("REASONING", "MATCHING", mtConfig,
                "{\"pairs\":[{\"leftId\":\"l1\",\"rightId\":\"r2\"},"
                        + "{\"leftId\":\"l2\",\"rightId\":\"r1\"}]}", 10);
    }

    @Test
    void dragOrder_incorrect_deducts() throws Exception {
        String doConfig = "{\"items\":[{\"id\":\"i1\"},{\"id\":\"i2\"},"
                + "{\"id\":\"i3\"}],"
                + "\"expectedOrder\":[\"i1\",\"i2\",\"i3\"],"
                + "\"maxAttempts\":3}";
        submitWrongAndExpect("RECONSTRUCTION", "DRAG_ORDER", doConfig,
                "{\"orderedIds\":[\"i3\",\"i2\",\"i1\"]}", 10);
    }

    @Test
    void cerChoice_incorrect_deducts() throws Exception {
        // acceptedCombos + 3 flat arrays (publish contract đòi song song
        // theo CerChoiceValidator); evidence ids phải thật của event.
        String ev2 = AttemptItFixture.newEvidence(jdbc, eventId);
        String cerConfig = "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
                + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
                + "\"evidenceOptions\":[{\"id\":\"" + evId + "\"},"
                + "{\"id\":\"" + ev2 + "\"}],"
                + "\"acceptedCombos\":[{\"claimId\":\"c1\",\"evidenceIds\":[\"" + evId + "\"],\"reasoningId\":\"r1\"}],"
                + "\"acceptedClaims\":[\"c1\"],"
                + "\"acceptedEvidenceIds\":[\"" + evId + "\"],"
                + "\"acceptedReasoningIds\":[\"r1\"],"
                + "\"maxAttempts\":3}";
        // feedback nằm ở activity.feedback (validator đọc activity, không
        // phải config) — draftSingleActivity chưa hỗ trợ feedback bên ngoài
        // nên build draft riêng tại đây.
        String draft = """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"s1","type":"CONCLUSION","required":true,
                    "activities":[{"id":"a1","type":"CER_CHOICE","required":true,
                                    "config":%s,
                                    "feedback":{"COMPLETED":"ok",
                                                "INCORRECT":"no"}}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(cerConfig, evId);
        String lessonId = publish(draft);
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        MvcResult res = submit(learnerToken, attemptId, "a1",
                "{\"claimId\":\"c2\",\"reasoningId\":\"r2\",\"evidenceIds\":[\"" + ev2 + "\"]}",
                null);
        JsonNode b = AttemptItFixture.body(om, res);
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        assertThat(b.get("energyDeducted").asInt()).isEqualTo(10);
        assertThat(currentEnergy()).isEqualTo(90);
    }

    @Test
    void partialOutcome_neverDeducts() throws Exception {
        // EVIDENCE_SELECT graded với một phần đúng nhưng chưa hết lượt →
        // PARTIAL — không trừ (đúng bảng policy). Cần 2 evidence thật của
        // event để accepted hợp lệ.
        String ev2 = AttemptItFixture.newEvidence(jdbc, eventId);
        String esConfig = "{\"visibleEvidenceIds\":[\"" + evId + "\",\""
                + ev2 + "\"],"
                + "\"graded\":true,"
                + "\"acceptedEvidenceIds\":[\"" + evId + "\",\"" + ev2 + "\"],"
                + "\"maxAttempts\":3}";
        String lessonId = publish(draftSingleActivity("EVIDENCE",
                "EVIDENCE_SELECT", esConfig));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        MvcResult res = submit(learnerToken, attemptId, "a1",
                "{\"selectedEvidenceIds\":[\"" + evId + "\"]}", null);
        JsonNode b = AttemptItFixture.body(om, res);
        assertThat(b.get("evaluation").get("outcome").asText())
                .isEqualTo("PARTIAL");
        assertThat(b.get("energyDeducted").asInt()).isZero();
        assertThat(currentEnergy()).isEqualTo(100);
    }

    @Test
    void ungradedEvidenceSelect_notGatedWhenZero() throws Exception {
        // EVIDENCE_SELECT KHÔNG graded (không flag) → ungraded thật sự;
        // energy=0 vẫn cho submit — baseline của FIX 2 (trường hợp graded
        // flag thiếu key bị publish chặn nên không thể tồn tại trên DB).
        String lessonId = publish(draftSingleActivity("EVIDENCE",
                "EVIDENCE_SELECT",
                "{\"visibleEvidenceIds\":[\"" + evId + "\"],"
                        + "\"minRequired\":1}"));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        setEnergy(0);
        MvcResult res = submit(learnerToken, attemptId, "a1",
                "{\"selectedEvidenceIds\":[\"" + evId + "\"]}", null);
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
    }

    @Test
    void submitResponse_carriesEnergySnapshot() throws Exception {
        // FIX 7: response submit trả kèm trạng thái energy sau tx — client
        // không phải gọi lại /me/energy để biết balance mới.
        String lessonId = publish(draftSingleActivity("EVIDENCE",
                "MULTIPLE_CHOICE", MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        MvcResult res = submit(learnerToken, attemptId, "a1", MC_WRONG, null);
        JsonNode b = AttemptItFixture.body(om, res);
        JsonNode snap = b.get("energy");
        assertThat(snap).isNotNull();
        assertThat(snap.get("current").asInt()).isEqualTo(90);
        assertThat(snap.get("max").asInt()).isEqualTo(100);
    }

    /* ---------- retry & idempotency ---------- */

    @Test
    void sameIdempotencyKey_neverDoubleDeducts() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        submit(learnerToken, attemptId, "mc", MC_WRONG, "k-eg-1");
        MvcResult replay = submit(learnerToken, attemptId, "mc", MC_WRONG,
                "k-eg-1");
        assertThat(replay.getResponse().getStatus()).isEqualTo(200);
        assertThat(currentEnergy()).isEqualTo(90);
        assertThat(txCount("user_id = '" + learnerId
                + "' and direction = 'DEBIT'")).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "select count(*) from activity_attempts "
              + "where learner_attempt_id = ?::uuid and activity_id = 'mc'",
                Long.class, attemptId)).isEqualTo(1);
    }

    @Test
    void newLegitimateSubmit_deductsAgain_withOwnCauseKey() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        submit(learnerToken, attemptId, "mc", MC_WRONG, "k-a");
        submit(learnerToken, attemptId, "mc", MC_WRONG, "k-b");
        assertThat(currentEnergy()).isEqualTo(80);
        assertThat(txCount("user_id = '" + learnerId
                + "' and direction = 'DEBIT'")).isEqualTo(2);
    }

    @Test
    void idempotencyConflict_neverDeducts() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        submit(learnerToken, attemptId, "mc", MC_WRONG, "k-cf");
        MvcResult conflict = submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o1\",\"o2\"]}", "k-cf");
        assertThat(conflict.getResponse().getStatus()).isEqualTo(409);
        assertThat(currentEnergy()).isEqualTo(90);
    }

    /* ---------- depletion ---------- */

    @Test
    void energyFive_wrongSubmit_drainsToZero() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        setEnergy(5);
        MvcResult res = submit(learnerToken, attemptId, "mc", MC_WRONG, null);
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        assertThat(AttemptItFixture.body(om, res).get("energyDeducted")
                .asInt()).isEqualTo(5);
        assertThat(currentEnergy()).isZero();
        JsonNode tx = om.readTree(jdbc.queryForObject(
                "select json_build_object('amount', amount,"
              + " 'balance_after', balance_after,"
              + " 'reference', reference_json)::text "
              + "from energy_transactions where user_id = ?::uuid "
              + "and direction = 'DEBIT'", String.class, learnerId));
        assertThat(tx.get("amount").asInt()).isEqualTo(5);
        assertThat(tx.get("balance_after").asInt()).isZero();
    }

    @Test
    void energyZero_gradedSubmitRejected_ungradedStillWorks() throws Exception {
        String lessonId = publish(AttemptItFixture.draftWithOptional(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        setEnergy(0);
        // Graded submit → 409 ENERGY_DEPLETED + thời gian hồi server tính.
        MvcResult res = submit(learnerToken, attemptId, "mc", MC_WRONG, null);
        assertThat(res.getResponse().getStatus()).isEqualTo(409);
        JsonNode b = AttemptItFixture.body(om, res);
        assertThat(b.get("code").asText()).isEqualTo("ENERGY_DEPLETED");
        assertThat(b.get("details").get("currentEnergy").asInt()).isZero();
        assertThat(b.get("details").get("serverTime").asText()).isNotBlank();
        // Không tạo activity_attempt, không đổi cursor.
        assertThat(jdbc.queryForObject(
                "select count(*) from activity_attempts "
              + "where learner_attempt_id = ?::uuid", Long.class, attemptId))
                .isEqualTo(1); // chỉ r1
        // Ungraded submit vẫn đi qua (es-opt optional trong stage hiện tại).
        MvcResult es = submit(learnerToken, attemptId, "es-opt",
                "{\"selectedEvidenceIds\":[\"" + evId + "\"]}", null);
        assertThat(es.getResponse().getStatus()).isEqualTo(200);
        // GET /me/energy đọc đúng trạng thái sau lỗi.
        assertThat(energy(learnerToken).get("current").asInt()).isZero();
    }

    @Test
    void energyZero_doesNotBlockContentOrComplete() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG.replace("\"maxAttempts\":3", "\"maxAttempts\":1")));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        // Sai một lần (exhausted) → lesson đủ điều kiện complete.
        submit(learnerToken, attemptId, "mc", MC_WRONG, null);
        setEnergy(0);
        mvc.perform(get("/api/v1/attempts/" + attemptId + "/content")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        // Và reward vẫn cấp bình thường — energy không ảnh hưởng ledger thưởng.
        assertThat(jdbc.queryForObject(
                "select count(*) from reward_transactions "
              + "where user_id = ?::uuid", Long.class, learnerId))
                .isEqualTo(2);
    }

    /* ---------- regression: reward/collection không đổi ---------- */

    @Test
    void rewardsAndProgress_unaffectedByPenalty() throws Exception {
        // maxAttempts=2: hai lần sai → exhausted-completed → đủ complete,
        // energy 100 − 10 × 2 = 80, reward vẫn cấp đầy đủ.
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG.replace("\"maxAttempts\":3", "\"maxAttempts\":2")));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        submit(learnerToken, attemptId, "mc", MC_WRONG, null);
        submit(learnerToken, attemptId, "mc", MC_WRONG, null);
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/me/rewards/summary")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exp").value(100))
                .andExpect(jsonPath("$.historyPoints").value(50));
        // 20 bị trừ (2 lần sai) — không ảnh hưởng thưởng.
        assertThat(currentEnergy()).isEqualTo(80);
    }

    /* ---------- concurrency ---------- */

    @Test
    void concurrentFirstAccess_createsSingleEnergyRow() throws Exception {
        int threads = 4;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Integer>> futures = new java.util.ArrayList<>();
        for (int i = 0; i < threads; i++) {
            Callable<Integer> call = () -> {
                go.await(5, TimeUnit.SECONDS);
                return mvc.perform(get("/api/v1/me/energy")
                                .header("Authorization", learnerToken))
                        .andReturn().getResponse().getStatus();
            };
            futures.add(pool.submit(call));
        }
        go.countDown();
        for (Future<Integer> f : futures) {
            assertThat(f.get(60, TimeUnit.SECONDS)).isEqualTo(200);
        }
        pool.shutdown();
        assertThat(jdbc.queryForObject(
                "select count(*) from user_energy where user_id = ?::uuid",
                Long.class, learnerId)).isEqualTo(1);
        assertThat(currentEnergy()).isEqualTo(100);
    }

    @Test
    void concurrentSubmits_noLostUpdate_neverBelowZero() throws Exception {
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        // startOrResume scoped per lesson → hai attempt song song cần 2
        // lesson khác nhau; cả hai tranh chấp MỘT dòng user_energy.
        String a1 = AttemptItFixture.startAttempt(mvc, om, learnerToken,
                lessonId);
        String lessonId2 = publish(AttemptItFixture.draftTwoStage(
                AttemptItFixture.newEvidence(jdbc, eventId), MC_CONFIG));
        String a2 = AttemptItFixture.startAttempt(mvc, om, learnerToken,
                lessonId2);
        String a2Final = a2;
        submit(learnerToken, a1, "r1", "{}", null);
        submit(learnerToken, a2, "r1", "{}", null);
        setEnergy(15);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch go = new CountDownLatch(1);
        String a1Final = a1;
        Future<MvcResult> f1 = pool.submit(() -> {
            go.await(5, TimeUnit.SECONDS);
            return submit(learnerToken, a1Final, "mc", MC_WRONG, "kc-1");
        });
        Future<MvcResult> f2 = pool.submit(() -> {
            go.await(5, TimeUnit.SECONDS);
            return submit(learnerToken, a2Final, "mc", MC_WRONG, "kc-2");
        });
        go.countDown();
        MvcResult r1 = f1.get(60, TimeUnit.SECONDS);
        MvcResult r2 = f2.get(60, TimeUnit.SECONDS);
        pool.shutdown();
        assertThat(r1.getResponse().getStatus()).isEqualTo(200);
        assertThat(r2.getResponse().getStatus()).isEqualTo(200);
        // 15 - 10 - 5 = 0, không âm, 2 bút toán riêng cause_key.
        assertThat(currentEnergy()).isZero();
        assertThat(txCount("user_id = '" + learnerId
                + "' and direction = 'DEBIT'")).isEqualTo(2);
    }

    @Test
    void energy_isolatedPerUser() throws Exception {
        JsonNode other = energy(otherToken);
        assertThat(other.get("current").asInt()).isEqualTo(100);
        String lessonId = publish(AttemptItFixture.draftTwoStage(evId,
                MC_CONFIG));
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}", null);
        submit(learnerToken, attemptId, "mc", MC_WRONG, null);
        assertThat(currentEnergy()).isEqualTo(90);
        assertThat(energy(otherToken).get("current").asInt()).isEqualTo(100);
    }

    /* ---------- GAME-07 (Issue #28): Viện Thái Y ---------- */

    @Test
    void me_energy_includesRemediesAndPointsBalance() throws Exception {
        JsonNode s = energy(learnerToken);
        assertThat(s.get("pointsBalance").asLong()).isGreaterThanOrEqualTo(0);
        assertThat(s.get("remedies").isArray()).isTrue();
        assertThat(s.get("remedies").size()).isEqualTo(4);
        assertThat(s.get("remedies").get(0).get("code").asText())
                .isEqualTo("NUOC_VOI");
    }

    @Test
    void refill_nuocVoi_free_creditsEnergy() throws Exception {
        // Trừ energy xuống 80 trước để NUOC_VOI (+20) có chỗ cộng.
        // setEnergy đảm bảo row tồn tại (lazy-create sẽ =100 → ENERGY_FULL).
        setEnergy(80);
        String key = "nuoc-" + UUID.randomUUID();
        MvcResult r = mvc.perform(post("/api/v1/me/energy/refills")
                        .header("Authorization", learnerToken)
                        .header("Idempotency-Key", key)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"remedyCode\":\"NUOC_VOI\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.remedyCode").value("NUOC_VOI"))
                .andExpect(jsonPath("$.energyCredited").value(20))
                .andExpect(jsonPath("$.pointsSpent").value(0))
                .andExpect(jsonPath("$.energy.current").value(100))
                .andReturn();
        // Idempotent replay — cùng key → cùng response, không credit lại
        JsonNode first = om.readTree(r.getResponse().getContentAsString());
        MvcResult r2 = mvc.perform(post("/api/v1/me/energy/refills")
                        .header("Authorization", learnerToken)
                        .header("Idempotency-Key", key)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"remedyCode\":\"NUOC_VOI\"}"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode second = om.readTree(r2.getResponse().getContentAsString());
        assertThat(second.get("energy").get("current").asInt())
                .isEqualTo(first.get("energy").get("current").asInt());
        // Vẫn chỉ 1 ledger entry REFILL_PURCHASE cho user
        Integer count = jdbc.queryForObject(
                "select count(*) from energy_transactions"
                        + " where user_id = ? and reason = 'REFILL_PURCHASE'",
                Integer.class, UUID.fromString(learnerId));
        assertThat(count).isEqualTo(1);
    }

    @Test
    void refill_traSen_paid_debitsWallet() throws Exception {
        // Trừ energy + nạp Điểm Sử Ký cho learner (qua wallet_transactions).
        // setEnergy đảm bảo row tồn tại (lazy-create sẽ =100 → ENERGY_FULL).
        setEnergy(70);
        jdbc.update("insert into wallet_transactions"
                + " (id, user_id, currency, direction, amount, reason,"
                + " cause_key, balance_after, created_at) values"
                + " (gen_random_uuid(), ?, 'HISTORY_POINTS', 'CREDIT',"
                + " 100, 'ADMIN_GRANT', 'seed-1', 100, now())",
                UUID.fromString(learnerId));
        MvcResult r = mvc.perform(post("/api/v1/me/energy/refills")
                        .header("Authorization", learnerToken)
                        .header("Idempotency-Key", "tra-" + UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"remedyCode\":\"TRA_SEN\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.energyCredited").value(30))
                .andExpect(jsonPath("$.pointsSpent").value(30))
                .andExpect(jsonPath("$.energy.current").value(100))
                .andReturn();
        Integer debit = jdbc.queryForObject(
                "select count(*) from wallet_transactions"
                        + " where user_id = ? and direction = 'DEBIT'"
                        + " and reason = 'REFILL_PURCHASE'",
                Integer.class, UUID.fromString(learnerId));
        assertThat(debit).isEqualTo(1);
    }

    @Test
    void refill_atMax_throwsEnergyFull422() throws Exception {
        // Energy 100 (default) — refill phải bị 422.
        mvc.perform(post("/api/v1/me/energy/refills")
                        .header("Authorization", learnerToken)
                        .header("Idempotency-Key", "full-" + UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"remedyCode\":\"NUOC_VOI\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("REFILL_NOT_ELIGIBLE"));
    }

    @Test
    void refill_missingKey_throws400() throws Exception {
        mvc.perform(post("/api/v1/me/energy/refills")
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"remedyCode\":\"NUOC_VOI\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void refill_unknownRemedy_throws404() throws Exception {
        mvc.perform(post("/api/v1/me/energy/refills")
                        .header("Authorization", learnerToken)
                        .header("Idempotency-Key", "x-" + UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"remedyCode\":\"NGOC_THANH\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("REMEDY_NOT_FOUND"));
    }

    @Test
    void refill_rateLimited_throws409() throws Exception {
        setEnergy(50);
        String key = "rl-" + UUID.randomUUID();
        // Refill 1st → success
        mvc.perform(post("/api/v1/me/energy/refills")
                        .header("Authorization", learnerToken)
                        .header("Idempotency-Key", key)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"remedyCode\":\"NUOC_VOI\"}"))
                .andExpect(status().isOk());
        // Refill lại NUOC_VOI ngay (cooldown 24h) → 409 REFILL_RATE_LIMITED
        mvc.perform(post("/api/v1/me/energy/refills")
                        .header("Authorization", learnerToken)
                        .header("Idempotency-Key", "rl2-" + UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"remedyCode\":\"NUOC_VOI\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REFILL_RATE_LIMITED"));
    }
}

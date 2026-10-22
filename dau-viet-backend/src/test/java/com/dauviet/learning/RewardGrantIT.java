package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
 * TASK-0023 — RewardGrantService: thưởng first-completion ghi đúng một lần
 * (100 EXP + 50 HISTORY_POINTS trong cùng transaction complete), idempotent
 * qua retry/replay/concurrent/backfill, per-learner isolation, endpoint
 * summary/transactions scoped theo JWT. Docker cần.
 */
@SpringBootTest
@AutoConfigureMockMvc
class RewardGrantIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String learnerId;
    private String otherToken;
    private String otherId;
    private String eventId;
    private String tplId;
    private String evId;

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

        adminToken = AttemptItFixture.token(users, jwt, "a@rw.vn",
                UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@rw.vn",
                UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@rw.vn",
                UserRole.LEARNER);
        learnerId = userIdByEmail("l@rw.vn");
        otherId = userIdByEmail("o@rw.vn");
        eventId = AttemptItFixture.newEvent(jdbc, "e-rw");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-rw");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private String userIdByEmail(String email) {
        return jdbc.queryForObject(
                "select id from users where email = ?", String.class, email);
    }

    private String publish() throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId,
                tplId, AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
    }

    private MvcResult submit(String token, String attemptId, String activityId,
                             String answerJson) throws Exception {
        return mvc.perform(post("/api/v1/attempts/" + attemptId
                        + "/activities/" + activityId + "/submissions")
                        .header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":" + answerJson + "}"))
                .andReturn();
    }

    private MvcResult complete(String token, String attemptId, String idemKey)
            throws Exception {
        var req = post("/api/v1/attempts/" + attemptId + "/complete")
                .header("Authorization", token);
        if (idemKey != null) req = req.header("Idempotency-Key", idemKey);
        return mvc.perform(req).andReturn();
    }

    /** Fresh attempt → submit đủ required → complete. Trả attemptId. */
    private String completeLesson(String token, String lessonId)
            throws Exception {
        String attemptId = AttemptItFixture.startAttempt(mvc, om, token,
                lessonId);
        submit(token, attemptId, "r1", "{}");
        submit(token, attemptId, "mc", "{\"selectedOptionIds\":[\"o1\"]}");
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", token))
                .andExpect(status().isOk());
        return attemptId;
    }

    private long rewardCount(String where) {
        Long n = jdbc.queryForObject(
                "select count(*) from reward_transactions where " + where,
                Long.class);
        return n == null ? 0 : n;
    }

    /* ---------- grant ---------- */

    @Test
    void firstCompletion_grantsExpAndHistoryPoints() throws Exception {
        String lessonId = publish();
        String attemptId = completeLesson(learnerToken, lessonId);

        assertThat(rewardCount(
                "user_id = '" + learnerId + "'")).isEqualTo(2);
        // Đúng loại + số tiền + gắn attempt.
        assertThat(jdbc.queryForObject(
                "select amount from reward_transactions where user_id = ?::uuid "
              + "and reward_type = 'EXP'", Long.class, learnerId))
                .isEqualTo(100);
        assertThat(jdbc.queryForObject(
                "select amount from reward_transactions where user_id = ?::uuid "
              + "and reward_type = 'HISTORY_POINTS'", Long.class, learnerId))
                .isEqualTo(50);
        assertThat(jdbc.queryForObject(
                "select learner_attempt_id::text from reward_transactions "
              + "where user_id = ?::uuid limit 1", String.class, learnerId))
                .isEqualTo(attemptId);
    }

    @Test
    void repeatComplete_sameAttempt_noDuplicateRewards() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken,
                lessonId);
        submit(learnerToken, attemptId, "r1", "{}");
        submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}");

        complete(learnerToken, attemptId, null).getResponse();
        complete(learnerToken, attemptId, null).getResponse(); // alreadyCompleted
        // Replay Idempotency-Key → vẫn 1 grant.
        complete(learnerToken, attemptId, "k-rw-1");
        complete(learnerToken, attemptId, "k-rw-1");

        assertThat(rewardCount("user_id = '" + learnerId + "'")).isEqualTo(2);
    }

    @Test
    void secondAttempt_sameLesson_noSecondGrant() throws Exception {
        String lessonId = publish();
        completeLesson(learnerToken, lessonId);
        // Attempt thứ hai của CÙNG lesson — hoàn thành lại không thưởng.
        completeLesson(learnerToken, lessonId);

        assertThat(rewardCount("user_id = '" + learnerId + "'")).isEqualTo(2);
    }

    @Test
    void republish_newVersionAttempt_doesNotDoubleGrant() throws Exception {
        String lessonId = publish();
        completeLesson(learnerToken, lessonId);

        // Publish lại lesson (version mới) — attempt trên version mới vẫn
        // là "đã hoàn thành lesson này", cause_key + check theo lesson_id
        // chặn grant thứ hai.
        MvcResult pub = mvc.perform(post(
                        "/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andReturn();
        assertThat(pub.getResponse().getStatus()).isEqualTo(200);
        completeLesson(learnerToken, lessonId);

        assertThat(rewardCount("user_id = '" + learnerId + "'")).isEqualTo(2);
    }

    @Test
    void rewards_scopedPerLearner() throws Exception {
        String lessonId = publish();
        completeLesson(learnerToken, lessonId);

        // Learner khác: summary/transactions/inventory rỗng.
        mvc.perform(get("/api/v1/me/rewards/summary")
                        .header("Authorization", otherToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exp").value(0))
                .andExpect(jsonPath("$.historyPoints").value(0))
                .andExpect(jsonPath("$.lessonsCompleted").value(0))
                .andExpect(jsonPath("$.itemsOwned").value(0));
        mvc.perform(get("/api/v1/me/rewards/transactions")
                        .header("Authorization", otherToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isEmpty());
        assertThat(rewardCount("user_id = '" + otherId + "'")).isZero();
    }

    @Test
    void summaryAndTransactions_reflectGrant() throws Exception {
        String lessonId = publish();
        completeLesson(learnerToken, lessonId);

        mvc.perform(get("/api/v1/me/rewards/summary")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exp").value(100))
                .andExpect(jsonPath("$.historyPoints").value(50))
                .andExpect(jsonPath("$.lessonsCompleted").value(1));

        MvcResult tx = mvc.perform(get("/api/v1/me/rewards/transactions")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andReturn();
        JsonNode items = AttemptItFixture.body(om, tx).get("content");
        assertThat(items).hasSize(2);
        // Mỗi bút toán trỏ đúng lesson của attempt.
        for (JsonNode t : items) {
            assertThat(t.get("lessonId").asText()).isEqualTo(lessonId);
        }
    }

    @Test
    void resultEnriched_withRewardsOfAttempt() throws Exception {
        String lessonId = publish();
        String attemptId = completeLesson(learnerToken, lessonId);

        MvcResult res = mvc.perform(get(
                        "/api/v1/attempts/" + attemptId + "/result")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rewards.length()").value(2))
                .andReturn();
        JsonNode rewards = AttemptItFixture.body(om, res).get("rewards");
        // Chỉ 2 loại MVP, không lộ loại thưởng nào khác.
        for (JsonNode r : rewards) {
            assertThat(r.get("rewardType").asText())
                    .isIn("EXP", "HISTORY_POINTS");
        }
    }

    /* ---------- backfill ---------- */

    @Test
    void backfill_grantsForPreexistingCompletions() throws Exception {
        String lessonId = publish();
        String attemptId = completeLesson(learnerToken, lessonId);
        // Giả lập attempt cũ chưa có bút toán (tính năng chưa ra mắt):
        // xoá grant vừa tạo, backfill phải khôi phục đúng 2 rows.
        jdbc.update("delete from reward_transactions");
        assertThat(rewardCount("user_id = '" + learnerId + "'")).isZero();

        mvc.perform(post("/api/v1/admin/rewards/backfill")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.attemptsGranted").value(1));

        assertThat(rewardCount("user_id = '" + learnerId + "'")).isEqualTo(2);
        // Backfill gắn đúng attempt gốc.
        assertThat(jdbc.queryForObject(
                "select learner_attempt_id::text from reward_transactions "
              + "limit 1", String.class)).isEqualTo(attemptId);
    }

    @Test
    void backfill_idempotent_skipsNonFirst() throws Exception {
        String lessonId = publish();
        completeLesson(learnerToken, lessonId);
        // Attempt thứ hai đã complete nhưng chưa có bút toán — backfill
        // KHÔNG được grant (không phải lần đầu).
        String second = completeLesson(learnerToken, lessonId);
        jdbc.update("delete from reward_transactions");

        mvc.perform(post("/api/v1/admin/rewards/backfill")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        // Chỉ attempt đầu được bổ sung — vẫn đúng 2 bút toán duy nhất.
        assertThat(rewardCount("user_id = '" + learnerId + "'")).isEqualTo(2);
        assertThat(jdbc.queryForObject(
                "select count(*) from reward_transactions "
              + "where learner_attempt_id = ?::uuid",
                Long.class, UUID.fromString(second))).isZero();

        // Chạy lại lần hai — không tạo thêm.
        mvc.perform(post("/api/v1/admin/rewards/backfill")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.attemptsGranted").value(0));
        assertThat(rewardCount("user_id = '" + learnerId + "'")).isEqualTo(2);
    }

    @Test
    void backfill_requiresAdmin() throws Exception {
        mvc.perform(post("/api/v1/admin/rewards/backfill")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void rewardsEndpoints_requireAuth() throws Exception {
        mvc.perform(get("/api/v1/me/rewards/summary"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/me/rewards/transactions"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/me/inventory"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/me/inventory/catalog"))
                .andExpect(status().isUnauthorized());
    }
}

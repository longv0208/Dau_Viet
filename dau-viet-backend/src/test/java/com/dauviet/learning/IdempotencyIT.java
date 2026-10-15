package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

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
 * Persistent Idempotency-Key handling on idempotency_records (TASK-0012):
 * replay stored response, 409 on payload mismatch, no double activity rows
 * under concurrency, records committed with the operation. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class IdempotencyIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String otherToken;
    private String lessonId;
    private String attemptId;

    private static final String MC_CONFIG =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"]}";

    @BeforeEach
    void setUp() throws Exception {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@i.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@i.vn", UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@i.vn", UserRole.LEARNER);
        String eventId = AttemptItFixture.newEvent(jdbc, "e-idem");
        String tplId = AttemptItFixture.newTemplate(jdbc, "t-idem");
        String evId = AttemptItFixture.newEvidence(jdbc, eventId);
        lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
        attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
    }

    private MvcResult submit(String token, String activityId,
                             String answerJson, String key) throws Exception {
        var req = post("/api/v1/attempts/" + attemptId
                        + "/activities/" + activityId + "/submissions")
                .header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"answer\":" + answerJson + "}");
        if (key != null) req = req.header("Idempotency-Key", key);
        return mvc.perform(req).andReturn();
    }

    @Test
    void sameKey_samePayload_replaysStoredResponse_noDuplicateRow() throws Exception {
        MvcResult first = submit(learnerToken, "r1", "{}", "k-1");
        assertThat(first.getResponse().getStatus()).isEqualTo(200);

        MvcResult replay = submit(learnerToken, "r1", "{}", "k-1");
        assertThat(replay.getResponse().getStatus()).isEqualTo(200);
        // identical response — replayed, not re-evaluated. Compare as JSON:
        // the stored response was serialized once and now round-trips through
        // the response DTO, so field order inside nested objects may differ.
        assertThat(AttemptItFixture.body(om, replay))
                .isEqualTo(AttemptItFixture.body(om, first));

        // exactly one activity_attempts row despite two requests
        assertThat(jdbc.queryForObject(
                "select count(*) from activity_attempts "
              + "where learner_attempt_id = ?::uuid and activity_id = 'r1'",
                Integer.class, attemptId)).isEqualTo(1);
        // one idempotency record persisted
        assertThat(jdbc.queryForObject(
                "select count(*) from idempotency_records where idempotency_key = 'k-1'",
                Integer.class)).isEqualTo(1);
    }

    @Test
    void sameKey_differentPayload_409() throws Exception {
        submit(learnerToken, "r1", "{\"note\":\"a\"}", "k-2")
                .getResponse().getStatus();
        MvcResult res = submit(learnerToken, "r1", "{\"note\":\"b\"}", "k-2");
        assertThat(res.getResponse().getStatus()).isEqualTo(409);
        JsonNode body = AttemptItFixture.body(om, res);
        assertThat(body.get("code").asText()).isEqualTo("IDEMPOTENCY_CONFLICT");
    }

    @Test
    void keyScopedPerOperationAndUser() throws Exception {
        // same key on a different activity = different operation scope? The
        // uniqueness tuple is (user, operation, key) and request_hash covers
        // the activity — same key+op with different activityId fingerprint
        // is a conflict, guiding clients to mint fresh keys per action.
        submit(learnerToken, "r1", "{}", "k-3");
        MvcResult otherActivity = submit(learnerToken, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}", "k-3");
        assertThat(otherActivity.getResponse().getStatus()).isEqualTo(409);

        // a different user can reuse the same key string freely
        String otherAttempt = AttemptItFixture.startAttempt(mvc, om, otherToken, lessonId);
        var req = post("/api/v1/attempts/" + otherAttempt
                        + "/activities/r1/submissions")
                .header("Authorization", otherToken)
                .header("Idempotency-Key", "k-3")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"answer\":{}}");
        mvc.perform(req).andExpect(status().isOk());
    }

    @Test
    void concurrentSameKey_neverDoubleWrites() throws Exception {
        int threads = 3;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger ok = new AtomicInteger();
        AtomicInteger conflict = new AtomicInteger();
        AtomicInteger other = new AtomicInteger();
        List<Future<?>> futures = new java.util.ArrayList<>();
        for (int i = 0; i < threads; i++) {
            Callable<Void> call = () -> {
                ready.countDown();
                go.await(5, TimeUnit.SECONDS);
                MvcResult res = submit(learnerToken, "r1", "{}", "k-conc");
                int sc = res.getResponse().getStatus();
                if (sc == 200) ok.incrementAndGet();
                else if (sc == 409) conflict.incrementAndGet();
                else other.incrementAndGet();
                return null;
            };
            futures.add(pool.submit(call));
        }
        assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
        go.countDown();
        for (Future<?> f : futures) f.get(60, TimeUnit.SECONDS);
        pool.shutdown();

        assertThat(other.get()).as("no 5xx/422").isZero();
        // winners serialize on the row lock; every 200 is the same replayed
        // response, and exactly ONE activity row exists
        assertThat(jdbc.queryForObject(
                "select count(*) from activity_attempts "
              + "where learner_attempt_id = ?::uuid and activity_id = 'r1'",
                Integer.class, attemptId)).isEqualTo(1);
    }

    @Test
    void noKey_stillWorks_butNoRecord() throws Exception {
        MvcResult res = submit(learnerToken, "r1", "{}", null);
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        assertThat(jdbc.queryForObject(
                "select count(*) from idempotency_records", Integer.class))
                .isZero();
    }

    @Test
    void failedSubmit_doesNotStoreResponse_retryAllowed() throws Exception {
        // stale-cursor submit (mc while cursor is r1) -> 409 business error;
        // the key must NOT be burned — retry after advancing must work
        MvcResult bad = submit(learnerToken, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}", "k-5");
        assertThat(bad.getResponse().getStatus()).isEqualTo(409);

        submit(learnerToken, "r1", "{}", null); // advance cursor to mc
        MvcResult retry = submit(learnerToken, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}", "k-5");
        // claim rolled back with the failed tx -> fresh execution allowed
        assertThat(retry.getResponse().getStatus()).isEqualTo(200);
    }
}

package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
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
 * Server-authoritative completion lifecycle (TASK-0012): premature complete
 * refused, exactly-once flip + lesson_results, idempotent repeat,
 * concurrent completes, completed-attempt terminal state, restart after
 * completion. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AttemptCompletionIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String otherToken;
    private String eventId;
    private String tplId;
    private String evId;

    private static final String MC_CONFIG =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"]}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@c12.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@c12.vn", UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@c12.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "e-c12");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-c12");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private String publish() throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
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

    /** Drive a fresh attempt on `lessonId` to a completable state. */
    private String completableAttempt(String lessonId) throws Exception {
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}");
        submit(learnerToken, attemptId, "mc", "{\"selectedOptionIds\":[\"o1\"]}");
        return attemptId;
    }

    @Test
    void complete_beforeRequirements_409_noFlip() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        MvcResult res = complete(learnerToken, attemptId, null);
        assertThat(res.getResponse().getStatus()).isEqualTo(409);
        JsonNode body = AttemptItFixture.body(om, res);
        assertThat(body.get("code").asText()).isEqualTo("ATTEMPT_NOT_COMPLETE");

        // nothing flipped, no result row
        assertThat(jdbc.queryForObject(
                "select status from learner_attempts where id = ?::uuid",
                String.class, attemptId)).isEqualTo("IN_PROGRESS");
        assertThat(jdbc.queryForObject(
                "select count(*) from lesson_results where learner_attempt_id = ?::uuid",
                Integer.class, attemptId)).isZero();
    }

    @Test
    void complete_success_flipsOnce_persistsResult() throws Exception {
        String lessonId = publish();
        String attemptId = completableAttempt(lessonId);

        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.alreadyCompleted").value(false))
                .andExpect(jsonPath("$.completedAt").isNotEmpty())
                .andExpect(jsonPath("$.completion.complete").value(true));

        // persisted exactly once
        Integer rows = jdbc.queryForObject(
                "select count(*) from lesson_results where learner_attempt_id = ?::uuid",
                Integer.class, attemptId);
        assertThat(rows).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "select score from lesson_results where learner_attempt_id = ?::uuid",
                java.math.BigDecimal.class, attemptId))
                .isEqualByComparingTo("100.00");
        assertThat(jdbc.queryForObject(
                "select completed_at is not null from learner_attempts where id = ?::uuid",
                Boolean.class, attemptId)).isTrue();
    }

    @Test
    void complete_repeat_returnsStoredResult_noDuplicate() throws Exception {
        String lessonId = publish();
        String attemptId = completableAttempt(lessonId);

        complete(learnerToken, attemptId, null);
        MvcResult again = complete(learnerToken, attemptId, null);
        assertThat(again.getResponse().getStatus()).isEqualTo(200);
        JsonNode body = AttemptItFixture.body(om, again);
        assertThat(body.get("status").asText()).isEqualTo("COMPLETED");
        assertThat(body.get("alreadyCompleted").asBoolean()).isTrue();

        assertThat(jdbc.queryForObject(
                "select count(*) from lesson_results where learner_attempt_id = ?::uuid",
                Integer.class, attemptId)).isEqualTo(1);
    }

    @Test
    void complete_concurrent_exactlyOneResult() throws Exception {
        String lessonId = publish();
        String attemptId = completableAttempt(lessonId);

        int threads = 3;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger ok = new AtomicInteger();
        AtomicInteger other = new AtomicInteger();
        List<Future<?>> futures = new java.util.ArrayList<>();
        for (int i = 0; i < threads; i++) {
            Callable<Void> call = () -> {
                ready.countDown();
                go.await(5, TimeUnit.SECONDS);
                MvcResult res = complete(learnerToken, attemptId, null);
                if (res.getResponse().getStatus() == 200) ok.incrementAndGet();
                else other.incrementAndGet();
                return null;
            };
            futures.add(pool.submit(call));
        }
        assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
        go.countDown();
        for (Future<?> f : futures) f.get(60, TimeUnit.SECONDS);
        pool.shutdown();

        assertThat(other.get()).as("all completes succeed idempotently").isZero();
        assertThat(ok.get()).isEqualTo(threads);
        assertThat(jdbc.queryForObject(
                "select count(*) from lesson_results where learner_attempt_id = ?::uuid",
                Integer.class, attemptId)).isEqualTo(1);
    }

    @Test
    void completedAttempt_rejectsSubmits_andNewStart() throws Exception {
        String lessonId = publish();
        String attemptId = completableAttempt(lessonId);
        complete(learnerToken, attemptId, null);

        // submit on completed attempt -> 409 ATTEMPT_ALREADY_COMPLETED
        MvcResult res = submit(learnerToken, attemptId, "r1", "{}");
        assertThat(res.getResponse().getStatus()).isEqualTo(409);
        assertThat(AttemptItFixture.body(om, res).get("code").asText())
                .isEqualTo("ATTEMPT_ALREADY_COMPLETED");

        // GETs still readable
        mvc.perform(get("/api/v1/attempts/" + attemptId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));

        // start again -> brand-new attempt on the same published version
        MvcResult restart = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resumed").value(false))
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andReturn();
        String newAttemptId = AttemptItFixture.body(om, restart)
                .get("attemptId").asText();
        assertThat(newAttemptId).isNotEqualTo(attemptId);
    }

    /**
     * Regression for the empty-completion bug: a snapshot published with
     * `completion:{}` must behave like an absent completion — a fresh attempt
     * CANNOT complete right after start. Simulates a legacy snapshot (written
     * before publish rejected empty objects) by inserting the version row
     * directly, bypassing authoring validation.
     */
    @Test
    void emptyCompletionConfig_cannotCompleteRightAfterStart() throws Exception {
        // Seed a lesson whose CURRENT published snapshot carries completion:{}.
        String lessonId = publish(); // valid version first
        String adminId = jdbc.queryForObject(
                "select id::text from users where email = 'a@c12.vn'",
                String.class);
        String snapshot = """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","required":true,
                                    "config":{"text":"intro"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                                    "config":{"question":"q","options":[{"id":"o1"},{"id":"o2"}],
                                              "correctOptionIds":["o1"]}}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":[]}],
                 "completion":{}}
                """.formatted(evId);
        String versionId = java.util.UUID.randomUUID().toString();
        jdbc.update("insert into lesson_versions (id, lesson_id, version_no, "
                  + "schema_version, snapshot_json, published_by) "
                  + "values (?::uuid, ?::uuid, 2, 1, ?::jsonb, ?::uuid)",
                versionId, lessonId, snapshot, adminId);
        jdbc.update("update lessons set current_version_id = ?::uuid where id = ?::uuid",
                versionId, lessonId);

        // Fresh attempt on the {}-completion snapshot — complete must be
        // refused (nothing done), not auto-complete.
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        MvcResult res = complete(learnerToken, attemptId, null);
        assertThat(res.getResponse().getStatus()).isEqualTo(409);
        assertThat(AttemptItFixture.body(om, res).get("code").asText())
                .isEqualTo("ATTEMPT_NOT_COMPLETE");
        assertThat(jdbc.queryForObject(
                "select status from learner_attempts where id = ?::uuid",
                String.class, attemptId)).isEqualTo("IN_PROGRESS");
        assertThat(jdbc.queryForObject(
                "select count(*) from lesson_results where learner_attempt_id = ?::uuid",
                Integer.class, attemptId)).isZero();

        // ...but completing the required work DOES complete — the empty object
        // fell back to DEFAULT_ALL_REQUIRED, not a permanent lock-out.
        submit(learnerToken, attemptId, "r1", "{}");
        submit(learnerToken, attemptId, "mc", "{\"selectedOptionIds\":[\"o1\"]}");
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.completion.reason").value("DEFAULT_ALL_REQUIRED"));
    }

    /**
     * End-to-end optional-stage semantics: a lesson whose final stage is
     * `required:false` (Reflection-style) completes once the required
     * stages' work is done — the optional stage never enters the cursor,
     * never counts in progress, never gates completion. No soft-lock.
     */
    @Test
    void optionalStage_neverGatesCompletionOrCursor() throws Exception {
        String draft = """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","required":true,
                                    "config":{"text":"intro"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                                    "config":{"question":"q","options":[{"id":"o1"},{"id":"o2"}],
                                              "correctOptionIds":["o1"]}}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":["ref"]},
                   {"id":"ref","type":"REFLECTION","required":false,
                    "activities":[{"id":"note","type":"READ",
                                    "config":{"text":"takeaway"}}],
                    "nextStageIds":[]}]}
                """.formatted(evId);
        String lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId, tplId, draft);
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        // progress counts only required-stage required work (r1 + mc)
        mvc.perform(get("/api/v1/attempts/" + attemptId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.progress.totalRequired").value(2));

        submit(learnerToken, attemptId, "r1", "{}");
        // after ctx done, cursor hops to ev — never to the optional ref stage
        submit(learnerToken, attemptId, "mc", "{\"selectedOptionIds\":[\"o1\"]}");

        // all required work done — complete succeeds without touching ref
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.progress.completedRequired").value(2))
                .andExpect(jsonPath("$.progress.totalRequired").value(2));
    }

    @Test
    void result_endpoints_ownerAndTiming() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        // before completion -> 404 RESULT_NOT_FOUND
        mvc.perform(get("/api/v1/attempts/" + attemptId + "/result")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RESULT_NOT_FOUND"));

        // other user -> 403
        mvc.perform(get("/api/v1/attempts/" + attemptId + "/result")
                        .header("Authorization", otherToken))
                .andExpect(status().isForbidden());

        String done = completableAttempt(lessonId);
        complete(learnerToken, done, null);
        mvc.perform(get("/api/v1/attempts/" + done + "/result")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.score").value(100.0))
                .andExpect(jsonPath("$.result.completedRequired").value(2))
                .andExpect(jsonPath("$.completedAt").isNotEmpty());
    }
}

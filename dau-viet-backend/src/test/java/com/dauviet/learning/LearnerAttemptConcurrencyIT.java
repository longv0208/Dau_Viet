package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

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
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Concurrent submits on the same attempt+activity serialize on the
 * pessimistic lock — exactly one attempt_no=1 row; the loser either becomes
 * attempt_no=2 or gets a structured 409, never a 5xx or duplicate insert.
 * Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class LearnerAttemptConcurrencyIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String eventId;
    private String tplId;
    private String evId;
    private String lessonId;
    private String attemptId;

    @BeforeEach
    void setUp() throws Exception {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@c.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@c.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "e-conc");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-conc");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
        lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftTwoStage(evId,
                        "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
                      + "\"correctOptionIds\":[\"o1\"]}"));
        attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
    }

    /**
     * Concurrent POST /lessons/{id}/attempts on the same lesson: the partial
     * unique index admits exactly one row; every caller gets 200 and the SAME
     * attemptId (loser resumes the winner's committed row — never a 500).
     */
    @Test
    void concurrentStart_singleAttempt_allResumeSameRow() throws Exception {
        // a second published lesson nobody has started yet — the concurrent
        // starts below race on its partial-unique index, not the resume path
        String freshLesson = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId, tplId,
                AttemptItFixture.draftTwoStage(evId,
                        "{\"question\":\"q2\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
                      + "\"correctOptionIds\":[\"o1\"]}"));

        int threads = 3;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<MvcResult>> futures = new java.util.ArrayList<>();
        for (int i = 0; i < threads; i++) {
            futures.add(pool.submit(() -> {
                ready.countDown();
                go.await(5, TimeUnit.SECONDS);
                return mvc.perform(post("/api/v1/lessons/" + freshLesson + "/attempts")
                                .header("Authorization", learnerToken))
                        .andReturn();
            }));
        }
        assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
        go.countDown();

        java.util.Set<String> ids = new java.util.HashSet<>();
        for (Future<MvcResult> f : futures) {
            MvcResult res = f.get(60, TimeUnit.SECONDS);
            assertThat(res.getResponse().getStatus())
                    .as("every start returns 200 — loser resumes, never 500")
                    .isEqualTo(200);
            ids.add(AttemptItFixture.body(om, res).get("attemptId").asText());
        }
        pool.shutdown();

        assertThat(ids).as("all callers converge on ONE attempt row").hasSize(1);
        assertThat(jdbc.queryForObject(
                "select count(*) from learner_attempts a "
              + "join lesson_versions v on a.lesson_version_id = v.id "
              + "join lessons l on v.lesson_id = l.id where l.id = ?::uuid",
                Integer.class, freshLesson)).isEqualTo(1);
    }

    @Test
    void concurrentSubmits_serialize_noDuplicateOrCrash() throws Exception {
        int threads = 2;
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
                MvcResult res = mvc.perform(post("/api/v1/attempts/" + attemptId
                                + "/activities/r1/submissions")
                                .header("Authorization", learnerToken)
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"answer\":{}}"))
                        .andReturn();
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

        // No 5xx / 422 ever; the race resolves into either serialized 200s
        // or a structured 409 ACTIVITY_NOT_AVAILABLE on the loser.
        assertThat(other.get()).as("no unexpected statuses").isZero();
        assertThat(ok.get() + conflict.get()).isEqualTo(threads);

        // activity_attempts rows are dense per (attempt, activity):
        // one row per accepted submit, attempt_no monotonic 1..N
        List<Integer> nos = jdbc.queryForList(
                "select attempt_no from activity_attempts "
              + "where learner_attempt_id = ?::uuid and activity_id = 'r1' "
              + "order by attempt_no",
                Integer.class, attemptId);
        assertThat(nos).hasSize(ok.get());
        for (int i = 0; i < nos.size(); i++) {
            assertThat(nos.get(i)).isEqualTo(i + 1);
        }
    }
}

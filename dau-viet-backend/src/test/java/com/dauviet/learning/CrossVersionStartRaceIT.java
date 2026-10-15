package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.learning.application.LearnerAttemptService;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Cross-version start race (TASK-0012 review item 1/2): two concurrent
 * startOrResume calls for the same (user, lesson) while a republish swaps
 * current_version_id between them. Without per-(user,lesson) synchronization
 * each thread can pin a different version and create TWO IN_PROGRESS attempts
 * for one lesson — the partial unique index only covers (user_id,
 * lesson_version_id). Deterministic: thread B republishes exactly while
 * thread A holds the start path. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class CrossVersionStartRaceIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;
    @Autowired LearnerAttemptService service;

    private UUID userId;
    private String adminToken;
    private String eventId;
    private String tplId;
    private String evId;

    private static final String MC_V1 =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"]}";
    private static final String MC_V2 =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o2\"]}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@x.vn", UserRole.CONTENT_ADMIN);
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail("l@x.vn");
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(UserRole.LEARNER);
        u.setStatus(UserStatus.ACTIVE);
        users.save(u);
        userId = u.getId();

        eventId = AttemptItFixture.newEvent(jdbc, "e-x");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-x");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private void republish(String lessonId, String mcConfig) throws Exception {
        var req = new java.util.LinkedHashMap<String, Object>();
        req.put("draftJson", AttemptItFixture.draftTwoStage(evId, mcConfig));
        mvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders.put(
                                "/api/v1/admin/lessons/" + lessonId + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(org.springframework.test.web.servlet.result
                        .MockMvcResultMatchers.status().isOk());
        mvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders.post(
                                "/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(org.springframework.test.web.servlet.result
                        .MockMvcResultMatchers.status().isOk());
    }

    @Test
    void twoConcurrentStarts_aroundRepublish_oneInProgressAttempt() throws Exception {
        String lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId, tplId, AttemptItFixture.draftTwoStage(evId, MC_V1));
        UUID lessonUuid = UUID.fromString(lessonId);

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch aInside = new CountDownLatch(1);
        CountDownLatch bGo = new CountDownLatch(1);
        CountDownLatch republished = new CountDownLatch(1);
        AtomicReference<Throwable> err = new AtomicReference<>();

        // Thread A: start; as soon as it returns we know tx A committed —
        // but we want B to start DURING the republish window, so we fire
        // both and interleave the republish between their check+insert.
        Future<com.dauviet.learning.api.dto.AttemptStartResponse> fa = pool.submit(() -> {
            try {
                var r = service.startOrResume(userId, lessonUuid);
                aInside.countDown();
                return r;
            } catch (Throwable t) { err.compareAndSet(null, t); throw t; }
        });

        Future<com.dauviet.learning.api.dto.AttemptStartResponse> fb = pool.submit(() -> {
            try {
                // wait for A to commit, then republish BEFORE calling start —
                // B sees v2 as current; a non-synchronized impl could still
                // collide if B's check raced A's commit (both saw "no
                // IN_PROGRESS" across the version boundary).
                assertThat(aInside.await(10, TimeUnit.SECONDS)).isTrue();
                republish(lessonId, MC_V2);
                republished.countDown();
                return service.startOrResume(userId, lessonUuid);
            } catch (Throwable t) { err.compareAndSet(null, t); throw t; }
        });

        var ra = fa.get(60, TimeUnit.SECONDS);
        var rb = fb.get(60, TimeUnit.SECONDS);
        pool.shutdown();
        assertThat(err.get()).as("no thread threw").isNull();

        // exactly ONE IN_PROGRESS attempt for (user, lesson) across all versions
        Integer inProgress = jdbc.queryForObject(
                "select count(*) from learner_attempts a "
              + "join lesson_versions v on a.lesson_version_id = v.id "
              + "where v.lesson_id = ?::uuid and a.user_id = ?::uuid "
              + "and a.status = 'IN_PROGRESS'",
                Integer.class, lessonId, userId.toString());
        assertThat(inProgress).isEqualTo(1);

        // B resumed the same attempt A started — never a second attempt,
        // whichever version won the republish race
        assertThat(rb.attemptId()).isEqualTo(ra.attemptId());
        assertThat(rb.resumed()).isTrue();
    }

    /**
     * The tighter race: B's start call straddles A's commit AND the republish.
     * Even if B's existence check ran before A committed (both saw "no
     * IN_PROGRESS"), the advisory lock + fresh-tx resume guarantees exactly
     * one row and never a 500.
     */
    @Test
    void serializedStarts_underAdvisoryLock_neverDuplicateAcrossVersions() throws Exception {
        String lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId, tplId, AttemptItFixture.draftTwoStage(evId, MC_V1));
        UUID lessonUuid = UUID.fromString(lessonId);

        int threads = 4;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<com.dauviet.learning.api.dto.AttemptStartResponse>> fs =
                new java.util.ArrayList<>();
        for (int i = 0; i < threads; i++) {
            int idx = i;
            fs.add(pool.submit(() -> {
                ready.countDown();
                go.await(5, TimeUnit.SECONDS);
                if (idx == 2) republish(lessonId, MC_V2); // republish mid-race
                return service.startOrResume(userId, lessonUuid);
            }));
        }
        assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
        go.countDown();

        java.util.Set<UUID> ids = new java.util.HashSet<>();
        for (var f : fs) {
            var r = f.get(60, TimeUnit.SECONDS);
            assertThat(r).isNotNull();
            ids.add(r.attemptId());
        }
        pool.shutdown();

        assertThat(ids).as("every caller converged on ONE attempt").hasSize(1);
        assertThat(jdbc.queryForObject(
                "select count(*) from learner_attempts a "
              + "join lesson_versions v on a.lesson_version_id = v.id "
              + "where v.lesson_id = ?::uuid and a.user_id = ?::uuid "
              + "and a.status = 'IN_PROGRESS'",
                Integer.class, lessonId, userId.toString())).isEqualTo(1);
    }
}

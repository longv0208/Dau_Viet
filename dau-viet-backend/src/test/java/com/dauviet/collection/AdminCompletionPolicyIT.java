package com.dauviet.collection;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.UUID;
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
import com.dauviet.learning.AttemptItFixture;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * GAME-06 Module A — admin completion-policy CRUD/validate/publish ITs.
 * Requires Docker (Testcontainers Postgres).
 */
@SpringBootTest
@AutoConfigureMockMvc
class AdminCompletionPolicyIT extends AbstractPostgresIT {

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

        adminToken = AttemptItFixture.token(users, jwt, "a@g6.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@g6.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "e-g6");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-g6");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private String publishLesson() throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId,
                tplId, AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
    }

    private String policyUrl(String suffix) {
        return "/api/v1/admin/events/" + eventId + "/completion-policies" + suffix;
    }

    private MvcResult createPolicy(String body) throws Exception {
        return mvc.perform(post(policyUrl(""))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andReturn();
    }

    private String createPolicyId(String requiredLessonJson) throws Exception {
        MvcResult res = createPolicy("{\"requiredLessonIds\":"
                + requiredLessonJson + ",\"optionalLessonIds\":[],"
                + "\"masteryThreshold\":70}");
        assertThat(res.getResponse().getStatus()).as("create: %s",
                res.getResponse().getContentAsString()).isEqualTo(201);
        return om.readTree(res.getResponse().getContentAsString())
                .get("id").asText();
    }

    /* ---------- list/create ---------- */

    @Test
    void list_returnsAllVersions() throws Exception {
        String lessonId = publishLesson();
        String p1 = createPolicyId("[\"" + lessonId + "\"]");
        mvc.perform(post(policyUrl("/" + p1 + "/publish"))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        // Draft v2 sau publish.
        createPolicyId("[\"" + lessonId + "\"]");

        mvc.perform(get(policyUrl("")).header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                // Moi nhat truoc (desc policyVersion).
                .andExpect(jsonPath("$[0].policyVersion").value(2))
                .andExpect(jsonPath("$[0].status").value("DRAFT"))
                .andExpect(jsonPath("$[1].status").value("PUBLISHED"));
    }

    @Test
    void create_firstDraft_v1() throws Exception {
        MvcResult res = createPolicy(
                "{\"requiredLessonIds\":[],\"optionalLessonIds\":[]}");
        assertThat(res.getResponse().getStatus()).isEqualTo(201);
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        assertThat(body.get("policyVersion").asInt()).isEqualTo(1);
        assertThat(body.get("status").asText()).isEqualTo("DRAFT");
    }

    @Test
    void create_secondDraft_rejected() throws Exception {
        createPolicy("{\"requiredLessonIds\":[]}");
        mvc.perform(post(policyUrl(""))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requiredLessonIds\":[]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    /* ---------- update ---------- */

    @Test
    void updateDraft_inPlace_keepsPolicyId() throws Exception {
        String lessonId = publishLesson();
        String policyId = createPolicyId("[]");

        mvc.perform(put(policyUrl("/" + policyId))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requiredLessonIds\":[\"" + lessonId
                                + "\"],\"optionalLessonIds\":[],"
                                + "\"masteryThreshold\":80}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(policyId))
                .andExpect(jsonPath("$.masteryThreshold").value(80))
                .andExpect(jsonPath("$.requiredLessonIds[0]").value(lessonId));
    }

    @Test
    void updatePublished_rejects() throws Exception {
        String lessonId = publishLesson();
        String policyId = createPolicyId("[\"" + lessonId + "\"]");
        mvc.perform(post(policyUrl("/" + policyId + "/publish"))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());

        mvc.perform(put(policyUrl("/" + policyId))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requiredLessonIds\":[\"" + lessonId + "\"]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    /* ---------- validate ---------- */

    @Test
    void validate_draftLesson_returnsErrors() throws Exception {
        // Lesson DRAFT (chua publish) -> LESSON_NOT_PUBLISHED.
        String draftLessonId = UUID.randomUUID().toString();
        jdbc.update("insert into lessons (id, event_id, template_id, title,"
                        + " central_question, status) "
                        + "values (?::uuid, ?::uuid, ?::uuid, 'L','Q','DRAFT')",
                draftLessonId, eventId, tplId);
        String policyId = createPolicyId("[]");

        mvc.perform(post(policyUrl("/" + policyId + "/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requiredLessonIds\":[\"" + draftLessonId
                                + "\"]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.errors[0].code")
                        .value("LESSON_NOT_PUBLISHED"));
    }

    @Test
    void validate_overlapAndDuplicate_detected() throws Exception {
        String lessonId = publishLesson();
        String policyId = createPolicyId("[]");

        mvc.perform(post(policyUrl("/" + policyId + "/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requiredLessonIds\":[\"" + lessonId
                                + "\",\"" + lessonId + "\"],"
                                + "\"optionalLessonIds\":[\"" + lessonId + "\"]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false));
        JsonNode body = om.readTree(
                mvc.perform(post(policyUrl("/" + policyId + "/validate"))
                                .header("Authorization", adminToken)
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"requiredLessonIds\":[\"" + lessonId
                                        + "\",\"" + lessonId + "\"],"
                                        + "\"optionalLessonIds\":[\""
                                        + lessonId + "\"]}"))
                        .andReturn().getResponse().getContentAsString());
        List<String> codes = new java.util.ArrayList<>();
        body.get("errors").forEach(e -> codes.add(e.get("code").asText()));
        assertThat(codes).contains("LESSON_DUPLICATE", "LESSON_OVERLAP");
    }

    @Test
    void validate_lessonFromOtherEvent_rejected() throws Exception {
        String otherEvent = AttemptItFixture.newEvent(jdbc, "e-g6-b");
        String ev2 = AttemptItFixture.newEvidence(jdbc, otherEvent);
        String foreignLesson = AttemptItFixture.publishLesson(mvc, om,
                adminToken, otherEvent, tplId,
                AttemptItFixture.draftTwoStage(ev2, MC_CONFIG));
        String policyId = createPolicyId("[]");

        mvc.perform(post(policyUrl("/" + policyId + "/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requiredLessonIds\":[\"" + foreignLesson
                                + "\"]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.errors[0].code")
                        .value("LESSON_WRONG_EVENT"));
    }

    /* ---------- publish ---------- */

    @Test
    void publish_archivesOldPublishesNew_atomic() throws Exception {
        String lessonId = publishLesson();
        String p1 = createPolicyId("[\"" + lessonId + "\"]");
        mvc.perform(post(policyUrl("/" + p1 + "/publish"))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PUBLISHED"));

        String p2 = createPolicyId("[\"" + lessonId + "\"]");
        mvc.perform(post(policyUrl("/" + p2 + "/publish"))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PUBLISHED"))
                .andExpect(jsonPath("$.policyVersion").value(2));

        // Chi 1 PUBLISHED; p1 -> ARCHIVED.
        Long publishedCount = jdbc.queryForObject(
                "select count(*) from event_completion_policies "
              + "where event_id = ?::uuid and status = 'PUBLISHED'",
                Long.class, eventId);
        assertThat(publishedCount).isEqualTo(1);
        String s1 = jdbc.queryForObject(
                "select status from event_completion_policies where id = ?::uuid",
                String.class, p1);
        assertThat(s1).isEqualTo("ARCHIVED");
    }

    @Test
    void publish_staleExpectedVersion_409() throws Exception {
        String lessonId = publishLesson();
        String p1 = createPolicyId("[\"" + lessonId + "\"]");
        mvc.perform(post(policyUrl("/" + p1 + "/publish"))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        String p2 = createPolicyId("[\"" + lessonId + "\"]");

        mvc.perform(post(policyUrl("/" + p2 + "/publish"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"expectedPolicyVersion\":1}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("OPTIMISTIC_LOCK_CONFLICT"));
    }

    @Test
    void publish_invalid_returns422() throws Exception {
        String policyId = createPolicyId("[]"); // required rong

        mvc.perform(post(policyUrl("/" + policyId + "/publish"))
                        .header("Authorization", adminToken))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.errors").isArray());
    }

    @Test
    void publish_concurrent_oneWins() throws Exception {
        String lessonId = publishLesson();
        String p1 = createPolicyId("[\"" + lessonId + "\"]");
        mvc.perform(post(policyUrl("/" + p1 + "/publish"))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        String p2 = createPolicyId("[\"" + lessonId + "\"]");

        // 2 thread publish cung p2 — pessimistic lock tren event row
        // serialize; ket qua cuoi: dung 1 PUBLISHED, khong loi 500.
        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger ok = new AtomicInteger();
        AtomicInteger conflict = new AtomicInteger();
        List<Future<?>> futures = new java.util.ArrayList<>();
        for (int i = 0; i < 2; i++) {
            futures.add(pool.submit(() -> {
                ready.countDown();
                go.await(5, TimeUnit.SECONDS);
                MvcResult r = mvc.perform(
                        post(policyUrl("/" + p2 + "/publish"))
                                .header("Authorization", adminToken))
                        .andReturn();
                int sc = r.getResponse().getStatus();
                if (sc == 200) ok.incrementAndGet();
                if (sc == 400 || sc == 409 || sc == 422) {
                    conflict.incrementAndGet();
                }
                return null;
            }));
        }
        assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
        go.countDown();
        for (Future<?> f : futures) {
            f.get(60, TimeUnit.SECONDS);
        }
        pool.shutdown();

        assertThat(ok.get() + conflict.get()).isEqualTo(2);
        // Dung mot published cuoi cung.
        Long count = jdbc.queryForObject(
                "select count(*) from event_completion_policies "
              + "where event_id = ?::uuid and status = 'PUBLISHED'",
                Long.class, eventId);
        assertThat(count).isEqualTo(1);
    }

    @Test
    void publish_draftOfAnotherEvent_404() throws Exception {
        String lessonId = publishLesson();
        String policyId = createPolicyId("[\"" + lessonId + "\"]");
        String otherEvent = AttemptItFixture.newEvent(jdbc, "e-g6-c");

        mvc.perform(post("/api/v1/admin/events/" + otherEvent
                        + "/completion-policies/" + policyId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound());
    }

    /* ---------- security ---------- */

    @Test
    void unauthenticated_401_learner_403() throws Exception {
        mvc.perform(get(policyUrl("")))
                .andExpect(status().isUnauthorized());
        mvc.perform(get(policyUrl(""))
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }
}

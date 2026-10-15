package com.dauviet.lesson;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
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
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** POST /admin/lessons/{id}/publish — immutable versioning on real Postgres. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class AdminLessonPublishIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String eventId;
    private String tplId;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        User admin = new User();
        admin.setId(UUID.randomUUID());
        admin.setEmail("pub@t.vn");
        admin.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        admin.setRole(UserRole.CONTENT_ADMIN);
        admin.setStatus(UserStatus.ACTIVE);
        users.save(admin);
        adminToken = "Bearer " + jwt.createAccessToken(admin);

        eventId = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, 'e1', 'E', 's', 'DRAFT')", eventId);
        tplId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 't', 'T', 1, '{}'::jsonb, true)", tplId);
    }

    /* ---------- fixtures ---------- */

    private String createLesson(String draftJson) throws Exception {
        var req = new java.util.LinkedHashMap<String, Object>();
        req.put("eventId", eventId);
        req.put("templateId", tplId);
        req.put("title", "L");
        req.put("centralQuestion", "Q?");
        req.put("draftJson", draftJson);
        MvcResult res = mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        return om.readTree(res.getResponse().getContentAsString()).get("id").asText();
    }

    private String approvedEvidence() {
        String evId = UUID.randomUUID().toString();
        jdbc.update("insert into evidences (id, event_id, title, evidence_type, source_title, status) "
                  + "values (?::uuid, ?::uuid, 'EV', 'DOC', 'src', 'APPROVED')", evId, eventId);
        return evId;
    }

    /** PUBLISH-valid draft: CONTEXT -> EVIDENCE(terminal), one required interactive activity. */
    private String publishableDraft(String evId, String mcConfig) {
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","config":{"text":"hi"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                   "config":{"visibleEvidenceIds":["%s"]},
                                   "evidenceRefs":["%s"]},
                                  {"id":"mc","type":"MULTIPLE_CHOICE",
                                   "config":%s,
                                   "validation":{"kind":"SCORE","pass":80}}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(evId, evId, mcConfig, evId);
    }

    private String publishableDraft(String evId) {
        return publishableDraft(evId,
                "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
              + "\"correctOptionIds\":[\"o1\"]}");
    }

    private MvcResult publish(String lessonId) throws Exception {
        return mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andReturn();
    }

    /* ---------- tests ---------- */

    @Test
    void publish_happyPath_createsImmutableVersion() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));

        mvc.perform(post("/api/v1/admin/lessons/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lessonId").value(id))
                .andExpect(jsonPath("$.versionNo").value(1))
                .andExpect(jsonPath("$.status").value("PUBLISHED"))
                .andExpect(jsonPath("$.lessonVersionId").isString())
                .andExpect(jsonPath("$.publishedAt").isString());

        // lesson row points at the new version
        Map<String, Object> row = jdbc.queryForMap(
                "select status, current_version_id::text as cv from lessons where id = ?::uuid", id);
        assertThat(row.get("status")).isEqualTo("PUBLISHED");
        assertThat(row.get("cv")).isNotNull();

        // snapshot contract: lesson fields + verbatim stages + embedded evidence
        String snapshot = jdbc.queryForObject(
                "select snapshot_json::text from lesson_versions where lesson_id = ?::uuid",
                String.class, id);
        JsonNode snap = om.readTree(snapshot);
        assertThat(snap.get("schemaVersion").asInt()).isEqualTo(1);
        assertThat(snap.get("lessonId").asText()).isEqualTo(id);
        assertThat(snap.get("title").asText()).isEqualTo("L");
        assertThat(snap.get("centralQuestion").asText()).isEqualTo("Q?");
        assertThat(snap.get("templateCode").asText()).isEqualTo("t");
        assertThat(snap.get("stages").size()).isEqualTo(2);
        assertThat(snap.at("/evidence/0/id").asText()).isEqualTo(evId);
        assertThat(snap.at("/evidence/0/title").asText()).isEqualTo("EV");
        assertThat(snap.at("/evidence/0/source/title").asText()).isEqualTo("src");
        // server-only keys stay IN the snapshot (stripped at learner read)
        assertThat(snap.at("/stages/1/activities/1/config/correctOptionIds").isArray()).isTrue();
        assertThat(snap.at("/stages/1/activities/1/validation").isObject()).isTrue();
        assertThat(snap.at("/stages/1/requiredEvidenceIds").isArray()).isTrue();
    }

    @Test
    void publish_invalidDraft_422_withErrors() throws Exception {
        String id = createLesson("{}");
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("DRAFT_SCHEMA_INVALID"))
                .andExpect(jsonPath("$.details.errors").isArray())
                .andExpect(jsonPath("$.details.errors[0].code").isString());
        assertThat(jdbc.queryForObject(
                "select count(*) from lesson_versions where lesson_id = ?::uuid",
                Integer.class, id)).isZero();
    }

    @Test
    void publish_republish_incrementsVersionNo_priorVersionIntact() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));
        publish(id);

        // second publish on PUBLISHED lesson -> version 2
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.versionNo").value(2));

        Integer count = jdbc.queryForObject(
                "select count(*) from lesson_versions where lesson_id = ?::uuid",
                Integer.class, id);
        assertThat(count).isEqualTo(2);
        // current_version_id points at version_no = 2, v1 row untouched
        Integer currentNo = jdbc.queryForObject(
                "select v.version_no from lessons l join lesson_versions v "
              + "on v.id = l.current_version_id where l.id = ?::uuid",
                Integer.class, id);
        assertThat(currentNo).isEqualTo(2);
    }

    @Test
    void publish_concurrent_singleWinner_noVersionNoCollision() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));

        int threads = 3;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger ok = new AtomicInteger();
        AtomicInteger conflict = new AtomicInteger();
        AtomicInteger other = new AtomicInteger();
        List<Future<?>> futures = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            Callable<Void> call = () -> {
                ready.countDown();
                go.await(5, TimeUnit.SECONDS);
                MvcResult res = publish(id);
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

        // Pessimistic lock serializes; all may succeed sequentially (v1,v2,v3)
        // or some may hit the optimistic rowVersion conflict — never a 500 or
        // a version_no UNIQUE violation.
        assertThat(other.get()).as("no 5xx/422 under contention").isZero();
        Integer count = jdbc.queryForObject(
                "select count(*) from lesson_versions where lesson_id = ?::uuid",
                Integer.class, id);
        assertThat(count).isEqualTo(ok.get());
        // version_nos are dense and unique: 1..N
        List<Integer> nos = jdbc.queryForList(
                "select version_no from lesson_versions where lesson_id = ?::uuid order by version_no",
                Integer.class, id);
        for (int i = 0; i < nos.size(); i++) {
            assertThat(nos.get(i)).isEqualTo(i + 1);
        }
    }

    @Test
    void publish_archived_409() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));
        publish(id);
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS_TRANSITION"));
    }

    @Test
    void publish_staleExpectedRowVersion_409() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/publish")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"expectedRowVersion\":99}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("OPTIMISTIC_LOCK_CONFLICT"));
    }

    @Test
    void lessonVersions_immutableTrigger_blocksUpdateAndDelete() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));
        publish(id);
        String versionId = jdbc.queryForObject(
                "select id::text from lesson_versions where lesson_id = ?::uuid",
                String.class, id);

        org.junit.jupiter.api.Assertions.assertThrows(Exception.class, () ->
                jdbc.update("update lesson_versions set version_no = 99 where id = ?::uuid", versionId));
        org.junit.jupiter.api.Assertions.assertThrows(Exception.class, () ->
                jdbc.update("delete from lesson_versions where id = ?::uuid", versionId));
        // row intact
        assertThat(jdbc.queryForObject(
                "select count(*) from lesson_versions where id = ?::uuid",
                Integer.class, versionId)).isEqualTo(1);
    }

    @Test
    void evidenceArchive_blockedWhenEmbeddedInPublishedSnapshot() throws Exception {
        // Regression: EVIDENCE_IN_USE LIKE-scan must see ids inside snapshot_json.
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));
        publish(id);

        mvc.perform(post("/api/v1/admin/evidences/" + evId + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVIDENCE_IN_USE"));
    }

    @Test
    void publish_anon401_learner403() throws Exception {
        User learner = new User();
        learner.setId(UUID.randomUUID());
        learner.setEmail("pub-learn@t.vn");
        learner.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        learner.setRole(UserRole.LEARNER);
        learner.setStatus(UserStatus.ACTIVE);
        users.save(learner);
        String learnerToken = "Bearer " + jwt.createAccessToken(learner);

        String id = createLesson("{}");
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/publish"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/publish")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void publish_missingLesson_404() throws Exception {
        mvc.perform(post("/api/v1/admin/lessons/" + UUID.randomUUID() + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("LESSON_NOT_FOUND"));
    }
}

package com.dauviet.collection;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import com.dauviet.learning.AttemptItFixture;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * GAME-04 — Event completion + dossier unlock end-to-end. Requires Docker.
 *
 * Bao phủ: policy PUBLISHED → complete lesson → EVENT_COMPLETED + dossier
 * fan-out trong cùng tx; mastered khi best-score ≥ threshold; NOT_ASSESSED;
 * reconcile-on-read; concurrent last-two-lessons race; 404/ownership;
 * preview/locked visibility; route `/collection/dossiers` không đụng
 * `/{evidenceId}`.
 */
@SpringBootTest
@AutoConfigureMockMvc
class EventCompletionIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String otherToken;
    private String learnerId;
    private String otherId;
    private String eventId;
    private String tplId;
    private String evId;

    private static final String MC_CONFIG =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"]}";

    private static final String DOSSIER_SOURCE =
            "{\"source\":{\"title\":\"Đại Việt sử ký toàn thư\","
          + "\"author\":\"Ngô Sĩ Liên\",\"citation\":\"Ngoại kỷ, quyển 5\","
          + "\"reliability\":\"HIGH\"}}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@g4.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@g4.vn", UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@g4.vn", UserRole.LEARNER);
        learnerId = userIdByEmail("l@g4.vn");
        otherId = userIdByEmail("o@g4.vn");
        eventId = AttemptItFixture.newEvent(jdbc, "e-g4");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-g4");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    /* ---------- helpers ---------- */

    private String userIdByEmail(String email) {
        return jdbc.queryForObject(
                "select id from users where email = ?", String.class, email);
    }

    private String newDossier(String code, String type, String title,
                              String status) {
        String id = UUID.randomUUID().toString();
        jdbc.update("""
                insert into historical_dossiers
                    (id, canonical_code, dossier_type, title, summary,
                     description, source_json, status, dossier_version)
                values (?::uuid, ?, ?, ?, 'Tóm tắt ' || ?, 'Mô tả đầy đủ ' || ?,
                        ?::jsonb, ?, 1)
                """, id, code, type, title, title, title, DOSSIER_SOURCE, status);
        return id;
    }

    private void linkDossier(String dossierId, int sortOrder) {
        jdbc.update("""
                insert into event_dossiers (event_id, dossier_id, unlock_on, sort_order)
                values (?::uuid, ?::uuid, 'EVENT_COMPLETED', ?)
                """, eventId, dossierId, sortOrder);
    }

    /** Seed 1 policy PUBLISHED cho event; required = [lessonIds]. */
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

    private String publish() throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
    }

    private String publishReadOnly() throws Exception {
        // Lesson KHÔNG có graded activity nào → masteryStatus NOT_ASSESSED:
        // r1 READ required (không chấm) + es EVIDENCE_SELECT required nhưng
        // KHÔNG config.graded → ungraded (count-only) → satisfies
        // NO_REQUIRED_ACTIVITY mà không tạo denominator cho knowledgeScore.
        String draft = """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","required":true,
                                    "config":{"text":"intro"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"es","type":"EVIDENCE_SELECT",
                                    "required":true,
                                    "config":{"visibleEvidenceIds":["%s"],
                                              "minRequired":1}}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(evId, evId);
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId,
                tplId, draft);
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

    private String completableAttempt(String token, String lessonId) throws Exception {
        String attemptId = AttemptItFixture.startAttempt(mvc, om, token, lessonId);
        submit(token, attemptId, "r1", "{}");
        submit(token, attemptId, "mc", "{\"selectedOptionIds\":[\"o1\"]}");
        return attemptId;
    }

    private String completableReadOnly(String token, String lessonId) throws Exception {
        String attemptId = AttemptItFixture.startAttempt(mvc, om, token, lessonId);
        submit(token, attemptId, "r1", "{}");
        // EVIDENCE_SELECT required, ungraded — submit đủ minRequired=1.
        submit(token, attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + evId + "\"]}");
        return attemptId;
    }

    private long progressCount(String userId, String eventId, String milestone) {
        Long n = jdbc.queryForObject(
                "select count(*) from user_event_progress "
              + "where user_id = ?::uuid and event_id = ?::uuid and milestone = ?",
                Long.class, userId, eventId, milestone);
        return n == null ? 0 : n;
    }

    private long unlockCount(String userId) {
        Long n = jdbc.queryForObject(
                "select count(*) from user_dossier_unlocks where user_id = ?::uuid",
                Long.class, userId);
        return n == null ? 0 : n;
    }

    private boolean unlockExists(String userId, String dossierId) {
        Long n = jdbc.queryForObject(
                "select count(*) from user_dossier_unlocks "
              + "where user_id = ?::uuid and dossier_id = ?::uuid",
                Long.class, userId, dossierId);
        return n != null && n > 0;
    }

    /* ---------- happy path ---------- */

    @Test
    void completeLesson_policyFires_eventCompletedAndDossiersUnlocked()
            throws Exception {
        String lessonId = publish();
        String dos1 = newDossier("nguyen-trai", "PERSON", "Nguyễn Trãi", "PUBLISHED");
        String dos2 = newDossier("chi-linh", "LOCATION", "Chí Linh", "PUBLISHED");
        linkDossier(dos1, 1);
        linkDossier(dos2, 2);
        newPolicy(1, new String[]{lessonId}, 70);

        String attemptId = completableAttempt(learnerToken, lessonId);
        MvcResult res = complete(learnerToken, attemptId, "k-g4-1");
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        JsonNode body = AttemptItFixture.body(om, res);
        assertThat(body.get("status").asText()).isEqualTo("COMPLETED");
        // GAME-04 additive field — danh sách dossier mới trong lần complete.
        assertThat(body.get("newlyUnlockedDossiers").isArray()).isTrue();
        assertThat(body.get("newlyUnlockedDossiers").size()).isEqualTo(2);

        // Ledger + unlocks trong cùng tx.
        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(progressCount(learnerId, eventId, "EVENT_MASTERED")).isEqualTo(1);
        assertThat(unlockExists(learnerId, dos1)).isTrue();
        assertThat(unlockExists(learnerId, dos2)).isTrue();

        // Progress endpoint phản ánh đúng.
        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EVENT_MASTERED"))
                .andExpect(jsonPath("$.eventCompleted").value(true))
                .andExpect(jsonPath("$.eventMastered").value(true))
                .andExpect(jsonPath("$.requiredLessonsTotal").value(1))
                .andExpect(jsonPath("$.requiredLessonsCompleted").value(1))
                .andExpect(jsonPath("$.masteryThreshold").value(70))
                .andExpect(jsonPath("$.unlockedDossiersCount").value(2))
                .andExpect(jsonPath("$.requiredLessons[0].masteryStatus")
                        .value("MASTERED"));
    }

    @Test
    void replayComplete_emptyNewlyUnlocked_noCue() throws Exception {
        String lessonId = publish();
        String dos1 = newDossier("ngo-quyen", "PERSON", "Ngô Quyền", "PUBLISHED");
        linkDossier(dos1, 1);
        newPolicy(1, new String[]{lessonId}, 70);

        String attemptId = completableAttempt(learnerToken, lessonId);
        MvcResult first = complete(learnerToken, attemptId, "k-g4-2");
        assertThat(first.getResponse().getStatus()).isEqualTo(200);
        assertThat(AttemptItFixture.body(om, first)
                .get("newlyUnlockedDossiers").size()).isEqualTo(1);

        // Replay cùng idem key → stored response (idempotency layer) trả
        // verbatim từ lần đầu — không ghi thêm ledger/unlock row.
        MvcResult replay = complete(learnerToken, attemptId, "k-g4-2");
        assertThat(replay.getResponse().getStatus()).isEqualTo(200);
        assertThat(AttemptItFixture.body(om, replay).get("status").asText())
                .isEqualTo("COMPLETED");
        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(unlockCount(learnerId)).isEqualTo(1);

        // Complete lại KHÔNG idem key → đi vào doComplete, attempt đã
        // COMPLETED → alreadyCompleted=true, newlyUnlockedDossiers rỗng
        // (client không hiện cue lần hai).
        MvcResult again = complete(learnerToken, attemptId, null);
        assertThat(again.getResponse().getStatus()).isEqualTo(200);
        JsonNode againBody = AttemptItFixture.body(om, again);
        assertThat(againBody.get("alreadyCompleted").asBoolean()).isTrue();
        assertThat(againBody.get("newlyUnlockedDossiers").size()).isZero();

        // Ledger vẫn không duplicate.
        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(unlockCount(learnerId)).isEqualTo(1);
    }

    @Test
    void noPolicy_notConfigured_noProgressNoUnlock() throws Exception {
        String lessonId = publish();
        // Không seed policy → NOT_CONFIGURED.
        String attemptId = completableAttempt(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);

        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("NOT_CONFIGURED"))
                .andExpect(jsonPath("$.eventCompleted").value(false))
                .andExpect(jsonPath("$.policyVersion").doesNotExist())
                .andExpect(jsonPath("$.unlockedDossiersCount").value(0));

        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isZero();
        assertThat(unlockCount(learnerId)).isZero();
    }

    @Test
    void belowThreshold_completedNotMastered() throws Exception {
        String lessonId = publish();
        newPolicy(1, new String[]{lessonId}, 70);

        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}");
        submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o2\"]}"); // sai → knowledgeScore < 70
        complete(learnerToken, attemptId, null);

        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EVENT_COMPLETED"))
                .andExpect(jsonPath("$.eventCompleted").value(true))
                .andExpect(jsonPath("$.eventMastered").value(false))
                .andExpect(jsonPath("$.requiredLessons[0].masteryStatus")
                        .value("BELOW_THRESHOLD"))
                .andExpect(jsonPath("$.requiredLessons[0].bestKnowledgeScore")
                        .isNumber());

        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(progressCount(learnerId, eventId, "EVENT_MASTERED")).isZero();
    }

    @Test
    void readOnlyLesson_completedButNotAssessed_notMastered() throws Exception {
        String lessonId = publishReadOnly();
        newPolicy(1, new String[]{lessonId}, 70);

        String attemptId = completableReadOnly(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);

        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EVENT_COMPLETED"))
                .andExpect(jsonPath("$.eventCompleted").value(true))
                .andExpect(jsonPath("$.eventMastered").value(false))
                .andExpect(jsonPath("$.requiredLessons[0].masteryStatus")
                        .value("NOT_ASSESSED"))
                .andExpect(jsonPath("$.requiredLessons[0].bestKnowledgeScore")
                        .doesNotExist());

        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(progressCount(learnerId, eventId, "EVENT_MASTERED")).isZero();
    }

    @Test
    void thresholdNull_neverMastered() throws Exception {
        String lessonId = publish();
        newPolicy(1, new String[]{lessonId}, null); // không xét mastered

        String attemptId = completableAttempt(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);

        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EVENT_COMPLETED"))
                .andExpect(jsonPath("$.eventMastered").value(false))
                .andExpect(jsonPath("$.masteryThreshold").doesNotExist());

        assertThat(progressCount(learnerId, eventId, "EVENT_MASTERED")).isZero();
    }

    /* ---------- dossier API ---------- */

    @Test
    void dossierList_showsPublishedAndUnlocked_only() throws Exception {
        String lessonId = publish();
        String dos1 = newDossier("ngo-quyen", "PERSON", "Ngô Quyền", "PUBLISHED");
        String dos2 = newDossier("song-bach-dang", "LOCATION", "Sông Bạch Đằng", "PUBLISHED");
        String dosDraft = newDossier("draft-item", "ARTIFACT", "Bí mật", "DRAFT");
        String dosArchived = newDossier("arch-item", "CONTEXT", "Cũ", "ARCHIVED");
        linkDossier(dos1, 1);
        linkDossier(dos2, 2);
        newPolicy(1, new String[]{lessonId}, 70);

        // Chưa complete → list vẫn thấy PUBLISHED, không thấy DRAFT/ARCHIVED.
        mvc.perform(get("/api/v1/me/collection/dossiers")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content[0].dossierId").value(dos1))
                .andExpect(jsonPath("$.content[0].unlocked").value(false))
                .andExpect(jsonPath("$.content[0].preview").value(true))
                .andExpect(jsonPath("$.content[1].dossierId").value(dos2))
                .andExpect(jsonPath("$.content[1].unlocked").value(false));

        // Filter type.
        mvc.perform(get("/api/v1/me/collection/dossiers?type=PERSON")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].dossierId").value(dos1));

        // Complete → unlock cả hai.
        String attemptId = completableAttempt(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);

        mvc.perform(get("/api/v1/me/collection/dossiers?unlocked=true")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content[0].unlocked").value(true))
                .andExpect(jsonPath("$.content[0].preview").value(false));

        mvc.perform(get("/api/v1/me/collection/dossiers?unlocked=false")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void dossierDetail_lockedPublished_previewNoDescriptionNoSource()
            throws Exception {
        String lessonId = publish();
        String dos1 = newDossier("ngo-quyen", "PERSON", "Ngô Quyền", "PUBLISHED");
        linkDossier(dos1, 1);
        newPolicy(1, new String[]{lessonId}, 70);

        // Locked → preview, không description/source.
        mvc.perform(get("/api/v1/me/collection/dossiers/" + dos1)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dossierId").value(dos1))
                .andExpect(jsonPath("$.unlocked").value(false))
                .andExpect(jsonPath("$.preview").value(true))
                .andExpect(jsonPath("$.description").doesNotExist())
                .andExpect(jsonPath("$.source").doesNotExist())
                .andExpect(jsonPath("$.dossierVersion").doesNotExist());

        // Complete → full detail.
        String attemptId = completableAttempt(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);

        mvc.perform(get("/api/v1/me/collection/dossiers/" + dos1)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlocked").value(true))
                .andExpect(jsonPath("$.preview").value(false))
                .andExpect(jsonPath("$.description").isNotEmpty())
                .andExpect(jsonPath("$.source.title")
                        .value("Đại Việt sử ký toàn thư"))
                .andExpect(jsonPath("$.dossierVersion").value(1));
    }

    @Test
    void dossierDetail_draftAndLockedArchived_404() throws Exception {
        String lessonId = publish();
        String dosDraft = newDossier("draft-item", "ARTIFACT", "Bí mật", "DRAFT");
        String dosArchived = newDossier("arch-item", "CONTEXT", "Cũ", "ARCHIVED");
        linkDossier(dosDraft, 1);
        linkDossier(dosArchived, 2);
        newPolicy(1, new String[]{lessonId}, 70);

        // DRAFT → 404.
        mvc.perform(get("/api/v1/me/collection/dossiers/" + dosDraft)
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("DOSSIER_NOT_FOUND"));

        // ARCHIVED chưa unlock → 404.
        mvc.perform(get("/api/v1/me/collection/dossiers/" + dosArchived)
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("DOSSIER_NOT_FOUND"));

        // Sau complete, DRAFT không được fan-out; ARCHIVED cũng không
        // (fan-out chỉ PUBLISHED). Cả hai vẫn 404.
        String attemptId = completableAttempt(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);

        mvc.perform(get("/api/v1/me/collection/dossiers/" + dosDraft)
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/me/collection/dossiers/" + dosArchived)
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void dossierRoute_doesNotClashWithEvidenceRoute() throws Exception {
        // Literal `/dossiers` phải thắng `/{evidenceId}` — không trả 404
        // "collection item not found".
        mvc.perform(get("/api/v1/me/collection/dossiers")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
    }

    @Test
    void dossierList_scopedToLearner_otherSeesNothing() throws Exception {
        String lessonId = publish();
        String dos1 = newDossier("ngo-quyen", "PERSON", "Ngô Quyền", "PUBLISHED");
        linkDossier(dos1, 1);
        newPolicy(1, new String[]{lessonId}, 70);

        String attemptId = completableAttempt(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);

        // Other learner chưa complete → vẫn thấy dossier nhưng locked.
        mvc.perform(get("/api/v1/me/collection/dossiers")
                        .header("Authorization", otherToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].unlocked").value(false));

        // Other learner không thấy detail nếu dossier là DRAFT (đã có test).
        // Kiểm tra unlock provenance không lẫn.
        assertThat(unlockExists(otherId, dos1)).isFalse();
    }

    /* ---------- reconcile-on-read ---------- */

    @Test
    void reconcileOnRead_completedBeforePolicy_grantsOnFirstRead()
            throws Exception {
        String lessonId = publish();
        String dos1 = newDossier("ngo-quyen", "PERSON", "Ngô Quyền", "PUBLISHED");
        linkDossier(dos1, 1);

        // Complete TRƯỚC khi policy tồn tại — không milestone.
        String attemptId = completableAttempt(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);
        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isZero();
        assertThat(unlockCount(learnerId)).isZero();

        // Policy publish sau — đọc progress reconcile + grant.
        newPolicy(1, new String[]{lessonId}, 70);
        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EVENT_MASTERED"))
                .andExpect(jsonPath("$.unlockedDossiersCount").value(1));

        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(progressCount(learnerId, eventId, "EVENT_MASTERED")).isEqualTo(1);
        assertThat(unlockExists(learnerId, dos1)).isTrue();
    }

    @Test
    void reconcileOnRead_secondRead_idempotent() throws Exception {
        String lessonId = publish();
        String dos1 = newDossier("ngo-quyen", "PERSON", "Ngô Quyền", "PUBLISHED");
        linkDossier(dos1, 1);
        newPolicy(1, new String[]{lessonId}, 70);

        String attemptId = completableAttempt(learnerToken, lessonId);
        complete(learnerToken, attemptId, null);
        // Lần đọc đầu đã grant; lần hai không ghi thêm.
        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(unlockCount(learnerId)).isEqualTo(1);
    }

    /* ---------- concurrency ---------- */

    @Test
    void concurrentLastTwoLessons_exactlyOnceMilestoneAndUnlock()
            throws Exception {
        // 2 required lessons — 2 completes song song; lock (user,event)
        // serialize để không mất milestone.
        String lesson1 = publish();
        String lesson2 = publish(); // cùng event → cùng policy
        String dos1 = newDossier("ngo-quyen", "PERSON", "Ngô Quyền", "PUBLISHED");
        linkDossier(dos1, 1);
        newPolicy(1, new String[]{lesson1, lesson2}, 70);

        String a1 = completableAttempt(learnerToken, lesson1);
        String a2 = completableAttempt(learnerToken, lesson2);

        int threads = 2;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger ok = new AtomicInteger();
        List<Future<?>> futures = new java.util.ArrayList<>();
        futures.add(pool.submit(() -> {
            ready.countDown();
            go.await(5, TimeUnit.SECONDS);
            MvcResult r = complete(learnerToken, a1, "k-c1");
            if (r.getResponse().getStatus() == 200) ok.incrementAndGet();
            return null;
        }));
        futures.add(pool.submit(() -> {
            ready.countDown();
            go.await(5, TimeUnit.SECONDS);
            MvcResult r = complete(learnerToken, a2, "k-c2");
            if (r.getResponse().getStatus() == 200) ok.incrementAndGet();
            return null;
        }));
        assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
        go.countDown();
        for (Future<?> f : futures) f.get(60, TimeUnit.SECONDS);
        pool.shutdown();

        assertThat(ok.get()).isEqualTo(threads);
        // Cả hai complete → event completed + mastered (cả 2 đều pass).
        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(progressCount(learnerId, eventId, "EVENT_MASTERED")).isEqualTo(1);
        assertThat(unlockExists(learnerId, dos1)).isTrue();
    }

    /* ---------- 404 / ownership ---------- */

    @Test
    void progress_unknownEvent_404() throws Exception {
        String bogus = UUID.randomUUID().toString();
        mvc.perform(get("/api/v1/me/events/" + bogus + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void progress_unauthenticated_401() throws Exception {
        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void dossierList_unauthenticated_401() throws Exception {
        mvc.perform(get("/api/v1/me/collection/dossiers"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void dossierDetail_unknownId_404() throws Exception {
        String bogus = UUID.randomUUID().toString();
        mvc.perform(get("/api/v1/me/collection/dossiers/" + bogus)
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("DOSSIER_NOT_FOUND"));
    }

    @Test
    void dossierList_pageSizeCappedAt50() throws Exception {
        // size=100 → cap về 50; vẫn trả page 0 hợp lệ.
        mvc.perform(get("/api/v1/me/collection/dossiers?size=100")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.size").value(50));
    }

    @Test
    void republishPolicy_oldProgressSurvives() throws Exception {
        String lessonId = publish();
        newPolicy(1, new String[]{lessonId}, 70);

        // Complete với best score 0 (mc trả sai) — dưới cả threshold mới
        // (80) nên policy v2 cũng không grant EVENT_MASTERED.
        String attemptId = AttemptItFixture.startAttempt(mvc, om,
                learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}");
        submit(learnerToken, attemptId, "mc", "{\"selectedOptionIds\":[\"o2\"]}");
        complete(learnerToken, attemptId, null);
        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);

        // Archive policy 1, publish policy 2 — milestone cũ không mất.
        jdbc.update("update event_completion_policies set status = 'ARCHIVED' "
                  + "where event_id = ?::uuid and policy_version = 1", eventId);
        newPolicy(2, new String[]{lessonId}, 80); // threshold cao hơn

        mvc.perform(get("/api/v1/me/events/" + eventId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EVENT_COMPLETED"))
                .andExpect(jsonPath("$.eventMastered").value(false))
                .andExpect(jsonPath("$.policyVersion").value(2));

        // Grant cũ vẫn tồn tại (entitlement không thu hồi).
        assertThat(progressCount(learnerId, eventId, "EVENT_COMPLETED")).isEqualTo(1);
        assertThat(progressCount(learnerId, eventId, "EVENT_MASTERED")).isZero();
    }
}

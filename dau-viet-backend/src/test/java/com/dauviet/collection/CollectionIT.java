package com.dauviet.collection;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.Map;
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
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * TASK-0022 — Collection: EVIDENCE_SELECT hoàn thành → user_evidence rows;
 * dedup (user, evidence) qua upsert; snapshot_json giữ nội dung đã collect
 * khi evidence gốc bị archive; /me/collection scoped theo JWT. Docker cần.
 */
@SpringBootTest
@AutoConfigureMockMvc
class CollectionIT extends AbstractPostgresIT {

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
    private String ev1;
    private String ev2;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = token("a@c.vn", UserRole.CONTENT_ADMIN);
        learnerToken = token("l@c.vn", UserRole.LEARNER);
        otherToken = token("o@c.vn", UserRole.LEARNER);
        learnerId = userIdByEmail("l@c.vn");
        eventId = newEvent("e-col");
        tplId = newTemplate("t-col");
        ev1 = newEvidence(eventId, "Bãi cọc Bạch Đằng", "ARTIFACT", "Đại Việt Sử ký Toàn thư");
        ev2 = newEvidence(eventId, "Ngô Quyền", "CHARACTER", "Khâm định Việt sử");
    }

    /* ---------- helpers ---------- */

    private String token(String email, UserRole role) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail(email);
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(role);
        u.setStatus(UserStatus.ACTIVE);
        users.save(u);
        return "Bearer " + jwt.createAccessToken(u);
    }

    private String userIdByEmail(String email) {
        return jdbc.queryForObject(
                "select id from users where email = ?", String.class, email);
    }

    private String newEvent(String slug) {
        String id = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, ?, 'E', 's', 'PUBLISHED')", id, slug);
        return id;
    }

    private String newTemplate(String code) {
        String id = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, ?, 'T', 1, '{}'::jsonb, true)", id, code);
        return id;
    }

    private String newEvidence(String eventId, String title, String type,
                               String sourceTitle) {
        String id = UUID.randomUUID().toString();
        jdbc.update("""
                insert into evidences (id, event_id, title, evidence_type,
                                       source_title, source_author, source_citation,
                                       description, status)
                values (?::uuid, ?::uuid, ?, ?, ?, 'Tác giả', 'tr. 123', 'mô tả', 'APPROVED')
                """, id, eventId, title, type, sourceTitle);
        return id;
    }

    /** Draft một stage EVIDENCE có 1 EVIDENCE_SELECT required. */
    private String draftEvidenceSelect() {
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                    "config":{"visibleEvidenceIds":["%s","%s"],"minRequired":1}}],
                    "requiredEvidenceIds":["%s","%s"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(ev1, ev2, ev1, ev2);
    }

    private String publish() throws Exception {
        Map<String, Object> req = Map.of(
                "eventId", eventId, "templateId", tplId,
                "title", "L", "centralQuestion", "Q?",
                "draftJson", draftEvidenceSelect());
        MvcResult created = mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        String lessonId = om.readTree(created.getResponse().getContentAsString())
                .get("id").asText();
        mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        return lessonId;
    }

    private String startAttempt(String token, String lessonId) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", token))
                .andExpect(status().isOk()).andReturn();
        return om.readTree(res.getResponse().getContentAsString())
                .get("attemptId").asText();
    }

    private MvcResult submitEs(String token, String attemptId, String idsJson,
                               String idemKey) throws Exception {
        var req = post("/api/v1/attempts/" + attemptId
                        + "/activities/es/submissions")
                .header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"answer\":{\"selectedEvidenceIds\":" + idsJson + "}}");
        if (idemKey != null) req = req.header("Idempotency-Key", idemKey);
        return mvc.perform(req).andReturn();
    }

    private long rowCount(String where) {
        Long n = jdbc.queryForObject(
                "select count(*) from user_evidence where " + where, Long.class);
        return n == null ? 0 : n;
    }

    /* ---------- tests ---------- */

    @Test
    void evidenceSelectCompleted_savesSelectedEvidence() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);

        submitEs(learnerToken, attemptId, "[\"" + ev1 + "\",\"" + ev2 + "\"]", null);

        // Cả 2 evidence được lưu, đúng attempt + learner.
        List<Map<String, Object>> rows = jdbc.queryForList(
                "select evidence_id::text as eid, learner_attempt_id::text as aid, "
              + "evidence_type, event_id::text as evt, snapshot_json::text as snap "
              + "from user_evidence where user_id = ?::uuid order by evidence_id",
                learnerId);
        assertThat(rows).hasSize(2);
        assertThat(rows.stream().map(r -> (String) r.get("eid")).sorted().toList())
                .containsExactlyInAnyOrder(ev1, ev2);
        assertThat(rows).allSatisfy(r -> {
            assertThat(r.get("aid")).isEqualTo(attemptId);
            assertThat(r.get("evt")).isEqualTo(eventId);
            assertThat(r.get("snap")).isNotNull();
        });
    }

    @Test
    void replaySameIdempotencyKey_doesNotDuplicateRows() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);

        submitEs(learnerToken, attemptId, "[\"" + ev1 + "\"]", "k-es-1");
        submitEs(learnerToken, attemptId, "[\"" + ev1 + "\"]", "k-es-1"); // replay

        assertThat(rowCount("user_id = '" + learnerId + "'")).isEqualTo(1);
    }

    @Test
    void repeatSubmitDifferentKey_sameAttempt_noDuplicate() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);

        submitEs(learnerToken, attemptId, "[\"" + ev1 + "\"]", "k-a");
        submitEs(learnerToken, attemptId, "[\"" + ev1 + "\"]", "k-b"); // khác key

        // (attempt, evidence) UNIQUE của V4 chặn duplicate trong cùng attempt.
        assertThat(rowCount("user_id = '" + learnerId + "'")).isEqualTo(1);
    }

    @Test
    void newAttemptSameLesson_noDuplicateDisplayEntry() throws Exception {
        String lessonId = publish();
        String a1 = startAttempt(learnerToken, lessonId);
        submitEs(learnerToken, a1, "[\"" + ev1 + "\"]", "k-1");
        // Hoàn thành attempt 1 → start attempt 2 (khác version pin? cùng version,
        // nhưng attempt mới sau khi complete+abandon không được phép —
        // ở đây dùng user KHÁC để tạo attempt riêng, hoặc complete rồi start lại).
        mvc.perform(post("/api/v1/attempts/" + a1 + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        // Attempt 2 cùng lesson — resume-scope theo lesson nên vẫn trả attempt
        // COMPLETED cũ? Không: startOrResume chỉ resume IN_PROGRESS; sau
        // COMPLETED nó tạo attempt mới pinned cùng version.
        String a2 = startAttempt(learnerToken, lessonId);
        assertThat(a2).isNotEqualTo(a1);
        submitEs(learnerToken, a2, "[\"" + ev1 + "\"]", "k-2");

        // (user, evidence) dedup — collection chỉ 1 entry dù 2 attempts.
        assertThat(rowCount("user_id = '" + learnerId + "'")).isEqualTo(1);
        mvc.perform(get("/api/v1/me/collection")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].evidenceId").value(ev1));
    }

    @Test
    void invalidEvidenceId_rejected_noCollectionRow() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);
        String bogus = UUID.randomUUID().toString();

        mvc.perform(post("/api/v1/attempts/" + attemptId
                        + "/activities/es/submissions")
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":{\"selectedEvidenceIds\":[\""
                                + bogus + "\"]}}"))
                .andExpect(status().isBadRequest());

        assertThat(rowCount("user_id = '" + learnerId + "'")).isZero();
    }

    @Test
    void list_scopedToAuthenticatedLearner() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);
        submitEs(learnerToken, attemptId, "[\"" + ev1 + "\"]", "k-l");

        // Learner khác không thấy collection của learner này.
        mvc.perform(get("/api/v1/me/collection")
                        .header("Authorization", otherToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0))
                .andExpect(jsonPath("$.content").isEmpty());
        // Detail của learner khác → 404.
        mvc.perform(get("/api/v1/me/collection/" + ev1)
                        .header("Authorization", otherToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void list_filterByEvidenceType_andPagination() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);
        submitEs(learnerToken, attemptId,
                "[\"" + ev1 + "\",\"" + ev2 + "\"]", "k-t");

        mvc.perform(get("/api/v1/me/collection?type=ARTIFACT")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].evidenceId").value(ev1))
                .andExpect(jsonPath("$.content[0].evidence.title")
                        .value("Bãi cọc Bạch Đằng"));

        mvc.perform(get("/api/v1/me/collection?page=0&size=1")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.totalPages").value(2));
    }

    // P2-A — deterministic pagination khi nhiều row trùng collected_at
    // (Postgres now() gán cùng timestamp trong 1 transaction): secondary
    // sort evidenceId ASC đảm bảo mỗi item xuất hiện đúng một lần qua các
    // trang, thứ tự ổn định.
    @Test
    void list_deterministicOrder_whenSameCollectedAt() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);
        // Cần 1 row learner_attempts hợp lệ làm FK.
        submitEs(learnerToken, attemptId, "[\"" + ev1 + "\"]", "k-seed");

        // Xoá row collect từ submit; seed 25 rows evidence khác nhau
        // (unique (user_id, evidence_id)) nhưng cùng collected_at.
        jdbc.update("delete from user_evidence");
        final int total = 25;
        List<String> ids = new java.util.ArrayList<>();
        for (int i = 0; i < total; i++) {
            String eid = newEvidence(eventId, "E" + i, "ARTIFACT", "S" + i);
            ids.add(eid);
            jdbc.update("""
                    INSERT INTO user_evidence
                        (id, user_id, learner_attempt_id, evidence_id,
                         evidence_type, event_id, snapshot_json, collected_at)
                    VALUES (gen_random_uuid(), ?::uuid, ?::uuid, ?::uuid,
                            'ARTIFACT', ?::uuid,
                            '{"evidence":{"title":"T"}}'::jsonb,
                            '2026-10-22T00:00:00Z'::timestamptz)
                    """, learnerId, attemptId, eid, eventId);
        }

        // Fetch page 0..4 size 5 — mỗi item xuất hiện đúng một lần.
        List<String> seen = new java.util.ArrayList<>();
        for (int page = 0; page < 5; page++) {
            MvcResult res = mvc.perform(get(
                            "/api/v1/me/collection?page=" + page + "&size=5")
                            .header("Authorization", learnerToken))
                    .andExpect(status().isOk())
                    .andReturn();
            JsonNode items = om.readTree(res.getResponse().getContentAsString())
                    .get("content");
            for (JsonNode it : items) {
                seen.add(it.get("evidenceId").asText());
            }
        }
        assertThat(seen).hasSize(total);
        assertThat(seen).containsExactlyInAnyOrderElementsOf(ids);
        // Không trùng lặp qua các trang.
        assertThat(new java.util.HashSet<>(seen)).hasSize(total);

        // Thứ tự ổn định: fetch lại page 0 phải ra đúng 5 id đầu như lần trước.
        MvcResult again = mvc.perform(get(
                        "/api/v1/me/collection?page=0&size=5")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode items = om.readTree(again.getResponse().getContentAsString())
                .get("content");
        for (int i = 0; i < 5; i++) {
            assertThat(items.get(i).get("evidenceId").asText())
                    .isEqualTo(seen.get(i));
        }
    }

    @Test
    void detail_survivesEvidenceArchiveAndEdit() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);
        submitEs(learnerToken, attemptId, "[\"" + ev1 + "\"]", "k-d");

        // Admin archive + đổi title evidence gốc SAU KHI collect.
        jdbc.update("update evidences set status = 'ARCHIVED', title = 'TÊN MỚI' "
                  + "where id = ?::uuid", ev1);

        // Collection vẫn trả metadata lúc collect (snapshot_json immutable).
        mvc.perform(get("/api/v1/me/collection/" + ev1)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.evidenceId").value(ev1))
                .andExpect(jsonPath("$.evidence.title").value("Bãi cọc Bạch Đằng"))
                .andExpect(jsonPath("$.evidence.source.title")
                        .value("Đại Việt Sử ký Toàn thư"))
                .andExpect(jsonPath("$.evidence.source.author").value("Tác giả"))
                .andExpect(jsonPath("$.eventTitle").value("E"))
                .andExpect(jsonPath("$.lessonTitle").value("L"));
    }

    @Test
    void incompleteSubmission_doesNotCollect() throws Exception {
        String lessonId = publish();
        String attemptId = startAttempt(learnerToken, lessonId);
        // minRequired=1 → cần ít nhất 1; submit rỗng → completed=false.
        mvc.perform(post("/api/v1/attempts/" + attemptId
                        + "/activities/es/submissions")
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":{\"selectedEvidenceIds\":[]}}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.evaluation.completed").value(false));

        assertThat(rowCount("user_id = '" + learnerId + "'")).isZero();
    }

    @Test
    void unauthenticated_rejected() throws Exception {
        mvc.perform(get("/api/v1/me/collection"))
                .andExpect(status().isUnauthorized());
    }
}

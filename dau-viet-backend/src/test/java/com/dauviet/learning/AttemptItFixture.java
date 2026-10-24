package com.dauviet.learning;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Shared fixture helpers for learner-attempt ITs: users/tokens, published
 * lesson via the admin API, and attempt start. Keeps the ITs focused on
 * behavior instead of repeating insert/publish boilerplate.
 */
public final class AttemptItFixture {

    private AttemptItFixture() {
    }

    public static String token(UserRepository users, JwtTokenService jwt,
                        String email, UserRole role) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail(email);
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(role);
        u.setStatus(UserStatus.ACTIVE);
        users.save(u);
        return "Bearer " + jwt.createAccessToken(u);
    }

    public static String newEvent(JdbcTemplate jdbc, String slug) {
        String id = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, ?, 'E', 's', 'PUBLISHED')", id, slug);
        return id;
    }

    public static String newTemplate(JdbcTemplate jdbc, String code) {
        String id = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, ?, 'T', 1, '{}'::jsonb, true)", id, code);
        return id;
    }

    public static String newEvidence(JdbcTemplate jdbc, String eventId) {
        String id = UUID.randomUUID().toString();
        jdbc.update("insert into evidences (id, event_id, title, evidence_type, source_title, status) "
                  + "values (?::uuid, ?::uuid, 'EV', 'DOC', 'src', 'APPROVED')", id, eventId);
        return id;
    }

    /**
     * Publishable draft: CONTEXT(read, optional) -> EVIDENCE(mcq required) -> [].
     * `mcConfig` carries the hidden keys; evidence stage lists requiredEvidenceIds
     * so publish validation passes when evidence ids are referenced.
     */
    public static String draftTwoStage(String evId, String mcConfig) {
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","required":true,
                                    "config":{"text":"intro"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                                    "config":%s}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(mcConfig, evId);
    }

    /**
     * Draft mixing optional + required activities across two stages:
     * ctx(required): r1 READ required, opt1 READ optional
     * -> ev(required): esOpt EVIDENCE_SELECT optional, mc MC required
     *    (caller controls maxAttempts).
     * totalRequired = 2 (r1 + mc); optional activities never gate progress.
     */
    public static String draftWithOptional(String evId, String mcConfig) {
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[
                      {"id":"r1","type":"READ","required":true,
                       "config":{"text":"intro"}},
                      {"id":"opt1","type":"READ",
                       "config":{"text":"side note"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[
                      {"id":"es-opt","type":"EVIDENCE_SELECT",
                       "config":{"visibleEvidenceIds":["%s"],"minRequired":1}},
                      {"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                       "config":%s}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(evId, mcConfig, evId);
    }

    /** Full pipeline: create lesson -> PUT draft -> publish. Returns lessonId. */
    public static String publishLesson(MockMvc mvc, ObjectMapper om, String adminToken,
                                String eventId, String tplId, String draftJson)
            throws Exception {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("eventId", eventId);
        req.put("templateId", tplId);
        req.put("title", "L");
        req.put("centralQuestion", "Q?");
        req.put("draftJson", draftJson);
        MvcResult created = mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        String lessonId = om.readTree(created.getResponse().getContentAsString())
                .get("id").asText();
        MvcResult pub = mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andReturn();
        if (pub.getResponse().getStatus() != 200) {
            throw new AssertionError("publish failed "
                    + pub.getResponse().getStatus() + ": "
                    + pub.getResponse().getContentAsString());
        }
        return lessonId;
    }

    public static String startAttempt(MockMvc mvc, ObjectMapper om, String learnerToken,
                               String lessonId) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        return om.readTree(res.getResponse().getContentAsString())
                .get("attemptId").asText();
    }

    public static JsonNode body(ObjectMapper om, MvcResult res) throws Exception {
        return om.readTree(res.getResponse().getContentAsString());
    }
}

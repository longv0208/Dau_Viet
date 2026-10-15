package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.List;
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
import com.dauviet.lesson.draft.DraftSchema;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Walks every response of the attempt API surface and asserts zero
 * LEARNER_HIDDEN_KEYS leaf names anywhere in the emitted JSON — the
 * primary regression net against answer-key leakage. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class HiddenKeyLeakIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String learnerToken;
    private String lessonId;

    @BeforeEach
    void setUp() throws Exception {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        String adminToken = AttemptItFixture.token(users, jwt, "a@h.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@h.vn", UserRole.LEARNER);
        String eventId = AttemptItFixture.newEvent(jdbc, "e-hid");
        String tplId = AttemptItFixture.newTemplate(jdbc, "t-hid");
        String evId = AttemptItFixture.newEvidence(jdbc, eventId);

        // Draft exercises hidden keys on several activity types:
        // MCQ correctOptionIds, DRAG_ORDER expectedOrder, MATCHING correctPairs,
        // VERIFICATION requiredEvidenceIds + expectedHypothesis.
        String draft = """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","required":true,
                                    "config":{"text":"intro"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[
                      {"id":"es","type":"EVIDENCE_SELECT","required":true,
                       "config":{"visibleEvidenceIds":["%s"]},
                       "evidenceRefs":["%s"]},
                      {"id":"mc","type":"MULTIPLE_CHOICE","required":true,
                       "config":{"question":"q","options":[{"id":"o1"},{"id":"o2"}],
                                 "correctOptionIds":["o1"],"maxAttempts":3}}],
                    "requiredEvidenceIds":["%s"],
                    "nextStageIds":["rec"]},
                   {"id":"rec","type":"RECONSTRUCTION","required":true,
                    "activities":[
                      {"id":"do","type":"DRAG_ORDER","required":true,
                       "config":{"items":[{"id":"i1"},{"id":"i2"}],
                                 "expectedOrder":["i1","i2"]}}],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(evId, evId, evId);
        lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId, tplId, draft);
    }

    @Test
    void everyEndpoint_emitsZeroHiddenKeys() throws Exception {
        List<String> found = new ArrayList<>();

        // start
        MvcResult start = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        String attemptId = AttemptItFixture.body(om, start).get("attemptId").asText();
        collect(AttemptItFixture.body(om, start), found, "POST start");

        // get attempt
        found.addAll(scan(mvc.perform(get("/api/v1/attempts/" + attemptId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn(), "GET attempt"));

        // current at r1
        found.addAll(scan(mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn(), "GET current"));

        // walk the lesson: r1 -> es -> mc -> do
        found.addAll(scan(submit(attemptId, "r1", "{}"), "submit r1"));
        found.addAll(scan(mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn(), "GET current es"));

        found.addAll(scan(submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + firstEvidenceId() + "\"]}"), "submit es"));
        found.addAll(scan(submit(attemptId, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}"), "submit mc"));
        found.addAll(scan(mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn(), "GET current do"));
        found.addAll(scan(submit(attemptId, "do",
                "{\"orderedIds\":[\"i1\",\"i2\"]}"), "submit do"));

        // complete endpoint
        found.addAll(scan(mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn(), "POST complete"));

        // TASK-0012 surfaces: persisted result + history/progress lists
        found.addAll(scan(mvc.perform(get("/api/v1/attempts/" + attemptId + "/result")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn(), "GET result"));
        found.addAll(scan(mvc.perform(get("/api/v1/me/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn(), "GET me/attempts"));
        found.addAll(scan(mvc.perform(get("/api/v1/me/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn(), "GET me/progress"));

        assertThat(found).as("hidden key leaks across endpoint surface").isEmpty();
    }

    private String firstEvidenceId() {
        return jdbc.queryForObject(
                "select id::text from evidences order by id limit 1", String.class);
    }

    private MvcResult submit(String attemptId, String activityId, String answerJson)
            throws Exception {
        return mvc.perform(post("/api/v1/attempts/" + attemptId
                        + "/activities/" + activityId + "/submissions")
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":" + answerJson + "}"))
                .andExpect(status().isOk()).andReturn();
    }

    private List<String> scan(MvcResult res, String label) throws Exception {
        JsonNode body = AttemptItFixture.body(om, res);
        List<String> found = new ArrayList<>();
        collect(body, found, label);
        return found;
    }

    private void collect(JsonNode node, List<String> found, String label) {
        if (node == null) return;
        if (node.isObject()) {
            node.fields().forEachRemaining(e -> {
                if (DraftSchema.LEARNER_HIDDEN_KEYS.contains(e.getKey())) {
                    found.add(label + ": " + e.getKey());
                }
                collect(e.getValue(), found, label);
            });
        } else if (node.isArray()) {
            node.forEach(n -> collect(n, found, label));
        }
    }
}

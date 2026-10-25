package com.dauviet.reward;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import com.dauviet.learning.AttemptItFixture;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * GAME-06 Module C — rule validate dry-run + revision history ITs.
 * Requires Docker (Testcontainers Postgres).
 */
@SpringBootTest
@AutoConfigureMockMvc
class AdminItemRuleIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String itemId;
    private String eventId;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from item_unlock_rule");
        jdbc.update("delete from item_catalog");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@g6r.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@g6r.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "e-g6r");
        // EVENT_COMPLETED/EVENT_MASTERED leaf can event co published policy
        // (ItemConditionValidator.requireConfiguredPolicy) — seed policy v1.
        jdbc.update("insert into event_completion_policies "
                        + "(id, event_id, policy_version, status,"
                        + " required_lesson_ids, mastery_threshold, published_at)"
                        + " values (?::uuid, ?::uuid, 1, 'PUBLISHED',"
                        + " '[]'::jsonb, 70, now())",
                UUID.randomUUID().toString(), eventId);

        itemId = UUID.randomUUID().toString();
        jdbc.update("insert into item_catalog "
                        + "(id, code, name, description, category, item_type,"
                        + " rarity, active, created_at, updated_at, row_version) "
                        + "values (?::uuid, 'it-1', 'Item 1', 'd', 'HUY_HIEU',"
                        + " 'COMMEMORATIVE_BADGE', 'COMMON', true,"
                        + " now(), now(), 0)",
                itemId);
    }

    private String ruleUrl(String suffix) {
        return "/api/v1/admin/items/" + itemId + "/rule" + suffix;
    }

    /* ---------- validate dry-run ---------- */

    @Test
    void validate_validV2Rule_returnsValidTrue() throws Exception {
        String body = "{\"ruleType\":\"RULE_V2\",\"condition\":{\"all\":["
                + "{\"type\":\"COLLECTION_COUNT\",\"threshold\":3},"
                + "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + eventId
                + "\"}]}}";
        mvc.perform(post(ruleUrl("/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(true))
                .andExpect(jsonPath("$.errors").isEmpty())
                .andExpect(jsonPath("$.normalizedCondition.all").isArray());
    }

    @Test
    void validate_invalidAst_returnsErrorsNotException() throws Exception {
        // Nested operator — vuot depth limit.
        String body = "{\"ruleType\":\"RULE_V2\",\"condition\":{\"all\":["
                + "{\"all\":[{\"type\":\"LESSON_COUNT\",\"threshold\":1}]}]}}";
        mvc.perform(post(ruleUrl("/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.errors[0].code").value("VALIDATION_FAILED"));
    }

    @Test
    void validate_extraneousField_rejected() throws Exception {
        // FIX-2 strict shape: eventId khong thuoc shape COLLECTION_COUNT.
        String body = "{\"ruleType\":\"RULE_V2\",\"condition\":"
                + "{\"type\":\"COLLECTION_COUNT\",\"threshold\":3,"
                + "\"eventId\":\"" + eventId + "\"}}";
        mvc.perform(post(ruleUrl("/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false));
    }

    @Test
    void validate_eventScopedItemRejectsGlobalRule() throws Exception {
        // Seed rule v2 event-scoped da publish → item scope EVENT_SCOPED.
        jdbc.update("insert into item_unlock_rule "
                        + "(id, item_id, rule_type, rule_version, revision,"
                        + " active, condition_json, created_at) "
                        + "values (?::uuid, ?::uuid, 'RULE_V2', 2, 1, false,"
                        + " ?::jsonb, now())",
                UUID.randomUUID().toString(), itemId,
                "{\"type\":\"EVENT_COMPLETED\",\"eventId\":\"" + eventId + "\"}");

        // Rule global moi (khong leaf event) phai bi acceptsRule=false.
        String body = "{\"ruleType\":\"RULE_V2\",\"condition\":"
                + "{\"type\":\"LESSON_COUNT\",\"threshold\":1}}";
        mvc.perform(post(ruleUrl("/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptsRule").value(false))
                .andExpect(jsonPath("$.scope").value("EVENT_SCOPED"));
    }

    @Test
    void validate_needsMappingItem_scopeUnresolved() throws Exception {
        // Rule legacy flagged needs-mapping → scope UNRESOLVED. Shape V1:
        // threshold cot phang (chk_unlock_rule_shape doi threshold>0 +
        // condition_json NULL voi rule_version=1).
        jdbc.update("insert into item_unlock_rule "
                        + "(id, item_id, rule_type, rule_version, revision,"
                        + " active, threshold, rule_metadata, created_at) "
                        + "values (?::uuid, ?::uuid, 'COLLECTION_COUNT', 1, 1,"
                        + " false, 3, ?::jsonb, now())",
                UUID.randomUUID().toString(), itemId,
                "{\"audit\":\"needs-mapping\"}");

        String body = "{\"ruleType\":\"RULE_V2\",\"condition\":"
                + "{\"type\":\"LESSON_COUNT\",\"threshold\":1}}";
        mvc.perform(post(ruleUrl("/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptsRule").value(false))
                .andExpect(jsonPath("$.scope").value("UNRESOLVED"))
                .andExpect(jsonPath("$.warnings").isNotEmpty());
    }

    @Test
    void validate_doesNotWriteDb() throws Exception {
        Long before = jdbc.queryForObject(
                "select count(*) from item_unlock_rule where item_id = ?::uuid",
                Long.class, itemId);
        String body = "{\"ruleType\":\"RULE_V2\",\"condition\":"
                + "{\"type\":\"COLLECTION_COUNT\",\"threshold\":5}}";
        mvc.perform(post(ruleUrl("/validate"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(true));
        Long after = jdbc.queryForObject(
                "select count(*) from item_unlock_rule where item_id = ?::uuid",
                Long.class, itemId);
        assertThat(after).isEqualTo(before);
    }

    /* ---------- history ---------- */

    @Test
    void history_returnsRevisionsDescWithGrantCount() throws Exception {
        // Publish 3 revision (v1 counted x2 + v2 ast).
        for (int i = 1; i <= 2; i++) {
            mvc.perform(put(ruleUrl(""))
                            .header("Authorization", adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"ruleType\":\"COLLECTION_COUNT\","
                                    + "\"threshold\":" + i + "}"))
                    .andExpect(status().isOk());
        }
        mvc.perform(put(ruleUrl(""))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"RULE_V2\",\"condition\":"
                                + "{\"type\":\"COLLECTION_COUNT\","
                                + "\"threshold\":9}}"))
                .andExpect(status().isOk());

        mvc.perform(get(ruleUrl("/history"))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(3))
                // Desc revision — moi nhat truoc.
                .andExpect(jsonPath("$[0].revision").value(3))
                .andExpect(jsonPath("$[0].ruleVersion").value(2))
                .andExpect(jsonPath("$[0].active").value(true))
                .andExpect(jsonPath("$[1].active").value(false))
                .andExpect(jsonPath("$[0].grantCount").value(0));
    }

    @Test
    void detail_includesScopeField() throws Exception {
        mvc.perform(get("/api/v1/admin/items/" + itemId)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scope").value("GLOBAL"));
    }

    /* ---------- security ---------- */

    @Test
    void unauthenticated_401_learner_403() throws Exception {
        mvc.perform(get(ruleUrl("/history")))
                .andExpect(status().isUnauthorized());
        mvc.perform(get(ruleUrl("/history"))
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }
}

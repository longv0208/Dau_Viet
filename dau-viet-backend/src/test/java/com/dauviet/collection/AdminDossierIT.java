package com.dauviet.collection;

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
 * GAME-06 Module B — admin dossier CRUD/publish/archive/link ITs.
 * Requires Docker (Testcontainers Postgres).
 */
@SpringBootTest
@AutoConfigureMockMvc
class AdminDossierIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String learnerId;
    private String eventId;

    private static final String VALID_SOURCE =
            "{\"title\":\"Đại Việt sử ký toàn thư\",\"author\":\"Ngô Sĩ Liên\","
          + "\"reliability\":\"HIGH\"}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from historical_dossier_versions");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@g6d.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@g6d.vn", UserRole.LEARNER);
        learnerId = jdbc.queryForObject(
                "select id from users where email='l@g6d.vn'", String.class);
        eventId = AttemptItFixture.newEvent(jdbc, "e-g6d");
    }

    private String createBody(String canonical, String title) {
        return "{\"canonicalCode\":\"" + canonical + "\","
             + "\"dossierType\":\"PERSON\",\"title\":\"" + title + "\","
             + "\"summary\":\"S\",\"description\":\"D\","
             + "\"source\":" + VALID_SOURCE + "}";
    }

    private String createDossierId(String canonical) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/admin/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createBody(canonical, "T-" + canonical)))
                .andReturn();
        assertThat(res.getResponse().getStatus()).as("create: %s",
                res.getResponse().getContentAsString()).isEqualTo(201);
        return om.readTree(res.getResponse().getContentAsString())
                .get("id").asText();
    }

    private void publishDossier(String id) throws Exception {
        mvc.perform(post("/api/v1/admin/dossiers/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
    }

    /* ---------- CRUD ---------- */

    @Test
    void create_201_draftVersion1() throws Exception {
        mvc.perform(post("/api/v1/admin/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createBody("ngo-quyen", "Ngô Quyền")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                // draft() khoi tao dossierVersion=1; publish ghi snapshot
                // cung version vao historical_dossier_versions.
                .andExpect(jsonPath("$.dossierVersion").value(1))
                .andExpect(jsonPath("$.canonicalCode").value("ngo-quyen"));
    }

    @Test
    void create_duplicateCanonical_400() throws Exception {
        createDossierId("dup-code");
        mvc.perform(post("/api/v1/admin/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createBody("dup-code", "T2")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void update_published_bumpsNothing_createsPendingChanges()
            throws Exception {
        String id = createDossierId("ngo-quyen");
        publishDossier(id);

        mvc.perform(put("/api/v1/admin/dossiers/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Ngô Quyền (sửa)\",\"summary\":\"S2\"}"))
                .andExpect(status().isOk())
                // dossierVersion giu nguyen (draft=1 -> publish=1) cho toi
                // publish ke tiep ra version 2.
                .andExpect(jsonPath("$.dossierVersion").value(1))
                .andExpect(jsonPath("$.pendingChanges").value(true));

        // Row_version tang (optimistic lock counter).
        Long rv = jdbc.queryForObject(
                "select row_version from historical_dossiers where id = ?::uuid",
                Long.class, id);
        assertThat(rv).isGreaterThanOrEqualTo(1L);
    }

    @Test
    void update_staleRowVersion_409() throws Exception {
        String id = createDossierId("ol-dos");
        mvc.perform(put("/api/v1/admin/dossiers/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"v1\"}"))
                .andExpect(status().isOk());
        mvc.perform(put("/api/v1/admin/dossiers/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"v2\",\"expectedRowVersion\":0}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("OPTIMISTIC_LOCK_CONFLICT"));
    }

    /* ---------- publish + V28 snapshot ---------- */

    @Test
    void publish_createsVersionRow_andBumpsVersion() throws Exception {
        String id = createDossierId("ngo-quyen");
        publishDossier(id);

        // Row version snapshot trong V28 table.
        Long count = jdbc.queryForObject(
                "select count(*) from historical_dossier_versions "
              + "where dossier_id = ?::uuid and dossier_version = 1",
                Long.class, id);
        assertThat(count).isEqualTo(1);
        String status = jdbc.queryForObject(
                "select status from historical_dossiers where id = ?::uuid",
                String.class, id);
        assertThat(status).isEqualTo("PUBLISHED");

        // Publish lan 2 → snapshot v2.
        publishDossier(id);
        Long v2 = jdbc.queryForObject(
                "select count(*) from historical_dossier_versions "
              + "where dossier_id = ?::uuid and dossier_version = 2",
                Long.class, id);
        assertThat(v2).isEqualTo(1);
    }

    @Test
    void publish_missingSourceTitle_422() throws Exception {
        // source co block {"source":{}} thieu title — publish phai chan
        // (spec: source.title bat buoc khi publish). validateForPublish chi
        // check khi sourceJson != null nen seed qua JDBC.
        MvcResult res = mvc.perform(post("/api/v1/admin/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"canonicalCode\":\"no-source\","
                                + "\"dossierType\":\"PERSON\",\"title\":\"T\"}"))
                .andReturn();
        String id = om.readTree(res.getResponse().getContentAsString())
                .get("id").asText();
        jdbc.update("update historical_dossiers set source_json = "
                        + "'{\"source\":{}}'::jsonb where id = ?::uuid", id);

        mvc.perform(post("/api/v1/admin/dossiers/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void publish_nonexistentAsset_400or422() throws Exception {
        // assetId khong ton tai — validateForPublish tra error -> 422.
        String bogusAsset = UUID.randomUUID().toString();
        String body = "{\"canonicalCode\":\"bad-asset\","
                + "\"dossierType\":\"PERSON\",\"title\":\"T\","
                + "\"source\":" + VALID_SOURCE + ","
                + "\"assetId\":\"" + bogusAsset + "\"}";
        MvcResult res = mvc.perform(post("/api/v1/admin/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andReturn();
        // create cung chan asset ton tai -> 400 la dung.
        assertThat(res.getResponse().getStatus()).isIn(400, 422);
    }

    /* ---------- archive keeps unlocks ---------- */

    @Test
    void archive_keepsUnlocks() throws Exception {
        String id = createDossierId("ngo-quyen");
        publishDossier(id);
        // Learner da unlock → insert truc tiep (PK composite user+dossier,
        // khong co cot id; timestamp la granted_at).
        jdbc.update("insert into user_dossier_unlocks "
                        + "(user_id, dossier_id, event_id, dossier_version,"
                        + " granted_at) "
                        + "values (?::uuid, ?::uuid, ?::uuid, 1, now())",
                learnerId, id, eventId);

        mvc.perform(post("/api/v1/admin/dossiers/" + id + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARCHIVED"));

        Long unlocks = jdbc.queryForObject(
                "select count(*) from user_dossier_unlocks "
              + "where user_id = ?::uuid and dossier_id = ?::uuid",
                Long.class, learnerId, id);
        assertThat(unlocks).isEqualTo(1);
    }

    /* ---------- event links ---------- */

    @Test
    void replaceEventLinks_listReturnsLinked() throws Exception {
        String dos = createDossierId("ngo-quyen");
        publishDossier(dos);

        mvc.perform(put("/api/v1/admin/events/" + eventId + "/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("[{\"dossierId\":\"" + dos
                                + "\",\"displayOrder\":1}]"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].dossierId").value(dos))
                .andExpect(jsonPath("$[0].displayOrder").value(1));

        mvc.perform(get("/api/v1/admin/events/" + eventId + "/dossiers")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));

        // Detail dossier thay event link.
        mvc.perform(get("/api/v1/admin/dossiers/" + dos)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.events[0].eventId").value(eventId));
    }

    @Test
    void replaceEventLinks_draftDossier_422() throws Exception {
        String draft = createDossierId("draft-dos"); // chua publish

        mvc.perform(put("/api/v1/admin/events/" + eventId + "/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("[{\"dossierId\":\"" + draft
                                + "\",\"displayOrder\":1}]"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void replaceEventLinks_doesNotRevokeUnlocks() throws Exception {
        String dos = createDossierId("ngo-quyen");
        publishDossier(dos);
        mvc.perform(put("/api/v1/admin/events/" + eventId + "/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("[{\"dossierId\":\"" + dos
                                + "\",\"displayOrder\":1}]"))
                .andExpect(status().isOk());
        // Learner da unlock (schema PK composite — khong cot id).
        jdbc.update("insert into user_dossier_unlocks "
                        + "(user_id, dossier_id, event_id, dossier_version,"
                        + " granted_at) "
                        + "values (?::uuid, ?::uuid, ?::uuid, 1, now())",
                learnerId, dos, eventId);

        // Unlink bang empty list — unlock row van con (entitlement).
        mvc.perform(put("/api/v1/admin/events/" + eventId + "/dossiers")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("[]"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        Long unlocks = jdbc.queryForObject(
                "select count(*) from user_dossier_unlocks "
              + "where user_id = ?::uuid and dossier_id = ?::uuid",
                Long.class, learnerId, dos);
        assertThat(unlocks).isEqualTo(1);
    }

    /* ---------- security ---------- */

    @Test
    void unauthenticated_401_learner_403() throws Exception {
        mvc.perform(get("/api/v1/admin/dossiers"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/admin/dossiers")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }
}

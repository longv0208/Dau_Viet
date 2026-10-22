package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * TASK-0023 — ItemUnlockService: rule LESSON_COMPLETED / COLLECTION_COUNT /
 * LESSON_COUNT đánh giá trong transaction của complete()/submit, grant
 * once-per-(user,item) qua ON CONFLICT, không revoke khi rule đổi, catalog
 * trả owned + requirement + progress. Docker cần.
 */
@SpringBootTest
@AutoConfigureMockMvc
class ItemUnlockIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String learnerId;
    private String otherToken;
    private String otherId;
    private String eventId;
    private String tplId;
    private String ev1;
    private String ev2;

    private static final String MC_CONFIG =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"]}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from reward_transactions");
        jdbc.update("delete from user_inventory");
        jdbc.update("delete from item_unlock_rule");
        jdbc.update("delete from item_catalog");
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@it.vn",
                UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@it.vn",
                UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@it.vn",
                UserRole.LEARNER);
        learnerId = userIdByEmail("l@it.vn");
        otherId = userIdByEmail("o@it.vn");
        eventId = AttemptItFixture.newEvent(jdbc, "e-it");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-it");
        ev1 = AttemptItFixture.newEvidence(jdbc, eventId);
        ev2 = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private String userIdByEmail(String email) {
        return jdbc.queryForObject(
                "select id from users where email = ?", String.class, email);
    }

    /* ---------- helpers ---------- */

    private String publish(String draftJson) throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId,
                tplId, draftJson);
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

    private void complete(String token, String attemptId) throws Exception {
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", token))
                .andExpect(status().isOk());
    }

    /** MC-only draft (read+mc) — cho LESSON_COMPLETED / LESSON_COUNT. */
    private String draftMcOnly() {
        return AttemptItFixture.draftTwoStage(ev1, MC_CONFIG);
    }

    /** Draft có EVIDENCE_SELECT required — cho COLLECTION_COUNT. */
    private String draftEs() {
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

    private String newItem(String code, String itemType) {
        String id = UUID.randomUUID().toString();
        jdbc.update("""
                insert into item_catalog (id, code, name, category, item_type,
                                          rarity, active)
                values (?::uuid, ?, ?, 'HUY_HIEU', ?, 'COMMON', true)
                """, id, code, "Item " + code, itemType);
        return id;
    }

    private void newLessonCompletedRule(String itemId, String lessonId) {
        jdbc.update("""
                insert into item_unlock_rule (id, item_id, rule_type, lesson_id, active)
                values (?::uuid, ?::uuid, 'LESSON_COMPLETED', ?::uuid, true)
                """, UUID.randomUUID().toString(), itemId, lessonId);
    }

    private void newCountedRule(String itemId, String ruleType, int threshold) {
        jdbc.update("""
                insert into item_unlock_rule (id, item_id, rule_type, threshold, active)
                values (?::uuid, ?::uuid, ?, ?, true)
                """, UUID.randomUUID().toString(), itemId, ruleType, threshold);
    }

    private long inventoryCount(String where) {
        Long n = jdbc.queryForObject(
                "select count(*) from user_inventory where " + where,
                Long.class);
        return n == null ? 0 : n;
    }

    private String completeMcLesson(String token, String lessonId)
            throws Exception {
        String attemptId = AttemptItFixture.startAttempt(mvc, om, token,
                lessonId);
        submit(token, attemptId, "r1", "{}");
        submit(token, attemptId, "mc", "{\"selectedOptionIds\":[\"o1\"]}");
        complete(token, attemptId);
        return attemptId;
    }

    /* ---------- LESSON_COMPLETED ---------- */

    @Test
    void lessonCompletedRule_grantsItemOnComplete() throws Exception {
        String lessonId = publish(draftMcOnly());
        String itemId = newItem("HUY_HIEU_TEST", "COMMEMORATIVE_BADGE");
        newLessonCompletedRule(itemId, lessonId);

        String attemptId = completeMcLesson(learnerToken, lessonId);

        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "select acquisition_source from user_inventory "
              + "where user_id = ?::uuid and item_id = ?::uuid",
                String.class, learnerId, itemId))
                .isEqualTo("LESSON_COMPLETED");
        // source_attempt_id trỏ đúng attempt đã kích hoạt.
        assertThat(jdbc.queryForObject(
                "select source_attempt_id::text from user_inventory "
              + "where user_id = ?::uuid and item_id = ?::uuid",
                String.class, learnerId, itemId))
                .isEqualTo(attemptId);
    }

    @Test
    void lessonCompletedResult_enrichedWithItemsUnlocked() throws Exception {
        String lessonId = publish(draftMcOnly());
        String itemId = newItem("HUY_HIEU_ENRICH", "COMMEMORATIVE_BADGE");
        newLessonCompletedRule(itemId, lessonId);

        String attemptId = completeMcLesson(learnerToken, lessonId);

        MvcResult res = mvc.perform(get(
                        "/api/v1/attempts/" + attemptId + "/result")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.itemsUnlocked.length()").value(1))
                .andReturn();
        JsonNode items = AttemptItFixture.body(om, res).get("itemsUnlocked");
        assertThat(items.get(0).get("itemId").asText()).isEqualTo(itemId);
        assertThat(items.get(0).get("code").asText())
                .isEqualTo("HUY_HIEU_ENRICH");
    }

    /* ---------- once-per-user, per-learner ---------- */

    @Test
    void itemGrantedOnce_neverDuplicatedOrRevoked() throws Exception {
        String lessonId = publish(draftMcOnly());
        String itemId = newItem("HUY_HIEU_ONCE", "COMMEMORATIVE_BADGE");
        newLessonCompletedRule(itemId, lessonId);

        completeMcLesson(learnerToken, lessonId);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);

        // Hoàn thành lần hai (attempt mới) — vẫn 1 row.
        completeMcLesson(learnerToken, lessonId);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);

        // Admin đổi rule (deactivate) — vật phẩm đã cấp không bị thu hồi.
        jdbc.update("update item_unlock_rule set active = false "
                  + "where item_id = ?::uuid", itemId);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    @Test
    void inventory_scopedPerLearner() throws Exception {
        String lessonId = publish(draftMcOnly());
        String itemId = newItem("HUY_HIEU_SCOPE", "COMMEMORATIVE_BADGE");
        newLessonCompletedRule(itemId, lessonId);

        completeMcLesson(learnerToken, lessonId);

        // Learner khác: inventory + catalog đều không có item này.
        mvc.perform(get("/api/v1/me/inventory")
                        .header("Authorization", otherToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isEmpty());
        assertThat(inventoryCount(
                "user_id = '" + otherId + "' and item_id = '" + itemId + "'"))
                .isZero();
    }

    /* ---------- COLLECTION_COUNT ---------- */

    @Test
    void collectionCountRule_grantsAtThreshold() throws Exception {
        String lessonId = publish(draftEs());
        // Threshold = 2 evidence — submit chọn đủ 2 mới mở.
        String itemId = newItem("PHIEN_BAN_CC", "DIGITAL_EDITION");
        newCountedRule(itemId, "COLLECTION_COUNT", 2);

        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken,
                lessonId);
        // Chọn 1 evidence — chưa đủ ngưỡng, chưa cấp.
        submit(learnerToken, attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\"]}");
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();

        // Submit bổ sung evidence thứ hai — đạt ngưỡng, cấp trong tx.
        submit(learnerToken, attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "select acquisition_source from user_inventory "
              + "where user_id = ?::uuid and item_id = ?::uuid",
                String.class, learnerId, itemId))
                .isEqualTo("COLLECTION_COUNT");
    }

    /* ---------- LESSON_COUNT ---------- */

    @Test
    void lessonCountRule_grantsAfterNthLesson() throws Exception {
        // Hai bài khác nhau; rule yêu cầu 2 bài → mở sau bài thứ hai.
        String lessonA = publish(draftMcOnly());
        String lessonB = publish(draftMcOnly());
        String itemId = newItem("HUY_HIEU_LC", "COMMEMORATIVE_BADGE");
        newCountedRule(itemId, "LESSON_COUNT", 2);

        completeMcLesson(learnerToken, lessonA);
        // Chỉ 1 bài — chưa đủ.
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();

        String second = completeMcLesson(learnerToken, lessonB);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
        // Attempt thứ hai là nguồn kích hoạt.
        assertThat(jdbc.queryForObject(
                "select source_attempt_id::text from user_inventory "
              + "where user_id = ?::uuid and item_id = ?::uuid",
                String.class, learnerId, itemId))
                .isEqualTo(second);
    }

    /* ---------- catalog read ---------- */

    @Test
    void catalog_returnsOwnedPlusRequirementProgress() throws Exception {
        String lessonId = publish(draftMcOnly());
        String ownedItem = newItem("HUY_HIEU_OWNED", "COMMEMORATIVE_BADGE");
        newLessonCompletedRule(ownedItem, lessonId);
        String lockedItem = newItem("PHIEN_BAN_LOCKED", "DIGITAL_EDITION");
        newCountedRule(lockedItem, "COLLECTION_COUNT", 5);

        completeMcLesson(learnerToken, lessonId);

        MvcResult res = mvc.perform(get("/api/v1/me/inventory/catalog")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode items = AttemptItFixture.body(om, res);
        assertThat(items).hasSize(2);
        Map<String, JsonNode> byCode = new java.util.HashMap<>();
        for (JsonNode i : items) byCode.put(i.get("code").asText(), i);

        JsonNode owned = byCode.get("HUY_HIEU_OWNED");
        assertThat(owned.get("owned").asBoolean()).isTrue();
        assertThat(owned.get("requirement").get("type").asText())
                .isEqualTo("LESSON_COMPLETED");
        assertThat(owned.get("acquiredAt").asText()).isNotBlank();

        JsonNode locked = byCode.get("PHIEN_BAN_LOCKED");
        assertThat(locked.get("owned").asBoolean()).isFalse();
        JsonNode req = locked.get("requirement");
        assertThat(req.get("type").asText()).isEqualTo("COLLECTION_COUNT");
        assertThat(req.get("threshold").asInt()).isEqualTo(5);
        // Learner chưa collect evidence nào → current = 0.
        assertThat(req.get("current").asLong()).isZero();
    }

    /* ---------- P1-A: item disabled vẫn hiển thị nếu đã sở hữu ---------- */

    @Test
    void disabledItem_stillVisibleWhenOwned_hiddenWhenNot() throws Exception {
        String lessonId = publish(draftMcOnly());
        String itemId = newItem("HUY_HIEU_DISABLED", "COMMEMORATIVE_BADGE");
        newLessonCompletedRule(itemId, lessonId);
        completeMcLesson(learnerToken, lessonId);

        // Admin tắt item.
        jdbc.update("update item_catalog set active = false "
                  + "where id = ?::uuid", itemId);

        // Learner đã sở hữu → vẫn thấy trong catalog (owned) + inventory.
        MvcResult cat = mvc.perform(get("/api/v1/me/inventory/catalog")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        JsonNode items = AttemptItFixture.body(om, cat);
        JsonNode owned = null;
        for (JsonNode i : items) {
            if (itemId.equals(i.get("itemId").asText())) owned = i;
        }
        assertThat(owned).isNotNull();
        assertThat(owned.get("owned").asBoolean()).isTrue();
        mvc.perform(get("/api/v1/me/inventory")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].itemId").value(itemId));

        // Learner khác chưa sở hữu → item biến mất khỏi catalog.
        MvcResult otherCat = mvc.perform(get("/api/v1/me/inventory/catalog")
                        .header("Authorization", otherToken))
                .andExpect(status().isOk()).andReturn();
        for (JsonNode i : AttemptItFixture.body(om, otherCat)) {
            assertThat(i.get("itemId").asText()).isNotEqualTo(itemId);
        }
        // Inventory row của learner không đổi.
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    @Test
    void disabledItem_cannotBeNewlyGranted() throws Exception {
        String lessonId = publish(draftMcOnly());
        String itemId = newItem("HUY_HIEU_NOGRANT", "COMMEMORATIVE_BADGE");
        newLessonCompletedRule(itemId, lessonId);
        // Disable trước khi learner hoàn thành.
        jdbc.update("update item_catalog set active = false "
                  + "where id = ?::uuid", itemId);

        completeMcLesson(learnerToken, lessonId);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isZero();
    }

    /* ---------- P1-B: sửa metadata không xoá asset/source ---------- */

    @Test
    void metadataEdit_preservesAssetAndSource() throws Exception {
        // Tạo item có assetId + sourceMetadata qua SQL.
        String itemId = UUID.randomUUID().toString();
        String assetId = UUID.randomUUID().toString();
        jdbc.update("""
                insert into assets (id, storage_key, mime_type, size_bytes, state)
                values (?::uuid, ?, 'image/png', 1, 'ACTIVE')
                """, assetId, "k-" + assetId);
        jdbc.update("""
                insert into item_catalog (id, code, name, category, item_type,
                                          rarity, asset_id, source_metadata, active)
                values (?::uuid, 'HUY_HIEU_META', 'N', 'HUY_HIEU',
                        'COMMEMORATIVE_BADGE', 'RARE', ?::uuid,
                        '{"note":"hiện vật thật"}'::jsonb, true)
                """, itemId, assetId);

        // Chỉ đổi tên — assetId/sourceMetadata không gửi.
        mvc.perform(put("/api/v1/admin/items/" + itemId)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"HUY_HIEU_META\","
                                + "\"name\":\"Tên mới\","
                                + "\"category\":\"HUY_HIEU\","
                                + "\"itemType\":\"COMMEMORATIVE_BADGE\"}"))
                .andExpect(status().isOk());

        // assetId + sourceMetadata giữ nguyên.
        assertThat(jdbc.queryForObject(
                "select asset_id::text from item_catalog where id = ?::uuid",
                String.class, itemId)).isEqualTo(assetId);
        assertThat(jdbc.queryForObject(
                "select source_metadata->>'note' from item_catalog where id = ?::uuid",
                String.class, itemId)).isEqualTo("hiện vật thật");
    }

    /* ---------- P1-C: thay rule active an toàn ---------- */

    @Test
    void replaceActiveRule_oldDeactivated_newActiveExactlyOne()
            throws Exception {
        String itemId = newItem("PHIEN_BAN_RULE", "DIGITAL_EDITION");
        newCountedRule(itemId, "COLLECTION_COUNT", 3);

        // Thay bằng LESSON_COUNT threshold 2.
        mvc.perform(put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"LESSON_COUNT\",\"threshold\":2,"
                                + "\"active\":true}"))
                .andExpect(status().isOk());

        Long active = jdbc.queryForObject(
                "select count(*) from item_unlock_rule "
              + "where item_id = ?::uuid and active = true",
                Long.class, itemId);
        assertThat(active).isEqualTo(1);
        // Rule cũ vẫn còn (inactive) — append-only.
        Long total = jdbc.queryForObject(
                "select count(*) from item_unlock_rule "
              + "where item_id = ?::uuid", Long.class, itemId);
        assertThat(total).isEqualTo(2);

        // Thay tiếp bằng LESSON_COMPLETED trỏ bài đã publish.
        String lessonId = publish(draftMcOnly());
        mvc.perform(put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"LESSON_COMPLETED\","
                                + "\"lessonId\":\"" + lessonId + "\"}"))
                .andExpect(status().isOk());
        active = jdbc.queryForObject(
                "select count(*) from item_unlock_rule "
              + "where item_id = ?::uuid and active = true",
                Long.class, itemId);
        assertThat(active).isEqualTo(1);

        // Hoàn thành bài → item mở qua rule mới.
        completeMcLesson(learnerToken, lessonId);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }

    @Test
    void ruleRejected_forMissingOrUnpublishedLesson() throws Exception {
        String itemId = newItem("PHIEN_BAN_BADLESSON", "DIGITAL_EDITION");
        // LessonId không tồn tại.
        mvc.perform(put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"LESSON_COMPLETED\","
                                + "\"lessonId\":\""
                                + UUID.randomUUID() + "\"}"))
                .andExpect(status().isBadRequest());
    }

    /* ---------- P2-A: summary đếm distinct lessons ---------- */
    // (đặt trong RewardGrantIT vì liên quan reward summary)

    @Test
    void adminItemCrud_andRuleConfig() throws Exception {
        // Tạo item qua admin API.
        MvcResult created = mvc.perform(post("/api/v1/admin/items")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"MO_HINH_ADMIN\",\"name\":\"Mô hình "
                                + "admin\",\"category\":\"MO_HINH\","
                                + "\"itemType\":\"HISTORICAL_REPLICA\","
                                + "\"rarity\":\"RARE\",\"active\":true}"))
                .andExpect(status().isCreated())
                .andReturn();
        String itemId = AttemptItFixture.body(om, created).get("id").asText();

        // Gán rule LESSON_COUNT threshold 1.
        mvc.perform(put("/api/v1/admin/items/" + itemId + "/rule")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ruleType\":\"LESSON_COUNT\",\"threshold\":1,"
                                + "\"active\":true}"))
                .andExpect(status().isOk());

        // Hoàn thành 1 bài → mở vật phẩm.
        String lessonId = publish(draftMcOnly());
        completeMcLesson(learnerToken, lessonId);
        assertThat(inventoryCount(
                "user_id = '" + learnerId + "' and item_id = '" + itemId + "'"))
                .isEqualTo(1);
    }
}

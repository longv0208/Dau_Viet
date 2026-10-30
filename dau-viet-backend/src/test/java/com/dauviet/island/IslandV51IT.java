package com.dauviet.island;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
 * V51 — Đảo Di Sản 3 cấp 12/28/56 + đặt nhiều bản sao + upgrade xoá placement.
 * Docker cần.
 */
@SpringBootTest
@AutoConfigureMockMvc
class IslandV51IT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String learnerToken;
    private String learnerId;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();
        learnerToken = token("is51@c.vn");
        learnerId = userIdByEmail("is51@c.vn");
    }

    /* ---------- helpers ---------- */

    private String token(String email) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail(email);
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(UserRole.LEARNER);
        u.setStatus(UserStatus.ACTIVE);
        users.save(u);
        return "Bearer " + jwt.createAccessToken(u);
    }

    private String userIdByEmail(String email) {
        return jdbc.queryForObject(
                "select id from users where email = ?", String.class, email);
    }

    /** Grant item vào inventory (không qua shop). */
    private void grantItem(String itemCode) {
        String itemId = jdbc.queryForObject(
                "select id from item_catalog where code = ?", String.class, itemCode);
        jdbc.update("""
                insert into user_inventory (id, user_id, item_id, acquired_at, acquisition_source)
                values (gen_random_uuid(), ?::uuid, ?::uuid, now(), 'ADMIN_GRANT')
                on conflict do nothing
                """, learnerId, itemId);
    }

    /** Lấy slotId đầu tiên còn trống ở tier hiện tại của island response. */
    private String firstEmptySlotId(JsonNode island) {
        for (JsonNode s : island.get("slots")) {
            if (s.get("unlocked").asBoolean()
                    && !s.hasNonNull("placedItemId")) {
                return s.get("slotId").asText();
            }
        }
        return null;
    }

    private JsonNode getIsland() throws Exception {
        MvcResult r = mvc.perform(get("/api/v1/me/island")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andReturn();
        return om.readTree(r.getResponse().getContentAsString());
    }

    private JsonNode place(String slotId, String itemId, long revision)
            throws Exception {
        MvcResult r = mvc.perform(put("/api/v1/me/island/placements/" + slotId)
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(Map.of(
                                "itemId", itemId,
                                "expectedRevision", revision))))
                .andExpect(status().isOk())
                .andReturn();
        return om.readTree(r.getResponse().getContentAsString());
    }

    /* ---------- tests ---------- */

    /** AC-3: đặt cùng 1 item lên 2 slot khác nhau — không còn ITEM_ALREADY_OWNED. */
    @Test
    void place_same_item_on_two_slots_allowed() throws Exception {
        grantItem("DECOR_CAY_DA");
        String itemId = jdbc.queryForObject(
                "select id from item_catalog where code = 'DECOR_CAY_DA'",
                String.class);

        JsonNode island = getIsland();
        assertThat(island.get("tier").asInt()).isEqualTo(1);
        // V59: 64 slot buildable (lưới 8x8 đồng tâm: T1=16, T2=36, T3=64)
        assertThat(island.get("slots").size()).isEqualTo(64);
        // Lấy 2 slot trống
        List<String> emptyIds = island.get("slots").findValues("slotId").stream()
                .map(JsonNode::asText)
                .filter(id -> {
                    for (JsonNode s : island.get("slots")) {
                        if (s.get("slotId").asText().equals(id)
                                && s.get("unlocked").asBoolean()
                                && !s.hasNonNull("placedItemId")) {
                            return true;
                        }
                    }
                    return false;
                })
                .limit(2)
                .toList();
        assertThat(emptyIds).hasSize(2);

        // Đặt lần 1
        JsonNode r1 = place(emptyIds.get(0), itemId, island.get("rowVersion").asLong());
        assertThat(r1.get("rowVersion").asLong())
                .isGreaterThan(island.get("rowVersion").asLong());

        // Đặt lần 2 — cùng item lên slot khác phải OK (V51)
        JsonNode r2 = place(emptyIds.get(1), itemId, r1.get("rowVersion").asLong());
        long placed = r2.get("slots").findParents("placedItemId").stream()
                .filter(s -> s.hasNonNull("placedItemId")).count();
        assertThat(placed).isEqualTo(2);
    }

    /** AC-1: tiers[] metadata trả về 3 cấp đảo Đảo An Lạc (16) / Đảo Phồn Thịnh (36) / Đảo Trường Tồn (64). */
    @Test
    void island_response_has_three_tier_metadata() throws Exception {
        JsonNode island = getIsland();
        JsonNode tiers = island.get("tiers");
        assertThat(tiers).isNotNull();
        assertThat(tiers.size()).isEqualTo(3);
        assertThat(tiers.get(0).get("slotCount").asInt()).isEqualTo(16);
        assertThat(tiers.get(1).get("slotCount").asInt()).isEqualTo(36);
        assertThat(tiers.get(2).get("slotCount").asInt()).isEqualTo(64);
        assertThat(tiers.get(0).get("stageLabel").asText()).isEqualTo("Đảo An Lạc");
        assertThat(tiers.get(1).get("stageLabel").asText()).isEqualTo("Đảo Phồn Thịnh");
        assertThat(tiers.get(2).get("stageLabel").asText()).isEqualTo("Đảo Trường Tồn");
        assertThat(tiers.get(0).get("unlocked").asBoolean()).isTrue();
        assertThat(tiers.get(1).get("unlocked").asBoolean()).isFalse();
        assertThat(tiers.get(2).get("unlocked").asBoolean()).isFalse();
    }

    /** AC-3 + upgrade: upgrade xoá sạch placements — item "về kho" qua inventory. */
    @Test
    void upgrade_clears_placements_and_repins_layout() throws Exception {
        grantItem("DECOR_CAY_DA");
        String itemId = jdbc.queryForObject(
                "select id from item_catalog where code = 'DECOR_CAY_DA'",
                String.class);

        // Đặt 1 item
        JsonNode island = getIsland();
        String slotId = firstEmptySlotId(island);
        place(slotId, itemId, island.get("rowVersion").asLong());

        // Kiểm tra placement tồn tại
        Integer placed = jdbc.queryForObject(
                "select count(*) from user_island_placements where user_id = ?::uuid",
                Integer.class, learnerId);
        assertThat(placed).isEqualTo(1);

        // Đủ Level 2 (>=500 EXP): grant EXP qua reward_transactions
        jdbc.update("""
                insert into reward_transactions (id, user_id, reward_type, amount, reason, cause_key)
                values (gen_random_uuid(), ?::uuid, 'EXP', 600, 'test', 'test-exp-1')
                """, learnerId);

        // Upgrade
        JsonNode latest = getIsland();
        mvc.perform(post("/api/v1/me/island/upgrade")
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(Map.of(
                                "expectedRevision", latest.get("rowVersion").asLong()))))
                .andExpect(status().isOk());

        // Placements đã bị xoá — item về kho
        Integer after = jdbc.queryForObject(
                "select count(*) from user_island_placements where user_id = ?::uuid",
                Integer.class, learnerId);
        assertThat(after).isEqualTo(0);

        // Inventory vẫn giữ item (không mất)
        Integer owned = jdbc.queryForObject(
                "select count(*) from user_inventory where user_id = ?::uuid and item_id = ?::uuid",
                Integer.class, learnerId, itemId);
        assertThat(owned).isEqualTo(1);

        // Island mới: tier=2, 36 slot unlock (6x6), layout_version mới
        JsonNode upgraded = getIsland();
        assertThat(upgraded.get("tier").asInt()).isEqualTo(2);
        long unlockedCount = upgraded.get("slots").findParents("unlocked").stream()
                .filter(s -> s.get("unlocked").asBoolean()).count();
        assertThat(unlockedCount).isEqualTo(36);
    }
}

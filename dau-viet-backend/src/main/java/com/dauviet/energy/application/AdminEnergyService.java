package com.dauviet.energy.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.energy.api.dto.AdminEnergyDtos.AdminEnergyRemedyResponse;
import com.dauviet.energy.api.dto.AdminEnergyDtos.AdminEnergySettingsResponse;
import com.dauviet.energy.api.dto.AdminEnergyDtos.CreateEnergyRemedyRequest;
import com.dauviet.energy.api.dto.AdminEnergyDtos.PatchEnergyRemedyRequest;
import com.dauviet.energy.api.dto.AdminEnergyDtos.UpdateEnergyRemedyRequest;
import com.dauviet.energy.api.dto.AdminEnergyDtos.UpdateEnergySettingsRequest;
import com.dauviet.energy.domain.EnergyPolicySetting;
import com.dauviet.energy.domain.EnergyRemedy;
import com.dauviet.energy.infrastructure.persistence.EnergyPolicySettingRepository;
import com.dauviet.energy.infrastructure.persistence.EnergyRemedyRepository;

/**
 * Admin API quản lý Viện Thái Y (GAME-07 Issue #28):
 * - PUT/GET /api/v1/admin/energy/settings — quy tắc Thể lực toàn cục.
 * - CRUD /api/v1/admin/energy/remedies — danh mục vật phẩm Viện Thái Y.
 *
 * <p>Runtime EnergyService đọc DB mỗi request nên thay đổi admin có hiệu
 * lực ngay — không cần publish hay restart.
 */
@Service
public class AdminEnergyService {

    private static final Logger log =
            LoggerFactory.getLogger(AdminEnergyService.class);

    private final EnergyPolicySettingRepository policies;
    private final EnergyRemedyRepository remedies;
    private final Clock clock;

    public AdminEnergyService(EnergyPolicySettingRepository policies,
                              EnergyRemedyRepository remedies,
                              Clock clock) {
        this.policies = policies;
        this.remedies = remedies;
        this.clock = clock;
    }

    /* ---------- Settings ---------- */

    @Transactional(readOnly = true)
    public AdminEnergySettingsResponse getSettings() {
        return policies.findSingleton()
                .map(this::toSettingsResponse)
                .orElseThrow(() -> new IllegalStateException(
                        "energy_policy_settings singleton missing — "
                                + "V49 migration not applied"));
    }

    @Transactional(propagation = Propagation.REQUIRED)
    public AdminEnergySettingsResponse updateSettings(
            UpdateEnergySettingsRequest req, UUID adminUserId) {
        Instant now = Instant.now(clock);
        // Lazy-create singleton nếu chưa có (idempotent — V49 seed chạy
        // trước nên chủ yếu cho unit test không Flyway).
        policies.insertIgnore(req.enabled(), req.maxEnergy(),
                req.incorrectPenalty(), req.recoveryAmount(),
                req.recoveryIntervalSeconds(), adminUserId);
        EnergyPolicySetting s = policies.findSingleton()
                .orElseThrow(() -> new IllegalStateException(
                        "energy_policy_settings insert lost"));
        s.apply(req.enabled(), req.maxEnergy(), req.incorrectPenalty(),
                req.recoveryAmount(), req.recoveryIntervalSeconds(),
                now, adminUserId);
        EnergyPolicySetting saved = policies.save(s);
        log.info("energy policy updated by={} enabled={} max={} penalty={} "
                + "recovery={}/{}s", adminUserId, req.enabled(),
                req.maxEnergy(), req.incorrectPenalty(),
                req.recoveryAmount(), req.recoveryIntervalSeconds());
        return toSettingsResponse(saved);
    }

    private AdminEnergySettingsResponse toSettingsResponse(
            EnergyPolicySetting s) {
        return new AdminEnergySettingsResponse(
                s.isEnabled(), s.getMaxEnergy(), s.getIncorrectPenalty(),
                s.getRecoveryAmount(), s.getRecoveryIntervalSeconds(),
                s.getUpdatedAt(), s.getUpdatedBy(), s.getRowVersion());
    }

    /* ---------- Remedies ---------- */

    @Transactional(readOnly = true)
    public List<AdminEnergyRemedyResponse> listRemedies() {
        return remedies.findAllOrdered().stream()
                .map(this::toRemedyResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public AdminEnergyRemedyResponse getRemedy(UUID id) {
        return remedies.findById(id)
                .map(this::toRemedyResponse)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "energy remedy not found: " + id));
    }

    @Transactional(propagation = Propagation.REQUIRED)
    public AdminEnergyRemedyResponse createRemedy(
            CreateEnergyRemedyRequest req) {
        String code = normalizeCode(req.code());
        if (remedies.existsByCodeIgnoreCase(code)) {
            throw new IllegalArgumentException(
                    "remedy code already exists: " + code);
        }
        Instant now = Instant.now(clock);
        EnergyRemedy r = EnergyRemedy.create(
                UUID.randomUUID(), code,
                req.title().trim(),
                req.description().trim(),
                normalizeRarity(req.rarity()),
                req.iconKey().trim(),
                req.assetId(),
                req.energyGain(),
                req.pointsCost(),
                req.cooldownSeconds(),
                req.active() == null || req.active(),
                req.sortOrder() == null ? 0 : req.sortOrder(),
                now);
        EnergyRemedy saved = remedies.save(r);
        log.info("energy remedy created id={} code={} gain={} cost={}",
                saved.getId(), saved.getCode(), saved.getEnergyGain(),
                saved.getPointsCost());
        return toRemedyResponse(saved);
    }

    @Transactional(propagation = Propagation.REQUIRED)
    public AdminEnergyRemedyResponse updateRemedy(
            UUID id, UpdateEnergyRemedyRequest req) {
        EnergyRemedy r = remedies.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "energy remedy not found: " + id));
        Instant now = Instant.now(clock);
        r.apply(
                req.title().trim(),
                req.description().trim(),
                normalizeRarity(req.rarity()),
                req.iconKey().trim(),
                req.assetId(),
                req.energyGain(),
                req.pointsCost(),
                req.cooldownSeconds(),
                req.active(),
                req.sortOrder(),
                now);
        EnergyRemedy saved = remedies.save(r);
        log.info("energy remedy updated id={} code={} gain={} cost={} "
                + "active={}", id, saved.getCode(), saved.getEnergyGain(),
                saved.getPointsCost(), saved.isActive());
        return toRemedyResponse(saved);
    }

    @Transactional(propagation = Propagation.REQUIRED)
    public AdminEnergyRemedyResponse patchRemedy(
            UUID id, PatchEnergyRemedyRequest req) {
        EnergyRemedy r = remedies.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "energy remedy not found: " + id));
        Instant now = Instant.now(clock);
        // Merge: chỉ trường non-null được cập nhật; null = giữ nguyên.
        r.apply(
                req.title() != null ? req.title().trim() : r.getTitle(),
                req.description() != null
                        ? req.description().trim() : r.getDescription(),
                req.rarity() != null
                        ? normalizeRarity(req.rarity()) : r.getRarity(),
                req.iconKey() != null
                        ? req.iconKey().trim() : r.getIconKey(),
                req.assetId() != null ? req.assetId() : r.getAssetId(),
                req.energyGain() != null
                        ? req.energyGain() : r.getEnergyGain(),
                req.pointsCost() != null
                        ? req.pointsCost() : r.getPointsCost(),
                req.cooldownSeconds() != null
                        ? req.cooldownSeconds() : r.getCooldownSeconds(),
                req.active() != null ? req.active() : r.isActive(),
                req.sortOrder() != null
                        ? req.sortOrder() : r.getSortOrder(),
                now);
        EnergyRemedy saved = remedies.save(r);
        log.info("energy remedy patched id={} code={} active={}",
                id, saved.getCode(), saved.isActive());
        return toRemedyResponse(saved);
    }

    @Transactional(propagation = Propagation.REQUIRED)
    public void deleteRemedy(UUID id) {
        EnergyRemedy r = remedies.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "energy remedy not found: " + id));
        remedies.delete(r);
        log.info("energy remedy deleted id={} code={}", id, r.getCode());
    }

    /* ---------- internals ---------- */

    private String normalizeCode(String raw) {
        return raw == null ? "" : raw.trim()
                .toUpperCase(Locale.ROOT);
    }

    private String normalizeRarity(String raw) {
        String rarity = raw == null ? "" : raw.trim()
                .toUpperCase(Locale.ROOT);
        return switch (rarity) {
            case EnergyRemedy.RARITY_COMMON, EnergyRemedy.RARITY_UNCOMMON,
                 EnergyRemedy.RARITY_RARE, EnergyRemedy.RARITY_EPIC -> rarity;
            default -> throw new IllegalArgumentException(
                    "rarity must be COMMON|UNCOMMON|RARE|EPIC, got: " + raw);
        };
    }

    private AdminEnergyRemedyResponse toRemedyResponse(EnergyRemedy r) {
        return new AdminEnergyRemedyResponse(
                r.getId(), r.getCode(), r.getTitle(), r.getDescription(),
                r.getRarity(), r.getIconKey(), r.getAssetId(),
                r.getEnergyGain(), r.getPointsCost(), r.getCooldownSeconds(),
                r.isActive(), r.getSortOrder(), r.getCreatedAt(),
                r.getUpdatedAt(), r.getRowVersion());
    }
}

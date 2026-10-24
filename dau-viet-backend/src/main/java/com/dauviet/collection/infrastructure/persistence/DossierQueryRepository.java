package com.dauviet.collection.infrastructure.persistence;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

/**
 * Query-side cho dossier (GAME-04 §11). JPA động cho list + detail: visible
 * = status='PUBLISHED' OR (status='ARCHIVED' AND learner đã unlock). DRAFT
 * invisible tuyệt đối. Sort ổn định theo (title, id) để phân trang
 * deterministic. Giữ trong infrastructure — service không ghép SQL.
 */
@Repository
public class DossierQueryRepository {

    @PersistenceContext
    private EntityManager em;

    /** Row dossier + unlock metadata của learner (null khi chưa mở). */
    public record Row(
            UUID id,
            String canonicalCode,
            String dossierType,
            String title,
            String summary,
            String description,
            String sourceJson,
            UUID assetId,
            String status,
            Integer dossierVersion,
            UUID unlockEventId,
            java.time.Instant grantedAt) {
    }

    /**
     * List dossiers learner thấy được. `unlockedOnly` = chỉ mục đã mở;
     * `lockedOnly` = chỉ preview chưa mở. eventId lọc qua event_dossiers.
     */
    @Transactional(readOnly = true)
    public List<Row> list(UUID userId, String type, UUID eventId,
                          Boolean unlocked, Pageable pageable) {
        StringBuilder sql = new StringBuilder("""
                SELECT d.id, d.canonical_code, d.dossier_type, d.title,
                       d.summary, d.description, d.source_json, d.asset_id,
                       d.status, d.dossier_version, u.event_id, u.granted_at
                FROM historical_dossiers d
                LEFT JOIN user_dossier_unlocks u
                  ON u.dossier_id = d.id AND u.user_id = :userId
                WHERE (d.status = 'PUBLISHED' OR u.dossier_id IS NOT NULL)
                """);
        if (type != null) {
            sql.append(" AND d.dossier_type = :type");
        }
        if (eventId != null) {
            sql.append("""
                     AND EXISTS (SELECT 1 FROM event_dossiers ed
                                 WHERE ed.dossier_id = d.id
                                   AND ed.event_id = :eventId)""");
        }
        if (Boolean.TRUE.equals(unlocked)) {
            sql.append(" AND u.dossier_id IS NOT NULL");
        } else if (Boolean.FALSE.equals(unlocked)) {
            sql.append(" AND u.dossier_id IS NULL");
        }
        sql.append(" ORDER BY d.title ASC, d.id ASC");

        var q = em.createNativeQuery(sql.toString())
                .setParameter("userId", userId)
                .setFirstResult((int) pageable.getOffset())
                .setMaxResults(pageable.getPageSize());
        if (type != null) q.setParameter("type", type);
        if (eventId != null) q.setParameter("eventId", eventId);
        return mapRows(q.getResultList());
    }

    /** Đếm tổng của cùng visible set — phân trang PageResponse. */
    @Transactional(readOnly = true)
    public long count(UUID userId, String type, UUID eventId, Boolean unlocked) {
        StringBuilder sql = new StringBuilder("""
                SELECT count(*) FROM historical_dossiers d
                LEFT JOIN user_dossier_unlocks u
                  ON u.dossier_id = d.id AND u.user_id = :userId
                WHERE (d.status = 'PUBLISHED' OR u.dossier_id IS NOT NULL)
                """);
        if (type != null) {
            sql.append(" AND d.dossier_type = :type");
        }
        if (eventId != null) {
            sql.append("""
                     AND EXISTS (SELECT 1 FROM event_dossiers ed
                                 WHERE ed.dossier_id = d.id
                                   AND ed.event_id = :eventId)""");
        }
        if (Boolean.TRUE.equals(unlocked)) {
            sql.append(" AND u.dossier_id IS NOT NULL");
        } else if (Boolean.FALSE.equals(unlocked)) {
            sql.append(" AND u.dossier_id IS NULL");
        }
        var q = em.createNativeQuery(sql.toString())
                .setParameter("userId", userId);
        if (type != null) q.setParameter("type", type);
        if (eventId != null) q.setParameter("eventId", eventId);
        return ((Number) q.getSingleResult()).longValue();
    }

    /** Một dossier + unlock của learner; null nếu không tồn tại/DRAFT. */
    @Transactional(readOnly = true)
    public Row detail(UUID userId, UUID dossierId) {
        var rows = em.createNativeQuery("""
                SELECT d.id, d.canonical_code, d.dossier_type, d.title,
                       d.summary, d.description, d.source_json, d.asset_id,
                       d.status, d.dossier_version, u.event_id, u.granted_at
                FROM historical_dossiers d
                LEFT JOIN user_dossier_unlocks u
                  ON u.dossier_id = d.id AND u.user_id = :userId
                WHERE d.id = :dossierId
                """)
                .setParameter("userId", userId)
                .setParameter("dossierId", dossierId)
                .getResultList();
        return rows.isEmpty() ? null : mapRow((Object[]) rows.get(0));
    }

    /** eventIds của một tập dossier — batch cho list/detail. */
    @Transactional(readOnly = true)
    public Map<UUID, List<UUID>> eventIdsOf(java.util.Set<UUID> dossierIds) {
        if (dossierIds.isEmpty()) {
            return Map.of();
        }
        var rows = em.createNativeQuery("""
                SELECT dossier_id, event_id FROM event_dossiers
                WHERE dossier_id IN (:ids)
                ORDER BY event_id
                """)
                .setParameter("ids", dossierIds)
                .getResultList();
        Map<UUID, List<UUID>> out = new java.util.HashMap<>();
        for (Object o : rows) {
            Object[] r = (Object[]) o;
            out.computeIfAbsent((UUID) r[0], k -> new java.util.ArrayList<>())
               .add((UUID) r[1]);
        }
        return out;
    }

    private List<Row> mapRows(List<?> raw) {
        return raw.stream().map(o -> mapRow((Object[]) o)).toList();
    }

    private Row mapRow(Object[] r) {
        return new Row(
                (UUID) r[0], (String) r[1], (String) r[2], (String) r[3],
                (String) r[4], (String) r[5], (String) r[6], (UUID) r[7],
                (String) r[8], (Integer) r[9], (UUID) r[10],
                toInstant(r[11]));
    }

    private static java.time.Instant toInstant(Object ts) {
        if (ts == null) return null;
        if (ts instanceof java.sql.Timestamp t) return t.toInstant();
        if (ts instanceof java.time.Instant i) return i;
        return null;
    }
}

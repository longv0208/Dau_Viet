package com.dauviet.historicalevent.infrastructure.seed;

import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.animation.domain.AnimationScene;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneRepository;
import com.dauviet.historicalevent.domain.HistoricalEvent;

/**
 * FIX-01 — local-only link between a seeded historical event and the
 * production animation scene that V17 inserted with event_id NULL
 * (EventSeedRunner is an ApplicationRunner → runs AFTER Flyway, so the
 * migration cannot reference the event row on a clean local DB; its
 * trailing UPDATE only helps databases where the event already existed
 * at migrate-time).
 *
 * Contract: fills event_id only while the scene still looks like the
 * untouched V17 seed row (eventId NULL AND updatedBy = the seed's
 * sys_user). Any admin link/unlink (SceneUpdateRequest.eventId /
 * clearEvent) bumps updatedBy to the admin id and is never overwritten.
 * Idempotent, never touches published animation_scene_versions, never
 * creates scenes. Runs only under profile=local + app.seed.enabled —
 * production has no automatic linking of unapproved content; admins
 * link via the scene editor.
 */
@Service
public class AnimationSceneEventLinker {

    private static final Logger log = LoggerFactory.getLogger(AnimationSceneEventLinker.class);

    /** The only seed scene ids we know how to post-link — V17 Bạch Đằng production scene. */
    private static final UUID BACH_DANG_PROD_SCENE_ID =
            UUID.fromString("d7a80000-0000-4000-8000-000000000001");

    /** sys_user UUID used by V15–V17 seeds — proves the row is still the untouched seed row. */
    private static final UUID SEED_SYS_USER =
            UUID.fromString("00000000-0000-4000-8000-000000000001");

    private final AnimationSceneRepository scenes;

    public AnimationSceneEventLinker(AnimationSceneRepository scenes) {
        this.scenes = scenes;
    }

    /**
     * Post-link the Bạch Đằng production scene to the given event.
     * No-op when the scene does not exist (V17 not applied), is already
     * linked, or has been touched by an admin (updatedBy != sys_user).
     * Uses the real event id from the repository — never a hard-coded UUID.
     */
    @Transactional
    public void linkBachDangProdScene(HistoricalEvent event) {
        if (event == null || event.getId() == null) {
            return;
        }
        linkSceneIfUntouchedSeed(BACH_DANG_PROD_SCENE_ID, event);
    }

    private void linkSceneIfUntouchedSeed(UUID sceneId, HistoricalEvent event) {
        var opt = scenes.findById(sceneId);
        if (opt.isEmpty()) {
            log.debug("post-link skipped — scene {} absent (V17 not applied?)", sceneId);
            return;
        }
        AnimationScene s = opt.get();
        if (s.getEventId() != null) {
            log.debug("post-link skipped — scene {} already linked eventId={}",
                    sceneId, s.getEventId());
            return;
        }
        if (!SEED_SYS_USER.equals(s.getUpdatedBy())) {
            // Admin (or another seed pass) touched the row — respect it.
            log.info("post-link skipped — scene {} edited by {} (admin link kept)",
                    sceneId, s.getUpdatedBy());
            return;
        }
        s.setEventId(event.getId());
        // Keep updatedBy = sys_user: the row is still "seed-owned", so a
        // later V17-style late-link UPDATE would also recognise it, and
        // the admin editor still sees it as untouched by a human.
        scenes.save(s);
        log.info("post-linked scene {} → event slug={} id={}",
                sceneId, event.getSlug(), event.getId());
    }
}

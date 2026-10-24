package com.dauviet.historicalevent.infrastructure.seed;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.dauviet.animation.domain.AnimationScene;
import com.dauviet.animation.infrastructure.persistence.AnimationSceneRepository;
import com.dauviet.historicalevent.domain.HistoricalEvent;

/**
 * FIX-01 — post-Flyway link contract (no DB): real event id used,
 * untouched seed rows linked, admin edits / existing links / missing
 * scenes never overwritten. Idempotent re-runs are no-ops.
 */
class AnimationSceneEventLinkerTest {

    private static final UUID SCENE_ID =
            UUID.fromString("d7a80000-0000-4000-8000-000000000001");
    private static final UUID SYS_USER =
            UUID.fromString("00000000-0000-4000-8000-000000000001");
    private static final UUID ADMIN = UUID.randomUUID();

    private AnimationSceneRepository repo() {
        return mock(AnimationSceneRepository.class);
    }

    private HistoricalEvent event(UUID id) {
        HistoricalEvent e = new HistoricalEvent();
        e.setId(id);
        e.setSlug("bach-dang-938");
        return e;
    }

    private AnimationScene untouchedSeedScene() {
        AnimationScene s = new AnimationScene();
        s.setId(SCENE_ID);
        s.setEventId(null);
        s.setUpdatedBy(SYS_USER);
        return s;
    }

    @Test
    void links_null_event_scene_using_real_event_id() {
        var repo = repo();
        var scene = untouchedSeedScene();
        when(repo.findById(SCENE_ID)).thenReturn(Optional.of(scene));
        var linker = new AnimationSceneEventLinker(repo);

        UUID realEventId = UUID.randomUUID(); // NOT the seed UUID
        linker.linkBachDangProdScene(event(realEventId));

        assertEquals(realEventId, scene.getEventId());
        verify(repo).save(scene);
    }

    @Test
    void rerun_is_idempotent_after_linked() {
        var repo = repo();
        var scene = untouchedSeedScene();
        scene.setEventId(UUID.randomUUID()); // already linked
        when(repo.findById(SCENE_ID)).thenReturn(Optional.of(scene));
        var linker = new AnimationSceneEventLinker(repo);

        linker.linkBachDangProdScene(event(UUID.randomUUID()));
        verify(repo, never()).save(scene);
    }

    @Test
    void admin_unlink_is_not_overwritten() {
        var repo = repo();
        var scene = untouchedSeedScene();
        scene.setUpdatedBy(ADMIN); // admin clearEvent → NULL + updatedBy admin
        when(repo.findById(SCENE_ID)).thenReturn(Optional.of(scene));
        var linker = new AnimationSceneEventLinker(repo);

        linker.linkBachDangProdScene(event(UUID.randomUUID()));
        assertNull(scene.getEventId());
        verify(repo, never()).save(scene);
    }

    @Test
    void missing_scene_is_noop() {
        var repo = repo();
        when(repo.findById(SCENE_ID)).thenReturn(Optional.empty());
        var linker = new AnimationSceneEventLinker(repo);
        linker.linkBachDangProdScene(event(UUID.randomUUID()));
        verify(repo, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void null_event_is_noop() {
        var repo = repo();
        var linker = new AnimationSceneEventLinker(repo);
        linker.linkBachDangProdScene(null);
        verify(repo, never()).save(org.mockito.ArgumentMatchers.any());
    }
}

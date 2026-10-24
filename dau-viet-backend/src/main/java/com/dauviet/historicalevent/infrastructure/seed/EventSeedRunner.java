package com.dauviet.historicalevent.infrastructure.seed;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import com.dauviet.historicalevent.application.EventSeedService;

/**
 * Dev-only seed trigger: active only under the `local` profile AND when
 * app.seed.enabled=true. Never runs under test/prod so demo rows can
 * never leak into real databases.
 */
@Component
@Profile("local")
@ConditionalOnProperty(name = "app.seed.enabled", havingValue = "true")
public class EventSeedRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(EventSeedRunner.class);

    private final EventSeedService seedService;
    private final AnimationSceneEventLinker sceneLinker;

    public EventSeedRunner(EventSeedService seedService,
                           AnimationSceneEventLinker sceneLinker) {
        this.seedService = seedService;
        this.sceneLinker = sceneLinker;
    }

    @Override
    public void run(ApplicationArguments args) {
        var event = seedService.upsertBachDang();
        // FIX-01 — Flyway ran before this runner, so V17 could only insert
        // the production scene with event_id NULL on a clean local DB.
        // Post-link it here using the real (possibly non-seed) event id;
        // no-op if the scene is already linked or an admin touched it.
        sceneLinker.linkBachDangProdScene(event);
        log.info("event seed completed (profile=local)");
    }
}

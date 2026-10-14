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

    public EventSeedRunner(EventSeedService seedService) {
        this.seedService = seedService;
    }

    @Override
    public void run(ApplicationArguments args) {
        seedService.upsertBachDang();
        log.info("event seed completed (profile=local)");
    }
}

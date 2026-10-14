package com.dauviet;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Full-context smoke test: boots the entire application against the shared
 * Testcontainers Postgres (see AbstractPostgresIT) and asserts the context
 * loads — covers the phase-05 "context loads" requirement.
 */
@SpringBootTest
class DauVietApplicationTests extends AbstractPostgresIT {

    @Test
    void contextLoads() {
        // Context failing to start fails this test.
    }
}

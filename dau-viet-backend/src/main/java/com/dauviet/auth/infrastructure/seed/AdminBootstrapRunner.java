package com.dauviet.auth.infrastructure.seed;

import java.util.Locale;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;

/**
 * Dev-only admin bootstrap: under the `local` profile with
 * app.seed.enabled=true, creates a CONTENT_ADMIN from ADMIN_EMAIL /
 * ADMIN_PASSWORD env vars. Insert-only — an existing account is never
 * overwritten or silently promoted. For non-local environments use the SQL
 * procedure documented in docs/backend-runbook.md.
 */
@Component
@Profile("local")
@ConditionalOnProperty(name = "app.seed.enabled", havingValue = "true")
public class AdminBootstrapRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminBootstrapRunner.class);

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final Environment env;

    public AdminBootstrapRunner(UserRepository users, PasswordEncoder passwordEncoder,
                                Environment env) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.env = env;
    }

    @Override
    public void run(ApplicationArguments args) {
        String email = env.getProperty("ADMIN_EMAIL");
        String password = env.getProperty("ADMIN_PASSWORD");
        if (email == null || email.isBlank() || password == null || password.isBlank()) {
            log.info("admin bootstrap skipped (ADMIN_EMAIL/ADMIN_PASSWORD unset)");
            return;
        }
        String normalized = email.trim().toLowerCase(Locale.ROOT);
        if (users.findByEmailIgnoreCase(normalized).isPresent()) {
            log.info("admin bootstrap skipped: account already exists");
            return;
        }
        User admin = new User();
        admin.setId(UUID.randomUUID());
        admin.setEmail(normalized);
        admin.setPasswordHash(passwordEncoder.encode(password));
        admin.setDisplayName(env.getProperty("ADMIN_DISPLAY_NAME", "Content Admin"));
        admin.setRole(UserRole.CONTENT_ADMIN);
        admin.setStatus(UserStatus.ACTIVE);
        users.save(admin);
        log.info("admin bootstrap created CONTENT_ADMIN for {}", normalized);
    }
}

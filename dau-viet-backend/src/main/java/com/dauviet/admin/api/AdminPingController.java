package com.dauviet.admin.api;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Minimal CONTENT_ADMIN-gated placeholder proving role-based authorization
 * works end to end. Real admin tooling lands in later tasks.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminPingController {

    @GetMapping("/ping")
    public Map<String, String> ping() {
        return Map.of("status", "ok");
    }
}

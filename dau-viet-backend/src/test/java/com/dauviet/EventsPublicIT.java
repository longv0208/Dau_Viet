package com.dauviet;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Public surface unchanged after JWT wiring: GET /api/v1/events stays
 * open without a token under the full security chain. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class EventsPublicIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;

    @Test
    void events_200_unauthenticated() throws Exception {
        mvc.perform(get("/api/v1/events"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void unknownApi_stillRequiresAuth() throws Exception {
        mvc.perform(get("/api/v1/unknown"))
                .andExpect(status().isUnauthorized());
    }
}

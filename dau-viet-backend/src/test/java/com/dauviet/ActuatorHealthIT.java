package com.dauviet;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Real HTTP integration test for the public health endpoint: the whole app
 * boots on a random port against the shared Testcontainers Postgres and we
 * hit /actuator/health end-to-end (not a WebMvc slice).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ActuatorHealthIT extends AbstractPostgresIT {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate rest;

    @Test
    void healthEndpoint_returns200Up() {
        ResponseEntity<String> res = rest.getForEntity(
                "http://localhost:" + port + "/actuator/health", String.class);
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(res.getBody()).contains("\"status\":\"UP\"");
    }
}

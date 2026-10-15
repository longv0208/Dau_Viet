package com.dauviet.learning.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.infrastructure.persistence.IdempotencyRecordRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Pure-logic unit tests for fingerprint/canonical stability — the fields the
 * idempotency contract depends on: same payload -> same hash regardless of
 * JSON field order; different payload -> different hash.
 */
class IdempotencyServiceTest {

    private final IdempotencyService service = new IdempotencyService(
            mock(IdempotencyRecordRepository.class), new ObjectMapper(), 86400);

    @Test
    void fingerprint_isStableAndHexSha256() throws Exception {
        String h1 = service.fingerprint("a|b|c");
        String h2 = service.fingerprint("a|b|c");
        assertThat(h1).isEqualTo(h2).hasSize(64)
                .matches("[0-9a-f]{64}");
        assertThat(service.fingerprint("a|b|d")).isNotEqualTo(h1);
    }

    @Test
    void canonical_sortsFields_atEveryDepth() throws Exception {
        ObjectMapper om = new ObjectMapper();
        String c1 = service.canonical(om.readTree(
                "{\"b\":1,\"a\":{\"y\":2,\"x\":1}}"));
        String c2 = service.canonical(om.readTree(
                "{\"a\":{\"x\":1,\"y\":2},\"b\":1}"));
        // same logical payload in different field order -> identical canonical
        assertThat(c1).isEqualTo(c2);
        assertThat(c1).isEqualTo("{\"a\":{\"x\":1,\"y\":2},\"b\":1}");
    }

    @Test
    void canonical_differentPayload_differs() throws Exception {
        ObjectMapper om = new ObjectMapper();
        String c1 = service.canonical(om.readTree("{\"selectedOptionIds\":[\"o1\"]}"));
        String c2 = service.canonical(om.readTree("{\"selectedOptionIds\":[\"o2\"]}"));
        assertThat(c1).isNotEqualTo(c2);
    }

    @Test
    void canonical_nullNode_isStable() {
        assertThat(service.canonical(null)).isEqualTo("null");
    }

    @Test
    void fingerprint_coversFullFingerprintInput() throws Exception {
        // attemptId|activityId|canonical — two different attempts with the
        // same activity+answer must not collide
        String a = service.fingerprint("att1|mc|{}");
        String b = service.fingerprint("att2|mc|{}");
        assertThat(a).isNotEqualTo(b);
    }
}

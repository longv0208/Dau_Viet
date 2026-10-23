package com.dauviet.animation.manifest;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import com.dauviet.animation.domain.AnimationExceptions.ManifestFieldError;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

/**
 * Extract each seeded manifest JSONB literal out of V15__animation_seed.sql and
 * run AnimationManifestValidator over it — catches hand-translation typos without
 * needing a database or Testcontainers.
 */
class AnimationSeedManifestTest {

    private final ObjectMapper mapper = new ObjectMapper();
    private AnimationManifestValidator validator;

    @BeforeEach
    void setUp() {
        AssetRepository assets = Mockito.mock(AssetRepository.class);
        when(assets.existsByIdAndState(any(UUID.class), eq("ACTIVE"))).thenReturn(true);
        validator = new AnimationManifestValidator(assets);
    }

    private String migrationSql() throws Exception {
        try (InputStream in = getClass().getResourceAsStream("/db/migration/V15__animation_seed.sql")) {
            assertNotNull(in, "V15 migration missing from classpath");
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    /** Pull `m_<name> := '{...}'::jsonb;` out of the DO block. */
    private JsonNode seedManifest(String var) throws Exception {
        String sql = migrationSql();
        Pattern p = Pattern.compile(var + "\\s*:=\\s*'(.*?)'::jsonb", Pattern.DOTALL);
        Matcher m = p.matcher(sql);
        assertTrue(m.find(), "manifest variable " + var + " not found in V15");
        return mapper.readTree(m.group(1));
    }

    private AnimationTemplate template(String renderer) {
        AnimationTemplate t = new AnimationTemplate();
        t.setId(UUID.randomUUID());
        t.setCode(renderer);
        t.setRendererCode(renderer);
        t.setRendererVersion(1);
        t.setSchemaVersion(1);
        return t;
    }

    private void assertValid(JsonNode manifest, String renderer) {
        List<ManifestFieldError> errors = validator.validate(manifest, template(renderer));
        assertEquals(List.of(), errors,
                () -> "seed manifest for " + renderer + " failed validation: " + errors);
    }

    @Test
    void bachDangRiverManifestValidates() throws Exception {
        JsonNode m = seedManifest("m_bach_dang");
        assertValid(m, "RIVER_TIDE");
        assertEquals(6, m.get("steps").size());
        assertEquals(9, m.get("river").get("stakes").size());
    }

    @Test
    void haiBaTrungMapManifestValidates() throws Exception {
        JsonNode m = seedManifest("m_hai_ba");
        assertValid(m, "JOURNEY_MAP");
        assertEquals(3, m.get("map").get("locations").size());
        assertEquals(2, m.get("map").get("routes").size());
    }

    @Test
    void lyThaiToMapManifestValidates() throws Exception {
        JsonNode m = seedManifest("m_ly_thai");
        assertValid(m, "JOURNEY_MAP");
        assertEquals(2, m.get("map").get("locations").size());
        assertEquals(1, m.get("map").get("routes").size());
    }
}

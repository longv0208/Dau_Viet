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
 * TASK-0019 — extract the production manifest literal out of
 * V17__bachdang_production_scene.sql and run AnimationManifestValidator
 * over it (mirrors AnimationSeedManifestTest for V15). Catches
 * hand-translation typos without a database.
 */
class AnimationProductionSeedTest {

    private final ObjectMapper mapper = new ObjectMapper();
    private AnimationManifestValidator validator;

    @BeforeEach
    void setUp() {
        AssetRepository assets = Mockito.mock(AssetRepository.class);
        // V17 seeds its three assets in the same DO block — mock ACTIVE
        // for every UUID the manifest references.
        when(assets.existsByIdAndState(any(UUID.class), eq("ACTIVE"))).thenReturn(true);
        validator = new AnimationManifestValidator(assets);
    }

    private String migrationSql() throws Exception {
        try (InputStream in = getClass().getResourceAsStream(
                "/db/migration/V17__bachdang_production_scene.sql")) {
            assertNotNull(in, "V17 migration missing from classpath");
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    private JsonNode productionManifest() throws Exception {
        String sql = migrationSql();
        Pattern p = Pattern.compile("m_bd_prod\\s*:=\\s*'(.*?)'::jsonb", Pattern.DOTALL);
        Matcher m = p.matcher(sql);
        assertTrue(m.find(), "m_bd_prod variable not found in V17");
        return mapper.readTree(m.group(1));
    }

    private AnimationTemplate riverTemplate() {
        AnimationTemplate t = new AnimationTemplate();
        t.setId(UUID.randomUUID());
        t.setCode("RIVER_TIDE");
        t.setRendererCode("RIVER_TIDE");
        t.setRendererVersion(1);
        t.setSchemaVersion(2); // v2 template accepts schemaVersion 1 or 2
        return t;
    }

    @Test
    void productionManifestValidates() throws Exception {
        JsonNode m = productionManifest();
        List<ManifestFieldError> errors = validator.validate(m, riverTemplate());
        assertEquals(List.of(), errors,
                () -> "V17 production manifest failed validation: " + errors);
    }

    @Test
    void manifestHasEightBeatsAndAssets() throws Exception {
        JsonNode m = productionManifest();
        assertEquals(8, m.get("steps").size(), "8-beat storyboard");
        assertEquals(3, m.get("assets").size(), "hero + map + voice");

        // Step ids in the required order.
        String[] expected = {"estuary", "stake-prep", "tide-rise", "decoy",
                "prediction", "tide-fall", "counterattack", "evidence"};
        for (int i = 0; i < expected.length; i++) {
            assertEquals(expected[i], m.get("steps").get(i).get("id").asText());
        }

        // Every audio cue points at the AUDIO-role assetRef.
        String audioKey = null;
        for (JsonNode a : m.get("assets")) {
            if ("AUDIO".equals(a.get("role").asText())) {
                audioKey = a.get("id").asText();
            }
        }
        assertEquals("voice", audioKey);
        for (JsonNode cue : m.get("audio")) {
            assertEquals("voice", cue.get("assetRef").asText());
        }

        // Prediction checkpoint is wired.
        JsonNode pred = m.get("prediction");
        assertTrue(pred.get("options").size() >= 2);
        assertTrue(pred.get("explainedOptionIndex").asInt() < pred.get("options").size());
        assertTrue(m.get("sourceReferences").size() >= 1);
        assertTrue(m.hasNonNull("disclaimer"));
    }
}

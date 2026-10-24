package com.dauviet.animation.manifest;

import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import com.dauviet.animation.domain.AnimationExceptions.ManifestFieldError;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

/** Unit tests for the ~15-point manifest validation. */
class AnimationManifestValidatorTest {

    private final ObjectMapper mapper = new ObjectMapper();
    private AssetRepository assets;
    private AnimationManifestValidator validator;
    private AnimationTemplate riverTemplate;
    private AnimationTemplate mapTemplate;

    @BeforeEach
    void setUp() {
        assets = Mockito.mock(AssetRepository.class);
        when(assets.existsByIdAndState(any(UUID.class), eq("ACTIVE"))).thenReturn(true);
        validator = new AnimationManifestValidator(assets);
        riverTemplate = template("RIVER_TIDE");
        mapTemplate = template("JOURNEY_MAP");
    }

    private AnimationTemplate template(String renderer) {
        AnimationTemplate t = new AnimationTemplate();
        t.setId(UUID.randomUUID());
        t.setCode("T_" + renderer);
        t.setRendererCode(renderer);
        t.setRendererVersion(1);
        t.setSchemaVersion(1);
        return t;
    }

    private String riverManifest() {
        return """
            {
              "schemaVersion": 1, "rendererCode": "RIVER_TIDE", "rendererVersion": 1,
              "title": "Trận Bạch Đằng 938",
              "canvas": {"aspectRatio": 1.6},
              "river": {
                "stakes": [
                  {"id": "stake-a", "x": 0.5, "length": 0.7},
                  {"id": "stake-b", "x": 0.6, "length": 0.65}
                ]
              },
              "initialState": {"waterLevel": 0.3, "boatProgress": 0.0},
              "steps": [
                {"id": "s1", "title": "Chuẩn bị", "durationMs": 1200,
                 "targetState": {"waterLevel": 0.3},
                 "easing": "easeInOut", "effects": ["FADE_IN"]},
                {"id": "s2", "title": "Nước dâng", "durationMs": 1500,
                 "targetState": {"waterLevel": 0.9},
                 "allowedInteractions": ["WATER_LEVEL_CONTROL"]}
              ],
              "prediction": {
                "question": "Con nước sẽ thế nào?",
                "options": [{"text": "Dâng"}, {"text": "Rút"}],
                "explainedOptionIndex": 1
              },
              "sourceReferences": [{"title": "Bảo tàng LSQG"}],
              "disclaimer": "Minh họa mô phỏng"
            }
            """;
    }

    private String mapManifest() {
        return """
            {
              "schemaVersion": 1, "rendererCode": "JOURNEY_MAP", "rendererVersion": 1,
              "title": "Hành trình Hai Bà Trưng",
              "map": {
                "locations": [
                  {"id": "hat-mon", "name": "Hát Môn", "x": 0.30, "y": 0.62},
                  {"id": "me-linh", "name": "Mê Linh", "x": 0.48, "y": 0.42},
                  {"id": "luy-lau", "name": "Luy Lâu", "x": 0.72, "y": 0.34}
                ],
                "routes": [
                  {"id": "gather", "from": "hat-mon", "to": "me-linh",
                   "via": [{"x": 0.40, "y": 0.55}]},
                  {"id": "advance", "from": "me-linh", "to": "luy-lau"}
                ]
              },
              "initialState": {"markerVisibility": {"hat-mon": true}},
              "steps": [{"id": "s1", "title": "Khởi đầu",
                         "targetState": {"focusedLocationId": "hat-mon"}}],
              "interactions": ["TAP_TO_EXPLORE"],
              "sourceReferences": [{"title": "Đại Việt sử ký"}],
              "disclaimer": "Bản đồ schematic"
            }
            """;
    }

    private List<ManifestFieldError> run(String json, AnimationTemplate t) {
        try {
            return validator.validate(mapper.readTree(json), t);
        } catch (Exception e) {
            throw new AssertionError("unparseable test json", e);
        }
    }

    private static boolean has(List<ManifestFieldError> errs, String path, String code) {
        return errs.stream().anyMatch(e -> e.path().equals(path) && e.code().equals(code));
    }

    @Test
    void validRiverManifestPasses() {
        assertTrue(run(riverManifest(), riverTemplate).isEmpty());
    }

    @Test
    void validMapManifestPasses() {
        assertTrue(run(mapManifest(), mapTemplate).isEmpty());
    }

    @Test
    void rejectsNonObject() throws Exception {
        var errs = validator.validate(mapper.readTree("[]"), riverTemplate);
        assertTrue(has(errs, "manifest", "INVALID_TYPE"));
    }

    @Test
    void rejectsUnknownTopLevelField() {
        String json = riverManifest().replace("\"title\":", "\"hackField\": 1, \"title\":");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_FIELD")));
    }

    @Test
    void rejectsRendererMismatch() {
        var errs = run(riverManifest(), mapTemplate);
        assertTrue(has(errs, "manifest.rendererCode", "RENDERER_MISMATCH"));
    }

    @Test
    void rejectsUnsupportedRenderer() {
        String json = riverManifest().replace("RIVER_TIDE", "BATTLEFIELD_3D");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNSUPPORTED_RENDERER")));
    }

    @Test
    void rejectsMissingSteps() {
        String json = riverManifest().replace(
                "\"steps\": [", "\"stepsX\": [").replace(
                "],\n              \"prediction\"", "],\n              \"prediction2\": 1, \"prediction\"");
        var errs = run(json, riverTemplate);
        assertTrue(has(errs, "manifest.steps", "MISSING_FIELD"));
    }

    @Test
    void rejectsDuplicateStepIds() {
        String json = riverManifest().replace("\"id\": \"s2\"", "\"id\": \"s1\"");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("DUPLICATE_ID")));
    }

    @Test
    void rejectsBadEasingAndEffect() {
        String json = riverManifest()
                .replace("easeInOut", "bounce")
                .replace("FADE_IN", "EXPLODE");
        var errs = run(json, riverTemplate);
        assertTrue(errs.stream().anyMatch(e -> e.code().equals("INVALID_VALUE")
                && e.path().contains("easing")));
        assertTrue(errs.stream().anyMatch(e -> e.code().equals("INVALID_VALUE")
                && e.path().contains("effects")));
    }

    @Test
    void rejectsUnknownStateKey() {
        String json = riverManifest()
                .replace("\"waterLevel\": 0.3, \"boatProgress\": 0.0",
                        "\"waterLevel\": 0.3, \"hackState\": true, \"boatProgress\": 0.0");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_STATE_KEY")));
    }

    @Test
    void rejectsOutOfRangeStakeX() {
        String json = riverManifest().replace("\"x\": 0.5", "\"x\": 1.5");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("OUT_OF_RANGE")));
    }

    @Test
    void rejectsRouteToUnknownLocation() {
        String json = mapManifest().replace("\"to\": \"luy-lau\"", "\"to\": \"nowhere\"");
        assertTrue(run(json, mapTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")));
    }

    @Test
    void rejectsBadPredictionIndex() {
        String json = riverManifest().replace(
                "\"explainedOptionIndex\": 1", "\"explainedOptionIndex\": 9");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.path().contains("explainedOptionIndex")));
    }

    @Test
    void rejectsInactiveAssetRef() {
        when(assets.existsByIdAndState(any(UUID.class), eq("ACTIVE"))).thenReturn(false);
        String json = riverManifest().replace("\"canvas\": {\"aspectRatio\": 1.6},",
                "\"canvas\": {\"aspectRatio\": 1.6},"
                + "\"assets\": [{\"id\": \"bg\", \"assetId\": \""
                + UUID.randomUUID() + "\", \"role\": \"BACKGROUND\"}],");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("ASSET_NOT_FOUND")));
    }

    @Test
    void rejectsMissingRiverSection() {
        String json = riverManifest().replace("\"river\": {", "\"riverX\": {");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("MISSING_FIELD")
                        && e.path().equals("manifest.river")));
    }

    @Test
    void rejectsMissingMapLocations() {
        String json = mapManifest().replace("\"locations\": [", "\"locationsX\": [");
        assertTrue(run(json, mapTemplate).stream()
                .anyMatch(e -> e.code().equals("MISSING_FIELD")
                        && e.path().equals("manifest.map.locations")));
    }

    /* ---------- P1-9 hardening ---------- */

    @Test
    void rejectsMissingSourceReferences() {
        String json = riverManifest().replace(
                "\"sourceReferences\": [{\"title\": \"Bảo tàng LSQG\"}],", "");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("MISSING_FIELD")
                        && e.path().equals("manifest.sourceReferences")));
    }

    @Test
    void rejectsEmptySourceReferences() {
        String json2 = riverManifest().replace(
                "[{\"title\": \"Bảo tàng LSQG\"}]", "[]");
        assertTrue(run(json2, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("MISSING_FIELD")
                        && e.path().equals("manifest.sourceReferences")));
    }

    @Test
    void rejectsMissingDisclaimer() {
        String json = riverManifest().replace(
                "\"disclaimer\": \"Minh họa mô phỏng\"", "\"disclaimerX\": 1");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("MISSING_FIELD")
                        && e.path().equals("manifest.disclaimer")));
    }

    @Test
    void rejectsInactiveBackgroundAsset() {
        when(assets.existsByIdAndState(any(UUID.class), eq("ACTIVE"))).thenReturn(false);
        String json = mapManifest().replace(
                "\"routes\": [",
                "\"backgroundAssetId\": \"" + UUID.randomUUID() + "\", \"routes\": [");
        assertTrue(run(json, mapTemplate).stream()
                .anyMatch(e -> e.code().equals("ASSET_NOT_FOUND")
                        && e.path().equals("manifest.map.backgroundAssetId")));
    }

    @Test
    void rejectsWaterLevelOutOfRange() {
        String json = riverManifest().replace(
                "\"targetState\": {\"waterLevel\": 0.9}",
                "\"targetState\": {\"waterLevel\": 1.5}");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("OUT_OF_RANGE")
                        && e.path().contains("waterLevel")));
    }

    @Test
    void rejectsMarkerVisibilityUnknownLocation() {
        String json = mapManifest().replace(
                "\"markerVisibility\": {\"hat-mon\": true}",
                "\"markerVisibility\": {\"nowhere\": 1}");
        assertTrue(run(json, mapTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")
                        && e.path().contains("markerVisibility")));
    }

    @Test
    void rejectsRouteProgressUnknownRoute() {
        String json = mapManifest().replace(
                "\"targetState\": {\"focusedLocationId\": \"hat-mon\"}",
                "\"targetState\": {\"routeProgress\": {\"ghost-route\": 0.5}}");
        assertTrue(run(json, mapTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")
                        && e.path().contains("routeProgress")));
    }

    @Test
    void rejectsFocusedLocationUnknown() {
        String json = mapManifest().replace(
                "\"focusedLocationId\": \"hat-mon\"",
                "\"focusedLocationId\": \"nowhere\"");
        assertTrue(run(json, mapTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")
                        && e.path().contains("focusedLocationId")));
    }

    /* ---------- P1-6 renderer/schema version compat ---------- */

    @Test
    void rejectsNewerRendererVersionThanTemplate() {
        String json = riverManifest().replace(
                "\"rendererVersion\": 1", "\"rendererVersion\": 2");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNSUPPORTED_VERSION")
                        && e.path().equals("manifest.rendererVersion")));
    }

    @Test
    void acceptsMatchingOrOlderRendererVersion() {
        // rendererVersion == template.rendererVersion → pass.
        assertTrue(run(riverManifest(), riverTemplate).isEmpty());
        // rendererVersion thấp hơn template vẫn tương thích (app cũ đọc
        // manifest cũ) — field khác giữ nguyên.
        String json = riverManifest().replace(
                "\"rendererVersion\": 1", "\"rendererVersion\": 1");
        riverTemplate.setRendererVersion(3);
        assertTrue(run(json, riverTemplate).isEmpty());
    }

    @Test
    void rejectsRendererVersionBelowOne() {
        String json = riverManifest().replace(
                "\"rendererVersion\": 1", "\"rendererVersion\": 0");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("INVALID_VALUE")
                        && e.path().equals("manifest.rendererVersion")));
    }

    @Test
    void rejectsUnsupportedSchemaVersion() {
        String json = riverManifest().replace(
                "\"schemaVersion\": 1", "\"schemaVersion\": 99");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNSUPPORTED_SCHEMA")
                        && e.path().equals("manifest.schemaVersion")));
    }

    @Test
    void rejectsStakeVisibilityUnknownStake() {
        String json = riverManifest().replace(
                "\"targetState\": {\"waterLevel\": 0.3}",
                "\"targetState\": {\"stakeVisibility\": {\"ghost\": 1}}");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")
                        && e.path().contains("stakeVisibility")));
    }

    /* ---------- Cinematic v2 fields ---------- */

    private String v2River() {
        return riverManifest()
                .replace("\"schemaVersion\": 1", "\"schemaVersion\": 2")
                .replace("\"canvas\": {\"aspectRatio\": 1.6},",
                        "\"canvas\": {\"aspectRatio\": 1.6},"
                        + "\"objects\": [{\"id\": \"decoy-1\", \"type\": \"DECOY\","
                        + " \"position\": {\"x\": 0.8, \"y\": 0.4}}],"
                        + "\"camera\": {\"initial\": {\"x\": 0.5, \"y\": 0.5, \"zoom\": 1.0},"
                        + " \"steps\": [{\"target\": {\"x\": 0.55, \"y\": 0.6, \"zoom\": 1.4},"
                        + "  \"easing\": \"easeInOut\"}]},"
                        + "\"tracks\": [{\"objectId\": \"decoy-1\", \"property\": \"position\","
                        + " \"keyframes\": [{\"tMs\": 0, \"value\": {\"x\": 0.9, \"y\": 0.4}},"
                        + "  {\"tMs\": 1500, \"value\": {\"x\": 0.5, \"y\": 0.4}}]}],"
                        + "\"effects\": [{\"type\": \"MIST\", \"params\": {\"intensity\": 0.5}}],"
                        + "\"environment\": {\"waterLevel\": 0.3, \"mist\": 0.4},"
                        + "\"audio\": [{\"stepId\": \"s1\", \"assetRef\": \"river-amb\","
                        + " \"cue\": \"LOOP\", \"volume\": 0.6}],"
                        + "\"assets\": [{\"id\": \"river-amb\", \"assetId\": \""
                        + UUID.randomUUID() + "\", \"role\": \"AUDIO\"}],");
    }

    @Test
    void validV2RiverManifestPasses() {
        assertTrue(run(v2River(), riverTemplate).isEmpty(),
                "v2 manifest with camera+tracks+effects+audio+environment must validate");
    }

    @Test
    void v1ManifestStillValidates() {
        assertTrue(run(riverManifest(), riverTemplate).isEmpty());
        assertTrue(run(mapManifest(), mapTemplate).isEmpty());
    }

    @Test
    void rejectsV2KeysUnderSchemaVersion1() {
        String json = riverManifest().replace(
                "\"canvas\": {\"aspectRatio\": 1.6},",
                "\"canvas\": {\"aspectRatio\": 1.6},"
                + "\"camera\": {\"initial\": {\"x\": 0.5, \"y\": 0.5, \"zoom\": 1.0}},");
        var errs = run(json, riverTemplate);
        assertTrue(errs.stream().anyMatch(e -> e.code().equals("OUTDATED_SCHEMA")
                && e.path().equals("manifest.schemaVersion")));
    }

    @Test
    void rejectsCameraZoomOutOfRange() {
        String json = v2River().replace("\"zoom\": 1.4", "\"zoom\": 5.0");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("OUT_OF_RANGE")
                        && e.path().contains("zoom")));
    }

    @Test
    void rejectsCameraFocusUnknownObject() {
        String json = v2River().replace(
                "\"zoom\": 1.4", "\"zoom\": 1.4, \"focusObjectId\": \"ghost\"");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")
                        && e.path().contains("focusObjectId")));
    }

    @Test
    void rejectsTrackUnknownObject() {
        String json = v2River().replace(
                "\"objectId\": \"decoy-1\"", "\"objectId\": \"ghost\"");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")
                        && e.path().contains("objectId")));
    }

    @Test
    void rejectsTrackBadProperty() {
        String json = v2River().replace(
                "\"property\": \"position\"", "\"property\": \"explode\"");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("INVALID_VALUE")
                        && e.path().contains("property")));
    }

    @Test
    void rejectsKeyframesNotAscending() {
        String json = v2River().replace("\"tMs\": 1500", "\"tMs\": 0");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("OUT_OF_ORDER")));
    }

    @Test
    void rejectsAudioNonAudioRole() {
        String json = v2River().replace("\"role\": \"AUDIO\"", "\"role\": \"OBJECT\"");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")
                        && e.path().contains("assetRef")));
    }

    @Test
    void rejectsAudioBadStep() {
        String json = v2River().replace("\"stepId\": \"s1\"", "\"stepId\": \"ghost\"");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("UNKNOWN_REF")
                        && e.path().contains("stepId")));
    }

    @Test
    void rejectsEnvironmentOnJourneyMap() {
        String json = mapManifest()
                .replace("\"schemaVersion\": 1", "\"schemaVersion\": 2")
                .replace("\"map\": {",
                        "\"environment\": {\"waterLevel\": 0.5}, \"map\": {");
        assertTrue(run(json, mapTemplate).stream()
                .anyMatch(e -> e.code().equals("RENDERER_MISMATCH")
                        && e.path().contains("environment")));
    }

    @Test
    void rejectsUnknownEffectType() {
        String json = v2River().replace("\"type\": \"MIST\"", "\"type\": \"EXPLODE\"");
        assertTrue(run(json, riverTemplate).stream()
                .anyMatch(e -> e.code().equals("INVALID_VALUE")
                        && e.path().contains("effects")));
    }

    /* ---------- V16 demo-scene positive tests ---------- */

    private String resource(String name) {
        try (var in = getClass().getResourceAsStream(
                "/animation-manifests/" + name)) {
            if (in == null) throw new AssertionError("missing fixture " + name);
            return new String(in.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
        } catch (java.io.IOException e) {
            throw new AssertionError("cannot read fixture " + name, e);
        }
    }

    @Test
    void v16BachDangCinematicValidates() {
        var errs = run(resource("bd.json"), riverTemplate);
        assertTrue(errs.isEmpty(),
                () -> "bach_dang_938_cinematic must validate cleanly: " + errs);
    }

    @Test
    void v16HaiBaTrungCinematicValidates() {
        var errs = run(resource("hb.json"), mapTemplate);
        assertTrue(errs.isEmpty(),
                () -> "hai_ba_trung_40_cinematic must validate cleanly: " + errs);
    }

    @Test
    void v16LyThaiToCinematicValidates() {
        var errs = run(resource("lt.json"), mapTemplate);
        assertTrue(errs.isEmpty(),
                () -> "ly_thai_to_1010_cinematic must validate cleanly: " + errs);
    }

    /* ---------- HTML_WEBVIEW ---------- */

    private AnimationTemplate htmlTemplate() {
        AnimationTemplate t = new AnimationTemplate();
        t.setId(UUID.randomUUID());
        t.setCode("html-webview");
        t.setRendererCode("HTML_WEBVIEW");
        t.setRendererVersion(1);
        t.setSchemaVersion(2);
        return t;
    }

    private String htmlManifest(String sha) {
        return """
            {
              "schemaVersion": 2, "rendererCode": "HTML_WEBVIEW",
              "rendererVersion": 1, "title": "Bạch Đằng HTML",
              "disclaimer": "Nội dung do tác giả HTML chịu trách nhiệm.",
              "sourceReferences": [],
              "html": {"filename": "bd.html", "sizeBytes": 12345, "sha256": "%s"}
            }
            """.formatted(sha);
    }

    private static final String SHA = "a".repeat(64);

    private String htmlNoSection() {
        return """
            {
              "schemaVersion": 2, "rendererCode": "HTML_WEBVIEW",
              "rendererVersion": 1, "title": "Bạch Đằng HTML",
              "disclaimer": "Nội dung do tác giả HTML chịu trách nhiệm.",
              "sourceReferences": []
            }
            """;
    }

    private String htmlNoDisclaimer() {
        return """
            {
              "schemaVersion": 2, "rendererCode": "HTML_WEBVIEW",
              "rendererVersion": 1, "title": "Bạch Đằng HTML",
              "sourceReferences": [],
              "html": {"filename": "bd.html", "sizeBytes": 12345, "sha256": "%s"}
            }
            """.formatted(SHA);
    }

    private String htmlWithSteps() {
        return """
            {
              "schemaVersion": 2, "rendererCode": "HTML_WEBVIEW",
              "rendererVersion": 1, "title": "Bạch Đằng HTML",
              "disclaimer": "Nội dung do tác giả HTML chịu trách nhiệm.",
              "sourceReferences": [],
              "html": {"filename": "bd.html", "sizeBytes": 12345, "sha256": "%s"},
              "steps": [{"id": "s1", "title": "x"}]
            }
            """.formatted(SHA);
    }

    @Test
    void htmlWebviewValidatesCleanly() {
        var errs = run(htmlManifest(SHA), htmlTemplate());
        assertTrue(errs.isEmpty(), () -> "html manifest must validate: " + errs);
    }

    @Test
    void htmlWebviewRejectsMissingHtmlSection() {
        var errs = run(htmlNoSection(), htmlTemplate());
        assertTrue(errs.stream().anyMatch(
                e -> e.path().contains("html") && e.code().equals("MISSING_FIELD")),
                () -> "expected html MISSING_FIELD, got: " + errs);
    }

    @Test
    void htmlWebviewRejectsBadSha256() {
        var errs = run(htmlManifest("nothex"), htmlTemplate());
        assertTrue(errs.stream().anyMatch(
                e -> e.path().contains("sha256")),
                () -> "expected sha256 error, got: " + errs);
    }

    @Test
    void htmlWebviewRejectsManifestSteps() {
        var errs = run(htmlWithSteps(), htmlTemplate());
        assertTrue(errs.stream().anyMatch(
                e -> e.code().equals("UNKNOWN_FIELD")),
                () -> "expected UNKNOWN_FIELD for steps, got: " + errs);
    }

    @Test
    void htmlWebviewRejectsMissingDisclaimer() {
        var errs = run(htmlNoDisclaimer(), htmlTemplate());
        assertTrue(errs.stream().anyMatch(
                e -> e.path().contains("disclaimer")),
                () -> "expected disclaimer error, got: " + errs);
    }

    @Test
    void htmlWebviewEmptySourceReferencesAllowed() {
        var errs = run(htmlManifest(SHA), htmlTemplate());
        // Unlike generic renderers, empty sourceReferences is allowed.
        assertTrue(errs.stream().noneMatch(
                e -> e.path().contains("sourceReferences")),
                () -> "empty sourceReferences must not error for HTML: " + errs);
    }
}

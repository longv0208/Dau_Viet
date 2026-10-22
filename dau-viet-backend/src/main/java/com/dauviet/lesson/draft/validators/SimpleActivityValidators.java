package com.dauviet.lesson.draft.validators;

import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;

import com.dauviet.lesson.draft.ActivityType;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.ValidationContext;

/**
 * Validators for passive / single-interaction activity types.
 * Grouped in one file because each is under ~40 lines of real logic.
 */
public final class SimpleActivityValidators {

    // Public holder so tests and wiring can reference each validator type.

    private SimpleActivityValidators() {
    }

    /** READ: optional text/html body (bounded length). */
    @Component
    public static class ReadValidator extends AbstractActivityValidator {
        private static final int MAX_TEXT = 20_000;

        /**
         * ANIM-01: `config.animationKey` tuỳ chọn — identifier an toàn,
         * versioned (khuyến nghị hậu tố `_vN`), resolve phía Flutter.
         * Bounded: không URL/path/ký tự thực thi; backend không biết
         * registry Flutter nên không kiểm tra key có scene tương ứng.
         */
        private static final java.util.regex.Pattern ANIMATION_KEY_PATTERN =
                java.util.regex.Pattern.compile("[a-z0-9]+(_[a-z0-9]+){0,7}");
        private static final int MAX_ANIMATION_KEY = 80;

        @Override public ActivityType supports() { return ActivityType.READ; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            if (config == null) return; // READ may be config-free at SAVE
            JsonNode text = config.get("text");
            if (text != null && text.isTextual() && text.asText().length() > MAX_TEXT) {
                errors.add(new FieldError(path + ".config.text", "TOO_LONG",
                        "text exceeds " + MAX_TEXT + " chars"));
            }
            JsonNode anim = config.get("animationKey");
            if (anim == null || anim.isNull()) return; // optional field
            if (!anim.isTextual()) {
                errors.add(new FieldError(path + ".config.animationKey",
                        "INVALID_TYPE", "animationKey must be a string"));
                return;
            }
            String key = anim.asText();
            if (key.isBlank() || key.length() > MAX_ANIMATION_KEY
                    || !ANIMATION_KEY_PATTERN.matcher(key).matches()) {
                errors.add(new FieldError(path + ".config.animationKey",
                        "INVALID_ID",
                        "animationKey must be a safe lowercase identifier "
                                + "(e.g. 'bach_dang_938_tide_v1'), max "
                                + MAX_ANIMATION_KEY + " chars"));
            }
        }
    }

    /** VIEW_IMAGE: imageAssetId required; existence checked at PUBLISH. */
    @Component
    public static class ViewImageValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.VIEW_IMAGE; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            requireField(config, "imageAssetId", path, errors);
            if (ctx.isPublish() && config != null && config.hasNonNull("imageAssetId")) {
                String assetId = config.get("imageAssetId").asText();
                if (!ctx.assetUsable(assetId)) {
                    errors.add(new FieldError(path + ".config.imageAssetId",
                            "ASSET_NOT_FOUND", "asset '" + assetId + "' not active"));
                }
            }
        }
    }

    /** EXPLORE_MAP: markers[] >= 1 with unique ids. */
    @Component
    public static class ExploreMapValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.EXPLORE_MAP; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            requireNonEmptyArray(config, "markers", path, 1, errors);
            if (config != null && config.has("markers")) {
                collectIds(config.get("markers"), path + ".config.markers", errors);
            }
        }
    }

    /** REFLECTION_PROMPT: optional prompt, length-bounded. */
    @Component
    public static class ReflectionPromptValidator extends AbstractActivityValidator {
        private static final int MAX_PROMPT = 2_000;

        @Override public ActivityType supports() { return ActivityType.REFLECTION_PROMPT; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            if (config == null) return;
            JsonNode prompt = config.get("prompt");
            if (prompt != null && prompt.isTextual() && prompt.asText().length() > MAX_PROMPT) {
                errors.add(new FieldError(path + ".config.prompt", "TOO_LONG",
                        "prompt exceeds " + MAX_PROMPT + " chars"));
            }
        }
    }

    /** HYPOTHESIS_CHOICE: hypotheses[] >= 2 unique ids. */
    @Component
    public static class HypothesisChoiceValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.HYPOTHESIS_CHOICE; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            requireNonEmptyArray(config, "hypotheses", path, 2, errors);
            if (config != null && config.has("hypotheses")) {
                collectIds(config.get("hypotheses"), path + ".config.hypotheses", errors);
            }
        }
    }

    /**
     * VERIFICATION: outcome-driven stage transitions.
     * onPartial/onContradicted reference stage ids; targets checked
     * at the stage-graph level (DraftValidator), here only shape.
     */
    @Component
    public static class VerificationValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.VERIFICATION; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            if (config == null) return;
            checkEvidenceRefs(config, "visibleSourceIds", path, ctx, errors);
            checkEvidenceRefs(config, "requiredEvidenceIds", path, ctx, errors);
        }
    }

    /** EVIDENCE_SELECT: visibleEvidenceIds[] non-empty; refs checked at PUBLISH. */
    @Component
    public static class EvidenceSelectValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.EVIDENCE_SELECT; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            requireNonEmptyArray(config, "visibleEvidenceIds", path, 1, errors);
            checkEvidenceRefs(config, "visibleEvidenceIds", path, ctx, errors);
        }
    }

    /** CER: rubric.criteria[] non-empty + requiredEvidenceIds[] non-empty. */
    @Component
    public static class CerValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.CER; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            if (config == null) {
                errors.add(new FieldError(path + ".config", "MISSING_FIELD", "config is required"));
                return;
            }
            JsonNode rubric = config.get("rubric");
            if (rubric == null || !rubric.isObject()
                    || rubric.get("criteria") == null || !rubric.get("criteria").isArray()
                    || rubric.get("criteria").isEmpty()) {
                errors.add(new FieldError(path + ".config.rubric.criteria", "MISSING_FIELD",
                        "rubric.criteria must be a non-empty array"));
            }
            requireNonEmptyArray(config, "requiredEvidenceIds", path, 1, errors);
            checkEvidenceRefs(config, "requiredEvidenceIds", path, ctx, errors);
        }
    }

    /** REASONING_CONNECT: nodes[] >=2 and allowedRelations[] non-empty. */
    @Component
    public static class ReasoningConnectValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.REASONING_CONNECT; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            requireNonEmptyArray(config, "nodes", path, 2, errors);
            requireNonEmptyArray(config, "allowedRelations", path, 1, errors);
            if (config != null && config.has("nodes")) {
                collectIds(config.get("nodes"), path + ".config.nodes", errors);
            }
        }
    }

    /** MATCHING: pairs[] >=2; declared ids unique; correctPairs subset. */
    @Component
    public static class MatchingValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.MATCHING; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            requireNonEmptyArray(config, "pairs", path, 2, errors);
            if (config == null || !config.has("pairs")) return;
            JsonNode pairs = config.get("pairs");
            Set<String> leftIds = new java.util.HashSet<>();
            Set<String> rightIds = new java.util.HashSet<>();
            for (int i = 0; i < pairs.size(); i++) {
                JsonNode p = pairs.get(i);
                if (!p.isObject()) {
                    errors.add(new FieldError(path + ".config.pairs[" + i + "]",
                            "INVALID_CONFIG", "pair must be an object"));
                    continue;
                }
                JsonNode l = p.get("left"); JsonNode r = p.get("right");
                String lid = l != null && l.hasNonNull("id") ? l.get("id").asText() : null;
                String rid = r != null && r.hasNonNull("id") ? r.get("id").asText() : null;
                if (lid == null || !leftIds.add(lid)) {
                    errors.add(new FieldError(path + ".config.pairs[" + i + "].left.id",
                            lid == null ? "MISSING_FIELD" : "DUPLICATE_ID",
                            lid == null ? "left.id required" : "duplicate left.id '" + lid + "'"));
                }
                if (rid == null || !rightIds.add(rid)) {
                    errors.add(new FieldError(path + ".config.pairs[" + i + "].right.id",
                            rid == null ? "MISSING_FIELD" : "DUPLICATE_ID",
                            rid == null ? "right.id required" : "duplicate right.id '" + rid + "'"));
                }
            }
            // correctPairs (server-only) must reference declared ids if present
            JsonNode correct = config.get("correctPairs");
            if (correct != null && correct.isArray()) {
                for (int i = 0; i < correct.size(); i++) {
                    JsonNode cp = correct.get(i);
                    String l = cp.hasNonNull("left") ? cp.get("left").asText() : null;
                    String r = cp.hasNonNull("right") ? cp.get("right").asText() : null;
                    if (l == null || !leftIds.contains(l) || r == null || !rightIds.contains(r)) {
                        errors.add(new FieldError(path + ".config.correctPairs[" + i + "]",
                                "INVALID_CONFIG", "correctPairs must reference declared pair ids"));
                    }
                }
            }
        }
    }

    /** DRAG_ORDER: items[] >=2 unique ids; expectedOrder permutation at PUBLISH. */
    @Component
    public static class DragOrderValidator extends AbstractActivityValidator {
        @Override public ActivityType supports() { return ActivityType.DRAG_ORDER; }

        @Override
        public void validate(JsonNode activity, String path, ValidationContext ctx,
                             List<FieldError> errors) {
            JsonNode config = config(activity);
            requireNonEmptyArray(config, "items", path, 2, errors);
            if (config == null || !config.has("items")) return;
            Set<String> itemIds = collectIds(config.get("items"),
                    path + ".config.items", errors);
            JsonNode expected = config.get("expectedOrder");
            if (ctx.isPublish()) {
                if (expected == null || !expected.isArray()) {
                    errors.add(new FieldError(path + ".config.expectedOrder", "MISSING_FIELD",
                            "expectedOrder required for publish"));
                } else {
                    Set<String> expIds = collectStringIds(expected);
                    if (!expIds.equals(itemIds)) {
                        errors.add(new FieldError(path + ".config.expectedOrder",
                                "INVALID_CONFIG", "expectedOrder must be a permutation of items"));
                    }
                }
            }
        }
    }
}

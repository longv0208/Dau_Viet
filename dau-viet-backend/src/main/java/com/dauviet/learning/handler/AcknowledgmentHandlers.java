package com.dauviet.learning.handler;

import org.springframework.stereotype.Component;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.ActivitySubmission;
import com.dauviet.learning.contract.AttemptContext;
import com.dauviet.lesson.draft.ActivityType;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Passive/acknowledgment activities (BA: completion semantics, no grading).
 * READ/VIEW_IMAGE: any well-formed submit completes. REFLECTION_PROMPT:
 * non-empty text (<=4000 chars) or a valid config.options[].id completes.
 */
public final class AcknowledgmentHandlers {

    private AcknowledgmentHandlers() {
    }

    private static ObjectNode outcomeNode(JsonNodeFactory f) {
        return f.objectNode();
    }

    @Component
    public static class ReadHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.READ; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNodeFactory f = JsonNodeFactory.instance;
            return result(ActivityResult.COMPLETED, true,
                    outcomeNode(f).put("viewed", true),
                    feedbackFor(ctx.activity(), ActivityResult.COMPLETED));
        }
    }

    @Component
    public static class ViewImageHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.VIEW_IMAGE; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = config(ctx.activity());
            if (config != null && config.hasNonNull("imageAssetId")) {
                String assetId = config.get("imageAssetId").asText();
                if (!hasAsset(ctx, assetId)) {
                    throw new com.dauviet.learning.domain.SnapshotInvalidForActivityException(
                            "imageAssetId not present in snapshot assets");
                }
            }
            JsonNodeFactory f = JsonNodeFactory.instance;
            return result(ActivityResult.COMPLETED, true,
                    outcomeNode(f).put("viewed", true),
                    feedbackFor(ctx.activity(), ActivityResult.COMPLETED));
        }

        private boolean hasAsset(AttemptContext ctx, String assetId) {
            JsonNode assets = ctx.snapshot().get("assets");
            if (assets == null || !assets.isArray()) return false;
            for (JsonNode a : assets) {
                if (assetId.equals(a.path("id").asText(null))) return true;
            }
            return false;
        }
    }

    @Component
    public static class ReflectionPromptHandler extends AbstractActivityHandler {
        private static final int MAX_TEXT = 4000;

        @Override public ActivityType supports() { return ActivityType.REFLECTION_PROMPT; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode answer = sub.answer();
            JsonNodeFactory f = JsonNodeFactory.instance;
            JsonNode text = answer == null ? null : answer.get("text");
            JsonNode optionId = answer == null ? null : answer.get("optionId");

            if (optionId != null && optionId.isTextual()) {
                java.util.Set<String> valid = objectIds(requireConfig(ctx.activity()), "options");
                if (!valid.isEmpty() && !valid.contains(optionId.asText())) {
                    throw new IllegalArgumentException("optionId is not a declared option");
                }
                return result(ActivityResult.COMPLETED, true,
                        outcomeNode(f).put("optionId", optionId.asText()),
                        feedbackFor(ctx.activity(), ActivityResult.COMPLETED));
            }
            if (text == null || !text.isTextual() || text.asText().isBlank()) {
                throw new IllegalArgumentException("reflection requires non-empty text or optionId");
            }
            if (text.asText().length() > MAX_TEXT) {
                throw new IllegalArgumentException("text exceeds " + MAX_TEXT + " chars");
            }
            return result(ActivityResult.COMPLETED, true,
                    outcomeNode(f).put("text", text.asText()),
                    feedbackFor(ctx.activity(), ActivityResult.COMPLETED));
        }
    }
}

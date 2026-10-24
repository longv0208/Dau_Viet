package com.dauviet.animation.domain;

import java.util.List;
import java.util.UUID;

/**
 * Animation module exceptions, grouped in one file (each is a thin carrier).
 * Mapped to the unified error envelope in GlobalExceptionHandler.
 */
public final class AnimationExceptions {

    private AnimationExceptions() {
    }

    /** 404 — animation template id not found. */
    public static class TemplateNotFoundException extends RuntimeException {
        public TemplateNotFoundException(String message) { super(message); }
    }

    /** 404 — animation scene id not found. */
    public static class SceneNotFoundException extends RuntimeException {
        public SceneNotFoundException(String message) { super(message); }
    }

    /** 404 — animation scene version id (or scene+versionNo) not found. */
    public static class SceneVersionNotFoundException extends RuntimeException {
        public SceneVersionNotFoundException(String message) { super(message); }
    }

    /** 409 — template code already taken (unique constraint). */
    public static class TemplateCodeTakenException extends RuntimeException {
        public TemplateCodeTakenException(String message) { super(message); }
    }

    /** 422 — template disabled, cannot be used for new scenes. */
    public static class TemplateDisabledException extends RuntimeException {
        public TemplateDisabledException(String message) { super(message); }
    }

    /** 409 — invalid status transition (e.g. publish an ARCHIVED scene). */
    public static class InvalidStatusTransitionException extends RuntimeException {
        public InvalidStatusTransitionException(String message) { super(message); }
    }

    /**
     * 422 — manifest validation failures. Carries structured
     * {path, code, message} errors (same shape as lesson draft validation).
     */
    public static class ManifestValidationException extends RuntimeException {
        private final List<ManifestFieldError> errors;

        public ManifestValidationException(List<ManifestFieldError> errors) {
            super("manifest validation failed (" + errors.size() + " errors)");
            this.errors = List.copyOf(errors);
        }

        public List<ManifestFieldError> getErrors() { return errors; }
    }

    /** One structured manifest validation error. */
    public record ManifestFieldError(String path, String code, String message) {
    }

    /**
     * 422 — uploaded HTML document validation failures. Same structured
     * {path, code, message} shape as ManifestValidationException.
     */
    public static class HtmlValidationException extends RuntimeException {
        private final List<ManifestFieldError> errors;

        public HtmlValidationException(List<ManifestFieldError> errors) {
            super("HTML validation failed (" + errors.size() + " errors)");
            this.errors = List.copyOf(errors);
        }

        public List<ManifestFieldError> getErrors() { return errors; }
    }

    /** 409 — asset still referenced by a published animation manifest. */
    public static class AssetInUseException extends RuntimeException {
        private final List<UUID> sceneVersionIds;

        public AssetInUseException(String message, List<UUID> sceneVersionIds) {
            super(message);
            this.sceneVersionIds = List.copyOf(sceneVersionIds);
        }

        public List<UUID> getSceneVersionIds() { return sceneVersionIds; }
    }
}

package com.dauviet.path.domain;

import java.util.Collections;
import java.util.List;

public final class LearningPathExceptions {

    private LearningPathExceptions() {}

    public static class PathNotFoundException extends RuntimeException {
        private final String pathCode;

        public PathNotFoundException(String pathCode) {
            super("No published learning path found for code: " + pathCode);
            this.pathCode = pathCode;
        }

        public String getPathCode() {
            return pathCode;
        }
    }

    public static class PathValidationException extends RuntimeException {
        private final List<String> errors;

        public PathValidationException(List<String> errors) {
            super("Learning path validation failed: " + String.join("; ", errors));
            this.errors = errors != null ? List.copyOf(errors) : Collections.emptyList();
        }

        public List<String> getErrors() {
            return errors;
        }
    }
}

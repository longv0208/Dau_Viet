package com.dauviet.common.error;

/**
 * Thrown when a requested resource does not exist or is not visible
 * to the caller (e.g. draft content for learners).
 */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }
}

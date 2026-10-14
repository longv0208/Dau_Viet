package com.dauviet.common.error;

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import com.dauviet.common.api.ApiError;
import com.dauviet.common.trace.TraceIdFilter;

import jakarta.validation.ConstraintViolationException;

/**
 * Maps exceptions to the unified {code,message,details,traceId} contract.
 * Never leaks stack traces or internal implementation details to clients.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
        Map<String, Object> details = new HashMap<>();
        for (FieldError fe : ex.getBindingResult().getFieldErrors()) {
            details.put(fe.getField(), fe.getDefaultMessage());
        }
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Validation failed", details);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiError> handleConstraint(ConstraintViolationException ex) {
        Map<String, Object> details = new HashMap<>();
        ex.getConstraintViolations().forEach(v -> details.put(v.getPropertyPath().toString(), v.getMessage()));
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Validation failed", details);
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiError> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        Map<String, Object> details = Map.of(
                "parameter", ex.getName(),
                "requiredType", ex.getRequiredType() == null ? "unknown" : ex.getRequiredType().getSimpleName()
        );
        // Path-variable UUID mismatch reads naturally as MALFORMED_ID for this API surface.
        if ("id".equals(ex.getName()) && ex.getRequiredType() != null
                && java.util.UUID.class.isAssignableFrom(ex.getRequiredType())) {
            return build(HttpStatus.BAD_REQUEST, ErrorCode.MALFORMED_ID, "Malformed id", details);
        }
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Invalid parameter", details);
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ApiError> handleMissingParam(MissingServletRequestParameterException ex) {
        Map<String, Object> details = Map.of("parameter", ex.getParameterName());
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Missing required parameter", details);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiError> handleUnreadable(HttpMessageNotReadableException ex) {
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Malformed request body", Map.of());
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiError> handleMethodNotAllowed(HttpRequestMethodNotSupportedException ex) {
        Map<String, Object> details = Map.of("method", ex.getMethod());
        return build(HttpStatus.METHOD_NOT_ALLOWED, ErrorCode.METHOD_NOT_ALLOWED, "Method not allowed", details);
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiError> handleNoResource(NoResourceFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND, "Resource not found", Map.of());
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(ResourceNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.EVENT_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiError> handleIllegalArgument(IllegalArgumentException ex) {
        Map<String, Object> details = Map.of("reason", ex.getMessage() == null ? "invalid argument" : ex.getMessage());
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Invalid request", details);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGeneric(Exception ex) {
        String traceId = MDC.get(TraceIdFilter.MDC_KEY);
        log.error("Unhandled exception traceId={}", traceId, ex);
        return build(HttpStatus.INTERNAL_SERVER_ERROR, ErrorCode.INTERNAL_ERROR,
                "An unexpected error occurred", Map.of());
    }

    private ResponseEntity<ApiError> build(HttpStatus status, ErrorCode code,
                                           String message, Map<String, Object> details) {
        String traceId = MDC.get(TraceIdFilter.MDC_KEY);
        ApiError body = ApiError.of(code.name(), message, details, traceId);
        return ResponseEntity.status(status).body(body);
    }
}

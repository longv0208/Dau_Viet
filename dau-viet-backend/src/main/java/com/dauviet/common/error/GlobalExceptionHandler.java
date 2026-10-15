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

    @ExceptionHandler(com.dauviet.auth.domain.EmailTakenException.class)
    public ResponseEntity<ApiError> handleEmailTaken(
            com.dauviet.auth.domain.EmailTakenException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.EMAIL_TAKEN,
                "Email already registered", Map.of());
    }

    @ExceptionHandler(com.dauviet.auth.domain.AuthenticationFailedException.class)
    public ResponseEntity<ApiError> handleAuthFailed(
            com.dauviet.auth.domain.AuthenticationFailedException ex) {
        return build(HttpStatus.UNAUTHORIZED, ErrorCode.INVALID_CREDENTIALS,
                "Invalid credentials", Map.of());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiError> handleIllegalArgument(IllegalArgumentException ex) {
        Map<String, Object> details = Map.of("reason", ex.getMessage() == null ? "invalid argument" : ex.getMessage());
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Invalid request", details);
    }

    @ExceptionHandler(com.dauviet.lesson.domain.InvalidStatusTransitionException.class)
    public ResponseEntity<ApiError> handleInvalidTransition(
            com.dauviet.lesson.domain.InvalidStatusTransitionException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.INVALID_STATUS_TRANSITION, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.EventInUseException.class)
    public ResponseEntity<ApiError> handleEventInUse(
            com.dauviet.lesson.domain.EventInUseException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.EVENT_IN_USE, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.LessonNotFoundException.class)
    public ResponseEntity<ApiError> handleLessonNotFound(
            com.dauviet.lesson.domain.LessonNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.LESSON_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.TemplateNotFoundException.class)
    public ResponseEntity<ApiError> handleTemplateNotFound(
            com.dauviet.lesson.domain.TemplateNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.TEMPLATE_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.TemplateDisabledException.class)
    public ResponseEntity<ApiError> handleTemplateDisabled(
            com.dauviet.lesson.domain.TemplateDisabledException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.TEMPLATE_DISABLED, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.DraftSchemaInvalidException.class)
    public ResponseEntity<ApiError> handleDraftInvalid(
            com.dauviet.lesson.domain.DraftSchemaInvalidException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.DRAFT_SCHEMA_INVALID, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.draft.DraftValidationException.class)
    public ResponseEntity<ApiError> handleDraftValidation(
            com.dauviet.lesson.draft.DraftValidationException ex) {
        Map<String, Object> details = Map.of("errors", ex.getErrors().stream()
                .map(e -> Map.of("path", e.path(), "code", e.code(), "message", e.message()))
                .toList());
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.DRAFT_SCHEMA_INVALID,
                "Draft validation failed", details);
    }

    @ExceptionHandler(com.dauviet.lesson.domain.StageNotFoundException.class)
    public ResponseEntity<ApiError> handleStageNotFound(
            com.dauviet.lesson.domain.StageNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.STAGE_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.ActivityNotFoundException.class)
    public ResponseEntity<ApiError> handleActivityNotFound(
            com.dauviet.lesson.domain.ActivityNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.ACTIVITY_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.EvidenceNotFoundException.class)
    public ResponseEntity<ApiError> handleEvidenceNotFound(
            com.dauviet.lesson.domain.EvidenceNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.EVIDENCE_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.EvidenceInUseException.class)
    public ResponseEntity<ApiError> handleEvidenceInUse(
            com.dauviet.lesson.domain.EvidenceInUseException ex) {
        Map<String, Object> details = ex.getLessonIds().isEmpty()
                ? Map.of()
                : Map.of("lessonIds", ex.getLessonIds());
        return build(HttpStatus.CONFLICT, ErrorCode.EVIDENCE_IN_USE, ex.getMessage(), details);
    }

    @ExceptionHandler(com.dauviet.lesson.domain.AssetNotFoundException.class)
    public ResponseEntity<ApiError> handleAssetNotFound(
            com.dauviet.lesson.domain.AssetNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.ASSET_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.LessonNotPublishedException.class)
    public ResponseEntity<ApiError> handleLessonNotPublished(
            com.dauviet.lesson.domain.LessonNotPublishedException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.LESSON_NOT_PUBLISHED, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.VersionNotFoundException.class)
    public ResponseEntity<ApiError> handleVersionNotFound(
            com.dauviet.lesson.domain.VersionNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.VERSION_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.lesson.domain.TemplateSchemaMismatchException.class)
    public ResponseEntity<ApiError> handleTemplateSchemaMismatch(
            com.dauviet.lesson.domain.TemplateSchemaMismatchException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.TEMPLATE_SCHEMA_MISMATCH,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(org.springframework.orm.ObjectOptimisticLockingFailureException.class)
    public ResponseEntity<ApiError> handleOptimisticLock(
            org.springframework.orm.ObjectOptimisticLockingFailureException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.OPTIMISTIC_LOCK_CONFLICT,
                "Resource was modified concurrently; reload and retry", Map.of());
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

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

    @ExceptionHandler(org.springframework.web.bind.MissingRequestHeaderException.class)
    public ResponseEntity<ApiError> handleMissingHeader(
            org.springframework.web.bind.MissingRequestHeaderException ex) {
        Map<String, Object> details = Map.of("header", ex.getHeaderName());
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR,
                "Missing required header: " + ex.getHeaderName(), details);
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

    @ExceptionHandler(com.dauviet.reward.application.ItemRuleException.class)
    public ResponseEntity<ApiError> handleItemRule(
            com.dauviet.reward.application.ItemRuleException ex) {
        // Cáº¥u hĂ¬nh rule v2 sai grammar/reference â†’ 400 sáº¡ch (ITEM-06), khĂ´ng
        // bao giá» Ä‘á»ƒ lá»t thĂ nh 500 khi admin publish rule lá»—i.
        Map<String, Object> details = Map.of("reason",
                ex.getMessage() == null ? "invalid rule" : ex.getMessage());
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR,
                "Invalid unlock rule", details);
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

    @ExceptionHandler(com.dauviet.lesson.domain.TemplateCodeTakenException.class)
    public ResponseEntity<ApiError> handleTemplateCodeTaken(
            com.dauviet.lesson.domain.TemplateCodeTakenException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.TEMPLATE_CODE_TAKEN, ex.getMessage(), Map.of());
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

    @ExceptionHandler(com.dauviet.lesson.domain.InvalidAssetUploadException.class)
    public ResponseEntity<ApiError> handleInvalidAssetUpload(
            com.dauviet.lesson.domain.InvalidAssetUploadException ex) {
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, ex.getMessage(), Map.of());
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

    @ExceptionHandler(com.dauviet.lesson.domain.SnapshotCorruptException.class)
    public ResponseEntity<ApiError> handleSnapshotCorrupt(
            com.dauviet.lesson.domain.SnapshotCorruptException ex) {
        String traceId = MDC.get(TraceIdFilter.MDC_KEY);
        log.error("corrupt snapshot_json traceId={} {}", traceId, ex.getMessage());
        return build(HttpStatus.INTERNAL_SERVER_ERROR, ErrorCode.SNAPSHOT_CORRUPT,
                "Lesson content is unavailable", Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.AttemptNotFoundException.class)
    public ResponseEntity<ApiError> handleAttemptNotFound(
            com.dauviet.learning.domain.AttemptNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.ATTEMPT_NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.AttemptNotOwnedException.class)
    public ResponseEntity<ApiError> handleAttemptNotOwned(
            com.dauviet.learning.domain.AttemptNotOwnedException ex) {
        return build(HttpStatus.FORBIDDEN, ErrorCode.ATTEMPT_NOT_OWNER, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.AttemptNotInProgressException.class)
    public ResponseEntity<ApiError> handleAttemptNotInProgress(
            com.dauviet.learning.domain.AttemptNotInProgressException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.ATTEMPT_NOT_IN_PROGRESS, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.AttemptAlreadyCompletedException.class)
    public ResponseEntity<ApiError> handleAttemptAlreadyCompleted(
            com.dauviet.learning.domain.AttemptAlreadyCompletedException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.ATTEMPT_ALREADY_COMPLETED, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.ActivityNotAvailableException.class)
    public ResponseEntity<ApiError> handleActivityNotAvailable(
            com.dauviet.learning.domain.ActivityNotAvailableException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.ACTIVITY_NOT_AVAILABLE, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.LessonVersionMismatchException.class)
    public ResponseEntity<ApiError> handleLessonVersionMismatch(
            com.dauviet.learning.domain.LessonVersionMismatchException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.LESSON_VERSION_MISMATCH, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.UnsupportedActivityTypeException.class)
    public ResponseEntity<ApiError> handleUnsupportedActivityType(
            com.dauviet.learning.domain.UnsupportedActivityTypeException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.UNSUPPORTED_ACTIVITY_TYPE,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.SnapshotInvalidForActivityException.class)
    public ResponseEntity<ApiError> handleSnapshotInvalidForActivity(
            com.dauviet.learning.domain.SnapshotInvalidForActivityException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.SNAPSHOT_INVALID_FOR_ACTIVITY,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.IdempotencyConflictException.class)
    public ResponseEntity<ApiError> handleIdempotencyConflict(
            com.dauviet.learning.domain.IdempotencyConflictException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.IDEMPOTENCY_CONFLICT,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.learning.domain.AttemptIncompleteException.class)
    public ResponseEntity<ApiError> handleAttemptIncomplete(
            com.dauviet.learning.domain.AttemptIncompleteException ex) {
        Map<String, Object> details = ex.getDetail() == null
                ? Map.of() : Map.of("completion", ex.getDetail());
        return build(HttpStatus.CONFLICT, ErrorCode.ATTEMPT_NOT_COMPLETE,
                ex.getMessage(), details);
    }

    @ExceptionHandler(com.dauviet.energy.domain.EnergyDepletedException.class)
    public ResponseEntity<ApiError> handleEnergyDepleted(
            com.dauviet.energy.domain.EnergyDepletedException ex) {
        // details mang thá»i gian server tĂ­nh â€” client Ä‘á»“ng bá»™ countdown mĂ 
        // khĂ´ng cáº§n Ä‘oĂ¡n; khĂ´ng lá»™ Ä‘Ă¡p Ă¡n/rule cháº¥m.
        Map<String, Object> details = new java.util.HashMap<>();
        details.put("currentEnergy", 0);
        details.put("serverTime", ex.getServerTime() == null
                ? null : ex.getServerTime().toString());
        details.put("nextRecoveryAt", ex.getNextRecoveryAt() == null
                ? null : ex.getNextRecoveryAt().toString());
        return build(HttpStatus.CONFLICT, ErrorCode.ENERGY_DEPLETED,
                ex.getMessage(), details);
    }
    /* ---------- GAME-07 (Issue #28): Viện Thái Y ---------- */

    @ExceptionHandler(com.dauviet.energy.domain.EnergyRefillExceptions
            .RemedyNotFoundException.class)
    public ResponseEntity<ApiError> handleRemedyNotFound(
            com.dauviet.energy.domain.EnergyRefillExceptions
                    .RemedyNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.REMEDY_NOT_FOUND,
                ex.getMessage(), Map.of("code", ex.getCode()));
    }

    @ExceptionHandler(com.dauviet.energy.domain.EnergyRefillExceptions
            .RefillNotEligibleException.class)
    public ResponseEntity<ApiError> handleRefillNotEligible(
            com.dauviet.energy.domain.EnergyRefillExceptions
                    .RefillNotEligibleException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY,
                ErrorCode.REFILL_NOT_ELIGIBLE, ex.getMessage(),
                ex.details());
    }

    @ExceptionHandler(com.dauviet.energy.domain.EnergyRefillExceptions
            .RefillRateLimitedException.class)
    public ResponseEntity<ApiError> handleRefillRateLimited(
            com.dauviet.energy.domain.EnergyRefillExceptions
                    .RefillRateLimitedException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.REFILL_RATE_LIMITED,
                ex.getMessage(), ex.details());
    }

    @ExceptionHandler(com.dauviet.learning.domain.ResultNotFoundException.class)
    public ResponseEntity<ApiError> handleResultNotFound(
            com.dauviet.learning.domain.ResultNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.RESULT_NOT_FOUND,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.collection.domain.CollectedEvidenceNotFoundException.class)
    public ResponseEntity<ApiError> handleCollectedEvidenceNotFound(
            com.dauviet.collection.domain.CollectedEvidenceNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.COLLECTION_ITEM_NOT_FOUND,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.collection.domain.DossierNotFoundException.class)
    public ResponseEntity<ApiError> handleDossierNotFound(
            com.dauviet.collection.domain.DossierNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.DOSSIER_NOT_FOUND,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.collection.domain.PolicyValidationException.class)
    public ResponseEntity<ApiError> handlePolicyValidation(
            com.dauviet.collection.domain.PolicyValidationException ex) {
        Map<String, Object> details = Map.of("errors", ex.getErrors());
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.VALIDATION_ERROR,
                "Policy validation failed", details);
    }

    /* ---------- animation engine ---------- */

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.TemplateNotFoundException.class)
    public ResponseEntity<ApiError> handleAnimationTemplateNotFound(
            com.dauviet.animation.domain.AnimationExceptions.TemplateNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.ANIMATION_TEMPLATE_NOT_FOUND,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.SceneNotFoundException.class)
    public ResponseEntity<ApiError> handleAnimationSceneNotFound(
            com.dauviet.animation.domain.AnimationExceptions.SceneNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.ANIMATION_SCENE_NOT_FOUND,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.SceneVersionNotFoundException.class)
    public ResponseEntity<ApiError> handleAnimationSceneVersionNotFound(
            com.dauviet.animation.domain.AnimationExceptions.SceneVersionNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.ANIMATION_SCENE_VERSION_NOT_FOUND,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.TemplateCodeTakenException.class)
    public ResponseEntity<ApiError> handleAnimationTemplateCodeTaken(
            com.dauviet.animation.domain.AnimationExceptions.TemplateCodeTakenException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.TEMPLATE_CODE_TAKEN, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.TemplateDisabledException.class)
    public ResponseEntity<ApiError> handleAnimationTemplateDisabled(
            com.dauviet.animation.domain.AnimationExceptions.TemplateDisabledException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.TEMPLATE_DISABLED,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.InvalidStatusTransitionException.class)
    public ResponseEntity<ApiError> handleAnimationInvalidTransition(
            com.dauviet.animation.domain.AnimationExceptions.InvalidStatusTransitionException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.INVALID_STATUS_TRANSITION,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.ManifestValidationException.class)
    public ResponseEntity<ApiError> handleManifestValidation(
            com.dauviet.animation.domain.AnimationExceptions.ManifestValidationException ex) {
        Map<String, Object> details = Map.of("errors", ex.getErrors().stream()
                .map(e -> Map.of("path", e.path(), "code", e.code(), "message", e.message()))
                .toList());
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.ANIMATION_MANIFEST_INVALID,
                "Animation manifest validation failed", details);
    }

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.HtmlValidationException.class)
    public ResponseEntity<ApiError> handleHtmlValidation(
            com.dauviet.animation.domain.AnimationExceptions.HtmlValidationException ex) {
        Map<String, Object> details = Map.of("errors", ex.getErrors().stream()
                .map(e -> Map.of("path", e.path(), "code", e.code(), "message", e.message()))
                .toList());
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.ANIMATION_HTML_INVALID,
                "Uploaded HTML is not a valid self-contained animation", details);
    }

    @ExceptionHandler(com.dauviet.animation.domain.AnimationExceptions.AssetInUseException.class)
    public ResponseEntity<ApiError> handleAnimationAssetInUse(
            com.dauviet.animation.domain.AnimationExceptions.AssetInUseException ex) {
        Map<String, Object> details = ex.getSceneVersionIds().isEmpty()
                ? Map.of()
                : Map.of("sceneVersionIds", ex.getSceneVersionIds());
        return build(HttpStatus.CONFLICT, ErrorCode.ASSET_IN_USE, ex.getMessage(), details);
    }

    /* ---------- ISLAND-BE-01: Äáº£o Di Sáº£n + Wallet + Shop ---------- */

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.InsufficientFundsException.class)
    public ResponseEntity<ApiError> handleInsufficientFunds(
            com.dauviet.island.domain.IslandExceptions.InsufficientFundsException ex) {
        Map<String, Object> details = Map.of(
                "balance", ex.getBalance(), "price", ex.getPrice());
        return build(HttpStatus.CONFLICT, ErrorCode.INSUFFICIENT_FUNDS,
                ex.getMessage(), details);
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.ItemNotOwnedException.class)
    public ResponseEntity<ApiError> handleItemNotOwned(
            com.dauviet.island.domain.IslandExceptions.ItemNotOwnedException ex) {
        return build(HttpStatus.FORBIDDEN, ErrorCode.ITEM_NOT_OWNED,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.ItemAlreadyOwnedException.class)
    public ResponseEntity<ApiError> handleItemAlreadyOwned(
            com.dauviet.island.domain.IslandExceptions.ItemAlreadyOwnedException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.ITEM_ALREADY_OWNED,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.ItemNotPlaceableException.class)
    public ResponseEntity<ApiError> handleItemNotPlaceable(
            com.dauviet.island.domain.IslandExceptions.ItemNotPlaceableException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.ITEM_NOT_PLACEABLE,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.SlotLockedException.class)
    public ResponseEntity<ApiError> handleSlotLocked(
            com.dauviet.island.domain.IslandExceptions.SlotLockedException ex) {
        Map<String, Object> details = Map.of(
                "tierRequired", ex.getTierRequired(),
                "currentTier", ex.getCurrentTier());
        return build(HttpStatus.FORBIDDEN, ErrorCode.SLOT_LOCKED,
                ex.getMessage(), details);
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.SlotOccupiedException.class)
    public ResponseEntity<ApiError> handleSlotOccupied(
            com.dauviet.island.domain.IslandExceptions.SlotOccupiedException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.SLOT_OCCUPIED,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.SlotNotFoundException.class)
    public ResponseEntity<ApiError> handleSlotNotFound(
            com.dauviet.island.domain.IslandExceptions.SlotNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.SLOT_NOT_FOUND,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.IslandUpgradeNotEligibleException.class)
    public ResponseEntity<ApiError> handleUpgradeNotEligible(
            com.dauviet.island.domain.IslandExceptions.IslandUpgradeNotEligibleException ex) {
        Map<String, Object> details = Map.of(
                "targetTier", ex.getTargetTier(),
                "requiredEvents", ex.getRequiredEvents(),
                "currentEvents", ex.getCurrentEvents());
        return build(HttpStatus.UNPROCESSABLE_ENTITY,
                ErrorCode.ISLAND_UPGRADE_NOT_ELIGIBLE,
                ex.getMessage(), details);
    }

    /** 422 â€” Level tĂ i khoáº£n chÆ°a Ä‘á»§ Ä‘á»ƒ nĂ¢ng Ä‘áº£o (ISLAND-01). */
    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.IslandUpgradeInsufficientLevelException.class)
    public ResponseEntity<ApiError> handleUpgradeInsufficientLevel(
            com.dauviet.island.domain.IslandExceptions.IslandUpgradeInsufficientLevelException ex) {
        Map<String, Object> details = Map.of(
                "targetTier",    ex.getTargetTier(),
                "requiredLevel", ex.getRequiredLevel(),
                "currentLevel",  ex.getCurrentLevel(),
                "currentExp",    ex.getCurrentExp(),
                "requiredExp",   ex.getRequiredExp());
        return build(HttpStatus.UNPROCESSABLE_ENTITY,
                ErrorCode.ISLAND_UPGRADE_INSUFFICIENT_LEVEL,
                ex.getMessage(), details);
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.StaleIslandRevisionException.class)
    public ResponseEntity<ApiError> handleStaleIslandRevision(
            com.dauviet.island.domain.IslandExceptions.StaleIslandRevisionException ex) {
        Map<String, Object> details = Map.of(
                "expectedRevision", ex.getExpected(),
                "actualRevision", ex.getActual());
        return build(HttpStatus.CONFLICT, ErrorCode.STALE_ISLAND_REVISION,
                ex.getMessage(), details);
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.ItemNotForSaleException.class)
    public ResponseEntity<ApiError> handleItemNotForSale(
            com.dauviet.island.domain.IslandExceptions.ItemNotForSaleException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.ITEM_NOT_FOR_SALE,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.FeatureDisabledException.class)
    public ResponseEntity<ApiError> handleFeatureDisabled(
            com.dauviet.island.domain.IslandExceptions.FeatureDisabledException ex) {
        return build(HttpStatus.SERVICE_UNAVAILABLE, ErrorCode.FEATURE_DISABLED,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.common.error.FeatureDisabledException.class)
    public ResponseEntity<ApiError> handleCommonFeatureDisabled(
            com.dauviet.common.error.FeatureDisabledException ex) {
        return build(HttpStatus.SERVICE_UNAVAILABLE, ErrorCode.FEATURE_DISABLED,
                ex.getMessage(), Map.of());
    }

    /* Issue #34 — OTP + Google auth failures. */

    @ExceptionHandler(com.dauviet.auth.domain.OtpException.Invalid.class)
    public ResponseEntity<ApiError> handleOtpInvalid(
            com.dauviet.auth.domain.OtpException.Invalid ex) {
        return build(HttpStatus.BAD_REQUEST, ErrorCode.OTP_INVALID,
                ex.getMessage(), Map.of("attemptsLeft", ex.getAttemptsLeft()));
    }

    @ExceptionHandler(com.dauviet.auth.domain.OtpException.Expired.class)
    public ResponseEntity<ApiError> handleOtpExpired(
            com.dauviet.auth.domain.OtpException.Expired ex) {
        return build(HttpStatus.BAD_REQUEST, ErrorCode.OTP_EXPIRED, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.auth.domain.OtpException.MaxAttemptsExceeded.class)
    public ResponseEntity<ApiError> handleOtpMaxAttempts(
            com.dauviet.auth.domain.OtpException.MaxAttemptsExceeded ex) {
        return build(HttpStatus.TOO_MANY_REQUESTS, ErrorCode.OTP_MAX_ATTEMPTS_EXCEEDED,
                ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.auth.domain.OtpException.ResendCooldown.class)
    public ResponseEntity<ApiError> handleOtpResendCooldown(
            com.dauviet.auth.domain.OtpException.ResendCooldown ex) {
        return build(HttpStatus.TOO_MANY_REQUESTS, ErrorCode.OTP_RESEND_COOLDOWN,
                ex.getMessage(), Map.of("retryAfterSeconds", ex.getRetryAfterSeconds()));
    }

    @ExceptionHandler(com.dauviet.auth.domain.OtpException.NoChallenge.class)
    public ResponseEntity<ApiError> handleOtpNoChallenge(
            com.dauviet.auth.domain.OtpException.NoChallenge ex) {
        return build(HttpStatus.BAD_REQUEST, ErrorCode.OTP_NO_CHALLENGE, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(com.dauviet.auth.domain.GoogleTokenInvalidException.class)
    public ResponseEntity<ApiError> handleGoogleTokenInvalid(
            com.dauviet.auth.domain.GoogleTokenInvalidException ex) {
        return build(HttpStatus.UNAUTHORIZED, ErrorCode.GOOGLE_TOKEN_INVALID,
                "Google sign-in failed", Map.of());
    }

    @ExceptionHandler(com.dauviet.auth.domain.GoogleEmailUnverifiedException.class)
    public ResponseEntity<ApiError> handleGoogleEmailUnverified(
            com.dauviet.auth.domain.GoogleEmailUnverifiedException ex) {
        return build(HttpStatus.FORBIDDEN, ErrorCode.GOOGLE_EMAIL_UNVERIFIED,
                "Verify your email before linking Google sign-in", Map.of());
    }

    /** 503 â€” Cáº¥u hĂ¬nh Island (tier policy hoáº·c level thresholds) khĂ´ng há»£p lá»‡ (ISLAND-02). */
    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.IslandConfigurationInvalidException.class)
    public ResponseEntity<ApiError> handleIslandConfigurationInvalid(
            com.dauviet.island.domain.IslandExceptions.IslandConfigurationInvalidException ex) {
        Map<String, Object> details = Map.of("targetTier", ex.getTargetTier());
        return build(HttpStatus.SERVICE_UNAVAILABLE,
                ErrorCode.ISLAND_CONFIGURATION_INVALID,
                ex.getMessage() != null ? ex.getMessage() : "Island configuration is invalid or incomplete; contact support",
                details);
    }

    @ExceptionHandler(com.dauviet.island.domain.IslandExceptions.IslandLayoutValidationException.class)
    public ResponseEntity<ApiError> handleIslandLayoutValidation(
            com.dauviet.island.domain.IslandExceptions.IslandLayoutValidationException ex) {
        Map<String, Object> details = Map.of("errors", ex.getErrors().stream()
                .map(e -> Map.of(
                        "objectType", e.objectType() == null ? "" : e.objectType(),
                        "objectKey", e.objectKey() == null ? "" : e.objectKey(),
                        "field", e.field() == null ? "" : e.field(),
                        "code", e.code() == null ? "" : e.code(),
                        "message", e.message() == null ? "" : e.message()))
                .toList());
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.VALIDATION_ERROR,
                ex.getMessage(), details);
    }

    /* ---------- PATH-01: Learning Path 2.0 ---------- */

    @ExceptionHandler(com.dauviet.path.domain.LearningPathExceptions.PathNotFoundException.class)
    public ResponseEntity<ApiError> handlePathNotFound(
            com.dauviet.path.domain.LearningPathExceptions.PathNotFoundException ex) {
        return build(HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND,
                ex.getMessage(), Map.of("pathCode", ex.getPathCode()));
    }

    @ExceptionHandler(com.dauviet.path.domain.LearningPathExceptions.PathValidationException.class)
    public ResponseEntity<ApiError> handlePathValidation(
            com.dauviet.path.domain.LearningPathExceptions.PathValidationException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.VALIDATION_ERROR,
                ex.getMessage(), Map.of("errors", ex.getErrors()));
    }

    @ExceptionHandler(com.dauviet.path.domain.LessonLockedByPathException.class)
    public ResponseEntity<ApiError> handleLessonLockedByPath(
            com.dauviet.path.domain.LessonLockedByPathException ex) {
        return build(HttpStatus.FORBIDDEN, ErrorCode.LESSON_LOCKED_BY_PATH,
                ex.getMessage(), Map.of("reason", "LEARNING_PATH_LOCKED"));
    }

    @ExceptionHandler(com.dauviet.path.domain.LearningPathExceptions.PathNodeInvalidParentException.class)
    public ResponseEntity<ApiError> handlePathNodeInvalidParent(
            com.dauviet.path.domain.LearningPathExceptions.PathNodeInvalidParentException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.PATH_NODE_INVALID_PARENT,
                ex.getMessage(), Map.of());
    }

    /**
     * GAME-06: bat ca hai â€” ObjectOptimisticLockingFailure (JPA/Hibernate)
     * lan OptimisticLockingFailureException (service throw thu cong cho
     * expectedPolicyVersion/expectedRowVersion mismatch). OLF la superclass
     * nen mot handler la du; @ExceptionHandler match subclass truoc.
     */
    @ExceptionHandler(org.springframework.dao.OptimisticLockingFailureException.class)
    public ResponseEntity<ApiError> handleOptimisticLock(
            org.springframework.dao.OptimisticLockingFailureException ex) {
        return build(HttpStatus.CONFLICT, ErrorCode.OPTIMISTIC_LOCK_CONFLICT,
                "Resource was modified concurrently; reload and retry", Map.of());
    }

    @ExceptionHandler(org.springframework.dao.DataIntegrityViolationException.class)
    public ResponseEntity<ApiError> handleDataIntegrityViolation(
            org.springframework.dao.DataIntegrityViolationException ex) {
        String traceId = MDC.get(TraceIdFilter.MDC_KEY);
        String raw = ex.getMostSpecificCause() != null && ex.getMostSpecificCause().getMessage() != null
                ? ex.getMostSpecificCause().getMessage()
                : (ex.getMessage() != null ? ex.getMessage() : "Data integrity violation");
        log.warn("Data integrity violation traceId={}: {}", traceId, raw);
        String friendly = resolveDataIntegrityMessage(raw);
        return build(HttpStatus.CONFLICT, ErrorCode.VALIDATION_ERROR,
                friendly, Map.of("reason", friendly, "cause", raw));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGeneric(Exception ex) {
        String traceId = MDC.get(TraceIdFilter.MDC_KEY);
        log.error("Unhandled exception traceId={}", traceId, ex);
        String reason = ex.getMessage() != null && !ex.getMessage().isBlank()
                ? ex.getMessage()
                : ex.getClass().getSimpleName();
        return build(HttpStatus.INTERNAL_SERVER_ERROR, ErrorCode.INTERNAL_ERROR,
                "Lỗi máy chủ: " + reason, Map.of("reason", reason));
    }

    private static String resolveDataIntegrityMessage(String raw) {
        if (raw == null) return "Dữ liệu bị trùng hoặc vi phạm ràng buộc cơ sở dữ liệu.";
        if (raw.contains("ux_path_chapter_version_sort")) {
            return "Thứ tự sắp xếp (sort_order) của đơn vị chương/thời kỳ bị trùng trong cùng cấp cha.";
        }
        if (raw.contains("ux_path_chapter_version_code") || raw.contains("learning_path_chapters_path_version_id_code_key")) {
            return "Mã chương/thời kỳ (code) đã tồn tại trong phiên bản lộ trình này.";
        }
        if (raw.contains("learning_path_versions")) {
            return "Phiên bản lộ trình hoặc bản nháp của mã lộ trình này đã tồn tại.";
        }
        if (raw.contains("duplicate key")) {
            return "Dữ liệu bị trùng khóa duy nhất trong cơ sở dữ liệu: " + raw;
        }
        return "Vi phạm ràng buộc dữ liệu: " + raw;
    }

    private ResponseEntity<ApiError> build(HttpStatus status, ErrorCode code,
                                           String message, Map<String, Object> details) {
        String traceId = MDC.get(TraceIdFilter.MDC_KEY);
        ApiError body = ApiError.of(code.name(), message, details, traceId);
        return ResponseEntity.status(status).body(body);
    }
}

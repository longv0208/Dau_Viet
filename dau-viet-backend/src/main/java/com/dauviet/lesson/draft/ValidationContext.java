package com.dauviet.lesson.draft;

import java.util.Set;
import java.util.UUID;

/**
 * Carries what a validator needs beyond the JSON itself:
 * the lesson's event (evidence refs must belong to it) and lookups
 * resolved by the caller so validators stay persistence-free.
 */
public record ValidationContext(
        UUID eventId,
        ValidationLevel level,
        Set<String> validEvidenceIds,
        Set<String> activeAssetIds) {

    /** True when an evidence id exists, belongs to this event, and is publishable. */
    public boolean evidenceUsable(String evidenceId) {
        return validEvidenceIds != null && validEvidenceIds.contains(evidenceId);
    }

    public boolean assetUsable(String assetId) {
        return activeAssetIds != null && activeAssetIds.contains(assetId);
    }

    public boolean isPublish() {
        return level == ValidationLevel.PUBLISH;
    }
}

package com.dauviet.common.error;

/**
 * A feature is switched off by configuration (e.g. Google sign-in with no
 * client-ids, shop disabled). Surfaced as 503 FEATURE_DISABLED.
 */
public class FeatureDisabledException extends RuntimeException {

    public FeatureDisabledException(String feature) {
        super(feature);
    }
}

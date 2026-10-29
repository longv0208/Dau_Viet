package com.dauviet.auth.application;

import org.springframework.context.annotation.Condition;
import org.springframework.context.annotation.ConditionContext;
import org.springframework.core.type.AnnotatedTypeMetadata;

/**
 * True when `dauviet.auth.google.client-ids` contains at least one
 * non-blank entry — @ConditionalOnProperty can't distinguish "set but
 * empty" from "unset", and SpEL can't express a lambda over the list.
 */
public class GoogleClientIdsConfiguredCondition implements Condition {

    @Override
    public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
        String raw = context.getEnvironment().getProperty("dauviet.auth.google.client-ids", "");
        for (String id : raw.split(",")) {
            if (!id.isBlank()) return true;
        }
        return false;
    }
}

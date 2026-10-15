package com.dauviet.learning.handler;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Component;

import com.dauviet.learning.domain.UnsupportedActivityTypeException;
import com.dauviet.lesson.draft.ActivityType;

/**
 * EnumMap registry of all ActivityHandler beans; fails fast at startup when
 * a type is missing or registered twice — same pattern as DraftValidator's
 * ActivityConfigValidator registry.
 */
@Component
public class ActivityHandlerRegistry {

    private final Map<ActivityType, ActivityHandler> handlers =
            new EnumMap<>(ActivityType.class);

    public ActivityHandlerRegistry(List<ActivityHandler> beans) {
        for (ActivityHandler h : beans) {
            ActivityHandler prev = handlers.put(h.supports(), h);
            if (prev != null) {
                throw new IllegalStateException(
                        "duplicate ActivityHandler for " + h.supports());
            }
        }
        for (ActivityType t : ActivityType.values()) {
            if (!handlers.containsKey(t)) {
                throw new IllegalStateException(
                        "missing ActivityHandler for " + t);
            }
        }
    }

    public ActivityHandler handlerFor(ActivityType type) {
        ActivityHandler h = handlers.get(type);
        if (h == null) {
            throw new UnsupportedActivityTypeException(
                    "no handler for activity type " + type);
        }
        return h;
    }
}

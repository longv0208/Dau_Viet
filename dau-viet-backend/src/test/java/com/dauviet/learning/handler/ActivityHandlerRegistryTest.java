package com.dauviet.learning.handler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.dauviet.lesson.draft.ActivityType;

class ActivityHandlerRegistryTest {

    private static List<ActivityHandler> allHandlers() {
        return List.of(
                new AcknowledgmentHandlers.ReadHandler(),
                new AcknowledgmentHandlers.ViewImageHandler(),
                new AcknowledgmentHandlers.ReflectionPromptHandler(),
                new ExploreMapHandler(),
                new SelectionHandlers.EvidenceSelectHandler(),
                new SelectionHandlers.HypothesisChoiceHandler(),
                new ScoredHandlers.MultipleChoiceHandler(),
                new ScoredHandlers.MatchingHandler(),
                new ScoredHandlers.DragOrderHandler(),
                new ReasoningHandlers.ReasoningConnectHandler(),
                new ReasoningHandlers.VerificationHandler(),
                new ReasoningHandlers.CerHandler());
    }

    @Test
    void allTwelveTypesRegistered() {
        ActivityHandlerRegistry registry = new ActivityHandlerRegistry(allHandlers());
        for (ActivityType t : ActivityType.values()) {
            assertThat(registry.handlerFor(t).supports()).isEqualTo(t);
        }
    }

    @Test
    void missingType_failsAtStartup() {
        List<ActivityHandler> incomplete = allHandlers().stream()
                .filter(h -> h.supports() != ActivityType.CER)
                .toList();
        assertThatThrownBy(() -> new ActivityHandlerRegistry(incomplete))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("CER");
    }

    @Test
    void duplicateType_failsAtStartup() {
        List<ActivityHandler> dup = new java.util.ArrayList<>(allHandlers());
        dup.add(new AcknowledgmentHandlers.ReadHandler());
        assertThatThrownBy(() -> new ActivityHandlerRegistry(dup))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("duplicate");
    }
}

package com.dauviet.learning.contract;

/** A stage hop decided by the transition resolver. */
public record NextStage(
        String stageId,
        String stageType,
        String reason) {

    public static final String FORWARD = "FORWARD";
    public static final String REVISE = "REVISE";
}

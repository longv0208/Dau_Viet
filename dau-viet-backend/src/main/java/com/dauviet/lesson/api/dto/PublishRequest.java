package com.dauviet.lesson.api.dto;

/** Optional optimistic-lock guard on publish. */
public record PublishRequest(Long expectedRowVersion) {
}

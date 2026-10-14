package com.dauviet.common.api;

import java.util.List;

import org.springframework.data.domain.Page;

/**
 * Stable pagination envelope for list endpoints; mirrors Spring Page metadata
 * while decoupling clients from Spring types.
 */
public record PageResponse<T>(
        List<T> content,
        int page,
        int size,
        long totalElements,
        int totalPages
) {
    public static <T> PageResponse<T> from(Page<T> page) {
        return new PageResponse<>(
                page.getContent(),
                page.getNumber(),
                page.getSize(),
                page.getTotalElements(),
                page.getTotalPages()
        );
    }
}

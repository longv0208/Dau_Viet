package com.dauviet.historicalevent.api;

import java.util.Set;
import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.api.PageResponse;
import com.dauviet.historicalevent.api.dto.HistoricalEventDetailDto;
import com.dauviet.historicalevent.api.dto.HistoricalEventSummaryDto;
import com.dauviet.historicalevent.application.HistoricalEventService;

/**
 * Public read API for published historical events.
 * Controller only validates input and delegates — no business rules here.
 */
@RestController
@RequestMapping("/api/v1/events")
@Validated
public class HistoricalEventController {

    /** Sort whitelist — prevents arbitrary property paths / SQL errors. */
    private static final Set<String> ALLOWED_SORT_FIELDS = Set.of("startYear", "title");
    private static final Sort DEFAULT_SORT = Sort.by(Sort.Direction.ASC, "startYear");

    private final HistoricalEventService service;

    public HistoricalEventController(HistoricalEventService service) {
        this.service = service;
    }

    @GetMapping
    public PageResponse<HistoricalEventSummaryDto> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "startYear,asc") String sort) {
        Pageable pageable = PageRequest.of(page, size, parseSort(sort));
        Page<HistoricalEventSummaryDto> result = service.listPublished(pageable);
        return PageResponse.from(result);
    }

    @GetMapping("/{id}")
    public HistoricalEventDetailDto getById(@PathVariable UUID id) {
        return service.getPublishedById(id);
    }

    private Sort parseSort(String sort) {
        if (sort == null || sort.isBlank()) {
            return DEFAULT_SORT;
        }
        String[] parts = sort.split(",");
        if (parts.length > 2) {
            throw new IllegalArgumentException("Malformed sort parameter: " + sort);
        }
        String field = parts[0].trim();
        if (!ALLOWED_SORT_FIELDS.contains(field)) {
            throw new IllegalArgumentException("Unsupported sort field: " + field);
        }
        if (parts.length == 1) {
            return Sort.by(Sort.Direction.ASC, field);
        }
        String dir = parts[1].trim().toLowerCase();
        if (!dir.equals("asc") && !dir.equals("desc")) {
            throw new IllegalArgumentException("Unsupported sort direction: " + parts[1].trim());
        }
        return Sort.by(Sort.Direction.fromString(dir), field);
    }
}

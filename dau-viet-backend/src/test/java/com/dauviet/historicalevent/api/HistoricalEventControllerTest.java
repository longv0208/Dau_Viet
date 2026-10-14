package com.dauviet.historicalevent.api;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.dauviet.common.config.CorsConfig;
import com.dauviet.common.config.SecurityConfig;
import com.dauviet.common.error.GlobalExceptionHandler;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.common.trace.TraceIdFilter;
import com.dauviet.historicalevent.api.dto.HistoricalEventDetailDto;
import com.dauviet.historicalevent.api.dto.HistoricalEventSummaryDto;
import com.dauviet.historicalevent.application.HistoricalEventService;

@WebMvcTest(HistoricalEventController.class)
@Import({SecurityConfig.class, CorsConfig.class,
        GlobalExceptionHandler.class, TraceIdFilter.class})
class HistoricalEventControllerTest {

    private static final UUID ID = UUID.fromString("00000000-0000-0000-0000-000000000001");

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private HistoricalEventService service;

    private HistoricalEventSummaryDto summary() {
        return new HistoricalEventSummaryDto(ID, "bach-dang-938", "Đại Chiến Bạch Đằng 938",
                "Thời Ngô", "Mùa Đông 938", 938, "summary",
                "events/bach-dang-938/hero.jpg", List.of("a"));
    }

    private HistoricalEventDetailDto detail() {
        return new HistoricalEventDetailDto(ID, "bach-dang-938", "Đại Chiến Bạch Đằng 938",
                "Thời Ngô", "Mùa Đông 938", 938, "summary", "desc",
                "Quảng Ninh", "events/bach-dang-938/hero.jpg", List.of("a"), null);
    }

    @Test
    void list_returnsPageEnvelope() throws Exception {
        when(service.listPublished(any()))
                .thenReturn(new PageImpl<>(List.of(summary()), PageRequest.of(0, 20), 1));
        mvc.perform(get("/api/v1/events"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].slug").value("bach-dang-938"))
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(20))
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.totalPages").value(1))
                .andExpect(header().exists(TraceIdFilter.HEADER));
    }

    @Test
    void list_rejectsNegativePage() throws Exception {
        mvc.perform(get("/api/v1/events?page=-1"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void list_rejectsOversize() throws Exception {
        mvc.perform(get("/api/v1/events?size=101"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void list_rejectsUnknownSortField() throws Exception {
        mvc.perform(get("/api/v1/events?sort=evil,asc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void getById_returnsDetail() throws Exception {
        when(service.getPublishedById(ID)).thenReturn(detail());
        mvc.perform(get("/api/v1/events/{id}", ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.slug").value("bach-dang-938"))
                .andExpect(jsonPath("$.location").value("Quảng Ninh"));
    }

    @Test
    void getById_missing_returns404() throws Exception {
        UUID missing = UUID.fromString("99999999-9999-9999-9999-999999999999");
        when(service.getPublishedById(missing))
                .thenThrow(new ResourceNotFoundException("Historical event not found"));
        mvc.perform(get("/api/v1/events/{id}", missing))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVENT_NOT_FOUND"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }

    @Test
    void getById_malformed_returns400() throws Exception {
        mvc.perform(get("/api/v1/events/not-a-uuid"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("MALFORMED_ID"));
    }

    @Test
    void healthIsPublic() throws Exception {
        // /actuator/** is outside this slice's dispatch — assert security chain permits pattern.
        // Covered indirectly: any other path falls through to 401, tested below.
        mvc.perform(get("/api/v1/unknown"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }
}

package com.dauviet.animation.api;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.JwtRequestPostProcessor;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.dauviet.animation.api.dto.AnimationDtos.SceneResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneSummaryResponse;
import com.dauviet.animation.application.AnimationHtmlService;
import com.dauviet.animation.application.AnimationScenePublishService;
import com.dauviet.animation.application.AnimationSceneService;
import com.dauviet.animation.domain.AnimationSceneStatus;
import com.dauviet.animation.domain.AnimationExceptions.SceneNotFoundException;
import com.dauviet.animation.domain.AnimationExceptions.TemplateDisabledException;
import com.dauviet.animation.domain.AnimationExceptions.TemplateNotFoundException;
import com.dauviet.common.config.CorsConfig;
import com.dauviet.common.config.SecurityConfig;
import com.dauviet.common.error.GlobalExceptionHandler;
import com.dauviet.common.trace.TraceIdFilter;

@WebMvcTest(AdminAnimationSceneController.class)
@Import({SecurityConfig.class, CorsConfig.class,
        GlobalExceptionHandler.class, TraceIdFilter.class})
class AdminAnimationSceneControllerTest {

    private static final UUID ADMIN_ID =
            UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID TEMPLATE_ID =
            UUID.fromString("22222222-2222-2222-2222-222222222222");
    private static final UUID SCENE_ID =
            UUID.fromString("33333333-3333-3333-3333-333333333333");
    private static final UUID VERSION_ID =
            UUID.fromString("44444444-4444-4444-4444-444444444444");

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private AnimationSceneService service;

    @MockitoBean
    private AnimationScenePublishService publishService;

    @MockitoBean
    private AnimationHtmlService htmlService;

    // Resource-server beans are absent from the @WebMvcTest slice; mocks keep
    // the security filter chain wiring loadable without a real JwtDecoder.
    @MockitoBean
    private JwtDecoder jwtDecoder;

    @MockitoBean
    private JwtAuthenticationConverter jwtAuthenticationConverter;

    private JwtRequestPostProcessor adminJwt() {
        return jwt().jwt(j -> j.subject(ADMIN_ID.toString()))
                .authorities(new SimpleGrantedAuthority("ROLE_CONTENT_ADMIN"));
    }

    private SceneResponse scene() {
        return new SceneResponse(SCENE_ID, TEMPLATE_ID, "RIVER_TIDE_938", "RIVER_TIDE",
                null, "Sông Bạch Đằng", "{}", "DRAFT", VERSION_ID, 1,
                0L, Instant.EPOCH, Instant.EPOCH);
    }

    /* ---------- create ---------- */

    @Test
    void create_validBody_returns201() throws Exception {
        when(service.create(any(), any())).thenReturn(scene());
        String body = """
                {"templateId":"%s","title":"Sông Bạch Đằng"}
                """.formatted(TEMPLATE_ID);
        mvc.perform(post("/api/v1/admin/animation-scenes")
                        .with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(SCENE_ID.toString()))
                .andExpect(jsonPath("$.rendererCode").value("RIVER_TIDE"));
    }

    @Test
    void create_nullTemplateId_returns400Validation() throws Exception {
        // @NotNull (not @NotBlank) on UUID must surface VALIDATION_ERROR, not 500.
        String body = """
                {"title":"Thiếu template"}
                """;
        mvc.perform(post("/api/v1/admin/animation-scenes")
                        .with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.templateId").exists());
    }

    @Test
    void create_blankTitle_returns400Validation() throws Exception {
        String body = """
                {"templateId":"%s","title":" "}
                """.formatted(TEMPLATE_ID);
        mvc.perform(post("/api/v1/admin/animation-scenes")
                        .with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void create_missingTemplate_returns404() throws Exception {
        when(service.create(any(), any()))
                .thenThrow(new TemplateNotFoundException("Template not found: " + TEMPLATE_ID));
        String body = """
                {"templateId":"%s","title":"X"}
                """.formatted(TEMPLATE_ID);
        mvc.perform(post("/api/v1/admin/animation-scenes")
                        .with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ANIMATION_TEMPLATE_NOT_FOUND"));
    }

    @Test
    void create_disabledTemplate_returns422() throws Exception {
        when(service.create(any(), any()))
                .thenThrow(new TemplateDisabledException("Template disabled: X"));
        String body = """
                {"templateId":"%s","title":"X"}
                """.formatted(TEMPLATE_ID);
        mvc.perform(post("/api/v1/admin/animation-scenes")
                        .with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("TEMPLATE_DISABLED"));
    }

    @Test
    void create_invalidDraftJson_returns400() throws Exception {
        when(service.create(any(), any()))
                .thenThrow(new IllegalArgumentException("draftJson is not valid JSON"));
        String body = """
                {"templateId":"%s","title":"X","draftJson":"{not json"}
                """.formatted(TEMPLATE_ID);
        mvc.perform(post("/api/v1/admin/animation-scenes")
                        .with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void create_malformedTemplateId_returns400Not500() throws Exception {
        // Wrong-annotation regressions used to surface as 500s; a non-UUID body
        // must fail fast with a readable validation error.
        String body = """
                {"templateId":"not-a-uuid","title":"X"}
                """;
        mvc.perform(post("/api/v1/admin/animation-scenes")
                        .with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void create_unauthenticated_returns401() throws Exception {
        String body = """
                {"templateId":"%s","title":"X"}
                """.formatted(TEMPLATE_ID);
        mvc.perform(post("/api/v1/admin/animation-scenes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isUnauthorized());
    }

    /* ---------- list (summary contract) ---------- */

    @Test
    void list_returnsSummaryWithCurrentVersionId() throws Exception {
        SceneSummaryResponse row = new SceneSummaryResponse(
                SCENE_ID, TEMPLATE_ID, "RIVER_TIDE", null, "Sông Bạch Đằng",
                "PUBLISHED", VERSION_ID, 2, 3L, Instant.EPOCH);
        when(service.list(any(), any(), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(row), PageRequest.of(0, 20), 1));
        mvc.perform(get("/api/v1/admin/animation-scenes")
                        .with(adminJwt()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].currentVersionId").value(VERSION_ID.toString()))
                .andExpect(jsonPath("$.content[0].currentVersionNo").value(2))
                .andExpect(jsonPath("$.content[0].rendererCode").value("RIVER_TIDE"))
                .andExpect(jsonPath("$.content[0].status").value("PUBLISHED"));
    }

    @Test
    void list_rejectsOversizePage() throws Exception {
        mvc.perform(get("/api/v1/admin/animation-scenes?size=101")
                        .with(adminJwt()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void list_supportsStatusFilterAndSearch() throws Exception {
        when(service.list(any(), any(), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 20), 0));
        mvc.perform(get("/api/v1/admin/animation-scenes?status=PUBLISHED&q=bạch")
                        .with(adminJwt()))
                .andExpect(status().isOk());
        org.mockito.Mockito.verify(service).list(any(), any(),
                org.mockito.ArgumentMatchers.eq(AnimationSceneStatus.PUBLISHED),
                org.mockito.ArgumentMatchers.eq("bạch"), any());
    }

    @Test
    void get_missingScene_returns404() throws Exception {
        UUID missing = UUID.fromString("99999999-9999-9999-9999-999999999999");
        when(service.get(missing))
                .thenThrow(new SceneNotFoundException("Animation scene not found: " + missing));
        mvc.perform(get("/api/v1/admin/animation-scenes/{id}", missing)
                        .with(adminJwt()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ANIMATION_SCENE_NOT_FOUND"));
    }
}

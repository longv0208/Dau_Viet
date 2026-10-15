package com.dauviet.lesson.api.dto;

import java.util.List;

public record DraftStagesResponse(List<StageDto> stages, Long rowVersion) {
}

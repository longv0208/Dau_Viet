package com.dauviet.lesson.api.dto;

import java.util.List;

public record DraftActivitiesResponse(List<ActivityDto> activities, Long rowVersion) {
}

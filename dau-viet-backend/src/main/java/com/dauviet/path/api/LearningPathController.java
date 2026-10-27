package com.dauviet.path.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.path.api.dto.LearningPathResponse;
import com.dauviet.path.application.LearningPathService;

/**
 * Controller đọc lộ trình học tập chuẩn hóa (PATH-01).
 * Bề mặt công khai/learner cho Bản đồ Dấu Ấn 2.0 (Timeline duy nhất).
 */
@RestController
@RequestMapping("/api/v1/learning-path")
public class LearningPathController {

    private final LearningPathService service;

    public LearningPathController(LearningPathService service) {
        this.service = service;
    }

    /**
     * Đọc toàn bộ cây lộ trình học tập phiên bản PUBLISHED hiện hành.
     *
     * @param code mã lộ trình (mặc định HISTORY_MAIN)
     * @return cây Chương -> Mốc năm -> Sự kiện -> Bài học
     */
    @GetMapping
    public LearningPathResponse learningPath(
            @RequestParam(required = false, defaultValue = LearningPathService.DEFAULT_PATH_CODE) String code) {
        return service.getPublishedPath(code);
    }
}

package com.dauviet.path.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.path.api.dto.LearningPathResponse;
import com.dauviet.path.api.dto.PathAuditReport;
import com.dauviet.path.application.LearningPathService;
import com.dauviet.path.application.LearningPathValidator;

/**
 * Controller đọc lộ trình học tập chuẩn hóa (PATH-01).
 * Bề mặt công khai/learner cho Bản đồ Dấu Ấn 2.0 (Timeline duy nhất).
 */
@RestController
@RequestMapping("/api/v1/learning-path")
public class LearningPathController {

    private final LearningPathService service;
    private final LearningPathValidator validator;

    public LearningPathController(LearningPathService service,
                                  LearningPathValidator validator) {
        this.service = service;
        this.validator = validator;
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

    /**
     * Báo cáo kiểm toán chất lượng nội dung và tính nhất quán dữ liệu lộ trình.
     */
    @GetMapping("/audit")
    public PathAuditReport audit(
            @RequestParam(required = false, defaultValue = LearningPathService.DEFAULT_PATH_CODE) String code,
            @RequestParam(required = false) Integer version) {
        return validator.audit(code, version);
    }
}

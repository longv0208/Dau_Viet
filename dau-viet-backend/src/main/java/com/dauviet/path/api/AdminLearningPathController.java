package com.dauviet.path.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.path.api.dto.PathAuditReport;
import com.dauviet.path.application.LearningPathService;
import com.dauviet.path.application.LearningPathValidator;

/**
 * Controller quản trị lộ trình học tập chuẩn hóa (PATH-01).
 * Bảo vệ bởi SecurityConfig: chỉ CONTENT_ADMIN mới được truy cập /api/v1/admin/**.
 */
@RestController
@RequestMapping("/api/v1/admin/learning-path")
public class AdminLearningPathController {

    private final LearningPathValidator validator;

    public AdminLearningPathController(LearningPathValidator validator) {
        this.validator = validator;
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

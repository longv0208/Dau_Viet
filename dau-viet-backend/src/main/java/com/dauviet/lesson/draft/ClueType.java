package com.dauviet.lesson.draft;

/**
 * Canonical 4 clue types in Step 1 (DISCOVERY — Truy tìm dấu vết) of the
 * 4-step learning flow.
 */
public enum ClueType {
    CONTEXT("Bối cảnh", "Tìm hiểu hoàn cảnh lịch sử dẫn đến sự kiện"),
    CHARACTERS("Nhân vật", "Khám phá các nhân vật lịch sử và vai trò của họ"),
    DEVELOPMENT("Diễn biến", "Theo dõi các mốc diễn biến chính của sự kiện"),
    SIGNIFICANCE("Ý nghĩa", "Đúc kết kết quả và ý nghĩa lịch sử của sự kiện");

    private final String defaultTitle;
    private final String defaultDescription;

    ClueType(String defaultTitle, String defaultDescription) {
        this.defaultTitle = defaultTitle;
        this.defaultDescription = defaultDescription;
    }

    public String defaultTitle() {
        return defaultTitle;
    }

    public String defaultDescription() {
        return defaultDescription;
    }
}

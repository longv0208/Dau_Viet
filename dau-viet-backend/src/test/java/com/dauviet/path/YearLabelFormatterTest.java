package com.dauviet.path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.dauviet.path.application.YearLabelFormatter;

@DisplayName("PATH-01 — YearLabelFormatter Unit Tests")
class YearLabelFormatterTest {

    @Test
    @DisplayName("Năm nguyên dương: Năm + số")
    void positiveYearsFormat() {
        assertThat(YearLabelFormatter.formatYear(40, null)).isEqualTo("Năm 40");
        assertThat(YearLabelFormatter.formatYear(938, null)).isEqualTo("Năm 938");
        assertThat(YearLabelFormatter.formatYear(1010, null)).isEqualTo("Năm 1010");
        assertThat(YearLabelFormatter.formatYear(1077, null)).isEqualTo("Năm 1077");
        assertThat(YearLabelFormatter.formatYear(1288, null)).isEqualTo("Năm 1288");
        assertThat(YearLabelFormatter.formatYear(1954, null)).isEqualTo("Năm 1954");
    }

    @Test
    @DisplayName("Năm nguyên âm tròn thế kỷ: Khoảng thế kỷ Roman TCN")
    void negativeCenturyYearsFormat() {
        assertThat(YearLabelFormatter.formatYear(-700, null)).isEqualTo("Khoảng thế kỷ VII TCN");
        assertThat(YearLabelFormatter.formatYear(-100, null)).isEqualTo("Khoảng thế kỷ I TCN");
        assertThat(YearLabelFormatter.formatYear(-300, null)).isEqualTo("Khoảng thế kỷ III TCN");
        assertThat(YearLabelFormatter.formatYear(-1000, null)).isEqualTo("Khoảng thế kỷ X TCN");
        assertThat(YearLabelFormatter.formatYear(-2000, null)).isEqualTo("Khoảng thế kỷ XX TCN");
    }

    @Test
    @DisplayName("Năm nguyên âm không tròn thế kỷ: Năm + abs + TCN")
    void negativeExactYearsFormat() {
        assertThat(YearLabelFormatter.formatYear(-179, null)).isEqualTo("Năm 179 TCN");
        assertThat(YearLabelFormatter.formatYear(-257, null)).isEqualTo("Năm 257 TCN");
        assertThat(YearLabelFormatter.formatYear(-111, null)).isEqualTo("Năm 111 TCN");
    }

    @Test
    @DisplayName("Năm 0: Không tồn tại trong quy ước lịch sử thông thường -> ném IllegalArgumentException")
    void yearZeroThrows() {
        assertThatThrownBy(() -> YearLabelFormatter.formatYear(0, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Year 0 does not exist");
    }

    @Test
    @DisplayName("Năm null: Fallback về chuỗi period hoặc null")
    void nullYearFallsBack() {
        assertThat(YearLabelFormatter.formatYear(null, "Thời kỳ tiền sử")).isEqualTo("Thời kỳ tiền sử");
        assertThat(YearLabelFormatter.formatYear(null, "   ")).isNull();
        assertThat(YearLabelFormatter.formatYear(null, null)).isNull();
    }
}

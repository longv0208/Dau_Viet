package com.dauviet.path.application;

/**
 * Tiện ích định dạng mốc niên đại lịch sử (PATH-01).
 *
 * <p>Quy tắc:
 * <ul>
 *   <li>Năm nguyên dương: {@code "Năm " + year} (ví dụ 40 -> "Năm 40", 938 -> "Năm 938").</li>
 *   <li>Năm nguyên âm tròn thế kỷ: {@code "Khoảng thế kỷ " + Roman + " TCN"} (ví dụ -700 -> "Khoảng thế kỷ VII TCN").</li>
 *   <li>Năm nguyên âm khác: {@code "Năm " + abs(year) + " TCN"} (ví dụ -179 -> "Năm 179 TCN").</li>
 *   <li>Năm null: Trả về {@code fallbackPeriod} nếu có, ngược lại trả về null.</li>
 *   <li>Năm 0: Không tồn tại trong quy ước lịch sử thông thường -> ném IllegalArgumentException.</li>
 * </ul>
 */
public final class YearLabelFormatter {

    private static final String[] ROMAN = {
        "", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
        "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"
    };

    private YearLabelFormatter() {}

    public static String formatYear(Integer year, String fallbackPeriod) {
        if (year == null) {
            return (fallbackPeriod != null && !fallbackPeriod.isBlank()) ? fallbackPeriod.trim() : null;
        }
        if (year == 0) {
            throw new IllegalArgumentException("Year 0 does not exist in standard historical calendar notation");
        }
        if (year < 0) {
            int abs = Math.abs(year);
            if (abs % 100 == 0) {
                int century = abs / 100;
                String roman = (century < ROMAN.length) ? ROMAN[century] : String.valueOf(century);
                return "Khoảng thế kỷ " + roman + " TCN";
            }
            return "Năm " + abs + " TCN";
        }
        return "Năm " + year;
    }
}

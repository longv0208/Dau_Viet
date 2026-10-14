package com.dauviet.historicalevent.application;

import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;

/**
 * Dev-only seed: upserts the Bạch Đằng 938 event so the Flutter app has a
 * stable row to render. Idempotent — keyed on the unique slug; re-runs update
 * fields instead of inserting duplicates. Never runs in prod/test profiles.
 */
@Service
public class EventSeedService {

    private static final Logger log = LoggerFactory.getLogger(EventSeedService.class);

    /** Fixed dev UUID so .http scratch files and dev docs can hard-reference it. */
    public static final UUID BACH_DANG_ID = UUID.fromString("00000000-0000-0000-0000-000000000001");
    public static final String BACH_DANG_SLUG = "bach-dang-938";

    private final HistoricalEventRepository repository;

    public EventSeedService(HistoricalEventRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public HistoricalEvent upsertBachDang() {
        HistoricalEvent e = repository.findBySlug(BACH_DANG_SLUG).orElseGet(() -> {
            HistoricalEvent fresh = new HistoricalEvent();
            // Assign fixed dev UUID only on insert — never rewrite the PK of a
            // managed entity loaded under a different id.
            fresh.setId(BACH_DANG_ID);
            return fresh;
        });
        e.setSlug(BACH_DANG_SLUG);
        e.setTitle("Đại Chiến Bạch Đằng 938");
        e.setEra("Thời Ngô - Đinh - Tiền Lê (938 - 1009)");
        e.setPeriod("Mùa Đông 938 SCN");
        e.setStartYear(938);
        e.setSummary("Trận thủy chiến kinh điển cắm cọc gỗ lim bịt sắt lợi dụng con nước triều, "
                + "tiêu diệt hoàn toàn thủy quân Nam Hán của Lưu Hoằng Tháo, "
                + "chính thức chấm dứt hơn 1.000 năm Bắc thuộc.");
        e.setDescription("Năm 938, Ngô Quyền lợi dụng địa thế cửa sông Bạch Đằng và quy luật "
                + "thủy triều để bố trí trận địa cọc ngầm bịt sắt, nhử hạm đội Nam Hán vào "
                + "trận địa rồi tiêu diệt khi nước rút. Chiến thắng mở ra kỷ nguyên độc lập "
                + "lâu dài cho Việt Nam.");
        e.setLocation("Cửa sông Bạch Đằng, Quảng Ninh - Hải Phòng");
        e.setCoverAssetKey("events/bach-dang-938/hero.jpg");
        e.setTags(List.of("ngo-quyen", "thuy-chien", "bac-thuoc", "bach-dang"));
        e.setStatus(EventStatus.PUBLISHED);
        HistoricalEvent saved = repository.save(e);
        log.info("seeded historical event slug={} id={}", saved.getSlug(), saved.getId());
        return saved;
    }
}

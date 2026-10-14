package com.dauviet.historicalevent.api.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.dauviet.historicalevent.api.dto.HistoricalEventDetailDto;
import com.dauviet.historicalevent.api.dto.HistoricalEventSummaryDto;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;

class HistoricalEventMapperTest {

    private final HistoricalEventMapper mapper = new HistoricalEventMapper();

    private HistoricalEvent sample() {
        HistoricalEvent e = new HistoricalEvent();
        e.setId(UUID.fromString("00000000-0000-0000-0000-000000000001"));
        e.setSlug("bach-dang-938");
        e.setTitle("Đại Chiến Bạch Đằng 938");
        e.setEra("Thời Ngô");
        e.setPeriod("Mùa Đông 938");
        e.setStartYear(938);
        e.setSummary("summary");
        e.setDescription("long description");
        e.setLocation("Quảng Ninh");
        e.setCoverAssetKey("events/bach-dang-938/hero.jpg");
        e.setTags(List.of("a", "b"));
        e.setStatus(EventStatus.PUBLISHED);
        return e;
    }

    @Test
    void toSummaryDto_mapsAllFields() {
        HistoricalEventSummaryDto dto = mapper.toSummaryDto(sample());
        assertThat(dto.id()).isEqualTo(UUID.fromString("00000000-0000-0000-0000-000000000001"));
        assertThat(dto.slug()).isEqualTo("bach-dang-938");
        assertThat(dto.title()).isEqualTo("Đại Chiến Bạch Đằng 938");
        assertThat(dto.era()).isEqualTo("Thời Ngô");
        assertThat(dto.startYear()).isEqualTo(938);
        assertThat(dto.tags()).containsExactly("a", "b");
    }

    @Test
    void toDetailDto_includesExtendedFields() {
        HistoricalEventDetailDto dto = mapper.toDetailDto(sample());
        assertThat(dto.description()).isEqualTo("long description");
        assertThat(dto.location()).isEqualTo("Quảng Ninh");
        assertThat(dto.summary()).isEqualTo("summary");
    }

    @Test
    void nullTags_becomeEmptyList() {
        HistoricalEvent e = sample();
        e.setTags(null);
        assertThat(mapper.toSummaryDto(e).tags()).isEmpty();
        assertThat(mapper.toDetailDto(e).tags()).isEmpty();
    }
}

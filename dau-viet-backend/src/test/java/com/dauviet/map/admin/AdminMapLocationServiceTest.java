package com.dauviet.map.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import org.springframework.test.util.ReflectionTestUtils;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.map.admin.dto.AdminMapLocationResponse;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.EventLinkInput;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.ReplaceEventsRequest;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.StandaloneLocationResponse;
import com.dauviet.map.domain.MapLocation;
import com.dauviet.map.domain.MapLocationEvent;
import com.dauviet.map.domain.MapLocationStatus;
import com.dauviet.map.infrastructure.persistence.MapLocationEventRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationMediaRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationUnlockLessonRepository;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.MediaInput;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.StandaloneLocationRequest;
import com.dauviet.map.domain.MapLocationMedia;

class AdminMapLocationServiceTest {

    private MapLocationRepository locations;
    private HistoricalEventRepository events;
    private LessonRepository lessons;
    private MapLocationEventRepository locationEvents;
    private MapLocationUnlockLessonRepository unlockLessons;
    private MapLocationMediaRepository locationMedia;
    private AssetRepository assets;
    private AdminMapLocationService service;

    @BeforeEach
    void setUp() {
        locations = mock(MapLocationRepository.class);
        events = mock(HistoricalEventRepository.class);
        lessons = mock(LessonRepository.class);
        locationEvents = mock(MapLocationEventRepository.class);
        unlockLessons = mock(MapLocationUnlockLessonRepository.class);
        locationMedia = mock(MapLocationMediaRepository.class);
        assets = mock(AssetRepository.class);
        service = new AdminMapLocationService(
                locations, events, lessons, locationEvents, unlockLessons, locationMedia, assets);
    }

    @Test
    void replaceEvents_syncsEventIdToPrimaryOrFirstOrNullAndSavesLocation() {
        UUID locId = UUID.randomUUID();
        UUID event1 = UUID.randomUUID();
        UUID event2 = UUID.randomUUID();

        MapLocation loc = new MapLocation();
        loc.setId(locId);
        loc.setTitle("Bến Bạch Đằng");
        loc.setStatus(MapLocationStatus.DRAFT);
        ReflectionTestUtils.setField(loc, "rowVersion", 0L);

        when(locations.findById(locId)).thenReturn(Optional.of(loc));
        when(events.existsById(event1)).thenReturn(true);
        when(events.existsById(event2)).thenReturn(true);
        when(locations.saveAndFlush(any(MapLocation.class))).thenAnswer(inv -> inv.getArgument(0));

        // 1. PRIMARY entry wins even if it is second in the list
        StandaloneLocationResponse resPrimary = service.replaceEvents(locId, new ReplaceEventsRequest(List.of(
                new EventLinkInput(event1, "RELATED", 0),
                new EventLinkInput(event2, "PRIMARY", 1)
        )));
        assertThat(loc.getEventId()).isEqualTo(event2);
        assertThat(resPrimary.eventId()).isEqualTo(event2);
        verify(locations).saveAndFlush(loc);

        // 2. First entry wins when none has PRIMARY
        StandaloneLocationResponse resFirst = service.replaceEvents(locId, List.of(
                new EventLinkInput(event1, "RELATED", 0),
                new EventLinkInput(event2, "RELATED", 1)
        ));
        assertThat(loc.getEventId()).isEqualTo(event1);
        assertThat(resFirst.eventId()).isEqualTo(event1);

        // 3. Empty list clears eventId to null
        StandaloneLocationResponse resEmpty = service.replaceEvents(locId, List.of());
        assertThat(loc.getEventId()).isNull();
        assertThat(resEmpty.eventId()).isNull();
    }

    @Test
    void list_returnsDirectAndLinkedLocationsDeduplicatedAndOrdered() {
        UUID eventId = UUID.randomUUID();
        UUID otherEventId = UUID.randomUUID();
        when(events.existsById(eventId)).thenReturn(true);

        MapLocation locDirect = new MapLocation();
        locDirect.setId(UUID.randomUUID());
        locDirect.setEventId(eventId);
        locDirect.setTitle("Bãi cọc Yên Giang");
        locDirect.setDisplayOrder(2);
        locDirect.setStatus(MapLocationStatus.PUBLISHED);
        ReflectionTestUtils.setField(locDirect, "rowVersion", 0L);

        MapLocation locLinked = new MapLocation();
        locLinked.setId(UUID.randomUUID());
        locLinked.setEventId(otherEventId);
        locLinked.setTitle("Cửa sông Bạch Đằng");
        locLinked.setDisplayOrder(1);
        locLinked.setStatus(MapLocationStatus.PUBLISHED);
        ReflectionTestUtils.setField(locLinked, "rowVersion", 0L);

        when(locations.findByEventIdOrderByDisplayOrderAscTitleAsc(eventId))
                .thenReturn(List.of(locDirect));
        when(locationEvents.findByIdEventId(eventId))
                .thenReturn(List.of(
                        new MapLocationEvent(locDirect.getId(), eventId, "PRIMARY", 0),
                        new MapLocationEvent(locLinked.getId(), eventId, "RELATED", 1)
                ));
        when(locations.findAllById(any()))
                .thenReturn(List.of(locLinked));

        List<AdminMapLocationResponse> result = service.list(eventId);
        assertThat(result).hasSize(2);
        assertThat(result.get(0).id()).isEqualTo(locLinked.getId());
        assertThat(result.get(0).title()).isEqualTo("Cửa sông Bạch Đằng");
        assertThat(result.get(1).id()).isEqualTo(locDirect.getId());
        assertThat(result.get(1).title()).isEqualTo("Bãi cọc Yên Giang");
    }

    @Test
    void createAndUpdateStandalone_persistsStorybookFieldsAndMediaSourceCitation() {
        UUID locId = UUID.randomUUID();
        when(locations.saveAndFlush(any(MapLocation.class))).thenAnswer(inv -> {
            MapLocation l = inv.getArgument(0);
            if (l.getRowVersion() == null) {
                ReflectionTestUtils.setField(l, "rowVersion", 0L);
            }
            return l;
        });
        when(locations.findById(locId)).thenReturn(Optional.empty());

        // Create: storybook fields are applied and returned
        StandaloneLocationRequest req = new StandaloneLocationRequest(
                "ben-bach-dang",
                "Bến Bạch Đằng",
                "Tóm tắt",
                "Mô tả",
                "BATTLEFIELD",
                20.9,
                106.8,
                "EXACT",
                "ALWAYS_VISIBLE",
                "NONE",
                null,
                null,
                3,
                "Ngô Quyền, Dương Tam Kha; đối phương: Lưu Hoằng Thao",
                "Câu chuyện trận Bạch Đằng 938 chi tiết...",
                "Ý nghĩa mở kỷ nguyên độc lập");
        StandaloneLocationResponse created = service.createStandalone(req);
        assertThat(created.keyFigures()).isEqualTo("Ngô Quyền, Dương Tam Kha; đối phương: Lưu Hoằng Thao");
        assertThat(created.storyNarrative()).isEqualTo("Câu chuyện trận Bạch Đằng 938 chi tiết...");
        assertThat(created.historicalSignificance()).isEqualTo("Ý nghĩa mở kỷ nguyên độc lập");

        // Update: fields persist on the entity
        MapLocation loc = new MapLocation();
        loc.setId(locId);
        loc.setTitle("Bến Bạch Đằng");
        loc.setStatus(MapLocationStatus.DRAFT);
        ReflectionTestUtils.setField(loc, "rowVersion", 0L);
        when(locations.findById(locId)).thenReturn(Optional.of(loc));

        StandaloneLocationResponse updated = service.updateStandalone(
                locId,
                new StandaloneLocationRequest(
                        "ben-bach-dang",
                        "Bến Bạch Đằng",
                        "Tóm tắt mới",
                        "Mô tả mới",
                        "BATTLEFIELD",
                        20.9,
                        106.8,
                        "EXACT",
                        "ALWAYS_VISIBLE",
                        "NONE",
                        null,
                        null,
                        3,
                        "Ngô Quyền, Trịnh Khả",
                        "Câu chuyện cập nhật",
                        "Ý nghĩa cập nhật"),
                0L);
        assertThat(loc.getKeyFigures()).isEqualTo("Ngô Quyền, Trịnh Khả");
        assertThat(loc.getStoryNarrative()).isEqualTo("Câu chuyện cập nhật");
        assertThat(loc.getHistoricalSignificance()).isEqualTo("Ý nghĩa cập nhật");
        assertThat(updated.keyFigures()).isEqualTo("Ngô Quyền, Trịnh Khả");
        assertThat(updated.storyNarrative()).isEqualTo("Câu chuyện cập nhật");
        assertThat(updated.historicalSignificance()).isEqualTo("Ý nghĩa cập nhật");

        // replaceMedia: sourceCitation is persisted on saved media and returned in the view
        when(locationMedia.findByLocationIdOrderBySortOrderAsc(locId)).thenAnswer(inv -> {
            MapLocationMedia m = new MapLocationMedia(
                    UUID.randomUUID(), locId, "IMAGE_2D", "Trận địa cọc",
                    "Chú thích", "Nguồn: Đại Việt Sử ký Toàn thư",
                    null, "/heritage/bg_story_tran_dia.jpg", "PUBLIC_PREVIEW", 1);
            return List.of(m);
        });
        StandaloneLocationResponse res = service.replaceMedia(locId, List.of(
                new MediaInput("IMAGE_2D", "Trận địa cọc", "Chú thích",
                        null, "/heritage/bg_story_tran_dia.jpg", "PUBLIC_PREVIEW", 1,
                        "Nguồn: Đại Việt Sử ký Toàn thư")));
        verify(locationMedia).save(any(MapLocationMedia.class));
        assertThat(res.media()).hasSize(1);
        assertThat(res.media().get(0).sourceCitation()).isEqualTo("Nguồn: Đại Việt Sử ký Toàn thư");
    }
}

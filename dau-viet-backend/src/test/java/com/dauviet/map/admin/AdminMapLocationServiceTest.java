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
}

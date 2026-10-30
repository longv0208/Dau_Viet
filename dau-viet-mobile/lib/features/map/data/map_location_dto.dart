/// DTO khớp contract `GET /api/v1/map/locations[/{id}]` v2 (Issue #16 / #24).
/// `unlockState` và `unlocked` do server tính theo learner trong JWT —
/// client KHÔNG gửi userId hay cờ completed (server-authoritative).
enum MapUnlockState {
  available,
  locked,
  unlocked;

  static MapUnlockState parse(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'AVAILABLE':
        return MapUnlockState.available;
      case 'UNLOCKED':
        return MapUnlockState.unlocked;
      case 'LOCKED':
      default:
        return MapUnlockState.locked;
    }
  }

  String get labelVi => switch (this) {
    MapUnlockState.unlocked => 'Đã mở khoá',
    MapUnlockState.available => 'Sẵn sàng khám phá',
    MapUnlockState.locked => 'Đang khoá',
  };
}

/// Tham chiếu bài học cần hoàn thành để mở khoá địa điểm (tương thích v1).
/// `accessible=false` = bài học liên kết không còn mở được cho learner
/// (draft/archived sau khi địa điểm publish) → UI ẩn CTA bài học; trạng
/// thái UNLOCKED đã đạt được KHÔNG bị thu hồi.
class RequiredLessonRef {
  final String lessonId;
  final String title;
  final bool accessible;

  const RequiredLessonRef({
    required this.lessonId,
    required this.title,
    this.accessible = true,
  });

  factory RequiredLessonRef.fromJson(Map<String, dynamic> json) {
    return RequiredLessonRef(
      lessonId: json['lessonId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      accessible: json['accessible'] as bool? ?? true,
    );
  }
}

/// Sự kiện lịch sử gắn với địa điểm di sản (`events[]` trong API v2).
class MapLocationLinkedEventDto {
  final String eventId;
  final String title;
  final String? yearLabel;
  final String role;
  final int sortOrder;
  final String? slug;
  final String? summary;
  final String? description;
  final String? periodCode;
  final String? periodTitle;

  const MapLocationLinkedEventDto({
    required this.eventId,
    required this.title,
    this.yearLabel,
    this.role = 'PRIMARY',
    this.sortOrder = 0,
    this.slug,
    this.summary,
    this.description,
    this.periodCode,
    this.periodTitle,
  });

  factory MapLocationLinkedEventDto.fromJson(Map<String, dynamic> json) {
    return MapLocationLinkedEventDto(
      eventId: json['eventId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      yearLabel: json['yearLabel'] as String?,
      role: json['role'] as String? ?? 'PRIMARY',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String?,
      summary: json['summary'] as String?,
      description: json['description'] as String?,
      periodCode: json['periodCode'] as String?,
      periodTitle: json['periodTitle'] as String?,
    );
  }
}

/// Tiến độ bài học trong điều kiện mở khoá địa điểm (`unlockLessons[]` v2).
class MapLocationUnlockLessonDto {
  final String lessonId;
  final String title;
  final bool completed;
  final bool accessible;

  const MapLocationUnlockLessonDto({
    required this.lessonId,
    required this.title,
    this.completed = false,
    this.accessible = true,
  });

  factory MapLocationUnlockLessonDto.fromJson(Map<String, dynamic> json) {
    return MapLocationUnlockLessonDto(
      lessonId: json['lessonId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      accessible: json['accessible'] as bool? ?? true,
    );
  }
}

/// Học liệu / media của địa điểm di sản (`media[]` trong API v2).
/// `mediaType` ∈ `IMAGE_2D | PANORAMA_360 | AUDIO_GUIDE | DOCUMENTARY_CLIP`.
/// `visibility` ∈ `PUBLIC_PREVIEW | UNLOCKED_ONLY`.
class MapLocationMediaDto {
  final String id;
  final String mediaType;
  final String title;
  final String? caption;
  final String? assetId;
  final String? assetUrl;
  final String? externalUrl;
  final String? sourceCitation;
  final String visibility;
  final int sortOrder;

  const MapLocationMediaDto({
    required this.id,
    required this.mediaType,
    required this.title,
    this.caption,
    this.assetId,
    this.assetUrl,
    this.externalUrl,
    this.sourceCitation,
    this.visibility = 'PUBLIC_PREVIEW',
    this.sortOrder = 0,
  });

  factory MapLocationMediaDto.fromJson(Map<String, dynamic> json) {
    return MapLocationMediaDto(
      id: json['id']?.toString() ?? '',
      mediaType: (json['mediaType'] as String? ?? 'IMAGE_2D')
          .trim()
          .toUpperCase(),
      title: json['title'] as String? ?? '',
      caption: json['caption'] as String?,
      assetId: json['assetId'] as String?,
      assetUrl: json['assetUrl'] as String?,
      externalUrl: json['externalUrl'] as String?,
      sourceCitation: json['sourceCitation'] as String?,
      visibility: (json['visibility'] as String? ?? 'PUBLIC_PREVIEW')
          .trim()
          .toUpperCase(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isPublicPreview =>
      visibility.trim().toUpperCase() == 'PUBLIC_PREVIEW' ||
      visibility.trim().toUpperCase() == 'PUBLIC';

  bool get isUnlockedOnly => visibility.trim().toUpperCase() == 'UNLOCKED_ONLY';

  bool get isImageMedia {
    final t = mediaType.trim().toUpperCase();
    return t == 'IMAGE_2D' || t == 'PANORAMA_360' || t == 'IMAGE';
  }

  bool get isVideoOrAudioMedia {
    final t = mediaType.trim().toUpperCase();
    return t == 'DOCUMENTARY_CLIP' ||
        t == 'AUDIO_GUIDE' ||
        t == 'VIDEO' ||
        t == 'AUDIO';
  }

  String get mediaTypeLabelVi => switch (mediaType.trim().toUpperCase()) {
    'IMAGE_2D' => 'Ảnh tư liệu 2D',
    'PANORAMA_360' => 'Toàn cảnh 360°',
    'DOCUMENTARY_CLIP' => 'Phim tư liệu',
    'AUDIO_GUIDE' => 'Thuyết minh âm thanh',
    _ => 'Tư liệu đa phương tiện',
  };
}

/// Một địa điểm di sản trên bản đồ lịch sử (API v2).
class MapLocationDto {
  final String id;
  final String eventId;
  final String? eventTitle;
  final String? slug;
  final String title;
  final String? shortSummary;
  final String? description;
  final double latitude;
  final double longitude;
  final String kind;
  final String coordinatePrecision;
  final String visibility;
  final String unlockMode;
  final bool unlocked;
  final MapUnlockState unlockState;
  final String? coverAssetId;
  final String? mapAssetId;
  final RequiredLessonRef? requiredLesson;
  final List<String> eventIds;
  final List<MapLocationLinkedEventDto> events;
  final List<MapLocationUnlockLessonDto> unlockLessons;
  final List<MapLocationMediaDto> media;
  final String? keyFigures;
  final String? storyNarrative;
  final String? historicalSignificance;

  const MapLocationDto({
    required this.id,
    this.eventId = '',
    this.eventTitle,
    this.slug,
    required this.title,
    this.shortSummary,
    this.description,
    required this.latitude,
    required this.longitude,
    this.kind = 'HERITAGE_SITE',
    this.coordinatePrecision = 'EXACT',
    this.visibility = 'ALWAYS_VISIBLE',
    this.unlockMode = 'NONE',
    bool? unlocked,
    required this.unlockState,
    this.coverAssetId,
    this.mapAssetId,
    this.requiredLesson,
    this.eventIds = const [],
    this.events = const [],
    this.unlockLessons = const [],
    this.media = const [],
    this.keyFigures,
    this.storyNarrative,
    this.historicalSignificance,
  }) : unlocked = unlocked ?? (unlockState != MapUnlockState.locked);

  bool get isUnlocked => unlocked;

  /// `visibility` là công khai (`PUBLIC` hoặc `ALWAYS_VISIBLE`).
  /// Khi `isPublicVisibility == true`, địa điểm đang khoá vẫn hiển thị tên
  /// và ghim trên bản đồ (AC-2).
  bool get isPublicVisibility {
    final v = visibility.trim().toUpperCase();
    return v.isEmpty || v == 'PUBLIC' || v == 'ALWAYS_VISIBLE';
  }

  bool get isHiddenUntilUnlocked =>
      visibility.trim().toUpperCase() == 'HIDDEN_UNTIL_UNLOCKED';

  /// Địa điểm có hiển thị trên bản đồ hay không:
  /// - Nếu đã mở khoá (`unlocked == true`): luôn hiển thị.
  /// - Nếu đang khoá: chỉ hiển thị khi `visibility` là `PUBLIC` / `ALWAYS_VISIBLE`;
  ///   ẩn nếu `HIDDEN_UNTIL_UNLOCKED`.
  bool get shouldDisplayOnMap => unlocked || !isHiddenUntilUnlocked;

  /// ID sự kiện chính để nhóm chặng hoặc mở màn Chiến dịch.
  String? get primaryEventId {
    if (eventId.trim().isNotEmpty) return eventId.trim();
    if (eventIds.isNotEmpty && eventIds.first.trim().isNotEmpty) {
      return eventIds.first.trim();
    }
    if (events.isNotEmpty && events.first.eventId.trim().isNotEmpty) {
      return events.first.eventId.trim();
    }
    return null;
  }

  /// Tên sự kiện chính (ưu tiên `eventTitle`, sau đó `events.first.title`).
  String? get primaryEventTitle {
    if (eventTitle != null && eventTitle!.trim().isNotEmpty) {
      return eventTitle!.trim();
    }
    if (events.isNotEmpty && events.first.title.trim().isNotEmpty) {
      return events.first.title.trim();
    }
    return null;
  }

  /// Danh sách media được phép hiển thị theo trạng thái khoá/mở.
  List<MapLocationMediaDto> get visibleMedia =>
      media.where((m) => unlocked || m.isPublicPreview).toList();

  /// Media thuộc tab "Ảnh" (`IMAGE_2D`, `PANORAMA_360`).
  List<MapLocationMediaDto> get imageMedia =>
      visibleMedia.where((m) => m.isImageMedia).toList();

  /// Danh sách ảnh cho Carousel (gộp `imageMedia` hoặc tạo mục từ `coverAssetId`
  /// khi `imageMedia` rỗng nhưng địa điểm có ảnh bìa).
  List<MapLocationMediaDto> get galleryImages {
    final imgs = imageMedia;
    if (imgs.isNotEmpty) return imgs;
    if (coverAssetId != null && coverAssetId!.trim().isNotEmpty) {
      return [
        MapLocationMediaDto(
          id: 'cover_$id',
          mediaType: 'IMAGE_2D',
          title: title,
          caption: shortSummary,
          assetId: coverAssetId,
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
      ];
    }
    return const [];
  }

  /// Media thuộc tab "Video" (`DOCUMENTARY_CLIP`, `AUDIO_GUIDE`).
  List<MapLocationMediaDto> get videoMedia =>
      visibleMedia.where((m) => m.isVideoOrAudioMedia).toList();

  /// Có nội dung cho tab "Tư liệu" hay không.
  bool get hasDocumentContent =>
      (description != null && description!.trim().isNotEmpty) ||
      (shortSummary != null && shortSummary!.trim().isNotEmpty) ||
      (storyNarrative != null && storyNarrative!.trim().isNotEmpty) ||
      (keyFigures != null && keyFigures!.trim().isNotEmpty) ||
      (historicalSignificance != null &&
          historicalSignificance!.trim().isNotEmpty) ||
      events.isNotEmpty ||
      (eventTitle != null && eventTitle!.trim().isNotEmpty) ||
      unlockLessons.isNotEmpty ||
      requiredLesson != null;
  /// Bài học đại diện có thể mở để học/ôn (ưu tiên bài chưa hoàn thành trong
  /// `unlockLessons`, sau đó bài đầu tiên `accessible`, hoặc `requiredLesson`).
  RequiredLessonRef? get actionableLesson {
    for (final l in unlockLessons) {
      if (l.accessible && !l.completed) {
        return RequiredLessonRef(
          lessonId: l.lessonId,
          title: l.title,
          accessible: l.accessible,
        );
      }
    }
    for (final l in unlockLessons) {
      if (l.accessible) {
        return RequiredLessonRef(
          lessonId: l.lessonId,
          title: l.title,
          accessible: l.accessible,
        );
      }
    }
    return requiredLesson;
  }

  String get kindLabelVi => switch (kind.trim().toUpperCase()) {
    'HERITAGE_SITE' => 'Di tích lịch sử',
    'BATTLEFIELD' => 'Chiến trường cổ',
    'ANCIENT_CAPITAL' => 'Kinh đô cổ',
    'ARCHAEOLOGICAL_SITE' => 'Khu khảo cổ',
    'MEMORIAL' => 'Đài tưởng niệm / Đền thờ',
    'SCHEMATIC_REGION' => 'Vùng chiến lược',
    _ => 'Di tích lịch sử',
  };

  String get coordinatePrecisionLabelVi =>
      switch (coordinatePrecision.trim().toUpperCase()) {
        'EXACT' => 'Tọa độ chính xác',
        'APPROXIMATE' => 'Tọa độ tương đối',
        'SCHEMATIC_ONLY' => 'Vị trí ước lệ',
        _ => 'Tọa độ chính xác',
      };

  String get unlockModeLabelVi => switch (unlockMode.trim().toUpperCase()) {
    'NONE' => 'Mở tự do',
    'ANY' => 'Hoàn thành 1 bài học bất kỳ',
    'ALL' => 'Hoàn thành tất cả bài học liên kết',
    _ => 'Mở khoá qua bài học',
  };

  factory MapLocationDto.fromJson(Map<String, dynamic> json) {
    final Object? req = json['requiredLesson'];
    final List<String> parsedEventIds = (json['eventIds'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final List<MapLocationLinkedEventDto> parsedEvents =
        (json['events'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) =>
                  MapLocationLinkedEventDto.fromJson(e.cast<String, dynamic>()),
            )
            .toList();
    final List<MapLocationUnlockLessonDto> parsedUnlockLessons =
        (json['unlockLessons'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) => MapLocationUnlockLessonDto.fromJson(
                e.cast<String, dynamic>(),
              ),
            )
            .toList();
    final List<MapLocationMediaDto> parsedMedia =
        (json['media'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => MapLocationMediaDto.fromJson(m.cast<String, dynamic>()))
            .toList();

    final String rawEventId =
        json['eventId'] as String? ??
        (parsedEventIds.isNotEmpty
            ? parsedEventIds.first
            : (parsedEvents.isNotEmpty ? parsedEvents.first.eventId : ''));

    final MapUnlockState parsedState = MapUnlockState.parse(
      json['unlockState'] as String? ?? '',
    );
    final bool? parsedUnlocked = json['unlocked'] as bool?;

    return MapLocationDto(
      id: json['id'] as String? ?? '',
      eventId: rawEventId,
      eventTitle: json['eventTitle'] as String?,
      slug: json['slug'] as String?,
      title: json['title'] as String? ?? '',
      shortSummary: json['shortSummary'] as String?,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      kind: json['kind'] as String? ?? 'HERITAGE_SITE',
      coordinatePrecision: json['coordinatePrecision'] as String? ?? 'EXACT',
      visibility: json['visibility'] as String? ?? 'ALWAYS_VISIBLE',
      unlockMode:
          json['unlockMode'] as String? ??
          (req != null || parsedUnlockLessons.isNotEmpty ? 'ANY' : 'NONE'),
      unlocked: parsedUnlocked,
      unlockState: parsedState,
      coverAssetId: json['coverAssetId'] as String?,
      mapAssetId: json['mapAssetId'] as String?,
      requiredLesson: req is Map
          ? RequiredLessonRef.fromJson(req.cast<String, dynamic>())
          : null,
      eventIds: parsedEventIds,
      events: parsedEvents,
      unlockLessons: parsedUnlockLessons,
      media: parsedMedia,
      keyFigures: json['keyFigures'] as String?,
      storyNarrative: json['storyNarrative'] as String?,
      historicalSignificance: json['historicalSignificance'] as String?,
    );
  }
}

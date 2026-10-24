/// DTO cho GAME-04 dossier API — khớp DossierDtos backend.
/// `preview` = true nghĩa server chỉ trả metadata title-level (locked
/// PUBLISHED); description + source chỉ có khi unlocked.
library;

class DossierSourceDto {
  final String? title;
  final String? author;
  final String? citation;
  final String? url;
  final String? reliability;

  const DossierSourceDto({
    this.title,
    this.author,
    this.citation,
    this.url,
    this.reliability,
  });

  factory DossierSourceDto.fromJson(Map<String, dynamic> json) =>
      DossierSourceDto(
        title: json['title'] as String?,
        author: json['author'] as String?,
        citation: json['citation'] as String?,
        url: json['url'] as String?,
        reliability: json['reliability'] as String?,
      );
}

/// Item trong GET /me/collection/dossiers — list preview khi locked.
class DossierSummaryDto {
  final String dossierId;
  final String canonicalCode;
  final String dossierType;
  final String title;
  final String? summary;
  final String? assetId;
  final List<String> eventIds;
  final bool unlocked;
  final String? grantedAt;
  final String? unlockEventId;
  final bool preview;

  const DossierSummaryDto({
    required this.dossierId,
    required this.canonicalCode,
    required this.dossierType,
    required this.title,
    this.summary,
    this.assetId,
    this.eventIds = const [],
    required this.unlocked,
    this.grantedAt,
    this.unlockEventId,
    required this.preview,
  });

  factory DossierSummaryDto.fromJson(Map<String, dynamic> json) =>
      DossierSummaryDto(
        dossierId: json['dossierId'] as String? ?? '',
        canonicalCode: json['canonicalCode'] as String? ?? '',
        dossierType: json['dossierType'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String?,
        assetId: json['assetId'] as String?,
        eventIds: (json['eventIds'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        unlocked: json['unlocked'] as bool? ?? false,
        grantedAt: json['grantedAt'] as String?,
        unlockEventId: json['unlockEventId'] as String?,
        preview: json['preview'] as bool? ?? false,
      );
}

/// Detail GET /me/collection/dossiers/{id} — full khi unlocked, chỉ
/// metadata + preview khi locked.
class DossierDetailDto {
  final String dossierId;
  final String canonicalCode;
  final String dossierType;
  final String title;
  final String? summary;
  final String? description;
  final String? assetId;
  final DossierSourceDto? source;
  final List<String> eventIds;
  final bool unlocked;
  final String? grantedAt;
  final String? unlockEventId;
  final int? dossierVersion;
  final bool preview;

  const DossierDetailDto({
    required this.dossierId,
    required this.canonicalCode,
    required this.dossierType,
    required this.title,
    this.summary,
    this.description,
    this.assetId,
    this.source,
    this.eventIds = const [],
    required this.unlocked,
    this.grantedAt,
    this.unlockEventId,
    this.dossierVersion,
    required this.preview,
  });

  factory DossierDetailDto.fromJson(Map<String, dynamic> json) =>
      DossierDetailDto(
        dossierId: json['dossierId'] as String? ?? '',
        canonicalCode: json['canonicalCode'] as String? ?? '',
        dossierType: json['dossierType'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String?,
        description: json['description'] as String?,
        assetId: json['assetId'] as String?,
        source: json['source'] is Map
            ? DossierSourceDto.fromJson(
                (json['source'] as Map).cast<String, dynamic>(),
              )
            : null,
        eventIds: (json['eventIds'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        unlocked: json['unlocked'] as bool? ?? false,
        grantedAt: json['grantedAt'] as String?,
        unlockEventId: json['unlockEventId'] as String?,
        dossierVersion: (json['dossierVersion'] as num?)?.toInt(),
        preview: json['preview'] as bool? ?? false,
      );
}

/// PageResponse envelope cho dossier list.
class DossierPageDto {
  final List<DossierSummaryDto> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const DossierPageDto({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  bool get hasMore => page + 1 < totalPages;

  factory DossierPageDto.fromJson(Map<String, dynamic> json) {
    final raw = json['content'] ?? json['items'];
    return DossierPageDto(
      content: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (e) => DossierSummaryDto.fromJson(e.cast<String, dynamic>()),
                )
                .toList()
          : const [],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

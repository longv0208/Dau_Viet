/// ANIM-03 — Resolve assetId trong manifest → metadata embed sẵn trong
/// lesson snapshot (`snapshot.assets[]`). Bytes đã pin trong snapshot
/// nên resolver thuần túy in-memory — KHÔNG fetch mạng per-frame và
/// KHÔNG dựa vào storageKey ngoài (admin đổi file sau publish không ảnh
/// hưởng). Renderer dùng [LearningAssetImage] với assetId khi cần hiển
/// thị ảnh — widget đó tự cache bytes.
class AnimationAssetResolver {
  /// assetId → {storageKey, mimeType, originalFilename, altText}.
  final Map<String, Map<String, String>> _byId;

  AnimationAssetResolver(List<dynamic>? snapshotAssets)
      : _byId = {
          if (snapshotAssets != null)
            for (final a in snapshotAssets)
              if (a is Map && a['id'] != null)
                '${a['id']}': {
                  if (a['storageKey'] != null) 'storageKey': '${a['storageKey']}',
                  if (a['mimeType'] != null) 'mimeType': '${a['mimeType']}',
                  if (a['originalFilename'] != null)
                    'originalFilename': '${a['originalFilename']}',
                  if (a['altText'] != null) 'altText': '${a['altText']}',
                },
        };

  /// Manifest dùng cả hai dạng: draft `{id, assetId}` hoặc snapshot
  /// `{id:<uuid>}` đã embed — id nào resolve được cũng trả assetId
  /// thật (để LearningAssetImage fetch qua endpoint có auth).
  String? assetIdOf(Object? ref) {
    if (ref is! Map) return null;
    final candidate = ref['assetId'] ?? ref['id'];
    return candidate == null ? null : '$candidate';
  }

  String? storageKeyOf(String assetId) => _byId[assetId]?['storageKey'];
  String? mimeTypeOf(String assetId) => _byId[assetId]?['mimeType'];
  String? altTextOf(String assetId) => _byId[assetId]?['altText'];
}

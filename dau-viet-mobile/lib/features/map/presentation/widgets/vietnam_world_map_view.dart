import 'package:flutter/material.dart';

import '../../data/map_location_dto.dart';
import '../../geo/vietnam_world_map_projection.dart';
import 'heritage_map_marker.dart';

class MapCluster {
  final Offset world;
  final List<MapLocationDto> members;
  const MapCluster({required this.world, required this.members});
}

List<MapCluster> clusterLocations({
  required List<MapLocationDto> locations,
  required double scale,
}) {
  final radius = (28.0 / scale.clamp(0.2, 6.0)).clamp(12.0, 90.0);
  final remaining = [...locations];
  final clusters = <MapCluster>[];
  while (remaining.isNotEmpty) {
    final seed = remaining.removeAt(0);
    final seedWorld = VietnamWorldMapProjection.geoToWorld(
      seed.latitude,
      seed.longitude,
    );
    final members = <MapLocationDto>[seed];
    remaining.removeWhere((other) {
      final w = VietnamWorldMapProjection.geoToWorld(
        other.latitude,
        other.longitude,
      );
      if ((w - seedWorld).distance <= radius) {
        members.add(other);
        return true;
      }
      return false;
    });
    var cx = 0.0, cy = 0.0;
    for (final m in members) {
      final w = VietnamWorldMapProjection.geoToWorld(m.latitude, m.longitude);
      cx += w.dx;
      cy += w.dy;
    }
    clusters.add(
      MapCluster(
        world: Offset(cx / members.length, cy / members.length),
        members: members,
      ),
    );
  }
  return clusters;
}

class VietnamWorldMapView extends StatelessWidget {
  final TransformationController controller;
  final List<MapLocationDto> locations;
  final String? selectedId;
  final Set<String> highlightedIds;
  final ValueChanged<MapLocationDto> onSelect;
  final ValueChanged<MapCluster> onClusterTap;

  const VietnamWorldMapView({
    super.key,
    required this.controller,
    required this.locations,
    required this.selectedId,
    required this.highlightedIds,
    required this.onSelect,
    required this.onClusterTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onDoubleTap: () {
                  final current = controller.value.getMaxScaleOnAxis();
                  final next = current < 2.0 ? 3.2 : 1.0;
                  final size = constraints.biggest;
                  final center = Offset(size.width / 2, size.height / 2);
                  final world = VietnamWorldMapProjection.screenToWorld(
                    center,
                    controller.value,
                  );
                  controller.value = VietnamWorldMapProjection.focusWorld(
                    world,
                    viewport: size,
                    scale: next,
                  );
                },
                child: InteractiveViewer(
                transformationController: controller,
                minScale: 0.22,
                maxScale: 6.0,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(80),
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: VietnamWorldMapProjection.designWidth,
                  height: VietnamWorldMapProjection.designHeight,
                  child: Image.asset(
                    VietnamWorldMapProjection.rasterAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFD8E8EF),
                      child: Center(
                        child: Text('Không tải được bản đồ Việt Nam'),
                      ),
                    ),
                  ),
                ),
              ),
              ),
              IgnorePointer(
                ignoring: false,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final scale = controller.value.getMaxScaleOnAxis();
                    final plottable = locations
                        .where((l) => l.hasReliableGeographicCoordinate)
                        .toList();
                    final clusters = clusterLocations(
                      locations: plottable,
                      scale: scale,
                    );
                    return Stack(
                      children: [
                        for (final cluster in clusters)
                          _positionedOverlay(
                            cluster.world,
                            child: cluster.members.length == 1
                                ? HeritageMapMarker(
                                    key: Key(
                                      'heritage-marker-${cluster.members.first.id}',
                                    ),
                                    location: cluster.members.first,
                                    selected:
                                        selectedId == cluster.members.first.id,
                                    dimmed:
                                        highlightedIds.isNotEmpty &&
                                        !highlightedIds.contains(
                                          cluster.members.first.id,
                                        ),
                                    onTap: () =>
                                        onSelect(cluster.members.first),
                                  )
                                : HeritageMapCluster(
                                    key: Key(
                                      'heritage-cluster-${cluster.members.map((m) => m.id).join(',')}',
                                    ),
                                    count: cluster.members.length,
                                    semanticLabel: cluster.members
                                        .map((m) => m.title)
                                        .join(', '),
                                    onTap: () => onClusterTap(cluster),
                                  ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _positionedOverlay(Offset world, {required Widget child}) {
    final screen = VietnamWorldMapProjection.worldToScreen(
      world,
      controller.value,
    );
    return Positioned(
      left: screen.dx - 22,
      top: screen.dy - 28,
      child: child,
    );
  }
}

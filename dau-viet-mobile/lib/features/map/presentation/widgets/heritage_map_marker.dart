import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/map_location_dto.dart';

IconData heritageKindIcon(String kind) {
  switch (kind.trim().toUpperCase()) {
    case 'BATTLEFIELD':
      return Icons.fort_rounded;
    case 'ANCIENT_CAPITAL':
      return Icons.account_balance_rounded;
    case 'ARCHAEOLOGICAL_SITE':
      return Icons.terrain_rounded;
    case 'MEMORIAL':
      return Icons.temple_buddhist_rounded;
    case 'SCHEMATIC_REGION':
      return Icons.public_rounded;
    default:
      return Icons.location_on_rounded;
  }
}

class HeritageMapMarker extends StatelessWidget {
  final MapLocationDto location;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const HeritageMapMarker({
    super.key,
    required this.location,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color ring;
    final IconData icon;
    switch (location.unlockState) {
      case MapUnlockState.unlocked:
        fill = const Color(0xFF1A5642);
        ring = const Color(0xFFE0AE45);
        icon = heritageKindIcon(location.kind);
      case MapUnlockState.available:
        fill = DauVietColors.heritageGreenLight;
        ring = const Color(0xFFD8BA73);
        icon = heritageKindIcon(location.kind);
      case MapUnlockState.locked:
        fill = const Color(0xFF8D8274);
        ring = const Color(0xFFC4B49A);
        icon = Icons.lock_rounded;
    }
    final size = selected ? 44.0 : 36.0;
    return Semantics(
      button: true,
      label: location.title,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: dimmed ? 0.38 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: selected ? 2.4 : 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: selected ? 10 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: selected ? 20 : 16, color: Colors.white),
              ),
              if (selected) ...[
                const SizedBox(height: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xF6FFF8EC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDEC8A4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        location.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2B1F17),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HeritageMapCluster extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final String semanticLabel;

  const HeritageMapCluster({
    super.key,
    required this.count,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1A5642),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE0AE45), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: DauVietTypography.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

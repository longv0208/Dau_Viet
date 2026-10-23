import 'package:flutter/material.dart';

import '../runtime/animation_manifest_dto.dart';
import 'effect_painters.dart';

/// v2 — Ambient overlays từ `environment{}` (RIVER_TIDE): sương + glow
/// nền render xuyên suốt scene, nằm GIỮA background image và painter
/// canvas — sương sau lưng object, không che narration hay object
/// images. Reduced-motion vẫn render (tĩnh, không motion).
///
/// `environment.waterLevel` KHÔNG thuộc overlay này — nó seed painter
/// trực tiếp (xem `toDefinition._seedRiver` / player init).
class EnvironmentOverlay extends StatelessWidget {
  final EnvironmentDto environment;
  final Widget child;

  const EnvironmentOverlay({
    super.key,
    required this.environment,
    required this.child,
  });

  bool get _hasAny => environment.mist > 0 || environment.glow > 0;

  @override
  Widget build(BuildContext context) {
    if (!_hasAny) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (environment.glow > 0)
          // Ambient glow trung tâm — bầu không khí ấm (ánh nến/đuốc).
          CustomPaint(
            painter: GlowPainter(
              center: const Offset(0.5, 0.42),
              intensity: environment.glow,
            ),
            child: const SizedBox.expand(),
          ),
        child,
        if (environment.mist > 0)
          // Mist vẽ TRÊN child nhưng alpha thấp — painter vẫn đọc được.
          CustomPaint(
            painter: MistPainter(intensity: environment.mist),
            child: const SizedBox.expand(),
          ),
      ],
    );
  }
}

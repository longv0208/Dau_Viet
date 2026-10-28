import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/tactile_3d_button.dart';
import '../../auth/data/auth_state.dart';
import '../../learning/data/learning_providers.dart';
import '../data/island_dto.dart';
import '../data/island_providers.dart';
import 'widgets/island_inventory_sheet.dart';
import 'widgets/island_scene.dart';
import 'widgets/island_slot_detail_card.dart';
import 'widgets/island_tile_sheet.dart';
import 'widgets/island_upgrade_panel.dart';
import 'widgets/island_visual_asset_manager.dart';

/// Màn hình chính Đảo Di Sản Cá Nhân 2.5D (`/island`).
/// Bổ sung trong ISLAND-07:
/// - Chuỗi animation 5 phase khi mở rộng đảo (camera -> mở đất mới -> mở slot mới -> hoàn thành),
///   có nút "BỎ QUA" và hỗ trợ Reduce Motion.
/// - Trải nghiệm hướng dẫn lần đầu (Onboarding) lưu theo từng tài khoản (`userId`),
///   có nút `?` để xem lại bất kỳ lúc nào.
/// - Hiệu ứng one-shot khi đặt/gỡ vật phẩm thành công và kích hoạt Confetti nhiều lần.
class IslandScreen extends ConsumerStatefulWidget {
  const IslandScreen({super.key});

  @override
  ConsumerState<IslandScreen> createState() => _IslandScreenState();
}

class _IslandScreenState extends ConsumerState<IslandScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedSlotId;
  bool _isMutating = false;
  bool _isSheetOpen = false;
  int _resetCameraVersion = 0;
  IslandCameraDirection _cameraDirection = IslandCameraDirection.northEast;

  void _rotateCameraLeft() {
    setState(() {
      _cameraDirection = _cameraDirection.nextCounterClockwise;
    });
  }

  void _rotateCameraRight() {
    setState(() {
      _cameraDirection = _cameraDirection.nextClockwise;
    });
  }

  void _resetCameraAndAngle() {
    setState(() {
      _cameraDirection = IslandCameraDirection.northEast;
      _resetCameraVersion++;
    });
  }

  // Confetti one-shot counter (A3)
  int _confettiTriggerCount = 0;

  // Hiệu ứng one-shot khi vừa đặt / gỡ vật phẩm (D1, D2)
  String? _activeEffectSlotId;
  int _placementEffectToken = 0;
  int _removalEffectToken = 0;

  // Chuỗi animation mở rộng đảo (Part B)
  AnimationController? _expansionController;
  int? _expandingFromTier;
  int? _expandingToTier;
  IslandDto? _completedUpgradeIsland;
  bool _finishingExpansion = false;

  // Trạng thái hướng dẫn người chơi gắn với userId (Part C / ISLAND-08 Part B)
  String? _loadedOnboardingUserId;
  int? _loadedOnboardingTier;
  bool _showWelcomeCard = false;
  bool _showSlotStepHint = false;
  bool _showUpgradeReadyToast = false;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final island = ref.read(islandControllerProvider).asData?.value;
      if (island != null) {
        _syncOnboardingForCurrentUser(island);
      }
    });
  }

  @override
  void dispose() {
    _expansionController?.stop();
    _expansionController?.dispose();
    _expansionController = null;
    _transformationController.dispose();
    super.dispose();
  }

  /// Trả về `userId` đã xác thực (hoặc `'mock_user'` khi chạy chế độ demo).
  /// Trả về `null` nếu chưa có phiên đăng nhập hợp lệ — tuyệt đối không dùng chung `'guest'`.
  String? _currentAuthenticatedUserId() {
    final auth = ref.read(authSessionProvider);
    final profileId = auth.profile?.id.trim();
    if (auth.status == AuthStatus.authenticated &&
        profileId != null &&
        profileId.isNotEmpty) {
      return profileId;
    }
    if (auth.status == AuthStatus.guest && ApiConfig.useMock) {
      return 'mock_user';
    }
    return null;
  }

  void _resetTransientUserUiState() {
    _expansionController?.stop();
    _expansionController?.dispose();
    _expansionController = null;
    _expandingFromTier = null;
    _expandingToTier = null;
    _completedUpgradeIsland = null;
    _finishingExpansion = false;
    _loadedOnboardingUserId = null;
    _loadedOnboardingTier = null;
    _showWelcomeCard = false;
    _showSlotStepHint = false;
    _showUpgradeReadyToast = false;
    _selectedSlotId = null;
  }

  Future<void> _syncOnboardingForCurrentUser(IslandDto island) async {
    final userId = _currentAuthenticatedUserId();
    if (userId == null) return;
    if (_loadedOnboardingUserId == userId &&
        _loadedOnboardingTier == island.tier) {
      return;
    }
    final expectedUserId = userId;
    final expectedTier = island.tier;
    _loadedOnboardingUserId = expectedUserId;
    _loadedOnboardingTier = expectedTier;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _currentAuthenticatedUserId() != expectedUserId) return;
      final latestIsland = ref.read(islandControllerProvider).asData?.value;
      if (latestIsland != null && latestIsland.tier != expectedTier) return;

      final doneKey = 'dv_island_onboarding_done_$expectedUserId';
      final upgradeHintKey =
          'dv_island_upgrade_hint_${expectedUserId}_tier_$expectedTier';

      final onboardingDone = prefs.getBool(doneKey) ?? false;
      final upgradeHintSeen = prefs.getBool(upgradeHintKey) ?? false;

      if (!onboardingDone && expectedTier == 1) {
        setState(() {
          _showWelcomeCard = true;
          _showUpgradeReadyToast = false;
        });
      } else if (island.canUpgrade && !island.isMaxTier && !upgradeHintSeen) {
        setState(() {
          _showUpgradeReadyToast = true;
        });
        await prefs.setBool(upgradeHintKey, true);
      }
    } catch (_) {}
  }

  Future<void> _markOnboardingCompleted({required bool exploreSlot}) async {
    final userId = _currentAuthenticatedUserId();
    setState(() {
      _showWelcomeCard = false;
      _showSlotStepHint = exploreSlot;
    });
    if (userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (mounted && _currentAuthenticatedUserId() == userId) {
          await prefs.setBool('dv_island_onboarding_done_$userId', true);
        }
      } catch (_) {}
    }

    if (exploreSlot && mounted) {
      final island = ref.read(islandControllerProvider).asData?.value;
      if (island != null) {
        final firstEmpty = island.slots.cast<IslandSlotDto?>().firstWhere(
          (s) => s != null && !s.isLocked && s.isEmpty,
          orElse: () => null,
        );
        if (firstEmpty != null) {
          setState(() {
            _selectedSlotId = firstEmpty.slotId;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authSessionProvider, (previous, next) {
      final prevId = previous?.profile?.id;
      final nextId = next.profile?.id;
      final prevStatus = previous?.status;
      final nextStatus = next.status;
      if (prevStatus != nextStatus || prevId != nextId) {
        if (mounted) {
          setState(_resetTransientUserUiState);
        }
        final currentIsland = ref.read(islandControllerProvider).asData?.value;
        if (currentIsland != null && _currentAuthenticatedUserId() != null) {
          _syncOnboardingForCurrentUser(currentIsland);
        }
      }
    });

    ref.listen<AsyncValue<IslandDto>>(islandControllerProvider, (previous, next) {
      final island = next.asData?.value;
      if (island != null) {
        _syncOnboardingForCurrentUser(island);
      }
    });

    final islandAsync = ref.watch(islandControllerProvider);
    final walletAsync = ref.watch(islandWalletProvider);

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: GoldConfettiOverlay(
        trigger: false,
        triggerCount: _confettiTriggerCount,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(
                context,
                islandAsync.asData?.value,
                walletAsync.asData?.value,
              ),
              Expanded(
                child: islandAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: DauVietColors.cinnabarRed,
                    ),
                  ),
                  error: (error, stack) => _buildErrorView(error),
                  data: (island) => (island.board != null &&
                          island.board!.tiles.isEmpty &&
                          island.board!.fromBackend)
                      // Board metadata tồn tại nhưng không có tile nào =
                      // layout chưa cấu hình / API trả sai — KHÔNG im lặng
                      // vẽ nước, không fallback mock trên production.
                      ? _buildEmptyIslandView(island)
                      : _buildIslandContent(island),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    IslandDto? island,
    WalletDto? wallet,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: const Border(
          bottom: BorderSide(color: DauVietColors.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: DauVietColors.woodBrown,
              size: 20,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'ĐẢO DI SẢN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DauVietColors.cinnabarRed,
                          letterSpacing: 0.4,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (island != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DauVietColors.heritageGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          island.tierScaleLabel,
                          style: DauVietTypography.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  island != null
                      ? '${island.tierScaleLabel} — Level tài khoản ${island.currentLevel}'
                      : 'Không gian di sản cá nhân',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Chỉ số Điểm Sử Ký thật
          GestureDetector(
            onTap: () => context.push('/island/shop'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: DauVietColors.parchmentContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: DauVietColors.imperialGold,
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: DauVietColors.imperialGold,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wallet != null ? '${wallet.historyPoints}' : '...',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.woodBrown,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Nút Kho Đồ
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Kho Đồ Di Sản',
            icon: const Icon(
              Icons.inventory_2_rounded,
              color: DauVietColors.woodBrown,
              size: 21,
            ),
            onPressed: island != null
                ? () {
                    final empty =
                        island.slots.where((s) => s.isEmpty).firstOrNull ??
                        island.slots.firstOrNull;
                    if (empty != null) {
                      _openInventorySheet(empty);
                    } else {
                      context.push('/island/shop');
                    }
                  }
                : () => context.push('/island/shop'),
          ),

          // Nút Cửa Hàng
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Cửa Hàng Di Sản',
            icon: const Icon(
              Icons.storefront_rounded,
              color: DauVietColors.cinnabarRed,
              size: 22,
            ),
            onPressed: () => context.push('/island/shop'),
          ),

          // Nút Mở Rộng Đảo
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Mở Rộng Đảo',
                icon: const Icon(
                  Icons.landscape_rounded,
                  color: DauVietColors.heritageGreen,
                  size: 22,
                ),
                onPressed: island != null
                    ? () => _openUpgradePanel(island)
                    : null,
              ),
              if (island != null && island.canUpgrade && !island.isMaxTier)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DauVietColors.parchmentSurface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Nút Xem lại hướng dẫn (C5)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Hướng dẫn Đảo Di Sản',
            icon: const Icon(
              Icons.help_outline_rounded,
              color: DauVietColors.woodBrown,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _showWelcomeCard = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIslandContent(IslandDto island) {
    final selectedSlot = island.slots.cast<IslandSlotDto?>().firstWhere(
      (s) => s?.slotId == _selectedSlotId,
      orElse: () => null,
    );
    final isAnimatingExpansion =
        _expansionController != null &&
        _expansionController!.isAnimating &&
        _expandingFromTier != null &&
        _expandingToTier != null;

    return Stack(
      children: [
        // 1. Canvas 2.5D Isometric Scene (lắng nghe tiến độ mở rộng đảo nếu đang chạy)
        Positioned.fill(
          child: isAnimatingExpansion
              ? AnimatedBuilder(
                  animation: _expansionController!,
                  builder: (context, _) {
                    return IslandScene(
                      island: island,
                      selectedSlotId: _selectedSlotId,
                      transformationController: _transformationController,
                      cameraDirection: _cameraDirection,
                      resetCameraVersion: _resetCameraVersion,
                      expansionTransition: IslandExpansionTransition(
                        fromTier: _expandingFromTier!,
                        toTier: _expandingToTier!,
                        progress: _expansionController!.value,
                      ),
                      activeEffectSlotId: _activeEffectSlotId,
                      placementEffectToken: _placementEffectToken,
                      removalEffectToken: _removalEffectToken,
                      onSelectSlot: (_) {},
                    );
                  },
                )
              : IslandScene(
                  island: island,
                  selectedSlotId: _selectedSlotId,
                  transformationController: _transformationController,
                  cameraDirection: _cameraDirection,
                  resetCameraVersion: _resetCameraVersion,
                  activeEffectSlotId: _activeEffectSlotId,
                  placementEffectToken: _placementEffectToken,
                  removalEffectToken: _removalEffectToken,
                  onSelectSlot: (slot) {
                    setState(() {
                      _selectedSlotId = slot?.slotId;
                      if (slot == null) _showSlotStepHint = false;
                    });
                  },
                ),
        ),

        // 2. Nút "BỎ QUA" khi chuỗi animation mở rộng đảo đang chạy (Part B4)
        if (isAnimatingExpansion)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xD930251F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: DauVietColors.imperialGold,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: DauVietColors.imperialGold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Đang khai mở ${island.tierScaleLabel}...',
                        style: DauVietTypography.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DauVietColors.parchmentSurface,
                    foregroundColor: DauVietColors.woodBrown,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: DauVietColors.imperialGold,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onPressed: _skipExpansionAnimation,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text(
                    'BỎ QUA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // 3. Thông báo ngắn khi đủ điều kiện mở rộng đảo (Part C4)
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            _showUpgradeReadyToast &&
            island.canUpgrade &&
            !island.isMaxTier)
          Positioned(
            left: 12,
            right: 58,
            top: 10,
            child: _buildUpgradeReadyBanner(island),
          ),

        // 4. Chỉ dẫn bước chọn slot trống sau khi bấm "KHÁM PHÁ" (Part C3)
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            _showSlotStepHint &&
            selectedSlot != null &&
            selectedSlot.isEmpty)
          Positioned(
            left: 12,
            right: 58,
            top: 10,
            child: _buildSlotStepHintBanner(),
          ),

        // 5. Bottom Sheet chi tiết tile/slot gọn gàng, chuẩn phong cách Cozy Heritage (Part D4)
        if (!isAnimatingExpansion && selectedSlot != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IslandTileSheet(
              slot: selectedSlot,
              tile: island.board?.tileForSlotDto(selectedSlot),
              islandTier: island.tier,
              onClose: () => setState(() {
                _selectedSlotId = null;
                _showSlotStepHint = false;
              }),
              onPlaceItem: () => _openInventorySheet(selectedSlot),
              onRemoveItem: () => _removePlacement(selectedSlot),
              onViewRequirements: () => _openUpgradePanel(island),
            ),
          ),

        // Thanh công cụ nổi tối giản ở đáy khi không chọn slot
        if (!isAnimatingExpansion && selectedSlot == null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xF2FFF8EC),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFD9C098), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFloatingActionBtn(
                        icon: Icons.inventory_2_outlined,
                        label: 'Kho đồ',
                        onTap: () {
                          final empty =
                              island.slots.where((s) => s.isEmpty).firstOrNull ??
                              island.slots.firstOrNull;
                          if (empty != null) {
                            _openInventorySheet(empty);
                          } else {
                            context.push('/island/shop');
                          }
                        },
                      ),
                      _buildFloatingActionBtn(
                        icon: Icons.storefront_outlined,
                        label: 'Cửa hàng',
                        onTap: () => context.push('/island/shop'),
                      ),
                      _buildFloatingActionBtn(
                        icon: Icons.landscape_rounded,
                        label: 'Mở rộng đảo',
                        isHighlight: island.canUpgrade && !island.isMaxTier,
                        onTap: () => _openUpgradePanel(island),
                      ),
                      _buildFloatingActionBtn(
                        icon: Icons.threesixty_rounded,
                        label: 'Góc ${_cameraDirection.shortCode}',
                        onTap: _rotateCameraRight,
                      ),
                      _buildFloatingActionBtn(
                        icon: Icons.center_focus_strong_rounded,
                        label: 'Căn giữa',
                        onTap: _resetCameraAndAngle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 6. Cụm điều khiển Góc Nhìn Isometric (4 hướng) & Reset Camera (10A)
        if (!isAnimatingExpansion)
          Positioned(
            top: 10,
            right: 10,
            child: _buildCameraRotationPod(),
          ),

        // 7. Thẻ Chào mừng / Hướng dẫn lần đầu (Part C2 & C3)
        if (!isAnimatingExpansion && _showWelcomeCard)
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: _buildWelcomeOnboardingCard(island),
            ),
          ),
      ],
    );
  }

  /// Cụm điều khiển Góc Nhìn Isometric (4 hướng: Đông Bắc, Đông Nam, Tây Nam, Tây Bắc) & Reset Camera (10A).
  Widget _buildCameraRotationPod() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xF2FFF8EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9C098), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPodIconBtn(
            icon: Icons.rotate_left_rounded,
            tooltip: 'Xoay góc nhìn sang trái (-90°)',
            onTap: _rotateCameraLeft,
          ),
          InkWell(
            onTap: _rotateCameraRight,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: _cameraDirection.quarterTurns * 0.25,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.explore_rounded,
                      size: 15,
                      color: DauVietColors.cinnabarRed,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _cameraDirection.labelVi,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.woodBrown,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildPodIconBtn(
            icon: Icons.rotate_right_rounded,
            tooltip: 'Xoay góc nhìn sang phải (+90°)',
            onTap: _rotateCameraRight,
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            color: const Color(0xFFD9C098),
          ),
          _buildPodIconBtn(
            icon: Icons.center_focus_strong_rounded,
            tooltip: 'Căn giữa & về góc nhìn mặc định (Đông Bắc)',
            onTap: _resetCameraAndAngle,
          ),
        ],
      ),
    );
  }

  Widget _buildPodIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 19,
            color: DauVietColors.woodBrown,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isHighlight
                  ? DauVietColors.cinnabarRed
                  : const Color(0xFF5D4037),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: DauVietTypography.bodySmall.copyWith(
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight
                    ? DauVietColors.cinnabarRed
                    : const Color(0xFF49382C),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thẻ chào mừng lần đầu ngắn gọn, giải thích rõ mục đích Đảo Di Sản,
  /// sự khác biệt giữa EXP/Level (mở rộng đảo) và Điểm Sử Ký (mua vật phẩm).
  Widget _buildWelcomeOnboardingCard(IslandDto island) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DauVietColors.imperialGold, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: DauVietColors.parchmentContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.temple_buddhist_rounded,
                  color: DauVietColors.cinnabarRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chào mừng đến Đảo Di Sản!',
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DauVietColors.cinnabarRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy xây dựng không gian văn hóa Việt của riêng bạn.',
            style: DauVietTypography.bodyMedium.copyWith(
              color: DauVietColors.inkText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _buildGuideBullet(
            icon: Icons.add_location_alt_rounded,
            color: DauVietColors.heritageGreen,
            title: 'Trang trí Đảo cá nhân',
            body:
                'Chạm vào các ô đất trống (+) để đặt công trình văn hóa hoặc mô hình lịch sử từ Kho vật phẩm.',
          ),
          const SizedBox(height: 10),
          _buildGuideBullet(
            icon: Icons.school_rounded,
            color: DauVietColors.cinnabarRed,
            title: 'Học bài tích lũy EXP → Nâng Level mở đảo',
            body:
                'Hoàn thành bài học giúp tích lũy EXP và tăng Level tài khoản. Khi đủ Level, bạn có thể chủ động mở rộng lên Đảo vừa và Đảo lớn.',
          ),
          const SizedBox(height: 10),
          _buildGuideBullet(
            icon: Icons.stars_rounded,
            color: DauVietColors.imperialGold,
            title: 'Điểm Sử Ký → Mua vật phẩm Cửa hàng',
            body:
                'Điểm Sử Ký dùng để mua đồ trang trí trong Cửa Hàng Di Sản (không dùng để nâng Level).',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      _markOnboardingCompleted(exploreSlot: false),
                  child: Text(
                    'BỎ QUA',
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: DauVietColors.inkMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Tactile3DButton(
                  label: 'KHÁM PHÁ',
                  height: 40,
                  icon: Icons.explore_rounded,
                  variant: Tactile3DVariant.heritageGreen,
                  onPressed: () =>
                      _markOnboardingCompleted(exploreSlot: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBullet({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DauVietColors.inkText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotStepHintBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DauVietColors.heritageGreen, width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.touch_app_rounded,
            size: 18,
            color: DauVietColors.heritageGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bạn đang chọn một ô đất trống. Nhấn "CHỌN VẬT PHẨM ĐẶT LÊN ĐẢO" ở thẻ bên dưới để mở Kho vật phẩm!',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkText,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showSlotStepHint = false),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeReadyBanner(IslandDto island) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: DauVietColors.cinnabarRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _showUpgradeReadyToast = false);
                _openUpgradePanel(island);
              },
              child: Text(
                'Bạn đã đạt Level ${island.currentLevel} — đủ điều kiện mở rộng đảo! Chạm vào đây để khai mở vùng đất mới.',
                style: DauVietTypography.bodySmall.copyWith(
                  color: DauVietColors.inkText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _showUpgradeReadyToast = false),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Board hợp lệ nhưng `tiles` rỗng — layout chưa được cấu hình phía Admin
  /// hoặc version đang pin thiếu dữ liệu. Thông báo rõ ràng, không suy đoán.
  Widget _buildEmptyIslandView(IslandDto island) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.terrain_rounded,
              size: 56,
              color: DauVietColors.woodBrown,
            ),
            const SizedBox(height: 16),
            Text(
              'Đảo chưa được lập bản đồ',
              style: DauVietTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bố cục đảo "${island.layoutCode ?? 'hiện tại'}" '
              '(phiên bản ${island.layoutVersionNumber}) chưa có ô đất nào. '
              'Vui lòng báo quản trị viên xuất bản lại layout.',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            Tactile3DButton(
              label: 'TẢI LẠI',
              variant: Tactile3DVariant.secondaryParchment,
              onPressed: () =>
                  ref.read(islandControllerProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: DauVietColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Không thể kết nối Đảo Di Sản',
              style: DauVietTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error is ApiException
                  ? error.error.message
                  : 'Vui lòng kiểm tra lại kết nối mạng.',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            Tactile3DButton(
              label: 'THỬ LẠI',
              variant: Tactile3DVariant.secondaryParchment,
              onPressed: () =>
                  ref.read(islandControllerProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInventorySheet(IslandSlotDto slot) async {
    if (_isSheetOpen || _isMutating) return;
    _isSheetOpen = true;
    setState(() => _showSlotStepHint = false);
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => IslandInventorySheet(
          targetSlot: slot,
          onSelectItem: (itemId) => _placeItem(slot, itemId),
        ),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  Future<void> _placeItem(IslandSlotDto slot, String itemId) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);

    try {
      await ref
          .read(islandControllerProvider.notifier)
          .placeItem(slotId: slot.slotId, itemId: itemId);

      if (!mounted) return;
      setState(() {
        _activeEffectSlotId = slot.slotId;
        _placementEffectToken++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đặt vật phẩm lên Đảo Di Sản thành công!'),
          backgroundColor: DauVietColors.heritageGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 409
          ? 'Trạng thái đảo vừa thay đổi, dữ liệu đã được làm mới. Vui lòng thử lại.'
          : e.error.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: DauVietColors.errorRed),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể đặt vật phẩm, vui lòng thử lại.'),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _removePlacement(IslandSlotDto slot) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);

    try {
      await ref
          .read(islandControllerProvider.notifier)
          .removePlacement(slotId: slot.slotId);

      if (!mounted) return;
      setState(() {
        _activeEffectSlotId = slot.slotId;
        _removalEffectToken++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã cất vật phẩm về kho. Bạn có thể chọn vật phẩm khác cho ô này.',
          ),
          backgroundColor: DauVietColors.heritageGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 409
          ? 'Trạng thái đảo vừa thay đổi, dữ liệu đã được làm mới. Vui lòng thử lại.'
          : e.error.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: DauVietColors.errorRed),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cất vật phẩm, vui lòng thử lại.'),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _openUpgradePanel(IslandDto island) async {
    if (_isSheetOpen || _isMutating) return;
    _isSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => IslandUpgradePanel(
          island: island,
          isUpgrading: _isMutating,
          onUpgrade: () {
            Navigator.of(ctx).pop();
            _executeUpgrade(previousTier: island.tier);
          },
        ),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  /// Phase 1 -> 5: Thực hiện nâng cấp đảo và chạy chuỗi animation mở rộng đất (Part B).
  Future<void> _executeUpgrade({required int previousTier}) async {
    if (_isMutating) return;
    setState(() {
      _isMutating = true;
      _selectedSlotId = null;
    });

    try {
      final updated = await ref.read(islandControllerProvider.notifier).upgrade();
      if (!mounted) return;

      // Chỉ kích hoạt chuỗi mở rộng khi backend xác nhận thành công và Tier mới > Tier cũ (B2)
      if (updated.tier <= previousTier) {
        return;
      }

      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion) {
        setState(() {
          _confettiTriggerCount++;
          _resetCameraVersion++;
          _showUpgradeReadyToast = false;
        });
        _showExpansionCompletedDialog(updated);
        return;
      }

      _startExpansionSequence(
        fromTier: previousTier,
        toTier: updated.tier,
        updatedIsland: updated,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 409
          ? 'Trạng thái đảo vừa được cập nhật. Vui lòng kiểm tra và thử lại.'
          : e.error.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: DauVietColors.errorRed),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể mở rộng đảo lúc này, vui lòng thử lại.'),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _startExpansionSequence({
    required int fromTier,
    required int toTier,
    required IslandDto updatedIsland,
  }) {
    _expansionController?.stop();
    _expansionController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _expansionController = controller;
    _finishingExpansion = false;

    setState(() {
      _expandingFromTier = fromTier;
      _expandingToTier = toTier;
      _completedUpgradeIsland = updatedIsland;
      _showUpgradeReadyToast = false;
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _finishExpansionSequence(showCompletionDialog: true);
      }
    });

    controller.forward(from: 0.0);
  }

  void _skipExpansionAnimation() {
    _expansionController?.stop();
    _finishExpansionSequence(showCompletionDialog: true);
  }

  void _finishExpansionSequence({required bool showCompletionDialog}) {
    if (_finishingExpansion) return;
    _finishingExpansion = true;

    final completedIsland = _completedUpgradeIsland;
    _expansionController?.stop();
    _expansionController?.dispose();
    _expansionController = null;

    if (!mounted) return;
    setState(() {
      _expandingFromTier = null;
      _expandingToTier = null;
      _completedUpgradeIsland = null;
      _confettiTriggerCount++;
      _resetCameraVersion++;
    });

    if (showCompletionDialog && completedIsland != null && mounted) {
      _showExpansionCompletedDialog(completedIsland);
    }
  }

  /// Phase 5: Hộp thoại chúc mừng sau khi mở rộng đảo thành công (Part B3 Phase 5).
  void _showExpansionCompletedDialog(IslandDto updated) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DauVietColors.parchmentSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: DauVietColors.imperialGold, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.celebration_rounded,
              color: DauVietColors.cinnabarRed,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'KHAI MỞ ${updated.tierScaleLabel.toUpperCase()}!',
                style: DauVietTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DauVietColors.cinnabarRed,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Chúc mừng! Bạn đã mở rộng lên ${updated.tierScaleLabel} và có ${updated.unlockedSlotCount} vị trí trang trí cho không gian văn hóa Việt của mình.',
          style: DauVietTypography.bodyMedium.copyWith(
            color: DauVietColors.inkText,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/island/shop');
            },
            child: Text(
              'ĐẾN CỬA HÀNG',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.cinnabarRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DauVietColors.heritageGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'KHÁM PHÁ ĐẢO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/kabi_mascot_widget.dart';
import '../../../core/widgets/rare_frame_badge.dart';
import '../../auth/data/auth_state.dart';
import '../../learning/data/learning_providers.dart';
import '../data/island_dto.dart';
import '../data/island_providers.dart';
import 'widgets/island_inventory_sheet.dart';
import 'widgets/island_inventory_tray.dart';
import 'widgets/island_scene.dart';
import 'widgets/island_tier_tabs.dart';
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
  String? _selectedTrayItemId;   // Item đang chọn trên khay Kho Vật Phẩm
  int _previewTier = 1;          // Tab cấp đảo đang xem (1: Đảo An Lạc, 2: Đảo Phồn Thịnh, 3: Đảo Trường Tồn)
  bool _isEditMode = false;      // Issue #46: false = Chế độ Tham quan (Màn 1 & 3), true = Chế độ Bài trí (Màn 2)
  final Set<String> _flippedSlotIds = <String>{}; // Issue #46 AC-3: lưu hướng xoay ngang của vật phẩm trên đảo
  bool _isMutating = false;
  bool _isSheetOpen = false;
  int _resetCameraVersion = 0;
  IslandCameraDirection _cameraDirection = IslandCameraDirection.northEast;
  void _rotateCameraRight() {
    setState(() {
      _cameraDirection = _cameraDirection.nextClockwise;
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
    _isEditMode = false;
    _flippedSlotIds.clear();
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

      if (!onboardingDone && expectedTier == 1 && _selectedSlotId == null) {
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
      backgroundColor: DauVietColors.paperBackground,
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
    final bool isCompactHeader = MediaQuery.sizeOf(context).width < 480;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF6ECD9),
        border: Border(
          bottom: BorderSide(color: Color(0xFFDEC9A8), width: 1.2),
        ),
      ),
      child: Row(
        children: [
          // Nút quay lại (<) bo tròn nền kem bên trái (Issue #46 AC-1)
          InkWell(
            onTap: () {
              if (_isEditMode) {
                setState(() {
                  _isEditMode = false;
                  _selectedSlotId = null;
                  _selectedTrayItemId = null;
                });
                return;
              }
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF3E4),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDEC9A8), width: 1.3),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF4A3728),
                size: 22,
              ),
            ),
          ),

          // Tiêu đề ĐẢO DI SẢN chính giữa màu đỏ chu sa (Issue #46 AC-1)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ĐẢO DI SẢN',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 0.6,
                  ),
                ),
                if (island != null)
                  Text(
                    '${island.tierScaleLabel} · ${island.legacyTierScaleLabel} (LV${island.currentLevel})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: const Color(0xFF7D6B59),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // Cụm bên phải: Nút trợ giúp (?), Điểm Sử Ký (⭐ 250) & lối tắt Cửa hàng / Mở rộng
          InkWell(
            onTap: () {
              setState(() {
                _showWelcomeCard = true;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF3E4),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDEC9A8), width: 1.2),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFF4A3728),
                size: 17,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Huy hiệu Điểm Sử Ký / Sao (⭐ 250)
          GestureDetector(
            onTap: () => context.push('/island/shop'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF3E4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFDEC9A8),
                  width: 1.3,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFE6A117),
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wallet != null ? '${wallet.historyPoints}' : '...',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3E2D20),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isCompactHeader) ...[
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Cửa Hàng Di Sản',
              icon: const Icon(
                Icons.storefront_rounded,
                color: DauVietColors.cinnabarRed,
                size: 20,
              ),
              onPressed: () => context.push('/island/shop'),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Mở Rộng Đảo',
              icon: const Icon(
                Icons.landscape_rounded,
                color: DauVietColors.heritageGreen,
                size: 20,
              ),
              onPressed:
                  island != null ? () => _openUpgradePanel(island) : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIslandContent(IslandDto island) {
    if (_previewTier < 1) _previewTier = 1;
    if (_previewTier > island.maxTier) _previewTier = island.maxTier;

    final selectedSlot = island.slots.cast<IslandSlotDto?>().firstWhere(
      (s) => s?.slotId == _selectedSlotId,
      orElse: () => null,
    );
    final isAnimatingExpansion =
        _expansionController != null &&
        _expansionController!.isAnimating &&
        _expandingFromTier != null &&
        _expandingToTier != null;

    final visibleIsland = _islandForTier(island, _previewTier);

    return Stack(
      children: [
        // 1. Canvas 2.5D Isometric Scene (có nền vịnh Hạ Long & đảo phụ phía xa)
        Positioned.fill(
          child: isAnimatingExpansion
              ? AnimatedBuilder(
                  animation: _expansionController!,
                  builder: (context, _) {
                    return IslandScene(
                      island: visibleIsland,
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
                      isEditMode: _isEditMode,
                      flippedSlotIds: _flippedSlotIds,
                      previewTier: _previewTier,
                      onSelectTier: _handleSelectTier,
                      onSelectSlot: (_) {},
                    );
                  },
                )
              : IslandScene(
                  island: visibleIsland,
                  selectedSlotId: _selectedSlotId,
                  transformationController: _transformationController,
                  cameraDirection: _cameraDirection,
                  resetCameraVersion: _resetCameraVersion,
                  activeEffectSlotId: _activeEffectSlotId,
                  placementEffectToken: _placementEffectToken,
                  removalEffectToken: _removalEffectToken,
                  isEditMode: _isEditMode,
                  flippedSlotIds: _flippedSlotIds,
                  previewTier: _previewTier,
                  onSelectTier: _handleSelectTier,
                  onSelectSlot: (slot) => _onSlotTap(slot, island),
                ),
        ),

        // 2. Thanh Tab 3 Cấp Đảo + Thẻ Thông tin Đảo (Island Summary Card) (Issue #46 AC-1)
        if (!isAnimatingExpansion && !_showWelcomeCard)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isEditMode) ...[
                  IslandTierTabs(
                    island: island,
                    previewTier: _previewTier,
                    onSelectTier: _handleSelectTier,
                  ),
                  const SizedBox(height: 8),
                ],
                _buildIslandSummaryCard(island, isCompact: _isEditMode),
              ],
            ),
          ),

        // 3. Hai nút điều hướng trái/phải (< / >) chuyển nhanh giữa các cấp đảo ở Chế độ Tham quan (AC-1)
        if (!isAnimatingExpansion && !_showWelcomeCard && !_isEditMode) ...[
          Positioned(
            left: 10,
            top: 250,
            child: _buildTierNavArrowButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Đảo trước',
              onTap: () {
                final prev = _previewTier > 1 ? _previewTier - 1 : island.maxTier;
                _handleSelectTier(prev);
              },
            ),
          ),
          Positioned(
            right: 10,
            top: 250,
            child: _buildTierNavArrowButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Đảo tiếp theo',
              onTap: () {
                final next = _previewTier < island.maxTier ? _previewTier + 1 : 1;
                _handleSelectTier(next);
              },
            ),
          ),
        ],

        // 4. Cụm 3 nút công cụ nổi dọc bên phải ở Chế độ Bài trí: Lưu đảo, Xoay, Xóa (Issue #46 AC-3)
        if (!isAnimatingExpansion && !_showWelcomeCard && _isEditMode)
          Positioned(
            top: 84,
            right: 12,
            child: _buildEditFloatingTools(island, selectedSlot),
          ),

        // 5. Nút "BỎ QUA" khi chuỗi animation mở rộng đảo đang chạy
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
                    color: DauVietColors.inkText.withValues(alpha: 0.85),
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
                DongSonButton(
                  label: 'BỎ QUA',
                  icon: Icons.skip_next_rounded,
                  variant: DongSonButtonVariant.secondaryParchment,
                  height: 40,
                  onPressed: _skipExpansionAnimation,
                ),
              ],
            ),
          ),

        // 6. Thông báo ngắn khi đủ điều kiện mở rộng đảo
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            _showUpgradeReadyToast &&
            island.canUpgrade &&
            !island.isMaxTier)
          Positioned(
            left: 12,
            right: 12,
            top: _isEditMode ? 76 : 156,
            child: _buildUpgradeReadyBanner(island),
          ),

        // 7. Chỉ dẫn bước chọn slot trống sau khi bấm "KHÁM PHÁ"
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            _showSlotStepHint &&
            selectedSlot != null &&
            selectedSlot.isEmpty)
          Positioned(
            left: 12,
            right: 12,
            top: _isEditMode ? 76 : 156,
            child: _buildSlotStepHintBanner(),
          ),

        // 8. Bottom Sheet chi tiết tile/slot khi chạm vào ô ở Chế độ Tham quan
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            !_isEditMode &&
            selectedSlot != null)
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

        // 9. Trợ lý Rùa Kabi đội nón lá ở góc dưới trái khi ở Chế độ Tham quan (Màn 1 & Màn 3 — AC-1)
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            !_isEditMode &&
            selectedSlot == null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: _buildKabiGuideOverlay(island),
          ),

        // 10. Khay Kho Vật Phẩm Phân loại 5 Tab & Lưới 4 Cột khi ở Chế độ Bài trí (Màn 2 — AC-4)
        if (!isAnimatingExpansion && !_showWelcomeCard && _isEditMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IslandInventoryTray(
              island: island,
              selectedItemId: _selectedTrayItemId,
              onSelectItem: (itemId) {
                setState(() {
                  _selectedTrayItemId = itemId;
                });
              },
            ),
          ),

        // 11. Thẻ Chào mừng / Hướng dẫn lần đầu
        if (!isAnimatingExpansion && _showWelcomeCard)
          Positioned.fill(
            child: Container(
              color: DauVietColors.inkText.withValues(alpha: 0.38),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: _buildWelcomeOnboardingCard(island),
            ),
          ),
      ],
    );
  }

  void _handleSelectTier(int tier) {
    setState(() {
      _previewTier = tier;
      _selectedSlotId = null;
      _selectedTrayItemId = null;
      _resetCameraVersion++;
    });
  }

  /// Thẻ Thông tin Đảo (Island Summary Card) nằm ngay dưới thanh tab (Issue #46 AC-1 & AC-2).
  Widget _buildIslandSummaryCard(IslandDto island, {required bool isCompact}) {
    final tierName = IslandDto.tierHeritageName(_previewTier);
    final areaLabel = 'Diện tích: ${island.tierAreaDimensionLabel(_previewTier)}';
    final isTierUnlocked = _previewTier <= island.tier;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF1E0).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDEC9A8), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          IslandTierThumbnail(
            tier: _previewTier,
            isUnlocked: isTierUnlocked,
            width: isCompact ? 42 : 50,
            height: isCompact ? 34 : 42,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tierName,
                  style: DauVietTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2E2118),
                    fontSize: 14.5,
                  ),
                ),
                Text(
                  areaLabel,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5D4837),
                    fontSize: 11.5,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Nơi lưu giữ những dấu ấn di sản và vật phẩm bạn đã sưu tầm.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: const Color(0xFF6E5A49),
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isCompact || !isTierUnlocked)
            InkWell(
              onTap: () => _openUpgradePanel(island),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E4CA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD8C09B)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: Color(0xFF5A4635),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Mở rộng đảo',
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4A3728),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4D3B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Đang sử dụng',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isEditMode = true;
                      _selectedSlotId = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E4C8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD5BC94)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          size: 12,
                          color: Color(0xFF4A3728),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bài trí',
                          style: DauVietTypography.bodySmall.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4A3728),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Nút mũi tên tròn (< / >) hai bên mép màn hình chuyển nhanh giữa các cấp đảo.
  Widget _buildTierNavArrowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF1E0).withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDEC9A8), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF4A3728), size: 24),
        ),
      ),
    );
  }

  /// Cụm 3 nút công cụ nổi (Lưu đảo / Xoay / Xóa) dọc bên phải màn hình khi ở Chế độ Bài trí (Issue #46 AC-3).
  Widget _buildEditFloatingTools(
    IslandDto island,
    IslandSlotDto? selectedSlot,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatingToolButton(
          icon: Icons.inventory_2_outlined,
          label: 'Lưu đảo',
          onTap: () {
            setState(() {
              _isEditMode = false;
              _selectedSlotId = null;
              _selectedTrayItemId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã lưu bố cục Đảo Di Sản!'),
                backgroundColor: Color(0xFF1E4D3B),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildFloatingToolButton(
          icon: Icons.rotate_right_rounded,
          label: 'Xoay',
          onTap: () {
            if (selectedSlot != null && selectedSlot.placement != null) {
              setState(() {
                if (_flippedSlotIds.contains(selectedSlot.slotId)) {
                  _flippedSlotIds.remove(selectedSlot.slotId);
                } else {
                  _flippedSlotIds.add(selectedSlot.slotId);
                }
              });
            } else {
              _rotateCameraRight();
            }
          },
        ),
        const SizedBox(height: 8),
        _buildFloatingToolButton(
          icon: Icons.delete_outline_rounded,
          label: 'Xóa',
          onTap: () {
            if (selectedSlot != null && selectedSlot.placement != null) {
              _removePlacement(selectedSlot);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Hãy chạm chọn một vật phẩm đang đặt trên đảo để xóa.',
                  ),
                  backgroundColor: Color(0xFF5A4635),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildFloatingToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF1E0).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDEC9A8), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF4A3728), size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3E2D20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Trợ lý Rùa Kabi đội nón lá kèm khung thoại hướng dẫn tự nhiên ở góc dưới trái (Issue #46 AC-1).
  Widget _buildKabiGuideOverlay(IslandDto island) {
    final message = IslandDto.kabiGuideTextForTier(_previewTier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Hình minh họa Rùa Kabi đội nón lá truyền thống
            SizedBox(
              width: 78,
              height: 86,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  const KabiMascotWidget(
                    mood: KabiMood.guiding,
                    width: 72,
                    height: 72,
                  ),
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      size: const Size(64, 28),
                      painter: _NonLaConicalHatPainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF1E0).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: const Color(0xFFDEC9A8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: const Color(0xFF2E2118),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isEditMode = true;
                            _selectedSlotId = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E4D3B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Bài trí vật phẩm →',
                            style: DauVietTypography.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Chỉ báo 3 chấm tròn ở đáy màn hình
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int t = 1; t <= 3; t++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _previewTier == t ? 9 : 7,
                height: _previewTier == t ? 9 : 7,
                decoration: BoxDecoration(
                  color: _previewTier == t
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Thẻ chào mừng lần đầu ngắn gọn, giải thích rõ mục đích Đảo Di Sản,
  /// sự khác biệt giữa EXP/Level (mở rộng đảo) và Điểm Sử Ký (mua vật phẩm).
  Widget _buildWelcomeOnboardingCard(IslandDto island) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DauVietColors.paperBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DauVietColors.imperialGold, width: 2),
        boxShadow: DauVietColors.pixelShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const RareFrameBadge(
                rarity: ItemRarity.rare,
                borderRadius: 20,
                padding: EdgeInsets.all(8),
                child: Icon(
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
            rarity: ItemRarity.uncommon,
            title: 'Trang trí Đảo cá nhân',
            body:
                'Chạm vào các ô đất trống (+) để đặt công trình văn hóa hoặc mô hình lịch sử từ Kho vật phẩm.',
          ),
          const SizedBox(height: 10),
          _buildGuideBullet(
            icon: Icons.school_rounded,
            color: DauVietColors.cinnabarRed,
            rarity: ItemRarity.rare,
            title: 'Học bài tích lũy EXP → Nâng Level mở đảo',
            body:
                'Hoàn thành bài học giúp tích lũy EXP và tăng Level tài khoản. Khi đủ Level, bạn có thể chủ động mở rộng lên Đảo vừa và Đảo lớn.',
          ),
          const SizedBox(height: 10),
          _buildGuideBullet(
            icon: Icons.stars_rounded,
            color: DauVietColors.imperialGold,
            rarity: ItemRarity.epic,
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
                child: DongSonButton(
                  label: 'KHÁM PHÁ',
                  height: 44,
                  icon: Icons.explore_rounded,
                  variant: DongSonButtonVariant.heritageGreen,
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
    required ItemRarity rarity,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DauVietColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RareFrameBadge(
            rarity: rarity,
            borderRadius: 10,
            showGlow: false,
            padding: const EdgeInsets.all(5),
            child: Icon(icon, color: color, size: 18),
          ),
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
        color: DauVietColors.paperBackground.withValues(alpha: 0.95),
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
        color: DauVietColors.paperBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.5),
        boxShadow: DauVietColors.heritageShadow,
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
        child: EmptyStateCard(
          mood: KabiMood.guiding,
          illustration: const KabiMascotWidget(
            mood: KabiMood.guiding,
            width: 84,
            height: 84,
          ),
          title: 'Đảo chưa được lập bản đồ',
          description:
              'Bố cục đảo "${island.layoutCode ?? 'hiện tại'}" '
              '(phiên bản ${island.layoutVersionNumber}) chưa có ô đất nào. '
              'Vui lòng báo quản trị viên xuất bản lại layout.',
          actionLabel: 'TẢI LẠI',
          onAction: () =>
              ref.read(islandControllerProvider.notifier).refresh(),
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
            DongSonButton(
              label: 'THỬ LẠI',
              variant: DongSonButtonVariant.secondaryParchment,
              height: 44,
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
        backgroundColor: DauVietColors.paperBackground.withValues(alpha: 0.0),
        builder: (ctx) => IslandInventorySheet(
          targetSlot: slot,
          onSelectItem: (itemId) => _placeItem(slot, itemId),
        ),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  /// Chạm ô đất trên đảo:
  /// - Ở Chế độ Bài trí: nếu đang chọn vật phẩm trong khay -> đặt ngay lên ô đất;
  ///   nếu đang chọn một vật phẩm trên đảo và chạm sang ô trống khác -> di chuyển vật phẩm;
  ///   ngược lại chọn ô để Xoay hoặc Xóa.
  /// - Ở Chế độ Tham quan: mở `IslandTileSheet` chi tiết ô đất.
  void _onSlotTap(IslandSlotDto? slot, IslandDto island) {
    if (slot == null) {
      setState(() {
        _selectedSlotId = null;
        _showSlotStepHint = false;
      });
      return;
    }
    if (_selectedTrayItemId != null && slot.unlocked) {
      if (slot.placement == null) {
        _placeItem(slot, _selectedTrayItemId!);
      } else {
        _replacePlacement(slot, _selectedTrayItemId!);
      }
      return;
    }
    if (_isEditMode && _selectedSlotId != null && _selectedSlotId != slot.slotId) {
      final prevSlot = island.slots.cast<IslandSlotDto?>().firstWhere(
        (s) => s?.slotId == _selectedSlotId,
        orElse: () => null,
      );
      if (prevSlot != null &&
          prevSlot.placement != null &&
          slot.unlocked &&
          slot.placement == null) {
        _movePlacement(prevSlot, slot);
        return;
      }
    }
    setState(() {
      _selectedSlotId = slot.slotId;
      _showSlotStepHint = false;
    });
  }

  Future<void> _replacePlacement(IslandSlotDto slot, String newItemId) async {
    if (_isMutating) return;
    await _removePlacement(slot);
    if (!mounted) return;
    await _placeItem(slot, newItemId);
  }

  Future<void> _movePlacement(
    IslandSlotDto fromSlot,
    IslandSlotDto toSlot,
  ) async {
    final movingItemId = fromSlot.placement?.itemId;
    if (movingItemId == null || _isMutating) return;
    await _removePlacement(fromSlot);
    if (!mounted) return;
    await _placeItem(toSlot, movingItemId);
    if (!mounted) return;
    setState(() {
      _selectedSlotId = toSlot.slotId;
    });
  }

  /// Trả bản IslandDto theo cấp đảo đang xem (`viewTier`):
  /// - Khi xem Đảo An Lạc (viewTier == 1), lọc gọn vùng đất để đảo vừa vặn, rõ nét trên mobile
  ///   (giữ kèm vành đai Cấp 2 liền kề để hiển thị trạng thái khóa trực quan).
  IslandDto _islandForTier(IslandDto island, int viewTier) {
    if (island.board == null) return island;
    final maxVisibleTier = viewTier == 1 && island.tier == 1 ? 2 : viewTier;
    final filteredSlots = island.slots
        .where((s) => s.unlockTier <= maxVisibleTier)
        .toList();
    final filteredTiles = island.board!.tiles
        .where(
          (t) =>
              t.unlockTier <= viewTier ||
              (viewTier == 1 &&
                  t.unlockTier == 2 &&
                  island.slots.any(
                    (s) =>
                        s.tileKey == t.key ||
                        (s.tileRow == t.row && s.tileCol == t.col),
                  )),
        )
        .toList();
    final filteredRegions = island.regions
        .where((r) => r.unlockTier <= maxVisibleTier)
        .toList();
    return island.copyWith(
      slots: filteredSlots,
      regions: filteredRegions,
      board: island.board!.copyWithTiles(filteredTiles),
    );
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
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(left: 20, right: 20, bottom: 220),
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
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(left: 20, right: 20, bottom: 220),
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
        backgroundColor: DauVietColors.paperBackground.withValues(alpha: 0.0),
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
        backgroundColor: DauVietColors.paperBackground,
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
          DongSonButton(
            label: 'KHÁM PHÁ ĐẢO',
            variant: DongSonButtonVariant.heritageGreen,
            height: 44,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}

/// Vẽ chiếc Nón Lá truyền thống Việt Nam đội trên đầu trợ lý Rùa Kabi.
class _NonLaConicalHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final hatPath = Path()
      ..moveTo(w * 0.04, h * 0.86)
      ..lineTo(w * 0.50, h * 0.08)
      ..lineTo(w * 0.96, h * 0.86)
      ..quadraticBezierTo(w * 0.50, h * 1.04, w * 0.04, h * 0.86)
      ..close();

    canvas.drawPath(hatPath, Paint()..color = const Color(0xFFEBD29B));
    canvas.drawPath(
      hatPath,
      Paint()
        ..color = const Color(0xFFB58E4C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Các vòng nan tre trên nón lá
    final ribPaint = Paint()
      ..color = const Color(0xFFC8A464)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.22, h * 0.36, w * 0.56, h * 0.22),
      0.1,
      2.9,
      false,
      ribPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.12, h * 0.56, w * 0.76, h * 0.28),
      0.1,
      2.9,
      false,
      ribPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

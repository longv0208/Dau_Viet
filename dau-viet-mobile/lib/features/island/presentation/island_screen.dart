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
import '../../rewards/data/reward_dtos.dart';
import '../../rewards/data/reward_providers.dart';
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
  String? _selectedTrayItemId;   // Item đang chọn để đặt lên đảo (Màn 2 Placement Preview)
  bool _previewFlipHorizontally = false;
  int _previewTier = 1;          // Tab cấp đảo đang xem (1: Đảo Nhỏ, 2: Đảo Vừa, 3: Đảo Lớn)
  bool _isEditMode = false;      // Màn 3 & Màn 5: hiển thị cụm 3 nút Lưu / Thu hồi / Xoay
  bool _isPanoramicMapOpen = false; // Màn 4: Bản đồ Toàn cảnh 3 Cấp Đảo xếp dọc
  final Set<String> _flippedSlotIds = <String>{};
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

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final island = ref.read(islandControllerProvider).asData?.value;
      if (island != null) {
        // Khởi tạo tab cấp đảo theo tier hiện tại của user — đảo lớn hơn hiển
        // thị đúng vùng đất thay vì luôn mở ở Đảo Nhỏ.
        setState(() {
          _previewTier = island.tier;
        });
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
    _selectedSlotId = null;
    _selectedTrayItemId = null;
    _previewFlipHorizontally = false;
    _isEditMode = false;
    _isPanoramicMapOpen = false;
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
        });
      } else if (island.canUpgrade && !island.isMaxTier && !upgradeHintSeen) {
        await prefs.setBool(upgradeHintKey, true);
      }
    } catch (_) {}
  }

  Future<void> _markOnboardingCompleted({required bool exploreSlot}) async {
    final userId = _currentAuthenticatedUserId();
    setState(() {
      _showWelcomeCard = false;
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
        // Khi island resolve lần đầu (hoặc tier đổi sau nâng cấp), đồng bộ
        // tab cấp đảo theo tier thực của user.
        final prevTier = previous?.asData?.value.tier;
        if (prevTier != island.tier && _previewTier != island.tier) {
          setState(() {
            _previewTier = island.tier;
          });
        }
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
              if (_isPanoramicMapOpen) {
                setState(() => _isPanoramicMapOpen = false);
                return;
              }
              if (_selectedTrayItemId != null) {
                setState(() {
                  _selectedTrayItemId = null;
                  _previewFlipHorizontally = false;
                });
                return;
              }
              if (_isEditMode) {
                setState(() {
                  _isEditMode = false;
                  _selectedSlotId = null;
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
                    '${IslandDto.tierHeritageName(_previewTier)} · ${island.legacyTierScaleLabel} (LV${island.currentLevel})',
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

          // Cụm bên phải: Huy hiệu Điểm Sử Ký (⭐ 250) + Nút trợ giúp (?) (Issue #50 AC-1)
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
          const SizedBox(width: 6),
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

    final catalogList =
        ref.watch(inventoryCatalogProvider).asData?.value ??
        const <CatalogItemDto>[];
    final shopList =
        ref.watch(islandShopItemsProvider).asData?.value ??
        const <ShopItemDto>[];
    final allPlaceable = IslandInventoryTray.mergePlaceableItems(
      catalogList,
      shopList,
      island,
    );

    final previewCatalogItem = _selectedTrayItemId == null
        ? null
        : allPlaceable.cast<CatalogItemDto?>().firstWhere(
            (it) => it?.itemId == _selectedTrayItemId,
            orElse: () => null,
          );
    final IslandPlacementDto? previewPlacement = previewCatalogItem == null
        ? null
        : IslandPlacementDto(
            itemId: previewCatalogItem.itemId,
            code: previewCatalogItem.code,
            name: previewCatalogItem.name,
            renderKey: previewCatalogItem.renderKey,
            assetId: previewCatalogItem.assetId,
          );

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
    final bool isPlacementPreviewMode = previewPlacement != null;
    final bool showManageToolbar =
        (_isEditMode || (_previewTier >= 2 && _previewTier <= island.tier)) &&
        !isPlacementPreviewMode &&
        !_isPanoramicMapOpen;

    return Stack(
      children: [
        // 1. Canvas 2.5D Isometric Scene (hoặc Màn 4 Bản đồ Toàn cảnh 3 Đảo)
        Positioned.fill(
          child: _isPanoramicMapOpen
              ? _buildPanoramicThreeIslandsMap(island)
              : isAnimatingExpansion
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
                      isEditMode: _isEditMode || isPlacementPreviewMode,
                      flippedSlotIds: _flippedSlotIds,
                      previewTier: _previewTier,
                      onSelectTier: (tier) => _handleSelectTier(tier, island),
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
                  isEditMode: _isEditMode || isPlacementPreviewMode,
                  flippedSlotIds: _flippedSlotIds,
                  previewTier: _previewTier,
                  previewPlacement: previewPlacement,
                  previewFlipHorizontally: _previewFlipHorizontally,
                  onCancelPreviewPlacement: () {
                    setState(() {
                      _selectedTrayItemId = null;
                      _previewFlipHorizontally = false;
                    });
                  },
                  onRotatePreviewPlacement: () {
                    setState(() {
                      _previewFlipHorizontally = !_previewFlipHorizontally;
                    });
                  },
                  onConfirmPreviewPlacement: () =>
                      _confirmPreviewPlacement(island),
                  onSelectTier: (tier) => _handleSelectTier(tier, island),
                  onSelectSlot: (slot) => _onSlotTap(slot, island),
                ),
        ),

        // 2. Thanh Segmented Tab 3 Cấp Đảo (`Đảo Nhỏ` · `Đảo Vừa` · `Đảo Lớn`) — KHÔNG có IslandSummaryCard (Issue #50 AC-1)
        if (!isAnimatingExpansion && !_showWelcomeCard)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: IslandTierTabs(
              island: island,
              previewTier: _previewTier,
              onSelectTier: (tier) => _handleSelectTier(tier, island),
            ),
          ),

        // 3. Màn 1: Khung thoại Rùa đội nón lá nằm ở phía trên bên trái (ngay dưới thanh tab) (Issue #50 AC-1)
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            !_isPanoramicMapOpen &&
            !isPlacementPreviewMode &&
            !showManageToolbar)
          Positioned(
            top: 56,
            left: 12,
            right: 12,
            child: _buildTopTurtleGuideBubble(island),
          ),

        // 4. Màn 1: Nút nổi `Bản đồ` ở góc dưới bên phải cạnh đảo để mở Màn 4 Bản đồ Toàn cảnh 3 Đảo (Issue #50 AC-1 & AC-4)
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            !_isPanoramicMapOpen &&
            !isPlacementPreviewMode &&
            selectedSlot == null)
          Positioned(
            right: 14,
            bottom: 162,
            child: _buildMapFloatingButton(),
          ),

        // 5. Màn 3 & Màn 5: Cụm 3 nút công cụ nổi dọc bên phải (`Lưu` / `Thu hồi` / `Xoay`) (Issue #50 AC-3)
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            showManageToolbar)
          Positioned(
            top: 62,
            right: 12,
            child: _buildManageFloatingTools(island, selectedSlot),
          ),

        // 6. Nút "BỎ QUA" khi chuỗi animation mở rộng đảo đang chạy
        if (isAnimatingExpansion)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
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
                        Flexible(
                          child: Text(
                            'Đang khai mở ${island.tierScaleLabel}...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DauVietTypography.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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

        // 7. Bottom Sheet chi tiết tile/slot khi chạm vào ô ở Chế độ Tham quan (tương thích kiểm thử slot)
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            !_isPanoramicMapOpen &&
            !_isEditMode &&
            !isPlacementPreviewMode &&
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
              }),
              onPlaceItem: () => _openInventorySheet(selectedSlot),
              onRemoveItem: () => _removePlacement(selectedSlot),
              onViewRequirements: () => _openUpgradePanel(island),
            ),
          ),

        // 8. Khay `🧰 Kho vật phẩm` rút gọn (Màn 1, 3, 5) hoặc Thẻ Đặt Vật Phẩm (Màn 2) ở đáy màn hình
        if (!isAnimatingExpansion &&
            !_showWelcomeCard &&
            !_isPanoramicMapOpen &&
            (isPlacementPreviewMode || _isEditMode || selectedSlot == null))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IslandInventoryTray(
              island: island,
              selectedItemId: _selectedTrayItemId,
              onSelectItem: (itemId) =>
                  _startPlacementPreview(itemId, visibleIsland),
              onOpenExpandedInventory: () =>
                  _openExpandedInventoryModal(visibleIsland),
              onConfirmPlacement: () => _confirmPreviewPlacement(island),
              onInspectItem: (item) =>
                  _openItemDetailModal(item, visibleIsland, shopList),
            ),
          ),

        // 9. Thẻ Chào mừng / Hướng dẫn lần đầu
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

  /// Chuyển tab cấp đảo (`Đảo Nhỏ` / `Đảo Vừa` / `Đảo Lớn`).
  /// Nếu chạm vào tab cấp đảo đang khóa -> mở Modal 3 `NÂNG CẤP ĐẢO` (hoặc cho phép xem trước).
  void _handleSelectTier(int tier, [IslandDto? island]) {
    if (island != null && tier > island.tier) {
      setState(() {
        _previewTier = tier;
        _isPanoramicMapOpen = false;
        _selectedSlotId = null;
        _selectedTrayItemId = null;
        _resetCameraVersion++;
      });
      _openUpgradePanel(island, targetTierOverride: tier);
      return;
    }
    setState(() {
      _previewTier = tier;
      _isPanoramicMapOpen = false;
      _selectedSlotId = null;
      _selectedTrayItemId = null;
      _resetCameraVersion++;
    });
  }

  /// Bắt đầu chế độ Đặt Vật Phẩm lên Đảo (Màn 2 Placement Preview).
  void _startPlacementPreview(String? itemId, IslandDto visibleIsland) {
    if (itemId == null) {
      setState(() {
        _selectedTrayItemId = null;
        _previewFlipHorizontally = false;
      });
      return;
    }
    String? targetSlotId = _selectedSlotId;
    final currentSlot = targetSlotId == null
        ? null
        : visibleIsland.slots.cast<IslandSlotDto?>().firstWhere(
            (s) => s?.slotId == targetSlotId,
            orElse: () => null,
          );
    if (currentSlot == null || !currentSlot.unlocked) {
      final emptySlot = visibleIsland.slots.cast<IslandSlotDto?>().firstWhere(
        (s) => s != null && s.unlocked && s.isEmpty,
        orElse: () => visibleIsland.slots.cast<IslandSlotDto?>().firstWhere(
          (s) => s != null && s.unlocked,
          orElse: () => null,
        ),
      );
      targetSlotId = emptySlot?.slotId;
    }
    setState(() {
      _selectedTrayItemId = itemId;
      _selectedSlotId = targetSlotId;
      _previewFlipHorizontally = false;
    });
  }

  /// Xác nhận đặt vật phẩm đang preview ở Màn 2 (bấm nút `✓` hoặc nút `Đặt`).
  /// Đối với công trình `2x2`, tự động kiểm tra 3 ô lân cận trong vùng đế `2x2` không bị vướng.
  Future<void> _confirmPreviewPlacement(IslandDto island) async {
    final itemId = _selectedTrayItemId;
    if (itemId == null) return;
    final slot = island.slots.cast<IslandSlotDto?>().firstWhere(
      (s) => s?.slotId == _selectedSlotId && s!.unlocked,
      orElse: () => island.slots.cast<IslandSlotDto?>().firstWhere(
        (s) => s != null && s.unlocked && s.isEmpty,
        orElse: () => island.slots.cast<IslandSlotDto?>().firstWhere(
          (s) => s != null && s.unlocked,
          orElse: () => null,
        ),
      ),
    );
    if (slot == null) return;

    // Giải phóng các ô con trong vùng đế 2x2 nếu có vật phẩm cũ đang chiếm chỗ
    final catalogList =
        ref.read(inventoryCatalogProvider).asData?.value ??
        const <CatalogItemDto>[];
    final shopList =
        ref.read(islandShopItemsProvider).asData?.value ??
        const <ShopItemDto>[];
    final allPlaceable = IslandInventoryTray.mergePlaceableItems(
      catalogList,
      shopList,
      island,
    );
    final matchedItem = allPlaceable.cast<CatalogItemDto?>().firstWhere(
      (it) => it?.itemId == itemId,
      orElse: () => null,
    );
    final (footW, footH) = resolveIslandItemFootprint(
      matchedItem?.code,
      matchedItem?.renderKey,
    );
    final anchorTile = island.board?.tileForSlotDto(slot);
    if ((footW > 1 || footH > 1) && anchorTile != null) {
      for (int dr = 0; dr < footH; dr++) {
        for (int dc = 0; dc < footW; dc++) {
          if (dr == 0 && dc == 0) continue;
          final subTile = island.board?.tileAt(
            anchorTile.row + dr,
            anchorTile.col + dc,
          );
          if (subTile?.slotId != null) {
            final subSlot = island.slots.cast<IslandSlotDto?>().firstWhere(
              (s) => s?.slotId == subTile!.slotId,
              orElse: () => null,
            );
            if (subSlot != null && subSlot.placement != null) {
              await _removePlacement(subSlot);
            }
          }
        }
      }
    }

    final shouldFlip = _previewFlipHorizontally;
    setState(() {
      _selectedTrayItemId = null;
      _previewFlipHorizontally = false;
      _isEditMode = true;
      _selectedSlotId = slot.slotId;
      if (shouldFlip) {
        _flippedSlotIds.add(slot.slotId);
      } else {
        _flippedSlotIds.remove(slot.slotId);
      }
    });
    if (slot.placement == null) {
      await _placeItem(slot, itemId);
    } else {
      await _replacePlacement(slot, itemId);
    }
  }

  /// Màn 1 (Issue #50 AC-1): Khung thoại Rùa đội nón lá nằm ngay dưới thanh tab ở phía trên bên trái.
  Widget _buildTopTurtleGuideBubble(IslandDto island) {
    final tierName = IslandDto.tierHeritageName(_previewTier);
    final fullGuideText = IslandDto.kabiGuideTextForTier(_previewTier);

    return Semantics(
      label: fullGuideText,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Chân dung Rùa đội nón lá truyền thống
          Container(
            width: 68,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              'assets/island/scenery/turtle_hat_avatar.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const KabiMascotWidget(
                mood: KabiMood.guiding,
                width: 64,
                height: 64,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isEditMode = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF3E4).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFDEC8A4),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text.rich(
                  TextSpan(
                    style: DauVietTypography.bodySmall.copyWith(
                      color: const Color(0xFF2E1E12),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Đây là '),
                      TextSpan(
                        text: tierName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(
                        text:
                            ' của bạn!\nHãy đặt các vật phẩm để xây dựng hòn đảo theo cách riêng nhé!',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Màn 1 (Issue #50 AC-1 & AC-4): Nút nổi `Bản đồ` ở góc dưới bên phải cạnh đảo.
  Widget _buildMapFloatingButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _isPanoramicMapOpen = true;
          _selectedSlotId = null;
          _selectedTrayItemId = null;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF3E4).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDEC8A4), width: 1.4),
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
            const Icon(
              Icons.map_rounded,
              color: Color(0xFF1A5642),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              'Bản đồ',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3A2618),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Màn 3 & Màn 5 (Issue #50 AC-3): Cụm 3 nút công cụ nổi dọc bên phải (`Lưu` / `Thu hồi` / `Xoay`).
  Widget _buildManageFloatingTools(
    IslandDto island,
    IslandSlotDto? selectedSlot,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatingToolButton(
          icon: Icons.save_outlined,
          label: 'Lưu',
          onTap: () {
            setState(() {
              _isEditMode = false;
              _selectedSlotId = null;
              _selectedTrayItemId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã lưu bố cục Đảo Di Sản!'),
                backgroundColor: Color(0xFF1A5642),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildFloatingToolButton(
          icon: Icons.unarchive_outlined,
          label: 'Thu hồi',
          onTap: () {
            final target = (selectedSlot != null && selectedSlot.placement != null)
                ? selectedSlot
                : island.slots.cast<IslandSlotDto?>().firstWhere(
                    (s) =>
                        s != null &&
                        s.unlocked &&
                        s.unlockTier <= _previewTier &&
                        s.placement != null,
                    orElse: () => null,
                  );
            if (target != null) {
              _removePlacement(target);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Hãy chạm chọn một vật phẩm đang đặt trên đảo để thu hồi về kho.',
                  ),
                  backgroundColor: Color(0xFF5A4635),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
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
          color: const Color(0xFFFBF3E4).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDEC8A4), width: 1.4),
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
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3A2618),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Màn 4 (Issue #50 AC-4): Bản đồ Toàn cảnh 3 Cấp Đảo xếp dọc trên biển mây
  /// (`✅ Đảo Nhỏ — Đang sử dụng`, `🔒 Đảo Vừa — Hoàn thành 15 bài học để mở khóa`,
  /// `🔒 Đảo Lớn — Hoàn thành 30 bài học để mở khóa`).
  Widget _buildPanoramicThreeIslandsMap(IslandDto island) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFA8DFEA),
            Color(0xFF66B9CE),
            Color(0xFF398FA9),
            Color(0xFF236E86),
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Những tầng mây trắng bồng bềnh nối giữa 3 đảo
          Positioned(
            top: 90,
            left: -20,
            child: _buildSoftCloudCluster(width: 180, height: 64),
          ),
          Positioned(
            top: 230,
            right: -30,
            child: _buildSoftCloudCluster(width: 200, height: 70),
          ),
          Positioned(
            bottom: 40,
            left: 10,
            right: 10,
            child: _buildSoftCloudCluster(width: 340, height: 80),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 58, 16, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPanoramicIslandNode(
                  island: island,
                  tier: 1,
                  title: 'Đảo Nhỏ',
                  unlockedSubtitle: 'Đang sử dụng',
                  lockedSubtitle: 'Đang sử dụng',
                  thumbWidth: 146,
                  thumbHeight: 104,
                ),
                _buildPanoramicIslandNode(
                  island: island,
                  tier: 2,
                  title: 'Đảo Vừa',
                  unlockedSubtitle:
                      island.tier == 2 ? 'Đang sử dụng' : 'Đã mở khóa',
                  lockedSubtitle: 'Hoàn thành 15 bài học\nđể mở khóa',
                  thumbWidth: 162,
                  thumbHeight: 116,
                ),
                _buildPanoramicIslandNode(
                  island: island,
                  tier: 3,
                  title: 'Đảo Lớn',
                  unlockedSubtitle:
                      island.tier == 3 ? 'Đang sử dụng' : 'Đã mở khóa',
                  lockedSubtitle: 'Hoàn thành 30 bài học\nđể mở khóa',
                  thumbWidth: 174,
                  thumbHeight: 126,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftCloudCluster({required double width, required double height}) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF0).withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(height),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.34),
              blurRadius: 24,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanoramicIslandNode({
    required IslandDto island,
    required int tier,
    required String title,
    required String unlockedSubtitle,
    required String lockedSubtitle,
    required double thumbWidth,
    required double thumbHeight,
  }) {
    final isUnlocked = tier <= island.tier;
    final subtitle = isUnlocked ? unlockedSubtitle : lockedSubtitle;

    return GestureDetector(
      onTap: () {
        if (isUnlocked) {
          setState(() {
            _previewTier = tier;
            _isPanoramicMapOpen = false;
            _resetCameraVersion++;
          });
        } else {
          _openUpgradePanel(island, targetTierOverride: tier);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: IslandTierThumbnail(
                tier: tier,
                isUnlocked: isUnlocked,
                width: thumbWidth,
                height: thumbHeight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF3E4).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDEC8A4), width: 1.4),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUnlocked
                            ? Icons.check_circle_rounded
                            : Icons.lock_rounded,
                        size: 16,
                        color: isUnlocked
                            ? const Color(0xFF1A5642)
                            : const Color(0xFF5A4635),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          title,
                          style: DauVietTypography.titleSmall.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2E1E12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5D4A3A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  /// Mở Modal 1 `KHO VẬT PHẨM` khi chạm vào một ô cụ thể.
  Future<void> _openInventorySheet(IslandSlotDto slot) async {
    if (_isSheetOpen || _isMutating) return;
    _isSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: DauVietColors.paperBackground.withValues(alpha: 0.0),
        builder: (ctx) => IslandInventorySheet(
          targetSlot: slot,
          onSelectItem: (itemId) => slot.placement == null
              ? _placeItem(slot, itemId)
              : _replacePlacement(slot, itemId),
        ),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  /// Mở Modal 1 `KHO VẬT PHẨM` từ khay `🧰 Kho vật phẩm` ở đáy màn hình.
  Future<void> _openExpandedInventoryModal(IslandDto visibleIsland) async {
    if (_isSheetOpen || _isMutating) return;
    _isSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => IslandInventorySheet(
          onSelectItem: (itemId) =>
              _startPlacementPreview(itemId, visibleIsland),
        ),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  /// Mở Modal 2 `CHI TIẾT VẬT PHẨM` trực tiếp khi người dùng chạm vào ảnh vật phẩm.
  Future<void> _openItemDetailModal(
    CatalogItemDto item,
    IslandDto visibleIsland,
    List<ShopItemDto> shopItems,
  ) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;
    try {
      final matchedShop = shopItems.cast<ShopItemDto?>().firstWhere(
        (s) =>
            s?.itemId == item.itemId ||
            s?.code.toLowerCase() == item.code.toLowerCase(),
        orElse: () => null,
      );
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => IslandItemDetailSheet(
          item: item,
          pricePoints: matchedShop?.pricePoints,
          onPlaceOnIsland: () => Navigator.of(ctx).pop(true),
        ),
      );
      if (confirmed == true && mounted) {
        _startPlacementPreview(item.itemId, visibleIsland);
      }
    } finally {
      _isSheetOpen = false;
    }
  }

  /// Chạm ô đất trên đảo:
  /// - Ở Màn 2 (Placement Preview): di chuyển vị trí preview tới ô đất vừa chạm.
  /// - Ở Chế độ Quản lý (`_isEditMode`): chọn ô để Xoay/Thu hồi hoặc di chuyển vật phẩm sang ô trống khác.
  /// - Ở Chế độ Tham quan: mở `IslandTileSheet` chi tiết ô đất.
  void _onSlotTap(IslandSlotDto? slot, IslandDto island) {
    if (_selectedTrayItemId != null) {
      if (slot != null && slot.unlocked) {
        setState(() {
          _selectedSlotId = slot.slotId;
        });
      }
      return;
    }
    if (slot == null) {
      setState(() {
        _selectedSlotId = null;
      });
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
    final bool isLegacyFixtureWithFewSlots = island.slots.length <= 20;
    final maxVisibleTier =
        (viewTier == 1 && island.tier == 1 && isLegacyFixtureWithFewSlots)
            ? 2
            : viewTier;
    final filteredSlots = island.slots
        .where((s) => s.unlockTier <= maxVisibleTier)
        .toList();
    final filteredTiles = island.board!.tiles
        .where(
          (t) =>
              t.unlockTier <= viewTier ||
              (viewTier == 1 &&
                  isLegacyFixtureWithFewSlots &&
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

  Future<void> _openUpgradePanel(
    IslandDto island, {
    int? targetTierOverride,
  }) async {
    if (_isSheetOpen || _isMutating) return;
    _isSheetOpen = true;
    final targetTier =
        targetTierOverride ??
        (island.isMaxTier ? island.tier : (island.tier + 1));
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: DauVietColors.paperBackground.withValues(alpha: 0.0),
        builder: (ctx) => IslandUpgradePanel(
          island: island,
          targetTierOverride: targetTierOverride,
          isUpgrading: _isMutating,
          onUpgrade: () {
            Navigator.of(ctx).pop();
            _showIslandTransitionConfirmationDialog(
              island: island,
              targetTier: targetTier,
            );
          },
        ),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  /// Mở Modal 4 `Chuyển đến Đảo Vừa?` (`IslandTransitionDialog`) sau khi bấm `Mở khóa Đảo Vừa` ở Modal 3:
  /// - `Để sau`: vẫn thực hiện nâng cấp mở khóa đảo mới nhưng giữ góc nhìn hiện tại ở đảo cũ.
  /// - `Chuyển ngay`: thực hiện nâng cấp mở khóa và chuyển ngay sang đảo mới.
  Future<void> _showIslandTransitionConfirmationDialog({
    required IslandDto island,
    required int targetTier,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => IslandTransitionDialog(
        targetTier: targetTier,
        onLater: () {
          Navigator.of(ctx).pop();
          _executeUpgrade(previousTier: island.tier);
        },
        onSwitchNow: () {
          Navigator.of(ctx).pop();
          _executeUpgrade(previousTier: island.tier, switchToTier: targetTier);
        },
      ),
    );
  }

  /// Phase 1 -> 5: Thực hiện nâng cấp đảo và chạy chuỗi animation mở rộng đất (Part B).
  Future<void> _executeUpgrade({
    required int previousTier,
    int? switchToTier,
  }) async {
    if (_isMutating) return;
    setState(() {
      _isMutating = true;
      _selectedSlotId = null;
    });

    try {
      final updated = await ref.read(islandControllerProvider.notifier).upgrade();
      if (!mounted) return;

      setState(() {
        _previewTier = switchToTier ?? updated.tier;
        _isPanoramicMapOpen = false;
        _isEditMode = true;
      });

      // Chỉ kích hoạt chuỗi mở rộng khi backend xác nhận thành công và Tier mới > Tier cũ (B2)
      if (updated.tier <= previousTier) {
        return;
      }

      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion || switchToTier != null) {
        setState(() {
          _confettiTriggerCount++;
          _resetCameraVersion++;
        });
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

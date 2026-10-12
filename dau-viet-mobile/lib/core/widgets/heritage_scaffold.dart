import 'package:flutter/material.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'energy_pill.dart';
import 'sound_toggle_button.dart';

/// Khung Scaffold chuẩn Di sản Văn hiến cho Dấu Việt
class HeritageScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showEnergyPill;
  final int energy;
  final int historyPoints;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const HeritageScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.showBack = true,
    this.onBack,
    this.actions,
    this.showEnergyPill = true,
    this.energy = 100,
    this.historyPoints = 150,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: (title != null || titleWidget != null || showBack || showEnergyPill)
          ? AppBar(
              backgroundColor: DauVietColors.parchmentSurface,
              elevation: 0,
              centerTitle: false,
              leading: showBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: DauVietColors.inkText,
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  : null,
              title: titleWidget ??
                  (title != null
                      ? Text(
                          title!,
                          style: DauVietTypography.headlineMedium.copyWith(fontSize: 18),
                        )
                      : null),
              actions: [
                if (showEnergyPill)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: EnergyPill(
                      energy: energy,
                      historyPoints: historyPoints,
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SoundToggleButton(),
                ),
                ...?actions,
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
                  height: 1.0,
                ),
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              DauVietColors.parchmentSurface,
              Color(0xFFFAF2E4),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: body,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

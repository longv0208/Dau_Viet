import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/core/audio/dau_viet_audio_service.dart';
import 'package:dau_viet_mobile/core/widgets/sound_toggle_button.dart';
import 'package:dau_viet_mobile/core/widgets/story_audio_player_widget.dart';
import 'package:dau_viet_mobile/core/widgets/tactile_3d_button.dart';
import 'package:dau_viet_mobile/core/widgets/tactile_3d_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DauVietAudioService Unit Tests', () {
    late DauVietAudioService service;

    setUp(() {
      service = DauVietAudioService.instance;
      service.setSoundEnabled(true);
      service.setNarrationEnabled(true);
      service.setSfxVolume(1.0);
      service.setNarrationVolume(1.0);
    });

    test('Initial audio settings state', () {
      expect(service.isSoundEnabled, isTrue);
      expect(service.isNarrationEnabled, isTrue);
      expect(service.sfxVolume, equals(1.0));
      expect(service.narrationVolume, equals(1.0));
      expect(service.isNarrationPlaying, isFalse);
    });

    test('Toggle and set sound enabled', () {
      service.toggleSound();
      expect(service.isSoundEnabled, isFalse);

      service.setSoundEnabled(true);
      expect(service.isSoundEnabled, isTrue);
    });

    test('Toggle and set narration enabled', () {
      service.toggleNarration();
      expect(service.isNarrationEnabled, isFalse);

      service.setNarrationEnabled(true);
      expect(service.isNarrationEnabled, isTrue);
    });

    test('Volume clamping', () {
      service.setSfxVolume(1.5);
      expect(service.sfxVolume, equals(1.0));

      service.setSfxVolume(-0.5);
      expect(service.sfxVolume, equals(0.0));

      service.setNarrationVolume(0.75);
      expect(service.narrationVolume, equals(0.75));
    });

    test('SFX playback calls execute safely without throwing', () async {
      await expectLater(service.playTap(), completes);
      await expectLater(service.playCorrect(), completes);
      await expectLater(service.playWrong(), completes);
      await expectLater(service.playStreakUp(combo: 3), completes);
      await expectLater(service.playChestOpen(), completes);
    });

    test('Narration controls state transitions in test environment', () async {
      expect(service.isNarrationPlaying, isFalse);

      await service.playNarration();
      expect(service.isNarrationPlaying, isTrue);

      await service.pauseNarration();
      expect(service.isNarrationPlaying, isFalse);

      await service.seekNarration(const Duration(seconds: 4));
      expect(service.narrationPosition, equals(const Duration(seconds: 4)));

      await service.stopNarration();
      expect(service.isNarrationPlaying, isFalse);
      expect(service.narrationPosition, equals(Duration.zero));
    });
  });

  group('SoundToggleButton Widget Tests', () {
    testWidgets('Renders toggle button and flips icon state on tap', (tester) async {
      final service = DauVietAudioService.instance;
      service.setSoundEnabled(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SoundToggleButton(),
          ),
        ),
      );

      // Ban đầu đang bật âm
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);

      // Bấm tắt âm
      await tester.tap(find.byType(SoundToggleButton));
      await tester.pump();

      expect(service.isSoundEnabled, isFalse);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

      // Bấm bật lại âm
      await tester.tap(find.byType(SoundToggleButton));
      await tester.pump();

      expect(service.isSoundEnabled, isTrue);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });
  });

  group('StoryAudioPlayerWidget Widget Tests', () {
    testWidgets('Renders full mode with title and play button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StoryAudioPlayerWidget(
              title: 'Bài đọc: Bối cảnh Bạch Đằng',
            ),
          ),
        ),
      );

      expect(find.text('Bài đọc: Bối cảnh Bạch Đằng'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders compact mode with audio waveform bars', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StoryAudioPlayerWidget(
              title: 'Bài đọc ngắn',
              compact: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('Play button triggers narration without exception', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StoryAudioPlayerWidget(
              title: 'Bài đọc: Kiểm thử âm thanh',
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(DauVietAudioService.instance.isNarrationPlaying, isTrue);

      // Stop narration so animation controller stops cleanly
      await DauVietAudioService.instance.stopNarration();
      await tester.pump();
    });
  });

  group('Tactile 3D Micro-interactions Audio Trigger Tests', () {
    testWidgets('Tactile3DButton triggers tap SFX on press', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Tactile3DButton(
              label: 'Thử Âm Thanh',
              onPressed: () => pressed = true,
              enableSound: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Thử Âm Thanh'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('Tactile3DCard triggers tap SFX on press', (tester) async {
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Tactile3DCard(
              onTap: () => cardTapped = true,
              child: const Text('Thẻ Bào Trúc'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Thẻ Bào Trúc'));
      await tester.pump();

      expect(cardTapped, isTrue);
    });
  });
}

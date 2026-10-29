import 'package:dau_viet_mobile/features/learning_path/data/learning_path_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningPath Enums & Contract A2 Parsers', () {
    test(
      'PathNodeType.parse handles ERA, PERIOD, PHASE and defaults to PERIOD',
      () {
        expect(PathNodeType.parse('ERA'), PathNodeType.era);
        expect(PathNodeType.parse('era'), PathNodeType.era);
        expect(PathNodeType.parse('PERIOD'), PathNodeType.period);
        expect(PathNodeType.parse('PHASE'), PathNodeType.phase);
        expect(PathNodeType.parse(null), PathNodeType.period);
        expect(PathNodeType.parse(''), PathNodeType.period);
        expect(PathNodeType.parse('UNKNOWN'), PathNodeType.period);

        expect(PathNodeType.era.isEra, isTrue);
        expect(PathNodeType.period.isPeriod, isTrue);
        expect(PathNodeType.phase.isPhase, isTrue);
        expect(PathNodeType.era.wireValue, 'ERA');
        expect(PathNodeType.period.wireValue, 'PERIOD');
        expect(PathNodeType.phase.wireValue, 'PHASE');
        expect(PathNodeType.era.labelVi, isNotEmpty);
        expect(PathNodeType.period.labelVi, isNotEmpty);
        expect(PathNodeType.phase.labelVi, isNotEmpty);
      },
    );

    test(
      'LearnerPathStatus.parse covers all 6 states, semantics, and Vietnamese labels',
      () {
        expect(LearnerPathStatus.parse('LOCKED'), LearnerPathStatus.locked);
        expect(
          LearnerPathStatus.parse('AVAILABLE'),
          LearnerPathStatus.available,
        );
        expect(
          LearnerPathStatus.parse('PUBLISHED'),
          LearnerPathStatus.available,
        );
        expect(
          LearnerPathStatus.parse('IN_PROGRESS'),
          LearnerPathStatus.inProgress,
        );
        expect(
          LearnerPathStatus.parse('COMPLETED'),
          LearnerPathStatus.completed,
        );
        expect(LearnerPathStatus.parse('MASTERED'), LearnerPathStatus.mastered);
        expect(
          LearnerPathStatus.parse('NOT_READY'),
          LearnerPathStatus.notReady,
        );
        expect(LearnerPathStatus.parse(null), LearnerPathStatus.locked);
        expect(LearnerPathStatus.tryParse(null), isNull);
        expect(LearnerPathStatus.tryParse('UNKNOWN'), isNull);

        expect(LearnerPathStatus.available.canStart, isTrue);
        expect(LearnerPathStatus.inProgress.canStart, isTrue);
        expect(LearnerPathStatus.completed.canStart, isTrue);
        expect(LearnerPathStatus.mastered.canStart, isTrue);
        expect(LearnerPathStatus.locked.canStart, isFalse);
        expect(LearnerPathStatus.notReady.canStart, isFalse);

        expect(LearnerPathStatus.completed.isDone, isTrue);
        expect(LearnerPathStatus.mastered.isDone, isTrue);
        expect(LearnerPathStatus.inProgress.isDone, isFalse);

        for (final status in LearnerPathStatus.values) {
          expect(status.labelVi, isNotEmpty);
          expect(LearnerPathStatus.parse(status.wireValue), status);
        }
      },
    );

    test(
      'PathContentStatus, ParticipationType, and EventDatePrecision parse accurately',
      () {
        expect(PathContentStatus.parse('PLAYABLE'), PathContentStatus.playable);
        expect(
          PathContentStatus.parse('NO_PUBLISHED_LESSON'),
          PathContentStatus.noPublishedLesson,
        );
        expect(
          PathContentStatus.parse('NO_COMPLETION_POLICY'),
          PathContentStatus.noCompletionPolicy,
        );
        expect(
          PathContentStatus.parse('CONTENT_REVIEW_REQUIRED'),
          PathContentStatus.contentReviewRequired,
        );
        expect(
          PathContentStatus.parse(null),
          PathContentStatus.noPublishedLesson,
        );

        expect(ParticipationType.parse('REQUIRED'), ParticipationType.required);
        expect(
          ParticipationType.parse('EXPLORATION_ONLY'),
          ParticipationType.explorationOnly,
        );
        expect(ParticipationType.parse(null), ParticipationType.required);

        expect(EventDatePrecision.parse('EXACT'), EventDatePrecision.exact);
        expect(EventDatePrecision.parse('CIRCA'), EventDatePrecision.circa);
        expect(EventDatePrecision.parse('CENTURY'), EventDatePrecision.century);
        expect(EventDatePrecision.parse('PERIOD'), EventDatePrecision.period);
        expect(EventDatePrecision.parse(null), EventDatePrecision.exact);
      },
    );
  });

  group('LearningPathDto — Contract A2 (GET /api/v1/me/learning-path)', () {
    final Map<String, dynamic> learnerResponseJson = {
      'pathCode': 'HISTORY_MAIN',
      'pathVersion': 2,
      'enrolled': true,
      'summary': {
        'completedEvents': 2,
        'totalRequiredEvents': 5,
        'completedLessons': 3,
        'totalRequiredLessons': 8,
      },
      'current': {
        'chapterId': 'period-ly',
        'eventNodeId': 'node-ly-thai-to',
        'lessonId': 'les-thang-long-1',
      },
      'lastPeriodCode': 'LY_DYNASTY',
      'periodProgress': [
        {
          'chapterId': 'period-bach-dang',
          'code': 'EARLY_INDEPENDENCE',
          'title': 'Buổi đầu độc lập tự chủ',
          'completedEvents': 1,
          'requiredEvents': 1,
          'completedLessons': 2,
          'requiredLessons': 2,
          'percent': 100,
        },
        {
          'chapterId': 'period-ly',
          'code': 'LY_DYNASTY',
          'title': 'Thời nhà Lý',
          'completedEvents': 1,
          'requiredEvents': 2,
          'completedLessons': 1,
          'requiredLessons': 3,
          'percent': 50,
        },
      ],
      'currentByPeriod': {
        'EARLY_INDEPENDENCE': null,
        'LY_DYNASTY': {
          'chapterId': 'period-ly',
          'eventNodeId': 'node-ly-thai-to',
          'lessonId': 'les-thang-long-1',
        },
      },
      'chapters': [
        {
          'chapterId': 'era-feudal',
          'parentId': null,
          'nodeType': 'ERA',
          'code': 'ERA_FEUDAL',
          'title': 'Thời kỳ Phong kiến Độc lập',
          'sortOrder': 1,
          'events': [],
        },
        {
          'chapterId': 'period-bach-dang',
          'parentId': 'era-feudal',
          'nodeType': 'PERIOD',
          'code': 'EARLY_INDEPENDENCE',
          'title': 'Buổi đầu độc lập tự chủ',
          'sortOrder': 1,
          'events': [
            {
              'eventNodeId': 'node-bach-dang',
              'eventId': 'evt-bach-dang-uuid',
              'title': 'Đại Chiến Bạch Đằng 938',
              'yearLabel': 'Năm 938',
              'endYear': 938,
              'datePrecision': 'EXACT',
              'sortOrder': 1,
              'participationType': 'REQUIRED',
              'status': 'MASTERED',
              'contentStatus': 'PLAYABLE',
              'lessons': [
                {
                  'lessonId': 'les-bd-1',
                  'title': 'Cọc ngầm Bạch Đằng',
                  'sortOrder': 1,
                  'status': 'COMPLETED',
                },
              ],
            },
          ],
        },
        {
          'chapterId': 'period-ly',
          'parentId': 'era-feudal',
          'nodeType': 'PERIOD',
          'code': 'LY_DYNASTY',
          'title': 'Thời nhà Lý',
          'sortOrder': 2,
          'events': [
            {
              'eventNodeId': 'node-ly-thai-to',
              'eventId': 'evt-ly-thai-to-uuid',
              'title': 'Lý Thái Tổ Dời Đô',
              'yearLabel': 'Năm 1010',
              'endYear': 1010,
              'datePrecision': 'EXACT',
              'sortOrder': 1,
              'participationType': 'REQUIRED',
              'status': 'AVAILABLE',
              'contentStatus': 'PLAYABLE',
              'lessons': [
                {
                  'lessonId': 'les-thang-long-1',
                  'title': 'Chiếu dời đô',
                  'sortOrder': 1,
                  'status': 'IN_PROGRESS',
                },
                {
                  'lessonId': 'les-thang-long-2',
                  'title': 'Thành Đại La',
                  'sortOrder': 2,
                  'status': 'LOCKED',
                },
              ],
            },
          ],
        },
        {
          'chapterId': 'phase-nhu-nguyet',
          'parentId': 'period-ly',
          'nodeType': 'PHASE',
          'code': 'PHASE_SONG_WAR',
          'title': 'Kháng chiến chống Tống',
          'sortOrder': 1,
          'events': [
            {
              'eventNodeId': 'node-nhu-nguyet',
              'eventId': 'evt-nhu-nguyet-uuid',
              'title': 'Chiến Thắng Như Nguyệt',
              'yearLabel': 'Năm 1077',
              'endYear': 1077,
              'datePrecision': 'EXACT',
              'sortOrder': 2,
              'participationType': 'REQUIRED',
              'status': 'LOCKED',
              'contentStatus': 'PLAYABLE',
              'lessons': [
                {
                  'lessonId': 'les-nhu-nguyet-1',
                  'title': 'Phòng tuyến sông Cầu',
                  'sortOrder': 1,
                  'status': 'LOCKED',
                },
              ],
            },
          ],
        },
      ],
    };

    test(
      'parses full LearnerLearningPathResponse and resolves hierarchy + pointers',
      () {
        final dto = LearningPathDto.fromJson(learnerResponseJson);

        expect(dto.pathCode, 'HISTORY_MAIN');
        expect(dto.pathVersion, 2);
        expect(dto.enrolled, isTrue);
        expect(dto.lastPeriodCode, 'LY_DYNASTY');

        expect(dto.summary.completedEvents, 2);
        expect(dto.summary.totalRequiredEvents, 5);
        expect(dto.summary.completedLessons, 3);
        expect(dto.summary.totalRequiredLessons, 8);
        expect(dto.summary.eventProgressFraction, closeTo(0.4, 1e-6));
        expect(dto.summary.lessonProgressFraction, closeTo(0.375, 1e-6));

        expect(dto.current, isNotNull);
        expect(dto.current!.chapterId, 'period-ly');
        expect(dto.current!.eventNodeId, 'node-ly-thai-to');
        expect(dto.current!.lessonId, 'les-thang-long-1');
        expect(dto.effectiveCurrent, equals(dto.current));

        // currentByPeriod skips null entry for completed period, keeps LY_DYNASTY
        expect(dto.currentByPeriod['EARLY_INDEPENDENCE'], isNull);
        expect(dto.currentByPeriod['LY_DYNASTY']?.lessonId, 'les-thang-long-1');

        // Period progress
        expect(dto.periodProgress.length, 2);
        final earlyProg = dto.progressForPeriod('EARLY_INDEPENDENCE')!;
        expect(earlyProg.percent, 100);
        expect(earlyProg.fraction, 1.0);
        expect(earlyProg.isCompleted, isTrue);

        final lyProg = dto.progressForPeriod('LY_DYNASTY')!;
        expect(lyProg.percent, 50);
        expect(lyProg.fraction, 0.5);
        expect(lyProg.isCompleted, isFalse);
        expect(lyProg.hasStarted, isTrue);

        // Hierarchy: ERA -> PERIOD -> PHASE
        expect(dto.eras.length, 1);
        expect(dto.eras.first.code, 'ERA_FEUDAL');
        expect(dto.periods.length, 2);
        expect(dto.periodsOfEra('era-feudal').length, 2);
        expect(dto.phasesOfPeriod('period-ly').length, 1);

        // eventsOfPeriod includes both direct PERIOD events and child PHASE events
        final lyEvents = dto.eventsOfPeriodCode('LY_DYNASTY');
        expect(lyEvents.length, 2);
        expect(lyEvents[0].eventNodeId, 'node-ly-thai-to');
        expect(lyEvents[1].eventNodeId, 'node-nhu-nguyet');

        // Tree builder
        final tree = dto.buildTree();
        expect(tree.length, 1);
        expect(tree.first.chapter.code, 'ERA_FEUDAL');
        expect(tree.first.depth, 0);
        expect(tree.first.totalSubtreeEvents, 3);
        expect(tree.first.children.length, 2);
        expect(tree.first.allEventsInSubtree.length, 3);

        // Lookups for E2 / E3
        expect(
          dto.findEventByNodeId('node-ly-thai-to')?.title,
          'Lý Thái Tổ Dời Đô',
        );
        expect(
          dto.findEventById('evt-nhu-nguyet-uuid')?.status,
          LearnerPathStatus.locked,
        );
        expect(
          dto.lessonStatusOf('les-thang-long-1'),
          LearnerPathStatus.inProgress,
        );
        expect(
          dto.lessonStatusOf('les-thang-long-2'),
          LearnerPathStatus.locked,
        );
        // Out-of-path lesson returns null (freely playable per A1)
        expect(dto.lessonStatusOf('out-of-path-lesson'), isNull);
      },
    );

    test(
      'parses public GET /api/v1/learning-path payload and TouchPeriodResponseDto',
      () {
        final publicJson = {
          'pathCode': 'HISTORY_MAIN',
          'pathVersion': 1,
          'title': 'Hành trình Lịch sử Việt Nam',
          'description': 'Mô tả lộ trình',
          'chapters': [
            {
              'chapterId': 'ch-1',
              'code': 'FOUNDING_ERA',
              'title': 'Buổi đầu dựng nước',
              'description': 'Thời đại Hùng Vương',
              'startYear': -700,
              'endYear': -179,
              'periodLabel': 'Khoảng thế kỷ VII TCN – năm 179 TCN',
              'sortOrder': 1,
              'themeKey': 'FOUNDING_ERA',
              'events': [
                {
                  'nodeId': 'pub-node-1',
                  'eventId': '00000000-0000-0000-0000-000000000005',
                  'slug': 'hung-vuong-van-lang',
                  'title': 'Thời Đại Hùng Vương',
                  'startYear': -700,
                  'endYear': -258,
                  'datePrecision': 'CENTURY',
                  'yearLabel': 'Khoảng thế kỷ VII TCN',
                  'period': 'Khoảng thế kỷ VII TCN',
                  'coverAssetKey': 'events/hung-vuong/hero.jpg',
                  'sortOrder': 1,
                  'contentStatus': 'NO_PUBLISHED_LESSON',
                  'participationType': 'EXPLORATION_ONLY',
                  'lessons': [],
                },
              ],
            },
          ],
        };

        final pubDto = LearningPathDto.fromJson(publicJson);
        expect(pubDto.title, 'Hành trình Lịch sử Việt Nam');
        expect(pubDto.chapters.length, 1);
        final ch = pubDto.chapters.first;
        expect(ch.nodeType, PathNodeType.period);
        expect(ch.startYear, -700);
        expect(ch.endYear, -179);

        final ev = ch.events.first;
        expect(ev.eventNodeId, 'pub-node-1');
        expect(ev.nodeId, 'pub-node-1');
        expect(ev.slug, 'hung-vuong-van-lang');
        expect(ev.datePrecision, EventDatePrecision.century);
        expect(ev.participationType, ParticipationType.explorationOnly);
        expect(ev.contentStatus, PathContentStatus.noPublishedLesson);
        expect(ev.status, LearnerPathStatus.notReady);

        final touch = TouchPeriodResponseDto.fromJson({
          'periodCode': 'LY_DYNASTY',
          'chapterId': 'd7e21000-0000-4000-8000-000000000004',
          'touchedAt': '2026-10-28T10:15:30Z',
        });
        expect(touch.periodCode, 'LY_DYNASTY');
        expect(touch.chapterId, 'd7e21000-0000-4000-8000-000000000004');
        expect(touch.touchedAt, DateTime.utc(2026, 10, 28, 10, 15, 30));
      },
    );
  });
}

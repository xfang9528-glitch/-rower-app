import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rower_app/ble/anytum_rower.dart';
import 'package:rower_app/ble/rowing_metrics.dart';
import 'package:rower_app/data/json_file.dart';
import 'package:rower_app/models/training_goal.dart';
import 'package:rower_app/models/workout.dart';
import 'package:rower_app/util/fmt.dart';

void main() {
  group('Fmt', () {
    test('时长格式', () {
      expect(Fmt.dur(0), '0:00');
      expect(Fmt.dur(65), '1:05');
      expect(Fmt.dur(3661), '1:01:01');
    });
    test('配速:<=0 视为无', () {
      expect(Fmt.pace(0), '—');
      expect(Fmt.pace(128), '2:08');
    });
    test('距离千分位', () {
      expect(Fmt.dist(2000), '2,000');
      expect(Fmt.dist(950), '950');
      expect(Fmt.dist(12345), '12,345');
    });
  });

  group('JsonFile 原子写 + 损坏留证(回归:丢全部历史风险)', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('rower_jsonfile_test');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('写入往返 + 留 .bak', () async {
      final f = File('${dir.path}/d.json');
      await JsonFile.writeAtomic(f, {'n': 1});
      expect(await JsonFile.readMap(f), {'n': 1});
      await JsonFile.writeAtomic(f, {'n': 2});
      expect(await JsonFile.readMap(f), {'n': 2});
      expect(await File('${f.path}.bak').exists(), isTrue); // 上一份留底
    });

    test('文件损坏 → 改名 .corrupt 留证 + 回滚 .bak,不静默丢数据', () async {
      final f = File('${dir.path}/d.json');
      await JsonFile.writeAtomic(f, {'good': 1}); // 第一份
      await JsonFile.writeAtomic(f, {'good': 2}); // 现 .bak={good:1}
      await f.writeAsString('{ this is not json'); // 模拟写一半损坏
      final recovered = await JsonFile.readMap(f);
      expect(recovered, {'good': 1}); // 从 .bak 回滚,而非返回空
      final corrupt = await dir
          .list()
          .where((e) => e.path.contains('.corrupt.'))
          .toList();
      expect(corrupt, isNotEmpty); // 坏文件留证可恢复
    });

    test('不存在返回 null', () async {
      expect(await JsonFile.readMap(File('${dir.path}/none.json')), isNull);
    });
  });

  group('RowingMetrics 功率上限(回归:峰值 2561W bug)', () {
    test('脉冲突发不会把功率/速度炸上天', () {
      const tn = RowingTuning(); // maxSpeed 6.0, k 2.8
      final m = RowingMetrics(tn);
      final t0 = DateTime(2026, 5, 17, 22);
      // 起划
      m.add(AnytumSample(80, 0, 0, true), t0);
      // 0.4s 后一个荒谬的脉冲跳变(模拟突发/窗口伪影)
      m.add(AnytumSample(80, 0, 100000, true),
          t0.add(const Duration(milliseconds: 400)));
      expect(m.speed, lessThanOrEqualTo(6.0));
      // 功率 = k·v³,封顶 2.8·6³ = 604.8W,远小于此前的 2561W
      expect(m.powerW, lessThanOrEqualTo(2.8 * 6 * 6 * 6 + 0.01));
      expect(m.avgPowerW, lessThanOrEqualTo(2.8 * 6 * 6 * 6 + 0.01));
    });
  });

  group('Split', () {
    test('配速按本段距离归一化(末段不足 500m 也可比)', () {
      const full = Split(
          index: 1,
          distanceM: 500,
          durationSec: 128,
          avgSpm: 24,
          avgPower: 150);
      expect(full.pace500.inSeconds, 128);
      const tail = Split(
          index: 2,
          distanceM: 250,
          durationSec: 64,
          avgSpm: 24,
          avgPower: 150);
      expect(tail.pace500.inSeconds, 128); // 64s/250m → 128s/500m
    });
  });

  group('Workout JSON 往返', () {
    test('序列化后反序列化字段一致(持久化契约)', () {
      final w = Workout(
        id: 'w_1',
        userId: 'u1',
        startTime: DateTime(2026, 5, 17, 21, 36),
        durationSec: 526,
        goal: const TrainingGoal(
            mode: TrainingMode.distance,
            targetLabel: '2000 m',
            targetValue: 2000),
        goalAchieved: true,
        distanceM: 2000,
        strokes: 198,
        pulses: 4444,
        avgSpeed: 3.8,
        avgSpm: 23,
        avgPower: 150,
        peakPower: 205,
        calories: 86,
        avgHr: 142,
        peakHr: 156,
        hrPartial: false,
        splits: const [
          Split(
              index: 1,
              distanceM: 500,
              durationSec: 132,
              avgSpm: 22,
              avgPower: 134,
              avgHr: 128),
        ],
        paceSeries: const [138, 132, 130],
        hrSeries: const [128, 142, 150],
      );
      final back = Workout.fromJson(w.toJson());
      expect(back.id, w.id);
      expect(back.distanceM, w.distanceM);
      expect(back.goal.mode, TrainingMode.distance);
      expect(back.goal.targetValue, 2000);
      expect(back.splits.length, 1);
      expect(back.splits.first.avgHr, 128);
      expect(back.paceSeries, w.paceSeries);
      expect(back.avgPace500!.inSeconds,
          Duration(milliseconds: (500 / 3.8 * 1000).round()).inSeconds);
    });

    test('copyWith 仅改 userId', () {
      final w = Workout(
        id: 'w_2',
        userId: '',
        startTime: DateTime(2026, 5, 17),
        durationSec: 100,
        goal: const TrainingGoal.free(),
        goalAchieved: false,
        distanceM: 300,
        strokes: 30,
        pulses: 600,
        avgSpeed: 3,
        avgSpm: 20,
        avgPower: 100,
        peakPower: 120,
        calories: 12,
      );
      final assigned = w.copyWith(userId: 'fang');
      expect(assigned.userId, 'fang');
      expect(assigned.distanceM, 300);
    });
  });
}

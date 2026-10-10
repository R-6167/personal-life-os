import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/life_area_repository.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('life area create assigns sequential positions', () async {
    final repo = LifeAreaRepository(AppDatabase.instance);
    final a = await repo.create(title: 'Work');
    final b = await repo.create(title: 'Health');
    final list = await repo.listActive();
    expect(list.map((e) => e.title).toList(), ['Work', 'Health']);
    expect(list.map((e) => e.position).toList(), [0, 1]);
    expect(a.position, 0);
    expect(b.position, 1);
  });

  test('life area reorder and archive', () async {
    final repo = LifeAreaRepository(AppDatabase.instance);
    final a = await repo.create(title: 'A');
    final b = await repo.create(title: 'B');
    final c = await repo.create(title: 'C');
    await repo.reorder([c.id, a.id, b.id]);
    var list = await repo.listActive();
    expect(list.map((e) => e.title).toList(), ['C', 'A', 'B']);

    await repo.archive(a.id);
    list = await repo.listActive();
    expect(list.map((e) => e.title).toList(), ['C', 'B']);
  });

  test('seed defaults only when empty', () async {
    final repo = LifeAreaRepository(AppDatabase.instance);
    await repo.seedDefaultsIfEmpty();
    final first = await repo.listActive();
    expect(first.length, LifeAreaRepository.defaultTitles.length);
    await repo.seedDefaultsIfEmpty();
    final second = await repo.listActive();
    expect(second.length, first.length);
  });

  test('rejects empty title', () async {
    final repo = LifeAreaRepository(AppDatabase.instance);
    await expectLater(
      repo.create(title: '   '),
      throwsA(isA<ArgumentError>()),
    );
  });
}

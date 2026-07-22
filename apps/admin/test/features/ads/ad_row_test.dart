import 'package:devpath_admin/src/features/ads/data/ad_row.dart';
import 'package:devpath_admin/src/features/ads/data/ad_stats_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AdRow.fromJson parses all fields incl. nullable instants', () {
    final r = AdRow.fromJson({
      'id': 7,
      'title': '배너',
      'imageUrl': 'https://cdn/x.png',
      'linkUrl': 'https://e.com',
      'slot': 'DASHBOARD_TOP',
      'weight': 3,
      'status': 'ACTIVE',
      'startsAt': '2026-07-22T00:00:00Z',
      'endsAt': null,
    });
    expect(r.id, 7);
    expect(r.title, '배너');
    expect(r.slot, 'DASHBOARD_TOP');
    expect(r.weight, 3);
    expect(r.startsAt!.toUtc().toIso8601String(), '2026-07-22T00:00:00.000Z');
    expect(r.endsAt, isNull);
  });

  test('AdRow.toRequestJson omits id and serializes instants as ISO-8601', () {
    final r = AdRow(
      id: 7,
      title: '배너',
      imageUrl: null,
      linkUrl: 'https://e.com',
      slot: 'COMMUNITY_FEED',
      weight: 1,
      status: 'PAUSED',
      startsAt: DateTime.utc(2026, 7, 22),
      endsAt: null,
    );
    final j = r.toRequestJson();
    expect(j.containsKey('id'), isFalse);
    expect(j['title'], '배너');
    expect(j['slot'], 'COMMUNITY_FEED');
    expect(j['status'], 'PAUSED');
    expect(j['startsAt'], '2026-07-22T00:00:00.000Z');
    expect(j['endsAt'], isNull);
    expect(j['imageUrl'], isNull);
  });

  test('AdStatsRow.fromJson parses date and counts', () {
    final s = AdStatsRow.fromJson({
      'date': '2026-07-22',
      'impressions': 100,
      'clicks': 5,
    });
    expect(s.date.year, 2026);
    expect(s.date.month, 7);
    expect(s.date.day, 22);
    expect(s.impressions, 100);
    expect(s.clicks, 5);
  });
}

// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_fcm/otel_fcm.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_fcm-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('send_multicast records batch breakdown + target type', () async {
    await tracedFcm<String>(
      operation: 'send_multicast',
      invoke: () async => const FcmCallResult(
        value: 'ok',
        result: FcmResult(
          projectId: 'my-app',
          targetType: 'token',
          platform: 'android',
          priority: 'HIGH',
          collapseKey: 'msg-42',
          timeToLiveSec: 3600,
          successCount: 480,
          failureCount: 20,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('fcm send_multicast')!);
    expect(a['fcm.project.id'], 'my-app');
    expect(a['fcm.target.type'], 'token');
    expect(a['fcm.platform'], 'android');
    expect(a['fcm.priority'], 'HIGH');
    expect(a['fcm.collapse.key'], 'msg-42');
    expect(a['fcm.batch.success_count'], 480);
    expect(a['fcm.batch.failure_count'], 20);
  });

  test('UNREGISTERED error_code sets span error', () async {
    await tracedFcm<String>(
      operation: 'send',
      invoke: () async => const FcmCallResult(
        value: 'ok',
        result: FcmResult(
          targetType: 'token',
          target: 'aabbcc...',
          errorCode: 'UNREGISTERED',
          statusCode: 404,
        ),
      ),
    );
    expect(
      spans.findSpanByName('fcm send')!.status,
      SpanStatusCode.Error,
    );
  });

  test('topic.subscribe with dry_run', () async {
    await tracedFcm<String>(
      operation: 'topic.subscribe',
      invoke: () async => const FcmCallResult(
        value: 'ok',
        result: FcmResult(
          targetType: 'topic',
          target: 'news',
          dryRun: true,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('fcm topic.subscribe')!);
    expect(a['fcm.target'], 'news');
    expect(a['fcm.dry_run'], true);
  });

  test('suppression skips spans', () async {
    await runWithoutFcmInstrumentationAsync(() async {
      await tracedFcm<String>(
        operation: 'send',
        invoke: () async => const FcmCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('fcm '), isEmpty);
  });
}

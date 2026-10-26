// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_fcm/otel_fcm.dart';

/// Traces FCM HTTP v1 send/topic calls with OpenTelemetry.
///
/// `otel_fcm` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each FCM HTTP v1 send/topic call in
/// [tracedFcm]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'fcm-example');

  // Wraps an FCM HTTP v1 send/topic call in a CLIENT span.
  final fcmId = await tracedFcm<String>(
    operation: 'topic.subscribe',
    invoke: () async {
      // Make the FCM HTTP v1 send/topic call here, then report what it returned.
      const id = 'fcm_8f3a2c';
      return const FcmCallResult(
          value: id,
          result: FcmResult(
              projectId: 'project_8f3a2c',
              messageName: 'messages/{message_id}',
              targetType: 'token',
              target: 'example',
              platform: 'android',
              priority: 'NORMAL',
              collapseKey: 'orders/2026/inv-1042.pdf',
              timeToLiveSec: 1,
              dryRun: true,
              successCount: 3,
              failureCount: 3,
              errorCode: 'UNREGISTERED',
              statusCode: 200));
    },
  );
  OTelLog.info('tracedFcm topic.subscribe returned $fcmId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutFcmInstrumentationAsync.
  await runWithoutFcmInstrumentationAsync(
    () => tracedFcm<String>(
      operation: 'topic.subscribe',
      invoke: () async {
        const id = 'fcm_8f3a2c';
        return const FcmCallResult(
            value: id,
            result: FcmResult(
                projectId: 'project_8f3a2c',
                messageName: 'messages/{message_id}',
                targetType: 'token',
                target: 'example',
                platform: 'android',
                priority: 'NORMAL',
                collapseKey: 'orders/2026/inv-1042.pdf',
                timeToLiveSec: 1,
                dryRun: true,
                successCount: 3,
                failureCount: 3,
                errorCode: 'UNREGISTERED',
                statusCode: 200));
      },
    ),
  );

  await OTel.shutdown();
}

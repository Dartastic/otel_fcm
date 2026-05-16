// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_fcm_suppression.dart';

const _tracerName = 'dartastic_otel_libs_fcm';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class FcmResult {
  const FcmResult({
    this.projectId,
    this.messageName,
    this.targetType,
    this.target,
    this.platform,
    this.priority,
    this.collapseKey,
    this.timeToLiveSec,
    this.dryRun,
    this.successCount,
    this.failureCount,
    this.errorCode,
    this.statusCode,
  });

  /// GCP project id.
  final String? projectId;

  /// `messages/{message_id}` returned for unicast sends.
  final String? messageName;

  /// `token` / `topic` / `condition`.
  final String? targetType;

  /// Token value (id only — never payload), topic name, or condition
  /// expression.
  final String? target;

  /// `android` / `apns` / `webpush` — which platform-specific override
  /// shaped the payload.
  final String? platform;

  /// Android: `NORMAL` / `HIGH`. APNS section uses headers
  /// `apns-priority` 10/5/1 — surfaced via otel_apns.
  final String? priority;

  /// Android collapse_key (FCM groups + delivers most recent).
  final String? collapseKey;

  /// Android TTL in seconds (0 = drop if device offline).
  final int? timeToLiveSec;

  /// `validate_only` flag (test send, no actual push).
  final bool? dryRun;

  /// For `sendAll` / `sendMulticast` / `sendEachForMulticast` —
  /// breakdown of the batch.
  final int? successCount;

  final int? failureCount;

  /// FCM error code (`UNREGISTERED` / `SENDER_ID_MISMATCH` /
  /// `QUOTA_EXCEEDED` / `INVALID_ARGUMENT` / `UNAVAILABLE` /
  /// `THIRD_PARTY_AUTH_ERROR` / `INTERNAL`).
  final String? errorCode;

  final int? statusCode;
}

class FcmCallResult<T> {
  const FcmCallResult({required this.value, this.result});
  final T value;
  final FcmResult? result;
}

/// Wraps an FCM HTTP v1 send/topic call in a CLIENT span. [operation]
/// is one of `send`, `send_all`, `send_multicast`,
/// `send_each_for_multicast`, `topic.subscribe`,
/// `topic.unsubscribe`.
Future<T> tracedFcm<T>({
  required String operation,
  required Future<FcmCallResult<T>> Function() invoke,
}) async {
  if (fcmInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'fcm',
    'rpc.method': operation,
    'fcm.operation': operation,
  };

  final span = _tracer().startSpan(
    'fcm $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.projectId != null) {
        extras.add(OTel.attributeString(
          'fcm.project.id',
          r.result!.projectId!,
        ));
      }
      if (r.result!.messageName != null) {
        extras.add(OTel.attributeString(
          'fcm.message.name',
          r.result!.messageName!,
        ));
      }
      if (r.result!.targetType != null) {
        extras.add(OTel.attributeString(
          'fcm.target.type',
          r.result!.targetType!,
        ));
      }
      if (r.result!.target != null) {
        extras.add(OTel.attributeString('fcm.target', r.result!.target!));
      }
      if (r.result!.platform != null) {
        extras.add(OTel.attributeString(
          'fcm.platform',
          r.result!.platform!,
        ));
      }
      if (r.result!.priority != null) {
        extras.add(OTel.attributeString(
          'fcm.priority',
          r.result!.priority!,
        ));
      }
      if (r.result!.collapseKey != null) {
        extras.add(OTel.attributeString(
          'fcm.collapse.key',
          r.result!.collapseKey!,
        ));
      }
      if (r.result!.timeToLiveSec != null) {
        extras.add(OTel.attributeInt(
          'fcm.ttl.sec',
          r.result!.timeToLiveSec!,
        ));
      }
      if (r.result!.dryRun != null) {
        extras.add(OTel.attributeBool('fcm.dry_run', r.result!.dryRun!));
      }
      if (r.result!.successCount != null) {
        extras.add(OTel.attributeInt(
          'fcm.batch.success_count',
          r.result!.successCount!,
        ));
      }
      if (r.result!.failureCount != null) {
        extras.add(OTel.attributeInt(
          'fcm.batch.failure_count',
          r.result!.failureCount!,
        ));
        if (r.result!.failureCount! > 0 &&
            r.result!.successCount != null &&
            r.result!.successCount == 0) {
          span.setStatus(
            SpanStatusCode.Error,
            'FCM batch all-failed',
          );
        }
      }
      if (r.result!.errorCode != null) {
        extras.add(OTel.attributeString(
          'fcm.error.code',
          r.result!.errorCode!,
        ));
        span.setStatus(
          SpanStatusCode.Error,
          'FCM ${r.result!.errorCode}',
        );
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'FCM HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

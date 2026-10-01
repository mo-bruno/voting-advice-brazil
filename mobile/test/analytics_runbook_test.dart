import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _runbookPath =
    '../docs/operations/web-product-analytics-cutover-2026-09.md';

void main() {
  test('GA4 inventory gate rejects every stream set except the approved pair',
      () async {
    final approved = [_webStream(), _androidStream()];
    final cases = <String, List<Map<String, Object?>>>{
      'missing dormant Android stream': [_webStream()],
      'replacement Android stream': [
        _webStream(),
        _androidStream(id: '99999999999'),
      ],
      'extra Android stream': [
        ...approved,
        _androidStream(id: '99999999999'),
      ],
      'extra iOS stream': [
        ...approved,
        {
          'name': 'properties/535804267/dataStreams/99999999999',
          'type': 'IOS_APP_DATA_STREAM',
          'displayName': 'Unexpected iOS app',
          'createTime': '2026-09-30T00:00:00Z',
          'updateTime': '2026-09-30T00:00:00Z',
          'iosAppStreamData': {
            'firebaseAppId': '1:1234567890:ios:unexpected',
            'bundleId': 'br.com.fpolitico.unexpected',
          },
        },
      ],
      'extra Web stream': [
        ...approved,
        _webStream(id: '99999999999'),
      ],
    };

    expect(
      await _runInventoryGate(approved),
      0,
      reason: 'the documented Web + dormant Android inventory must pass',
    );
    expect(
      await _runInventoryGate(approved, nextPageToken: 'hidden-page'),
      isNot(0),
      reason: 'a partial inventory cannot prove the exact stream set',
    );
    for (final entry in cases.entries) {
      expect(
        await _runInventoryGate(entry.value),
        isNot(0),
        reason: entry.key,
      );
    }
  });
}

Map<String, Object?> _webStream({String id = '14797759925'}) => {
      'name': 'properties/535804267/dataStreams/$id',
      'type': 'WEB_DATA_STREAM',
      'displayName': 'Farol Politico Web',
      'createTime': '2026-09-30T00:00:00Z',
      'updateTime': '2026-09-30T00:00:00Z',
      'webStreamData': {
        'measurementId': 'G-0P9XLRYVWT',
        'firebaseAppId': '1:1234567890:web:fixture',
        'defaultUri': 'https://fpolitico.com.br',
      },
    };

Map<String, Object?> _androidStream({String id = '14797877644'}) => {
      'name': 'properties/535804267/dataStreams/$id',
      'type': 'ANDROID_APP_DATA_STREAM',
      'displayName': 'Dormant Android app',
      'createTime': '2026-09-30T00:00:00Z',
      'updateTime': '2026-09-30T00:00:00Z',
      'androidAppStreamData': {
        'firebaseAppId': '1:1234567890:android:fixture',
        'packageName': 'com.example.guia_eleitoral',
      },
    };

Future<int> _runInventoryGate(
  List<Map<String, Object?>> streams, {
  String? nextPageToken,
}) async {
  final runbook = File(_runbookPath).readAsStringSync();
  final phaseStart = runbook.indexOf(
    '### A.3 Inventário GA4 e BigQueryLink — somente leitura',
  );
  expect(phaseStart, isNonNegative);
  final fenceStart = runbook.indexOf('```bash\n', phaseStart);
  final fenceEnd = runbook.indexOf('\n```', fenceStart + 8);
  expect(fenceStart, isNonNegative);
  expect(fenceEnd, isNonNegative);
  final phaseScript = runbook.substring(fenceStart + 8, fenceEnd);

  final temporaryDirectory = Directory.systemTemp.createTempSync(
    'analytics-runbook-test-',
  );
  try {
    final streamsFixture =
        File('${temporaryDirectory.path}/fixture-streams.json')
          ..writeAsStringSync(jsonEncode({
            'dataStreams': streams,
            if (nextPageToken != null) 'nextPageToken': nextPageToken,
          }));
    final script = '''
set -euo pipefail

ga_get() {
  local output_path="\$2"
  case "\$output_path" in
    */property.json)
      printf '%s\\n' '{"name":"properties/535804267","parent":"accounts/353673747"}' > "\$output_path"
      ;;
    */streams.json)
      cp -- "\$FP_STREAMS_FIXTURE" "\$output_path"
      ;;
    */bigquery-links.json)
      printf '%s\\n' '{"bigqueryLinks":[{"name":"properties/535804267/bigQueryLinks/fixture"}]}' > "\$output_path"
      ;;
    *)
      printf '%s\\n' '{}' > "\$output_path"
      ;;
  esac
}

$phaseScript
''';
    final result = await Process.run(
      'bash',
      ['-c', script],
      environment: {
        'FP_CONFIG_DIR': temporaryDirectory.path,
        'FP_STREAMS_FIXTURE': streamsFixture.path,
        'FP_GA_PROPERTY': '535804267',
        'FP_GA_WEB_STREAM': '14797759925',
        'FP_GA_ANDROID_STREAM': '14797877644',
        'FP_GA_MEASUREMENT_ID': 'G-0P9XLRYVWT',
      },
    );
    return result.exitCode;
  } finally {
    temporaryDirectory.deleteSync(recursive: true);
  }
}

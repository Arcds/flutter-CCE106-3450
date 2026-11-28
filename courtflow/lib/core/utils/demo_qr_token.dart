import 'dart:convert';

/// Phase 1 demo token. This is **not** signed and must be replaced by the
/// server-issued Ed25519 token described in the project context before pilot.
///
/// Format: `CFDEMO.<base64url(json)>` with payload
/// `{bookingId, facilityId, nbf, exp, nonce}`.
class DemoQrPayload {
  const DemoQrPayload({
    required this.bookingId,
    required this.facilityId,
    required this.nbf,
    required this.exp,
  });

  static const String prefix = 'CFDEMO.';

  final String bookingId;
  final String facilityId;
  final DateTime nbf;
  final DateTime exp;

  bool isInsideWindow(DateTime now) =>
      !now.toUtc().isBefore(nbf) && !now.toUtc().isAfter(exp);

  static DemoQrPayload? tryParse(String token) {
    if (!token.startsWith(prefix)) return null;
    try {
      final encoded = token.substring(prefix.length);
      final padded = base64Url.normalize(encoded);
      final json = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (json is! Map<String, dynamic>) return null;
      final bookingId = json['bookingId'] as String?;
      final facilityId = json['facilityId'] as String?;
      final nbf = DateTime.tryParse(json['nbf'] as String? ?? '');
      final exp = DateTime.tryParse(json['exp'] as String? ?? '');
      if (bookingId == null || facilityId == null || nbf == null || exp == null) {
        return null;
      }
      return DemoQrPayload(
        bookingId: bookingId,
        facilityId: facilityId,
        nbf: nbf,
        exp: exp,
      );
    } catch (_) {
      return null;
    }
  }
}

String issueDemoQrToken({
  required String bookingId,
  required String facilityId,
  required DateTime startsAt,
  required Duration duration,
}) {
  final payload = <String, dynamic>{
    'bookingId': bookingId,
    'facilityId': facilityId,
    'nbf': startsAt.subtract(const Duration(minutes: 30)).toUtc().toIso8601String(),
    'exp': startsAt.add(duration).toUtc().toIso8601String(),
    'nonce': DateTime.now().microsecondsSinceEpoch.toString(),
  };
  final encoded = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '${DemoQrPayload.prefix}$encoded';
}

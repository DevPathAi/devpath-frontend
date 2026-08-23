import 'dart:convert';
import 'dart:io';

final _signerCountPattern = RegExp(
  r'^Number of signers:\s*([0-9]+)\s*$',
  multiLine: true,
);
final _certificateDigestPattern = RegExp(
  r'^(?:Signer #[0-9]+|V[0-9.]+ Signer:)\s+'
  r'certificate SHA-256 digest:\s*([0-9a-fA-F]{64})\s*$',
  multiLine: true,
);

String parseSingleCertificateSha256(String output) {
  final signerCounts = _signerCountPattern
      .allMatches(output)
      .map((match) => int.parse(match.group(1)!))
      .toList();
  if (signerCounts.length != 1 || signerCounts.single != 1) {
    throw const FormatException(
      'apksigner output must report exactly one signer',
    );
  }

  final digests = _certificateDigestPattern
      .allMatches(output)
      .map((match) => match.group(1)!.toLowerCase())
      .toSet();
  if (digests.length != 1) {
    throw const FormatException(
      'apksigner output must contain one unique certificate SHA-256 digest',
    );
  }
  return digests.single;
}

Future<void> main() async {
  try {
    final output = await stdin.transform(utf8.decoder).join();
    stdout.writeln(parseSingleCertificateSha256(output));
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  }
}

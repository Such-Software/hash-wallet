import 'dart:convert';
import 'dart:io';
import 'utils/utils.dart';

const configPath = 'tool/.secrets-config.json';
const outputPath = 'lib/.secrets.g.dart';

const evmChainsConfigPath = 'tool/.evm-secrets-config.json';
const evmChainsOutputPath = 'cw_evm/lib/.secrets.g.dart';

const bitcoinConfigPath = 'tool/.bitcoin-secrets-config.json';
const bitcoinOutputPath = 'cw_bitcoin/lib/.secrets.g.dart';

const nanoConfigPath = 'tool/.nano-secrets-config.json';
const nanoOutputPath = 'cw_nano/lib/.secrets.g.dart';

Future<void> main(List<String> args) async => importSecretsConfig();

Future<void> importSecretsConfig() async {
  final outputFile = File(outputPath);
  final input = json.decode(File(configPath).readAsStringSync()) as Map<String, dynamic>;
  final output = input.keys.fold('', (String acc, String val) => acc + generateConst(val, input));

  final evmChainsOutputFile = File(evmChainsOutputPath);
  final evmChainsInput =
      json.decode(File(evmChainsConfigPath).readAsStringSync()) as Map<String, dynamic>;
  final evmChainsOutput = evmChainsInput.keys
      .fold('', (String acc, String val) => acc + generateConst(val, evmChainsInput));

  final nanoOutputFile = File(nanoOutputPath);
  final nanoInput = json.decode(File(nanoConfigPath).readAsStringSync()) as Map<String, dynamic>;
  final nanoOutput =
      nanoInput.keys.fold('', (String acc, String val) => acc + generateConst(val, nanoInput));

  // Hash Bags: upstream Cake declares bitcoinConfigPath/bitcoinOutputPath
  // but never processes them, leaving cw_bitcoin/lib/.secrets.g.dart missing
  // and the build broken on a fresh clone. Add it to the pipeline.
  final bitcoinOutputFile = File(bitcoinOutputPath);
  final bitcoinInput =
      json.decode(File(bitcoinConfigPath).readAsStringSync()) as Map<String, dynamic>;
  final bitcoinOutput =
      bitcoinInput.keys.fold('', (String acc, String val) => acc + generateConst(val, bitcoinInput));

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(output);

  if (evmChainsOutputFile.existsSync()) {
    await evmChainsOutputFile.delete();
  }

  await evmChainsOutputFile.writeAsString(evmChainsOutput);

  if (nanoOutputFile.existsSync()) {
    await nanoOutputFile.delete();
  }

  await nanoOutputFile.writeAsString(nanoOutput);

  if (bitcoinOutputFile.existsSync()) {
    await bitcoinOutputFile.delete();
  }

  await bitcoinOutputFile.writeAsString(bitcoinOutput);
}

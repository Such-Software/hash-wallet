import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import "package:yaml/yaml.dart";
import 'package:cw_core/node.dart';
import 'package:cw_core/wallet_type.dart';

Future<List<Node>> loadDefaultNodes(WalletType type) async {
  String path;
  switch (type) {
    case WalletType.monero:
      path = 'assets/node_list.yml';
      break;
    case WalletType.bitcoin:
      path = 'assets/bitcoin_electrum_server_list.yml';
      break;
    case WalletType.litecoin:
      path = 'assets/litecoin_electrum_server_list.yml';
      break;
    // TODO: (refactoring) each wallet would have its path, so `wallet.nodePath` would be decided based on chain id in Evm wallet
    case WalletType.ethereum:
      path = 'assets/ethereum_server_list.yml';
      break;
    case WalletType.nano:
      path = 'assets/nano_node_list.yml';
      break;
    case WalletType.bitcoinCash:
      path = 'assets/bitcoin_cash_electrum_server_list.yml';
      break;
    case WalletType.polygon:
      path = 'assets/polygon_node_list.yml';
      break;
    case WalletType.wownero:
      path = 'assets/wownero_node_list.yml';
      break;
    case WalletType.dogecoin:
      path = 'assets/dogecoin_electrum_server_list.yml';
      break;
    case WalletType.base:
      path = 'assets/base_node_list.yml';
      break;
    case WalletType.arbitrum:
      path = 'assets/arbitrum_node_list.yml';
      break;
    case WalletType.bsc:
      path = 'assets/bsc_node_list.yml';
      break;
    case WalletType.banano:
    case WalletType.none:
      path = '';
      break;
  }

  final nodesRaw = await rootBundle.loadString(path);
  final loadedNodes = loadYaml(nodesRaw) as YamlList;
  final nodes = <Node>[];

  for (final raw in loadedNodes) {
    if (raw is Map) {
      final node = Node.fromMap(Map<String, Object>.from(raw));
      node.type = type;
      nodes.add(node);
    }
  }

  return nodes;
}

Future<List<Node>> loadDefaultNanoPowNodes() async {
  final powNodesRaw = await rootBundle.loadString('assets/nano_pow_node_list.yml');
  final loadedPowNodes = loadYaml(powNodesRaw) as YamlList;
  final nodes = <Node>[];

  for (final raw in loadedPowNodes) {
    if (raw is Map) {
      final node = Node.fromMap(Map<String, Object>.from(raw));
      node.type = WalletType.nano;
      nodes.add(node);
    }
  }

  return nodes;
}

Future<void> resetToDefault(Box<Node> nodeSource) async {
  final wowneroNodes = await loadDefaultNodes(WalletType.wownero);
  final moneroNodes = await loadDefaultNodes(WalletType.monero);
  final bitcoinElectrumServerList = await loadDefaultNodes(WalletType.bitcoin);
  final litecoinElectrumServerList = await loadDefaultNodes(WalletType.litecoin);
  final bitcoinCashElectrumServerList = await loadDefaultNodes(WalletType.bitcoinCash);
  final ethereumNodes = await loadDefaultNodes(WalletType.ethereum);
  final nanoNodes = await loadDefaultNodes(WalletType.nano);
  final polygonNodes = await loadDefaultNodes(WalletType.polygon);
  final dogecoinElectrumServerList = await loadDefaultNodes(WalletType.dogecoin);
  final baseNodes = await loadDefaultNodes(WalletType.base);
  final arbitrumNodes = await loadDefaultNodes(WalletType.arbitrum);
  final bscNodes = await loadDefaultNodes(WalletType.bsc);

  final nodes = wowneroNodes +
      moneroNodes +
      bitcoinElectrumServerList +
      litecoinElectrumServerList +
      ethereumNodes +
      bitcoinCashElectrumServerList +
      nanoNodes +
      polygonNodes +
      dogecoinElectrumServerList +
      baseNodes +
      arbitrumNodes +
      bscNodes;

  await nodeSource.clear();
  await nodeSource.addAll(nodes);
}

Future<void> resetPowToDefault(Box<Node> powNodeSource) async {
  final nanoPowNodes = await loadDefaultNanoPowNodes();
  final nodes = nanoPowNodes;
  await powNodeSource.clear();
  await powNodeSource.addAll(nodes);
}

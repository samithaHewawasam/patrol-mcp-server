import 'dart:convert';
import '../utils/vm_service_client.dart';

Future<String> getWidgetTree(Map<String, dynamic> arguments) async {
  try {
    print('[GetWidgetTree] Starting widget tree retrieval...');

    final vmServiceUrl = arguments['vm_service_url'] as String?;
    final flatten = arguments['flatten'] as bool? ?? true;
    final keysOnly = arguments['keys_only'] as bool? ?? false;

    print('[GetWidgetTree] VM service URL: ${vmServiceUrl ?? "auto-detect"}');
    print('[GetWidgetTree] Flatten: $flatten, Keys only: $keysOnly');

    final result = await VmServiceClient.getWidgetTree(
      vmServiceUrl: vmServiceUrl,
      flatten: flatten,
      keysOnly: keysOnly,
    );

    print('[GetWidgetTree] Widget tree retrieval completed');
    return jsonEncode(result);
  } catch (e, stackTrace) {
    print('[GetWidgetTree] ERROR: $e');
    print('[GetWidgetTree] Stack trace: $stackTrace');
    return jsonEncode({
      'error': true,
      'code': 'GET_WIDGET_TREE_FAILED',
      'message': 'Failed to get widget tree: $e',
      'stack': stackTrace.toString(),
    });
  }
}

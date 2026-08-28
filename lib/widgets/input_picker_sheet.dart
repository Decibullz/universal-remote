import 'package:flutter/material.dart';
import 'package:universal_tv_remote/models/tv_input_info.dart';

class InputPickerSheet extends StatefulWidget {
  const InputPickerSheet({
    required this.deviceName,
    required this.loadInputs,
    super.key,
  });

  final String deviceName;
  final Future<List<TvInputInfo>> Function() loadInputs;

  @override
  State<InputPickerSheet> createState() => _InputPickerSheetState();
}

class _InputPickerSheetState extends State<InputPickerSheet> {
  late Future<List<TvInputInfo>> _inputsFuture;

  @override
  void initState() {
    super.initState();
    _inputsFuture = widget.loadInputs();
  }

  void _retry() {
    setState(() => _inputsFuture = widget.loadInputs());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose input',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.deviceName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<TvInputInfo>>(
              future: _inputsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SizedBox(
                    height: 180,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.input_rounded, size: 38),
                          const SizedBox(height: 10),
                          Text(
                            snapshot.error.toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final inputs = snapshot.data ?? const [];
                if (inputs.isEmpty) {
                  return const SizedBox(
                    height: 130,
                    child: Center(
                      child: Text(
                        'No selectable TV inputs were reported.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: inputs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final input = inputs[index];
                      return ListTile(
                        leading: const Icon(Icons.settings_input_hdmi_rounded),
                        title: Text(input.title),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).pop(input),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

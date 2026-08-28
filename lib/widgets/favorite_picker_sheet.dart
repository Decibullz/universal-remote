import 'package:flutter/material.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';

class FavoritePickerSheet extends StatefulWidget {
  const FavoritePickerSheet({
    required this.deviceName,
    required this.initialFavorites,
    required this.loadApps,
    super.key,
  });

  final String deviceName;
  final List<TvAppInfo> initialFavorites;
  final Future<List<TvAppInfo>> Function() loadApps;

  @override
  State<FavoritePickerSheet> createState() => _FavoritePickerSheetState();
}

class _FavoritePickerSheetState extends State<FavoritePickerSheet> {
  late Future<List<TvAppInfo>> _appsFuture;
  late List<TvAppInfo> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List<TvAppInfo>.from(widget.initialFavorites);
    _appsFuture = _loadApps();
  }

  Future<List<TvAppInfo>> _loadApps() async {
    final loaded = await widget.loadApps();
    final unique = <String, TvAppInfo>{};
    for (final app in loaded) {
      unique[app.id] = app;
    }

    final apps = unique.values.toList(growable: false)
      ..sort(
        (first, second) => first.title.toLowerCase().compareTo(
              second.title.toLowerCase(),
            ),
      );

    final normalized = <TvAppInfo>[];
    for (final favorite in _selected) {
      final match = _matchingApp(apps, favorite);
      if (match != null &&
          !normalized.any((selected) => selected.id == match.id)) {
        normalized.add(match);
      }
    }
    _selected = normalized;
    if (mounted) {
      setState(() {});
    }
    return apps;
  }

  TvAppInfo? _matchingApp(List<TvAppInfo> apps, TvAppInfo favorite) {
    for (final app in apps) {
      if (app.id == favorite.id) {
        return app;
      }
    }

    final target = favorite.title.toLowerCase();
    for (final app in apps) {
      final title = app.title.toLowerCase();
      if (title == target ||
          (target == 'mlb' &&
              (title == 'mlb.tv' || title.startsWith('mlb ')))) {
        return app;
      }
    }
    return null;
  }

  bool _isSelected(TvAppInfo app) {
    return _selected.any((selected) => selected.id == app.id);
  }

  void _toggle(TvAppInfo app) {
    setState(() {
      if (_isSelected(app)) {
        _selected.removeWhere((selected) => selected.id == app.id);
      } else if (_selected.length < 4) {
        _selected.add(app);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remove a favorite before adding one.')),
        );
      }
    });
  }

  void _retry() {
    setState(() => _appsFuture = _loadApps());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.84,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit favorites',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose four apps for ${widget.deviceName}.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${_selected.length} / 4',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search apps',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _query = value.trim().toLowerCase());
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<TvAppInfo>>(
                  future: _appsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _AppLoadError(
                        error: snapshot.error,
                        onRetry: _retry,
                      );
                    }

                    final apps = snapshot.data ?? const [];
                    final visible = _query.isEmpty
                        ? apps
                        : apps
                            .where(
                              (app) => app.title.toLowerCase().contains(_query),
                            )
                            .toList(growable: false);
                    if (visible.isEmpty) {
                      return const Center(child: Text('No matching apps.'));
                    }

                    return ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final app = visible[index];
                        final selected = _isSelected(app);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (_) => _toggle(app),
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          secondary: CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            foregroundColor: colors.onPrimaryContainer,
                            child: Text(
                              app.title.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            app.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.length == 4
                      ? () => Navigator.of(context).pop(_selected)
                      : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save favorites'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppLoadError extends StatelessWidget {
  const _AppLoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(
              error?.toString() ?? 'Could not load apps.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/widgets/favorite_app_button.dart';

class EditableFavoritesRow extends StatefulWidget {
  const EditableFavoritesRow({
    super.key,
    required this.favorites,
    required this.onChanged,
  });

  final List<TvAppInfo> favorites;
  final ValueChanged<List<TvAppInfo>> onChanged;

  @override
  State<EditableFavoritesRow> createState() => _EditableFavoritesRowState();
}

class _EditableFavoritesRowState extends State<EditableFavoritesRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggleController;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..repeat();
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  void _reorder(int oldIndex, int newIndex) {
    final updated = List<TvAppInfo>.from(widget.favorites);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    widget.onChanged(List.unmodifiable(updated));
  }

  void _remove(TvAppInfo app) {
    widget.onChanged(
      List.unmodifiable(
        widget.favorites.where((favorite) => favorite.id != app.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.favorites.isEmpty) {
      return SizedBox(
        key: const Key('editable-favorites-row'),
        height: 64,
        child: Center(
          child: Text(
            'No favorites selected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return SizedBox(
      key: const Key('editable-favorites-row'),
      height: 64,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = constraints.maxWidth * 0.02;
          final slotWidth = (constraints.maxWidth - (spacing * 3)) / 4;

          return ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            itemCount: widget.favorites.length,
            onReorderItem: _reorder,
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 7,
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
            itemBuilder: (context, index) {
              final app = widget.favorites[index];
              final trailingSpacing =
                  index == widget.favorites.length - 1 ? 0.0 : spacing;
              return SizedBox(
                key: ValueKey('editable-favorite-${app.id}'),
                width: slotWidth + trailingSpacing,
                child: Padding(
                  padding: EdgeInsets.only(right: trailingSpacing),
                  child: ReorderableDelayedDragStartListener(
                    index: index,
                    child: AnimatedBuilder(
                      animation: _wiggleController,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FavoriteAppButton(
                            app: app,
                            onPressed: () {},
                            onLongPress: null,
                          ),
                          Positioned(
                            left: 3,
                            top: 3,
                            child: Material(
                              color: Theme.of(context).colorScheme.error,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                key: Key('remove-favorite-${app.id}'),
                                customBorder: const CircleBorder(),
                                onTap: () => _remove(app),
                                child: SizedBox.square(
                                  dimension: 23,
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 17,
                                    color:
                                        Theme.of(context).colorScheme.onError,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      builder: (context, child) {
                        final phase = _wiggleController.value * math.pi * 2;
                        final direction = index.isEven ? 1 : -1;
                        return Transform.rotate(
                          angle: math.sin(phase) * 0.012 * direction,
                          child: child,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

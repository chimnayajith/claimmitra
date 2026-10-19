import 'package:flutter/material.dart';

import 'status_pill.dart';

class WorkflowTile extends StatefulWidget {
  final String title;
  final int yellow;
  final int orange;
  final int red;
  final VoidCallback? onTap;

  const WorkflowTile({
    super.key,
    required this.title,
    this.yellow = 0,
    this.orange = 0,
    this.red = 0,
    this.onTap,
  });

  @override
  State<WorkflowTile> createState() => _WorkflowTileState();
}

class _WorkflowTileState extends State<WorkflowTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: Material(
        color: _hovered
            ? Colors.grey.shade50
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),

                Wrap(
                  spacing: 10,
                  children: [
                    StatusPill(
                      color: Colors.amber,
                      count: widget.yellow,
                    ),
                    StatusPill(
                      color: Colors.orange,
                      count: widget.orange,
                    ),
                    StatusPill(
                      color: Colors.red,
                      count: widget.red,
                    ),
                  ],
                ),

                const SizedBox(width: 20),

                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
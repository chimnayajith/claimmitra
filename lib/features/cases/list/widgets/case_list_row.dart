import 'package:flutter/material.dart';

class CaseListRow extends StatefulWidget {
  final String caseNumber;
  final String clientName;
  final String currentStage;
  final String due;
  final String status;
  final Color statusColor;
  final VoidCallback? onTap;

  const CaseListRow({
    super.key,
    required this.caseNumber,
    required this.clientName,
    required this.currentStage,
    required this.due,
    required this.status,
    required this.statusColor,
    this.onTap,
  });

  @override
  State<CaseListRow> createState() => _CaseListRowState();
}

class _CaseListRowState extends State<CaseListRow> {
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
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.grey.shade50
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  widget.caseNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              Expanded(
                flex: 3,
                child: Text(widget.clientName),
              ),

              Expanded(
                flex: 3,
                child: Text(widget.currentStage),
              ),

              Expanded(
                flex: 2,
                child: Text(widget.due),
              ),

              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.statusColor
                          .withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.status,
                      style: TextStyle(
                        color: widget.statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
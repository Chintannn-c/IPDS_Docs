import 'package:flutter/material.dart';
import '../../../../core/models/file_tracking.dart';
import 'package:intl/intl.dart';

class FileTracker extends StatelessWidget {
  final FileTracking tracking;

  const FileTracker({super.key, required this.tracking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Stages mapping
    final stages = [
      _StageData("Initiated", tracking.stages.initiated),
      _StageData("Verified", tracking.stages.verified),
      _StageData("Approved", tracking.stages.approved),
      _StageData("Closed", tracking.stages.closed),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Tracking", style: theme.textTheme.titleMedium),
            if (tracking.isDelayed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Delayed",
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Custom horizontal stepper
        SizedBox(
          height: 80,
          child: Row(
            children: List.generate(stages.length, (index) {
              final stage = stages[index];
              // Logic for line color: if 'this' stage is completed, line before is green.
              // We pass 'isCompleted' of *this* stage to color the line *after* it? No.
              // Line to the left matches previous.

              return Expanded(
                child: _buildStageStep(
                  context,
                  stage,
                  isFirst: index == 0,
                  isLast: index == stages.length - 1,
                  isActive: stage.stage.completed,
                  // Line after is green if Next is completed? Or if current is completed?
                  // Usually, if Step 1 is done, line to Step 2 is green.
                  isLineAfterGreen:
                      stage.stage.completed &&
                      (index < stages.length - 1 &&
                          stages[index + 1].stage.completed),
                  isLineBeforeGreen: stage.stage.completed, // Simplified
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStageStep(
    BuildContext context,
    _StageData data, {
    bool isFirst = false,
    bool isLast = false,
    bool isActive = false,
    bool isLineAfterGreen = false,
    bool isLineBeforeGreen = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            // Line Before
            Expanded(
              child: isFirst
                  ? const SizedBox()
                  : Container(
                      height: 2,
                      color: isLineBeforeGreen
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
            ),
            // Dot
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? Colors.green : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isActive
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            // Line After
            Expanded(
              child: isLast
                  ? const SizedBox()
                  : Container(
                      height: 2,
                      // If current is active, arguably line after is active if we are 'in progress' towards next?
                      // But strictly, line is green if both ends are green.
                      color: isLineAfterGreen
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          data.label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (data.stage.timestamp != null)
          Text(
            DateFormat('MM/dd HH:mm').format(data.stage.timestamp!.toLocal()),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
      ],
    );
  }
}

class _StageData {
  final String label;
  final FileStage stage;
  _StageData(this.label, this.stage);
}

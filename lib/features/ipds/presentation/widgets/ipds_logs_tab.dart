import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ipds_provider.dart';
import 'package:file_stroage_system/core/models/activity_log.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';

class IPDSLogsTab extends StatefulWidget {
  const IPDSLogsTab({super.key});

  @override
  State<IPDSLogsTab> createState() => _IPDSLogsTabState();
}

class _IPDSLogsTabState extends State<IPDSLogsTab> {
  String _filter = 'All';
  String _searchQuery = '';
  bool _showStats = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ipds = context.watch<IPDSProvider>();
    final logs = _filterLogs(ipds.logs);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(
          child: AnimatedCrossFade(
            firstChild: _buildSummaryCounters(ipds.logs),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _showStats
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ),
        SliverToBoxAdapter(child: _buildSearchBar()),
        SliverToBoxAdapter(child: _buildFilterTabs()),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (logs.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildLogItem(logs[index]),
                childCount: logs.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.history, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Activity Stream',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () => setState(() => _showStats = !_showStats),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  _showStats
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCounters(List<ActivityLog> allLogs) {
    final success = allLogs
        .where(
          (l) => l.type == 'info' || l.type == 'login' || l.type == 'success',
        )
        .length;
    final warning = allLogs.where((l) => l.type == 'warning').length;
    final error = allLogs
        .where(
          (l) =>
              l.type == 'error' ||
              l.type == 'danger' ||
              l.title.toLowerCase().contains('brute force'),
        )
        .length;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Row(
        children: [
          _buildCounterBox('$success', 'Success', AppTheme.successColor),
          const SizedBox(width: 12),
          _buildCounterBox('$warning', 'Warning', AppTheme.warningColor),
          const SizedBox(width: 12),
          _buildCounterBox('$error', 'Error', AppTheme.errorColor),
        ],
      ),
    );
  }

  Widget _buildCounterBox(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search logs...',
          hintStyle: TextStyle(color: AppTheme.textSecondary),
          prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.textSecondary.withOpacity(0.1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.textSecondary.withOpacity(0.1),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['All', 'Success', 'Warning', 'Error'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: filters.map((f) => _buildFilterChip(f)).toList()),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    Color chipColor = AppTheme.textSecondary;
    if (label == 'Success') chipColor = AppTheme.successColor;
    if (label == 'Warning') chipColor = AppTheme.warningColor;
    if (label == 'Error') chipColor = AppTheme.errorColor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withOpacity(0.1)
                : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? chipColor.withOpacity(0.3)
                  : AppTheme.textSecondary.withOpacity(0.15),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? chipColor : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: AppTheme.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No logs found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(ActivityLog log) {
    final (icon, color) = _getLogStyle(log.type);
    final timeAgo = _getTimeAgo(log.timestamp);

    // Calculate risk points for display
    int riskPoints = 0;
    if (log.type == 'danger' || log.type == 'error') {
      riskPoints = 25;
    } else if (log.type == 'warning') {
      riskPoints = 10;
    }

    return GestureDetector(
      onTap: () => _showLogDetails(log),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(riskPoints > 0 ? 0.3 : 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.source,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Risk Points Badge
            if (riskPoints > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_rounded, color: color, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '+$riskPoints',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    log.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary.withOpacity(0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // Tap-to-expand log details modal
  void _showLogDetails(ActivityLog log) {
    final (icon, color) = _getLogStyle(log.type);

    // Calculate risk level for the meter
    int riskPoints = 0; // Risk points for this event
    String riskLabel = 'Low';
    Color riskColor = AppTheme.successColor;

    if (log.type == 'danger' || log.type == 'error') {
      riskPoints = 25;
      riskLabel = 'Critical';
      riskColor = AppTheme.errorColor;
    } else if (log.type == 'warning') {
      riskPoints = 10;
      riskLabel = 'Medium';
      riskColor = AppTheme.warningColor;
    } else {
      riskPoints = 0;
      riskLabel = 'Low';
      riskColor = AppTheme.successColor;
    }

    // Format timestamp nicely
    final formattedTime =
        '${log.timestamp.day.toString().padLeft(2, '0')}/${log.timestamp.month.toString().padLeft(2, '0')}/${log.timestamp.year} at ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.2),
                            color.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              log.status,
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Risk Meter Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              color: riskColor,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Risk Assessment',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: riskColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            riskLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: riskColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Risk Points Display
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Risk Points Added',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+$riskPoints',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: riskColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'pts',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Mini meter
                        Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(
                                  value: riskPoints / 50,
                                  strokeWidth: 6,
                                  backgroundColor: AppTheme.textSecondary
                                      .withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation(riskColor),
                                ),
                              ),
                              Icon(
                                riskPoints > 15
                                    ? Icons.warning_rounded
                                    : Icons.check_rounded,
                                color: riskColor,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Event Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Event Information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildInfoRow(
                      Icons.category_outlined,
                      'Event Type',
                      log.type.toUpperCase(),
                    ),
                    if (log.source.isNotEmpty && log.source != 'System')
                      _buildInfoRow(
                        Icons.insert_drive_file_outlined,
                        'File Name',
                        log.source,
                      ),
                    _buildInfoRow(
                      Icons.access_time,
                      'Occurred At',
                      formattedTime,
                    ),
                    if (log.actor.name.isNotEmpty &&
                        log.actor.name != 'Unknown')
                      _buildInfoRow(
                        Icons.person_outline,
                        'Name',
                        log.actor.name,
                      ),
                    if (log.actor.ipAddress != null)
                      _buildInfoRow(
                        Icons.computer,
                        'Device IP',
                        log.actor.ipAddress!,
                      ),
                    if (log.location != null)
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'Location',
                        log.location!,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _getLogStyle(String type) {
    switch (type.toLowerCase()) {
      case 'error':
      case 'danger':
        return (Icons.block_outlined, AppTheme.errorColor);
      case 'warning':
        return (Icons.warning_amber_outlined, AppTheme.warningColor);
      case 'brute_force_attempt':
        return (Icons.security_update_warning_rounded, AppTheme.errorColor);
      case 'login':
        return (Icons.login, AppTheme.primaryColor);
      case 'success':
      case 'info':
      default:
        return (Icons.check_circle_outline, AppTheme.successColor);
    }
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);

    // For logs less than 24 hours old, show relative time
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    // For logs older than 1 day, show actual date
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr = '${time.day} ${months[time.month - 1]}';

    // If same year, just show "DD MMM"
    if (time.year == now.year) {
      return dateStr;
    } else {
      // If different year, show "DD MMM YYYY"
      return '$dateStr ${time.year}';
    }
  }

  List<ActivityLog> _filterLogs(List<ActivityLog> logs) {
    var filtered = logs;

    if (_filter != 'All') {
      filtered = filtered.where((log) {
        if (_filter == 'Success')
          return log.type == 'info' ||
              log.type == 'login' ||
              log.type == 'success';
        if (_filter == 'Warning') return log.type == 'warning';
        if (_filter == 'Error')
          return log.type == 'error' || log.type == 'danger';
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (log) =>
                log.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                log.source.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return filtered;
  }
}

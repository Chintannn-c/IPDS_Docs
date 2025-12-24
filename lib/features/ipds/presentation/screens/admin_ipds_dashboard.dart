import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/presentation/widgets/app_toast.dart'; // Add this import

class AdminIPDSDashboard extends StatefulWidget {
  const AdminIPDSDashboard({super.key});

  @override
  State<AdminIPDSDashboard> createState() => _AdminIPDSDashboardState();
}

class _AdminIPDSDashboardState extends State<AdminIPDSDashboard> {
  final ApiClient _apiClient = ApiClient();

  // Data
  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _history = [];

  // UI State
  bool _isLoading = true;
  bool _isResetting = false;
  String? _error;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Timer
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchData(background: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool background = false}) async {
    if (!mounted) return;
    if (!background) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final futures = await Future.wait([
        _apiClient.fetchLiveMetrics(),
        _apiClient.fetchIPDSHistory(),
      ]);

      final metrics = futures[0];
      final history = futures[1];

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppToast.error(context, 'Error fetching admin data: $e');
      if (mounted && !background) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm System Reset'),
        content: const Text(
          'Are you sure you want to reset all IPDS metrics?\n\n'
          'This will clear risk scores, unblock all IPs, and reset threat levels for ALL users. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('RESET EVERYTHING'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isResetting = true);
      try {
        await _apiClient.adminResetSystem();
        if (mounted) {
          AppToast.success(
            context,
            'System Reset Successful! All risks normalized.',
          );
        }
        // Immediate refresh
        await _fetchData();
      } catch (e) {
        if (mounted) {
          AppToast.error(context, 'Reset Failed: $e');
        }
      } finally {
        if (mounted) setState(() => _isResetting = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMetrics {
    if (_searchQuery.isEmpty) return _metrics;
    final q = _searchQuery.toLowerCase();
    return _metrics.where((m) {
      final id = m['id']?.toString().toLowerCase() ?? '';
      final ip = m['ip']?.toString().toLowerCase() ?? '';
      return id.contains(q) || ip.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin IPDS Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _fetchData(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
          ),
        ],
      ),
      body: _isLoading && _metrics.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _metrics.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _fetchData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _fetchData(),
              child: CustomScrollView(
                slivers: [
                  // 1. Chart Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Attack Trends (Last 7 Days)",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(height: 200, child: _buildTrendChart()),
                        ],
                      ),
                    ),
                  ),

                  // 2. Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by User ID or IP...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // 3. User List
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Live User Metrics (${_filteredMetrics.length})",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),

                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildMetricCard(_filteredMetrics[index]);
                    }, childCount: _filteredMetrics.length),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_ipds_fab',
        onPressed: _isResetting ? null : _handleReset,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        icon: _isResetting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.restart_alt),
        label: Text(_isResetting ? 'Resetting...' : 'Cool Down Everything'),
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_history.isEmpty) {
      return const Center(child: Text("No history data available"));
    }

    // Extract spots
    List<FlSpot> spots = [];
    double maxY = 5;

    for (int i = 0; i < _history.length; i++) {
      final count = (_history[i]['failed_attempts'] ?? 0).toDouble();
      if (count > maxY) maxY = count;
      spots.add(FlSpot(i.toDouble(), count));
    }

    // Add some padding to Y
    maxY *= 1.2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                int idx = val.toInt();
                if (idx >= 0 && idx < _history.length) {
                  // Show every other date to save space
                  if (idx % 2 == 0) {
                    final date = _history[idx]['date'].toString();
                    // returns "2024-12-09" -> "12-09"
                    return Text(
                      date.substring(5),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        minX: 0,
        maxX: (_history.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.redAccent.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> item) {
    final riskScore = item['risk_score'] ?? 0;
    final threatLevel = item['threat_level']?.toString().toLowerCase() ?? 'low';
    final isLocked = item['is_locked'] == true;
    final ipBlocked = item['ip_blocked'] == true;
    final anomalyCount = item['anomaly_count'] ?? 0;

    Color riskColor = Colors.green;
    if (riskScore >= 50)
      riskColor = Colors.red;
    else if (riskScore >= 25)
      riskColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: riskColor.withOpacity(0.1),
          child: Text(
            riskScore.toString(),
            style: TextStyle(color: riskColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          item['id'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('IP: ${item['ip']}'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (isLocked)
                  _buildBadge('LOCKED', Colors.red, Icons.lock_outline),
                if (ipBlocked)
                  _buildBadge('IP BLOCKED', Colors.red.shade900, Icons.block),
                if (!isLocked && !ipBlocked)
                  _buildBadge(threatLevel.toUpperCase(), riskColor, null),
                if (anomalyCount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$anomalyCount anomalies',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

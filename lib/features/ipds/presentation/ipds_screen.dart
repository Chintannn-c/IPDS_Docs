import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/ipds_provider.dart';
import 'widgets/ipds_dashboard_tab.dart';
import 'widgets/ipds_logs_tab.dart';
import 'widgets/ipds_risk_tab.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'package:file_stroage_system/core/presentation/widgets/custom_header.dart';
import 'package:file_stroage_system/core/presentation/utils/screen_utils.dart'; // Add import

class IPDSScreen extends StatefulWidget {
  final int initialIndex;

  const IPDSScreen({super.key, this.initialIndex = 0});

  @override
  State<IPDSScreen> createState() => _IPDSScreenState();
}

class _IPDSScreenState extends State<IPDSScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IPDSProvider>().initData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              title: 'Security',
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh, color: AppTheme.textSecondary),
                  onPressed: () {
                    final provider = context.read<IPDSProvider>();
                    provider.fetchDashboardStats();
                    provider.fetchLogs();
                    provider.fetchRiskAnalysis();
                  },
                ),
              ],
            ),

            // Tab Bar
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: ScreenUtils.spacing(context),
                vertical: ScreenUtils.spacing(context) / 2,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Dashboard'),
                  Tab(text: 'Logs'),
                  Tab(text: 'Risk'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  IPDSDashboardTab(),
                  IPDSLogsTab(),
                  IPDSRiskTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

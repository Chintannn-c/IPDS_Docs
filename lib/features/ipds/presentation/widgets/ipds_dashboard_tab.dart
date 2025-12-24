import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ipds_provider.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'package:file_stroage_system/core/presentation/widgets/glass_container.dart';

class IPDSDashboardTab extends StatelessWidget {
  final bool isScrollable;

  const IPDSDashboardTab({super.key, this.isScrollable = true});

  @override
  Widget build(BuildContext context) {
    final ipds = context.watch<IPDSProvider>();
    final riskScore = ipds.risk['risk_score'] ?? 30;
    final riskLevel = _getRiskLevel(riskScore);

    final content = Column(
      children: [
        const SizedBox(height: 10),
        _buildRiskScoreCard(riskScore, riskLevel),
        const SizedBox(height: 20),
        _buildStatsGrid(ipds),
        const SizedBox(height: 20),
        _buildSecurityStatus(riskLevel, ipds.securityAlerts),
        const SizedBox(height: 100),
      ],
    );

    if (isScrollable) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: content,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: content,
    );
  }

  Widget _buildRiskScoreCard(int score, RiskLevel level) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            // Minimal Circular Gauge
            SizedBox(
              height: 160,
              width: 160,
              child: CustomPaint(
                painter: _MinimalGaugePainter(score: score, level: level),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: -2,
                        ),
                      ),
                      Text(
                        'of 100',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Risk Level Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: level.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                level.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: level.color,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              level.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Minimal Reset Button
            // TextButton(
            //   onPressed: () {},
            //   style: TextButton.styleFrom(
            //     foregroundColor: Colors.white.withOpacity(0.7),
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 24,
            //       vertical: 12,
            //     ),
            //   ),
            //   child: Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Icon(
            //         Icons.refresh_rounded,
            //         size: 16,
            //         color: Colors.white.withOpacity(0.5),
            //       ),
            //       const SizedBox(width: 8),
            //       Text(
            //         'Reset Analysis',
            //         style: TextStyle(
            //           fontSize: 13,
            //           fontWeight: FontWeight.w400,
            //           color: Colors.white.withOpacity(0.6),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(IPDSProvider ipds) {
    final devices = ipds.safeDeviceCount + ipds.riskDeviceCount;
    final blocked = ipds.riskDeviceCount;
    final alerts = ipds.stats['alerts'] ?? 0;
    final prevented = ipds.stats['prevented'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          Icons.devices_other_rounded,
          '$devices',
          'Active Devices',
          Colors.blue,
        ),
        _buildStatCard(
          Icons.security_rounded,
          '$blocked',
          'Blocked Threats',
          Colors.redAccent,
        ),
        _buildStatCard(
          Icons.notifications_active_rounded,
          '$alerts',
          'Security Alerts',
          Colors.amber,
        ),
        _buildStatCard(
          Icons.verified_user_rounded,
          '$prevented',
          'Attacks Prevented',
          Colors.greenAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return GlassContainer(
      opacity: 0.05,
      blur: 10,
      padding: const EdgeInsets.all(12),
      border: Border.all(color: AppTheme.textSecondary.withOpacity(0.05)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatus(
    RiskLevel level,
    List<Map<String, dynamic>> alerts,
  ) {
    return SecurityStatusCard(level: level, securityAlerts: alerts);
  }

  RiskLevel _getRiskLevel(int score) {
    if (score <= 30) return RiskLevel.low;
    if (score <= 60) return RiskLevel.medium;
    return RiskLevel.high;
  }
}

class SecurityStatusCard extends StatefulWidget {
  final RiskLevel level;
  final List<Map<String, dynamic>> securityAlerts;

  const SecurityStatusCard({
    super.key,
    required this.level,
    this.securityAlerts = const [],
  });

  @override
  State<SecurityStatusCard> createState() => _SecurityStatusCardState();
}

class _SecurityStatusCardState extends State<SecurityStatusCard> {
  bool isExpanded = false;

  IconData _getAlertIcon(String alertType) {
    switch (alertType) {
      case 'failed_login':
        return Icons.login_outlined;
      case 'blocked_device':
      case 'blocked_attempts':
        return Icons.devices_other_outlined;
      case 'high_risk':
      case 'elevated_risk':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSecure = widget.level == RiskLevel.low;

    // Transform backend alerts to UI format
    final List<Map<String, dynamic>> securityIssues = widget.securityAlerts.map(
      (alert) {
        return {
          'icon': _getAlertIcon(alert['alert_type'] ?? ''),
          'title': alert['title'] ?? 'Security Alert',
          'description': alert['description'] ?? '',
          'severity': alert['severity'] ?? 'medium',
        };
      },
    ).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isSecure ? const Color(0xFF0F172A) : const Color(0xFF2A1215),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSecure
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: securityIssues.isEmpty
                ? null
                : () {
                    setState(() {
                      isExpanded = !isExpanded;
                    });
                  },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  // Status Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSecure
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSecure
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      color: isSecure ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text Content - Flexible to prevent overflow
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSecure ? 'System Secure' : 'Attention Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSecure ? Colors.white : Colors.red[100],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSecure
                              ? 'Real-time protection is active'
                              : 'Potential vulnerabilities detected',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSecure
                                ? Colors.white.withOpacity(0.6)
                                : Colors.red[200],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Active Badge - Fixed size, won't overflow
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSecure ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (securityIssues.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: isExpanded ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expandable Details Section
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
                    children: [
                      Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Detected Issues (${securityIssues.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...securityIssues.map((issue) {
                              final severityColor = issue['severity'] == 'high'
                                  ? Colors.red
                                  : issue['severity'] == 'medium'
                                  ? Colors.orange
                                  : Colors.yellow;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: severityColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: severityColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        issue['icon'],
                                        size: 18,
                                        color: severityColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            issue['title'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            issue['description'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white.withOpacity(
                                                0.6,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: severityColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        issue['severity']
                                            .toString()
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: severityColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

enum RiskLevel {
  low(Color(0xFF22C55E), 'LOW RISK', 'System is secure. No threats detected.'),
  medium(
    Color(0xFFF59E0B),
    'MEDIUM RISK',
    'Some unusual activity detected. Monitor closely.',
  ),
  high(
    Color(0xFFEF4444),
    'HIGH RISK',
    'Critical threats detected. Immediate action required.',
  );

  final Color color;
  final String label;
  final String description;
  const RiskLevel(this.color, this.label, this.description);
}

class _MinimalGaugePainter extends CustomPainter {
  final int score;
  final RiskLevel level;

  _MinimalGaugePainter({required this.score, required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = -math.pi * 0.75;
    const sweepLength = math.pi * 1.5;

    // Background Arc - thin and subtle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepLength,
      false,
      bgPaint,
    );

    // Progress Arc - clean, no glow
    final progressPaint = Paint()
      ..color = level.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final progressSweep = (score / 100) * sweepLength;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressSweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ipds_provider.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'package:file_stroage_system/features/auth/presentation/auth_provider.dart';

class IPDSRiskTab extends StatelessWidget {
  const IPDSRiskTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ipds = context.watch<IPDSProvider>();
    final auth = context.watch<AuthProvider>();
    final risk = ipds.risk;

    final riskScore = risk['risk_score'] ?? 0;
    final riskLevel = _getRiskLevel(riskScore);
    final preventedAttacks = risk['prevented_attacks'] ?? 0;
    final history = (risk['history'] as List?) ?? [];
    final riskFactors = (risk['risk_factors'] as List?) ?? [];
    final threats = (risk['threats'] as List?) ?? [];

    // Get user MFA status
    final user = auth.user ?? {};
    final mfaEnabled = user['mfa_enabled'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRiskCard(riskScore, riskLevel, preventedAttacks),
          const SizedBox(height: 24),

          // 7-Day History Section
          _buildSectionHeader('7-Day Attack History', Icons.timeline),
          const SizedBox(height: 12),
          _buildHistoryChart(history),
          const SizedBox(height: 24),

          // Risk Factors Section
          _buildSectionHeader('Risk Factors', Icons.analytics_outlined),
          const SizedBox(height: 12),
          ...riskFactors.map(
            (factor) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRiskFactorCard(factor),
            ),
          ),

          // Show 2FA specifically if not in factors
          if (!riskFactors.any((f) => f['name'] == 'Authentication'))
            _buildRiskFactor(
              Icons.security,
              mfaEnabled ? AppTheme.successColor : AppTheme.warningColor,
              '2-Step Verification',
              mfaEnabled
                  ? '2-Step verification is enabled'
                  : '2-Step verification not enabled - recommended',
              mfaEnabled ? 0 : 15,
            ),

          const SizedBox(height: 24),

          // Recommendations Section
          _buildSectionHeader('Recommendations', Icons.lightbulb_outline),
          const SizedBox(height: 12),
          _buildRecommendationsSection(
            context,
            riskScore,
            threats,
            mfaEnabled,
            riskFactors,
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRiskCard(int score, RiskLevel level, int preventedAttacks) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            level.color.withOpacity(0.9),
            level.color.withOpacity(0.7),
            level.color.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: level.color.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: level.color.withOpacity(0.2),
            blurRadius: 60,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated Risk Meter
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: score.toDouble()),
            builder: (context, value, child) {
              return SizedBox(
                height: 140,
                width: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow effect for high risk
                    if (score > 70)
                      Container(
                        height: 160,
                        width: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    CustomPaint(
                      painter: _RiskArcPainter(score: value.toInt()),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const Text(
                              'pts',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'RISK LEVEL',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white60,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            level.label,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            level.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusIndicator(
                Icons.shield_outlined,
                '$preventedAttacks',
                'Prevented',
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatusIndicator(
                Icons.verified_user_outlined,
                'Active',
                'Security',
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatusIndicator(
                Icons.check_circle_outline,
                'On',
                'Protection',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryChart(List history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            'No history data available',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final maxScore = history.fold<int>(30, (max, item) {
      final score = item['score'] ?? 0;
      return score > max ? score : max;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceColor,
            AppTheme.surfaceColor.withOpacity(0.5),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.textSecondary.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Daily Risk Points',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Max: $maxScore',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: history.asMap().entries.map<Widget>((entry) {
                final index = entry.key;
                final item = entry.value;
                final score = item['score'] ?? 0;
                final date = item['date'] ?? '';

                // Extract day and month
                final day = date.length >= 10 ? date.substring(8, 10) : '--';
                final month = date.length >= 10 ? date.substring(5, 7) : '';
                final monthNames = [
                  '',
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
                final monthName =
                    month.isNotEmpty && int.tryParse(month) != null
                    ? monthNames[int.parse(month)]
                    : '';

                final height = maxScore > 0 ? (score / maxScore) * 75 : 0.0;
                final color = _getScoreColor(score);
                final isToday = index == history.length - 1;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 800 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0, end: height),
                      builder: (context, animatedHeight, child) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Bar
                            Container(
                              height: 75,
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: double.infinity,
                                height: animatedHeight.clamp(6.0, 75.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [color, color.withOpacity(0.6)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                  boxShadow: score > 0
                                      ? [
                                          BoxShadow(
                                            color: color.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Date label
                            Column(
                              children: [
                                Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: isToday ? 11 : 11,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isToday
                                        ? AppTheme.primaryColor
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  monthName,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),

                            // Score value
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: score > 0
                                    ? color.withOpacity(0.15)
                                    : AppTheme.textSecondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$score',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: score > 0
                                      ? color
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score < 30) return AppTheme.successColor;
    if (score < 70) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Widget _buildRiskFactorCard(Map factor) {
    final name = factor['name'] ?? 'Unknown';
    final score = factor['score'] ?? 0;
    final description = factor['description'] ?? '';
    final iconName = factor['icon'] ?? 'security';

    IconData icon;
    Color color;

    switch (iconName) {
      case 'login':
        icon = Icons.login;
        color = AppTheme.primaryColor;
        break;
      case 'devices':
        icon = Icons.devices_outlined;
        color = Colors.purple;
        break;
      case 'folder':
        icon = Icons.folder_outlined;
        color = Colors.teal;
        break;
      case 'wifi':
        icon = Icons.wifi;
        color = Colors.indigo;
        break;
      case 'security':
        icon = Icons.security;
        color = Colors.orange;
        break;
      default:
        icon = Icons.shield_outlined;
        color = AppTheme.textSecondary;
    }

    return _buildRiskFactor(icon, color, name, description, score);
  }

  Widget _buildRiskFactor(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    int points,
  ) {
    final progress = (points / 30).clamp(0.0, 1.0);
    final isHighRisk = points > 15;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: progress),
      builder: (context, animatedProgress, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isHighRisk
                  ? [color.withOpacity(0.15), color.withOpacity(0.05)]
                  : [AppTheme.surfaceColor, AppTheme.surfaceColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighRisk
                  ? color.withOpacity(0.4)
                  : AppTheme.textSecondary.withOpacity(0.1),
              width: isHighRisk ? 2 : 1,
            ),
            boxShadow: isHighRisk
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.9),
                          color.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.3,
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
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: points > 0
                              ? color.withOpacity(0.15)
                              : AppTheme.successColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: points > 0
                                ? color.withOpacity(0.3)
                                : AppTheme.successColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '$points pts',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: points > 0 ? color : AppTheme.successColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: animatedProgress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsSection(
    BuildContext context,
    int riskScore,
    List threats,
    bool mfaEnabled,
    List riskFactors,
  ) {
    final recommendations = <_Recommendation>[];

    // Check risk factors for specific recommendations
    final loginRisk =
        riskFactors.firstWhere(
          (f) => f['name'] == 'Login Activity',
          orElse: () => {'score': 0},
        )['score'] ??
        0;

    final fileRisk =
        riskFactors.firstWhere(
          (f) => f['name'] == 'File Activity',
          orElse: () => {'score': 0},
        )['score'] ??
        0;

    // Add recommendations based on state
    if (riskScore > 30 || loginRisk > 10) {
      recommendations.add(
        _Recommendation(
          icon: Icons.password,
          color: AppTheme.errorColor,
          title: 'Change Password',
          description: 'Suspicious activity detected. Update your password.',
          action: () => Navigator.pushNamed(context, '/profile'),
        ),
      );
    }

    if (fileRisk > 0) {
      recommendations.add(
        _Recommendation(
          icon: Icons.delete_sweep,
          color: Colors.orange,
          title: 'Remove Harmful Files',
          description:
              'Risky files detected in your storage. Review and remove.',
          action: () => Navigator.pushNamed(context, '/all_files'),
        ),
      );
    }

    if (!mfaEnabled) {
      recommendations.add(
        _Recommendation(
          icon: Icons.security,
          color: AppTheme.primaryColor,
          title: 'Enable 2-Step Verification',
          description: 'Add an extra layer of security to your account.',
          action: () => Navigator.pushNamed(context, '/mfa_setup'),
        ),
      );
    }

    // Always show if no specific recommendations
    if (recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Clear!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor,
                    ),
                  ),
                  Text(
                    'No immediate actions required. Your account is secure.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: recommendations
          .map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRecommendationCard(rec),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecommendationCard(_Recommendation rec) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: rec.action,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rec.color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rec.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(rec.icon, color: rec.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rec.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: rec.color, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  RiskLevel _getRiskLevel(int score) {
    if (score <= 30) return RiskLevel.low;
    if (score <= 70) return RiskLevel.medium;
    return RiskLevel.high;
  }
}

class _Recommendation {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback action;

  _Recommendation({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.action,
  });
}

enum RiskLevel {
  low(Color(0xFF22C55E), 'LOW', 'System is secure.'),
  medium(Color(0xFFF59E0B), 'MEDIUM', 'Some activity detected.'),
  high(Color(0xFFEF4444), 'HIGH', 'Critical threats detected!');

  final Color color;
  final String label;
  final String description;
  const RiskLevel(this.color, this.label, this.description);
}

class _RiskArcPainter extends CustomPainter {
  final int score;

  _RiskArcPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background arc with shadow
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Progress arc with gradient effect
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, Colors.white.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 150) * math.pi * 1.5;

    // Draw glow effect
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      sweepAngle,
      false,
      glowPaint,
    );

    // Draw actual progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

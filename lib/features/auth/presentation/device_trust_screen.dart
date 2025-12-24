import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'auth_provider.dart';

class DeviceTrustScreen extends StatefulWidget {
  const DeviceTrustScreen({super.key});

  @override
  State<DeviceTrustScreen> createState() => _DeviceTrustScreenState();
}

class _DeviceTrustScreenState extends State<DeviceTrustScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.loadCurrentDeviceId();
      authProvider.fetchDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),

              // DEVICE LIST
              Expanded(
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final devices = List<Map<String, dynamic>>.from(
                      auth.devices.map((d) => Map<String, dynamic>.from(d)),
                    );

                    // Sort: Current device first, then active before blocked
                    devices.sort((a, b) {
                      final aIsCurrent = auth.isCurrentDevice(a);
                      final bIsCurrent = auth.isCurrentDevice(b);

                      // Primary sort: Current device first
                      if (aIsCurrent) return -1;
                      if (bIsCurrent) return 1;

                      // Secondary sort: Active devices before blocked
                      final aBlocked = a['is_blocked'] ?? false;
                      final bBlocked = b['is_blocked'] ?? false;
                      if (!aBlocked && bBlocked) return -1;
                      if (aBlocked && !bBlocked) return 1;

                      return 0; // Same priority
                    });

                    if (devices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.devices_other,
                              size: 64,
                              color: color.onSurface.withOpacity(.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No devices found",
                              style: theme.textTheme.titleMedium!.copyWith(
                                color: color.onSurface.withOpacity(.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => auth.fetchDevices(),
                              icon: const Icon(Icons.refresh),
                              label: const Text("Refresh"),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () => auth.fetchDevices(),
                      child: ListView.separated(
                        itemBuilder: (ctx, index) => _deviceCard(
                          context: context,
                          device: devices[index],
                          auth: auth,
                        ),
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemCount: devices.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER UI
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Text(
            "ACCESS CONTROL",
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall!.copyWith(
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Total Devices",
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DEVICE CARD UI
  // ---------------------------------------------------------------------------

  Widget _deviceCard({
    required BuildContext context,
    required Map<String, dynamic> device,
    required AuthProvider auth,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final String name = device['name'] ?? "Unknown Device";
    final String ip = device['ip_address'] ?? "Unknown IP";
    final String type = device['type'] ?? "unknown";
    final bool trusted = device['is_trusted'] ?? false;
    final bool blocked = device['is_blocked'] ?? false;
    final String id = device['device_id'] ?? "";
    final bool isCurrent = auth.isCurrentDevice(device);

    // status pill properties
    Color statusColor;
    String statusText;

    if (blocked) {
      statusText = "BLOCKED";
      statusColor = color.error;
    } else if (trusted) {
      statusText = "TRUSTED";
      statusColor = Colors.green;
    } else {
      statusText = "UNTRUSTED";
      statusColor = color.onSurface.withOpacity(.5);
    }

    IconData icon = Icons.devices_other_rounded;
    if (type.contains("mobile") || type.contains("android"))
      icon = Icons.smartphone;
    if (type.contains("desktop") || type.contains("windows"))
      icon = Icons.computer_rounded;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 1, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: GestureDetector(
        onTapDown: (_) => setState(() {}),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.surface.withOpacity(.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent
                      ? color.secondary.withOpacity(.4)
                      : color.outline.withOpacity(.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOP ROW: ICON + NAME + STATUS PILL
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: statusColor.withOpacity(.08),
                        ),
                        child: Icon(icon, size: 20, color: statusColor),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            // ENHANCED: Show OS, Browser, Location
                            Row(
                              children: [
                                // OS
                                if (device['os'] != null &&
                                    device['os'] != 'Unknown')
                                  Flexible(
                                    child: Text(
                                      device['os'],
                                      style: theme.textTheme.bodySmall!
                                          .copyWith(
                                            color: color.onSurface.withOpacity(
                                              .6,
                                            ),
                                            fontSize: 12,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // Separator
                                if (device['os'] != null &&
                                    device['os'] != 'Unknown' &&
                                    device['browser_or_app'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        color: color.onSurface.withOpacity(.4),
                                      ),
                                    ),
                                  ),
                                // Browser
                                if (device['browser_or_app'] != null &&
                                    device['browser_or_app'] != 'Unknown')
                                  Flexible(
                                    child: Text(
                                      device['browser_or_app'],
                                      style: theme.textTheme.bodySmall!
                                          .copyWith(
                                            color: color.onSurface.withOpacity(
                                              .6,
                                            ),
                                            fontSize: 12,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            // Location (if available)
                            if (device['location'] != null &&
                                device['location'] != 'Unknown' &&
                                !device['location'].toString().startsWith(
                                  'IP:',
                                ))
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 12,
                                      color: color.onSurface.withOpacity(.4),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        device['location'],
                                        style: theme.textTheme.bodySmall!
                                            .copyWith(
                                              color: color.onSurface
                                                  .withOpacity(.5),
                                              fontSize: 11,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      _statusPill(
                        context,
                        isCurrentDevice: isCurrent,
                        statusText: statusText,
                        statusColor: statusColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  if (!isCurrent)
                    _deviceActions(context, auth, id, trusted, blocked, name),
                  if (isCurrent) _cannotModifyInfo(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS PILL UI
  // ---------------------------------------------------------------------------

  Widget _statusPill(
    BuildContext context, {
    required bool isCurrentDevice,
    required String statusText,
    required Color statusColor,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isCurrentDevice
            ? LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade700],
              )
            : LinearGradient(
                colors: [
                  statusColor.withOpacity(.2),
                  statusColor.withOpacity(.35),
                ],
              ),
      ),
      child: Text(
        isCurrentDevice ? "THIS DEVICE" : statusText,
        style: theme.textTheme.labelSmall!.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: .3,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION ROW (Trust / Block / Remove)
  // ---------------------------------------------------------------------------

  Widget _deviceActions(
    BuildContext context,
    AuthProvider auth,
    String id,
    bool trusted,
    bool blocked,
    String name,
  ) {
    final color = Theme.of(context).colorScheme;

    return Column(
      children: [
        Divider(color: color.outline.withOpacity(.1), thickness: 1, height: 16),

        // Trust Switch Row
        if (!blocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    trusted ? Icons.verified_user : Icons.shield_outlined,
                    color: trusted
                        ? Colors.green
                        : color.onSurface.withOpacity(.5),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Trusted Device",
                  style: TextStyle(
                    color: color.onSurface.withOpacity(.8),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: trusted,
                  onChanged: (_) => auth.toggleDeviceTrust(id),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),

        // Action Buttons Row
        Row(
          children: [
            // Block/Unblock Button
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => auth.toggleDeviceBlock(id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blocked
                        ? AppTheme.successColor.withOpacity(.15)
                        : AppTheme.errorColor.withOpacity(.15),
                    foregroundColor: blocked
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      side: BorderSide(
                        color: blocked
                            ? AppTheme.successColor.withOpacity(.3)
                            : AppTheme.errorColor.withOpacity(.3),
                      ),
                    ),
                  ),
                  icon: Icon(
                    blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    size: 18,
                  ),
                  label: Text(
                    blocked ? "Unblock" : "Block",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppTheme.spacingM),

            // Remove Button
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmRemove(context, id, auth, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textSecondary.withOpacity(.1),
                    foregroundColor: AppTheme.textSecondary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      side: BorderSide(
                        color: AppTheme.textSecondary.withOpacity(.2),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    "Remove",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cannotModifyInfo(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          "This device cannot be modified",
          style: TextStyle(
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REMOVE DIALOG
  // ---------------------------------------------------------------------------

  void _confirmRemove(
    BuildContext context,
    String id,
    AuthProvider auth,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Remove Device"),
        content: Text(
          "Are you sure you want to remove \"$name\"?\n\n"
          "It will require login again to access your account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              auth.removeDevice(id);
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

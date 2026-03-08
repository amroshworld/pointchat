import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';

class AiSubscriptionScreen extends StatefulWidget {
  const AiSubscriptionScreen({super.key});

  @override
  State<AiSubscriptionScreen> createState() => _AiSubscriptionScreenState();
}

class _AiSubscriptionScreenState extends State<AiSubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService.instance;

  @override
  void initState() {
    super.initState();
    _subscriptionService.refresh();
  }

  Future<void> _purchase(Package package) async {
    final unlocked = await _subscriptionService.purchasePackage(package);
    if (!mounted) {
      return;
    }
    if (unlocked) {
      Navigator.of(context).pop(true);
    }
  }

  String _packageLabel(Package package) {
    final raw = package.packageType.name;
    return raw[0].toUpperCase() + raw.substring(1).replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: Text(
          'Unlock AI',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<SubscriptionState>(
          valueListenable: _subscriptionService.state,
          builder: (context, state, _) {
            final packages = state.offering?.availablePackages ?? const [];

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B1C23), Color(0xFF10231B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI is paid only',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textPri,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'There is no free AI tier. Subscribe to use AI prompts, AI bots, and future premium model features.',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSec,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _FeatureLine(
                        label: 'All AI prompts require an active subscription',
                      ),
                      const _FeatureLine(
                        label: 'Bot chats use the same AI entitlement',
                      ),
                      const _FeatureLine(
                        label:
                            'Android purchases come from Google Play through RevenueCat',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!state.isConfigured)
                  _MessageCard(
                    message:
                        state.message ??
                        'RevenueCat is not configured yet. Add your API keys and offering in the app build.',
                  )
                else if (state.hasAiAccess)
                  const _MessageCard(message: 'Your AI subscription is active.')
                else if (packages.isEmpty && state.isBusy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (packages.isEmpty)
                  _MessageCard(
                    message:
                        state.message ??
                        'No subscription packages are available. Create an offering in RevenueCat and attach your Google Play products.',
                  )
                else
                  ...packages.map(
                    (package) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PackageCard(
                        package: package,
                        label: _packageLabel(package),
                        isBusy: state.isBusy,
                        onPressed: () => _purchase(package),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: state.isBusy
                      ? null
                      : () async {
                          await _subscriptionService.restorePurchases();
                          if (!context.mounted) {
                            return;
                          }
                          if (_subscriptionService.hasAiAccess) {
                            Navigator.of(context).pop(true);
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPri,
                    side: const BorderSide(color: AppTheme.border),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Restore purchases',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                if ((state.message ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    state.message!,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSec,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Package package;
  final String label;
  final bool isBusy;
  final VoidCallback onPressed;

  const _PackageCard({
    required this.package,
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPri,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  product.priceString,
                  style: GoogleFonts.inter(
                    color: AppTheme.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.title,
            style: GoogleFonts.inter(
              color: AppTheme.textPri,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (product.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              product.description,
              style: GoogleFonts.inter(
                color: AppTheme.textSec,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isBusy ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.green,
                foregroundColor: AppTheme.bg,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isBusy ? 'Processing...' : 'Subscribe',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final String label;

  const _FeatureLine({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle, size: 16, color: AppTheme.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(color: AppTheme.textSec, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(color: AppTheme.textSec, height: 1.5),
      ),
    );
  }
}

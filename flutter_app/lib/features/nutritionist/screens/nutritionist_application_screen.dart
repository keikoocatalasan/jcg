import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/auth/account_flow_provider.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';
import 'package:path/path.dart' as path;

class NutritionistApplicationScreen extends ConsumerStatefulWidget {
  const NutritionistApplicationScreen({super.key});

  @override
  ConsumerState<NutritionistApplicationScreen> createState() =>
      _NutritionistApplicationScreenState();
}

class _NutritionistApplicationScreenState
    extends ConsumerState<NutritionistApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _credentialNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  Uint8List? _credentialBytes;
  String? _credentialMimeType;
  String? _credentialExtension;
  DateTime? _expirationDate;
  bool _isSubmitting = false;
  bool _editingCredentials = false;

  @override
  void dispose() {
    _credentialNameController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickCredential() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (file == null) return;

      final extension = path.extension(file.name).toLowerCase();
      final allowed = <String, String>{
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.webp': 'image/webp',
      };
      final mimeType = allowed[extension];
      if (mimeType == null) {
        _showMessage('Choose a JPG, PNG, or WebP image.');
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showMessage('That image could not be read. Choose another image.');
        return;
      }
      setState(() {
        _credentialBytes = bytes;
        _credentialMimeType = mimeType;
        _credentialExtension = extension.substring(1);
      });
    } catch (_) {
      _showMessage('Could not open your photos. Please try again.');
    }
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 15, 12, 31),
      helpText: 'PRC license expiration date',
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  Future<void> _submit() async {
    if (AppConfig.isLocalTestMode) {
      _showMessage('Credential applications need a connected online account.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_credentialBytes == null ||
        _credentialMimeType == null ||
        _credentialExtension == null) {
      _showMessage('Add a clear image of your nutritionist credential.');
      return;
    }
    if (_expirationDate == null) {
      _showMessage('Choose your PRC license expiration date.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(nutritionistServiceProvider).submitApplication(
            credentialName: _credentialNameController.text,
            licenseNumber: _licenseNumberController.text,
            prcLicenseExpirationDate: _expirationDate!,
            documentBytes: _credentialBytes!,
            mimeType: _credentialMimeType!,
            fileExtension: _credentialExtension!,
          );
      ref.invalidate(nutritionistApplicationProvider);
      ref.invalidate(verifiedNutritionistProvider);
      if (mounted) {
        _showMessage('Application submitted for admin verification.');
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        _showMessage('Application could not be submitted: $message');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _useFoodTracking() {
    enterConsumerFlow(ref);
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final applicationAsync = ref.watch(nutritionistApplicationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutritionist verification'),
        actions: [
          IconButton(
            tooltip: 'Refresh application status',
            onPressed: () => ref.invalidate(nutritionistApplicationProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: applicationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _ApplicationMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not check application status',
          message:
              'Connect to the internet and try again. If this continues, the online application service may not be ready yet.',
        ),
        data: (application) {
          if (application?.status == 'verified' && !_editingCredentials) {
            return _buildVerified(application!);
          }
          if (application?.status == 'pending') {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _ApplicationMessage(
                  icon: Icons.hourglass_top_rounded,
                  title: 'Pending verification',
                  message:
                      'Your credential details were submitted on ${_date(application!.submittedAt)}. Food-review access will be enabled after an administrator verifies your PRC credential.',
                  color: AppColors.warning,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _useFoodTracking,
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Use food tracking while you wait'),
                ),
              ],
            );
          }
          if (application?.status == 'suspended') {
            return _ApplicationMessage(
              icon: Icons.block_outlined,
              title: 'Reviewer access suspended',
              message: application!.suspensionReason?.trim().isNotEmpty == true
                  ? application.suspensionReason!
                  : application.reviewNote?.trim().isNotEmpty == true
                      ? application.reviewNote!
                      : 'Contact an administrator if you have questions about your reviewer access.',
              color: AppColors.error,
            );
          }

          return _buildApplicationForm(
            rejectedApplication:
                application?.status == 'rejected' ? application : null,
          );
        },
      ),
    );
  }

  Widget _buildVerified(NutritionistApplication application) {
    final expiration = application.prcLicenseExpirationDate;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ApplicationMessage(
          icon: Icons.verified_outlined,
          title: 'Professional verification complete',
          message:
              'You can review official food nutrition data and record source evidence while online.',
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Profession', value: application.profession),
                _DetailRow(
                  label: 'Name on credential',
                  value: application.credentialName,
                ),
                _DetailRow(
                  label: 'PRC license',
                  value: _maskLicense(application.licenseNumber),
                ),
                _DetailRow(
                  label: 'License expiration',
                  value: expiration == null
                      ? 'Not yet recorded'
                      : DateFormat('MMM d, yyyy').format(expiration),
                ),
                _DetailRow(
                  label: 'Verified on',
                  value: application.reviewedAt == null
                      ? '—'
                      : DateFormat('MMM d, yyyy')
                          .format(application.reviewedAt!),
                ),
              ],
            ),
          ),
        ),
        if (application.revalidationRequired ||
            application.prcLicenseExpirationDate == null) ...[
          const SizedBox(height: 12),
          const _ApplicationMessage(
            icon: Icons.warning_amber_rounded,
            title: 'Credential revalidation required',
            message:
                'Your PRC license expiration date is not on record yet. Submit it the next time you update your credentials so the administrator can re-verify your access.',
            color: AppColors.warning,
          ),
        ],
        if (application.isExpired) ...[
          const SizedBox(height: 12),
          const _ApplicationMessage(
            icon: Icons.error_outline,
            title: 'Credential expired',
            message:
                'Professional review actions are paused until your PRC credential is renewed and re-verified.',
            color: AppColors.error,
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go('/nutritionist'),
          icon: const Icon(Icons.workspaces_outline),
          label: const Text('Open nutritionist workspace'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isSubmitting
              ? null
              : () => setState(() {
                    _credentialNameController.text = application.credentialName;
                    _licenseNumberController.text = application.licenseNumber;
                    _expirationDate = application.prcLicenseExpirationDate;
                    _editingCredentials = true;
                  }),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Update credential details'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _useFoodTracking,
          icon: const Icon(Icons.restaurant_menu),
          label: const Text('Open food tracking'),
        ),
      ],
    );
  }

  Widget _buildApplicationForm({
    required NutritionistApplication? rejectedApplication,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_editingCredentials) ...[
          _ApplicationMessage(
            icon: Icons.info_outline,
            title: 'Re-verification required',
            message:
                'Updating your professional credentials returns your access to pending verification until an administrator verifies the new details.',
            color: AppColors.warning,
            onDismiss: () => setState(() => _editingCredentials = false),
          ),
          const SizedBox(height: 12),
        ],
        if (rejectedApplication != null) ...[
          _ApplicationMessage(
            icon: Icons.info_outline,
            title: 'Changes requested',
            message: rejectedApplication.rejectionReason?.trim().isNotEmpty ==
                    true
                ? rejectedApplication.rejectionReason!
                : rejectedApplication.reviewNote?.trim().isNotEmpty == true
                    ? rejectedApplication.reviewNote!
                    : 'Your previous submission was not approved. You may submit updated information.',
            color: AppColors.warning,
          ),
          const SizedBox(height: 12),
        ],
        if (!_editingCredentials && rejectedApplication == null) ...[
          _SetupChecklist(credentialReady: _credentialBytes != null),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply to verify food nutrition data',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nutritionist-Dietitian accounts require professional verification before review actions become available. An administrator checks the PRC credential details you provide. This is a manual admin review, not automatic PRC verification.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const _PrivacyNotice(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Profession: $nutritionistProfession',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _credentialNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name shown on credential',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Enter the name shown on the credential.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseNumberController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'PRC license number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'Enter the PRC license number.'
                    : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _isSubmitting ? null : _pickExpirationDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'PRC license expiration date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _expirationDate == null
                        ? 'Choose expiration date'
                        : DateFormat('MMM d, yyyy').format(_expirationDate!),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _expirationDate == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Upload your PRC ID / credential',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_credentialBytes case final bytes?) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            bytes,
                            height: 200,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 100,
                              child: Center(
                                child: Text('Image preview unavailable'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickCredential,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(_credentialBytes == null
                            ? 'Choose credential image'
                            : 'Change credential image'),
                      ),
                      Text(
                        'JPG, PNG, or WebP · up to 5 MB. The image stays private to you and the reviewing administrator.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label:
                      Text(_isSubmitting ? 'Submitting…' : 'Submit for review'),
                ),
              ),
              if (AppConfig.isLocalTestMode) ...[
                const SizedBox(height: 8),
                Text(
                  'Submissions are online-only and unavailable in the local demo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _useFoodTracking,
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Skip for now and use food tracking'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _maskLicense(String license) {
    if (license.length <= 4) return license;
    return '••••${license.substring(license.length - 4)}';
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _SetupChecklist extends StatelessWidget {
  final bool credentialReady;

  const _SetupChecklist({required this.credentialReady});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 2 of 2 — Professional verification',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const _SetupStep(label: 'Account created', done: true),
            _SetupStep(
              label: 'Upload PRC ID and license details',
              done: credentialReady,
            ),
            const _SetupStep(
              label: 'Submit for admin verification',
              done: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final String label;
  final bool done;

  const _SetupStep({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: done ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;
  final VoidCallback? onDismiss;

  const _ApplicationMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42, color: color ?? AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                if (onDismiss != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('Cancel update'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your credential image is private and can only be viewed by you and the administrator reviewing your application. This is an admin review, not automatic PRC verification.',
            ),
          ),
        ],
      ),
    );
  }
}

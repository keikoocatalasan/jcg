import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/app/theme.dart';
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
  bool _isSubmitting = false;

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

    setState(() => _isSubmitting = true);
    try {
      await ref.read(nutritionistServiceProvider).submitApplication(
            credentialName: _credentialNameController.text,
            licenseNumber: _licenseNumberController.text,
            documentBytes: _credentialBytes!,
            mimeType: _credentialMimeType!,
            fileExtension: _credentialExtension!,
          );
      ref.invalidate(nutritionistApplicationProvider);
      if (mounted) {
        _showMessage('Application submitted for admin review.');
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

  @override
  Widget build(BuildContext context) {
    final applicationAsync = ref.watch(nutritionistApplicationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutritionist reviewer access'),
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
          if (application?.status == 'approved') {
            return const _ApplicationMessage(
              icon: Icons.verified_outlined,
              title: 'Application approved',
              message:
                  'You can now submit nutrition reviews on official food entries while online.',
              color: AppColors.success,
            );
          }
          if (application?.status == 'pending') {
            return _ApplicationMessage(
              icon: Icons.hourglass_top_rounded,
              title: 'Waiting for admin review',
              message:
                  'Your credential details were submitted on ${_date(application!.submittedAt)}. Food-review access will be enabled after approval.',
              color: AppColors.warning,
            );
          }
          if (application?.status == 'suspended') {
            return _ApplicationMessage(
              icon: Icons.block_outlined,
              title: 'Reviewer access paused',
              message: application!.reviewNote?.trim().isNotEmpty == true
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

  Widget _buildApplicationForm({
    required NutritionistApplication? rejectedApplication,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rejectedApplication != null) ...[
          _ApplicationMessage(
            icon: Icons.info_outline,
            title: 'Changes requested',
            message: rejectedApplication.reviewNote?.trim().isNotEmpty == true
                ? rejectedApplication.reviewNote!
                : 'Your previous submission was not approved. You may submit updated information.',
            color: AppColors.warning,
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply to review food information',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'An administrator will review the credential details you provide before enabling nutritionist feedback.',
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
                  labelText: 'License or registration number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'Enter the license or registration number.'
                    : null,
              ),
              const SizedBox(height: 12),
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
                        'JPG, PNG, or WebP · up to 5 MB',
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
            ],
          ),
        ),
      ],
    );
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ApplicationMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  const _ApplicationMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
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

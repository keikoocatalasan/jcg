import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: January 2025',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Information We Collect',
              'We collect information you provide directly, including:\n\n• Account information (email, nickname)\n• Profile data (age, height, weight, fitness goals)\n• Meal logs and food entries\n• Water and weight tracking data\n• Budget preferences\n• Allergy and dietary restriction information\n• Community posts and interactions\n• Device information for sync purposes',
            ),
            _buildSection(
              context,
              '2. How We Use Your Information',
              'We use your information to:\n\n• Provide personalized nutrition recommendations\n• Calculate your daily calorie and macro targets\n• Track your progress toward fitness goals\n• Enable offline functionality with sync\n• Improve the App\'s features and accuracy\n• Send important account notifications',
            ),
            _buildSection(
              context,
              '3. Data Storage and Security',
              'Your data is stored securely using industry-standard encryption. We use Supabase for backend services, which provides:\n\n• Encrypted data transmission (TLS/SSL)\n• Secure database storage\n• Row-level security policies\n• Regular security audits\n\nYour data is stored locally on your device for offline access and synced to our servers when connected.',
            ),
            _buildSection(
              context,
              '4. Data Sharing',
              'We do not sell or share your personal information with third parties except:\n\n• With your explicit consent\n• To comply with legal obligations\n• To protect our rights and safety\n• With service providers who assist in App operations (under strict confidentiality agreements)',
            ),
            _buildSection(
              context,
              '5. AI and Food Recognition',
              'When you use the AI food scanner feature:\n\n• Images are processed to identify food items\n• Images are not stored permanently after processing\n• Recognition results are used to suggest nutritional data\n• You can manually correct any识别 errors',
            ),
            _buildSection(
              context,
              '6. Community Features',
              'Content you post in community features is visible to other users. You can control visibility by:\n\n• Deleting your posts\n• Reporting inappropriate content\n• Choosing what to share',
            ),
            _buildSection(
              context,
              '7. Your Rights',
              'You have the right to:\n\n• Access your personal data\n• Correct inaccurate data\n• Delete your account and data\n• Export your data\n• Opt-out of non-essential data collection',
            ),
            _buildSection(
              context,
              '8. Children\'s Privacy',
              'The App is not intended for children under 13. We do not knowingly collect information from children under 13. If you are a parent or guardian and believe your child has provided us with information, please contact us.',
            ),
            _buildSection(
              context,
              '9. Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy in the App and updating the "Last updated" date.',
            ),
            _buildSection(
              context,
              '10. Contact Us',
              'If you have questions about this Privacy Policy, please contact us through the App\'s support features.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

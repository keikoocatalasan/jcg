import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
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
              '1. Acceptance of Terms',
              'By accessing and using JCG Fitness ("the App"), you accept and agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.',
            ),
            _buildSection(
              context,
              '2. Description of Service',
              'JCG Fitness is a budget-aware nutrition tracking application that provides food recommendations, calorie tracking, meal planning, and AI-powered nutrition assistance. The App is designed to help users make informed dietary choices within their budget.',
            ),
            _buildSection(
              context,
              '3. User Accounts',
              'You are responsible for maintaining the confidentiality of your account credentials. You agree to provide accurate and complete information during registration and to update such information as necessary. You must be at least 13 years old to create an account.',
            ),
            _buildSection(
              context,
              '4. Health Disclaimer',
              'The App provides general nutrition information and is not intended to be a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.',
            ),
            _buildSection(
              context,
              '5. Food Data Accuracy',
              'While we strive to provide accurate nutritional information, the food database may contain inaccuracies. Nutritional values are estimates and may vary based on preparation methods, portion sizes, and ingredient sources. Use this information as a guide, not as absolute truth.',
            ),
            _buildSection(
              context,
              '6. AI Recommendations',
              'AI-generated recommendations are based on algorithms and may not always be suitable for your specific needs. These recommendations should be used as suggestions only and do not replace professional nutritional advice.',
            ),
            _buildSection(
              context,
              '7. Budget Features',
              'The App allows you to set daily budget limits for food purchases. These budgets are for tracking purposes only and do not connect to any financial services. We are not responsible for any financial decisions made based on the App\'s suggestions.',
            ),
            _buildSection(
              context,
              '8. User Content',
              'You retain ownership of any content you create within the App, including meal logs, custom food entries, and community posts. By posting content in community features, you grant us a non-exclusive license to display and distribute such content within the App.',
            ),
            _buildSection(
              context,
              '9. Privacy',
              'Your use of the App is also governed by our Privacy Policy, which describes how we collect, use, and protect your personal information. Please review our Privacy Policy to understand our practices.',
            ),
            _buildSection(
              context,
              '10. Limitation of Liability',
              'To the maximum extent permitted by law, JCG Fitness shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the App.',
            ),
            _buildSection(
              context,
              '11. Changes to Terms',
              'We reserve the right to modify these Terms of Service at any time. Changes will be effective immediately upon posting. Your continued use of the App after changes constitutes acceptance of the modified terms.',
            ),
            _buildSection(
              context,
              '12. Contact Us',
              'If you have any questions about these Terms of Service, please contact us through the App\'s support features.',
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

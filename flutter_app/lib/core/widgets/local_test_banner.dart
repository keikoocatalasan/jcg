import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:jcg_fitness/app/theme.dart';

/// Visible guardrail for the compile-time local test build.
class LocalTestBanner extends StatelessWidget {
  const LocalTestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Material(
        color: AppColors.accentSoft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.science_outlined,
                  size: 18, color: AppColors.accentPrimary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'LOCAL QA  •  demo data only',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/admin'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

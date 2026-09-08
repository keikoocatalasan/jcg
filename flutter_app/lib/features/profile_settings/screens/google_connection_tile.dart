import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/errors/result.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

class GoogleConnectionTile extends ConsumerStatefulWidget {
  const GoogleConnectionTile({super.key});
  @override
  ConsumerState<GoogleConnectionTile> createState() =>
      _GoogleConnectionTileState();
}

class _GoogleConnectionTileState extends ConsumerState<GoogleConnectionTile> {
  bool _busy = false;

  Future<void> _connect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(authServiceProvider).connectGoogle();
      if (!mounted) return;
      final message = switch (result) {
        Success() =>
          'Google connected. Your existing account and logs are preserved.',
        Failure(:final error) => error.message,
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider)?.user;
    final connected =
        user?.identities?.any((identity) => identity.provider == 'google') ??
            false;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: const Icon(Icons.link),
        title: Text(connected ? 'Google connected' : 'Connect Google'),
        subtitle: Text(connected
            ? 'Google is linked to this JCG Fitness account.'
            : 'Connect the same verified email to keep your account and logs.'),
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                connected ? Icons.check_circle_outline : Icons.chevron_right),
        onTap: connected || _busy || user == null ? null : _connect,
      ),
    );
  }
}

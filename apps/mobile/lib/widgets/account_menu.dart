import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/voffer_repository.dart';
import '../models/app_user.dart';

/// App bar menu with Sign out and Delete account.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) {
        switch (action) {
          case _AccountAction.signOut:
            AppScope.read(context).signOut();
          case _AccountAction.delete:
            confirmDeleteAccount(context);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _AccountAction.signOut,
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _AccountAction.delete,
          child: ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

enum _AccountAction { signOut, delete }

/// Asks the user to confirm, then permanently deletes their account. On
/// success the app returns to the sign-in screen; on failure a snackbar
/// explains and the user stays signed in.
Future<void> confirmDeleteAccount(BuildContext context) async {
  final app = AppScope.read(context);
  final user = app.user;
  if (user == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final error = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteAccountDialog(app: app, user: user),
  );
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
  } else if (app.user == null) {
    // The root route already shows the sign-in screen; drop anything above.
    navigator.popUntil((route) => route.isFirst);
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.app, required this.user});

  final AppState app;
  final AppUser user;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _deleting = false;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    String? error;
    try {
      await widget.app.deleteAccount();
    } on RepositoryException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not delete your account. Please try again.';
    }
    if (mounted) Navigator.of(context).pop(error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final removed = widget.user.isFirm
        ? 'your shop, its offers and photos, its followers and alerts'
        : 'your profile, the shops you follow and your alerts';
    final kept = widget.user.isFirm
        ? 'Orders customers placed with you stay in their order history; '
              'any not yet redeemed are cancelled.'
        : 'Your past orders stay in the shops\' records, without your name.';
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
        title: const Text('Delete your account?'),
        content: Text(
          'This permanently deletes your account (${widget.user.email}), '
          '$removed. It can\'t be undone.\n\n$kept',
        ),
        actions: [
          TextButton(
            onPressed: _deleting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: _deleting ? null : _delete,
            child: _deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}

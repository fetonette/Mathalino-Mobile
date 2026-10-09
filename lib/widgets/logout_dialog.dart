import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/auth_service.dart';
import '../providers/diagnostic_provider.dart';
import '../providers/post_assessment_provider.dart';

/// Shows the "Log out?" confirmation and, if confirmed, logs out and returns
/// to the landing page. Identical behavior to the former header logout icon.
Future<void> confirmAndLogout(BuildContext context) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Log out?'),
      content: const Text('Are you sure you want to log out of Mathalino?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );

  if (shouldLogout != true || !context.mounted) return;

  try {
    context.read<DiagnosticProvider>().resetDiagnostic();
  } catch (_) {}
  try {
    context.read<PostAssessmentProvider>().reset();
  } catch (_) {}

  await context.read<AuthService>().logout();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
}

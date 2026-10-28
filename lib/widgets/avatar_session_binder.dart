import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/services/auth_service.dart';
import '../core/services/avatar_shop_service.dart';

/// Keeps [AvatarShopService] bound to the CURRENTLY authenticated student.
///
/// Sits above the whole navigator so the saved avatar is loaded as soon as the
/// student profile is available (app restart, login) - before any screen that
/// shows the avatar - and is cleared on logout. Binding is keyed on the
/// student uid only; later profile refreshes for the same student are no-ops
/// and can never overwrite the saved selection.
class AvatarSessionBinder extends StatefulWidget {
  final Widget child;
  final AvatarShopService? service;

  const AvatarSessionBinder({super.key, required this.child, this.service});

  @override
  State<AvatarSessionBinder> createState() => _AvatarSessionBinderState();
}

class _AvatarSessionBinderState extends State<AvatarSessionBinder> {
  AuthService? _auth;

  AvatarShopService get _service => widget.service ?? AvatarShopService.instance;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _auth!.addListener(_sync);
    scheduleMicrotask(_sync);
  }

  void _sync() {
    final profile = _auth?.studentProfile;
    unawaited(_service.syncSession(
      uid: profile?.uid,
      serverAvatarUrl: profile?.avatarUrl ?? '',
    ));
  }

  @override
  void dispose() {
    _auth?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


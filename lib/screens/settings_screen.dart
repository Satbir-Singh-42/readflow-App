import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/library_service.dart';
import '../services/tts_service.dart';
import '../services/user_account_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tts = TtsService();
  final _accountService = UserAccountService();
  bool _autoScroll = false;
  bool _keepScreenOn = true;
  bool _hapticFeedback = true;
  String _defaultLanguage = 'en-US';

  @override
  void initState() {
    super.initState();
    _accountService.addListener(_onAccountChange);
  }

  @override
  void dispose() {
    _accountService.removeListener(_onAccountChange);
    super.dispose();
  }

  void _onAccountChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Settings',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 20),

                  // Account Section
                  _AccountSection(
                    account: _accountService.account,
                    onSignIn: () => _showSignInSheet(context),
                    onEditProfile: () => _showEditProfileSheet(context),
                    onSignOut: _confirmSignOut,
                  ),
                  const SizedBox(height: 16),

                  // Pro card
                  if (!lib.isPro)
                    _ProCard(onUpgrade: () => _showProSheet(context, lib)),
                  if (lib.isPro) _ProBadge(),
                  const SizedBox(height: 24),

                  // Sync & Backup
                  _SectionCard(title: 'Sync & Backup', children: [
                    _SyncRow(
                      accountService: _accountService,
                      onSync: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final success = await _accountService.syncNow();
                        if (!context.mounted) return;
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Synced successfully'
                                : 'Sync failed'),
                            backgroundColor:
                                success ? AppTheme.success : AppTheme.error,
                          ),
                        );
                      },
                    ),
                    _SwitchRow(
                      label: 'Background sync',
                      subtitle: 'Sync automatically in background',
                      value: _accountService.backgroundSyncEnabled,
                      onChanged: (v) => _accountService.setBackgroundSync(v),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // TTS settings
                  _SectionCard(title: 'Text-to-speech', children: [
                    _SettingRow(
                      label: 'Language',
                      trailing: DropdownButton<String>(
                        value: _defaultLanguage,
                        dropdownColor: AppTheme.bgElevated,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                        items: _tts.availableLanguages
                            .map<DropdownMenuItem<String>>(
                                (l) => DropdownMenuItem<String>(
                                      value: l['code'] as String,
                                      child: Text(l['label'] as String),
                                    ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _defaultLanguage = v;
                              _tts.setLanguage(v);
                            });
                          }
                        },
                      ),
                    ),
                    _SettingRow(
                      label: 'Reading speed',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['0.75×', '1×', '1.25×', '1.5×'].map((s) {
                          final speed = double.parse(s.replaceAll('×', ''));
                          final sel = (_tts.speed - speed).abs() < 0.01;
                          return GestureDetector(
                            onTap: () {
                              setState(() {});
                              _tts.setSpeed(speed);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.primary
                                    : AppTheme.bgHighlight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(s,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.textSecondary)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Reading settings
                  _SectionCard(title: 'Reading', children: [
                    _SwitchRow(
                      label: 'Keep screen on',
                      subtitle: 'Prevent screen from sleeping',
                      value: _keepScreenOn,
                      onChanged: (v) => setState(() => _keepScreenOn = v),
                    ),
                    _SwitchRow(
                      label: 'Haptic feedback',
                      subtitle: 'Vibrate on page turn',
                      value: _hapticFeedback,
                      onChanged: (v) => setState(() => _hapticFeedback = v),
                    ),
                    _SwitchRow(
                      label: 'Auto scroll',
                      subtitle: 'Scroll automatically while reading',
                      value: _autoScroll,
                      onChanged: (v) => setState(() => _autoScroll = v),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Recycle Bin
                  _SectionCard(title: 'Storage', children: [
                    _TapRow(
                      label: 'Recycle Bin',
                      trailing: Text(
                        '${_accountService.recycleBin.length} items',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      onTap: () => _showRecycleBin(context),
                    ),
                    _TapRow(
                      label: 'Clear Cache',
                      onTap: () => _confirmClearCache(context),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // About
                  _SectionCard(title: 'About', children: [
                    const _SettingRow(
                        label: 'Version',
                        trailing: Text('1.0.0',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13))),
                    _TapRow(label: 'Privacy Policy', onTap: () {}),
                    _TapRow(label: 'Terms of Service', onTap: () {}),
                    _TapRow(label: 'Rate ReadFlow', onTap: () {}),
                    _TapRow(label: 'Send Feedback', onTap: () {}),
                  ]),
                  const SizedBox(height: 16),

                  // Danger Zone
                  if (_accountService.isLoggedIn)
                    _SectionCard(title: 'Danger Zone', children: [
                      _TapRow(
                        label: 'Delete Account',
                        textColor: AppTheme.error,
                        onTap: () => _confirmDeleteAccount(context),
                      ),
                    ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignInSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => _SignInSheet(
        onSignIn: (email, password) async {
          final success = await _accountService.signIn(email, password);
          if (!sheetContext.mounted) return;
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(
              content:
                  Text(success ? 'Signed in successfully' : 'Sign in failed'),
              backgroundColor: success ? AppTheme.success : AppTheme.error,
            ),
          );
        },
        onGoogleSignIn: () async {
          final success = await _accountService.signInWithGoogle();
          if (!sheetContext.mounted) return;
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(
              content: Text(
                  success ? 'Signed in with Google' : 'Google sign in failed'),
              backgroundColor: success ? AppTheme.success : AppTheme.error,
            ),
          );
        },
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    final nameController =
        TextEditingController(text: _accountService.account.name);
    final emailController =
        TextEditingController(text: _accountService.account.email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.textHint,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Edit Profile',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Save Changes',
              onTap: () async {
                final navigator = Navigator.of(context);
                await _accountService.updateProfile(
                  name: nameController.text,
                  email: emailController.text,
                );
                if (!context.mounted) return;
                navigator.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _accountService.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showRecycleBin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _RecycleBinSheet(
        accountService: _accountService,
        onRestore: (deletedDoc) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restored: ${deletedDoc.document.title}')),
          );
        },
      ),
    );
  }

  void _confirmClearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cache',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
            'This will clear temporary files. Your documents will not be affected.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account',
            style: TextStyle(color: AppTheme.error)),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              final success = await _accountService.deleteAccount();
              if (!context.mounted) return;
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                      success ? 'Account deleted' : 'Failed to delete account'),
                  backgroundColor: success ? AppTheme.warning : AppTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  void _showProSheet(BuildContext context, LibraryService lib) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ProSheet(onPurchase: () {
        lib.unlockPro();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Welcome to ReadFlow Pro!'),
              backgroundColor: AppTheme.primary),
        );
      }),
    );
  }
}

// ============================================================================
// ACCOUNT SECTION
// ============================================================================

class _AccountSection extends StatelessWidget {
  final UserAccount account;
  final VoidCallback onSignIn;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  const _AccountSection({
    required this.account,
    required this.onSignIn,
    required this.onEditProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    if (!account.isLoggedIn) {
      return _SignInCard(onSignIn: onSignIn);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: Text(
              account.name.isNotEmpty ? account.name[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  account.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppTheme.bgElevated,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            icon: const Icon(Icons.more_vert_rounded,
                color: AppTheme.textSecondary),
            onSelected: (value) {
              if (value == 'edit') onEditProfile();
              if (value == 'signout') onSignOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded,
                        color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Edit Profile',
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                    SizedBox(width: 12),
                    Text('Sign Out', style: TextStyle(color: AppTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignInCard({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSignIn,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.person_add_rounded, color: AppTheme.primary),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign in to sync',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Backup & sync across devices',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SIGN IN SHEET
// ============================================================================

class _SignInSheet extends StatefulWidget {
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function() onGoogleSignIn;

  const _SignInSheet({required this.onSignIn, required this.onGoogleSignIn});

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.textHint,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('Sign In',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Sync your reading across devices',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),

          // Google Sign In
          OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    await widget.onGoogleSignIn();
                    if (mounted) setState(() => _isLoading = false);
                  },
            icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.bgHighlight),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          const Row(
            children: [
              Expanded(child: Divider(color: AppTheme.bgHighlight)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('or',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
              ),
              Expanded(child: Divider(color: AppTheme.bgHighlight)),
            ],
          ),
          const SizedBox(height: 16),

          // Email
          TextField(
            controller: _emailController,
            style: const TextStyle(color: AppTheme.textPrimary),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: const TextStyle(color: AppTheme.textHint),
              filled: true,
              fillColor: AppTheme.bgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Password
          TextField(
            controller: _passwordController,
            style: const TextStyle(color: AppTheme.textPrimary),
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: const TextStyle(color: AppTheme.textHint),
              filled: true,
              fillColor: AppTheme.bgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sign In Button
          GradientButton(
            label: _isLoading ? 'Signing in...' : 'Sign In',
            onTap: _isLoading
                ? () {}
                : () async {
                    if (_emailController.text.isEmpty ||
                        _passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill in all fields')),
                      );
                      return;
                    }
                    setState(() => _isLoading = true);
                    await widget.onSignIn(
                        _emailController.text, _passwordController.text);
                    if (mounted) setState(() => _isLoading = false);
                  },
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: () {},
            child: const Text("Don't have an account? Sign up",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SYNC ROW
// ============================================================================

class _SyncRow extends StatelessWidget {
  final UserAccountService accountService;
  final VoidCallback onSync;

  const _SyncRow({required this.accountService, required this.onSync});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sync Status',
                  style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              Text(accountService.syncStatusText,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const Spacer(),
          if (accountService.isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            )
          else
            IconButton(
              onPressed: accountService.isLoggedIn ? onSync : null,
              icon: Icon(
                Icons.sync_rounded,
                color: accountService.isLoggedIn
                    ? AppTheme.primary
                    : AppTheme.textHint,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// RECYCLE BIN
// ============================================================================

class _RecycleBinSheet extends StatelessWidget {
  final UserAccountService accountService;
  final Function(DeletedDocument) onRestore;

  const _RecycleBinSheet(
      {required this.accountService, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final items = accountService.recycleBin;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Recycle Bin',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppTheme.bgElevated,
                          title: const Text('Empty Recycle Bin',
                              style: TextStyle(color: AppTheme.textPrimary)),
                          content: const Text('Permanently delete all items?',
                              style: TextStyle(color: AppTheme.textSecondary)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                accountService.emptyRecycleBin();
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.error),
                              child: const Text('Delete All'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Empty',
                        style: TextStyle(color: AppTheme.error)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: AppTheme.textHint, size: 48),
                        SizedBox(height: 12),
                        Text('Recycle bin is empty',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Icon(
                          item.document.type.name == 'pdf'
                              ? Icons.picture_as_pdf
                              : Icons.description,
                          color: AppTheme.textSecondary,
                        ),
                        title: Text(item.document.title,
                            style:
                                const TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text(
                            'Expires in ${item.daysUntilExpiry} days',
                            style: const TextStyle(
                                color: AppTheme.textHint, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore_rounded,
                                  color: AppTheme.success),
                              onPressed: () => onRestore(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_rounded,
                                  color: AppTheme.error),
                              onPressed: () {
                                accountService
                                    .permanentlyDelete(item.document.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXISTING WIDGETS (unchanged)
// ============================================================================

class _ProCard extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _ProCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C94FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PRO',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Upgrade to ReadFlow Pro',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Natural voices · Cloud import · Speed reading · No ads',
                style: TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Unlock for ₹149',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, color: AppTheme.primary, size: 28),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ReadFlow Pro',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text('All features unlocked',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProSheet extends StatelessWidget {
  final VoidCallback onPurchase;
  const _ProSheet({required this.onPurchase});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.textHint,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.auto_awesome_rounded,
              color: AppTheme.primary, size: 48),
          const SizedBox(height: 16),
          const Text('ReadFlow Pro',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('One-time payment · No subscription',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ...[
            ('Natural AI voices', 'Ultra-realistic text-to-speech voices'),
            ('Cloud import', 'Import from Google Drive & Dropbox'),
            ('Speed reading', 'RSVP mode — read at 600 wpm'),
            ('Highlights & notes', 'Annotate and export your notes'),
            ('No ads', 'Ad-free reading experience'),
            ('Folder organisation', 'Organise your library by genre'),
          ].map((f) => _Feature(title: f.$1, desc: f.$2)),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Unlock Pro — ₹149',
            onTap: onPurchase,
            icon: Icons.lock_open_rounded,
          ),
          const SizedBox(height: 12),
          const Text('One-time purchase, no recurring charges',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String title;
  final String desc;
  const _Feature({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.success, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children.map((c) {
              final idx = children.indexOf(c);
              return Column(
                children: [
                  c,
                  if (idx < children.length - 1)
                    const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppTheme.bgHighlight),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _SettingRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow(
      {required this.label,
      this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? textColor;
  const _TapRow(
      {required this.label,
      required this.onTap,
      this.trailing,
      this.textColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14, color: textColor ?? AppTheme.textPrimary)),
            const Spacer(),
            if (trailing != null) trailing!,
            if (trailing == null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

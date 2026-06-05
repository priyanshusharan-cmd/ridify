import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../core/socket_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('Admin Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.directions_car), text: 'Rides'),
            Tab(icon: Icon(Icons.verified_user), text: 'Verify'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DashboardTab(),
          _UsersTab(),
          _RidesTab(),
          _VerificationsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 1: DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════════

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _initSocket();
  }

  void _initSocket() {
    final socket = SocketService().socket;
    socket.on('all_rides_wiped', (_) {
      if (mounted) _fetchStats();
    });
  }

  Future<void> _fetchStats() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AdminService.getStats();
      if (mounted) setState(() { _stats = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final users = _stats!['users'] ?? {};
    final rides = _stats!['rides'] ?? {};

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Text(
              'Platform Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),

            // ── Stats Grid ────────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _StatCard(
                  icon: Icons.people,
                  label: 'Total Users',
                  value: '${users['total'] ?? 0}',
                  color: Colors.blue,
                  isDark: isDark,
                ),
                _StatCard(
                  icon: Icons.directions_car,
                  label: 'Total Rides',
                  value: '${rides['total'] ?? 0}',
                  color: Colors.green,
                  isDark: isDark,
                ),
                _StatCard(
                  icon: Icons.play_circle_fill,
                  label: 'Active Rides',
                  value: '${rides['active'] ?? 0}',
                  color: Colors.orange,
                  isDark: isDark,
                ),
                _StatCard(
                  icon: Icons.check_circle,
                  label: 'Completed',
                  value: '${rides['completed'] ?? 0}',
                  color: Colors.teal,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Ride Status Breakdown ─────────────────────────────────
            _SectionHeader(title: 'Ride Breakdown'),
            const SizedBox(height: 12),
            _StatusRow(label: 'Available', count: rides['available'] ?? 0, color: Colors.green),
            _StatusRow(label: 'Accepted', count: rides['accepted'] ?? 0, color: Colors.blue),
            _StatusRow(label: 'Full', count: rides['full'] ?? 0, color: Colors.purple),
            _StatusRow(label: 'Started', count: rides['started'] ?? 0, color: Colors.orange),
            _StatusRow(label: 'Completed', count: rides['completed'] ?? 0, color: Colors.teal),
            _StatusRow(label: 'Cancelled', count: rides['cancelled'] ?? 0, color: Colors.red),

            const SizedBox(height: 24),

            // ── Recent Users ──────────────────────────────────────────
            _SectionHeader(title: 'Recent Sign-ups'),
            const SizedBox(height: 12),
            if (users['recent'] != null)
              ...List<Widget>.from((users['recent'] as List).map((u) => Card(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        child: Text(
                          _getInitials(u['name'] ?? '?'),
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (u['verificationStatus'] == 'verified')
                        const Positioned(
                          bottom: -2,
                          right: -2,
                          child: Icon(Icons.verified, color: Colors.green, size: 16),
                        ),
                    ],
                  ),
                  title: Text(
                    u['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  subtitle: Text(
                    u['email'] ?? '',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                  ),
                  trailing: Text(
                    _formatDate(u['createdAt']),
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11),
                  ),
                ),
              ))),
            
            const SizedBox(height: 24),

            // ── System Actions ─────────────────────────────────────────
            _SectionHeader(title: 'System Actions'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepOrange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => _adminWipeAllUsers(context),
                      icon: const Icon(Icons.group_off, color: Colors.deepOrange),
                      label: const Text(
                        "Wipe Users",
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => _adminWipeAllRides(context),
                      icon: const Icon(Icons.car_crash, color: Colors.red),
                      label: const Text(
                        "Wipe Rides",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _adminWipeAllUsers(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '⚠️ Delete ALL Users',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: const Text(
          'This permanently deletes every user account and all associated ride data EXCEPT your admin account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Delete All Others',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final adminEmail = prefs.getString('email') ?? '';
      await AuthService.adminDeleteAllUsers(adminEmail);
      if (!context.mounted) return;
      
      _fetchStats();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All other users deleted.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _adminWipeAllRides(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '⚠️ Delete ALL Rides',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: const Text(
          'This permanently deletes every ride from the database.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Delete All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AdminService.wipeAllRides();
      _fetchStats();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All rides deleted successfully.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 2: USERS
// ═══════════════════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> with AutomaticKeepAliveClientMixin {
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isSelecting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AdminService.getAllUsers(
        search: _searchController.text.trim(),
        page: page,
      );
      if (mounted) {
        setState(() {
          _users = data['users'] ?? [];
          final pagination = data['pagination'] ?? {};
          _page = pagination['page'] ?? 1;
          _totalPages = pagination['pages'] ?? 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(id);
        _isSelecting = true;
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Delete Users', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete ${_selectedIds.length} selected user(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AdminService.bulkDeleteUsers(_selectedIds.toList());
      _selectedIds.clear();
      _isSelecting = false;
      _fetchUsers(page: _page);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Users deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteUser(String id, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete user "$email"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AdminService.deleteUser(id);
      _fetchUsers(page: _page);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $email deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateUserDialog() {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final ageC = TextEditingController();
    final passC = TextEditingController();
    bool obscure = true;
    bool creating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.amber),
              SizedBox(width: 8),
              Text('Create User', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withAlpha(76)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No email verification required',
                          style: TextStyle(fontSize: 12, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailC,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageC,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passC,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2C)
                    : Colors.black,
              ),
              onPressed: creating
                  ? null
                  : () async {
                      if (nameC.text.trim().isEmpty || emailC.text.trim().isEmpty || passC.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name, email, and password are required'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (passC.text.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 8 characters'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      setDialogState(() => creating = true);
                      try {
                        await AdminService.createUser(
                          name: nameC.text.trim(),
                          email: emailC.text.trim(),
                          password: passC.text,
                          age: ageC.text.trim().isNotEmpty ? ageC.text.trim() : null,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchUsers();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User created successfully!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => creating = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: creating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> initialUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Map<String, dynamic> user = Map.from(initialUser);
    bool isEditing = false;
    bool isSaving = false;
    final nameCtrl = TextEditingController(text: user['name'] ?? '');
    final ageCtrl = TextEditingController(text: user['age'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 40), // Balance the edit button
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        child: Text(
                          _getInitials(user['name'] ?? '?'),
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(isEditing ? Icons.close : Icons.edit, color: Colors.blue),
                        onPressed: () {
                          setModalState(() {
                            if (isEditing) {
                              isEditing = false;
                              nameCtrl.text = user['name'] ?? '';
                              ageCtrl.text = user['age'] ?? '';
                            } else {
                              isEditing = true;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isEditing)
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    )
                  else
                    Text(
                      user['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? '',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  
                  if (isEditing)
                    TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                    )
                  else
                    _DetailRow(icon: Icons.cake_outlined, label: 'Age', value: user['age'] ?? 'N/A'),
                    
                  if (!isEditing) ...[
                    _DetailRow(icon: Icons.calendar_today, label: 'Joined', value: _formatDate(user['createdAt'])),
                    _DetailRow(icon: Icons.fingerprint, label: 'ID', value: user['_id'] ?? ''),
                    
                    if (user['verificationStatus'] != null && user['verificationStatus'] != 'none')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user, color: user['verificationStatus'] == 'verified' ? Colors.green : Colors.orange, size: 20),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                user['verificationStatus'] == 'verified' ? 'Account Verified' : 'Verification Pending',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: user['verificationStatus'] == 'verified' ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                    if (user['idUrl'] != null && user['idUrl'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () async {
                            final Uri url = Uri.parse(user['idUrl']);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
                              }
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.image, color: Colors.blue, size: 20),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'View ID Document',
                                  style: TextStyle(fontSize: 15, color: Colors.blue, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  if (isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  final result = await AdminService.updateUser(
                                    user['_id'],
                                    name: nameCtrl.text.trim(),
                                    age: ageCtrl.text.trim(),
                                  );
                                  setModalState(() {
                                    isSaving = false;
                                    isEditing = false;
                                    user = result['user'];
                                  });
                                  _fetchUsers();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('User updated!'), backgroundColor: Colors.green),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    Row(
                      children: [
                        if (user['verificationStatus'] == 'verified') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orange),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Revoke Verification', style: TextStyle(fontWeight: FontWeight.bold)),
                                    content: const Text('Are you sure you want to revoke verification for this user?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Revoke', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  Navigator.pop(ctx);
                                  try {
                                    await AdminService.rejectVerification(user['_id']);
                                    _fetchUsers();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Verification revoked.'), backgroundColor: Colors.green),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(Icons.verified_user_outlined, color: Colors.orange),
                              label: const Text('Revoke', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _deleteUser(user['_id'], user['email']);
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        backgroundColor: Colors.amber,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
        // ── Search Bar ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _fetchUsers();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onSubmitted: (_) => _fetchUsers(),
                ),
              ),
              if (_isSelecting) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  tooltip: 'Delete selected',
                  onPressed: _bulkDelete,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel selection',
                  onPressed: () {
                    setState(() {
                      _selectedIds.clear();
                      _isSelecting = false;
                    });
                  },
                ),
              ],
            ],
          ),
        ),

        if (_isSelecting)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        // ── User List ─────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: () => _fetchUsers(), child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _users.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () => _fetchUsers(page: _page),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_outline, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No users found',
                                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchUsers(page: _page),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _users.length + 1, // +1 for pagination
                            itemBuilder: (context, index) {
                              if (index == _users.length) {
                                // Pagination controls
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: _page > 1 ? () => _fetchUsers(page: _page - 1) : null,
                                      ),
                                      Text(
                                        'Page $_page of $_totalPages',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: _page < _totalPages ? () => _fetchUsers(page: _page + 1) : null,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final user = _users[index];
                              final id = user['_id']?.toString() ?? '';
                              final isSelected = _selectedIds.contains(id);

                              return Card(
                                color: isSelected
                                    ? (isDark ? Colors.amber.withAlpha(38) : Colors.amber.withAlpha(25))
                                    : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isSelected
                                      ? const BorderSide(color: Colors.amber, width: 1.5)
                                      : BorderSide.none,
                                ),
                                child: ListTile(
                                  leading: _isSelecting
                                      ? Checkbox(
                                          value: isSelected,
                                          activeColor: Colors.amber,
                                          onChanged: (_) => _toggleSelection(id),
                                        )
                                      : Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: isDark ? Colors.white : Colors.black,
                                              child: Text(
                                                _getInitials(user['name'] ?? '?'),
                                                style: TextStyle(
                                                  color: isDark ? Colors.black : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (user['verificationStatus'] == 'verified')
                                              const Positioned(
                                                bottom: -2,
                                                right: -2,
                                                child: Icon(Icons.verified, color: Colors.green, size: 16),
                                              ),
                                          ],
                                        ),
                                  title: Text(
                                    user['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  subtitle: Text(
                                    user['email'] ?? '',
                                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                                  ),
                                  trailing: Text(
                                    _formatDate(user['createdAt']),
                                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11),
                                  ),
                                  onTap: () => _isSelecting ? _toggleSelection(id) : _showUserDetails(user),
                                  onLongPress: () => _toggleSelection(id),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 3: RIDES
// ═══════════════════════════════════════════════════════════════════════════════

class _RidesTab extends StatefulWidget {
  const _RidesTab();

  @override
  State<_RidesTab> createState() => _RidesTabState();
}

class _RidesTabState extends State<_RidesTab> with AutomaticKeepAliveClientMixin {
  List<dynamic> _rides = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String? _statusFilter;
  
  final TextEditingController _searchController = TextEditingController();

  final List<String?> _filters = [null, 'available', 'accepted', 'started', 'completed', 'cancelled'];
  final List<String> _filterLabels = ['All', 'Available', 'Accepted', 'Started', 'Completed', 'Cancelled'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchRides();
    _initSocket();
  }

  void _initSocket() {
    final socket = SocketService().socket;
    socket.on('all_rides_wiped', (_) {
      if (mounted) _fetchRides(page: 1);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRides({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final query = _searchController.text.trim();
      final data = await AdminService.getAllRides(status: _statusFilter, driverEmail: query.isNotEmpty ? query : null, page: page);
      if (mounted) {
        setState(() {
          _rides = data['rides'] ?? [];
          final pagination = data['pagination'] ?? {};
          _page = pagination['page'] ?? 1;
          _totalPages = pagination['pages'] ?? 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _deleteRide(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ride', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Permanently delete this ride? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AdminService.deleteRide(id);
      _fetchRides(page: _page);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _forceCancelRide(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force Cancel Ride', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Force cancel this ride? All pending requests will be declined.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Force Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AdminService.forceCancelRide(id);
      _fetchRides(page: _page);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride force-cancelled'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDateWithTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showRideDetails(Map<String, dynamic> ride) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = ride['status'] ?? 'unknown';
    final canCancel = !['completed', 'cancelled'].contains(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  'Ride Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const Spacer(),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(icon: Icons.person, label: 'Driver', value: ride['riderName'] ?? ride['riderEmail'] ?? 'Unknown'),
                    _DetailRow(icon: Icons.email_outlined, label: 'Email', value: ride['riderEmail'] ?? ''),
                    _DetailRow(icon: Icons.location_on, label: 'Pickup', value: ride['pickupLocation'] ?? ''),
                    _DetailRow(icon: Icons.flag, label: 'Destination', value: ride['destination'] ?? ''),
                    _DetailRow(icon: Icons.directions_car, label: 'Vehicle', value: ride['vehicleType'] ?? ''),
                    _DetailRow(
                      icon: Icons.currency_rupee,
                      label: 'Fare',
                      value: '₹${ride['fare'] ?? 0}',
                    ),
                    _DetailRow(
                      icon: Icons.airline_seat_recline_normal,
                      label: 'Seats',
                      value: '${ride['availableSeats'] ?? ride['totalSeats'] ?? '-'} / ${ride['totalSeats'] ?? '-'}',
                    ),
                    _DetailRow(icon: Icons.schedule, label: 'Departure', value: ride['departureTime'] ?? 'N/A'),
                    
                    const SizedBox(height: 24),
                    if ((ride['passengers'] as List?)?.isNotEmpty == true || (ride['droppedPassengers'] as List?)?.isNotEmpty == true) ...[
                      const Text('Passengers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...((ride['passengers'] as List?) ?? []).map((email) {
                        final details = (ride['riderDetails'] as Map?)?[email] as Map?;
                        final hasPaid = details?['paid'] == true;
                        final fare = details?['fare'] ?? '?';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${details?['riderName'] ?? 'Unknown'} ($email)', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Pickup: ${details?['pickupLocation'] ?? '?'}', style: const TextStyle(fontSize: 12)),
                              Text('Drop: ${details?['destination'] ?? '?'}', style: const TextStyle(fontSize: 12)),
                              Text('Fare: ₹$fare | Status: ${hasPaid ? "Paid" : "Pending"}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasPaid ? Colors.green : Colors.orange)),
                            ],
                          ),
                        );
                      }),
                      ...((ride['droppedPassengers'] as List?) ?? []).map((email) {
                        final details = (ride['riderDetails'] as Map?)?[email] as Map?;
                        final hasPaid = details?['paid'] == true;
                        final fare = details?['fare'] ?? '?';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withAlpha(100)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${details?['riderName'] ?? 'Unknown'} ($email) - Dropped', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              const SizedBox(height: 4),
                              Text('Pickup: ${details?['pickupLocation'] ?? '?'}', style: const TextStyle(fontSize: 12)),
                              Text('Drop: ${details?['destination'] ?? '?'}', style: const TextStyle(fontSize: 12)),
                              Text('Fare: ₹$fare | Status: ${hasPaid ? "Paid" : "Pending"}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasPaid ? Colors.green : Colors.orange)),
                              if (details?['droppedAt'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Dropped at: ${_formatDateWithTime(details!['droppedAt'])}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],

                    if ((ride['kicked'] as List?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      const Text('Kicked Passengers', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...((ride['kicked'] as List?) ?? []).map((email) {
                        final details = (ride['riderDetails'] as Map?)?[email] as Map?;
                        final hasPaid = details?['paid'] == true;
                        final fare = details?['fare'] ?? '?';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withAlpha(100)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${details?['riderName'] ?? 'Unknown'} ($email)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              const SizedBox(height: 4),
                              Text('Pickup: ${details?['pickupLocation'] ?? '?'}', style: const TextStyle(fontSize: 12)),
                              Text('Drop: ${details?['destination'] ?? '?'}', style: const TextStyle(fontSize: 12)),
                              Text('Fare: ₹$fare | Status: ${hasPaid ? "Paid (Refunded?)" : "Pending"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                              if (details?['kickedAt'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Kicked at: ${_formatDateWithTime(details!['kickedAt'])}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500)),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (canCancel)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _forceCancelRide(ride['_id']);
                      },
                      icon: const Icon(Icons.cancel, color: Colors.orange),
                      label: const Text('Cancel', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (canCancel) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteRide(ride['_id']);
                    },
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Search Bar ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by driver email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _fetchRides();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onSubmitted: (_) => _fetchRides(),
                ),
              ),
            ],
          ),
        ),

        // ── Filter Chips ──────────────────────────────────────────
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final isSelected = _statusFilter == _filters[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(_filterLabels[index]),
                  selectedColor: Colors.amber.withAlpha(51),
                  checkmarkColor: Colors.amber,
                  backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.amber : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: isSelected ? const BorderSide(color: Colors.amber) : BorderSide.none,
                  onSelected: (_) {
                    setState(() => _statusFilter = _filters[index]);
                    _fetchRides();
                  },
                ),
              );
            },
          ),
        ),

        // ── Ride List ─────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: () => _fetchRides(), child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _rides.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () => _fetchRides(page: _page),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.directions_car_filled, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No rides found',
                                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchRides(page: _page),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _rides.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _rides.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: _page > 1 ? () => _fetchRides(page: _page - 1) : null,
                                      ),
                                      Text(
                                        'Page $_page of $_totalPages',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: _page < _totalPages ? () => _fetchRides(page: _page + 1) : null,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final ride = _rides[index];
                              final status = ride['status'] ?? 'unknown';

                              return Dismissible(
                                key: Key(ride['_id'].toString()),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  await _deleteRide(ride['_id']);
                                  return false; // We handle removal via refresh
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                child: Card(
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: _VehicleIcon(vehicleType: ride['vehicleType'] ?? 'Sedan'),
                                    title: Text(
                                      '${ride['pickupLocation'] ?? '?'} → ${ride['destination'] ?? '?'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          ride['riderEmail'] ?? '',
                                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            _StatusChip(status: status),
                                            const SizedBox(width: 8),
                                            Text(
                                              '₹${ride['fare'] ?? 0}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showRideDetails(ride),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(76), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatusRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _color {
    switch (status) {
      case 'available': return Colors.green;
      case 'accepted': return Colors.blue;
      case 'full': return Colors.purple;
      case 'started': return Colors.orange;
      case 'completed': return Colors.teal;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withAlpha(127)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _VehicleIcon extends StatelessWidget {
  final String vehicleType;
  const _VehicleIcon({required this.vehicleType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    IconData icon;
    switch (vehicleType) {
      case 'Bike':
        icon = Icons.two_wheeler;
        break;
      case 'SUV':
        icon = Icons.airport_shuttle;
        break;
      default:
        icon = Icons.directions_car;
    }
    return CircleAvatar(
      backgroundColor: isDark ? Colors.white12 : Colors.black12,
      child: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 4: VERIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════════

class _VerificationsTab extends StatefulWidget {
  const _VerificationsTab();
  @override
  State<_VerificationsTab> createState() => _VerificationsTabState();
}

class _VerificationsTabState extends State<_VerificationsTab> with AutomaticKeepAliveClientMixin {
  List<dynamic> _pendingUsers = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await AdminService.getPendingVerifications();
      if (mounted) setState(() { _pendingUsers = users; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _approve(String userId) async {
    try {
      await AdminService.approveVerification(userId);
      _fetchPending();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User verified!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject(String userId) async {
    try {
      await AdminService.rejectVerification(userId);
      _fetchPending();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification rejected.'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  void _viewIdImage(String? idUrl) {
    if (idUrl == null || idUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No ID image available'), backgroundColor: Colors.orange));
      return;
    }
    // Open Drive URL in browser
    launchUrl(Uri.parse(idUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _fetchPending, child: const Text('Retry')),
      ]));
    }

    if (_pendingUsers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchPending,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified, size: 64, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 12),
              Text('No pending verifications', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
            ])),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPending,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _pendingUsers.length,
        itemBuilder: (context, index) {
          final user = _pendingUsers[index];
          return Card(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      child: Text(
                        (user['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                        style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                      Text(user['email'] ?? '', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.withAlpha(38), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Pending', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // View ID button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _viewIdImage(user['idUrl']),
                      icon: const Icon(Icons.image, size: 18),
                      label: const Text('View ID Document'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _reject(user['_id']),
                        child: const Text('Reject', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _approve(user['_id']),
                        child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


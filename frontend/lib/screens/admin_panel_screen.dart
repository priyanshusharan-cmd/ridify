import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

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
    _tabController = TabController(length: 6, vsync: this);
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
          isScrollable: true,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.directions_car), text: 'Rides'),
            Tab(icon: Icon(Icons.local_offer), text: 'Promos'),
            Tab(icon: Icon(Icons.settings), text: 'Config'),
            Tab(icon: Icon(Icons.support_agent), text: 'Support'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DashboardTab(),
          _UsersTab(),
          _RidesTab(),
          _PromosTab(),
          _ConfigTab(),
          _SupportTab(),
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
                  leading: CircleAvatar(
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
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.deepOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () => _adminWipeAllUsers(context),
                icon: const Icon(Icons.delete_sweep, color: Colors.deepOrange),
                label: const Text(
                  "Wipe All Users",
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
          'This permanently deletes every user account and all associated ride data.\n\nYou will be logged out immediately after.',
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
      final prefs = await SharedPreferences.getInstance();
      final adminEmail = prefs.getString('email') ?? '';
      await AuthService.adminDeleteAllUsers(adminEmail);
      await prefs.clear(); // Auto-logout
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
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

  void _showUserDetails(Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 16),
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
            _DetailRow(icon: Icons.cake_outlined, label: 'Age', value: user['age'] ?? 'N/A'),
            _DetailRow(icon: Icons.calendar_today, label: 'Joined', value: _formatDate(user['createdAt'])),
            _DetailRow(icon: Icons.fingerprint, label: 'ID', value: user['_id'] ?? ''),
            const SizedBox(height: 24),
            Row(
              children: [
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
                      ? Center(
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
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchUsers(page: _page),
                          child: ListView.builder(
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
                                      : CircleAvatar(
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

  final List<String?> _filters = [null, 'available', 'accepted', 'started', 'completed', 'cancelled'];
  final List<String> _filterLabels = ['All', 'Available', 'Accepted', 'Started', 'Completed', 'Cancelled'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AdminService.getAllRides(status: _statusFilter, page: page);
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

  void _showRideDetails(Map<String, dynamic> ride) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = ride['status'] ?? 'unknown';
    final canCancel = !['completed', 'cancelled'].contains(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            _DetailRow(
              icon: Icons.people,
              label: 'Passengers',
              value: '${(ride['passengers'] as List?)?.length ?? 0}',
            ),
            _DetailRow(icon: Icons.schedule, label: 'Departure', value: ride['departureTime'] ?? 'N/A'),
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
                      ? Center(
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
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchRides(page: _page),
                          child: ListView.builder(
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
        crossAxisAlignment: CrossAxisAlignment.start,
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

class _PromosTab extends StatefulWidget {
  const _PromosTab();
  @override
  State<_PromosTab> createState() => _PromosTabState();
}

class _PromosTabState extends State<_PromosTab> with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  List<dynamic> promos = [];
  String error = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchPromos();
  }

  Future<void> _fetchPromos() async {
    try {
      setState(() { isLoading = true; error = ''; });
      final data = await AdminService.getPromos();
      if (mounted) setState(() { promos = data; isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); isLoading = false; });
    }
  }

  Future<void> _createPromo() async {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Promo Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code (e.g. SUMMER50)')),
            TextField(controller: discountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount %')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await AdminService.createPromo(codeCtrl.text.trim(), num.parse(discountCtrl.text));
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) _fetchPromos();
  }

  Future<void> _deletePromo(String id) async {
    try {
      await AdminService.deletePromo(id);
      _fetchPromos();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (error.isNotEmpty) return Center(child: Text(error, style: const TextStyle(color: Colors.red)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _createPromo,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: promos.length,
        itemBuilder: (context, index) {
          final p = promos[index];
          return Card(
            child: ListTile(
              title: Text(p['code'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Discount: ${p['discountPercentage']}% | Used: ${p['usageCount']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deletePromo(p['_id']),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConfigTab extends StatefulWidget {
  const _ConfigTab();
  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  String error = '';
  num commission = 10;
  num surge = 1.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      setState(() { isLoading = true; error = ''; });
      final data = await AdminService.getSettings();
      for (var s in data) {
        if (s['key'] == 'commission_rate') commission = s['value'];
        if (s['key'] == 'surge_multiplier') surge = s['value'];
      }
      if (mounted) setState(() { isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); isLoading = false; });
    }
  }

  Future<void> _updateCommission(num val) async {
    try {
      await AdminService.updateCommission(val);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commission updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _updateSurge(num val) async {
    try {
      await AdminService.updateSurge(val);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Surge updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (error.isNotEmpty) return Center(child: Text(error, style: const TextStyle(color: Colors.red)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Platform Commission (%)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Slider(
                  value: commission.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 50,
                  label: commission.toString(),
                  onChanged: (v) => setState(() => commission = v),
                  onChangeEnd: (v) => _updateCommission(v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Surge Multiplier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Slider(
                  value: surge.toDouble(),
                  min: 1.0,
                  max: 5.0,
                  divisions: 40,
                  label: surge.toStringAsFixed(1),
                  onChanged: (v) => setState(() => surge = v),
                  onChangeEnd: (v) => _updateSurge(v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportTab extends StatefulWidget {
  const _SupportTab();
  @override
  State<_SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<_SupportTab> with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  String error = '';
  List<dynamic> disputes = [];
  List<dynamic> sosAlerts = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchSupportData();
  }

  Future<void> _fetchSupportData() async {
    try {
      setState(() { isLoading = true; error = ''; });
      final d = await AdminService.getDisputes();
      final s = await AdminService.getSOSAlerts();
      if (mounted) setState(() { disputes = d; sosAlerts = s; isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); isLoading = false; });
    }
  }

  Future<void> _resolveDispute(String id) async {
    try {
      await AdminService.resolveDispute(id);
      _fetchSupportData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (error.isNotEmpty) return Center(child: Text(error, style: const TextStyle(color: Colors.red)));

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Disputes'),
              Tab(text: 'SOS Alerts'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: disputes.length,
                  itemBuilder: (ctx, i) {
                    final d = disputes[i];
                    return Card(
                      child: ListTile(
                        title: Text('Ride: ${d['rideId'] ?? 'N/A'}'),
                        subtitle: Text('Reporter: ${d['reporterEmail']}\nReason: ${d['reason']}'),
                        trailing: d['status'] == 'open'
                            ? TextButton(onPressed: () => _resolveDispute(d['_id']), child: const Text('Resolve'))
                            : const Text('Resolved', style: TextStyle(color: Colors.green)),
                      ),
                    );
                  },
                ),
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sosAlerts.length,
                  itemBuilder: (ctx, i) {
                    final s = sosAlerts[i];
                    return Card(
                      color: s['status'] == 'active' ? Colors.red.withAlpha(50) : null,
                      child: ListTile(
                        title: Text('User: ${s['userEmail']}'),
                        subtitle: Text('Location: ${s['location']['lat']}, ${s['location']['lng']}'),
                        trailing: Text(s['status'].toUpperCase(), style: TextStyle(color: s['status'] == 'active' ? Colors.red : Colors.green)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

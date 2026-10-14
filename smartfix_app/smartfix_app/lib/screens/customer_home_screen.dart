import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'service_detail_screen.dart';
import 'booking_screen.dart';
import 'my_bookings_screen.dart';
import 'login_screen.dart';
import 'chatbot_screen.dart';
import 'customer_complaints_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _ExploreServicesTab(),
          MyBookingsScreen(),
          _CustomerProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: 'Services'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'My Bookings'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _ExploreServicesTab extends StatefulWidget {
  const _ExploreServicesTab();

  @override
  State<_ExploreServicesTab> createState() => _ExploreServicesTabState();
}

class _ExploreServicesTabState extends State<_ExploreServicesTab> {
  final ApiService _api = ApiService();
  late Future<List<ServiceItem>> _servicesFuture;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Gardening',
    'Pest Control',
    'Appliance',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _servicesFuture = _api.getServices();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _servicesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final username = auth.profile?.username ?? 'Customer';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $username', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Make home feel effortless', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF161A1D),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatbotScreen()),
            ),
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Need Help?'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF2C3E50),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // Search Bar
            SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: _buildHeroBanner(theme),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                      hintText: 'What does your home need today?',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
              ),
            ),

            // Horizontal Category Selector
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        avatar: Icon(_getCategoryIcon(cat), size: 16),
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFFD6D2),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade200),
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // Services List
            FutureBuilder<List<ServiceItem>>(
              future: _servicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          Text('Failed to load services: ${snapshot.error}'),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  );
                }

                var services = snapshot.data ?? [];

                if (_selectedCategory != 'All') {
                  services = services.where((s) => s.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  services = services.where((s) {
                    return s.name.toLowerCase().contains(_searchQuery) ||
                        s.category.toLowerCase().contains(_searchQuery) ||
                        s.description.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (services.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No services found.')),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final service = services[index];
                        return _buildServiceCard(service);
                      },
                      childCount: services.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(ThemeData theme) {
    return Container(
      height: 178,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF161A1D),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?auto=format&fit=crop&w=1200&q=85'),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x24123B47), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xF2161A1D), Color(0xB2161A1D), Color(0x18161A1D)],
            stops: [0, .58, 1],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFFFD6D2), borderRadius: BorderRadius.circular(30)),
              child: const Text('SMART SERVICES. SMARTER LIVING.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9D1F24))),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 230,
              child: Text('Everything your home needs, in one place.', style: TextStyle(color: Colors.white, fontSize: 23, height: 1.08, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            const Text('Trusted pros. Clear prices. Easy booking.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(ServiceItem service) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: service)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  _imageForCategory(service.category),
                  width: 92,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 92,
                    height: 112,
                    color: const Color(0xFFFFE9E6),
                    child: Icon(_getCategoryIcon(service.category), color: const Color(0xFFE33434), size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF19333A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${service.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE33434)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE33434),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => BookingScreen(service: service)),
                            );
                          },
                          child: const Text('Book now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _imageForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?auto=format&fit=crop&w=500&q=80';
      case 'electrical':
        return 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=500&q=80';
      case 'cleaning':
        return 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=500&q=80';
      case 'gardening':
        return 'https://images.unsplash.com/photo-1558904541-efa843a96f01?auto=format&fit=crop&w=500&q=80';
      case 'pest control':
        return 'https://images.unsplash.com/photo-1585832770485-e68a5dbfad52?auto=format&fit=crop&w=500&q=80';
      case 'appliance':
        return 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=500&q=80';
      default:
        return 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=500&q=80';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electric_bolt;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'gardening':
        return Icons.yard;
      case 'pest control':
        return Icons.pest_control;
      case 'appliance':
        return Icons.microwave;
      default:
        return Icons.handyman;
    }
  }
}

class _CustomerProfileTab extends StatelessWidget {
  const _CustomerProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.blueAccent.shade100,
              child: const Icon(Icons.person, size: 42, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              profile?.username ?? 'Customer',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              profile?.email ?? 'customer@smartfix.com',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone, color: Colors.blueAccent),
                  title: const Text('Phone Number'),
                  subtitle: Text(profile?.phone?.isNotEmpty == true ? profile!.phone! : 'Not provided'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.badge, color: Colors.blueAccent),
                  title: Text('Account Role'),
                  subtitle: Text('Customer'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent, color: Color(0xFFE33434)),
                  title: const Text('My Complaints & Issues'),
                  subtitle: const Text('View and track your submitted complaints'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CustomerComplaintsScreen()),
                    );
                  },
                ),


              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
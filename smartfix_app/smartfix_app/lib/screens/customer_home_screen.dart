import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'service_detail_screen.dart';
import 'booking_screen.dart';
import 'my_bookings_screen.dart';
import 'login_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $username 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('SmartFix Home Maintenance Services', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
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
                padding: const EdgeInsets.all(14.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search plumbing, electrical, cleaning...',
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
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
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
                        selectedColor: Colors.blueAccent.shade100,
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
                  padding: const EdgeInsets.all(12),
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

  Widget _buildServiceCard(ServiceItem service) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: service)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getCategoryIcon(service.category), color: Colors.blueAccent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${service.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => BookingScreen(service: service)),
                            );
                          },
                          child: const Text('Book Now'),
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
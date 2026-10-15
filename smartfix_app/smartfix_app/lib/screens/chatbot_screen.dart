import 'package:flutter/material.dart';
import '../models/service.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_widgets.dart';
import 'booking_screen.dart';
import 'my_bookings_screen.dart';
import 'customer_complaints_screen.dart';

class ChatbotScreen extends StatefulWidget {
  final Future<List<ServiceItem>>? servicesFuture;
  final Future<List<AppUser>>? workersFuture;

  const ChatbotScreen({super.key, this.servicesFuture, this.workersFuture});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final Widget? actionWidget;

  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.actionWidget,
  });
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Tell me what needs fixing at home. I will suggest the right service and show who is available.',
      fromUser: false,
    ),
  ];
  late Future<List<ServiceItem>> _servicesFuture;
  late Future<List<AppUser>> _workersFuture;
  String _lastUserQuery = '';

  static const _quickQuestions = [
    'I have a leaking tap',
    'My fan is not working',
    'I need home cleaning',
    'Who is available now?',
    'How do I track my worker?',
    'How do I report an issue?',
  ];

  @override
  void initState() {
    super.initState();
    _servicesFuture = widget.servicesFuture ?? _api.getServices();
    _workersFuture = widget.workersFuture ?? _api.getAvailableWorkers();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? suggestedMessage]) {
    final text = (suggestedMessage ?? _messageController.text).trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _lastUserQuery = text;
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _messages.add(_replyMessageFor(text));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  _ChatMessage _replyMessageFor(String question) {
    final normalized = question.toLowerCase();

    // 1. Tracking queries
    if (normalized.contains('track') || normalized.contains('status') || normalized.contains('where is') || normalized.contains('eta') || normalized.contains('worker location')) {
      return _ChatMessage(
        text: 'You can track your assigned worker in real time! Go to My Bookings and tap "Track Worker" on any active service.',
        fromUser: false,
        actionWidget: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.location_on, size: 16),
            label: const Text('Go to My Bookings & Track'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
              );
            },
          ),
        ),
      );
    }

    // 2. Complaint / Issue queries
    if (normalized.contains('complain') || normalized.contains('issue') || normalized.contains('problem') || normalized.contains('report') || normalized.contains('refund') || normalized.contains('bad service')) {
      return _ChatMessage(
        text: 'If you faced an issue with your service, you can file a complaint directly. Our support team reviews all complaints and provides solutions.',
        fromUser: false,
        actionWidget: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.report_problem, size: 16),
            label: const Text('View or File Complaints'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerComplaintsScreen()),
              );
            },
          ),
        ),
      );
    }

    // 3. Plumbing
    if (normalized.contains('tap') || normalized.contains('pipe') || normalized.contains('water') || normalized.contains('plumb') || normalized.contains('leak') || normalized.contains('drain') || normalized.contains('sink')) {
      return const _ChatMessage(
        text: 'This sounds like a Plumbing issue. I recommend a leak and pipe repair service. Check the Plumbing suggestions below and book one that fits.',
        fromUser: false,
      );
    }

    // 4. Electrical
    if (normalized.contains('fan') || normalized.contains('light') || normalized.contains('switch') || normalized.contains('electric') || normalized.contains('wire') || normalized.contains('power') || normalized.contains('socket')) {
      return const _ChatMessage(
        text: 'This sounds like an Electrical issue. I recommend an electrician visit or fan and light installation. See the Electrical suggestions below.',
        fromUser: false,
      );
    }

    // 5. Cleaning
    if (normalized.contains('clean') || normalized.contains('dirt') || normalized.contains('sanit') || normalized.contains('wash') || normalized.contains('mop')) {
      return const _ChatMessage(
        text: 'A Cleaning service should help. You can choose between deep cleaning and bathroom or kitchen sanitization below.',
        fromUser: false,
      );
    }

    // 6. Gardening
    if (normalized.contains('garden') || normalized.contains('plant') || normalized.contains('lawn') || normalized.contains('grass') || normalized.contains('tree')) {
      return const _ChatMessage(
        text: 'This sounds like a Gardening service requirement. Check our garden and lawn maintenance suggestions below.',
        fromUser: false,
      );
    }

    // 7. Pest control
    if (normalized.contains('pest') || normalized.contains('termite') || normalized.contains('roach') || normalized.contains('bug') || normalized.contains('cockroach') || normalized.contains('ant')) {
      return const _ChatMessage(
        text: 'We provide certified Pest Control services for termites, roaches, and insects. See the options below to book a visit.',
        fromUser: false,
      );
    }

    // 8. Appliance
    if (normalized.contains('ac') || normalized.contains('fridge') || normalized.contains('refrigerator') || normalized.contains('washing') || normalized.contains('microwave') || normalized.contains('appliance')) {
      return const _ChatMessage(
        text: 'We can fix appliances like ACs, refrigerators, and washing machines. Look at the Appliance suggestions below to book now.',
        fromUser: false,
      );
    }

    // 9. Available workers
    if (normalized.contains('available') || normalized.contains('worker') || normalized.contains('who')) {
      return const _ChatMessage(
        text: 'The available workers are listed below by category. For an urgent request, SmartFix automatically matches a verified available worker in the service category.',
        fromUser: false,
      );
    }

    // 10. Booking flow
    if (normalized.contains('book') || normalized.contains('order') || normalized.contains('schedule')) {
      return const _ChatMessage(
        text: 'Choose a suggested service below and tap Book now. Select Urgent to request an immediate match, or Scheduled to choose a date and time.',
        fromUser: false,
      );
    }

    // 11. Greetings
    if (normalized == 'hi' || normalized == 'hello' || normalized == 'hey') {
      return const _ChatMessage(
        text: 'Hello! I am Fixie, your SmartFix assistant. Tell me what needs fixing at home (e.g. "leaking tap", "fan not working", "deep cleaning") and I will help you book right away.',
        fromUser: false,
      );
    }

    return const _ChatMessage(
      text: 'Describe the problem, room, or appliance. For example: “my AC is not cooling” or “I need the garden trimmed”. I will suggest a service below.',
      fromUser: false,
    );
  }

  List<ServiceItem> _suggestions(List<ServiceItem> services, String query) {
    final normalized = query.toLowerCase();
    if (normalized.isEmpty) return services.take(4).toList();
    final keywords = <String>{
      if (normalized.contains('tap') || normalized.contains('pipe') || normalized.contains('water') || normalized.contains('plumb') || normalized.contains('leak') || normalized.contains('drain') || normalized.contains('sink')) 'plumbing',
      if (normalized.contains('fan') || normalized.contains('light') || normalized.contains('switch') || normalized.contains('electric') || normalized.contains('wire') || normalized.contains('power') || normalized.contains('socket')) 'electrical',
      if (normalized.contains('clean') || normalized.contains('dirt') || normalized.contains('sanit') || normalized.contains('wash') || normalized.contains('mop')) 'cleaning',
      if (normalized.contains('garden') || normalized.contains('plant') || normalized.contains('lawn') || normalized.contains('grass') || normalized.contains('tree')) 'gardening',
      if (normalized.contains('pest') || normalized.contains('termite') || normalized.contains('roach') || normalized.contains('bug') || normalized.contains('cockroach') || normalized.contains('ant')) 'pest control',
      if (normalized.contains('ac') || normalized.contains('fridge') || normalized.contains('refrigerator') || normalized.contains('washing') || normalized.contains('microwave') || normalized.contains('appliance')) 'appliance',
    };
    final matches = services.where((service) {
      final text = '${service.name} ${service.category} ${service.description}'.toLowerCase();
      return keywords.any(text.contains) || text.contains(normalized);
    }).toList();
    return matches.isEmpty ? services.take(4).toList() : matches.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 18),
            ),
            SizedBox(width: 10),
            Text('Book with Fixie'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              children: [
                _buildConversation(),
                const SizedBox(height: 16),
                _buildSectionTitle('Suggested services'),
                _buildServicesSection(),
                const SizedBox(height: 16),
                _buildSectionTitle('Available workers'),
                _buildWorkersSection(),
              ],
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    return Column(
      children: _messages.map((message) => Align(
        alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: message.fromUser
                ? AppColors.primary
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: message.fromUser ? null : Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.fromUser ? Colors.white : AppColors.textPrimary,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              if (message.actionWidget != null) message.actionWidget!,
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildServicesSection() {
    return FutureBuilder<List<ServiceItem>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppBanner.error('Unable to load services at the moment.'),
          );
        }
        final services = snapshot.data ?? [];
        final suggestions = _suggestions(services, _lastUserQuery);
        if (suggestions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No service match found for this description.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          );
        }
        return Column(
          children: suggestions.map(_buildServiceCard).toList(),
        );
      },
    );
  }

  Widget _buildWorkersSection() {
    return FutureBuilder<List<AppUser>>(
      future: _workersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppBanner.error('Unable to load available workers right now.'),
          );
        }
        final workers = snapshot.data ?? [];
        if (workers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No active workers are marked as available right now. You can still submit an Urgent or Scheduled request!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          );
        }
        return Column(
          children: workers.take(4).map((worker) {
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker.username,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        Text(
                          worker.category ?? 'Verified Service Pro',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Available', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    ),
  );

  Widget _buildServiceCard(ServiceItem service) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_categoryIcon(service.category), color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${service.category} • From ₹${service.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookingScreen(service: service)),
              );
            },
            child: const Text('Book now', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const Divider(height: 1),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _quickQuestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) => ActionChip(
                  label: Text(_quickQuestions[index], style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => _sendMessage(_quickQuestions[index]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Describe what needs fixing...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    tooltip: 'Send message',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing': return Icons.plumbing;
      case 'electrical': return Icons.electrical_services;
      case 'cleaning': return Icons.cleaning_services;
      case 'gardening': return Icons.grass;
      case 'pest control': return Icons.pest_control;
      case 'appliance': return Icons.kitchen;
      default: return Icons.handyman;
    }
  }
}

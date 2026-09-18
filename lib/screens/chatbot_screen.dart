import 'package:flutter/material.dart';
import '../models/service.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';

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

  const _ChatMessage({required this.text, required this.fromUser});
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

  static const _quickQuestions = [
    'I have a leaking tap',
    'My fan is not working',
    'I need home cleaning',
    'Who is available now?',
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
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _messages.add(_ChatMessage(text: _replyFor(text), fromUser: false));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _replyFor(String question) {
    final normalized = question.toLowerCase();
    if (normalized.contains('tap') || normalized.contains('pipe') || normalized.contains('water') || normalized.contains('plumb')) {
      return 'This sounds like a Plumbing issue. I recommend a leak and pipe repair service. Check the Plumbing suggestions below and book one that fits.';
    }
    if (normalized.contains('fan') || normalized.contains('light') || normalized.contains('switch') || normalized.contains('electric')) {
      return 'This sounds like an Electrical issue. I recommend an electrician visit or fan and light installation. See the Electrical suggestions below.';
    }
    if (normalized.contains('clean') || normalized.contains('dirt') || normalized.contains('sanit')) {
      return 'A Cleaning service should help. You can choose between deep cleaning and bathroom or kitchen sanitization below.';
    }
    if (normalized.contains('available') || normalized.contains('worker')) {
      return 'The available workers are listed below by category. For an urgent request, SmartFix automatically matches a verified available worker in the service category.';
    }
    if (normalized.contains('book')) {
      return 'Choose a suggested service below and tap Book now. Select Urgent to request an immediate match, or Scheduled to choose a date and time.';
    }
    return 'Describe the problem, room, or appliance. For example: “my AC is not cooling” or “I need the garden trimmed”. I will suggest a service below.';
  }

  List<ServiceItem> _suggestions(List<ServiceItem> services, String query) {
    final normalized = query.toLowerCase();
    if (normalized.isEmpty) return services.take(4).toList();
    final keywords = <String>{
      if (normalized.contains('tap') || normalized.contains('pipe') || normalized.contains('water') || normalized.contains('plumb')) 'plumbing',
      if (normalized.contains('fan') || normalized.contains('light') || normalized.contains('switch') || normalized.contains('electric')) 'electrical',
      if (normalized.contains('clean') || normalized.contains('dirt') || normalized.contains('sanit')) 'cleaning',
      if (normalized.contains('garden') || normalized.contains('plant') || normalized.contains('lawn')) 'gardening',
      if (normalized.contains('pest') || normalized.contains('termite') || normalized.contains('roach')) 'pest control',
      if (normalized.contains('ac') || normalized.contains('fridge') || normalized.contains('washing')) 'appliance',
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
      appBar: AppBar(title: const Text('Book with Fixie')),
      body: FutureBuilder<List<ServiceItem>>(
        future: _servicesFuture,
        builder: (context, serviceSnapshot) {
          if (serviceSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (serviceSnapshot.hasError) {
            return Center(child: Text('Could not load booking suggestions.\n${serviceSnapshot.error}', textAlign: TextAlign.center));
          }
          final services = serviceSnapshot.data ?? [];
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  children: [
                    _buildConversation(),
                    const SizedBox(height: 12),
                    _buildSectionTitle('Suggested services'),
                    ..._suggestions(services, _messages.last.fromUser ? _messages.last.text : '').map(_buildServiceCard),
                    const SizedBox(height: 12),
                    _buildSectionTitle('Available workers'),
                    FutureBuilder<List<AppUser>>(
                      future: _workersFuture,
                      builder: (context, workerSnapshot) {
                        if (workerSnapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (workerSnapshot.hasError) {
                          return const Text('Worker availability will be checked automatically when you book.');
                        }
                        final workers = workerSnapshot.data ?? [];
                        if (workers.isEmpty) {
                          return const Text('No verified workers are marked available right now. Try a scheduled booking.');
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: workers.map((worker) => Chip(
                            avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            label: Text('${worker.username} • ${worker.category}'),
                          )).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              _buildComposer(),
            ],
          );
        },
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
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: message.fromUser ? Theme.of(context).colorScheme.onPrimary : null, height: 1.3),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _buildServiceCard(ServiceItem service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_categoryIcon(service.category))),
        title: Text(service.name),
        subtitle: Text('${service.category} • From ₹${service.price.toStringAsFixed(0)}'),
        trailing: FilledButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingScreen(service: service))),
          child: const Text('Book now'),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _quickQuestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ActionChip(
                label: Text(_quickQuestions[index]),
                onPressed: () => _sendMessage(_quickQuestions[index]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Describe what needs fixing...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sendMessage, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
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

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../chat/chat_palette.dart';
import '../main.dart'; // For AppConfig

class EventsPage extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final bool compact;

  const EventsPage({
    super.key,
    required this.onMenuPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ChatPalette.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _buildEventGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ChatPalette.background,
          border: Border(bottom: BorderSide(color: ChatPalette.borderSoft)),
        ),
        child: Row(
          children: [
            if (compact) ...[
              IconButton(
                icon: Icon(Icons.menu_rounded, color: ChatPalette.text),
                onPressed: onMenuPressed,
              ),
              SizedBox(width: 8),
            ] else ...[
              SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                AppConfig.appSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventGrid(BuildContext context) {
    final events = [
      _Event(
        title: 'Spectrum 2026',
        subtitle: 'Annual Cultural & Tech Festival',
        date: 'Oct 15 - 17, 2026',
        location: 'Main Campus Grounds',
        imageGradient: const [Color(0xFF334DFF), Color(0xFFBD5EFF)],
        icon: Icons.celebration_rounded,
        tags: ['Festival', 'Music', 'Tech'],
      ),
      _Event(
        title: 'Design Thinking Workshop',
        subtitle: 'Learn the fundamentals of UX/UI',
        date: 'Nov 02, 2026',
        location: 'Design Lab 4',
        imageGradient: const [Color(0xFFFFB340), Color(0xFFFF4D6D)],
        icon: Icons.design_services_rounded,
        tags: ['Workshop', 'Design'],
      ),
      _Event(
        title: 'Winter Internship Fair',
        subtitle: 'Connect with top fashion & tech brands',
        date: 'Dec 10, 2026',
        location: 'Auditorium',
        imageGradient: const [Color(0xFF00F5A0), Color(0xFF00C17A)],
        icon: Icons.work_rounded,
        tags: ['Career', 'Networking'],
      ),
      _Event(
        title: 'Alumni Meetup',
        subtitle: 'Networking dinner with ${AppConfig.appName} graduates',
        date: 'Jan 15, 2027',
        location: 'Hostel Courtyard',
        imageGradient: const [Color(0xFF4D7CFF), Color(0xFF334DFF)],
        icon: Icons.people_alt_rounded,
        tags: ['Alumni', 'Social'],
      ),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 380,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventCard(event: event)
            .animate()
            .fade(duration: 400.ms, delay: (index * 100).ms)
            .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
      },
    );
  }
}

class _Event {
  final String title;
  final String subtitle;
  final String date;
  final String location;
  final List<Color> imageGradient;
  final IconData icon;
  final List<String> tags;

  _Event({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.location,
    required this.imageGradient,
    required this.icon,
    required this.tags,
  });
}

class _EventCard extends StatelessWidget {
  final _Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image (Gradient Placeholder)
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: event.imageGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    event.icon,
                    size: 100,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Row(
                    children: event.tags.map((tag) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      color: ChatPalette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    event.subtitle,
                    style: TextStyle(
                      color: ChatPalette.muted,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Spacer(),
                  // Info rows
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: ChatPalette.dim),
                      SizedBox(width: 6),
                      Text(
                        event.date,
                        style: TextStyle(color: ChatPalette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: ChatPalette.dim),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(color: ChatPalette.muted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => _EventDetailsDialog(event: event),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChatPalette.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailsDialog extends StatelessWidget {
  final _Event event;

  const _EventDetailsDialog({required this.event});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ChatPalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Image
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: event.imageGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      event.icon,
                      size: 140,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: event.tags.map((tag) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: event.imageGradient.first.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: event.imageGradient.first,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Text(
                      event.title,
                      style: TextStyle(
                        color: ChatPalette.text,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      event.subtitle,
                      style: TextStyle(
                        color: ChatPalette.muted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 24),
                    Divider(color: ChatPalette.border),
                    SizedBox(height: 16),
                    _InfoRow(icon: Icons.calendar_today_rounded, title: 'Date & Time', value: event.date),
                    SizedBox(height: 16),
                    _InfoRow(icon: Icons.location_on_rounded, title: 'Location', value: event.location),
                    SizedBox(height: 16),
                    _InfoRow(icon: Icons.group_rounded, title: 'Eligibility', value: 'All ${AppConfig.appName} Students'),
                    const SizedBox(height: 12),
                    const _InfoRow(icon: Icons.info_outline_rounded, title: 'Contact', value: 'events@university.edu'),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Footer Action
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: ChatPalette.border)),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Registered successfully!'),
                      backgroundColor: ChatPalette.accent,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: event.imageGradient.first,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Register for Event',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ChatPalette.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: ChatPalette.muted),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: ChatPalette.dim, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(color: ChatPalette.text, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

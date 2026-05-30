import 'package:flutter/material.dart';

class HomeProfileActions extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onNotifications;

  const HomeProfileActions({
    super.key,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit),
                label: const Text('Uredi profil'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onChangePassword,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Lozinka'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Notifikacije'),
          ),
        ),
      ],
    );
  }
}

class HomeRecommendationSectionHeader extends StatelessWidget {
  final String summary;

  const HomeRecommendationSectionHeader({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personalizovane preporuke za vasu aktivnost i lokaciju.',
          style: TextStyle(color: Color(0xFF8A94A8)),
        ),
        const SizedBox(height: 12),
        Text(
          summary,
          style: const TextStyle(color: Color(0xFF8A94A8)),
        ),
      ],
    );
  }
}

class HomeTrainingTypeFilterSection extends StatelessWidget {
  final List<String> trainingTypes;
  final String? selectedTrainingType;
  final ValueChanged<String> onToggle;

  const HomeTrainingTypeFilterSection({
    super.key,
    required this.trainingTypes,
    required this.selectedTrainingType,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TIP TRENINGA',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: trainingTypes
              .map(
                (type) => ChoiceChip(
                  label: Text(type),
                  selected: selectedTrainingType == type,
                  onSelected: (_) => onToggle(type),
                ),
              )
              .toList(),
        ),
        if (trainingTypes.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Tipovi treninga ce biti prikazani kada budu dostupni iz baze.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          ),
        ],
      ],
    );
  }
}

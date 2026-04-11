class Donation {
  final String id;
  final String mosqueId;
  final String campaignTitle;
  final String description;
  final double targetAmount;
  final double collectedAmount;
  final String imageUrl;
  final DateTime? deadline;
  final bool isActive;

  const Donation({
    required this.id,
    required this.mosqueId,
    required this.campaignTitle,
    required this.description,
    required this.targetAmount,
    required this.collectedAmount,
    required this.imageUrl,
    required this.deadline,
    required this.isActive,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    final deadlineValue = json['deadline'] as String?;
    return Donation(
      id: json['id'] as String? ?? '',
      mosqueId: json['mosqueId'] as String? ?? '',
      campaignTitle: json['campaignTitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      collectedAmount: (json['collectedAmount'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
      deadline: deadlineValue == null || deadlineValue.isEmpty
          ? null
          : DateTime.parse(deadlineValue),
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'mosqueId': mosqueId,
      'campaignTitle': campaignTitle,
      'description': description,
      'targetAmount': targetAmount,
      'collectedAmount': collectedAmount,
      'imageUrl': imageUrl,
      'deadline': deadline?.toIso8601String(),
      'isActive': isActive,
    };
  }

  Donation copyWith({
    String? id,
    String? mosqueId,
    String? campaignTitle,
    String? description,
    double? targetAmount,
    double? collectedAmount,
    String? imageUrl,
    DateTime? deadline,
    bool clearDeadline = false,
    bool? isActive,
  }) {
    return Donation(
      id: id ?? this.id,
      mosqueId: mosqueId ?? this.mosqueId,
      campaignTitle: campaignTitle ?? this.campaignTitle,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      imageUrl: imageUrl ?? this.imageUrl,
      deadline: clearDeadline ? null : deadline ?? this.deadline,
      isActive: isActive ?? this.isActive,
    );
  }
}

class Review {
  final String? id;
  final double rating;
  final String userName;
  final String comment;
  final DateTime? createdAt;
  final String? timeAgo;

  const Review({
    this.id,
    required this.rating,
    required this.userName,
    required this.comment,
    this.createdAt,
    this.timeAgo,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    final createdAt = rawCreatedAt is String && rawCreatedAt.trim().isNotEmpty
        ? DateTime.tryParse(rawCreatedAt)?.toLocal()
        : null;

    final rawUserName = json['userName'] ?? json['user_name'];
    final rawComment = json['comment'] ?? json['comments'];

    return Review(
      id: json['id'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      userName: rawUserName is String && rawUserName.trim().isNotEmpty
          ? rawUserName.trim()
          : 'Community Member',
      comment: rawComment is String ? rawComment.trim() : '',
      createdAt: createdAt,
      timeAgo: json['timeAgo'] as String?,
    );
  }

  String get displayTimeAgo {
    final explicit = timeAgo?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final timestamp = createdAt;
    if (timestamp == null) {
      return '';
    }

    final elapsed = DateTime.now().difference(timestamp);
    if (elapsed.inMinutes < 1) {
      return 'Just now';
    }
    if (elapsed.inHours < 1) {
      final minutes = elapsed.inMinutes;
      return '$minutes min ago';
    }
    if (elapsed.inDays < 1) {
      final hours = elapsed.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }
    if (elapsed.inDays < 7) {
      final days = elapsed.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    }
    if (elapsed.inDays < 30) {
      final weeks = (elapsed.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    }
    if (elapsed.inDays < 365) {
      final months = (elapsed.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    }

    final years = (elapsed.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  }
}

class ReviewFeed {
  const ReviewFeed({
    required this.items,
    required this.averageRating,
    required this.totalReviews,
  });

  final List<Review> items;
  final double averageRating;
  final int totalReviews;

  factory ReviewFeed.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    final items = rawItems
        .whereType<Map>()
        .map(
          (item) => Review.fromJson(
            Map<String, dynamic>.from(item.cast<Object?, Object?>()),
          ),
        )
        .toList(growable: false);

    final rawSummary = json['summary'];
    final summary = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary.cast<Object?, Object?>())
        : const <String, dynamic>{};

    final totalReviews = (summary['totalReviews'] as num?)?.toInt() ??
        (summary['total_reviews'] as num?)?.toInt() ??
        items.length;

    final averageRating = (summary['averageRating'] as num?)?.toDouble() ??
        (summary['average_rating'] as num?)?.toDouble() ??
        (items.isEmpty
            ? 0
            : items
                    .map((item) => item.rating)
                    .reduce((left, right) => left + right) /
                items.length);

    return ReviewFeed(
      items: items,
      averageRating: averageRating,
      totalReviews: totalReviews,
    );
  }

  bool get hasReviews => totalReviews > 0;

  String get ratingLabel {
    if (!hasReviews) {
      return 'No reviews yet';
    }
    final label = totalReviews == 1 ? 'review' : 'reviews';
    return '${averageRating.toStringAsFixed(1)} | $totalReviews $label';
  }

  String get ratingChipLabel =>
      hasReviews ? averageRating.toStringAsFixed(1) : 'New';
}

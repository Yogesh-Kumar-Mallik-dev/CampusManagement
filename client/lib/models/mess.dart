enum MessMealType {
  breakfast('breakfast', 'Breakfast'),
  lunch('lunch', 'Lunch'),
  dinner('dinner', 'Dinner'),
  brunch('brunch', 'Brunch (Replaces Breakfast & Lunch)');

  final String code;
  final String label;
  const MessMealType(this.code, this.label);

  static MessMealType fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'brunch':
        return MessMealType.brunch;
      case 'lunch':
        return MessMealType.lunch;
      case 'dinner':
        return MessMealType.dinner;
      case 'breakfast':
      default:
        return MessMealType.breakfast;
    }
  }
}

enum MessRatingValue {
  veryPoor('very_poor', 'Very Poor', 1, true),
  poor('poor', 'Poor', 2, true),
  average('average', 'Average', 3, true),
  good('good', 'Good', 4, false),
  veryGood('very_good', 'Very Good', 5, false),
  abstained('abstained', 'Abstained', null, false);

  final String code;
  final String label;
  final int? score;
  final bool isMessageCompulsory;

  const MessRatingValue(this.code, this.label, this.score, this.isMessageCompulsory);

  static MessRatingValue fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'very_poor':
        return MessRatingValue.veryPoor;
      case 'poor':
        return MessRatingValue.poor;
      case 'average':
        return MessRatingValue.average;
      case 'good':
        return MessRatingValue.good;
      case 'very_good':
        return MessRatingValue.veryGood;
      case 'abstained':
      default:
        return MessRatingValue.abstained;
    }
  }
}

class MessMealModel {
  final String id;
  final String dayOfWeek; // 'monday' ... 'sunday'
  final String mealType; // 'breakfast', 'lunch', 'dinner', 'brunch'
  final String startTime;
  final String endTime;
  final String title;
  final String menuSummary;
  final List<String> items;

  const MessMealModel({
    required this.id,
    required this.dayOfWeek,
    required this.mealType,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.menuSummary,
    this.items = const [],
  });

  bool get isSundayBrunch =>
      dayOfWeek.toLowerCase() == 'sunday' && mealType.toLowerCase() == 'brunch';

  factory MessMealModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return MessMealModel(
      id: json['id'] as String? ?? '',
      dayOfWeek: (json['day_of_week'] as String? ?? 'monday').toLowerCase(),
      mealType: (json['meal_type'] as String? ?? 'breakfast').toLowerCase(),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      title: json['title'] as String? ?? '',
      menuSummary: json['menu_summary'] as String? ?? '',
      items: rawItems.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_of_week': dayOfWeek,
      'meal_type': mealType,
      'start_time': startTime,
      'end_time': endTime,
      'title': title,
      'menu_summary': menuSummary,
      'items': items,
    };
  }
}

class MessRatingModel {
  final String id;
  final String mealId;
  final String dayOfWeek;
  final String mealType;
  final String userId;
  final String userName;
  final String campusHandle;
  final String rating; // 'very_poor', 'poor', 'average', 'good', 'very_good', 'abstained'
  final String message;
  final DateTime createdAt;

  const MessRatingModel({
    required this.id,
    required this.mealId,
    required this.dayOfWeek,
    required this.mealType,
    required this.userId,
    required this.userName,
    required this.campusHandle,
    required this.rating,
    required this.message,
    required this.createdAt,
  });

  MessRatingValue get ratingEnum => MessRatingValue.fromCode(rating);

  bool get isMessageCompulsory => ratingEnum.isMessageCompulsory;

  static String? validateRatingFeedback({
    required MessRatingValue rating,
    required String? message,
  }) {
    final trimmed = message?.trim() ?? '';
    if (rating.isMessageCompulsory && trimmed.isEmpty) {
      return 'Feedback message is compulsory for ${rating.label} rating.';
    }
    return null;
  }

  factory MessRatingModel.fromJson(Map<String, dynamic> json) {
    return MessRatingModel(
      id: json['id'] as String? ?? '',
      mealId: json['meal_id'] as String? ?? '',
      dayOfWeek: (json['day_of_week'] as String? ?? 'monday').toLowerCase(),
      mealType: (json['meal_type'] as String? ?? 'breakfast').toLowerCase(),
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      campusHandle: json['campus_handle'] as String? ?? '',
      rating: json['rating'] as String? ?? 'abstained',
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meal_id': mealId,
      'day_of_week': dayOfWeek,
      'meal_type': mealType,
      'user_id': userId,
      'user_name': userName,
      'campus_handle': campusHandle,
      'rating': rating,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MessReportSummary {
  final int totalRatings;
  final double averageScore;
  final Map<String, int> ratingCounts;
  final List<MessRatingModel> recentMessages;
  final String sundayScheduleNote;

  const MessReportSummary({
    required this.totalRatings,
    required this.averageScore,
    required this.ratingCounts,
    required this.recentMessages,
    required this.sundayScheduleNote,
  });

  factory MessReportSummary.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['rating_counts'] as Map<String, dynamic>? ?? {};
    final parsedCounts = <String, int>{};
    rawCounts.forEach((k, v) {
      parsedCounts[k] = (v as num).toInt();
    });

    final rawMsgs = json['recent_messages'] as List<dynamic>? ?? [];
    final parsedMsgs = rawMsgs
        .map((e) => MessRatingModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return MessReportSummary(
      totalRatings: (json['total_ratings'] as num?)?.toInt() ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      ratingCounts: parsedCounts,
      recentMessages: parsedMsgs,
      sundayScheduleNote: json['sunday_schedule_note'] as String? ??
          'On Sunday, Brunch (10:00 - 13:00) replaces Breakfast and Lunch. Dinner is served at 19:30 - 21:30.',
    );
  }
}

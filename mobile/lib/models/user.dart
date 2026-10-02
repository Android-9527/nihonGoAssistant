/// 用户模型（登录态）
class User {
  final int id;
  final String email;
  final String nickname;
  final String? createdAt;

  const User({
    required this.id,
    required this.email,
    required this.nickname,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        email: (j['email'] as String?) ?? '',
        nickname: (j['nickname'] as String?) ?? '',
        createdAt: j['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nickname': nickname,
        'created_at': createdAt,
      };
}

/// 复习推荐项（/api/review/recommendations 返回）
class ReviewItem {
  final String elementType; // word | grammar
  final int elementId;
  final String source;
  final String? reason;
  final double? mastery;

  const ReviewItem({
    required this.elementType,
    required this.elementId,
    this.source = '',
    this.reason,
    this.mastery,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
        elementType: (j['element_type'] as String?) ?? '',
        elementId: (j['element_id'] as num?)?.toInt() ?? 0,
        source: (j['source'] as String?) ?? '',
        reason: j['reason'] as String?,
        mastery: (j['mastery'] as num?)?.toDouble(),
      );
}

/// 测试/复习提交结果（/api/test/submit 返回）
class SubmitResult {
  final double mastery;
  final int correctCount;
  final int wrongCount;
  final int totalAttempts;
  final int streak;
  final String? nextReviewAt;

  const SubmitResult({
    required this.mastery,
    required this.correctCount,
    required this.wrongCount,
    required this.totalAttempts,
    required this.streak,
    this.nextReviewAt,
  });

  factory SubmitResult.fromJson(Map<String, dynamic> j) => SubmitResult(
        mastery: (j['mastery'] as num?)?.toDouble() ?? 0,
        correctCount: (j['correct_count'] as num?)?.toInt() ?? 0,
        wrongCount: (j['wrong_count'] as num?)?.toInt() ?? 0,
        totalAttempts: (j['total_attempts'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        nextReviewAt: j['next_review_at'] as String?,
      );
}

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

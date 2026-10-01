enum AnalyticsScreen {
  home('home'),
  followValidation('follow_validation'),
  quizIntro('quiz_intro'),
  quizQuestions('quiz_questions'),
  weighting('weighting'),
  candidateSelection('candidate_selection'),
  results('results'),
  comparison('comparison'),
  communityFeed('community_feed'),
  communityPost('community_post'),
  communityCreate('community_create'),
  resultShare('result_share'),
  privacy('privacy');

  const AnalyticsScreen(this.value);
  final String value;
}

enum AnalyticsSource {
  initial('initial'),
  tab('tab'),
  homeCta('home_cta'),
  drawer('drawer'),
  deepLink('deep_link'),
  route('route'),
  back('back');

  const AnalyticsSource(this.value);
  final String value;
}

enum AnalyticsAction {
  quizEntry('quiz_entry'),
  evidenceOpen('evidence_open'),
  outboundOpen('outbound_open'),
  share('share');

  const AnalyticsAction(this.value);
  final String value;
}

enum AnalyticsSurface {
  home('home'),
  quiz('quiz'),
  comparison('comparison'),
  news('news'),
  results('results'),
  privacy('privacy');

  const AnalyticsSurface(this.value);
  final String value;
}

enum AnalyticsTarget {
  quizGuide('quiz_guide'),
  quizSource('quiz_source'),
  comparisonSource('comparison_source'),
  newsArticle('news_article'),
  newsIndex('news_index'),
  privacyEmail('privacy_email'),
  googlePrivacy('google_privacy'),
  nativeShare('native_share'),
  download('download'),
  copyLink('copy_link'),
  twitter('twitter'),
  whatsapp('whatsapp'),
  instagramHelp('instagram_help');

  const AnalyticsTarget(this.value);
  final String value;
}

enum AnalyticsOperation {
  newsLoad('news_load'),
  quizLoad('quiz_load'),
  candidateLoad('candidate_load'),
  resultsSubmit('results_submit'),
  comparisonLoad('comparison_load'),
  followStatusLoad('follow_status_load'),
  followRegister('follow_register'),
  communityFeedLoad('community_feed_load'),
  communityPostLoad('community_post_load'),
  communityPostCreate('community_post_create'),
  communityCommentCreate('community_comment_create'),
  communityVote('community_vote'),
  communityReport('community_report'),
  shareRender('share_render');

  const AnalyticsOperation(this.value);
  final String value;
}

enum AnalyticsOutcome {
  success('success'),
  empty('empty'),
  failed('failed'),
  stale('stale'),
  blocked('blocked');

  const AnalyticsOutcome(this.value);
  final String value;
}

enum AnalyticsTrigger {
  initial('initial'),
  retry('retry'),
  refresh('refresh'),
  pagination('pagination'),
  submit('submit');

  const AnalyticsTrigger(this.value);
  final String value;
}

enum AnalyticsFailureType {
  network('network'),
  timeout('timeout'),
  client('client'),
  server('server'),
  rateLimited('rate_limited'),
  moderationRejected('moderation_rejected'),
  unavailable('unavailable'),
  unknown('unknown');

  const AnalyticsFailureType(this.value);
  final String value;
}

enum AnalyticsQuizStage {
  questions('questions'),
  weighting('weighting'),
  candidateSelection('candidate_selection');

  const AnalyticsQuizStage(this.value);
  final String value;
}

enum AnalyticsAbandonReason {
  back('back'),
  restart('restart'),
  recovery('recovery');

  const AnalyticsAbandonReason(this.value);
  final String value;
}

/// Restituisce true se la lista di piani (già filtrata per scadenza upstream)
/// contiene almeno un piano valido per prenotare [courseId].
///
/// Un piano è valido quando:
/// - è unlimited (qualsiasi corso), oppure
/// - è credits con credits_remaining > 0 e corso_id null (Open) o == courseId
bool hasValidPlanForCourse(
    List<Map<String, dynamic>> plans, String courseId) {
  for (final p in plans) {
    final planCourseId = p['course_id'] as String?;
    if (planCourseId != null && planCourseId != courseId) continue;
    final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
    final credits = p['credits_remaining'] as int?;
    if (type == 'unlimited') return true;
    if (type == 'trial' && credits == null) return true; // trial-by-time: unlimited within expiry
    if (type == 'trial') continue; // trial-by-credits: use bookTrialLesson, not book
    if (credits != null && credits > 0) return true;
  }
  return false;
}

/// Restituisce il piano crediti migliore da cui detrarre un credito per [courseId].
///
/// Priorità: piano Open (course_id null) > piano corso-specifico.
/// Restituisce null se nessun piano crediti con crediti disponibili esiste.
Map<String, dynamic>? selectBestCreditPlan(
    List<Map<String, dynamic>> plans, String courseId) {
  // Open credits plan first
  for (final p in plans) {
    final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
    if (type != 'credits') continue;
    if (p['course_id'] != null) continue;
    final credits = p['credits_remaining'] as int?;
    if (credits != null && credits > 0) return p;
  }
  // Fallback: corso-specifico
  for (final p in plans) {
    final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
    if (type != 'credits') continue;
    if (p['course_id'] != courseId) continue;
    final credits = p['credits_remaining'] as int?;
    if (credits != null && credits > 0) return p;
  }
  // Ultimo fallback: crediti prova (disdetta tardiva da piano trial)
  for (final p in plans) {
    final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
    if (type != 'trial') continue;
    final credits = p['credits_remaining'] as int?;
    if (credits != null && credits > 0) return p;
  }
  return null;
}

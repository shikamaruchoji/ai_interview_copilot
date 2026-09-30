/// Deterministic template answers when no copilot server is configured or the request fails.
String fallbackAnswer(String question, List<String> retrieved) {
  final q = question.toLowerCase();
  final basis = retrieved.isNotEmpty ? retrieved.first : '';
  var detail = basis;
  if (detail.startsWith('[RESUME]')) {
    detail = detail.substring('[RESUME]'.length).trim();
  } else if (detail.startsWith('[JOB]')) {
    detail = detail.substring('[JOB]'.length).trim();
  }
  final oneDetail = detail.length > 120 ? '${detail.substring(0, 120)}…' : detail;

  String thirdBullet(String generic) {
    if (oneDetail.isEmpty) return generic;
    return 'Where my résumé fits, I’d mention one concrete thread briefly—without pasting blocks of text ($oneDetail).';
  }

  if (q.contains('debug') || q.contains('incident') || q.contains('outage') || q.contains('slow')) {
    return '• I would start by confirming scope: which endpoints, regions, or customers are affected, and whether the change correlates with a deploy, config flip, or dependency outage. I would pull golden signals like error rate, latency percentiles, saturation, and saturation on dependencies, then narrow to one layer at a time rather than guessing.\n'
        '• Once I have a likely subsystem, I would reproduce in a lower environment if possible, add temporary targeted logging or tracing where gaps exist, and coordinate mitigation first—throttle, feature flag, rollback, or scale—so user impact stops growing while root cause work continues in parallel.\n'
        '• After mitigation, I would write a short incident timeline, capture what detection missed, and drive follow-up items like SLO tuning, alerts, or load tests. ${thirdBullet("I would also sanity-check that dashboards still reflect reality after the fix ships.")}';
  }
  if (q.contains('microservice') || q.contains('kubernetes') || q.contains('k8s') || q.contains('deploy')) {
    return '• I would treat a breaking change as a contract problem first: who consumes the API, what compatibility window exists, and whether we can use additive changes, versioning, or feature flags to decouple rollout from consumer upgrades.\n'
        '• For deployment I would prefer progressive delivery—canary or blue/green—with automated health checks, synthetic probes, and a fast rollback path, while watching saturation and error budgets so we stop early if signals regress.\n'
        '• I would also validate observability across service boundaries so failures are attributable, and document operational runbooks for the new behavior. ${thirdBullet("Finally, I would align ownership with on-call load and clear escalation paths.")}';
  }
  if (q.contains('security') || q.contains('auth') || q.contains('oauth') || q.contains('jwt')) {
    return '• I would start from the threat model for the asset: what is being protected, who the actors are, and what abuse cases matter most, then choose primitives that match—short-lived credentials, rotation, audience and scope restrictions, and least privilege everywhere.\n'
        '• For tokens specifically, I would compare trade-offs like revocation UX, storage risks on clients, replay resistance, and operational complexity, then pick a pattern that fits the product constraints rather than treating JWT versus opaque sessions as purely ideological.\n'
        '• I would validate the end-to-end flow with tests and review, and ensure logging avoids leaking secrets while still supporting incident response. ${thirdBullet("I would schedule periodic reviews as the surface area grows.")}';
  }
  if (q.contains('sql') || q.contains('database') || q.contains('nosql')) {
    return '• I would anchor schema work in real access patterns and consistency requirements, because the safest migration is one that matches how data is read and written under production concurrency, not how it looks on a diagram.\n'
        '• For zero downtime, I would favor expand/contract patterns: add new columns or tables, dual-write or backfill with verification, cut reads over, then retire old paths, with checkpoints and reversible steps so we are never stuck halfway.\n'
        '• I would measure with explain plans, lock waits, and replay tests before and after, and communicate blast radius to teams that depend on the datastore. ${thirdBullet("I would document invariants so future changes stay safe.")}';
  }

  if (oneDetail.isNotEmpty) {
    return '• I would answer the question directly using a clear narrative structure, because interview answers land better when they are easy to follow under time pressure and still show depth where it matters.\n'
        '• Where it genuinely strengthens credibility, I would weave in one concrete example from my background without reading documents verbatim or inventing specifics that are not supported by what I actually shipped.\n'
        '• I would close by inviting a clarifying follow-up, because good candidates show they can collaborate and scope work instead of monologuing past the interviewer’s intent.';
  }
  return '• I would answer head-on with a tight structure: restate the goal, outline the approach with trade-offs, and describe how I would validate assumptions with data or prototypes rather than pure theory.\n'
      '• I would keep the tone conversational and adaptive, checking whether the interviewer wants more depth on architecture, people leadership, or hands-on execution depending on the role level.\n'
      '• I would end with a crisp summary sentence so the answer is memorable and easy to score positively in notes.';
}

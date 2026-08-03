import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_public_sector/models/emerging_risk_brief.dart';
import 'package:vantage_public_sector/services/report/claude_http.dart';
import 'package:vantage_public_sector/services/report/report_ai_service.dart';
import 'package:vantage_public_sector/services/report/risk_research_service.dart';

/// Enforces "no single API call costs more than ClaudeHttp.perCallBudgetUsd"
/// by computing a worst-case dollar estimate for every stage in the Risk
/// Desk swarm and Report Studio pipelines from their real max_tokens and
/// char-cap constants — the same numbers the request builders use, not a
/// copy that can drift out of sync.
///
/// This is deliberately a static estimate, not a live token count: a
/// chars/4 heuristic for input size, plus a flat margin for system-prompt,
/// tool-use and JSON-schema overhead the heuristic doesn't see. It is meant
/// to catch a max_tokens bump or an uncapped concatenation before it ships,
/// not to bill precisely. If a real invoice disagrees with this test, trust
/// the invoice and tighten the margin here.
///
/// Haiku 4.5 pricing (input/output per MTok, web search per call):
/// https://platform.claude.com/docs/en/about-claude/pricing
const double _inputPerMTok = 1.0;
const double _outputPerMTok = 5.0;
const double _perSearch = 0.01;

/// Rough chars-per-token ratio for English text (Anthropic's own estimate).
const int _charsPerToken = 4;

/// Flat token allowance per call for content this test doesn't model:
/// system prompt prose, JSON-schema encoding, and (where used) the tool-use
/// system-prompt addition (~500-600 tokens for Haiku per the pricing docs).
const int _overheadTokens = 1500;

double _estimateCost({
  required int maxOutputTokens,
  required int inputChars,
  int searches = 0,
}) {
  final inputTokens = (inputChars / _charsPerToken).ceil() + _overheadTokens;
  final inputCost = inputTokens * _inputPerMTok / 1e6;
  final outputCost = maxOutputTokens * _outputPerMTok / 1e6;
  final searchCost = searches * _perSearch;
  return inputCost + outputCost + searchCost;
}

void main() {
  test('this suite is pinned to Haiku pricing', () {
    expect(ClaudeHttp.model, 'claude-haiku-4-5',
        reason: 'The dollar constants above are Haiku 4.5 rates. If the '
            'model constant changes, every budget below needs re-deriving '
            'against the new price sheet before this test means anything.');
  });

  group('Risk Desk swarm — every call under budget', () {
    test('plan()', () {
      final cost = _estimateCost(
        maxOutputTokens: RiskResearchService.planMaxTokens,
        inputChars: 1000, // topic + focus, always short
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });

    test('research(), worst case: deep depth, max search fees', () {
      final cost = _estimateCost(
        maxOutputTokens: RiskResearchService.researchMaxTokens,
        inputChars: RiskResearchService.researchContextCharCap + 2000,
        // Search result content isn't in `inputChars` — each search's
        // returned snippets add to input too, on top of the flat fee.
        // Budget generously for that here rather than trying to model it.
        searches: ResearchDepth.deep.searchUses,
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });

    test('lens()', () {
      final cost = _estimateCost(
        maxOutputTokens: RiskResearchService.lensMaxTokens,
        inputChars: RiskResearchService.lensResearchCharCap + 500,
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });

    test('synthesize(), worst case: capped research + capped lenses', () {
      final cost = _estimateCost(
        maxOutputTokens: RiskResearchService.synthesizeMaxTokens,
        inputChars: RiskResearchService.synthesizeSectionCharCap * 2 + 500,
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });

    test('followUp(), worst case: capped brief + research + full history', () {
      final cost = _estimateCost(
        maxOutputTokens: RiskResearchService.followUpMaxTokens,
        inputChars: RiskResearchService.followUpBriefCharCap +
            RiskResearchService.followUpResearchCharCap +
            // followUpHistoryTurns messages, generously sized.
            RiskResearchService.followUpHistoryTurns * 1500,
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });

    test('triage(), worst case: max headlines + max known risks', () {
      final cost = _estimateCost(
        maxOutputTokens: RiskResearchService.triageMaxTokens,
        inputChars: RiskResearchService.triageMaxHeadlines * 100 +
            RiskResearchService.triageMaxKnownRisks * 80,
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });
  });

  group('Report Studio — every call under budget', () {
    test('editionBrief(), worst case: capped total source text', () {
      final cost = _estimateCost(
        maxOutputTokens: ReportAiService.editionBriefMaxTokens,
        // The running cap is checked between sources, so the last source
        // admitted can push slightly past it — budget for one more.
        inputChars: ReportAiService.sourceTotalCharCap +
            ReportAiService.slidesPerBatch * 1600,
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });

    test('cloneBatch(), worst case: full batch of capped blocks', () {
      const blocksPerSlideAssumed = 10; // generous for a real template
      final cost = _estimateCost(
        maxOutputTokens: ReportAiService.cloneBatchMaxTokens,
        inputChars:
            // Reused edition brief, itself bounded by editionBriefMaxTokens.
            ReportAiService.editionBriefMaxTokens * _charsPerToken +
                ReportAiService.slidesPerBatch *
                    blocksPerSlideAssumed *
                    ReportAiService.cloneBlockOriginalCharCap,
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });

    test('rebuildPlan(), worst case: reused brief + full archetype guide', () {
      final cost = _estimateCost(
        maxOutputTokens: ReportAiService.rebuildPlanMaxTokens,
        inputChars: ReportAiService.editionBriefMaxTokens * _charsPerToken +
            2000, // archetype field guide + requested archetypes list
      );
      expect(cost, lessThan(ClaudeHttp.perCallBudgetUsd));
    });
  });

  test('web search cost never exceeds budget on its own', () {
    // Search fees are flat regardless of tokens, so this is the one lever
    // token caps can't touch — check it in isolation.
    for (final depth in ResearchDepth.values) {
      final fee = depth.searchUses * _perSearch;
      expect(fee, lessThan(ClaudeHttp.perCallBudgetUsd),
          reason: '${depth.name}: ${depth.searchUses} searches = \$$fee');
    }
  });
}

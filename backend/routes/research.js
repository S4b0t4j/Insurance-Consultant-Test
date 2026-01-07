import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import Anthropic from '@anthropic-ai/sdk';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const router = express.Router();

// Initialize Anthropic client
const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

// Meetings database helpers
const MEETINGS_DB_PATH = path.join(__dirname, '../data/meetings.json');

const getMeetingsDb = () => {
  if (!fs.existsSync(MEETINGS_DB_PATH)) {
    return { meetings: [] };
  }
  return JSON.parse(fs.readFileSync(MEETINGS_DB_PATH, 'utf-8'));
};

const saveMeetingsDb = (data) => {
  fs.writeFileSync(MEETINGS_DB_PATH, JSON.stringify(data, null, 2));
};

// Deep Research endpoint
router.post('/:meetingId/deep-research', async (req, res) => {
  try {
    const { meetingId } = req.params;
    const { focusAreas } = req.body;

    const db = getMeetingsDb();
    const meetingIndex = db.meetings.findIndex(m => m.id === meetingId);

    if (meetingIndex === -1) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    const meeting = db.meetings[meetingIndex];

    if (!meeting.analysis) {
      return res.status(400).json({ error: 'Meeting has not been analyzed yet. Please run analysis first.' });
    }

    // Update status
    db.meetings[meetingIndex].status = 'researching';
    saveMeetingsDb(db);

    console.log(`Starting Deep Research for meeting: ${meetingId}`);

    // Build research context
    const researchContext = buildResearchContext(meeting, focusAreas);

    // Use Claude with web search capabilities
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 12000,
      messages: [
        {
          role: 'user',
          content: researchContext
        }
      ]
    });

    const researchText = response.content[0].text;
    const deepResearch = parseDeepResearchResponse(researchText);

    // Save deep research results
    const researchPath = path.join(__dirname, '../data/analyses', `${meetingId}-research.json`);
    fs.writeFileSync(researchPath, JSON.stringify({
      ...deepResearch,
      researchedAt: new Date().toISOString(),
      focusAreas
    }, null, 2));

    // Update meeting in database
    db.meetings[meetingIndex].deepResearch = deepResearch;
    db.meetings[meetingIndex].status = 'researched';
    db.meetings[meetingIndex].researchedAt = new Date().toISOString();
    saveMeetingsDb(db);

    console.log(`Deep Research complete for meeting: ${meetingId}`);

    res.json({
      success: true,
      deepResearch
    });
  } catch (error) {
    console.error('Deep Research error:', error);

    const db = getMeetingsDb();
    const meetingIndex = db.meetings.findIndex(m => m.id === req.params.meetingId);
    if (meetingIndex !== -1) {
      db.meetings[meetingIndex].status = 'analyzed';
      saveMeetingsDb(db);
    }

    res.status(500).json({
      error: 'Deep Research failed',
      details: error.message
    });
  }
});

function buildResearchContext(meeting, focusAreas) {
  const rfpData = meeting.rfpData || {};
  const analysis = meeting.analysis || {};
  const clientName = rfpData.factFindingSummary?.clientName || meeting.clientName || 'the client';
  const industry = rfpData.factFindingSummary?.industry || 'their industry';
  const location = rfpData.factFindingSummary?.location || '';

  const riskExposures = analysis.riskExposures || [];
  const painPoints = rfpData.factFindingSummary?.painPoints || [];
  const coverageGaps = rfpData.factFindingSummary?.coverageGaps || [];

  return `You are a senior insurance risk consultant at Marsh McLennan conducting deep research for a potential client.

CLIENT PROFILE:
- Name: ${clientName}
- Industry: ${industry}
- Location: ${location}
- Key Risk Exposures: ${JSON.stringify(riskExposures)}
- Pain Points: ${JSON.stringify(painPoints)}
- Coverage Gaps: ${JSON.stringify(coverageGaps)}

MEETING SUMMARY:
${analysis.summary || meeting.transcript?.text?.substring(0, 2000) || 'No summary available'}

${focusAreas ? `SPECIFIC RESEARCH FOCUS AREAS REQUESTED:\n${focusAreas.join('\n')}` : ''}

Please conduct comprehensive research and provide analysis in the following JSON format:

{
  "geographicRiskFactors": {
    "location": "Client location analysis",
    "naturalCatastrophes": [
      {"hazard": "Type of hazard", "severity": "high/medium/low", "frequency": "Annual probability", "historicalEvents": ["Notable past events"], "implications": "Insurance implications"}
    ],
    "regulatoryEnvironment": {
      "state": "State-specific regulations",
      "federal": "Federal regulations applicable",
      "compliance": ["Key compliance requirements"],
      "upcomingChanges": ["Pending regulatory changes"]
    },
    "economicFactors": {
      "localEconomy": "Economic conditions",
      "industryPresence": "Industry presence in region",
      "talentMarket": "Labor market conditions"
    },
    "infrastructureRisks": ["Infrastructure-related risks"]
  },

  "industryAnalysis": {
    "overview": "Industry overview and trends",
    "marketSize": "Market size and growth",
    "keyPlayers": ["Major industry players"],
    "challengesAndTrends": [
      {"trend": "Trend/challenge", "impact": "Impact on client", "insuranceImplications": "How it affects coverage needs"}
    ],
    "regulatoryLandscape": "Industry-specific regulations",
    "emergingRisks": [
      {"risk": "Emerging risk", "probability": "Likelihood", "severity": "Impact level", "mitigation": "How to address"}
    ],
    "benchmarkData": {
      "lossRatios": "Industry loss ratio benchmarks",
      "premiumTrends": "Premium trends",
      "retentionLevels": "Typical retention levels"
    }
  },

  "marketIntelligence": {
    "carrierAppetite": [
      {"carrier": "Carrier name", "appetite": "strong/moderate/limited/declining", "specialties": ["Areas of focus"], "concerns": "Any concerns they have", "recentActivity": "Recent market behavior"}
    ],
    "marketConditions": {
      "overall": "Hard/soft/transitioning",
      "byLine": [
        {"line": "Coverage line", "condition": "Market condition", "rateChange": "Expected rate movement", "capacityAvailable": "Capacity assessment"}
      ]
    },
    "reinsuranceMarket": "Reinsurance market conditions affecting this risk",
    "pricingTrends": "Expected pricing for this risk profile"
  },

  "coverageRecommendations": {
    "priorityCoverage": [
      {
        "line": "Coverage line",
        "priority": 1-5,
        "rationale": "Why this coverage is critical",
        "marketAvailability": "Ease of placement",
        "expectedTerms": "Likely terms and conditions",
        "suggestedLimits": "Recommended limits",
        "retentionStrategy": "Recommended retention",
        "keyCarriers": ["Carriers to approach"]
      }
    ],
    "gapAnalysis": [
      {"currentState": "Current coverage/gap", "recommendation": "What should be done", "urgency": "Timeline"}
    ],
    "programStructure": "Recommended overall program structure"
  },

  "alternativeRiskSolutions": {
    "captiveOptions": {
      "viable": true/false,
      "type": "Single parent/Group/RRG/etc.",
      "rationale": "Why a captive makes sense (or not)",
      "feasibilityStudy": "Key considerations",
      "domicileRecommendation": "Suggested domicile",
      "timeline": "Implementation timeline"
    },
    "riskRetentionGroups": {
      "viable": true/false,
      "existingGroups": ["Available RRGs in this space"],
      "considerations": "Pros and cons"
    },
    "parametricSolutions": {
      "viable": true/false,
      "applicableRisks": ["Risks suited for parametric"],
      "structureOptions": "How it could work",
      "triggerMechanisms": "Potential triggers"
    },
    "otherStructures": [
      {"structure": "Alternative structure", "description": "How it works", "applicability": "Fit for this client"}
    ]
  },

  "crossSellOpportunities": {
    "mercer": {
      "score": 1-10,
      "opportunities": [
        {
          "service": "Specific Mercer service",
          "rationale": "Why this client needs it",
          "problem": "Problem it solves",
          "positioning": "How to introduce to client",
          "timing": "Best time to introduce"
        }
      ]
    },
    "guyCarpenter": {
      "score": 1-10,
      "opportunities": [
        {
          "service": "Specific Guy Carpenter capability",
          "rationale": "Why relevant",
          "problem": "Problem it solves",
          "positioning": "How to introduce",
          "timing": "When to introduce"
        }
      ]
    },
    "oliverWyman": {
      "score": 1-10,
      "opportunities": [
        {
          "service": "Specific Oliver Wyman service",
          "rationale": "Why relevant",
          "problem": "Problem it solves",
          "positioning": "How to introduce",
          "timing": "When to introduce"
        }
      ]
    }
  },

  "significanceAnalysis": {
    "materialityAssessment": [
      {
        "factor": "Key risk factor",
        "materiality": "high/medium/low",
        "impactOnInsurability": "How it affects placement",
        "mitigationStrategies": ["Ways to address"]
      }
    ],
    "underwritingChallenges": [
      {"challenge": "Underwriting concern", "severity": "Impact level", "response": "How to address in submissions"}
    ],
    "competitiveAdvantages": [
      {"advantage": "Marsh advantage", "relevance": "Why it matters for this client", "proofPoints": ["Supporting evidence"]}
    ]
  },

  "sources": [
    {
      "title": "Source title/description",
      "type": "Report/Article/Database/Regulatory Filing",
      "relevance": "How it informs our analysis",
      "url": "URL if available",
      "date": "Publication date"
    }
  ],

  "executiveBrief": {
    "keyFindings": ["Top 3-5 key findings"],
    "criticalRisks": ["Most critical risks to address"],
    "immediateActions": ["Actions to take now"],
    "competitivePosition": "How Marsh can differentiate",
    "confidenceLevel": "high/medium/low based on available information"
  }
}

Provide thorough, accurate, and actionable research. All assertions should be based on real industry knowledge and best practices. Include realistic market intelligence and carrier insights based on current insurance market conditions.`;
}

function parseDeepResearchResponse(text) {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
  } catch (e) {
    console.error('Failed to parse deep research JSON:', e);
  }

  return {
    executiveBrief: {
      keyFindings: ['Research parsing failed - please review raw output'],
      rawOutput: text
    },
    parseError: true
  };
}

// Get deep research results
router.get('/:meetingId/deep-research', (req, res) => {
  try {
    const db = getMeetingsDb();
    const meeting = db.meetings.find(m => m.id === req.params.meetingId);

    if (!meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    if (!meeting.deepResearch) {
      return res.status(404).json({ error: 'Deep research not available' });
    }

    res.json(meeting.deepResearch);
  } catch (error) {
    console.error('Error fetching deep research:', error);
    res.status(500).json({ error: 'Failed to fetch deep research' });
  }
});

export default router;

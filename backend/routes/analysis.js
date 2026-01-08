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

// Analyze a meeting
router.post('/:meetingId', async (req, res) => {
  try {
    const { meetingId } = req.params;

    const db = getMeetingsDb();
    const meetingIndex = db.meetings.findIndex(m => m.id === meetingId);

    if (meetingIndex === -1) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    const meeting = db.meetings[meetingIndex];

    if (!meeting.transcript) {
      return res.status(400).json({ error: 'Meeting has not been transcribed yet' });
    }

    // Update status to analyzing
    db.meetings[meetingIndex].status = 'analyzing';
    saveMeetingsDb(db);

    console.log(`Starting analysis for meeting: ${meetingId}`);

    // Build the analysis prompt based on meeting type
    const analysisPrompt = buildAnalysisPrompt(meeting);

    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 8000,
      messages: [
        {
          role: 'user',
          content: analysisPrompt
        }
      ]
    });

    const analysisText = response.content[0].text;
    const analysis = parseAnalysisResponse(analysisText, meeting.meetingType);

    // For RFP meetings, also generate RFP-specific data
    let rfpData = null;
    let crossSellOpportunities = null;

    if (meeting.meetingType === 'Fact-Finding Session (RFP)') {
      const rfpPrompt = buildRfpPrompt(meeting, analysis);

      const rfpResponse = await anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 8000,
        messages: [
          {
            role: 'user',
            content: rfpPrompt
          }
        ]
      });

      rfpData = parseRfpResponse(rfpResponse.content[0].text);
      crossSellOpportunities = extractCrossSellOpportunities(rfpData);
    }

    // Save analysis
    const analysisPath = path.join(__dirname, '../data/analyses', `${meetingId}.json`);
    const fullAnalysis = {
      ...analysis,
      rfpData,
      crossSellOpportunities,
      analyzedAt: new Date().toISOString()
    };
    fs.writeFileSync(analysisPath, JSON.stringify(fullAnalysis, null, 2));

    // Update meeting in database
    db.meetings[meetingIndex].analysis = analysis;
    db.meetings[meetingIndex].rfpData = rfpData;
    db.meetings[meetingIndex].crossSellOpportunities = crossSellOpportunities;
    db.meetings[meetingIndex].status = 'analyzed';
    db.meetings[meetingIndex].analyzedAt = new Date().toISOString();
    saveMeetingsDb(db);

    console.log(`Analysis complete for meeting: ${meetingId}`);

    res.json({
      success: true,
      analysis: fullAnalysis
    });
  } catch (error) {
    console.error('Analysis error:', error);

    const db = getMeetingsDb();
    const meetingIndex = db.meetings.findIndex(m => m.id === req.params.meetingId);
    if (meetingIndex !== -1) {
      db.meetings[meetingIndex].status = 'error';
      db.meetings[meetingIndex].error = error.message;
      saveMeetingsDb(db);
    }

    res.status(500).json({
      error: 'Analysis failed',
      details: error.message
    });
  }
});

function buildAnalysisPrompt(meeting) {
  const transcriptText = meeting.transcript.text;
  const meetingType = meeting.meetingType;
  const clientName = meeting.clientName || 'the client';

  return `You are an expert insurance and risk management consultant at D&W Holdings, analyzing a meeting transcript.

Meeting Details:
- Title: ${meeting.title}
- Type: ${meetingType}
- Client: ${clientName}
- Date: ${new Date(meeting.createdAt).toLocaleDateString()}

Transcript:
"""
${transcriptText}
"""

Please provide a comprehensive analysis in the following JSON format:

{
  "summary": "A detailed 3-5 paragraph summary of the meeting, covering key topics discussed, major points raised, and overall context",

  "keyTopics": [
    {"topic": "Topic name", "description": "Brief description", "importance": "high/medium/low"}
  ],

  "decisions": [
    {"decision": "What was decided", "context": "Why/how it was decided", "stakeholders": ["names"]}
  ],

  "actionItems": [
    {
      "task": "What needs to be done",
      "owner": "Who is responsible (or 'TBD')",
      "deadline": "When it's due (or 'TBD')",
      "priority": "high/medium/low",
      "notes": "Additional context"
    }
  ],

  "participants": [
    {"name": "Name mentioned", "role": "Their role if mentioned", "organization": "Their company"}
  ],

  "businessImplications": [
    {"implication": "Strategic or business implication", "impact": "How it affects the client/engagement", "recommendation": "Suggested approach"}
  ],

  "riskExposures": [
    {"exposure": "Risk identified", "severity": "high/medium/low", "coverageType": "Related insurance line"}
  ],

  "followUpQuestions": [
    "Question that should be asked in follow-up"
  ],

  "sentiment": {
    "overall": "positive/neutral/negative",
    "clientEngagement": "high/medium/low",
    "dealProbability": "percentage or qualitative assessment"
  },

  "quotableStatements": [
    {"quote": "Direct quote from transcript", "speaker": "Who said it", "significance": "Why it matters"}
  ]
}

Ensure your analysis is thorough, professional, and actionable. Focus on insights that would help a D&W Holdings consultant serve this client effectively.`;
}

function buildRfpPrompt(meeting, analysis) {
  const transcriptText = meeting.transcript.text;

  return `You are an expert insurance consultant at D&W Holdings preparing an RFP response based on a fact-finding session.

Meeting Transcript:
"""
${transcriptText}
"""

Previous Analysis Summary:
${analysis.summary}

Please generate a comprehensive RFP preparation package in the following JSON format:

{
  "factFindingSummary": {
    "clientName": "Full client name",
    "industry": "Industry/sector",
    "location": "Headquarters and key locations",
    "employeeCount": "Number of employees if mentioned",
    "revenue": "Revenue/size if mentioned",
    "currentProgram": {
      "incumbent": "Current broker/insurer",
      "expirationDate": "Policy renewal date",
      "currentCoverage": ["List of current coverage lines"],
      "premiumSpend": "Current premium if mentioned"
    },
    "painPoints": [
      {"issue": "Pain point", "severity": "high/medium/low", "impact": "Business impact"}
    ],
    "riskExposures": [
      {"exposure": "Risk type", "description": "Details", "currentlyInsured": true/false}
    ],
    "coverageGaps": [
      {"gap": "Coverage gap identified", "recommendation": "How to address"}
    ],
    "budgetParameters": "Budget constraints or expectations",
    "timeline": {
      "decisionDate": "When they plan to decide",
      "effectiveDate": "When coverage should start",
      "milestones": ["Key dates/milestones"]
    },
    "decisionMakers": [
      {"name": "Name", "title": "Title", "influence": "Role in decision"}
    ],
    "competitiveLandscape": {
      "otherBrokers": ["Other brokers involved"],
      "incumbentStrengths": "What they like about current broker",
      "incumbentWeaknesses": "Pain points with current broker"
    }
  },

  "rfpDraft": {
    "executiveSummary": "2-3 paragraph executive summary of D&W Holdings' understanding of client needs and proposed approach",
    "scopeOfServices": [
      {"service": "Service offering", "description": "How D&W Holdings will deliver", "value": "Value to client"}
    ],
    "riskProfile": "Comprehensive risk profile based on discussion",
    "recommendedCoverage": [
      {
        "line": "Coverage line (e.g., General Liability, Property, Cyber)",
        "rationale": "Why this coverage is needed",
        "considerations": "Special considerations for this client",
        "marketingApproach": "How we'll approach the market"
      }
    ],
    "dwValueProposition": {
      "globalCapabilities": "How D&W Holdings' global reach benefits this client",
      "industryExpertise": "Relevant industry experience",
      "dataAndAnalytics": "Analytics capabilities to highlight",
      "claims": "Claims advocacy and management",
      "riskEngineering": "Risk control and engineering services"
    },
    "proposedTimeline": [
      {"phase": "Phase name", "activities": "What happens", "duration": "Time required"}
    ],
    "teamStructure": [
      {"role": "Team role", "responsibility": "What they handle", "qualifications": "Relevant experience"}
    ]
  },

  "crossSellOpportunities": {
    "benefitsConsulting": {
      "relevant": true/false,
      "opportunities": [
        {"service": "Benefits & Consulting Division service", "rationale": "Why relevant", "positioning": "How to introduce"}
      ]
    },
    "riskCapitalSolutions": {
      "relevant": true/false,
      "opportunities": [
        {"service": "Risk Capital Solutions Division service", "rationale": "Why relevant", "positioning": "How to introduce"}
      ]
    },
    "strategicAdvisory": {
      "relevant": true/false,
      "opportunities": [
        {"service": "Strategic Advisory Division service", "rationale": "Why relevant", "positioning": "How to introduce"}
      ]
    }
  },

  "nextSteps": [
    {"step": "Action item", "owner": "D&W Holdings/Client/Both", "timing": "When", "notes": "Additional context"}
  ],

  "winStrategy": {
    "keyDifferentiators": ["What will help us win"],
    "competitiveThreats": ["What competitors might emphasize"],
    "mustWinFactors": ["Critical success factors"],
    "pricingStrategy": "High-level pricing approach"
  }
}

Be specific, actionable, and focused on helping D&W Holdings win this opportunity.`;
}

function parseAnalysisResponse(text, meetingType) {
  try {
    // Extract JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
  } catch (e) {
    console.error('Failed to parse analysis JSON:', e);
  }

  // Return structured fallback if parsing fails
  return {
    summary: text,
    keyTopics: [],
    decisions: [],
    actionItems: [],
    participants: [],
    businessImplications: [],
    riskExposures: [],
    followUpQuestions: [],
    sentiment: { overall: 'neutral', clientEngagement: 'medium' },
    quotableStatements: [],
    parseError: true
  };
}

function parseRfpResponse(text) {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
  } catch (e) {
    console.error('Failed to parse RFP JSON:', e);
  }

  return {
    factFindingSummary: { clientName: 'Unknown' },
    rfpDraft: {},
    crossSellOpportunities: {},
    nextSteps: [],
    winStrategy: {},
    parseError: true
  };
}

function extractCrossSellOpportunities(rfpData) {
  if (!rfpData || !rfpData.crossSellOpportunities) {
    return null;
  }

  const opportunities = [];
  const crossSell = rfpData.crossSellOpportunities;

  // Support both old format (mercer, guyCarpenter, oliverWyman) and new format
  if (crossSell.mercer?.relevant || crossSell.benefitsConsulting?.relevant) {
    opportunities.push({
      company: 'Mercer',
      division: 'Benefits & Consulting Division',
      focus: 'Employee Benefits, Health & Wellness, Retirement',
      ...(crossSell.mercer || crossSell.benefitsConsulting)
    });
  }

  if (crossSell.guyCarpenter?.relevant || crossSell.riskCapitalSolutions?.relevant) {
    opportunities.push({
      company: 'Guy Carpenter',
      division: 'Risk Capital Solutions Division',
      focus: 'Reinsurance Solutions',
      ...(crossSell.guyCarpenter || crossSell.riskCapitalSolutions)
    });
  }

  if (crossSell.oliverWyman?.relevant || crossSell.strategicAdvisory?.relevant) {
    opportunities.push({
      company: 'Oliver Wyman',
      division: 'Strategic Advisory Division',
      focus: 'Strategic Consulting, Operational Resilience',
      ...(crossSell.oliverWyman || crossSell.strategicAdvisory)
    });
  }

  return opportunities;
}

export default router;

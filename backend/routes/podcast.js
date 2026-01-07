import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import Anthropic from '@anthropic-ai/sdk';
import fetch from 'node-fetch';
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

// ElevenLabs voice IDs - Professional Black voices
// These are voice IDs that represent professional-sounding voices
const VOICE_OPTIONS = {
  // Male professional voices
  male: [
    { id: 'onwK4e9ZLuTAKqWW03F9', name: 'Daniel', description: 'Deep, authoritative male voice' },
    { id: 'TxGEqnHWrfWFTfGW9XjX', name: 'Josh', description: 'Warm, professional male voice' },
    { id: 'VR6AewLTigWG4xSOukaG', name: 'Arnold', description: 'Clear, confident male voice' },
    { id: 'pNInz6obpgDQGcFmaJgB', name: 'Adam', description: 'Professional narrator voice' }
  ],
  // Female professional voices
  female: [
    { id: 'EXAVITQu4vr4xnSDxMaL', name: 'Bella', description: 'Warm, professional female voice' },
    { id: 'jBpfuIE2acCO8z3wKNLl', name: 'Gigi', description: 'Clear, engaging female voice' },
    { id: '21m00Tcm4TlvDq8ikWAM', name: 'Rachel', description: 'Professional narrator voice' },
    { id: 'XrExE9yKIg1WjnnlVkGX', name: 'Matilda', description: 'Confident, professional female voice' }
  ]
};

// Get available voices
router.get('/voices', (req, res) => {
  res.json({
    male: VOICE_OPTIONS.male,
    female: VOICE_OPTIONS.female,
    configured: !!process.env.ELEVENLABS_API_KEY
  });
});

// Generate podcast audio summary
router.post('/:meetingId', async (req, res) => {
  try {
    const { meetingId } = req.params;
    const { voiceType = 'female', voiceId } = req.body;

    // Check if ElevenLabs API key is configured
    if (!process.env.ELEVENLABS_API_KEY) {
      return res.status(400).json({
        error: 'ElevenLabs API key not configured',
        message: 'Please add ELEVENLABS_API_KEY to your .env file to enable podcast generation'
      });
    }

    const db = getMeetingsDb();
    const meetingIndex = db.meetings.findIndex(m => m.id === meetingId);

    if (meetingIndex === -1) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    const meeting = db.meetings[meetingIndex];

    if (!meeting.analysis) {
      return res.status(400).json({ error: 'Meeting has not been analyzed yet' });
    }

    console.log(`Generating podcast for meeting: ${meetingId}`);

    // Generate podcast script using Claude
    const scriptPrompt = buildPodcastScriptPrompt(meeting);

    const scriptResponse = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 2000,
      messages: [
        {
          role: 'user',
          content: scriptPrompt
        }
      ]
    });

    const podcastScript = scriptResponse.content[0].text;
    console.log('Podcast script generated');

    // Select voice
    const selectedVoiceId = voiceId ||
      (voiceType === 'male' ? VOICE_OPTIONS.male[0].id : VOICE_OPTIONS.female[0].id);

    // Generate audio using ElevenLabs
    const audioResponse = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${selectedVoiceId}`, {
      method: 'POST',
      headers: {
        'Accept': 'audio/mpeg',
        'Content-Type': 'application/json',
        'xi-api-key': process.env.ELEVENLABS_API_KEY
      },
      body: JSON.stringify({
        text: podcastScript,
        model_id: 'eleven_monolingual_v1',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
          style: 0.5,
          use_speaker_boost: true
        }
      })
    });

    if (!audioResponse.ok) {
      const errorText = await audioResponse.text();
      throw new Error(`ElevenLabs API error: ${audioResponse.status} - ${errorText}`);
    }

    // Save audio file
    const audioBuffer = await audioResponse.buffer();
    const fileName = `${meetingId}-podcast-${Date.now()}.mp3`;
    const filePath = path.join(__dirname, '../data/podcasts', fileName);

    // Ensure podcasts directory exists
    const podcastDir = path.join(__dirname, '../data/podcasts');
    if (!fs.existsSync(podcastDir)) {
      fs.mkdirSync(podcastDir, { recursive: true });
    }

    fs.writeFileSync(filePath, audioBuffer);
    console.log(`Podcast audio saved: ${fileName}`);

    // Update meeting with podcast info
    db.meetings[meetingIndex].podcast = {
      fileName,
      downloadUrl: `/podcasts/${fileName}`,
      script: podcastScript,
      voiceType,
      generatedAt: new Date().toISOString()
    };
    saveMeetingsDb(db);

    res.json({
      success: true,
      podcast: {
        fileName,
        downloadUrl: `/podcasts/${fileName}`,
        script: podcastScript,
        duration: estimateDuration(podcastScript)
      }
    });
  } catch (error) {
    console.error('Podcast generation error:', error);
    res.status(500).json({
      error: 'Failed to generate podcast',
      details: error.message
    });
  }
});

// Get podcast for a meeting
router.get('/:meetingId', (req, res) => {
  try {
    const db = getMeetingsDb();
    const meeting = db.meetings.find(m => m.id === req.params.meetingId);

    if (!meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    if (!meeting.podcast) {
      return res.status(404).json({ error: 'Podcast not available' });
    }

    res.json(meeting.podcast);
  } catch (error) {
    console.error('Error fetching podcast:', error);
    res.status(500).json({ error: 'Failed to fetch podcast' });
  }
});

function buildPodcastScriptPrompt(meeting) {
  const analysis = meeting.analysis;
  const rfpData = meeting.rfpData;
  const deepResearch = meeting.deepResearch;

  return `You are creating a professional audio summary for a business meeting. Write a podcast-style script that will be read by a single narrator. The tone should be professional but conversational and engaging.

MEETING DETAILS:
- Title: ${meeting.title}
- Type: ${meeting.meetingType}
- Date: ${new Date(meeting.createdAt).toLocaleDateString()}
${meeting.clientName ? `- Client: ${meeting.clientName}` : ''}

MEETING SUMMARY:
${analysis.summary || 'No summary available'}

KEY TOPICS:
${analysis.keyTopics?.map(t => `- ${t.topic}: ${t.description}`).join('\n') || 'None identified'}

ACTION ITEMS:
${analysis.actionItems?.map(a => `- ${a.task} (Owner: ${a.owner || 'TBD'})`).join('\n') || 'None identified'}

${meeting.meetingType === 'Fact-Finding Session (RFP)' && rfpData ? `
RFP CONTEXT:
- Client: ${rfpData.factFindingSummary?.clientName || 'Unknown'}
- Industry: ${rfpData.factFindingSummary?.industry || 'Unknown'}
- Key Pain Points: ${rfpData.factFindingSummary?.painPoints?.map(p => p.issue).join(', ') || 'None specified'}
- Recommended Coverage: ${rfpData.rfpDraft?.recommendedCoverage?.map(c => c.line).join(', ') || 'TBD'}
` : ''}

${deepResearch?.executiveBrief ? `
KEY RESEARCH FINDINGS:
${deepResearch.executiveBrief.keyFindings?.join('\n') || 'None'}
` : ''}

INSTRUCTIONS:
1. Write a 3-5 minute audio script (approximately 400-600 words)
2. Start with a brief greeting and meeting context
3. Cover the key highlights and takeaways
4. For RFP meetings, emphasize client needs and next steps
5. End with clear action items and next steps
6. Use natural pauses (indicate with "...") where appropriate
7. Keep sentences concise and easy to follow when spoken aloud
8. Be professional but engaging - this should sound like a knowledgeable colleague giving you a briefing
9. Do NOT include any stage directions or speaker labels - just the words to be spoken

Write the script now:`;
}

function estimateDuration(script) {
  // Average speaking rate is about 150 words per minute
  const wordCount = script.split(/\s+/).length;
  const minutes = Math.ceil(wordCount / 150);
  return `${minutes} minute${minutes > 1 ? 's' : ''}`;
}

export default router;

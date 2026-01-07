import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import OpenAI from 'openai';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const router = express.Router();

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
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

// Transcribe a meeting
router.post('/:meetingId', async (req, res) => {
  try {
    const { meetingId } = req.params;

    // Get meeting from database
    const db = getMeetingsDb();
    const meetingIndex = db.meetings.findIndex(m => m.id === meetingId);

    if (meetingIndex === -1) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    const meeting = db.meetings[meetingIndex];

    // Check if audio file exists
    const audioPath = path.join(__dirname, '../data/recordings', meeting.audioFile);
    if (!fs.existsSync(audioPath)) {
      return res.status(404).json({ error: 'Audio file not found' });
    }

    // Update status to transcribing
    db.meetings[meetingIndex].status = 'transcribing';
    saveMeetingsDb(db);

    // Transcribe using Whisper
    console.log(`Starting transcription for meeting: ${meetingId}`);

    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(audioPath),
      model: 'whisper-1',
      response_format: 'verbose_json',
      timestamp_granularities: ['segment', 'word']
    });

    // Format transcript with timestamps
    const formattedTranscript = {
      text: transcription.text,
      language: transcription.language,
      duration: transcription.duration,
      segments: transcription.segments?.map(seg => ({
        id: seg.id,
        start: seg.start,
        end: seg.end,
        text: seg.text,
        timestamp: formatTimestamp(seg.start)
      })) || [],
      words: transcription.words || []
    };

    // Save transcript to file
    const transcriptPath = path.join(__dirname, '../data/transcripts', `${meetingId}.json`);
    fs.writeFileSync(transcriptPath, JSON.stringify(formattedTranscript, null, 2));

    // Update meeting in database
    db.meetings[meetingIndex].transcript = formattedTranscript;
    db.meetings[meetingIndex].duration = transcription.duration;
    db.meetings[meetingIndex].status = 'transcribed';
    db.meetings[meetingIndex].transcribedAt = new Date().toISOString();
    saveMeetingsDb(db);

    console.log(`Transcription complete for meeting: ${meetingId}`);

    res.json({
      success: true,
      transcript: formattedTranscript
    });
  } catch (error) {
    console.error('Transcription error:', error);

    // Update status to error
    const db = getMeetingsDb();
    const meetingIndex = db.meetings.findIndex(m => m.id === req.params.meetingId);
    if (meetingIndex !== -1) {
      db.meetings[meetingIndex].status = 'error';
      db.meetings[meetingIndex].error = error.message;
      saveMeetingsDb(db);
    }

    res.status(500).json({
      error: 'Transcription failed',
      details: error.message
    });
  }
});

// Get transcript for a meeting
router.get('/:meetingId', (req, res) => {
  try {
    const db = getMeetingsDb();
    const meeting = db.meetings.find(m => m.id === req.params.meetingId);

    if (!meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    if (!meeting.transcript) {
      return res.status(404).json({ error: 'Transcript not available' });
    }

    res.json(meeting.transcript);
  } catch (error) {
    console.error('Error fetching transcript:', error);
    res.status(500).json({ error: 'Failed to fetch transcript' });
  }
});

// Helper function to format timestamp
function formatTimestamp(seconds) {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

export default router;

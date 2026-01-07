import express from 'express';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const router = express.Router();

// Configure multer for audio file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = path.join(__dirname, '../data/recordings');
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.webm';
    cb(null, `${Date.now()}-${uuidv4()}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 500 * 1024 * 1024 }, // 500MB max
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['audio/webm', 'audio/wav', 'audio/mp3', 'audio/mpeg', 'audio/ogg', 'audio/mp4', 'video/webm'];
    if (allowedTypes.includes(file.mimetype) || file.originalname.match(/\.(webm|wav|mp3|ogg|m4a)$/i)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only audio files are allowed.'));
    }
  }
});

// Meetings database file
const MEETINGS_DB_PATH = path.join(__dirname, '../data/meetings.json');

// Helper to read/write meetings database
const getMeetingsDb = () => {
  if (!fs.existsSync(MEETINGS_DB_PATH)) {
    fs.writeFileSync(MEETINGS_DB_PATH, JSON.stringify({ meetings: [] }, null, 2));
  }
  return JSON.parse(fs.readFileSync(MEETINGS_DB_PATH, 'utf-8'));
};

const saveMeetingsDb = (data) => {
  fs.writeFileSync(MEETINGS_DB_PATH, JSON.stringify(data, null, 2));
};

// Get all meetings
router.get('/', (req, res) => {
  try {
    const db = getMeetingsDb();
    const { type, confidentiality, search } = req.query;

    let meetings = db.meetings;

    // Filter by meeting type
    if (type) {
      meetings = meetings.filter(m => m.meetingType === type);
    }

    // Filter by confidentiality
    if (confidentiality) {
      meetings = meetings.filter(m => m.confidentiality === confidentiality);
    }

    // Search in title, transcript, or analysis
    if (search) {
      const searchLower = search.toLowerCase();
      meetings = meetings.filter(m =>
        m.title?.toLowerCase().includes(searchLower) ||
        m.transcript?.toLowerCase().includes(searchLower) ||
        m.analysis?.summary?.toLowerCase().includes(searchLower)
      );
    }

    // Sort by date, newest first
    meetings.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json(meetings);
  } catch (error) {
    console.error('Error fetching meetings:', error);
    res.status(500).json({ error: 'Failed to fetch meetings' });
  }
});

// Get single meeting
router.get('/:id', (req, res) => {
  try {
    const db = getMeetingsDb();
    const meeting = db.meetings.find(m => m.id === req.params.id);

    if (!meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    res.json(meeting);
  } catch (error) {
    console.error('Error fetching meeting:', error);
    res.status(500).json({ error: 'Failed to fetch meeting' });
  }
});

// Upload new recording
router.post('/upload', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file provided' });
    }

    const { title, meetingType, confidentiality, participants, clientName, password } = req.body;

    const meeting = {
      id: uuidv4(),
      title: title || `Meeting ${new Date().toLocaleDateString()}`,
      meetingType: meetingType || 'Client Check-in',
      confidentiality: confidentiality || (meetingType === 'Fact-Finding Session (RFP)' ? 'Confidential' : 'Internal'),
      participants: participants ? JSON.parse(participants) : [],
      clientName: clientName || '',
      hasPassword: !!password,
      passwordHash: password ? Buffer.from(password).toString('base64') : null,
      audioFile: req.file.filename,
      audioPath: `/recordings/${req.file.filename}`,
      duration: 0,
      fileSize: req.file.size,
      createdAt: new Date().toISOString(),
      status: 'recorded',
      transcript: null,
      analysis: null,
      rfpData: null,
      deepResearch: null,
      crossSellOpportunities: null
    };

    const db = getMeetingsDb();
    db.meetings.push(meeting);
    saveMeetingsDb(db);

    res.json({
      success: true,
      meeting
    });
  } catch (error) {
    console.error('Error uploading recording:', error);
    res.status(500).json({ error: 'Failed to upload recording' });
  }
});

// Update meeting
router.patch('/:id', (req, res) => {
  try {
    const db = getMeetingsDb();
    const index = db.meetings.findIndex(m => m.id === req.params.id);

    if (index === -1) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    db.meetings[index] = { ...db.meetings[index], ...req.body, updatedAt: new Date().toISOString() };
    saveMeetingsDb(db);

    res.json(db.meetings[index]);
  } catch (error) {
    console.error('Error updating meeting:', error);
    res.status(500).json({ error: 'Failed to update meeting' });
  }
});

// Delete meeting
router.delete('/:id', (req, res) => {
  try {
    const db = getMeetingsDb();
    const index = db.meetings.findIndex(m => m.id === req.params.id);

    if (index === -1) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    const meeting = db.meetings[index];

    // Delete audio file
    if (meeting.audioFile) {
      const audioPath = path.join(__dirname, '../data/recordings', meeting.audioFile);
      if (fs.existsSync(audioPath)) {
        fs.unlinkSync(audioPath);
      }
    }

    db.meetings.splice(index, 1);
    saveMeetingsDb(db);

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting meeting:', error);
    res.status(500).json({ error: 'Failed to delete meeting' });
  }
});

export default router;

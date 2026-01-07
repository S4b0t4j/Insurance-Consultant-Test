import express from 'express';
import cors from 'cors';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import fs from 'fs';

// Route imports
import recordingsRouter from './routes/recordings.js';
import transcriptionRouter from './routes/transcription.js';
import analysisRouter from './routes/analysis.js';
import researchRouter from './routes/research.js';
import exportRouter from './routes/export.js';
import podcastRouter from './routes/podcast.js';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Ensure data directories exist
const dataDirectories = [
  'data/recordings',
  'data/transcripts',
  'data/analyses',
  'data/exports',
  'data/podcasts'
];

dataDirectories.forEach(dir => {
  const fullPath = path.join(__dirname, dir);
  if (!fs.existsSync(fullPath)) {
    fs.mkdirSync(fullPath, { recursive: true });
  }
});

// Static file serving for recordings and exports
app.use('/recordings', express.static(path.join(__dirname, 'data/recordings')));
app.use('/exports', express.static(path.join(__dirname, 'data/exports')));
app.use('/podcasts', express.static(path.join(__dirname, 'data/podcasts')));

// API Routes
app.use('/api/recordings', recordingsRouter);
app.use('/api/transcription', transcriptionRouter);
app.use('/api/analysis', analysisRouter);
app.use('/api/research', researchRouter);
app.use('/api/export', exportRouter);
app.use('/api/podcast', podcastRouter);

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// API key status check
app.get('/api/config/status', (req, res) => {
  res.json({
    anthropic: !!process.env.ANTHROPIC_API_KEY,
    openai: !!process.env.OPENAI_API_KEY,
    elevenlabs: !!process.env.ELEVENLABS_API_KEY,
    unsplash: !!process.env.UNSPLASH_ACCESS_KEY
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🎙️  MARSH MEETING ANALYZER                                  ║
║   Insurance Consulting Intelligence Tool                      ║
║                                                               ║
║   Server running on: http://localhost:${PORT}                   ║
║                                                               ║
║   API Status:                                                 ║
║   • Anthropic Claude: ${process.env.ANTHROPIC_API_KEY ? '✅ Configured' : '❌ Not configured'}                    ║
║   • OpenAI Whisper:   ${process.env.OPENAI_API_KEY ? '✅ Configured' : '❌ Not configured'}                    ║
║   • ElevenLabs TTS:   ${process.env.ELEVENLABS_API_KEY ? '✅ Configured' : '⚠️  Optional'}                     ║
║   • Unsplash Images:  ${process.env.UNSPLASH_ACCESS_KEY ? '✅ Configured' : '⚠️  Optional'}                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
  `);
});

export default app;

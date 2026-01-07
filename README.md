# Marsh Meeting Analyzer

A comprehensive meeting recording and analysis application designed for insurance/risk management consulting work at Marsh. This tool helps with client meetings, fact-finding sessions, and RFP development using AI-powered transcription and analysis.

![Marsh Meeting Analyzer](https://img.shields.io/badge/Marsh-Meeting%20Analyzer-004B87?style=for-the-badge)

## Features

### Core Functionality

- **Audio Recording**: Clean, intuitive interface to start/stop meeting recordings
- **Whisper AI Transcription**: Accurate, timestamped transcripts using OpenAI's Whisper
- **Claude AI Analysis**: Comprehensive meeting summaries, action items, and strategic insights
- **Meeting Type Support**:
  - Sales/Discovery
  - Fact-Finding Session (RFP)
  - Strategy
  - Client Check-in
  - Internal Planning

### RFP Builder & Fact-Finding Module

For RFP-type meetings, the application provides specialized features:

- **Structured Fact-Finding Summary**
  - Client profile and industry analysis
  - Current insurance program overview
  - Pain points and risk exposures
  - Coverage gaps and recommendations

- **Automated RFP Draft Generator**
  - Executive summary of client needs
  - Scope of services
  - Recommended coverage lines
  - Marsh value proposition

- **Deep Research Component**
  - Geographic/regional risk factors
  - Industry-specific challenges
  - Market conditions and carrier appetite
  - Alternative risk solutions (captives, parametric)

### Marsh McLennan Ecosystem Integration

Automatic identification of cross-sell opportunities for:
- **Mercer**: Employee benefits, health & wellness, retirement
- **Guy Carpenter**: Reinsurance solutions
- **Oliver Wyman**: Strategic consulting, operational resilience

### Export Options

- **PowerPoint Generator**: Professional 16:9 presentations (Internal/External versions)
- **Podcast Generator**: Audio summaries using ElevenLabs TTS
- **PDF/Text Export**: Standard document exports
- **Email Integration**: One-click email summaries

### Security Features

- Confidentiality tagging (Public, Internal, Confidential, Highly Confidential)
- Password protection option
- RFP sessions default to Confidential
- All data stored locally

## Prerequisites

- **Node.js** 18+
- **npm** or **yarn**
- **API Keys** (see Configuration section)

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd marsh-meeting-analyzer
   ```

2. **Install dependencies**
   ```bash
   npm run install:all
   ```

3. **Configure API keys**
   ```bash
   cd backend
   cp .env.example .env
   ```

   Edit `.env` with your API keys:
   ```env
   # Required
   ANTHROPIC_API_KEY=your_anthropic_api_key
   OPENAI_API_KEY=your_openai_api_key

   # Optional (for additional features)
   ELEVENLABS_API_KEY=your_elevenlabs_api_key
   UNSPLASH_ACCESS_KEY=your_unsplash_key
   ```

## Getting API Keys

### Required APIs

1. **Anthropic Claude API** (Required for AI analysis)
   - Visit: https://console.anthropic.com/
   - Create an account and generate an API key
   - Used for: Meeting analysis, RFP generation, Deep Research

2. **OpenAI API** (Required for transcription)
   - Visit: https://platform.openai.com/api-keys
   - Create an account and generate an API key
   - Used for: Whisper transcription

### Optional APIs

3. **ElevenLabs API** (Optional - for podcast generation)
   - Visit: https://elevenlabs.io/
   - Create an account and get API key
   - Used for: Text-to-speech audio summaries

4. **Unsplash API** (Optional - for PowerPoint images)
   - Visit: https://unsplash.com/developers
   - Create an application to get access key
   - Used for: Adding images to presentations

## Running the Application

### Development Mode

```bash
npm run dev
```

This starts both the backend (port 3001) and frontend (port 3000) in development mode.

### Access the Application

Open your browser to: **http://localhost:3000**

### Individual Services

```bash
# Backend only
npm run dev:backend

# Frontend only
npm run dev:frontend
```

## Usage Guide

### Recording a Meeting

1. Click "Record" in the navigation
2. Fill in meeting details:
   - Meeting title
   - Meeting type (select RFP for fact-finding sessions)
   - Client name
   - Participants
   - Confidentiality level
3. Click the microphone button to start recording
4. Use pause/resume as needed
5. Click stop when finished
6. Review the recording and click "Save & Analyze"

### Processing Pipeline

After saving a recording, the processing pipeline begins:

1. **Transcription**: Audio is transcribed using Whisper AI
2. **Analysis**: Claude AI analyzes the transcript for insights
3. **Deep Research** (RFP only): Additional market and risk research

### RFP Workflow

For Fact-Finding sessions:

1. After analysis completes, the RFP tab becomes available
2. Review the structured fact-finding summary
3. Click "Run Deep Research" for market intelligence
4. Use the generated RFP draft as a starting point
5. Export to PowerPoint or PDF for presentations

### Exporting

Navigate to the Exports tab to:
- Generate Internal or External PowerPoint presentations
- Create audio summaries (requires ElevenLabs)
- Export as PDF or plain text
- Email the summary directly

## Project Structure

```
marsh-meeting-analyzer/
├── backend/
│   ├── routes/
│   │   ├── recordings.js   # Meeting CRUD operations
│   │   ├── transcription.js # Whisper integration
│   │   ├── analysis.js     # Claude AI analysis
│   │   ├── research.js     # Deep Research feature
│   │   ├── export.js       # PowerPoint/PDF generation
│   │   └── podcast.js      # ElevenLabs TTS
│   ├── data/               # Local storage
│   │   ├── recordings/     # Audio files
│   │   ├── transcripts/    # Transcript JSON
│   │   ├── analyses/       # Analysis results
│   │   ├── exports/        # Generated files
│   │   └── podcasts/       # Audio summaries
│   ├── server.js           # Express server
│   └── package.json
├── frontend/
│   ├── src/
│   │   ├── components/     # React components
│   │   ├── pages/          # Page components
│   │   ├── contexts/       # React contexts
│   │   ├── utils/          # API utilities
│   │   └── styles/         # CSS/Tailwind
│   ├── index.html
│   └── package.json
└── package.json            # Root package
```

## Technology Stack

- **Frontend**: React 18, Vite, TailwindCSS, React Router
- **Backend**: Node.js, Express
- **AI/ML**:
  - OpenAI Whisper (transcription)
  - Anthropic Claude (analysis)
  - ElevenLabs (text-to-speech)
- **Export**: PptxGenJS (PowerPoint)

## API Rate Limits & Costs

Be aware of API usage costs:
- **OpenAI Whisper**: ~$0.006/minute of audio
- **Anthropic Claude**: ~$3-15 per 1M tokens (varies by model)
- **ElevenLabs**: Free tier includes limited characters

## Troubleshooting

### Microphone Not Working
- Ensure browser has microphone permissions
- Check that no other application is using the microphone
- Try a different browser (Chrome/Edge recommended)

### Transcription Failing
- Verify OPENAI_API_KEY is set correctly
- Check API key has sufficient credits
- Ensure audio file isn't too large (500MB limit)

### Analysis Failing
- Verify ANTHROPIC_API_KEY is set correctly
- Check for API rate limits
- Review backend logs for detailed errors

### PowerPoint Generation Issues
- Ensure meeting has been analyzed
- Check backend logs for specific errors
- Try regenerating after a few seconds

## Security Considerations

- All data is stored locally on your machine
- API keys are stored in `.env` (never commit this file)
- Confidential meetings are tagged but not encrypted at rest
- Consider additional encryption for highly sensitive data

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

Proprietary - Internal Use Only

---

**MARSH** - A business of Marsh McLennan

*This tool is designed to enhance productivity for Marsh consultants. All client data should be handled in accordance with Marsh McLennan's data privacy and security policies.*

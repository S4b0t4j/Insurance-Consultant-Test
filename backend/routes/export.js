import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import PptxGenJS from 'pptxgenjs';
import fetch from 'node-fetch';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const router = express.Router();

// Meetings database helpers
const MEETINGS_DB_PATH = path.join(__dirname, '../data/meetings.json');

const getMeetingsDb = () => {
  if (!fs.existsSync(MEETINGS_DB_PATH)) {
    return { meetings: [] };
  }
  return JSON.parse(fs.readFileSync(MEETINGS_DB_PATH, 'utf-8'));
};

// D&W Holdings brand colors
const COLORS = {
  dwNavy: '0a1628',
  dwNavyLight: '1a2d4a',
  dwTeal: '0d9488',
  dwTealDark: '0f766e',
  dwGold: 'c9a227',
  accent: '00A3E0',
  white: 'FFFFFF',
  lightGray: 'F5F5F5',
  darkGray: '333333',
  text: '2C3E50'
};

// Generate PowerPoint
router.post('/:meetingId/powerpoint', async (req, res) => {
  try {
    const { meetingId } = req.params;
    const { type = 'internal' } = req.body; // 'internal' or 'external'

    const db = getMeetingsDb();
    const meeting = db.meetings.find(m => m.id === meetingId);

    if (!meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    if (!meeting.analysis) {
      return res.status(400).json({ error: 'Meeting has not been analyzed yet' });
    }

    console.log(`Generating ${type} PowerPoint for meeting: ${meetingId}`);

    const pptx = new PptxGenJS();
    pptx.layout = 'LAYOUT_WIDE'; // 16:9 aspect ratio
    pptx.author = 'D&W Holdings Meeting Analyzer';
    pptx.title = meeting.title;
    pptx.subject = `${type === 'external' ? 'Client' : 'Internal'} Presentation`;

    // Define master slide
    pptx.defineSlideMaster({
      title: 'DW_MASTER',
      background: { color: COLORS.white },
      objects: [
        { rect: { x: 0, y: 0, w: '100%', h: 0.5, fill: { color: COLORS.dwNavy } } },
        { text: { text: 'D&W HOLDINGS', options: { x: 0.5, y: 5.1, w: 2, h: 0.3, fontSize: 10, color: COLORS.dwNavy, fontFace: 'Arial' } } }
      ]
    });

    // Title Slide
    const titleSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
    titleSlide.addShape('rect', { x: 0, y: 0, w: '100%', h: '100%', fill: { color: COLORS.dwNavy } });
    titleSlide.addText(meeting.title, {
      x: 0.5, y: 2, w: 12.33, h: 1,
      fontSize: 36, color: COLORS.white, fontFace: 'Arial', bold: true, align: 'center'
    });
    titleSlide.addText(type === 'external' ? 'Client Presentation' : 'Internal Strategy Review', {
      x: 0.5, y: 3, w: 12.33, h: 0.5,
      fontSize: 20, color: COLORS.dwTeal, fontFace: 'Arial', align: 'center'
    });
    titleSlide.addText(new Date(meeting.createdAt).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }), {
      x: 0.5, y: 4, w: 12.33, h: 0.3,
      fontSize: 14, color: COLORS.white, fontFace: 'Arial', align: 'center'
    });

    // Executive Summary Slide
    const summarySlide = pptx.addSlide({ masterName: 'DW_MASTER' });
    addSlideTitle(summarySlide, 'Executive Summary');
    const summaryText = meeting.analysis.summary || 'No summary available';
    summarySlide.addText(truncateText(summaryText, 800), {
      x: 0.5, y: 1.2, w: 12.33, h: 4,
      fontSize: 14, color: COLORS.text, fontFace: 'Arial', valign: 'top', align: 'left'
    });

    // Key Topics Slide
    if (meeting.analysis.keyTopics?.length > 0) {
      const topicsSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
      addSlideTitle(topicsSlide, 'Key Topics Discussed');

      const topicRows = meeting.analysis.keyTopics.slice(0, 6).map(topic => [
        { text: topic.topic, options: { bold: true, color: COLORS.dwNavy } },
        topic.description,
        { text: topic.importance?.toUpperCase() || 'MEDIUM', options: { color: getPriorityColor(topic.importance) } }
      ]);

      topicsSlide.addTable([
        [
          { text: 'Topic', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } },
          { text: 'Description', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } },
          { text: 'Priority', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } }
        ],
        ...topicRows
      ], {
        x: 0.5, y: 1.2, w: 12.33,
        fontFace: 'Arial', fontSize: 11,
        colW: [3, 7.33, 2],
        border: { pt: 0.5, color: COLORS.lightGray }
      });
    }

    // Action Items Slide
    if (meeting.analysis.actionItems?.length > 0) {
      const actionsSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
      addSlideTitle(actionsSlide, 'Action Items');

      const actionRows = meeting.analysis.actionItems.slice(0, 6).map(item => [
        truncateText(item.task, 80),
        item.owner || 'TBD',
        item.deadline || 'TBD',
        { text: item.priority?.toUpperCase() || 'MEDIUM', options: { color: getPriorityColor(item.priority) } }
      ]);

      actionsSlide.addTable([
        [
          { text: 'Task', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } },
          { text: 'Owner', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } },
          { text: 'Deadline', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } },
          { text: 'Priority', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } }
        ],
        ...actionRows
      ], {
        x: 0.5, y: 1.2, w: 12.33,
        fontFace: 'Arial', fontSize: 11,
        colW: [6, 2.5, 2.33, 1.5],
        border: { pt: 0.5, color: COLORS.lightGray }
      });
    }

    // For RFP meetings, add specialized slides
    if (meeting.meetingType === 'Fact-Finding Session (RFP)' && meeting.rfpData) {
      // Client Profile Slide
      const clientSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
      addSlideTitle(clientSlide, 'Client Profile');

      const factFinding = meeting.rfpData.factFindingSummary || {};
      const clientInfo = [
        ['Client Name', factFinding.clientName || 'N/A'],
        ['Industry', factFinding.industry || 'N/A'],
        ['Location', factFinding.location || 'N/A'],
        ['Employees', factFinding.employeeCount || 'N/A'],
        ['Current Broker', factFinding.currentProgram?.incumbent || 'N/A'],
        ['Renewal Date', factFinding.currentProgram?.expirationDate || 'N/A']
      ];

      clientSlide.addTable(clientInfo.map(row => [
        { text: row[0], options: { bold: true, color: COLORS.dwNavy } },
        row[1]
      ]), {
        x: 0.5, y: 1.2, w: 6,
        fontFace: 'Arial', fontSize: 12,
        colW: [2.5, 3.5],
        border: { pt: 0.5, color: COLORS.lightGray }
      });

      // Pain Points (if present)
      if (factFinding.painPoints?.length > 0) {
        clientSlide.addText('Key Pain Points:', {
          x: 7, y: 1.2, w: 5.5, h: 0.4,
          fontSize: 14, color: COLORS.dwNavy, fontFace: 'Arial', bold: true
        });

        const painPointsText = factFinding.painPoints.slice(0, 4).map(pp => `• ${pp.issue}`).join('\n');
        clientSlide.addText(painPointsText, {
          x: 7, y: 1.7, w: 5.5, h: 2.5,
          fontSize: 11, color: COLORS.text, fontFace: 'Arial', valign: 'top'
        });
      }

      // Coverage Recommendations Slide
      if (meeting.rfpData.rfpDraft?.recommendedCoverage?.length > 0) {
        const coverageSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
        addSlideTitle(coverageSlide, 'Recommended Coverage');

        const coverageRows = meeting.rfpData.rfpDraft.recommendedCoverage.slice(0, 5).map(cov => [
          { text: cov.line, options: { bold: true, color: COLORS.dwNavy } },
          truncateText(cov.rationale, 100),
          truncateText(cov.considerations || '', 80)
        ]);

        coverageSlide.addTable([
          [
            { text: 'Coverage Line', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } },
            { text: 'Rationale', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } },
            { text: 'Considerations', options: { fill: { color: COLORS.dwNavy }, color: COLORS.white, bold: true } }
          ],
          ...coverageRows
        ], {
          x: 0.5, y: 1.2, w: 12.33,
          fontFace: 'Arial', fontSize: 10,
          colW: [2.5, 5, 4.83],
          border: { pt: 0.5, color: COLORS.lightGray }
        });
      }

      // D&W Holdings Value Proposition Slide (External only)
      const valueProp = meeting.rfpData.rfpDraft?.marshValueProposition || meeting.rfpData.rfpDraft?.dwValueProposition;
      if (type === 'external' && valueProp) {
        const valueSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
        addSlideTitle(valueSlide, 'Why D&W Holdings');

        const valueItems = [
          { title: 'Global Capabilities', desc: valueProp.globalCapabilities },
          { title: 'Industry Expertise', desc: valueProp.industryExpertise },
          { title: 'Data & Analytics', desc: valueProp.dataAndAnalytics },
          { title: 'Claims Advocacy', desc: valueProp.claims }
        ].filter(v => v.desc);

        valueItems.slice(0, 4).forEach((item, idx) => {
          const col = idx % 2;
          const row = Math.floor(idx / 2);
          const x = 0.5 + (col * 6.5);
          const y = 1.2 + (row * 2);

          valueSlide.addShape('rect', { x, y, w: 6, h: 1.8, fill: { color: COLORS.lightGray } });
          valueSlide.addText(item.title, {
            x: x + 0.2, y: y + 0.1, w: 5.6, h: 0.4,
            fontSize: 14, color: COLORS.dwNavy, fontFace: 'Arial', bold: true
          });
          valueSlide.addText(truncateText(item.desc, 150), {
            x: x + 0.2, y: y + 0.5, w: 5.6, h: 1.2,
            fontSize: 10, color: COLORS.text, fontFace: 'Arial', valign: 'top'
          });
        });
      }

      // D&W Holdings Service Lines Slide (Internal only)
      if (type === 'internal' && meeting.crossSellOpportunities?.length > 0) {
        const crossSellSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
        addSlideTitle(crossSellSlide, 'D&W Holdings Service Lines');

        // Map old company names to new division names
        const divisionMap = {
          'Mercer': 'Benefits & Consulting Division',
          'Guy Carpenter': 'Risk Capital Solutions Division',
          'Oliver Wyman': 'Strategic Advisory Division'
        };

        meeting.crossSellOpportunities.forEach((opp, idx) => {
          if (idx >= 3) return;
          const y = 1.2 + (idx * 1.3);
          const divisionName = divisionMap[opp.company] || opp.division || opp.company;

          crossSellSlide.addShape('rect', { x: 0.5, y, w: 12.33, h: 1.1, fill: { color: COLORS.lightGray } });
          crossSellSlide.addText(divisionName, {
            x: 0.7, y: y + 0.1, w: 4, h: 0.4,
            fontSize: 14, color: COLORS.dwNavy, fontFace: 'Arial', bold: true
          });
          crossSellSlide.addText(opp.focus, {
            x: 4.7, y: y + 0.1, w: 4, h: 0.4,
            fontSize: 10, color: COLORS.darkGray, fontFace: 'Arial', italic: true
          });
          if (opp.opportunities?.[0]) {
            crossSellSlide.addText(truncateText(opp.opportunities[0].rationale || opp.opportunities[0].service, 200), {
              x: 0.7, y: y + 0.5, w: 11.9, h: 0.5,
              fontSize: 10, color: COLORS.text, fontFace: 'Arial'
            });
          }
        });
      }
    }

    // Deep Research Highlights (if available)
    if (meeting.deepResearch?.executiveBrief) {
      const researchSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
      addSlideTitle(researchSlide, 'Research Insights');

      const brief = meeting.deepResearch.executiveBrief;
      if (brief.keyFindings?.length > 0) {
        researchSlide.addText('Key Findings:', {
          x: 0.5, y: 1.2, w: 6, h: 0.4,
          fontSize: 14, color: COLORS.dwNavy, fontFace: 'Arial', bold: true
        });
        const findingsText = brief.keyFindings.slice(0, 4).map(f => `• ${f}`).join('\n');
        researchSlide.addText(findingsText, {
          x: 0.5, y: 1.7, w: 6, h: 2.5,
          fontSize: 11, color: COLORS.text, fontFace: 'Arial', valign: 'top'
        });
      }

      if (brief.criticalRisks?.length > 0) {
        researchSlide.addText('Critical Risks:', {
          x: 7, y: 1.2, w: 5.5, h: 0.4,
          fontSize: 14, color: COLORS.dwNavy, fontFace: 'Arial', bold: true
        });
        const risksText = brief.criticalRisks.slice(0, 4).map(r => `• ${r}`).join('\n');
        researchSlide.addText(risksText, {
          x: 7, y: 1.7, w: 5.5, h: 2.5,
          fontSize: 11, color: COLORS.text, fontFace: 'Arial', valign: 'top'
        });
      }
    }

    // Next Steps Slide
    const nextStepsSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
    addSlideTitle(nextStepsSlide, 'Next Steps');

    const nextSteps = meeting.rfpData?.nextSteps || meeting.analysis.actionItems?.slice(0, 5) || [];
    if (nextSteps.length > 0) {
      const stepsText = nextSteps.slice(0, 6).map((step, idx) => {
        const text = step.step || step.task || step;
        return `${idx + 1}. ${typeof text === 'string' ? text : JSON.stringify(text)}`;
      }).join('\n\n');

      nextStepsSlide.addText(stepsText, {
        x: 0.5, y: 1.2, w: 12.33, h: 4,
        fontSize: 14, color: COLORS.text, fontFace: 'Arial', valign: 'top'
      });
    } else {
      nextStepsSlide.addText('Next steps to be determined based on discussion.', {
        x: 0.5, y: 1.2, w: 12.33, h: 1,
        fontSize: 14, color: COLORS.text, fontFace: 'Arial'
      });
    }

    // Closing Slide
    const closingSlide = pptx.addSlide({ masterName: 'DW_MASTER' });
    closingSlide.addShape('rect', { x: 0, y: 0, w: '100%', h: '100%', fill: { color: COLORS.dwNavy } });
    closingSlide.addText('Thank You', {
      x: 0, y: 2, w: '100%', h: 1,
      fontSize: 44, color: COLORS.white, fontFace: 'Arial', bold: true, align: 'center'
    });
    closingSlide.addText('D&W HOLDINGS', {
      x: 0, y: 3.2, w: '100%', h: 0.5,
      fontSize: 24, color: COLORS.dwGold, fontFace: 'Arial', align: 'center'
    });
    closingSlide.addText('Enterprise Risk Intelligence', {
      x: 0, y: 3.8, w: '100%', h: 0.3,
      fontSize: 12, color: COLORS.white, fontFace: 'Arial', align: 'center'
    });

    // Save PowerPoint
    const fileName = `${meetingId}-${type}-${Date.now()}.pptx`;
    const filePath = path.join(__dirname, '../data/exports', fileName);

    await pptx.writeFile({ fileName: filePath });

    console.log(`PowerPoint generated: ${fileName}`);

    res.json({
      success: true,
      fileName,
      downloadUrl: `/exports/${fileName}`
    });
  } catch (error) {
    console.error('PowerPoint generation error:', error);
    res.status(500).json({
      error: 'Failed to generate PowerPoint',
      details: error.message
    });
  }
});

// Generate PDF export
router.post('/:meetingId/pdf', async (req, res) => {
  try {
    const { meetingId } = req.params;
    const { includeTranscript = true, includeAnalysis = true, includeResearch = true } = req.body;

    const db = getMeetingsDb();
    const meeting = db.meetings.find(m => m.id === meetingId);

    if (!meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    // Generate HTML content for PDF
    const htmlContent = generatePdfHtml(meeting, { includeTranscript, includeAnalysis, includeResearch });

    // Save as HTML (PDF generation would require additional library like puppeteer)
    const fileName = `${meetingId}-export-${Date.now()}.html`;
    const filePath = path.join(__dirname, '../data/exports', fileName);

    fs.writeFileSync(filePath, htmlContent);

    res.json({
      success: true,
      fileName,
      downloadUrl: `/exports/${fileName}`,
      note: 'Open in browser and use Print > Save as PDF'
    });
  } catch (error) {
    console.error('PDF generation error:', error);
    res.status(500).json({
      error: 'Failed to generate PDF',
      details: error.message
    });
  }
});

// Generate plain text export
router.post('/:meetingId/text', async (req, res) => {
  try {
    const { meetingId } = req.params;

    const db = getMeetingsDb();
    const meeting = db.meetings.find(m => m.id === meetingId);

    if (!meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    const textContent = generateTextExport(meeting);
    const fileName = `${meetingId}-export-${Date.now()}.txt`;
    const filePath = path.join(__dirname, '../data/exports', fileName);

    fs.writeFileSync(filePath, textContent);

    res.json({
      success: true,
      fileName,
      downloadUrl: `/exports/${fileName}`
    });
  } catch (error) {
    console.error('Text export error:', error);
    res.status(500).json({
      error: 'Failed to generate text export',
      details: error.message
    });
  }
});

// Helper functions
function addSlideTitle(slide, title) {
  slide.addText(title, {
    x: 0.5, y: 0.6, w: 12.33, h: 0.5,
    fontSize: 24, color: COLORS.dwNavy, fontFace: 'Arial', bold: true
  });
}

function truncateText(text, maxLength) {
  if (!text) return '';
  return text.length > maxLength ? text.substring(0, maxLength - 3) + '...' : text;
}

function getPriorityColor(priority) {
  switch (priority?.toLowerCase()) {
    case 'high': return 'CC0000';
    case 'medium': return 'FF9900';
    case 'low': return '009900';
    default: return COLORS.darkGray;
  }
}

function generatePdfHtml(meeting, options) {
  return `
<!DOCTYPE html>
<html>
<head>
  <title>${meeting.title} - Meeting Report</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 40px; color: #333; }
    h1 { color: #0a1628; border-bottom: 3px solid #0d9488; padding-bottom: 10px; }
    h2 { color: #0a1628; margin-top: 30px; }
    h3 { color: #0d9488; }
    .meta { color: #666; margin-bottom: 20px; }
    .confidential { background: #FFF3CD; padding: 10px; border-left: 4px solid #FFC107; margin: 20px 0; }
    .section { margin: 20px 0; }
    table { width: 100%; border-collapse: collapse; margin: 15px 0; }
    th { background: #0a1628; color: white; padding: 10px; text-align: left; }
    td { padding: 10px; border-bottom: 1px solid #ddd; }
    .action-item { background: #f8f9fa; padding: 10px; margin: 10px 0; border-left: 4px solid #0d9488; }
    .priority-high { color: #CC0000; font-weight: bold; }
    .priority-medium { color: #FF9900; }
    .priority-low { color: #009900; }
    @media print { body { padding: 20px; } }
  </style>
</head>
<body>
  <h1>${meeting.title}</h1>
  <div class="meta">
    <p><strong>Date:</strong> ${new Date(meeting.createdAt).toLocaleDateString()}</p>
    <p><strong>Type:</strong> ${meeting.meetingType}</p>
    <p><strong>Confidentiality:</strong> ${meeting.confidentiality}</p>
    ${meeting.clientName ? `<p><strong>Client:</strong> ${meeting.clientName}</p>` : ''}
  </div>

  ${meeting.confidentiality !== 'Public' ? '<div class="confidential"><strong>⚠️ Confidential:</strong> This document contains confidential information.</div>' : ''}

  ${options.includeAnalysis && meeting.analysis ? `
    <div class="section">
      <h2>Executive Summary</h2>
      <p>${meeting.analysis.summary || 'No summary available'}</p>
    </div>

    ${meeting.analysis.actionItems?.length ? `
      <div class="section">
        <h2>Action Items</h2>
        ${meeting.analysis.actionItems.map(item => `
          <div class="action-item">
            <strong>${item.task}</strong>
            <p>Owner: ${item.owner || 'TBD'} | Deadline: ${item.deadline || 'TBD'} |
            <span class="priority-${item.priority?.toLowerCase()}">${item.priority?.toUpperCase() || 'MEDIUM'}</span></p>
          </div>
        `).join('')}
      </div>
    ` : ''}

    ${meeting.analysis.keyTopics?.length ? `
      <div class="section">
        <h2>Key Topics</h2>
        <table>
          <tr><th>Topic</th><th>Description</th><th>Importance</th></tr>
          ${meeting.analysis.keyTopics.map(t => `<tr><td>${t.topic}</td><td>${t.description}</td><td class="priority-${t.importance?.toLowerCase()}">${t.importance?.toUpperCase()}</td></tr>`).join('')}
        </table>
      </div>
    ` : ''}
  ` : ''}

  ${options.includeTranscript && meeting.transcript ? `
    <div class="section">
      <h2>Full Transcript</h2>
      <p style="white-space: pre-wrap; background: #f8f9fa; padding: 20px; border-radius: 5px;">${meeting.transcript.text}</p>
    </div>
  ` : ''}

  <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
    <p>Generated by D&W Holdings Meeting Analyzer | ${new Date().toLocaleString()}</p>
    <p>D&W Holdings - Enterprise Risk Intelligence</p>
  </footer>
</body>
</html>`;
}

function generateTextExport(meeting) {
  let text = `
================================================================================
${meeting.title}
================================================================================
Date: ${new Date(meeting.createdAt).toLocaleDateString()}
Type: ${meeting.meetingType}
Confidentiality: ${meeting.confidentiality}
${meeting.clientName ? `Client: ${meeting.clientName}` : ''}

--------------------------------------------------------------------------------
EXECUTIVE SUMMARY
--------------------------------------------------------------------------------
${meeting.analysis?.summary || 'No summary available'}

`;

  if (meeting.analysis?.actionItems?.length) {
    text += `
--------------------------------------------------------------------------------
ACTION ITEMS
--------------------------------------------------------------------------------
`;
    meeting.analysis.actionItems.forEach((item, idx) => {
      text += `${idx + 1}. ${item.task}
   Owner: ${item.owner || 'TBD'}
   Deadline: ${item.deadline || 'TBD'}
   Priority: ${item.priority || 'Medium'}

`;
    });
  }

  if (meeting.transcript?.text) {
    text += `
--------------------------------------------------------------------------------
FULL TRANSCRIPT
--------------------------------------------------------------------------------
${meeting.transcript.text}
`;
  }

  text += `
================================================================================
Generated by D&W Holdings Meeting Analyzer | ${new Date().toLocaleString()}
D&W Holdings - Enterprise Risk Intelligence
================================================================================
`;

  return text;
}

export default router;

# Claude Cowork Quick Start Guide

## Step 1: Open Claude Desktop & Enable Cowork

1. Open **Claude Desktop** on your laptop
2. Go to **Settings > Cowork**
3. Enable Cowork mode

## Step 2: Set Global Instructions

In Settings > Cowork > Global Instructions, paste:

```
I am the AI operations manager for the Education News Monitor project.
My role is to coordinate sub-agents for news screening, risk analysis, and UI coordination.
I have access to the project at: /home/user/Insurance-Consultant-Test/
I use Obsidian for knowledge management at: ~/Documents/Obsidian/EducationNewsMonitor/
I integrate with Lovable.dev for UI improvements.
```

## Step 3: Set Folder Instructions

1. Click "Select Folder" and choose `/home/user/Insurance-Consultant-Test/`
2. Cowork will read COWORK_INIT.md automatically for project context

## Step 4: Initialize with This Prompt

Copy and paste this into Claude Cowork:

```
Read COWORK_INIT.md in this project folder and execute the First Run Checklist.

Specifically:
1. Set up the Obsidian vault at ~/Documents/Obsidian/EducationNewsMonitor/
2. Copy the templates from obsidian-templates/ folder to the vault
3. Define the three sub-agents (Screener, Risk Analyst, UI/UX)
4. Run a test screening task manually
5. Report back what you've set up

Do not set up scheduled tasks yet - we'll do that after confirming manual tasks work.
```

## Step 5: Test Manual Tasks

After setup, test each agent:

**Test Screener:**
```
Run the Screener Agent once. Fetch articles from all RSS feeds listed in 
lib/services/news_feed_service.dart, categorize them, and write results 
to today's daily note in Obsidian.
```

**Test Risk Analyst:**
```
Take the top 3 high-priority articles from today's screening and run 
detailed risk analysis on each. Write the analysis to Obsidian using 
the risk-analysis template.
```

**Test Discord:**
```
Send a test alert to the Discord webhook (stored in the app) with a 
sample breaking news format.
```

## Step 6: Set Up Scheduled Tasks

Once manual tests pass:

```
/schedule every 30 minutes
Run the Screener Agent to fetch and categorize new articles.
Update Obsidian daily note. Alert on breaking news.
```

```
/schedule daily at 7:00 AM
Generate daily digest with top stories, risk summaries, and action items.
Write to Obsidian and send summary to Discord.
```

## Step 7: Connect Lovable.dev

1. Get your Lovable API key from lovable.dev
2. Add MCP config (see COWORK_INIT.md for details)
3. Test connection:
```
Connect to Lovable and list any existing projects. If none, create a new 
project called "Education News Monitor UI" and sync the design system 
colors from lib/utils/theme.dart.
```

## Troubleshooting

**Cowork can't read files:**
- Make sure you selected the correct folder
- Check file permissions

**RSS feeds failing:**
- The CORS proxy may be down
- Check COWORK_INIT.md for fallback proxies

**Obsidian vault not found:**
- Create the folder manually: `~/Documents/Obsidian/EducationNewsMonitor/`
- Then run setup again

**Discord not sending:**
- Verify webhook URL is configured in the app's admin panel
- Test webhook directly with curl

## Key Files Reference

| What | Where |
|------|-------|
| Full Setup Prompt | `COWORK_INIT.md` |
| RSS Feed Sources | `lib/services/news_feed_service.dart` |
| Claude API Setup | `lib/services/claude_service.dart` |
| Discord Webhook | `lib/services/discord_service.dart` |
| Obsidian Templates | `obsidian-templates/` |
| Theme Colors | `lib/utils/theme.dart` |

---

**Need the full detailed prompt?** Read `COWORK_INIT.md` in this folder.

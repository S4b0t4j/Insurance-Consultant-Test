# Quick Deployment Guide

## Deploy to Vercel (Free, 10 minutes)

### Step 1: Set Up Database (from your phone)

1. Go to [neon.tech](https://neon.tech) or [railway.app](https://railway.app)
2. Create a free account
3. Create a new PostgreSQL database
4. Copy the connection string (format: `postgresql://user:pass@host/dbname`)

### Step 2: Deploy to Vercel

1. Go to [vercel.com/new](https://vercel.com/new)
2. Sign in with GitHub
3. Import repository: `S4b0t4j/Insurance-Consultant-Test`
4. Select branch: `claude/sled-dashboard-prototype-PjTIO`
5. Configure environment variables:
   - `DATABASE_URL` = your database connection string
   - `NEXTAUTH_URL` = `https://your-app-name.vercel.app` (you'll get this after deployment)
   - `NEXTAUTH_SECRET` = any random string (min 32 chars)
6. Click **Deploy**

### Step 3: Seed the Database (one-time setup)

After deployment, you need to seed the database with sample data:

#### Option A: Using Vercel CLI (from your laptop later)
```bash
npm i -g vercel
vercel login
vercel env pull
npm run db:seed
```

#### Option B: Using Vercel Dashboard
1. Go to your project on Vercel
2. Click "Settings" → "Functions"
3. Add a serverless function to run the seed script (advanced)

#### Option C: Manual seed via database client
Connect to your Neon/Railway database directly and run the seed SQL.

### Step 4: Access Your Dashboard

Your dashboard will be live at: `https://your-project-name.vercel.app`

---

## Alternative: Use Cloudflare Tunnel (if laptop is running)

If your laptop is still on with the dev server running:

```bash
# Run this on your laptop:
npx cloudflared tunnel --url http://localhost:3000
```

You'll get a public URL like `https://xyz.trycloudflare.com` instantly.

---

## Free Database Options

- **Neon** (Recommended): https://neon.tech - 500MB free
- **Supabase**: https://supabase.com - 500MB free, includes admin UI
- **Railway**: https://railway.app - $5 free credit monthly
- **ElephantSQL**: https://elephantsql.com - 20MB free (sufficient for prototype)

---

## Environment Variables Explained

- `DATABASE_URL`: PostgreSQL connection string
- `NEXTAUTH_URL`: Full URL where your app is deployed
- `NEXTAUTH_SECRET`: Random secret for session encryption
  - Generate with: `openssl rand -base64 32`
  - Or use: `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`

---

## Troubleshooting

### Build fails with Prisma error
- Make sure `DATABASE_URL` is set in Vercel environment variables
- Check that database is accessible from the internet

### Database is empty
- Run the seed script: `npm run db:seed`
- Or manually insert data via your database provider's UI

### Can't access from mobile
- Verify the deployment URL is correct
- Check browser console for errors
- Ensure database connection is working (check Vercel logs)

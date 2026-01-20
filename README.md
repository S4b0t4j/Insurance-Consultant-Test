# SLED Insurance Analytics Dashboard

Internal analytics dashboard prototype for commercial insurance brokers focused on **State, Local, and Education (SLED)** public entities.

## Overview

This dashboard helps insurance producers quickly understand regulatory, operational, and loss-driven developments impacting SLED commercial insurance programs.

**Target entities:**
- State agencies and authorities
- Cities, counties, and municipalities
- Public school districts and charter schools
- Public colleges and universities
- Transit authorities, utilities, and special districts

## Tech Stack

- **Framework:** Next.js 14+ (App Router)
- **Language:** TypeScript (strict mode)
- **Styling:** TailwindCSS + shadcn/ui
- **Database:** PostgreSQL
- **ORM:** Prisma
- **Validation:** Zod
- **Auth:** Basic role-based (admin/viewer) via middleware

## Prerequisites

- Node.js 18+ and npm
- PostgreSQL database

## Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Set Up Environment Variables

Create a `.env.local` file in the root directory:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/sled_dashboard?schema=public"
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="your-secret-key-here-replace-in-production"
```

Replace the `DATABASE_URL` with your actual PostgreSQL connection string.

### 3. Set Up the Database

Generate Prisma client and push the schema to your database:

```bash
npm run db:generate
npm run db:push
```

### 4. Seed the Database

Populate the database with sample SLED signals:

```bash
npm run db:seed
```

This will create:
- 2 users (admin and viewer)
- 15 realistic SLED signal examples

### 5. Run the Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
/
├── /app                    # Next.js App Router pages
│   ├── /api               # API routes
│   │   └── /signals       # SLED signal CRUD endpoints
│   ├── /dashboard         # Main dashboard views
│   ├── /admin             # Admin-only pages
│   └── page.tsx           # Landing page
├── /components            # Shared UI components
│   ├── /ui               # shadcn/ui components
│   └── /dashboard        # Dashboard-specific components
├── /lib                   # Utilities, config, helpers
│   ├── /validations      # Zod schemas
│   ├── auth.ts           # Auth helpers
│   ├── prisma.ts         # Prisma client
│   └── utils.ts          # Utility functions
├── /types                 # Shared TypeScript types
├── /prisma               # Database schema and seed
│   ├── schema.prisma     # Prisma schema
│   └── seed.ts           # Seed script
└── middleware.ts          # Next.js middleware for auth
```

## Key Features

### Dashboard Features
- **Filter signals** by entity category, type, jurisdiction, insurance line, and severity
- **Search functionality** for finding specific jurisdictions
- **Signal cards** with key information at a glance
- **Detail view** with full signal information and "Why It Matters" insight
- **Responsive design** optimized for desktop and tablet

### Admin Features
- **Create new signals** with comprehensive form validation
- **Edit existing signals** with pre-populated data
- **Delete signals** with confirmation
- **Admin panel** with table view of all signals

### Security
- Input validation using Zod schemas
- SQL injection prevention via Prisma
- Role-based access control (prototype implementation)
- CSRF protection via Next.js

## API Endpoints

### GET /api/signals
List all signals with filtering

**Query Parameters:**
- `entityCategory`: STATE | LOCAL | EDUCATION
- `entityType`: STATE_AGENCY | MUNICIPALITY | etc.
- `jurisdiction`: String (search)
- `insuranceLine`: PROPERTY | CYBER | etc.
- `severityLevel`: LOW | MEDIUM | HIGH
- `limit`: Number (default: 20, max: 100)
- `offset`: Number (default: 0)

**Response:**
```json
{
  "data": {
    "signals": [...],
    "total": 15
  },
  "error": null
}
```

### POST /api/signals
Create a new signal

**Request Body:**
```json
{
  "headline": "California Passes AB 1234...",
  "summary": "New legislation requires...",
  "entityCategory": "EDUCATION",
  "entityType": "SCHOOL_DISTRICT",
  "jurisdiction": "California",
  "insuranceLines": ["CYBER"],
  "riskDriverType": "REGULATORY",
  "severityLevel": "HIGH",
  "whyItMatters": "School districts renewing..."
}
```

### GET /api/signals/[id]
Get a single signal by ID

### PUT /api/signals/[id]
Update a signal

### DELETE /api/signals/[id]
Delete a signal

## Database Schema

### Enums
- `EntityCategory`: STATE, LOCAL, EDUCATION
- `EntityType`: STATE_AGENCY, MUNICIPALITY, COUNTY, etc.
- `InsuranceLine`: PROPERTY, CYBER, AUTO, etc.
- `RiskDriverType`: REGULATORY, LITIGATION, OPERATIONAL, etc.
- `SeverityLevel`: LOW, MEDIUM, HIGH
- `UserRole`: ADMIN, VIEWER

### Models

**SledSignal**
- Core identification (headline, summary, source)
- SLED categorization (entity category, type, jurisdiction)
- Insurance relevance (lines, risk driver, severity)
- Plain English insight ("Why It Matters")
- Metadata (timestamps, creator)

**User**
- Basic user information
- Role-based access control

## Development Commands

```bash
# Development
npm run dev              # Start development server

# Database
npm run db:generate      # Generate Prisma client
npm run db:push          # Push schema to database
npm run db:seed          # Seed database with sample data

# Build
npm run build            # Build for production
npm run start            # Start production server

# Linting
npm run lint             # Run ESLint
```

## Future Enhancements

These features are not included in the prototype but are planned for future versions:

- RSS/API ingestion for automated signal capture
- AI-powered "Why It Matters" generation
- Producer notification system
- Integration with CRM/renewal calendars
- Analytics on signal engagement
- Multi-tenant support
- Full authentication system (NextAuth)

## Architecture Decisions

### Why Next.js App Router?
- Server Components for better performance
- Built-in API routes
- File-based routing
- Excellent TypeScript support

### Why Prisma?
- Type-safe database queries
- Easy migrations
- Excellent PostgreSQL support
- Prevents SQL injection

### Why shadcn/ui?
- Customizable components
- Built on Radix UI primitives
- Copy-paste approach (full ownership)
- Excellent accessibility

### Why Zod?
- Runtime type validation
- TypeScript inference
- Excellent error messages
- Framework agnostic

## Notes

- This is an **internal prototype only** - no client PII or confidential data
- Authentication is mocked for prototype purposes
- In production, implement proper authentication (NextAuth, Clerk, etc.)
- Consider implementing rate limiting for API endpoints
- Add proper error logging and monitoring
- Implement database backups and disaster recovery

## Support

For issues or questions, please contact the development team.

## License

Internal use only - All rights reserved 

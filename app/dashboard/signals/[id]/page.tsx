import Link from 'next/link';
import { notFound } from 'next/navigation';
import { format } from 'date-fns';
import { ArrowLeft, ExternalLink } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import type { SledSignal, ApiResponse } from '@/types';

async function getSignal(id: string) {
  const url = `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'}/api/signals/${id}`;

  try {
    const res = await fetch(url, {
      cache: 'no-store',
    });

    if (!res.ok) {
      return null;
    }

    const data: ApiResponse<SledSignal> = await res.json();
    return data.data;
  } catch (error) {
    console.error('Error fetching signal:', error);
    return null;
  }
}

const severityColors = {
  LOW: 'bg-green-100 text-green-800 border-green-200',
  MEDIUM: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  HIGH: 'bg-red-100 text-red-800 border-red-200',
};

const entityCategoryLabels = {
  STATE: 'State',
  LOCAL: 'Local',
  EDUCATION: 'Education',
};

const entityTypeLabels = {
  STATE_AGENCY: 'State Agency',
  MUNICIPALITY: 'Municipality',
  COUNTY: 'County',
  SCHOOL_DISTRICT: 'School District',
  CHARTER_SCHOOL: 'Charter School',
  PUBLIC_UNIVERSITY: 'Public University',
  COMMUNITY_COLLEGE: 'Community College',
  TRANSIT_AUTHORITY: 'Transit Authority',
  UTILITY: 'Utility',
  SPECIAL_DISTRICT: 'Special District',
};

const riskDriverLabels = {
  REGULATORY: 'Regulatory',
  LITIGATION: 'Litigation',
  OPERATIONAL: 'Operational',
  FINANCIAL: 'Financial',
  CATASTROPHE: 'Catastrophe',
};

export default async function SignalDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const signal = await getSignal(id);

  if (!signal) {
    notFound();
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="container mx-auto px-4 py-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/dashboard">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Dashboard
            </Link>
          </Button>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8 max-w-4xl">
        <div className="space-y-6">
          <div className="flex items-start justify-between gap-4">
            <div className="flex gap-2">
              <Badge className={severityColors[signal.severityLevel]}>
                {signal.severityLevel}
              </Badge>
              <Badge variant="outline">
                {entityCategoryLabels[signal.entityCategory]}
              </Badge>
              <Badge variant="outline">
                {entityTypeLabels[signal.entityType]}
              </Badge>
            </div>
            <Button asChild variant="outline" size="sm">
              <Link href={`/admin/signals/${signal.id}/edit`}>Edit</Link>
            </Button>
          </div>

          <div>
            <h1 className="text-4xl font-bold mb-4">{signal.headline}</h1>
            <div className="flex items-center gap-4 text-muted-foreground">
              <span>{signal.jurisdiction}</span>
              <span>•</span>
              <span>
                {signal.publishedAt
                  ? format(new Date(signal.publishedAt), 'MMMM d, yyyy')
                  : 'Date TBD'}
              </span>
              {signal.sourcePublication && (
                <>
                  <span>•</span>
                  <span>{signal.sourcePublication}</span>
                </>
              )}
            </div>
          </div>

          <Card className="bg-primary/5 border-primary">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <span className="text-2xl">💡</span>
                Why It Matters
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-lg leading-relaxed">{signal.whyItMatters}</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Summary</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="leading-relaxed whitespace-pre-line">{signal.summary}</p>
            </CardContent>
          </Card>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>Insurance Lines</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex flex-wrap gap-2">
                  {signal.insuranceLines.map((line) => (
                    <Badge key={line} variant="secondary">
                      {line.replace(/_/g, ' ')}
                    </Badge>
                  ))}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Risk Driver</CardTitle>
              </CardHeader>
              <CardContent>
                <Badge variant="outline" className="text-base px-4 py-2">
                  {riskDriverLabels[signal.riskDriverType]}
                </Badge>
              </CardContent>
            </Card>
          </div>

          {signal.sourceUrl && (
            <Card>
              <CardHeader>
                <CardTitle>Source</CardTitle>
              </CardHeader>
              <CardContent>
                <Button asChild variant="outline">
                  <a
                    href={signal.sourceUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-2"
                  >
                    Read Full Article
                    <ExternalLink className="h-4 w-4" />
                  </a>
                </Button>
              </CardContent>
            </Card>
          )}

          <div className="text-sm text-muted-foreground text-center pt-4">
            Last updated: {format(new Date(signal.updatedAt), 'MMMM d, yyyy h:mm a')}
          </div>
        </div>
      </main>
    </div>
  );
}

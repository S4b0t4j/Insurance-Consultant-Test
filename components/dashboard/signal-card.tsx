import Link from 'next/link';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import type { SledSignal } from '@/types';
import { format } from 'date-fns';

type SignalCardProps = {
  signal: SledSignal;
};

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

const riskDriverLabels = {
  REGULATORY: 'Regulatory',
  LITIGATION: 'Litigation',
  OPERATIONAL: 'Operational',
  FINANCIAL: 'Financial',
  CATASTROPHE: 'Catastrophe',
};

export function SignalCard({ signal }: SignalCardProps) {
  return (
    <Link href={`/dashboard/signals/${signal.id}`}>
      <Card className="hover:shadow-lg transition-shadow cursor-pointer h-full">
        <CardHeader>
          <div className="flex items-start justify-between gap-2 mb-2">
            <Badge className={severityColors[signal.severityLevel]}>
              {signal.severityLevel}
            </Badge>
            <Badge variant="outline">
              {entityCategoryLabels[signal.entityCategory]}
            </Badge>
          </div>
          <CardTitle className="text-lg line-clamp-2">{signal.headline}</CardTitle>
          <CardDescription>
            {signal.jurisdiction} • {signal.publishedAt ? format(new Date(signal.publishedAt), 'MMM d, yyyy') : 'Date TBD'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            <div className="flex flex-wrap gap-1">
              {signal.insuranceLines.map((line) => (
                <Badge key={line} variant="secondary" className="text-xs">
                  {line.replace(/_/g, ' ')}
                </Badge>
              ))}
            </div>
            <div className="text-sm text-muted-foreground">
              <span className="font-semibold text-foreground">Risk Driver:</span>{' '}
              {riskDriverLabels[signal.riskDriverType]}
            </div>
            <div className="border-l-4 border-primary pl-3">
              <p className="text-sm font-semibold mb-1">Why It Matters</p>
              <p className="text-sm text-muted-foreground line-clamp-3">
                {signal.whyItMatters}
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

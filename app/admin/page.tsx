import Link from 'next/link';
import { Button } from '@/components/ui/button';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { format } from 'date-fns';
import type { SledSignal, ApiResponse } from '@/types';
import { DeleteSignalButton } from '@/components/dashboard/delete-signal-button';

async function getSignals() {
  const url = `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'}/api/signals?limit=100`;

  try {
    const res = await fetch(url, {
      cache: 'no-store',
    });

    if (!res.ok) {
      throw new Error('Failed to fetch signals');
    }

    const data: ApiResponse<{ signals: SledSignal[]; total: number }> = await res.json();
    return data;
  } catch (error) {
    console.error('Error fetching signals:', error);
    return { data: null, error: 'Failed to load signals' };
  }
}

const severityColors = {
  LOW: 'bg-green-100 text-green-800',
  MEDIUM: 'bg-yellow-100 text-yellow-800',
  HIGH: 'bg-red-100 text-red-800',
};

export default async function AdminPage() {
  const result = await getSignals();

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold">Admin Dashboard</h1>
              <p className="text-muted-foreground">Manage SLED signals</p>
            </div>
            <div className="flex gap-2">
              <Button asChild variant="outline">
                <Link href="/dashboard">View Dashboard</Link>
              </Button>
              <Button asChild>
                <Link href="/admin/signals/new">Create Signal</Link>
              </Button>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        {result.error && (
          <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded mb-6">
            {result.error}
          </div>
        )}

        {result.data && (
          <>
            <div className="mb-6">
              <h2 className="text-2xl font-semibold">
                {result.data.total} Total Signal{result.data.total !== 1 ? 's' : ''}
              </h2>
            </div>

            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Headline</TableHead>
                    <TableHead>Category</TableHead>
                    <TableHead>Severity</TableHead>
                    <TableHead>Jurisdiction</TableHead>
                    <TableHead>Published</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {result.data.signals.map((signal) => (
                    <TableRow key={signal.id}>
                      <TableCell className="font-medium max-w-md">
                        <Link
                          href={`/dashboard/signals/${signal.id}`}
                          className="hover:underline"
                        >
                          {signal.headline}
                        </Link>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline">{signal.entityCategory}</Badge>
                      </TableCell>
                      <TableCell>
                        <Badge className={severityColors[signal.severityLevel]}>
                          {signal.severityLevel}
                        </Badge>
                      </TableCell>
                      <TableCell>{signal.jurisdiction}</TableCell>
                      <TableCell>
                        {signal.publishedAt
                          ? format(new Date(signal.publishedAt), 'MMM d, yyyy')
                          : 'TBD'}
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
                          <Button asChild variant="outline" size="sm">
                            <Link href={`/admin/signals/${signal.id}/edit`}>Edit</Link>
                          </Button>
                          <DeleteSignalButton signalId={signal.id} />
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </>
        )}
      </main>
    </div>
  );
}

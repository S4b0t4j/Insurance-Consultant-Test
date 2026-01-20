import { Suspense } from 'react';
import Link from 'next/link';
import { SignalFilters } from '@/components/dashboard/signal-filters';
import { SignalCard } from '@/components/dashboard/signal-card';
import { Button } from '@/components/ui/button';
import type { SledSignal, ApiResponse } from '@/types';

async function getSignals(searchParams: Record<string, string>) {
  const params = new URLSearchParams(searchParams);
  const url = `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'}/api/signals?${params.toString()}`;

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

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string>>;
}) {
  const params = await searchParams;
  const result = await getSignals(params);

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold">SLED Insurance Analytics</h1>
              <p className="text-muted-foreground">
                State, Local, and Education insurance intelligence
              </p>
            </div>
            <div className="flex gap-2">
              <Button asChild variant="outline">
                <Link href="/">Home</Link>
              </Button>
              <Button asChild>
                <Link href="/admin">Admin</Link>
              </Button>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        <Suspense fallback={<div>Loading filters...</div>}>
          <SignalFilters />
        </Suspense>

        <div className="mt-8">
          {result.error && (
            <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded">
              {result.error}
            </div>
          )}

          {result.data && (
            <>
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-semibold">
                  {result.data.total} Signal{result.data.total !== 1 ? 's' : ''}
                </h2>
              </div>

              {result.data.signals.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-muted-foreground text-lg">
                    No signals found matching your criteria.
                  </p>
                  <p className="text-muted-foreground mt-2">
                    Try adjusting your filters or{' '}
                    <Link href="/dashboard" className="text-primary underline">
                      clear all filters
                    </Link>
                    .
                  </p>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {result.data.signals.map((signal) => (
                    <SignalCard key={signal.id} signal={signal} />
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </main>
    </div>
  );
}

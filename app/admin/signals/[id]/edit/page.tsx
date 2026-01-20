import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { SignalForm } from '@/components/dashboard/signal-form';
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

export default async function EditSignalPage({
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
            <Link href={`/dashboard/signals/${id}`}>
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Signal
            </Link>
          </Button>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8 max-w-4xl">
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2">Edit Signal</h1>
          <p className="text-muted-foreground">Update signal information</p>
        </div>

        <SignalForm mode="edit" signal={signal} />
      </main>
    </div>
  );
}

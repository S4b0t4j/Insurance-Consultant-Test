'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';

type DeleteSignalButtonProps = {
  signalId: string;
};

export function DeleteSignalButton({ signalId }: DeleteSignalButtonProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  const handleDelete = async () => {
    if (!confirm('Are you sure you want to delete this signal? This action cannot be undone.')) {
      return;
    }

    setLoading(true);

    try {
      const res = await fetch(`/api/signals/${signalId}`, {
        method: 'DELETE',
      });

      if (!res.ok) {
        throw new Error('Failed to delete signal');
      }

      router.refresh();
    } catch (error) {
      alert(error instanceof Error ? error.message : 'Failed to delete signal');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Button
      variant="destructive"
      size="sm"
      onClick={handleDelete}
      disabled={loading}
    >
      <Trash2 className="h-4 w-4" />
    </Button>
  );
}

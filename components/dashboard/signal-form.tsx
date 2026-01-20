'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import type { SledSignal } from '@/types';

type SignalFormProps = {
  signal?: SledSignal;
  mode: 'create' | 'edit';
};

export function SignalForm({ signal, mode }: SignalFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [selectedInsuranceLines, setSelectedInsuranceLines] = useState<string[]>(
    signal?.insuranceLines || []
  );

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const formData = new FormData(e.currentTarget);
    const data = {
      headline: formData.get('headline'),
      summary: formData.get('summary'),
      sourceUrl: formData.get('sourceUrl') || undefined,
      sourcePublication: formData.get('sourcePublication') || undefined,
      publishedAt: formData.get('publishedAt')
        ? new Date(formData.get('publishedAt') as string).toISOString()
        : undefined,
      entityCategory: formData.get('entityCategory'),
      entityType: formData.get('entityType'),
      jurisdiction: formData.get('jurisdiction'),
      insuranceLines: selectedInsuranceLines,
      riskDriverType: formData.get('riskDriverType'),
      severityLevel: formData.get('severityLevel'),
      whyItMatters: formData.get('whyItMatters'),
    };

    try {
      const url =
        mode === 'create'
          ? '/api/signals'
          : `/api/signals/${signal?.id}`;
      const method = mode === 'create' ? 'POST' : 'PUT';

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });

      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.error || 'Failed to save signal');
      }

      const result = await res.json();
      router.push(`/dashboard/signals/${result.data.id}`);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const toggleInsuranceLine = (line: string) => {
    setSelectedInsuranceLines((prev) =>
      prev.includes(line) ? prev.filter((l) => l !== line) : [...prev, line]
    );
  };

  const insuranceLineOptions = [
    'PROPERTY',
    'GENERAL_LIABILITY',
    'AUTO',
    'CYBER',
    'PROFESSIONAL_LIABILITY',
    'EXCESS',
    'WORKERS_COMP',
    'EPLI',
    'D_AND_O',
  ];

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {error && (
        <div className="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded">
          {error}
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle>Basic Information</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="headline">Headline *</Label>
            <Input
              id="headline"
              name="headline"
              defaultValue={signal?.headline}
              required
              minLength={10}
              maxLength={200}
              placeholder="Brief, descriptive headline"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="summary">Summary *</Label>
            <textarea
              id="summary"
              name="summary"
              defaultValue={signal?.summary}
              required
              minLength={50}
              maxLength={2000}
              rows={6}
              className="flex w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50"
              placeholder="Detailed summary of the signal"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="whyItMatters">Why It Matters *</Label>
            <textarea
              id="whyItMatters"
              name="whyItMatters"
              defaultValue={signal?.whyItMatters}
              required
              minLength={50}
              maxLength={500}
              rows={4}
              className="flex w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50"
              placeholder="Plain English explanation of business impact"
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Source Information</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="sourceUrl">Source URL</Label>
            <Input
              id="sourceUrl"
              name="sourceUrl"
              type="url"
              defaultValue={signal?.sourceUrl || ''}
              placeholder="https://example.com/article"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="sourcePublication">Source Publication</Label>
            <Input
              id="sourcePublication"
              name="sourcePublication"
              defaultValue={signal?.sourcePublication || ''}
              placeholder="Publication name"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="publishedAt">Published Date</Label>
            <Input
              id="publishedAt"
              name="publishedAt"
              type="date"
              defaultValue={
                signal?.publishedAt
                  ? new Date(signal.publishedAt).toISOString().split('T')[0]
                  : ''
              }
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>SLED Classification</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="entityCategory">Entity Category *</Label>
            <Select name="entityCategory" defaultValue={signal?.entityCategory} required>
              <SelectTrigger>
                <SelectValue placeholder="Select category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="STATE">State</SelectItem>
                <SelectItem value="LOCAL">Local</SelectItem>
                <SelectItem value="EDUCATION">Education</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="entityType">Entity Type *</Label>
            <Select name="entityType" defaultValue={signal?.entityType} required>
              <SelectTrigger>
                <SelectValue placeholder="Select type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="STATE_AGENCY">State Agency</SelectItem>
                <SelectItem value="MUNICIPALITY">Municipality</SelectItem>
                <SelectItem value="COUNTY">County</SelectItem>
                <SelectItem value="SCHOOL_DISTRICT">School District</SelectItem>
                <SelectItem value="CHARTER_SCHOOL">Charter School</SelectItem>
                <SelectItem value="PUBLIC_UNIVERSITY">Public University</SelectItem>
                <SelectItem value="COMMUNITY_COLLEGE">Community College</SelectItem>
                <SelectItem value="TRANSIT_AUTHORITY">Transit Authority</SelectItem>
                <SelectItem value="UTILITY">Utility</SelectItem>
                <SelectItem value="SPECIAL_DISTRICT">Special District</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="jurisdiction">Jurisdiction *</Label>
            <Input
              id="jurisdiction"
              name="jurisdiction"
              defaultValue={signal?.jurisdiction}
              required
              minLength={2}
              maxLength={100}
              placeholder="e.g., California or Los Angeles, CA"
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Insurance Details</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label>Insurance Lines * (select at least one)</Label>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
              {insuranceLineOptions.map((line) => (
                <label
                  key={line}
                  className="flex items-center space-x-2 cursor-pointer p-2 rounded border hover:bg-accent"
                >
                  <input
                    type="checkbox"
                    checked={selectedInsuranceLines.includes(line)}
                    onChange={() => toggleInsuranceLine(line)}
                    className="h-4 w-4"
                  />
                  <span className="text-sm">{line.replace(/_/g, ' ')}</span>
                </label>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="riskDriverType">Risk Driver Type *</Label>
            <Select name="riskDriverType" defaultValue={signal?.riskDriverType} required>
              <SelectTrigger>
                <SelectValue placeholder="Select risk driver" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="REGULATORY">Regulatory</SelectItem>
                <SelectItem value="LITIGATION">Litigation</SelectItem>
                <SelectItem value="OPERATIONAL">Operational</SelectItem>
                <SelectItem value="FINANCIAL">Financial</SelectItem>
                <SelectItem value="CATASTROPHE">Catastrophe</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="severityLevel">Severity Level *</Label>
            <Select name="severityLevel" defaultValue={signal?.severityLevel} required>
              <SelectTrigger>
                <SelectValue placeholder="Select severity" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="LOW">Low</SelectItem>
                <SelectItem value="MEDIUM">Medium</SelectItem>
                <SelectItem value="HIGH">High</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      <div className="flex gap-4">
        <Button type="submit" disabled={loading || selectedInsuranceLines.length === 0}>
          {loading ? 'Saving...' : mode === 'create' ? 'Create Signal' : 'Update Signal'}
        </Button>
        <Button
          type="button"
          variant="outline"
          onClick={() => router.back()}
          disabled={loading}
        >
          Cancel
        </Button>
      </div>
    </form>
  );
}

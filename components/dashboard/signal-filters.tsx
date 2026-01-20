'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

export function SignalFilters() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const updateFilter = (key: string, value: string) => {
    const params = new URLSearchParams(searchParams.toString());
    if (value && value !== 'all') {
      params.set(key, value);
    } else {
      params.delete(key);
    }
    params.delete('offset');
    router.push(`/dashboard?${params.toString()}`);
  };

  const clearFilters = () => {
    router.push('/dashboard');
  };

  return (
    <div className="bg-card rounded-lg border p-4 space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold">Filters</h3>
        <Button variant="ghost" size="sm" onClick={clearFilters}>
          Clear All
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <div className="space-y-2">
          <Label htmlFor="entityCategory">Category</Label>
          <Select
            value={searchParams.get('entityCategory') || 'all'}
            onValueChange={(value) => updateFilter('entityCategory', value)}
          >
            <SelectTrigger id="entityCategory">
              <SelectValue placeholder="All Categories" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Categories</SelectItem>
              <SelectItem value="STATE">State</SelectItem>
              <SelectItem value="LOCAL">Local</SelectItem>
              <SelectItem value="EDUCATION">Education</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="entityType">Entity Type</Label>
          <Select
            value={searchParams.get('entityType') || 'all'}
            onValueChange={(value) => updateFilter('entityType', value)}
          >
            <SelectTrigger id="entityType">
              <SelectValue placeholder="All Types" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Types</SelectItem>
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
          <Label htmlFor="insuranceLine">Insurance Line</Label>
          <Select
            value={searchParams.get('insuranceLine') || 'all'}
            onValueChange={(value) => updateFilter('insuranceLine', value)}
          >
            <SelectTrigger id="insuranceLine">
              <SelectValue placeholder="All Lines" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Lines</SelectItem>
              <SelectItem value="PROPERTY">Property</SelectItem>
              <SelectItem value="GENERAL_LIABILITY">General Liability</SelectItem>
              <SelectItem value="AUTO">Auto</SelectItem>
              <SelectItem value="CYBER">Cyber</SelectItem>
              <SelectItem value="PROFESSIONAL_LIABILITY">Professional Liability</SelectItem>
              <SelectItem value="EXCESS">Excess</SelectItem>
              <SelectItem value="WORKERS_COMP">Workers Comp</SelectItem>
              <SelectItem value="EPLI">EPLI</SelectItem>
              <SelectItem value="D_AND_O">D&O</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="severityLevel">Severity</Label>
          <Select
            value={searchParams.get('severityLevel') || 'all'}
            onValueChange={(value) => updateFilter('severityLevel', value)}
          >
            <SelectTrigger id="severityLevel">
              <SelectValue placeholder="All Severities" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Severities</SelectItem>
              <SelectItem value="LOW">Low</SelectItem>
              <SelectItem value="MEDIUM">Medium</SelectItem>
              <SelectItem value="HIGH">High</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="jurisdiction">Jurisdiction</Label>
          <Input
            id="jurisdiction"
            placeholder="Search location..."
            defaultValue={searchParams.get('jurisdiction') || ''}
            onBlur={(e) => updateFilter('jurisdiction', e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                updateFilter('jurisdiction', e.currentTarget.value);
              }
            }}
          />
        </div>
      </div>
    </div>
  );
}

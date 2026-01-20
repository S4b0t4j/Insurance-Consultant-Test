import { z } from 'zod';

export const createSignalSchema = z.object({
  headline: z.string().min(10).max(200),
  summary: z.string().min(50).max(2000),
  sourceUrl: z.string().url().optional(),
  sourcePublication: z.string().optional(),
  publishedAt: z.string().datetime().optional(),
  entityCategory: z.enum(['STATE', 'LOCAL', 'EDUCATION']),
  entityType: z.enum([
    'STATE_AGENCY', 'MUNICIPALITY', 'COUNTY',
    'SCHOOL_DISTRICT', 'CHARTER_SCHOOL',
    'PUBLIC_UNIVERSITY', 'COMMUNITY_COLLEGE',
    'TRANSIT_AUTHORITY', 'UTILITY', 'SPECIAL_DISTRICT'
  ]),
  jurisdiction: z.string().min(2).max(100),
  insuranceLines: z.array(z.enum([
    'PROPERTY', 'GENERAL_LIABILITY', 'AUTO',
    'CYBER', 'PROFESSIONAL_LIABILITY', 'EXCESS',
    'WORKERS_COMP', 'EPLI', 'D_AND_O'
  ])).min(1),
  riskDriverType: z.enum([
    'REGULATORY', 'LITIGATION', 'OPERATIONAL',
    'FINANCIAL', 'CATASTROPHE'
  ]),
  severityLevel: z.enum(['LOW', 'MEDIUM', 'HIGH']),
  whyItMatters: z.string().min(50).max(500),
});

export const updateSignalSchema = createSignalSchema.partial();

export const signalFiltersSchema = z.object({
  entityCategory: z.enum(['STATE', 'LOCAL', 'EDUCATION']).optional(),
  entityType: z.string().optional(),
  jurisdiction: z.string().optional(),
  insuranceLine: z.string().optional(),
  severityLevel: z.enum(['LOW', 'MEDIUM', 'HIGH']).optional(),
  limit: z.coerce.number().min(1).max(100).default(20),
  offset: z.coerce.number().min(0).default(0),
});

export type CreateSignalInput = z.infer<typeof createSignalSchema>;
export type UpdateSignalInput = z.infer<typeof updateSignalSchema>;
export type SignalFilters = z.infer<typeof signalFiltersSchema>;

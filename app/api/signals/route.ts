import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { createSignalSchema, signalFiltersSchema } from '@/lib/validations/signal';
import type { ApiResponse, SledSignal } from '@/types';
import { Prisma } from '@prisma/client';

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;

    const filters = signalFiltersSchema.parse({
      entityCategory: searchParams.get('entityCategory') || undefined,
      entityType: searchParams.get('entityType') || undefined,
      jurisdiction: searchParams.get('jurisdiction') || undefined,
      insuranceLine: searchParams.get('insuranceLine') || undefined,
      severityLevel: searchParams.get('severityLevel') || undefined,
      limit: searchParams.get('limit') || 20,
      offset: searchParams.get('offset') || 0,
    });

    const where: Prisma.SledSignalWhereInput = {};

    if (filters.entityCategory) {
      where.entityCategory = filters.entityCategory;
    }

    if (filters.entityType) {
      where.entityType = filters.entityType as any;
    }

    if (filters.jurisdiction) {
      where.jurisdiction = {
        contains: filters.jurisdiction,
        mode: 'insensitive',
      };
    }

    if (filters.insuranceLine) {
      where.insuranceLines = {
        has: filters.insuranceLine as any,
      };
    }

    if (filters.severityLevel) {
      where.severityLevel = filters.severityLevel;
    }

    const [signals, total] = await Promise.all([
      prisma.sledSignal.findMany({
        where,
        take: filters.limit,
        skip: filters.offset,
        orderBy: {
          publishedAt: 'desc',
        },
      }),
      prisma.sledSignal.count({ where }),
    ]);

    return NextResponse.json<ApiResponse<{ signals: SledSignal[]; total: number }>>({
      data: { signals, total },
      error: null,
    });
  } catch (error) {
    console.error('Error fetching signals:', error);
    return NextResponse.json<ApiResponse<null>>(
      {
        data: null,
        error: error instanceof Error ? error.message : 'Failed to fetch signals',
      },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const validatedData = createSignalSchema.parse(body);

    const signal = await prisma.sledSignal.create({
      data: {
        ...validatedData,
        publishedAt: validatedData.publishedAt ? new Date(validatedData.publishedAt) : null,
      },
    });

    return NextResponse.json<ApiResponse<SledSignal>>(
      {
        data: signal,
        error: null,
      },
      { status: 201 }
    );
  } catch (error) {
    console.error('Error creating signal:', error);
    return NextResponse.json<ApiResponse<null>>(
      {
        data: null,
        error: error instanceof Error ? error.message : 'Failed to create signal',
      },
      { status: 400 }
    );
  }
}

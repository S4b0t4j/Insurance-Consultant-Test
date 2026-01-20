import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { updateSignalSchema } from '@/lib/validations/signal';
import type { ApiResponse, SledSignal } from '@/types';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const signal = await prisma.sledSignal.findUnique({
      where: { id },
    });

    if (!signal) {
      return NextResponse.json<ApiResponse<null>>(
        {
          data: null,
          error: 'Signal not found',
        },
        { status: 404 }
      );
    }

    return NextResponse.json<ApiResponse<SledSignal>>({
      data: signal,
      error: null,
    });
  } catch (error) {
    console.error('Error fetching signal:', error);
    return NextResponse.json<ApiResponse<null>>(
      {
        data: null,
        error: error instanceof Error ? error.message : 'Failed to fetch signal',
      },
      { status: 500 }
    );
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();
    const validatedData = updateSignalSchema.parse(body);

    const signal = await prisma.sledSignal.update({
      where: { id },
      data: {
        ...validatedData,
        publishedAt: validatedData.publishedAt ? new Date(validatedData.publishedAt) : undefined,
      },
    });

    return NextResponse.json<ApiResponse<SledSignal>>({
      data: signal,
      error: null,
    });
  } catch (error) {
    console.error('Error updating signal:', error);
    return NextResponse.json<ApiResponse<null>>(
      {
        data: null,
        error: error instanceof Error ? error.message : 'Failed to update signal',
      },
      { status: 400 }
    );
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    await prisma.sledSignal.delete({
      where: { id },
    });

    return NextResponse.json<ApiResponse<{ success: boolean }>>({
      data: { success: true },
      error: null,
    });
  } catch (error) {
    console.error('Error deleting signal:', error);
    return NextResponse.json<ApiResponse<null>>(
      {
        data: null,
        error: error instanceof Error ? error.message : 'Failed to delete signal',
      },
      { status: 400 }
    );
  }
}

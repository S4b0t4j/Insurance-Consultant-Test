import { UserRole } from '@prisma/client';

// Simple session type for prototype
export type Session = {
  user: {
    id: string;
    email: string;
    name: string | null;
    role: UserRole;
  };
} | null;

// Mock session for prototype - in production, use NextAuth or similar
export async function getSession(): Promise<Session> {
  // For prototype, return a mock admin user
  // In production, this would validate session cookies/tokens
  return {
    user: {
      id: 'mock-user-id',
      email: 'admin@sledinsurance.com',
      name: 'Admin User',
      role: 'ADMIN',
    },
  };
}

export function isAdmin(session: Session): boolean {
  return session?.user?.role === 'ADMIN';
}

export function isViewer(session: Session): boolean {
  return session?.user?.role === 'VIEWER' || isAdmin(session);
}

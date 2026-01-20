export type ApiResponse<T> = {
  data: T | null;
  error: string | null;
};

export type {
  EntityCategory,
  EntityType,
  InsuranceLine,
  RiskDriverType,
  SeverityLevel,
  UserRole,
  User,
  SledSignal,
} from '@prisma/client';

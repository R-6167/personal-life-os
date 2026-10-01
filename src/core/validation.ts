export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export function assertPositive(value: number, field: string): void {
  if (value <= 0) {
    throw new ValidationError(`${field} must be > 0`);
  }
}

export function assertNonNegative(value: number, field: string): void {
  if (value < 0) {
    throw new ValidationError(`${field} must be >= 0`);
  }
}

export function assertDateRange(start: number, end: number): void {
  if (end <= start) {
    throw new ValidationError('end time must be greater than start time');
  }
}

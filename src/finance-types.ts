import type { Timestamp } from './types.js';

export interface FinancialAccount { id: string; owner_id: string; name: string; type: string; currency: string; current_balance?: number | null; institution?: string | null; account_identifier?: string | null; is_tracked: number; created_at: Timestamp; updated_at: Timestamp; archived_at?: number | null; }
export interface Income { id: string; owner_id: string; account_id?: string | null; category_id?: string | null; source: string; amount: number; currency: string; occurred_at: Timestamp; description?: string | null; project_id?: string | null; goal_id?: string | null; created_at: Timestamp; updated_at: Timestamp; }

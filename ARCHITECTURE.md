# PERSONAL LIFE OS

## Database Entities, Relationships & Event Model

---

### 1. Architecture Overview

The database is divided conceptually into five layers:

```
┌─────────────────────────────────────────────┐
│              CORE ENTITIES                  │
│ Projects, Tasks, Goals, Habits, Bills, etc.│
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│                RELATIONSHIPS                │
│ Goal → Project → Milestone → Task           │
│ Task → Event → Activity                     │
│ Bill → Payment → Expense                    │
└──────────────────��───┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│             OCCURRENCES / INSTANCES         │
│ Habit occurrence, bill occurrence,          │
│ routine occurrence, scheduled task, etc.    │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│                 EVENT LOG                   │
│ What actually happened and when             │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│              DERIVED STATE                  │
│ Today, overdue, progress, patterns,         │
│ statistics, upcoming obligations            │
└─────────────────────────────────────────────┘
```

### Key Distinction

**Habit**: "Exercise every Monday, Wednesday and Friday." (the definition)

**Habit occurrence**: "Exercise — Wednesday, October 7." (a specific expected instance)

**Activity event**: "Exercise completed — Wednesday, October 7 at 18:32." (what actually happened)

---

### 2. Universal Entity Rules

Almost every persistent entity should have:

- `id` (UUID or globally unique identifier)
- `createdAt`
- `updatedAt`
- `archivedAt?` (soft deletion)

Entities should generally not be physically deleted immediately when historical references matter:

- Expenses
- Bills
- Projects
- Tasks
- Habits
- Financial records
- Activity history

---

### 3–54: Full Entity Specifications

See detailed entity definitions in the full specification document.

---

### 55. Momentum Integration Contract

Momentum should never directly depend on Personal Life OS's internal database tables.

Instead, query through:

```typescript
PersonalContext {
  currentTime
  today
  availableTime
  upcomingEvents
  activeTasks
  overdueTasks
  activeProjects
  activeGoals
  dueHabits
  activeRoutines
  financialObligations
  practicalObligations
  recentActivity
}
```

This contract allows decoupling and evolution of both systems.

import type { EventRecorder } from '../core/event-recorder.js';
import { assertNonNegative } from '../core/validation.js';
import type { Project } from '../types.js';
import type { ProjectRepository } from '../repositories/project-repository.js';

export class ProjectService {
  constructor(
    private readonly projectRepository: ProjectRepository,
    private readonly eventRecorder: EventRecorder
  ) {}

  createProject(input: Omit<Project, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Project {
    if (!input.title.trim()) throw new Error('Project title is required');
    assertNonNegative(input.priority ?? 0, 'priority');

    const now = Date.now();
    const project: Project = {
      ...input,
      id: input.id ?? crypto.randomUUID(),
      created_at: now,
      updated_at: now,
      status: input.status ?? 'PLANNED',
      priority: input.priority ?? 0,
      progress_mode: input.progress_mode ?? 'CALCULATED',
    };

    const saved = this.projectRepository.create(project);
    this.eventRecorder.record({
      ownerId: project.owner_id,
      eventType: 'PROJECT_CREATED',
      entityType: 'PROJECT',
      entityId: project.id,
      occurredAt: now,
      source: 'ProjectService.createProject',
      metadata: { title: project.title },
    });
    return saved;
  }

  startProject(projectId: string): Project | null {
    const updated = this.projectRepository.update(projectId, { status: 'ACTIVE' });
    if (!updated) return null;
    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'PROJECT_STARTED',
      entityType: 'PROJECT',
      entityId: updated.id,
      source: 'ProjectService.startProject',
    });
    return updated;
  }

  completeProject(projectId: string): Project | null {
    const updated = this.projectRepository.update(projectId, {
      status: 'COMPLETED',
      completed_at: Date.now(),
    });
    if (!updated) return null;
    this.eventRecorder.record({
      ownerId: updated.owner_id,
      eventType: 'PROJECT_COMPLETED',
      entityType: 'PROJECT',
      entityId: updated.id,
      source: 'ProjectService.completeProject',
    });
    return updated;
  }
}

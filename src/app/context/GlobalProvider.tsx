import { SessionProvider } from '@features/session'
import { DexieSessionService } from '@features/session/services/DexieSessionService'
import { SettingsProvider } from '@features/settings'
import { DexieSettingsService } from '@features/settings/services/DexieSettingsService'
import { TasksProvider } from '@features/tasks'
import { TodoistTasksService } from '@features/tasks/services/TodoistTaskService'
import { useMemo } from 'react'

/** Props for the {@link GlobalProvider} component. */
interface GlobalProviderProps {
  /** Child elements that will have access to the provided feature contexts. */
  children: React.ReactNode
}

/**
 * The top-level provider that composes and injects all feature-level services.
 *
 * This component acts as the application's dependency injection root,
 * instantiating each service and wrapping the app in the corresponding
 * React context providers. It ensures the correct dependency order:
 *
 * - `SettingsService` is created first, since other services may depend on it.
 * - `SessionService` manages active Pomodoro sessions.
 * - `TasksService` integrates with Todoist and depends on settings.
 *
 * These services are memoized to maintain stable instances across re-renders.
 */
export function GlobalProvider({ children }: GlobalProviderProps) {
  const settingsService = useMemo(() => new DexieSettingsService(), [])
  const sessionService = useMemo(() => new DexieSessionService(), [])
  const tasksService = useMemo(() => new TodoistTasksService(settingsService), [settingsService])

  return (
    <SettingsProvider service={settingsService}>
      <SessionProvider service={sessionService}>
        <TasksProvider service={tasksService}>{children}</TasksProvider>
      </SessionProvider>
    </SettingsProvider>
  )
}

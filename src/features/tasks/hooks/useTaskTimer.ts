import { useStartSessionFromTask } from '@features/session/hooks/useStartSessionFromTask'
import { Task } from '@types'
import { useState } from 'react'

/**
 * Handles starting a Pomodoro session from a task
 * and controls the timer modal visibility.
 */
export function useTaskTimer() {
  const startSessionFromTask = useStartSessionFromTask()
  const [isModalOpen, setIsModalOpen] = useState(false)

  const handleStartTimer = (task: Task) => {
    startSessionFromTask(task)
    setIsModalOpen(true)
  }

  const handleCloseModal = () => setIsModalOpen(false)

  return { isModalOpen, handleStartTimer, handleCloseModal }
}

import { DataContext } from '@context/data/DataContext'
import { useContext } from 'react'

/**
 * useDataContext Hook.
 *
 * Hook for getting the {DataContext} context.
 *
 * @returns the DataContext context.
 * @throws an exception if not called within the DataProvider component.
 */
export const useDataContext = () => {
  const context = useContext(DataContext)
  if (!context) {
    throw new Error('useDataContext must be used within a DataProvider')
  }
  return context
}

export default useDataContext

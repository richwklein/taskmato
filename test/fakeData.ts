import { Project, ProjectType } from '@types'
import { defaultColor } from '@utils/colors'

export const fakeProjects: Project[] = [
  {
    id: 'inbox',
    name: 'Inbox',
    type: ProjectType.Inbox,
    color: defaultColor,
    parentId: null,
    order: 10,
  },
  {
    id: 'today',
    name: 'Today',
    type: ProjectType.Today,
    color: defaultColor,
    parentId: null,
    order: 5,
  },
  {
    id: 'p1',
    name: 'Work',
    type: ProjectType.Project,
    color: defaultColor,
    parentId: null,
    order: 1,
  },
]

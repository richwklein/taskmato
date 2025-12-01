import { defaultColor } from '@features/tasks/model/colors'
import { Project } from '@types'

export const fakeProjects: Project[] = [
  {
    id: 'inbox',
    name: 'Inbox',
    type: 'inbox',
    color: defaultColor,
    parentId: null,
    order: 10,
  },
  {
    id: 'today',
    name: 'Today',
    type: 'today',
    color: defaultColor,
    parentId: null,
    order: 5,
  },
  {
    id: 'p1',
    name: 'Work',
    type: 'project',
    color: defaultColor,
    parentId: null,
    order: 1,
  },
  {
    id: 'p2',
    name: 'SDLC',
    type: 'project',
    color: defaultColor,
    parentId: 'p1',
    order: 2,
  },
]

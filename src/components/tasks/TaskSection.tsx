import ExpandMoreIcon from '@mui/icons-material/ExpandMore'
import { Accordion, AccordionDetails, AccordionSummary, Typography } from '@mui/material'
import { Section } from '@types'
import React from 'react'

interface TasksSectionProps {
  section: Section
  children?: React.ReactNode
  sx?: object
}

export function TaskSection({ section, sx, children }: TasksSectionProps) {
  const [expanded, setExpanded] = React.useState(true)

  const handleExpansion = () => {
    setExpanded((prevExpanded) => !prevExpanded)
  }

  return (
    <Accordion expanded={expanded} onChange={handleExpansion} sx={{ ...sx }}>
      <AccordionSummary expandIcon={<ExpandMoreIcon />} id={`${section.id}-header`}>
        <Typography variant="h6">{section.name}</Typography>
      </AccordionSummary>
      <AccordionDetails>{children}</AccordionDetails>
    </Accordion>
  )
}

export default TaskSection

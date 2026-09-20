import { motion } from 'framer-motion'
import { useReducedMotion } from '../lib/motion'

// A section's title and its one-line subtitle, when it has one. The optional
// command is the nekoshell subcommand behind the section, set small beside
// the title.
export function SectionHead({ title, sub, cmd }: { title: string; sub?: React.ReactNode; cmd?: string }) {
  const reduced = useReducedMotion()
  return (
    <motion.header
      className="sec-head"
      initial={reduced ? false : { opacity: 0, y: 12 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-10% 0px' }}
      transition={{ type: 'spring', bounce: 0, duration: 0.55 }}
    >
      {cmd && <code className="sec-head__cmd">{cmd}</code>}
      <h2>{title}</h2>
      {sub && <p>{sub}</p>}
    </motion.header>
  )
}

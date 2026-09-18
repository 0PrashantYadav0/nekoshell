import { motion } from 'framer-motion'
import { useReducedMotion } from '../lib/motion'

// A section's title and its one-line subtitle. The optional command is the
// nekoshell subcommand behind the section, set small beside the title.
export function SectionHead({ title, sub, cmd }: { title: string; sub: React.ReactNode; cmd?: string }) {
  const reduced = useReducedMotion()
  return (
    <motion.header
      className="sec-head"
      initial={reduced ? false : { opacity: 0, y: 12 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-10% 0px' }}
      transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
    >
      {cmd && <code className="sec-head__cmd">{cmd}</code>}
      <h2>{title}</h2>
      <p>{sub}</p>
    </motion.header>
  )
}

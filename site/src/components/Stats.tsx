import { motion } from 'framer-motion'
import { useReducedMotion } from '../lib/motion'

const stats: [string, string][] = [
  ['1', 'command installs, themes and checks it'],
  ['5', 'terminals, one adapter each'],
  ['24', 'plugins, three profiles'],
  ['4', 'Catppuccin flavours'],
]

export function Stats() {
  const reduced = useReducedMotion()
  return (
    <div className="stats-wrap">
      <ul className="wrap stats">
        {stats.map(([n, label], i) => (
          <motion.li
            key={label}
            initial={reduced ? false : { opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-5% 0px' }}
            transition={{ type: 'spring', bounce: 0, duration: 0.5, delay: i * 0.06 }}
          >
            <b>{n}</b>
            <span>{label}</span>
          </motion.li>
        ))}
      </ul>
    </div>
  )
}

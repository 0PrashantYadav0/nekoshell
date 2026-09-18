import { motion } from 'framer-motion'
import { Prompt } from './Prompt'
import { GitHubIcon } from './Nav'
import { author } from '../data/content'
import { useReducedMotion } from '../lib/motion'

export function About() {
  const reduced = useReducedMotion()
  return (
    <section className="section" id="author">
      <div className="wrap">
        <Prompt cmd="whoami" out={<>the person behind the cat</>} />
        <div className="about">
          <img className="about__avatar" src={author.avatar} alt="" width={120} height={120} loading="lazy" />
          <div>
            <h3>{author.name}</h3>
            <div className="about__handle">@{author.handle}</div>
            <p>{author.bio}</p>
            <div className="about__links">
              <a className="btn btn--fill" href={author.portfolio} target="_blank" rel="noreferrer">prashantyadav.vercel.app</a>
              <a className="btn" href={author.github} target="_blank" rel="noreferrer"><GitHubIcon /> {author.handle}</a>
              <a className="btn" href={author.x} target="_blank" rel="noreferrer">X</a>
            </div>
          </div>
        </div>
        <ul className="hl">
          {author.highlights.map((h, i) => (
            <motion.li
              key={h.k}
              initial={reduced ? false : { opacity: 0, y: 12 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-10% 0px' }}
              transition={{ duration: 0.5, delay: i * 0.08 }}
            >
              <b>{h.k}</b>
              <span>{h.v}</span>
            </motion.li>
          ))}
        </ul>
      </div>
    </section>
  )
}

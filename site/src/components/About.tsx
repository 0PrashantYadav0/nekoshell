import { SectionHead } from './SectionHead'
import { GitHubIcon } from './Nav'
import { author } from '../data/content'

export function About() {
  return (
    <section className="section" id="author">
      <div className="wrap">
        <SectionHead title="Made by Prashant" sub="The person behind the cat." />
        <div className="about">
          <img className="about__avatar" src={author.avatar} alt="" width={96} height={96} loading="lazy" />
          <div>
            <h3>{author.name}</h3>
            <div className="about__handle">@{author.handle}</div>
            <p>{author.bio}</p>
            <div className="about__links">
              <a className="btn btn--fill" href={author.portfolio} target="_blank" rel="noreferrer">prashantyadav.vercel.app</a>
              <a className="btn" href={author.github} target="_blank" rel="noreferrer"><GitHubIcon /> GitHub</a>
              <a className="btn" href={author.x} target="_blank" rel="noreferrer">X</a>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

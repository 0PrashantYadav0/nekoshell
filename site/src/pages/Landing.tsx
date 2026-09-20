import { useEffect } from 'react'
import { Background } from '../components/Background'
import { Nav } from '../components/Nav'
import { Stats } from '../components/Stats'
import { Hero } from '../components/Hero'
import { Demo } from '../components/Demo'
import { Shots } from '../components/Shots'
import { WhatYouGet } from '../components/WhatYouGet'
import { Terminals } from '../components/Terminals'
import { Commands } from '../components/Commands'
import { Plugins } from '../components/Plugins'
import { Themes } from '../components/Themes'
import { Install } from '../components/Install'
import { About } from '../components/About'
import { Footer } from '../components/Footer'

export function Landing() {
  // The sections exist only after React mounts, so a hash in the URL on
  // load finds nothing; look it up once the page is there.
  useEffect(() => {
    document.title = 'nekoshell'
    const id = decodeURIComponent(window.location.hash.slice(1))
    if (!id) return
    document.getElementById(id)?.scrollIntoView()
  }, [])
  return (
    <>
      <a className="skip" href="#demo">Skip to content</a>
      <Background />
      <div className="frame" aria-hidden="true" />
      <Nav />
      <main>
        <Hero />
        <Demo />
        <Stats />
        <Shots />
        <WhatYouGet />
        <Terminals />
        <Commands />
        <Plugins />
        <Themes />
        <Install />
        <About />
      </main>
      <Footer />
    </>
  )
}

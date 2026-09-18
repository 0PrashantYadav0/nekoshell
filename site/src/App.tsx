import { useEffect } from 'react'
import { Background } from './components/Background'
import { Nav } from './components/Nav'
import { Stats } from './components/Stats'
import { Hero } from './components/Hero'
import { Shots } from './components/Shots'
import { WhatYouGet } from './components/WhatYouGet'
import { Terminals } from './components/Terminals'
import { Commands } from './components/Commands'
import { Plugins } from './components/Plugins'
import { Themes } from './components/Themes'
import { Install } from './components/Install'
import { About } from './components/About'
import { Footer } from './components/Footer'

export default function App() {
  // The sections exist only after React mounts, so a hash in the URL on
  // load finds nothing; look it up once the page is there.
  useEffect(() => {
    const id = decodeURIComponent(window.location.hash.slice(1))
    if (!id) return
    document.getElementById(id)?.scrollIntoView()
  }, [])
  return (
    <>
      <a className="skip" href="#greet">Skip to content</a>
      <Background />
      <div className="frame" aria-hidden="true" />
      <Nav />
      <main>
        <Hero />
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

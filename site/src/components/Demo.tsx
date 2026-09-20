import { useEffect, useRef } from 'react'
import { useInView } from 'framer-motion'
import { SectionHead } from './SectionHead'
import { useNearViewport, useReducedMotion } from '../lib/motion'

// The demo recording, under the hero. It plays by itself, muted and looping,
// once its frame has come near the viewport and the reader has not asked for
// reduced motion; otherwise it waits at its poster for the play control. It
// pauses when it scrolls out of view and, if it was playing by itself, picks
// up again when it comes back; a reader who pressed pause is left alone.
export function Demo() {
  const [frame, near] = useNearViewport<HTMLDivElement>('200px')
  const inView = useInView(frame, { amount: 0.2 })
  const reduced = useReducedMotion()
  const video = useRef<HTMLVideoElement>(null)
  const held = useRef(false)
  const shown = useRef(false)
  const auto = near && !reduced

  useEffect(() => {
    const v = video.current
    if (!v) return
    shown.current = inView
    if (!inView) {
      if (!v.paused) v.pause()
      return
    }
    if (auto && !held.current) {
      v.muted = true
      v.play().catch(() => {})
    }
  }, [auto, inView])

  return (
    <section className="section" id="demo">
      <div className="wrap">
        <SectionHead cmd="nekoshell greet && nekoshell theme latte" title="Thirty seconds of nekoshell" />
        <figure className="demo">
          <div className="demo__frame" ref={frame}>
            {/* No <track>: the recording's audio is music only, no speech, so
                there is nothing to caption; what it shows is in the caption. */}
            <video
              ref={video}
              src="/demo.mp4"
              poster="/shots/demo.jpg"
              width={1920}
              height={1080}
              playsInline
              preload="metadata"
              controls
              muted
              loop={auto}
              onPause={() => {
                // A pause while the frame is on screen is taken as the reader's,
                // including one the browser made (a data saver, a tab put to
                // sleep): it is not undone by scrolling.
                if (shown.current) held.current = true
              }}
              onPlay={() => {
                held.current = false
              }}
            />
          </div>
          <figcaption className="demo__cap">
            <p>The greeting, a flavour switch from mocha to latte, the plugins, and the one-line install.</p>
            <a href="/demo.mp4" download>Download the MP4</a>
          </figcaption>
        </figure>
      </div>
    </section>
  )
}

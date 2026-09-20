import { useEffect, useRef } from 'react'
import { motion, useSpring, useTransform } from 'framer-motion'
import { useReducedMotion } from '../lib/motion'
import { swipeStep, wrapIndex } from '../lib/gallery'

export type LightboxItem = { file: string; art: string; caption: string; height: number }

type Props = {
  items: LightboxItem[]
  // The item on show, or null while the box is shut.
  index: number | null
  // The tile that opened it: the picture grows out of it, shrinks back into
  // it, and the focus returns to it.
  origin: HTMLElement | null
  onIndex: (i: number) => void
  onClose: () => void
}

// One critically damped spring for every move: no overshoot, and a new target
// set mid-flight steers the move from wherever the picture is. The values are
// springs of their own (useSpring) rather than calls to framer's standalone
// animate(), which would add its whole element-animation layer to the bundle
// for four numbers; a spring value animates whenever it is set and jumps
// when it is told to.
const spring = { bounce: 0, duration: 0.4 }
const fade = { bounce: 0, duration: 0.25 }

// Where a panel laid out at `panel` has to be moved and scaled to sit over
// `tile`. The panel's rect is its layout rect, before any transform.
function offset(tile: DOMRect, panel: { left: number; top: number; width: number; height: number }) {
  const scale = panel.width > 0 ? tile.width / panel.width : 1
  return {
    x: tile.left + tile.width / 2 - (panel.left + panel.width / 2),
    y: tile.top + tile.height / 2 - (panel.top + panel.height / 2),
    scale,
  }
}

// A native modal dialog holding one screenshot at a time. Arrow keys and a
// horizontal swipe move between the pictures; Escape, the close button and a
// click on the scrim shut it. It opens by growing from the tile that was
// clicked and closes by shrinking back into it, or cuts straight there when
// the reader asked for reduced motion.
export function Lightbox({ items, index, origin, onIndex, onClose }: Props) {
  const dialog = useRef<HTMLDialogElement>(null)
  const panel = useRef<HTMLElement>(null)
  const reduced = useReducedMotion()
  const open = index !== null
  const item = index === null ? null : items[index]

  const x = useSpring(0, spring)
  const y = useSpring(0, spring)
  const scale = useSpring(1, spring)
  const opacity = useSpring(1, fade)
  // The swipe rides on top of the opening move, so the two never fight.
  const swipe = useSpring(0, spring)
  const shift = useTransform(() => x.get() + swipe.get())
  const closing = useRef(false)

  const layout = () => {
    const p = panel.current
    return p ? { left: p.offsetLeft, top: p.offsetTop, width: p.offsetWidth, height: p.offsetHeight } : null
  }

  useEffect(() => {
    const d = dialog.current
    if (!d || !open) return
    if (!d.open) d.showModal()
    swipe.jump(0)
    const from = origin && !reduced && layout()
    if (!from) {
      x.jump(0)
      y.jump(0)
      scale.jump(1)
      opacity.jump(1)
      return
    }
    const at = offset(origin.getBoundingClientRect(), from)
    x.jump(at.x)
    y.jump(at.y)
    scale.jump(at.scale)
    opacity.jump(0)
    x.set(0)
    y.set(0)
    scale.set(1)
    opacity.set(1)
    // The origin changes only when a tile opens the box, so this runs once
    // per opening; the index moving on inside the box does not touch it.
  }, [open, origin, reduced, x, y, scale, opacity, swipe])

  const finish = () => {
    closing.current = false
    dialog.current?.close()
  }

  // The dialog shuts once the picture has settled over its tile.
  useEffect(() => scale.on('animationComplete', () => closing.current && finish()), [scale])

  const close = () => {
    const d = dialog.current
    if (!d?.open) return
    const to = origin && !reduced && layout()
    if (!to) return finish()
    const at = offset(origin.getBoundingClientRect(), to)
    closing.current = true
    x.set(at.x)
    y.set(at.y)
    scale.set(at.scale)
    opacity.set(0)
  }

  const step = (by: number) => {
    if (index === null) return
    onIndex(wrapIndex(index, by, items.length))
  }

  // 1:1 tracking while the finger is down, then the release velocity is
  // handed to the spring that takes the picture home.
  const drag = useRef<{ x0: number; last: number; t: number; dt: number; vx: number } | null>(null)
  const onPointerDown = (e: React.PointerEvent<HTMLElement>) => {
    if (e.button !== 0) return
    e.currentTarget.setPointerCapture(e.pointerId)
    // A grab takes the picture over from a spring still settling it.
    swipe.jump(swipe.get())
    drag.current = { x0: e.clientX - swipe.get(), last: swipe.get(), t: e.timeStamp, dt: 16, vx: 0 }
  }
  const onPointerMove = (e: React.PointerEvent<HTMLElement>) => {
    const g = drag.current
    if (!g) return
    const dx = e.clientX - g.x0
    const dt = e.timeStamp - g.t
    if (dt > 0) {
      g.vx = ((dx - g.last) / dt) * 1000
      g.dt = dt
      g.last = swipe.get()
      g.t = e.timeStamp
    }
    swipe.jump(dx, false)
  }
  const onPointerUp = (e: React.PointerEvent<HTMLElement>) => {
    const g = drag.current
    if (!g) return
    drag.current = null
    const dx = e.clientX - g.x0
    const by = swipeStep(dx, g.vx)
    if (by) step(by)
    if (reduced) return swipe.jump(0)
    // The spring home starts at the finger's speed: the value is told where
    // it was a frame ago, so the velocity it reads is the release velocity.
    swipe.jump(dx, false)
    swipe.setWithVelocity(g.last, dx, g.dt)
    swipe.set(0)
  }

  return (
    <dialog
      ref={dialog}
      className="lightbox"
      aria-labelledby="lightbox-cap"
      onCancel={(e) => {
        e.preventDefault()
        close()
      }}
      onClose={() => {
        origin?.focus()
        onClose()
      }}
      onClick={(e) => {
        if (e.target === e.currentTarget) close()
      }}
      onKeyDown={(e) => {
        if (e.key === 'ArrowRight') step(1)
        else if (e.key === 'ArrowLeft') step(-1)
      }}
    >
      <button type="button" className="btn btn--icon lightbox__close" aria-label="Close" onClick={close}>
        <svg viewBox="0 0 16 16" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
          <path d="M3 3l10 10M13 3L3 13" />
        </svg>
      </button>
      {item && (
        <motion.figure
          ref={panel}
          className="lightbox__panel"
          style={{ x: shift, y, scale, opacity }}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
        >
          <img src={item.file} alt={`An iTerm2 window after nekoshell greet --art ${item.art}`} width={1600} height={item.height} draggable={false} />
          <figcaption id="lightbox-cap" className="lightbox__cap">
            <code>nekoshell greet --art {item.art}</code>
            <p>{item.caption}</p>
          </figcaption>
        </motion.figure>
      )}
    </dialog>
  )
}

import { useEffect, useRef } from 'react'

// The page's background: a dot grid on the base colour, three slow colour
// fields in the flavour's own hues, and a spotlight that follows the pointer
// and brightens the grid around it. It sits fixed behind everything; the
// spotlight is driven by two CSS variables updated once per frame.
export function Background() {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    let raf = 0
    let x = window.innerWidth / 2
    let y = window.innerHeight / 3
    const paint = () => {
      el.style.setProperty('--mx', `${x}px`)
      el.style.setProperty('--my', `${y}px`)
      raf = 0
    }
    const move = (e: PointerEvent) => {
      x = e.clientX
      y = e.clientY
      if (!raf) raf = requestAnimationFrame(paint)
    }
    paint()
    window.addEventListener('pointermove', move, { passive: true })
    return () => {
      window.removeEventListener('pointermove', move)
      if (raf) cancelAnimationFrame(raf)
    }
  }, [])
  return (
    <div className="bg" ref={ref} aria-hidden="true">
      <div className="bg__field bg__field--a" />
      <div className="bg__field bg__field--b" />
      <div className="bg__field bg__field--c" />
      <div className="bg__grid" />
      <div className="bg__spot" />
    </div>
  )
}

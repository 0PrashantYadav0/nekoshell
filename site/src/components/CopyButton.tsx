import { useEffect, useRef, useState } from 'react'

// Copies a block of text and says so for a moment. The label is the live
// region, so a screen reader hears "Copied" without the focus moving. Where a
// page has several of these in a row, `label` says which one this is; the
// button still reads "Copy" on the page.
export function CopyButton({ text, className = 'copy', label }: { text: string; className?: string; label?: string }) {
  const [done, setDone] = useState(false)
  const timer = useRef<number>(0)
  useEffect(() => () => window.clearTimeout(timer.current), [])
  const copy = () => {
    // A browser that refuses the clipboard says nothing rather than throwing.
    navigator.clipboard?.writeText(text).then(
      () => {
        setDone(true)
        window.clearTimeout(timer.current)
        timer.current = window.setTimeout(() => setDone(false), 1500)
      },
      () => {},
    )
  }
  return (
    <button type="button" className={className} data-done={done} onClick={copy} aria-label={label} aria-live="polite">
      {done ? 'Copied' : 'Copy'}
    </button>
  )
}

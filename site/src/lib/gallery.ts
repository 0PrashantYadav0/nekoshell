// The arithmetic behind the screenshot lightbox: which picture comes next,
// and whether a swipe was one.

// The index `step` places after `i`, wrapping at either end of `n` items.
export function wrapIndex(i: number, step: number, n: number): number {
  if (n <= 0) return 0
  return (((i + step) % n) + n) % n
}

// A horizontal drag becomes a step when it went far enough or fast enough
// in one direction: -1 for a swipe to the right (the previous picture), 1 for
// a swipe to the left (the next), 0 when it was a tap or a wobble. Distance
// in px, velocity in px/s.
export function swipeStep(dx: number, vx: number, minDistance = 60, minVelocity = 500): -1 | 0 | 1 {
  if (Math.abs(dx) < minDistance && Math.abs(vx) < minVelocity) return 0
  // Direction comes from the velocity when there is any: a drag that went
  // out and came back is read by where the finger was going when it let go.
  const sign = Math.abs(vx) >= minVelocity ? Math.sign(vx) : Math.sign(dx)
  return sign < 0 ? 1 : sign > 0 ? -1 : 0
}

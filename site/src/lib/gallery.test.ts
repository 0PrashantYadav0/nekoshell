import { describe, expect, it } from 'vitest'
import { swipeStep, wrapIndex } from './gallery'

describe('wrapIndex', () => {
  it('steps forward and wraps to the first', () => {
    expect(wrapIndex(0, 1, 4)).toBe(1)
    expect(wrapIndex(3, 1, 4)).toBe(0)
  })

  it('steps back and wraps to the last', () => {
    expect(wrapIndex(2, -1, 4)).toBe(1)
    expect(wrapIndex(0, -1, 4)).toBe(3)
  })

  it('stays put with no step, and survives an empty list', () => {
    expect(wrapIndex(2, 0, 4)).toBe(2)
    expect(wrapIndex(0, 1, 0)).toBe(0)
  })
})

describe('swipeStep', () => {
  it('reads a tap or a wobble as nothing', () => {
    expect(swipeStep(0, 0)).toBe(0)
    expect(swipeStep(20, 100)).toBe(0)
    expect(swipeStep(-59, -499)).toBe(0)
  })

  it('reads a long drag by its distance', () => {
    expect(swipeStep(-80, 0)).toBe(1)
    expect(swipeStep(80, 0)).toBe(-1)
  })

  it('reads a short flick by its velocity', () => {
    expect(swipeStep(-20, -900)).toBe(1)
    expect(swipeStep(20, 900)).toBe(-1)
  })

  it('lets the release direction win over where the finger ended', () => {
    expect(swipeStep(-80, 900)).toBe(-1)
  })
})

import { describe, expect, it } from 'vitest'
import { flavours, pickFlavour } from './flavour'

describe('pickFlavour', () => {
  it('takes the saved flavour when it names one', () => {
    for (const f of flavours) expect(pickFlavour(f, false)).toBe(f)
  })

  it('ignores a saved value that is not a flavour', () => {
    expect(pickFlavour('nekoshell.flavour', false)).toBe('mocha')
    expect(pickFlavour('MOCHA', false)).toBe('mocha')
    expect(pickFlavour('', false)).toBe('mocha')
  })

  it('follows the Mac when nothing is saved', () => {
    expect(pickFlavour(null, true)).toBe('latte')
    expect(pickFlavour(null, false)).toBe('mocha')
  })

  it('lets a saved flavour outrank the Mac', () => {
    expect(pickFlavour('mocha', true)).toBe('mocha')
    expect(pickFlavour('latte', false)).toBe('latte')
  })
})

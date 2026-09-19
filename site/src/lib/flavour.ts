import { createContext, useContext } from 'react'
import palettes from '../data/palettes.json'

export type Flavour = 'mocha' | 'macchiato' | 'frappe' | 'latte'
export const flavours: Flavour[] = ['mocha', 'macchiato', 'frappe', 'latte']
export type Palette = Record<string, string>
export const paletteOf = (f: Flavour): Palette => palettes[f] as Palette
// The fourteen accent colours, in the order the greeting's swatch prints them.
export const accents = ['rosewater', 'flamingo', 'pink', 'mauve', 'red', 'maroon', 'peach', 'yellow', 'green', 'teal', 'sky', 'sapphire', 'blue', 'lavender']
export const shades = ['text', 'subtext1', 'subtext0', 'overlay2', 'overlay1', 'overlay0', 'surface2', 'surface1', 'surface0', 'base', 'mantle', 'crust']

// Where the chosen flavour is kept between visits.
export const flavourKey = 'nekoshell.flavour'

export const isFlavour = (v: unknown): v is Flavour => typeof v === 'string' && (flavours as string[]).includes(v)

// The flavour a visit starts in: the one saved last, when it names a flavour,
// and otherwise the one the Mac's own appearance asks for. Pure, so the rule
// reads and tests without a browser.
export function pickFlavour(saved: string | null, prefersLight: boolean): Flavour {
  if (isFlavour(saved)) return saved
  return prefersLight ? 'latte' : 'mocha'
}

export type FlavourState = { flavour: Flavour; setFlavour: (f: Flavour) => void; palette: Palette }
export const FlavourCtx = createContext<FlavourState>({ flavour: 'mocha', setFlavour: () => {}, palette: paletteOf('mocha') })
export const useFlavour = () => useContext(FlavourCtx)

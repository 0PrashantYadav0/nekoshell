import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { FlavourCtx, paletteOf, type Flavour } from './flavour'

// Holds the flavour in force and writes its palette onto :root as CSS
// variables, one per Catppuccin colour name, so the stylesheet and the 3D
// scenes change together.
export function FlavourProvider({ children }: { children: ReactNode }) {
  const [flavour, setFlavour] = useState<Flavour>('mocha')
  const palette = useMemo(() => paletteOf(flavour), [flavour])
  useEffect(() => {
    const root = document.documentElement
    for (const [k, v] of Object.entries(palette)) root.style.setProperty(`--${k}`, `#${v}`)
    root.dataset.flavour = flavour
  }, [flavour, palette])
  return <FlavourCtx.Provider value={{ flavour, setFlavour, palette }}>{children}</FlavourCtx.Provider>
}

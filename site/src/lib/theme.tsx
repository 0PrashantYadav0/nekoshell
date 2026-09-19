import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { FlavourCtx, flavourKey, paletteOf, pickFlavour, type Flavour } from './flavour'

// A browser with site data shut off throws on the first touch of
// localStorage, so both the read and the write are allowed to fail.
function saved(): string | null {
  try {
    return window.localStorage.getItem(flavourKey)
  } catch {
    return null
  }
}

function save(flavour: Flavour) {
  try {
    window.localStorage.setItem(flavourKey, flavour)
  } catch {
    /* the choice then lasts for this visit only */
  }
}

// Holds the flavour in force and writes its palette onto :root as CSS
// variables, one per Catppuccin colour name, so the stylesheet and the 3D
// scenes change together. The choice outlives the visit: it is read back on
// mount, and until there is one the Mac's own appearance picks it.
export function FlavourProvider({ children }: { children: ReactNode }) {
  const [flavour, setFlavour] = useState<Flavour>(() => pickFlavour(saved(), window.matchMedia('(prefers-color-scheme: light)').matches))
  const palette = useMemo(() => paletteOf(flavour), [flavour])
  useEffect(() => {
    const root = document.documentElement
    for (const [k, v] of Object.entries(palette)) root.style.setProperty(`--${k}`, `#${v}`)
    root.dataset.flavour = flavour
    save(flavour)
  }, [flavour, palette])
  return <FlavourCtx.Provider value={{ flavour, setFlavour, palette }}>{children}</FlavourCtx.Provider>
}

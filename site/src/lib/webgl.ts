// Asked once: a browser with WebGL switched off, or a machine that cannot
// give a context, gets the still picture instead and fetches no three.js.
let supported: boolean | null = null

export function hasWebGL(): boolean {
  if (supported !== null) return supported
  try {
    const probe = document.createElement('canvas')
    supported = Boolean(probe.getContext('webgl2') || probe.getContext('webgl'))
  } catch {
    supported = false
  }
  return supported
}

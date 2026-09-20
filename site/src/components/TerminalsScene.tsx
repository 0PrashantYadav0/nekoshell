import { useEffect, useMemo, useRef } from 'react'
import { useFrame, type ThreeEvent } from '@react-three/fiber'
import { RoundedBox } from '@react-three/drei'
import * as THREE from 'three'
import type { MotionValue } from 'framer-motion'
import { terminals } from '../data/content'
import { useFlavour, type Palette } from '../lib/flavour'

// Five window slabs, one per terminal adapter, each with a screen drawn on a
// canvas: a title bar, the prompt line, a few lines in the flavour. Scrolling
// the section fans them from a stack into a row. The slab under the pointer,
// or the one whose row the pointer is on, comes forward; a slab hovered
// directly also turns to face the pointer as it moves across it.
function screen(name: string, hue: string, p: Palette): THREE.CanvasTexture {
  const c = document.createElement('canvas')
  c.width = 512
  c.height = 336
  const g = c.getContext('2d')!
  const col = (k: string) => `#${p[k]}`
  g.fillStyle = col('mantle')
  g.fillRect(0, 0, c.width, c.height)
  g.fillStyle = col('crust')
  g.fillRect(0, 0, c.width, 40)
  for (const [i, k] of ['red', 'yellow', 'green'].entries()) {
    g.fillStyle = col(k)
    g.beginPath()
    g.arc(26 + i * 22, 20, 6, 0, Math.PI * 2)
    g.fill()
  }
  g.font = '500 17px "JetBrains Mono", monospace'
  g.fillStyle = col('overlay1')
  g.textAlign = 'center'
  g.fillText(name, c.width / 2, 26)
  g.textAlign = 'left'
  g.font = '500 20px "JetBrains Mono", monospace'
  const line = (y: number, parts: [string, string][]) => {
    let x = 24
    for (const [t, k] of parts) {
      g.fillStyle = col(k)
      g.fillText(t, x, y)
      x += g.measureText(t).width
    }
  }
  line(84, [['❯ ', 'green'], ['nekoshell ', 'text'], ['greet', 'peach']])
  line(122, [['neko', hue], ['@', 'overlay1'], ['mac', 'blue'], ['  macOS 26  ', 'subtext0'], ['zsh 5.9', 'subtext0']])
  line(154, [['memory  ', 'subtext0'], ['5.2 GiB / 16 GiB', 'text']])
  line(186, [['uptime  ', 'subtext0'], ['3 days, 4 hours', 'text']])
  const sw = ['rosewater', 'flamingo', 'pink', 'mauve', 'red', 'maroon', 'peach', 'yellow', 'green', 'teal', 'sky', 'sapphire', 'blue', 'lavender']
  sw.forEach((k, i) => {
    g.fillStyle = col(k)
    g.fillRect(24 + i * 30, 214, 24, 24)
  })
  line(290, [['❯ ', 'green'], ['', 'text']])
  g.fillStyle = col('text')
  g.fillRect(48, 272, 11, 22)
  const t = new THREE.CanvasTexture(c)
  t.colorSpace = THREE.SRGBColorSpace
  t.anisotropy = 4
  return t
}

const N = terminals.length

// How far a hovered slab turns toward the pointer, in radians per unit of
// normalised pointer offset from the slab's centre. The pointer at the slab's
// edge is roughly 0.15 of the canvas away, so the turn stays under 0.2 rad.
const TURN = 1.2
const MAX_TURN = 0.3

type Props = {
  progress: MotionValue<number>
  hovered: string | null
  onHover: (id: string | null) => void
  reduced: boolean
}

export default function TerminalsScene({ progress, hovered, onHover, reduced }: Props) {
  const { palette } = useFlavour()
  const textures = useMemo(() => terminals.map((t) => screen(t.name, t.hue, palette)), [palette])
  useEffect(() => () => textures.forEach((t) => t.dispose()), [textures])
  const refs = useRef<(THREE.Group | null)[]>([])
  const hoverRef = useRef<string | null>(hovered)
  // The slab the pointer is over inside the canvas; only that one turns.
  const underPointer = useRef<string | null>(null)
  useEffect(() => {
    hoverRef.current = hovered
    if (hovered === null) underPointer.current = null
  }, [hovered])

  const over = (id: string) => (e: ThreeEvent<PointerEvent>) => {
    e.stopPropagation()
    underPointer.current = id
    document.body.style.cursor = 'pointer'
    onHover(id)
  }
  const out = (id: string) => (e: ThreeEvent<PointerEvent>) => {
    e.stopPropagation()
    if (underPointer.current === id) underPointer.current = null
    document.body.style.cursor = ''
    onHover(null)
  }
  useEffect(() => () => { document.body.style.cursor = '' }, [])

  const projected = useMemo(() => new THREE.Vector3(), [])
  useFrame((state, dt) => {
    const p = progress.get()
    const k = 1 - Math.exp(-dt * 6)
    refs.current.forEach((g, i) => {
      if (!g) return
      const c = i - (N - 1) / 2
      // Stacked: same spot, stepping back. Fanned: a shallow arc across.
      const sx = c * 0.18
      const sy = -c * 0.12
      const sz = -i * 0.5
      const fx = c * 1.05
      const fy = Math.abs(c) * -0.1
      const fz = -Math.abs(c) * 1.7
      const lift = hoverRef.current === terminals[i].id ? 1 : 0
      // The picked slab comes to one plane in front of the rest, wherever it
      // sat in the fan, so no neighbour hides it, and slides in toward the
      // middle by as much as it sat out, so the canvas edge does not cut it.
      // It grows as it comes, so the pointer that picked it stays on it.
      const tx = THREE.MathUtils.lerp(sx, fx, p) - lift * c * 0.65
      const ty = THREE.MathUtils.lerp(sy, fy, p) + lift * 0.25 + Math.sin(state.clock.elapsedTime * 0.9 + i) * 0.03
      const tz = THREE.MathUtils.lerp(sz, fz, p) + lift * (Math.abs(fz) + 0.35)
      g.position.x += (tx - g.position.x) * k
      g.position.y += (ty - g.position.y) * k
      g.position.z += (tz - g.position.z) * k
      // A picked slab squares up to the camera out of the fan's arc, then
      // takes the pointer's tilt on top.
      let ry = THREE.MathUtils.lerp(-0.35, -c * 0.42, p) * (1 - lift)
      let rx = -lift * 0.12
      if (!reduced && underPointer.current === terminals[i].id) {
        // Turn toward the pointer: its offset from where the slab's centre
        // lands on screen, so the slab faces the cursor rather than the
        // canvas's middle.
        projected.copy(g.position).project(state.camera)
        const dx = THREE.MathUtils.clamp((state.pointer.x - projected.x) * TURN, -MAX_TURN, MAX_TURN)
        const dy = THREE.MathUtils.clamp((state.pointer.y - projected.y) * TURN, -MAX_TURN, MAX_TURN)
        ry += dx
        rx -= dy
      }
      g.rotation.y += (ry - g.rotation.y) * k
      g.rotation.x += (rx - g.rotation.x) * k
    })
  })

  return (
    <>
      <ambientLight intensity={0.9} />
      <directionalLight position={[3, 5, 6]} intensity={1.8} />
      <directionalLight position={[-4, 2, -3]} intensity={1.2} color={`#${palette.mauve}`} />
      {terminals.map((t, i) => (
        <group key={t.id} ref={(el) => { refs.current[i] = el }} position={[0, 0, -i * 0.5]} onPointerOver={over(t.id)} onPointerOut={out(t.id)}>
          <RoundedBox args={[2.3, 1.55, 0.09]} radius={0.06} smoothness={4}>
            <meshStandardMaterial color={`#${palette.surface0}`} roughness={0.6} />
          </RoundedBox>
          <mesh position={[0, 0, 0.047]}>
            <planeGeometry args={[2.18, 1.43]} />
            <meshBasicMaterial map={textures[i]} toneMapped={false} />
          </mesh>
          <mesh position={[0, -0.86, 0.02]}>
            <planeGeometry args={[2.3, 0.05]} />
            <meshBasicMaterial color={`#${palette[t.hue]}`} toneMapped={false} />
          </mesh>
        </group>
      ))}
    </>
  )
}

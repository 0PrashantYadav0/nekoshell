import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { RoundedBox } from '@react-three/drei'
import * as THREE from 'three'
import { accents, shades, useFlavour } from '../lib/flavour'
import { useReducedMotion } from '../lib/motion'

// The 26 colours of the flavour in force: the 14 accents on an outer ring,
// the 12 shades on an inner one, both turning around a prompt block. A
// flavour switch fades every sphere to its new colour.
export default function PaletteScene() {
  const { palette } = useFlavour()
  const reduced = useReducedMotion()
  const outer = useRef<THREE.Group>(null)
  const inner = useRef<THREE.Group>(null)
  const mats = useRef<THREE.MeshStandardMaterial[]>([])
  const block = useRef<THREE.MeshStandardMaterial>(null)
  const targets = useMemo(() => [...accents, ...shades].map((k) => new THREE.Color(`#${palette[k]}`)), [palette])
  const blockTarget = useMemo(() => new THREE.Color(`#${palette.mauve}`), [palette])

  useFrame((state, dt) => {
    const t = state.clock.elapsedTime
    if (!reduced) {
      if (outer.current) outer.current.rotation.y = t * 0.18
      if (inner.current) inner.current.rotation.y = -t * 0.26
      if (outer.current) outer.current.rotation.x = Math.sin(t * 0.2) * 0.12
    }
    const k = 1 - Math.exp(-dt * 4)
    mats.current.forEach((m, i) => m && m.color.lerp(targets[i], k))
    if (block.current) block.current.color.lerp(blockTarget, k)
  })

  const ring = (keys: string[], r: number, size: number, offset: number, ref: React.RefObject<THREE.Group | null>) => (
    <group ref={ref} rotation={[0.35, 0, 0]}>
      {keys.map((k, i) => {
        const a = (i / keys.length) * Math.PI * 2
        return (
          <mesh key={k} position={[Math.cos(a) * r, Math.sin(a * 2) * 0.12, Math.sin(a) * r]}>
            <sphereGeometry args={[size, 28, 20]} />
            <meshStandardMaterial ref={(m) => { if (m) mats.current[offset + i] = m }} color={`#${palette[k]}`} roughness={0.35} />
          </mesh>
        )
      })}
    </group>
  )

  return (
    <>
      <ambientLight intensity={0.8} />
      <directionalLight position={[4, 6, 5]} intensity={2} />
      <directionalLight position={[-4, -2, -4]} intensity={0.8} color={`#${palette.lavender}`} />
      <RoundedBox args={[1.5, 0.5, 0.9]} radius={0.06} smoothness={4} position={[0, -0.2, 0]}>
        <meshStandardMaterial ref={block} color={`#${palette.mauve}`} roughness={0.4} />
      </RoundedBox>
      <mesh position={[0, 0.3, 0]}>
        <boxGeometry args={[0.16, 0.5, 0.16]} />
        <meshStandardMaterial color={`#${palette.yellow}`} roughness={0.4} />
      </mesh>
      {ring(accents, 2.6, 0.24, 0, outer)}
      {ring(shades, 1.5, 0.16, accents.length, inner)}
    </>
  )
}

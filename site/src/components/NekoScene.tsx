import { useMemo, useRef } from 'react'
import { useFrame, useLoader } from '@react-three/fiber'
import { ContactShadows, OrbitControls } from '@react-three/drei'
import { STLLoader } from 'three/examples/jsm/loaders/STLLoader.js'
import * as THREE from 'three'
import { mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js'
import type { MotionValue } from 'framer-motion'
import { useFlavour, type Palette } from '../lib/flavour'

// The mascot, from docs/assets/neko.stl. An STL carries no colours, so each
// vertex is coloured by where it sits, following the part layout in
// docs/assets/gen-neko.py: the block below the cat, the prompt on its front
// face, the eyes, nose, blush, mouth and inner ears on the head. The mesh
// is z-up with the face towards -y; the group turns it y-up, face to +z.
type Parts = { cat: THREE.BufferGeometry; block: THREE.BufferGeometry }

// The STL is one unindexed mesh. Triangles below the block's top face are the
// block and the prompt on it, kept flat-shaded; the rest is the cat, whose
// vertices are merged so the ellipsoids shade smoothly.
function split(raw: THREE.BufferGeometry): Parts {
  const pos = raw.getAttribute('position')
  const cat: number[] = []
  const block: number[] = []
  for (let t = 0; t < pos.count; t += 3) {
    const up = (pos.getZ(t) + pos.getZ(t + 1) + pos.getZ(t + 2)) / 3
    const dst = up < 0.905 ? block : cat
    for (let k = 0; k < 3; k++) dst.push(pos.getX(t + k), pos.getY(t + k), pos.getZ(t + k))
  }
  const make = (arr: number[]) => {
    const g = new THREE.BufferGeometry()
    g.setAttribute('position', new THREE.Float32BufferAttribute(arr, 3))
    return g
  }
  const catG = mergeVertices(make(cat), 1e-4)
  catG.computeVertexNormals()
  const blockG = make(block)
  blockG.computeVertexNormals()
  return { cat: catG, block: blockG }
}

function colourise(geometry: THREE.BufferGeometry, p: Palette): THREE.BufferGeometry {
  const g = geometry.clone()
  const pos = g.getAttribute('position')
  const n = pos.count
  const colours = new Float32Array(n * 3)
  const c = new THREE.Color()
  const hex = (k: string) => `#${p[k]}`
  // A black cat in every flavour: the generator's fur colour, not the palette's.
  const fur = new THREE.Color('#181825').lerp(new THREE.Color('#000000'), 0.35)
  const set = (i: number, col: THREE.Color) => {
    colours[i * 3] = col.r
    colours[i * 3 + 1] = col.g
    colours[i * 3 + 2] = col.b
  }
  for (let i = 0; i < n; i++) {
    const x = pos.getX(i)
    const up = pos.getZ(i)
    const fwd = -pos.getY(i)
    if (up < 0.905) {
      // The prompt on the front face is two boxes between up 0.26 and 0.62,
      // proud of the face at fwd 0.95; the face's own corners sit at 0 and 0.9.
      if (fwd > 0.949 && up > 0.2 && up < 0.7) set(i, c.set(x > -0.35 ? hex('yellow') : hex('base')))
      else set(i, c.set(hex('mauve')))
      continue
    }
    // Head parts: head centre is (0, 2.62, 0.14) in these axes.
    const inEye = Math.abs(Math.abs(x) - 0.46) < 0.23 && Math.abs(up - 2.56) < 0.29 && fwd > 1.04
    if (inEye) {
      if (fwd > 1.25 && up > 2.6) set(i, c.set('#f8f8ff'))
      else if (fwd > 1.235) set(i, c.set(hex('crust')))
      else set(i, c.set(hex('green')))
      continue
    }
    if (Math.abs(x) < 0.1 && Math.abs(up - 2.36) < 0.08 && fwd > 1.1) { set(i, c.set(hex('red'))); continue }
    if (Math.abs(Math.abs(x) - 0.8) < 0.18 && Math.abs(up - 2.3) < 0.11 && fwd > 0.88) { set(i, c.set(hex('red'))); continue }
    if (Math.abs(x) < 0.33 && up > 2.13 && up < 2.29 && fwd > 1.0) { set(i, c.set(hex('pink'))); continue }
    if (up > 3.28 && Math.abs(x) > 0.45 && Math.abs(x) < 1.12 && fwd > 0.22) { set(i, c.set(hex('pink'))); continue }
    set(i, fur)
  }
  g.setAttribute('color', new THREE.BufferAttribute(colours, 3))
  return g
}

function NekoModel({ spin, drag = true }: { spin?: MotionValue<number>; drag?: boolean }) {
  const raw = useLoader(STLLoader, '/models/neko.stl')
  const { palette } = useFlavour()
  const parts = useMemo(() => split(raw), [raw])
  const cat = useMemo(() => colourise(parts.cat, palette), [parts, palette])
  const block = useMemo(() => colourise(parts.block, palette), [parts, palette])
  const group = useRef<THREE.Group>(null)
  const idle = useRef(0)

  useFrame((state, dt) => {
    if (!group.current) return
    idle.current += dt
    const scrolled = spin ? spin.get() : 0
    // The neko turns with the scroll (and the drag), never on its own.
    group.current.rotation.y = scrolled
    group.current.position.y = -1.95 + Math.sin(idle.current * 1.4) * 0.06
    state.camera.lookAt(0, 0.05, 0)
  })

  return (
    <>
      <group ref={group} position={[0, -1.95, 0]}>
        <mesh geometry={cat} rotation={[-Math.PI / 2, 0, 0]} castShadow>
          <meshStandardMaterial vertexColors roughness={0.5} metalness={0.05} />
        </mesh>
        <mesh geometry={block} rotation={[-Math.PI / 2, 0, 0]} castShadow receiveShadow>
          <meshStandardMaterial vertexColors roughness={0.45} metalness={0.02} />
        </mesh>
      </group>
      <ContactShadows position={[0, -2.02, 0]} opacity={0.55} scale={7} blur={2.4} far={3} color="#000000" />
      {drag && <OrbitControls enableZoom={false} enablePan={false} minPolarAngle={Math.PI / 3} maxPolarAngle={Math.PI / 1.8} target={[0, 0.05, 0]} />}
    </>
  )
}

export default function NekoScene({ spin }: { spin?: MotionValue<number> }) {
  return (
    <>
      <NekoLights />
      <NekoModel spin={spin} />
    </>
  )
}

function NekoLights() {
  const { palette } = useFlavour()
  return (
    <>
      <ambientLight intensity={0.6} color={`#${palette.text}`} />
      <hemisphereLight args={[`#${palette.lavender}`, `#${palette.crust}`, 0.7]} />
      <directionalLight position={[4, 6, 6]} intensity={2.2} color="#fff6ea" />
      <directionalLight position={[-5, 3, -4]} intensity={2.6} color={`#${palette.mauve}`} />
      <pointLight position={[0, 2.5, 4]} intensity={6} color={`#${palette.green}`} distance={7} decay={2} />
    </>
  )
}

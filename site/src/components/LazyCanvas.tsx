import { Suspense, lazy, type ReactNode } from 'react'
import type { CanvasProps } from '@react-three/fiber'

// three.js and the fiber renderer are their own chunk, fetched the first
// time a scene comes near the viewport, so the page's own bundle stays small.
const Canvas = lazy(() => import('@react-three/fiber').then((m) => ({ default: m.Canvas })))
import { useNearViewport } from '../lib/motion'

// A three.js canvas that mounts only once its box is near the viewport, so
// the page paints before any scene loads. The wrapper keeps its size from
// the start, so nothing shifts when the scene appears.
export function LazyCanvas({ children, className, ...rest }: { children: ReactNode; className?: string } & Omit<CanvasProps, 'children'>) {
  const [ref, near] = useNearViewport<HTMLDivElement>('300px')
  return (
    <div ref={ref} className={className} style={{ position: 'relative', width: '100%', height: '100%' }}>
      {near && (
        <Suspense fallback={null}>
          <Canvas dpr={[1, 1.75]} gl={{ antialias: true, alpha: true, powerPreference: 'high-performance' }} {...rest}>
            <Suspense fallback={null}>{children}</Suspense>
          </Canvas>
        </Suspense>
      )}
    </div>
  )
}

import { Component, Suspense, lazy, type ErrorInfo, type ReactNode } from 'react'
import type { CanvasProps } from '@react-three/fiber'

// three.js and the fiber renderer are their own chunk, fetched the first
// time a scene comes near the viewport, so the page's own bundle stays small.
const Canvas = lazy(() => import('@react-three/fiber').then((m) => ({ default: m.Canvas })))
import { useNearViewport } from '../lib/motion'
import { hasWebGL } from '../lib/webgl'

// A context that dies after it was granted (a lost GPU, a driver that throws
// on the first frame) arrives as a render error: catch it and show the same
// fallback rather than an empty box.
class SceneBoundary extends Component<{ fallback: ReactNode; children: ReactNode }, { failed: boolean }> {
  state = { failed: false }
  static getDerivedStateFromError() {
    return { failed: true }
  }
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.warn('nekoshell: a 3D scene did not start, showing the still picture instead', error, info.componentStack)
  }
  render() {
    return this.state.failed ? this.props.fallback : this.props.children
  }
}

// A three.js canvas that mounts only once its box is near the viewport, so
// the page paints before any scene loads. The wrapper keeps its size from
// the start, so nothing shifts when the scene appears. Without WebGL the
// caller's fallback stands in its place and nothing 3D is fetched at all.
export function LazyCanvas({ children, className, fallback = null, ...rest }: { children: ReactNode; className?: string; fallback?: ReactNode } & Omit<CanvasProps, 'children' | 'fallback'>) {
  const [ref, near] = useNearViewport<HTMLDivElement>('300px')
  const canDraw = hasWebGL()
  return (
    <div ref={ref} className={className} style={{ position: 'relative', width: '100%', height: '100%' }}>
      {!canDraw && fallback}
      {canDraw && near && (
        <SceneBoundary fallback={fallback}>
          <Suspense fallback={null}>
            <Canvas dpr={[1, 1.75]} gl={{ antialias: true, alpha: true, powerPreference: 'high-performance' }} {...rest}>
              <Suspense fallback={null}>{children}</Suspense>
            </Canvas>
          </Suspense>
        </SceneBoundary>
      )}
    </div>
  )
}

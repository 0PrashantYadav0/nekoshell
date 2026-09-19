import { lazy, Suspense } from 'react'
import { Route, Routes } from 'react-router-dom'
import { Landing } from './pages/Landing'
import { NotFound } from './pages/NotFound'

// The documentation, its Markdown and its renderer are a route of their own,
// so nothing of it is downloaded by a reader who stays on the front page.
const Docs = lazy(() => import('./pages/Docs'))

// The chunk arrives in a moment on any connection worth the name, so this is a
// panel holding the space rather than a spinner asking to be watched.
function DocsPanel() {
  return (
    <div className="docs-wait">
      <p>Opening the documentation…</p>
    </div>
  )
}

export default function App() {
  const docs = (
    <Suspense fallback={<DocsPanel />}>
      <Docs />
    </Suspense>
  )
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/docs" element={docs} />
      <Route path="/docs/*" element={docs} />
      <Route path="*" element={<NotFound />} />
    </Routes>
  )
}

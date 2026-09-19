import { useEffect } from 'react'
import { Link } from 'react-router-dom'
import { Background } from '../components/Background'
import { Nav } from '../components/Nav'
import { Footer } from '../components/Footer'

export function NotFound() {
  useEffect(() => {
    document.title = 'Not found · nekoshell'
  }, [])
  return (
    <>
      <Background />
      <Nav />
      <main className="wrap missing">
        <p className="missing__code">404</p>
        <h1>There is no page here</h1>
        <p className="missing__sub">The link is old or mistyped. The front page and the documentation are both a click away.</p>
        <div className="missing__links">
          <Link className="btn btn--fill" to="/">Front page</Link>
          <Link className="btn" to="/docs">Documentation</Link>
        </div>
      </main>
      <Footer />
    </>
  )
}

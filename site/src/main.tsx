import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import { FlavourProvider } from './lib/theme.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <FlavourProvider>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </FlavourProvider>
  </StrictMode>,
)

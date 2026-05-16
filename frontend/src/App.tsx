import React from 'react'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Header from './components/Header'
import Home from './pages/Home'
import Markets from './pages/Markets'
import Governance from './pages/Governance'
import Vault from './pages/Vault'
import './styles.css'

export default function App() {
  return (
    <BrowserRouter>
      <Header />
      <div className="container">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/markets" element={<Markets />} />
          <Route path="/governance" element={<Governance />} />
          <Route path="/vault" element={<Vault />} />
        </Routes>
      </div>
    </BrowserRouter>
  )
}

import React from 'react'
import { Link, useLocation } from 'react-router-dom'
import { Mic, LayoutDashboard, Settings, HelpCircle, Sparkles } from 'lucide-react'
import { useMeetings } from '../contexts/MeetingsContext'

export default function Layout({ children }) {
  const location = useLocation()
  const { apiStatus } = useMeetings()

  const isActive = (path) => location.pathname === path

  return (
    <div className="min-h-screen flex flex-col premium-bg">
      {/* Premium Header */}
      <header className="premium-header text-white relative overflow-hidden">
        {/* Subtle gradient overlay */}
        <div className="absolute inset-0 bg-gradient-to-r from-dw-navy via-dw-navy-light to-dw-navy opacity-90" />

        {/* Decorative elements */}
        <div className="absolute top-0 right-0 w-96 h-96 bg-dw-teal/5 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
        <div className="absolute bottom-0 left-0 w-64 h-64 bg-dw-gold/5 rounded-full blur-3xl translate-y-1/2 -translate-x-1/2" />

        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-20">
            {/* Logo */}
            <Link to="/" className="flex items-center gap-4 group">
              <div className="relative">
                <div className="w-12 h-12 bg-gradient-to-br from-dw-teal to-dw-teal-dark rounded-xl flex items-center justify-center shadow-lg group-hover:shadow-xl transition-all duration-300 group-hover:scale-105">
                  <Mic className="w-6 h-6 text-white" />
                </div>
                <div className="absolute -top-1 -right-1 w-3 h-3 bg-dw-gold rounded-full animate-pulse" />
              </div>
              <div>
                <h1 className="text-2xl font-extrabold tracking-tight dw-logo">
                  D&W <span className="text-dw-gold">Holdings</span>
                </h1>
                <p className="text-xs text-white/60 font-medium tracking-wide">Intelligence Platform</p>
              </div>
            </Link>

            {/* Navigation */}
            <nav className="flex items-center gap-2">
              <Link
                to="/"
                className={`px-5 py-2.5 rounded-xl flex items-center gap-2.5 transition-all duration-200 ${
                  isActive('/')
                    ? 'bg-white/15 text-white shadow-lg backdrop-blur-sm'
                    : 'text-white/70 hover:text-white hover:bg-white/10'
                }`}
              >
                <LayoutDashboard className="w-4 h-4" />
                <span className="text-sm font-semibold">Dashboard</span>
              </Link>
              <Link
                to="/record"
                className={`px-5 py-2.5 rounded-xl flex items-center gap-2.5 transition-all duration-200 ${
                  isActive('/record')
                    ? 'bg-white/15 text-white shadow-lg backdrop-blur-sm'
                    : 'text-white/70 hover:text-white hover:bg-white/10'
                }`}
              >
                <Mic className="w-4 h-4" />
                <span className="text-sm font-semibold">Record</span>
              </Link>
            </nav>

            {/* API Status */}
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-4 px-4 py-2 bg-white/5 rounded-xl backdrop-blur-sm">
                <div className="flex items-center gap-2">
                  <span className={`w-2 h-2 rounded-full ${apiStatus.anthropic ? 'bg-emerald-400 shadow-lg shadow-emerald-400/50' : 'bg-red-400'}`} />
                  <span className="text-xs font-medium text-white/70">Claude AI</span>
                </div>
                <div className="w-px h-4 bg-white/20" />
                <div className="flex items-center gap-2">
                  <span className={`w-2 h-2 rounded-full ${apiStatus.openai ? 'bg-emerald-400 shadow-lg shadow-emerald-400/50' : 'bg-red-400'}`} />
                  <span className="text-xs font-medium text-white/70">Whisper</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 animate-fade-in">
        {children}
      </main>

      {/* Premium Footer */}
      <footer className="bg-white border-t border-gray-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 bg-gradient-to-br from-dw-navy to-dw-navy-light rounded-lg flex items-center justify-center">
                <Sparkles className="w-4 h-4 text-dw-gold" />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-800">
                  D&W Holdings
                </p>
                <p className="text-xs text-gray-500">
                  Enterprise Risk Intelligence
                </p>
              </div>
            </div>
            <div className="flex items-center gap-6">
              <button className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 transition-colors">
                <HelpCircle className="w-4 h-4" />
                <span>Support</span>
              </button>
              <button className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 transition-colors">
                <Settings className="w-4 h-4" />
                <span>Settings</span>
              </button>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}

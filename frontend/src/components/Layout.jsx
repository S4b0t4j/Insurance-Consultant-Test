import React from 'react'
import { Link, useLocation } from 'react-router-dom'
import { Mic, LayoutDashboard, Settings, HelpCircle } from 'lucide-react'
import { useMeetings } from '../contexts/MeetingsContext'

export default function Layout({ children }) {
  const location = useLocation()
  const { apiStatus } = useMeetings()

  const isActive = (path) => location.pathname === path

  return (
    <div className="min-h-screen flex flex-col">
      {/* Header */}
      <header className="bg-marsh-gradient text-white shadow-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            {/* Logo */}
            <Link to="/" className="flex items-center gap-3">
              <div className="w-10 h-10 bg-white rounded-lg flex items-center justify-center">
                <Mic className="w-6 h-6 text-marsh-blue" />
              </div>
              <div>
                <h1 className="text-xl font-bold tracking-tight">MARSH</h1>
                <p className="text-xs text-marsh-accent opacity-90">Meeting Analyzer</p>
              </div>
            </Link>

            {/* Navigation */}
            <nav className="flex items-center gap-1">
              <Link
                to="/"
                className={`px-4 py-2 rounded-lg flex items-center gap-2 transition-colors ${
                  isActive('/')
                    ? 'bg-white/20 text-white'
                    : 'text-white/80 hover:text-white hover:bg-white/10'
                }`}
              >
                <LayoutDashboard className="w-4 h-4" />
                <span className="text-sm font-medium">Dashboard</span>
              </Link>
              <Link
                to="/record"
                className={`px-4 py-2 rounded-lg flex items-center gap-2 transition-colors ${
                  isActive('/record')
                    ? 'bg-white/20 text-white'
                    : 'text-white/80 hover:text-white hover:bg-white/10'
                }`}
              >
                <Mic className="w-4 h-4" />
                <span className="text-sm font-medium">Record</span>
              </Link>
            </nav>

            {/* API Status */}
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-2 text-xs">
                <span className={`w-2 h-2 rounded-full ${apiStatus.anthropic ? 'bg-green-400' : 'bg-red-400'}`} />
                <span className="opacity-80">Claude</span>
              </div>
              <div className="flex items-center gap-2 text-xs">
                <span className={`w-2 h-2 rounded-full ${apiStatus.openai ? 'bg-green-400' : 'bg-red-400'}`} />
                <span className="opacity-80">Whisper</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1">
        {children}
      </main>

      {/* Footer */}
      <footer className="bg-gray-100 border-t border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <div className="text-sm text-gray-500">
              <span className="font-medium text-marsh-blue">MARSH</span>
              <span className="mx-2">|</span>
              <span>A business of Marsh McLennan</span>
            </div>
            <div className="flex items-center gap-4 text-sm text-gray-500">
              <span className="flex items-center gap-1">
                <HelpCircle className="w-4 h-4" />
                Help
              </span>
              <span className="flex items-center gap-1">
                <Settings className="w-4 h-4" />
                Settings
              </span>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}

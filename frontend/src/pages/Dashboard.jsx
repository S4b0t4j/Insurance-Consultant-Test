import React, { useState, useMemo } from 'react'
import { Link } from 'react-router-dom'
import {
  Mic, Search, Filter, Clock, FileText, Brain,
  Download, Trash2, ChevronRight, Shield, AlertTriangle,
  FileSpreadsheet, RefreshCw, TrendingUp, Sparkles, Plus
} from 'lucide-react'
import { useMeetings } from '../contexts/MeetingsContext'

const MEETING_TYPES = [
  'Sales/Discovery',
  'Fact-Finding Session (RFP)',
  'Strategy',
  'Client Check-in',
  'Internal Planning'
]

const CONFIDENTIALITY_LEVELS = [
  'Public',
  'Internal',
  'Confidential',
  'Highly Confidential'
]

export default function Dashboard() {
  const { meetings, loading, error, refreshMeetings, deleteMeeting } = useMeetings()
  const [searchQuery, setSearchQuery] = useState('')
  const [filterType, setFilterType] = useState('')
  const [filterConfidentiality, setFilterConfidentiality] = useState('')
  const [showFilters, setShowFilters] = useState(false)

  const filteredMeetings = useMemo(() => {
    return meetings.filter(meeting => {
      const matchesSearch = !searchQuery ||
        meeting.title?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        meeting.clientName?.toLowerCase().includes(searchQuery.toLowerCase())

      const matchesType = !filterType || meeting.meetingType === filterType
      const matchesConfidentiality = !filterConfidentiality || meeting.confidentiality === filterConfidentiality

      return matchesSearch && matchesType && matchesConfidentiality
    })
  }, [meetings, searchQuery, filterType, filterConfidentiality])

  const stats = useMemo(() => ({
    total: meetings.length,
    rfpSessions: meetings.filter(m => m.meetingType === 'Fact-Finding Session (RFP)').length,
    analyzed: meetings.filter(m => m.status === 'analyzed' || m.status === 'researched').length,
    thisWeek: meetings.filter(m => {
      const weekAgo = new Date()
      weekAgo.setDate(weekAgo.getDate() - 7)
      return new Date(m.createdAt) >= weekAgo
    }).length
  }), [meetings])

  const handleDelete = async (id, e) => {
    e.preventDefault()
    e.stopPropagation()
    if (window.confirm('Are you sure you want to delete this meeting?')) {
      try {
        await deleteMeeting(id)
      } catch (err) {
        alert('Failed to delete meeting')
      }
    }
  }

  const getStatusBadge = (status) => {
    const badges = {
      recorded: { label: 'Recorded', class: 'bg-gray-100 text-gray-600 border border-gray-200' },
      transcribing: { label: 'Transcribing...', class: 'bg-amber-50 text-amber-600 border border-amber-200' },
      transcribed: { label: 'Transcribed', class: 'bg-blue-50 text-blue-600 border border-blue-200' },
      analyzing: { label: 'Analyzing...', class: 'bg-amber-50 text-amber-600 border border-amber-200' },
      analyzed: { label: 'Analyzed', class: 'bg-emerald-50 text-emerald-600 border border-emerald-200' },
      researching: { label: 'Researching...', class: 'bg-purple-50 text-purple-600 border border-purple-200' },
      researched: { label: 'Complete', class: 'bg-purple-50 text-purple-600 border border-purple-200' },
      error: { label: 'Error', class: 'bg-red-50 text-red-600 border border-red-200' }
    }
    return badges[status] || badges.recorded
  }

  const getMeetingTypeBadge = (type) => {
    const badges = {
      'Sales/Discovery': 'badge-sales',
      'Fact-Finding Session (RFP)': 'badge-rfp',
      'Strategy': 'badge-strategy',
      'Client Check-in': 'badge-checkin',
      'Internal Planning': 'badge-internal'
    }
    return badges[type] || 'badge-internal'
  }

  const getConfidentialityBadge = (level) => {
    const classes = {
      'Public': 'confidential-public',
      'Internal': 'confidential-internal',
      'Confidential': 'confidential-confidential',
      'Highly Confidential': 'confidential-highly-confidential'
    }
    return classes[level] || classes['Internal']
  }

  const formatDuration = (seconds) => {
    if (!seconds) return '—'
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  const formatDate = (dateStr) => {
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      {/* Welcome Section */}
      <div className="mb-10">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Welcome to <span className="gradient-text">D&W Holdings</span>
        </h1>
        <p className="text-gray-500 text-lg">Your intelligent meeting analysis platform</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">
        <div className="stat-card group">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 mb-1">Total Meetings</p>
              <p className="stat-card-value text-gray-900">{stats.total}</p>
            </div>
            <div className="stat-card-icon bg-gradient-to-br from-dw-navy to-dw-navy-light group-hover:scale-110 transition-transform duration-300">
              <Mic className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>

        <div className="stat-card group">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 mb-1">RFP Sessions</p>
              <p className="stat-card-value text-purple-600">{stats.rfpSessions}</p>
            </div>
            <div className="stat-card-icon bg-gradient-to-br from-purple-500 to-purple-600 group-hover:scale-110 transition-transform duration-300">
              <FileSpreadsheet className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>

        <div className="stat-card group">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 mb-1">Analyzed</p>
              <p className="stat-card-value text-emerald-600">{stats.analyzed}</p>
            </div>
            <div className="stat-card-icon bg-gradient-to-br from-emerald-500 to-emerald-600 group-hover:scale-110 transition-transform duration-300">
              <Brain className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>

        <div className="stat-card group">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 mb-1">This Week</p>
              <p className="stat-card-value text-dw-teal">{stats.thisWeek}</p>
            </div>
            <div className="stat-card-icon bg-gradient-to-br from-dw-teal to-dw-teal-dark group-hover:scale-110 transition-transform duration-300">
              <TrendingUp className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>
      </div>

      {/* Header & Search */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Recent Meetings</h2>
          <p className="text-gray-500 text-sm">Manage and analyze your recorded sessions</p>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search meetings..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="input-premium pl-11 w-72"
            />
          </div>

          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`btn-premium ${
              showFilters || filterType || filterConfidentiality
                ? 'btn-primary'
                : 'btn-secondary'
            }`}
          >
            <Filter className="w-4 h-4" />
            Filters
          </button>

          <button
            onClick={refreshMeetings}
            className="btn-premium btn-secondary"
            title="Refresh"
          >
            <RefreshCw className="w-4 h-4" />
          </button>

          <Link
            to="/record"
            className="btn-premium btn-primary"
          >
            <Plus className="w-4 h-4" />
            New Recording
          </Link>
        </div>
      </div>

      {/* Filters */}
      {showFilters && (
        <div className="premium-card-static p-5 mb-6 animate-fadeIn">
          <div className="flex flex-wrap items-end gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Meeting Type</label>
              <select
                value={filterType}
                onChange={(e) => setFilterType(e.target.value)}
                className="input-premium py-2.5"
              >
                <option value="">All Types</option>
                {MEETING_TYPES.map(type => (
                  <option key={type} value={type}>{type}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Confidentiality</label>
              <select
                value={filterConfidentiality}
                onChange={(e) => setFilterConfidentiality(e.target.value)}
                className="input-premium py-2.5"
              >
                <option value="">All Levels</option>
                {CONFIDENTIALITY_LEVELS.map(level => (
                  <option key={level} value={level}>{level}</option>
                ))}
              </select>
            </div>

            {(filterType || filterConfidentiality) && (
              <button
                onClick={() => { setFilterType(''); setFilterConfidentiality(''); }}
                className="text-sm font-medium text-dw-teal hover:text-dw-teal-dark transition-colors"
              >
                Clear filters
              </button>
            )}
          </div>
        </div>
      )}

      {/* Loading State */}
      {loading && (
        <div className="flex flex-col items-center justify-center py-20">
          <div className="spinner spinner-lg mb-4" />
          <span className="text-gray-500 font-medium">Loading meetings...</span>
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="premium-card-static p-5 flex items-center gap-4 bg-red-50 border-red-200">
          <div className="w-10 h-10 bg-red-100 rounded-xl flex items-center justify-center flex-shrink-0">
            <AlertTriangle className="w-5 h-5 text-red-600" />
          </div>
          <div>
            <p className="font-medium text-red-800">Error loading meetings</p>
            <p className="text-sm text-red-600">{error}</p>
          </div>
        </div>
      )}

      {/* Empty State */}
      {!loading && !error && filteredMeetings.length === 0 && (
        <div className="premium-card-static p-12 text-center">
          <div className="w-20 h-20 bg-gradient-to-br from-gray-100 to-gray-200 rounded-2xl flex items-center justify-center mx-auto mb-6">
            <Mic className="w-10 h-10 text-gray-400" />
          </div>
          <h3 className="text-xl font-semibold text-gray-900 mb-2">
            {searchQuery || filterType || filterConfidentiality
              ? 'No meetings match your filters'
              : 'No meetings yet'}
          </h3>
          <p className="text-gray-500 mb-8 max-w-md mx-auto">
            {searchQuery || filterType || filterConfidentiality
              ? 'Try adjusting your search or filters to find what you\'re looking for'
              : 'Start by recording your first meeting. Our AI will transcribe and analyze it for actionable insights.'}
          </p>
          <Link
            to="/record"
            className="btn-premium btn-primary inline-flex"
          >
            <Sparkles className="w-4 h-4" />
            Record Your First Meeting
          </Link>
        </div>
      )}

      {/* Meetings List */}
      {!loading && !error && filteredMeetings.length > 0 && (
        <div className="space-y-4">
          {filteredMeetings.map((meeting) => {
            const statusBadge = getStatusBadge(meeting.status)
            const isRFP = meeting.meetingType === 'Fact-Finding Session (RFP)'

            return (
              <Link
                key={meeting.id}
                to={`/meeting/${meeting.id}`}
                className="block meeting-card p-5"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-5 flex-1">
                    {/* Status indicator */}
                    <div className={`status-dot status-${meeting.status}`} />

                    {/* Meeting info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="font-semibold text-gray-900 truncate text-lg">{meeting.title}</h3>
                        {isRFP && (
                          <span className="badge badge-rfp">
                            <FileSpreadsheet className="w-3 h-3" />
                            RFP
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-5 text-sm text-gray-500">
                        <span className="flex items-center gap-1.5">
                          <Clock className="w-3.5 h-3.5" />
                          {formatDate(meeting.createdAt)}
                        </span>
                        <span>{formatDuration(meeting.duration)}</span>
                        {meeting.clientName && (
                          <span className="truncate font-medium text-gray-600">
                            {meeting.clientName}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Badges & Actions */}
                  <div className="flex items-center gap-3">
                    <span className={`badge ${getMeetingTypeBadge(meeting.meetingType)}`}>
                      {meeting.meetingType}
                    </span>
                    <span className={`badge ${getConfidentialityBadge(meeting.confidentiality)}`}>
                      <Shield className="w-3 h-3" />
                      {meeting.confidentiality}
                    </span>
                    <span className={`badge ${statusBadge.class}`}>
                      {statusBadge.label}
                    </span>

                    {/* Quick actions */}
                    <div className="flex items-center gap-1 ml-3">
                      {meeting.analysis && (
                        <button
                          className="p-2 text-gray-400 hover:text-dw-teal hover:bg-dw-teal/10 rounded-lg transition-all duration-200"
                          title="Download"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <Download className="w-4 h-4" />
                        </button>
                      )}
                      <button
                        className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-all duration-200"
                        title="Delete"
                        onClick={(e) => handleDelete(meeting.id, e)}
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                      <ChevronRight className="w-5 h-5 text-gray-300 ml-2" />
                    </div>
                  </div>
                </div>
              </Link>
            )
          })}
        </div>
      )}
    </div>
  )
}

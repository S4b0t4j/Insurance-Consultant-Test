import React, { useState, useMemo } from 'react'
import { Link } from 'react-router-dom'
import {
  Mic, Search, Filter, Clock, FileText, Brain,
  Download, Trash2, ChevronRight, Shield, AlertTriangle,
  FileSpreadsheet, Headphones, Mail, RefreshCw
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
      recorded: { label: 'Recorded', class: 'bg-gray-100 text-gray-700' },
      transcribing: { label: 'Transcribing...', class: 'bg-yellow-100 text-yellow-700' },
      transcribed: { label: 'Transcribed', class: 'bg-blue-100 text-blue-700' },
      analyzing: { label: 'Analyzing...', class: 'bg-yellow-100 text-yellow-700' },
      analyzed: { label: 'Analyzed', class: 'bg-green-100 text-green-700' },
      researching: { label: 'Researching...', class: 'bg-purple-100 text-purple-700' },
      researched: { label: 'Complete', class: 'bg-purple-100 text-purple-700' },
      error: { label: 'Error', class: 'bg-red-100 text-red-700' }
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
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Total Meetings</p>
              <p className="text-3xl font-bold text-gray-900">{stats.total}</p>
            </div>
            <div className="w-12 h-12 bg-marsh-blue/10 rounded-lg flex items-center justify-center">
              <Mic className="w-6 h-6 text-marsh-blue" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">RFP Sessions</p>
              <p className="text-3xl font-bold text-purple-600">{stats.rfpSessions}</p>
            </div>
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <FileSpreadsheet className="w-6 h-6 text-purple-600" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Analyzed</p>
              <p className="text-3xl font-bold text-green-600">{stats.analyzed}</p>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <Brain className="w-6 h-6 text-green-600" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">This Week</p>
              <p className="text-3xl font-bold text-marsh-accent">{stats.thisWeek}</p>
            </div>
            <div className="w-12 h-12 bg-cyan-100 rounded-lg flex items-center justify-center">
              <Clock className="w-6 h-6 text-cyan-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Header & Search */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Meetings</h2>
          <p className="text-gray-500">Manage and analyze your recorded meetings</p>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search meetings..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-marsh-blue/20 focus:border-marsh-blue outline-none w-64"
            />
          </div>

          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`px-4 py-2 rounded-lg border flex items-center gap-2 transition-colors ${
              showFilters || filterType || filterConfidentiality
                ? 'bg-marsh-blue text-white border-marsh-blue'
                : 'border-gray-200 text-gray-600 hover:bg-gray-50'
            }`}
          >
            <Filter className="w-4 h-4" />
            Filters
          </button>

          <button
            onClick={refreshMeetings}
            className="p-2 rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-50"
          >
            <RefreshCw className="w-4 h-4" />
          </button>

          <Link
            to="/record"
            className="px-4 py-2 bg-marsh-blue text-white rounded-lg flex items-center gap-2 hover:bg-marsh-dark-blue transition-colors"
          >
            <Mic className="w-4 h-4" />
            New Recording
          </Link>
        </div>
      </div>

      {/* Filters */}
      {showFilters && (
        <div className="bg-white rounded-lg border border-gray-200 p-4 mb-6 flex flex-wrap gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Meeting Type</label>
            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value)}
              className="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-marsh-blue/20 focus:border-marsh-blue outline-none"
            >
              <option value="">All Types</option>
              {MEETING_TYPES.map(type => (
                <option key={type} value={type}>{type}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Confidentiality</label>
            <select
              value={filterConfidentiality}
              onChange={(e) => setFilterConfidentiality(e.target.value)}
              className="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-marsh-blue/20 focus:border-marsh-blue outline-none"
            >
              <option value="">All Levels</option>
              {CONFIDENTIALITY_LEVELS.map(level => (
                <option key={level} value={level}>{level}</option>
              ))}
            </select>
          </div>

          {(filterType || filterConfidentiality) && (
            <div className="flex items-end">
              <button
                onClick={() => { setFilterType(''); setFilterConfidentiality(''); }}
                className="text-sm text-marsh-blue hover:underline"
              >
                Clear filters
              </button>
            </div>
          )}
        </div>
      )}

      {/* Loading State */}
      {loading && (
        <div className="flex items-center justify-center py-12">
          <div className="spinner border-marsh-blue border-t-transparent" />
          <span className="ml-3 text-gray-500">Loading meetings...</span>
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-center gap-3 text-red-700">
          <AlertTriangle className="w-5 h-5" />
          <span>{error}</span>
        </div>
      )}

      {/* Empty State */}
      {!loading && !error && filteredMeetings.length === 0 && (
        <div className="text-center py-12 bg-white rounded-xl border border-gray-200">
          <Mic className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            {searchQuery || filterType || filterConfidentiality
              ? 'No meetings match your filters'
              : 'No meetings yet'}
          </h3>
          <p className="text-gray-500 mb-6">
            {searchQuery || filterType || filterConfidentiality
              ? 'Try adjusting your search or filters'
              : 'Start by recording your first meeting'}
          </p>
          <Link
            to="/record"
            className="inline-flex items-center gap-2 px-4 py-2 bg-marsh-blue text-white rounded-lg hover:bg-marsh-dark-blue transition-colors"
          >
            <Mic className="w-4 h-4" />
            Record a Meeting
          </Link>
        </div>
      )}

      {/* Meetings List */}
      {!loading && !error && filteredMeetings.length > 0 && (
        <div className="space-y-3">
          {filteredMeetings.map((meeting) => {
            const statusBadge = getStatusBadge(meeting.status)
            const isRFP = meeting.meetingType === 'Fact-Finding Session (RFP)'

            return (
              <Link
                key={meeting.id}
                to={`/meeting/${meeting.id}`}
                className="block bg-white rounded-xl border border-gray-200 p-4 meeting-card hover:border-marsh-blue/30"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4 flex-1">
                    {/* Status indicator */}
                    <div className={`status-dot status-${meeting.status}`} />

                    {/* Meeting info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <h3 className="font-medium text-gray-900 truncate">{meeting.title}</h3>
                        {isRFP && (
                          <span className="px-2 py-0.5 bg-purple-100 text-purple-700 text-xs font-medium rounded-full flex items-center gap-1">
                            <FileSpreadsheet className="w-3 h-3" />
                            RFP
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-4 text-sm text-gray-500">
                        <span>{formatDate(meeting.createdAt)}</span>
                        <span>{formatDuration(meeting.duration)}</span>
                        {meeting.clientName && (
                          <span className="truncate">Client: {meeting.clientName}</span>
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
                      <Shield className="w-3 h-3 mr-1" />
                      {meeting.confidentiality}
                    </span>
                    <span className={`badge ${statusBadge.class}`}>
                      {statusBadge.label}
                    </span>

                    {/* Quick actions */}
                    <div className="flex items-center gap-1 ml-2">
                      {meeting.analysis && (
                        <button
                          className="p-1.5 text-gray-400 hover:text-marsh-blue hover:bg-gray-100 rounded"
                          title="Download"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <Download className="w-4 h-4" />
                        </button>
                      )}
                      <button
                        className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded"
                        title="Delete"
                        onClick={(e) => handleDelete(meeting.id, e)}
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                      <ChevronRight className="w-5 h-5 text-gray-400" />
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

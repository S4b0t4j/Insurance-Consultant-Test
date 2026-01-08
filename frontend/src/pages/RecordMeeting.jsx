import React, { useState, useRef, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Mic, Square, Pause, Play, Save, X, Clock,
  Shield, User, Building, AlertTriangle, Check, Sparkles
} from 'lucide-react'
import { api } from '../utils/api'
import { useMeetings } from '../contexts/MeetingsContext'

const MEETING_TYPES = [
  { value: 'Sales/Discovery', label: 'Sales/Discovery', color: 'green' },
  { value: 'Fact-Finding Session (RFP)', label: 'Fact-Finding Session (RFP)', color: 'purple' },
  { value: 'Strategy', label: 'Strategy', color: 'blue' },
  { value: 'Client Check-in', label: 'Client Check-in', color: 'yellow' },
  { value: 'Internal Planning', label: 'Internal Planning', color: 'gray' }
]

const CONFIDENTIALITY_LEVELS = [
  { value: 'Public', label: 'Public', description: 'Can be shared externally', color: 'green' },
  { value: 'Internal', label: 'Internal', description: 'D&W employees only', color: 'blue' },
  { value: 'Confidential', label: 'Confidential', description: 'Need-to-know basis', color: 'orange' },
  { value: 'Highly Confidential', label: 'Highly Confidential', description: 'Restricted access', color: 'red' }
]

export default function RecordMeeting() {
  const navigate = useNavigate()
  const { refreshMeetings } = useMeetings()

  // Recording state
  const [isRecording, setIsRecording] = useState(false)
  const [isPaused, setIsPaused] = useState(false)
  const [recordingTime, setRecordingTime] = useState(0)
  const [audioBlob, setAudioBlob] = useState(null)
  const [audioUrl, setAudioUrl] = useState(null)

  // Form state
  const [title, setTitle] = useState('')
  const [meetingType, setMeetingType] = useState('Client Check-in')
  const [confidentiality, setConfidentiality] = useState('Internal')
  const [clientName, setClientName] = useState('')
  const [participants, setParticipants] = useState('')
  const [password, setPassword] = useState('')
  const [enablePassword, setEnablePassword] = useState(false)

  // Upload state
  const [uploading, setUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [error, setError] = useState(null)

  // Refs
  const mediaRecorderRef = useRef(null)
  const audioChunksRef = useRef([])
  const timerRef = useRef(null)
  const streamRef = useRef(null)

  // Start recording
  const startRecording = useCallback(async () => {
    try {
      setError(null)
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.current = stream

      const mediaRecorder = new MediaRecorder(stream, {
        mimeType: 'audio/webm;codecs=opus'
      })
      mediaRecorderRef.current = mediaRecorder
      audioChunksRef.current = []

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data)
        }
      }

      mediaRecorder.onstop = () => {
        const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/webm' })
        setAudioBlob(audioBlob)
        setAudioUrl(URL.createObjectURL(audioBlob))
      }

      mediaRecorder.start(1000) // Collect data every second
      setIsRecording(true)
      setIsPaused(false)

      // Start timer
      timerRef.current = setInterval(() => {
        setRecordingTime(prev => prev + 1)
      }, 1000)
    } catch (err) {
      console.error('Error starting recording:', err)
      setError('Failed to access microphone. Please ensure microphone permissions are granted.')
    }
  }, [])

  // Pause recording
  const pauseRecording = useCallback(() => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'recording') {
      mediaRecorderRef.current.pause()
      setIsPaused(true)
      clearInterval(timerRef.current)
    }
  }, [])

  // Resume recording
  const resumeRecording = useCallback(() => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'paused') {
      mediaRecorderRef.current.resume()
      setIsPaused(false)
      timerRef.current = setInterval(() => {
        setRecordingTime(prev => prev + 1)
      }, 1000)
    }
  }, [])

  // Stop recording
  const stopRecording = useCallback(() => {
    if (mediaRecorderRef.current) {
      mediaRecorderRef.current.stop()
      streamRef.current?.getTracks().forEach(track => track.stop())
      clearInterval(timerRef.current)
      setIsRecording(false)
      setIsPaused(false)
    }
  }, [])

  // Discard recording
  const discardRecording = useCallback(() => {
    if (audioUrl) {
      URL.revokeObjectURL(audioUrl)
    }
    setAudioBlob(null)
    setAudioUrl(null)
    setRecordingTime(0)
  }, [audioUrl])

  // Upload and save
  const saveRecording = useCallback(async () => {
    if (!audioBlob) return

    // Auto-set confidentiality for RFP sessions
    const finalConfidentiality = meetingType === 'Fact-Finding Session (RFP)'
      ? (confidentiality === 'Public' || confidentiality === 'Internal' ? 'Confidential' : confidentiality)
      : confidentiality

    try {
      setUploading(true)
      setError(null)

      const formData = new FormData()
      formData.append('audio', audioBlob, `recording-${Date.now()}.webm`)
      formData.append('title', title || `Meeting ${new Date().toLocaleDateString()}`)
      formData.append('meetingType', meetingType)
      formData.append('confidentiality', finalConfidentiality)
      formData.append('clientName', clientName)
      formData.append('participants', JSON.stringify(participants.split(',').map(p => p.trim()).filter(Boolean)))
      if (enablePassword && password) {
        formData.append('password', password)
      }

      const result = await api.uploadRecording(formData, (progress) => {
        setUploadProgress(progress)
      })

      if (result.success) {
        refreshMeetings()
        navigate(`/meeting/${result.meeting.id}`)
      }
    } catch (err) {
      console.error('Upload error:', err)
      setError('Failed to upload recording. Please try again.')
    } finally {
      setUploading(false)
      setUploadProgress(0)
    }
  }, [audioBlob, title, meetingType, confidentiality, clientName, participants, password, enablePassword, refreshMeetings, navigate])

  // Format time
  const formatTime = (seconds) => {
    const hrs = Math.floor(seconds / 3600)
    const mins = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    if (hrs > 0) {
      return `${hrs}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
    }
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      {/* Header */}
      <div className="mb-10">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Record <span className="gradient-text">Meeting</span>
        </h1>
        <p className="text-gray-500 text-lg">Capture and analyze your meeting with AI-powered insights</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Recording Panel */}
        <div className="premium-card-static p-8">
          <div className="flex items-center gap-3 mb-8">
            <div className="w-10 h-10 bg-gradient-to-br from-dw-teal to-dw-teal-dark rounded-xl flex items-center justify-center">
              <Mic className="w-5 h-5 text-white" />
            </div>
            <h2 className="text-xl font-bold text-gray-900">Recording</h2>
          </div>

          {/* Recording Controls */}
          <div className="flex flex-col items-center py-8">
            {/* Waveform visualization */}
            {isRecording && (
              <div className="flex items-center gap-1 h-16 mb-6">
                {[...Array(5)].map((_, i) => (
                  <div
                    key={i}
                    className={`w-1.5 bg-gradient-to-t from-dw-teal to-dw-teal-dark rounded-full waveform-bar ${isPaused ? 'opacity-30' : ''}`}
                    style={{ height: '100%' }}
                  />
                ))}
              </div>
            )}

            {/* Timer */}
            <div className="text-5xl font-mono font-bold text-gray-900 mb-8 tracking-wider">
              {formatTime(recordingTime)}
            </div>

            {/* Recording button */}
            <div className="relative mb-6">
              {isRecording && !isPaused && (
                <div className="absolute inset-0 bg-red-500 rounded-full recording-pulse opacity-30" />
              )}
              {!isRecording && !audioBlob && (
                <button
                  onClick={startRecording}
                  className="w-24 h-24 bg-gradient-to-br from-dw-teal to-dw-teal-dark text-white rounded-full flex items-center justify-center hover:shadow-xl hover:scale-105 transition-all duration-300 shadow-lg"
                >
                  <Mic className="w-10 h-10" />
                </button>
              )}
              {isRecording && (
                <div className="flex items-center gap-4">
                  {isPaused ? (
                    <button
                      onClick={resumeRecording}
                      className="w-16 h-16 bg-gradient-to-br from-emerald-500 to-emerald-600 text-white rounded-full flex items-center justify-center hover:shadow-lg hover:scale-105 transition-all duration-200"
                    >
                      <Play className="w-6 h-6 ml-1" />
                    </button>
                  ) : (
                    <button
                      onClick={pauseRecording}
                      className="w-16 h-16 bg-gradient-to-br from-amber-400 to-amber-500 text-white rounded-full flex items-center justify-center hover:shadow-lg hover:scale-105 transition-all duration-200"
                    >
                      <Pause className="w-6 h-6" />
                    </button>
                  )}
                  <button
                    onClick={stopRecording}
                    className="w-16 h-16 bg-gradient-to-br from-red-500 to-red-600 text-white rounded-full flex items-center justify-center hover:shadow-lg hover:scale-105 transition-all duration-200"
                  >
                    <Square className="w-6 h-6" />
                  </button>
                </div>
              )}
            </div>

            {/* Status text */}
            <p className="text-sm text-gray-500 font-medium">
              {!isRecording && !audioBlob && 'Click to start recording'}
              {isRecording && !isPaused && (
                <span className="flex items-center gap-2">
                  <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse" />
                  Recording in progress...
                </span>
              )}
              {isRecording && isPaused && 'Recording paused'}
            </p>
          </div>

          {/* Audio preview */}
          {audioUrl && (
            <div className="border-t border-gray-100 pt-6 mt-6">
              <h3 className="text-sm font-semibold text-gray-700 mb-3">Recording Preview</h3>
              <audio src={audioUrl} controls className="w-full mb-5" />
              <div className="flex items-center gap-3">
                <button
                  onClick={discardRecording}
                  className="btn-premium btn-secondary flex-1"
                >
                  <X className="w-4 h-4" />
                  Discard
                </button>
                <button
                  onClick={saveRecording}
                  disabled={uploading}
                  className="btn-premium btn-primary flex-1"
                >
                  {uploading ? (
                    <>
                      <div className="spinner" />
                      <span>{uploadProgress}%</span>
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-4 h-4" />
                      Save & Analyze
                    </>
                  )}
                </button>
              </div>
            </div>
          )}

          {/* Error message */}
          {error && (
            <div className="mt-6 p-4 bg-red-50 border border-red-200 rounded-xl flex items-center gap-3 text-red-700 text-sm">
              <AlertTriangle className="w-5 h-5 flex-shrink-0" />
              {error}
            </div>
          )}
        </div>

        {/* Meeting Details Panel */}
        <div className="premium-card-static p-8">
          <div className="flex items-center gap-3 mb-8">
            <div className="w-10 h-10 bg-gradient-to-br from-dw-navy to-dw-navy-light rounded-xl flex items-center justify-center">
              <Building className="w-5 h-5 text-white" />
            </div>
            <h2 className="text-xl font-bold text-gray-900">Meeting Details</h2>
          </div>

          <div className="space-y-6">
            {/* Title */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-2">
                Meeting Title
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Enter meeting title..."
                className="input-premium"
              />
            </div>

            {/* Meeting Type */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-3">
                Meeting Type
              </label>
              <div className="grid grid-cols-1 gap-2">
                {MEETING_TYPES.map((type) => (
                  <label
                    key={type.value}
                    className={`flex items-center p-3.5 rounded-xl border-2 cursor-pointer transition-all duration-200 ${
                      meetingType === type.value
                        ? 'border-dw-teal bg-dw-teal/5 shadow-sm'
                        : 'border-gray-200 hover:border-gray-300 hover:bg-gray-50'
                    }`}
                  >
                    <input
                      type="radio"
                      name="meetingType"
                      value={type.value}
                      checked={meetingType === type.value}
                      onChange={(e) => setMeetingType(e.target.value)}
                      className="sr-only"
                    />
                    <div className={`w-5 h-5 rounded-full border-2 mr-3 flex items-center justify-center transition-colors ${
                      meetingType === type.value ? 'border-dw-teal bg-dw-teal' : 'border-gray-300'
                    }`}>
                      {meetingType === type.value && (
                        <Check className="w-3 h-3 text-white" />
                      )}
                    </div>
                    <span className={`text-sm font-medium ${meetingType === type.value ? 'text-dw-teal' : 'text-gray-700'}`}>
                      {type.label}
                    </span>
                    {type.value === 'Fact-Finding Session (RFP)' && (
                      <span className="ml-auto text-xs bg-purple-100 text-purple-700 px-2.5 py-1 rounded-full font-semibold">
                        RFP Builder
                      </span>
                    )}
                  </label>
                ))}
              </div>
            </div>

            {/* Client Name */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-2">
                <Building className="w-4 h-4 inline mr-1.5 text-gray-500" />
                Client Name
              </label>
              <input
                type="text"
                value={clientName}
                onChange={(e) => setClientName(e.target.value)}
                placeholder="Enter client name..."
                className="input-premium"
              />
            </div>

            {/* Participants */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-2">
                <User className="w-4 h-4 inline mr-1.5 text-gray-500" />
                Participants (comma-separated)
              </label>
              <input
                type="text"
                value={participants}
                onChange={(e) => setParticipants(e.target.value)}
                placeholder="John Smith, Jane Doe..."
                className="input-premium"
              />
            </div>

            {/* Confidentiality */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-3">
                <Shield className="w-4 h-4 inline mr-1.5 text-gray-500" />
                Confidentiality Level
              </label>
              {meetingType === 'Fact-Finding Session (RFP)' && (
                <p className="text-xs text-amber-600 mb-3 flex items-center gap-1.5 bg-amber-50 px-3 py-2 rounded-lg">
                  <AlertTriangle className="w-3.5 h-3.5" />
                  RFP sessions default to Confidential or higher
                </p>
              )}
              <div className="grid grid-cols-2 gap-3">
                {CONFIDENTIALITY_LEVELS.map((level) => {
                  const isDisabled = meetingType === 'Fact-Finding Session (RFP)' &&
                    (level.value === 'Public' || level.value === 'Internal')

                  return (
                    <label
                      key={level.value}
                      className={`flex flex-col p-3.5 rounded-xl border-2 cursor-pointer transition-all duration-200 ${
                        isDisabled ? 'opacity-40 cursor-not-allowed' : ''
                      } ${
                        confidentiality === level.value
                          ? 'border-dw-teal bg-dw-teal/5 shadow-sm'
                          : 'border-gray-200 hover:border-gray-300 hover:bg-gray-50'
                      }`}
                    >
                      <input
                        type="radio"
                        name="confidentiality"
                        value={level.value}
                        checked={confidentiality === level.value}
                        onChange={(e) => !isDisabled && setConfidentiality(e.target.value)}
                        disabled={isDisabled}
                        className="sr-only"
                      />
                      <span className={`text-sm font-semibold ${
                        confidentiality === level.value ? 'text-dw-teal' : 'text-gray-700'
                      }`}>
                        {level.label}
                      </span>
                      <span className="text-xs text-gray-500 mt-0.5">{level.description}</span>
                    </label>
                  )
                })}
              </div>
            </div>

            {/* Password Protection */}
            <div className="pt-2">
              <label className="flex items-center gap-3 cursor-pointer group">
                <div className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-colors ${
                  enablePassword ? 'bg-dw-teal border-dw-teal' : 'border-gray-300 group-hover:border-gray-400'
                }`}>
                  {enablePassword && <Check className="w-3 h-3 text-white" />}
                </div>
                <input
                  type="checkbox"
                  checked={enablePassword}
                  onChange={(e) => setEnablePassword(e.target.checked)}
                  className="sr-only"
                />
                <span className="text-sm font-medium text-gray-700">Password protect this meeting</span>
              </label>
              {enablePassword && (
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password..."
                  className="input-premium mt-3"
                />
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

import React, { useState, useRef, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Mic, Square, Pause, Play, Save, X, Clock,
  Shield, User, Building, AlertTriangle, Check
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
  { value: 'Internal', label: 'Internal', description: 'Marsh employees only', color: 'blue' },
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
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Record Meeting</h1>
        <p className="text-gray-500">Capture and analyze your meeting with AI-powered insights</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Recording Panel */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-6">Recording</h2>

          {/* Recording Controls */}
          <div className="flex flex-col items-center py-8">
            {/* Waveform visualization */}
            {isRecording && (
              <div className="flex items-center gap-1 h-16 mb-6">
                {[...Array(5)].map((_, i) => (
                  <div
                    key={i}
                    className={`w-1 bg-marsh-blue rounded-full waveform-bar ${isPaused ? 'opacity-30' : ''}`}
                    style={{ height: '100%' }}
                  />
                ))}
              </div>
            )}

            {/* Timer */}
            <div className="text-4xl font-mono font-bold text-gray-900 mb-6">
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
                  className="w-20 h-20 bg-marsh-blue text-white rounded-full flex items-center justify-center hover:bg-marsh-dark-blue transition-colors shadow-lg"
                >
                  <Mic className="w-8 h-8" />
                </button>
              )}
              {isRecording && (
                <div className="flex items-center gap-4">
                  {isPaused ? (
                    <button
                      onClick={resumeRecording}
                      className="w-16 h-16 bg-green-600 text-white rounded-full flex items-center justify-center hover:bg-green-700 transition-colors"
                    >
                      <Play className="w-6 h-6 ml-1" />
                    </button>
                  ) : (
                    <button
                      onClick={pauseRecording}
                      className="w-16 h-16 bg-yellow-500 text-white rounded-full flex items-center justify-center hover:bg-yellow-600 transition-colors"
                    >
                      <Pause className="w-6 h-6" />
                    </button>
                  )}
                  <button
                    onClick={stopRecording}
                    className="w-16 h-16 bg-red-600 text-white rounded-full flex items-center justify-center hover:bg-red-700 transition-colors"
                  >
                    <Square className="w-6 h-6" />
                  </button>
                </div>
              )}
            </div>

            {/* Status text */}
            <p className="text-sm text-gray-500">
              {!isRecording && !audioBlob && 'Click to start recording'}
              {isRecording && !isPaused && 'Recording in progress...'}
              {isRecording && isPaused && 'Recording paused'}
            </p>
          </div>

          {/* Audio preview */}
          {audioUrl && (
            <div className="border-t border-gray-200 pt-6 mt-6">
              <h3 className="text-sm font-medium text-gray-700 mb-3">Recording Preview</h3>
              <audio src={audioUrl} controls className="w-full mb-4" />
              <div className="flex items-center gap-3">
                <button
                  onClick={discardRecording}
                  className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 flex items-center justify-center gap-2"
                >
                  <X className="w-4 h-4" />
                  Discard
                </button>
                <button
                  onClick={saveRecording}
                  disabled={uploading}
                  className="flex-1 px-4 py-2 bg-marsh-blue text-white rounded-lg hover:bg-marsh-dark-blue flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  {uploading ? (
                    <>
                      <div className="spinner" />
                      <span>{uploadProgress}%</span>
                    </>
                  ) : (
                    <>
                      <Save className="w-4 h-4" />
                      Save & Analyze
                    </>
                  )}
                </button>
              </div>
            </div>
          )}

          {/* Error message */}
          {error && (
            <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg flex items-center gap-2 text-red-700 text-sm">
              <AlertTriangle className="w-4 h-4 flex-shrink-0" />
              {error}
            </div>
          )}
        </div>

        {/* Meeting Details Panel */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-6">Meeting Details</h2>

          <div className="space-y-5">
            {/* Title */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Meeting Title
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Enter meeting title..."
                className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-marsh-blue/20 focus:border-marsh-blue outline-none"
              />
            </div>

            {/* Meeting Type */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Meeting Type
              </label>
              <div className="grid grid-cols-1 gap-2">
                {MEETING_TYPES.map((type) => (
                  <label
                    key={type.value}
                    className={`flex items-center p-3 rounded-lg border-2 cursor-pointer transition-colors ${
                      meetingType === type.value
                        ? 'border-marsh-blue bg-marsh-blue/5'
                        : 'border-gray-200 hover:border-gray-300'
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
                    <div className={`w-4 h-4 rounded-full border-2 mr-3 flex items-center justify-center ${
                      meetingType === type.value ? 'border-marsh-blue' : 'border-gray-300'
                    }`}>
                      {meetingType === type.value && (
                        <div className="w-2 h-2 rounded-full bg-marsh-blue" />
                      )}
                    </div>
                    <span className={`text-sm ${meetingType === type.value ? 'font-medium text-marsh-blue' : 'text-gray-700'}`}>
                      {type.label}
                    </span>
                    {type.value === 'Fact-Finding Session (RFP)' && (
                      <span className="ml-auto text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full">
                        RFP Builder
                      </span>
                    )}
                  </label>
                ))}
              </div>
            </div>

            {/* Client Name */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                <Building className="w-4 h-4 inline mr-1" />
                Client Name
              </label>
              <input
                type="text"
                value={clientName}
                onChange={(e) => setClientName(e.target.value)}
                placeholder="Enter client name..."
                className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-marsh-blue/20 focus:border-marsh-blue outline-none"
              />
            </div>

            {/* Participants */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                <User className="w-4 h-4 inline mr-1" />
                Participants (comma-separated)
              </label>
              <input
                type="text"
                value={participants}
                onChange={(e) => setParticipants(e.target.value)}
                placeholder="John Smith, Jane Doe..."
                className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-marsh-blue/20 focus:border-marsh-blue outline-none"
              />
            </div>

            {/* Confidentiality */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Shield className="w-4 h-4 inline mr-1" />
                Confidentiality Level
              </label>
              {meetingType === 'Fact-Finding Session (RFP)' && (
                <p className="text-xs text-orange-600 mb-2">
                  RFP sessions default to Confidential or higher
                </p>
              )}
              <div className="grid grid-cols-2 gap-2">
                {CONFIDENTIALITY_LEVELS.map((level) => {
                  const isDisabled = meetingType === 'Fact-Finding Session (RFP)' &&
                    (level.value === 'Public' || level.value === 'Internal')

                  return (
                    <label
                      key={level.value}
                      className={`flex flex-col p-3 rounded-lg border-2 cursor-pointer transition-colors ${
                        isDisabled ? 'opacity-50 cursor-not-allowed' : ''
                      } ${
                        confidentiality === level.value
                          ? 'border-marsh-blue bg-marsh-blue/5'
                          : 'border-gray-200 hover:border-gray-300'
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
                      <span className={`text-sm font-medium ${
                        confidentiality === level.value ? 'text-marsh-blue' : 'text-gray-700'
                      }`}>
                        {level.label}
                      </span>
                      <span className="text-xs text-gray-500">{level.description}</span>
                    </label>
                  )
                })}
              </div>
            </div>

            {/* Password Protection */}
            <div>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={enablePassword}
                  onChange={(e) => setEnablePassword(e.target.checked)}
                  className="w-4 h-4 text-marsh-blue border-gray-300 rounded focus:ring-marsh-blue"
                />
                <span className="text-sm font-medium text-gray-700">Password protect this meeting</span>
              </label>
              {enablePassword && (
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password..."
                  className="mt-2 w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-marsh-blue/20 focus:border-marsh-blue outline-none"
                />
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

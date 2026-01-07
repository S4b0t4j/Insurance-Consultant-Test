import React, { createContext, useContext, useState, useCallback, useEffect } from 'react'
import { api } from '../utils/api'

const MeetingsContext = createContext(null)

export function MeetingsProvider({ children }) {
  const [meetings, setMeetings] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [apiStatus, setApiStatus] = useState({
    anthropic: false,
    openai: false,
    elevenlabs: false,
    unsplash: false
  })

  const fetchMeetings = useCallback(async (filters = {}) => {
    try {
      setLoading(true)
      const data = await api.getMeetings(filters)
      setMeetings(data)
      setError(null)
    } catch (err) {
      setError(err.message)
      console.error('Error fetching meetings:', err)
    } finally {
      setLoading(false)
    }
  }, [])

  const checkApiStatus = useCallback(async () => {
    try {
      const status = await api.checkApiStatus()
      setApiStatus(status)
    } catch (err) {
      console.error('Error checking API status:', err)
    }
  }, [])

  useEffect(() => {
    fetchMeetings()
    checkApiStatus()
  }, [fetchMeetings, checkApiStatus])

  const refreshMeetings = () => fetchMeetings()

  const getMeeting = useCallback(async (id) => {
    try {
      return await api.getMeeting(id)
    } catch (err) {
      console.error('Error fetching meeting:', err)
      throw err
    }
  }, [])

  const updateMeeting = useCallback(async (id, data) => {
    try {
      const updated = await api.updateMeeting(id, data)
      setMeetings(prev => prev.map(m => m.id === id ? updated : m))
      return updated
    } catch (err) {
      console.error('Error updating meeting:', err)
      throw err
    }
  }, [])

  const deleteMeeting = useCallback(async (id) => {
    try {
      await api.deleteMeeting(id)
      setMeetings(prev => prev.filter(m => m.id !== id))
    } catch (err) {
      console.error('Error deleting meeting:', err)
      throw err
    }
  }, [])

  const value = {
    meetings,
    loading,
    error,
    apiStatus,
    fetchMeetings,
    refreshMeetings,
    getMeeting,
    updateMeeting,
    deleteMeeting,
    checkApiStatus
  }

  return (
    <MeetingsContext.Provider value={value}>
      {children}
    </MeetingsContext.Provider>
  )
}

export function useMeetings() {
  const context = useContext(MeetingsContext)
  if (!context) {
    throw new Error('useMeetings must be used within a MeetingsProvider')
  }
  return context
}

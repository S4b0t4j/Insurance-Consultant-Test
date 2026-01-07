import React from 'react'
import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Dashboard from './pages/Dashboard'
import RecordMeeting from './pages/RecordMeeting'
import MeetingDetail from './pages/MeetingDetail'
import { MeetingsProvider } from './contexts/MeetingsContext'

function App() {
  return (
    <MeetingsProvider>
      <Layout>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/record" element={<RecordMeeting />} />
          <Route path="/meeting/:id" element={<MeetingDetail />} />
        </Routes>
      </Layout>
    </MeetingsProvider>
  )
}

export default App

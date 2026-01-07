import axios from 'axios'

const API_BASE = '/api'

const axiosInstance = axios.create({
  baseURL: API_BASE,
  timeout: 300000, // 5 minutes for long operations
})

export const api = {
  // Health & Config
  async checkHealth() {
    const response = await axiosInstance.get('/health')
    return response.data
  },

  async checkApiStatus() {
    const response = await axiosInstance.get('/config/status')
    return response.data
  },

  // Meetings
  async getMeetings(filters = {}) {
    const params = new URLSearchParams()
    if (filters.type) params.append('type', filters.type)
    if (filters.confidentiality) params.append('confidentiality', filters.confidentiality)
    if (filters.search) params.append('search', filters.search)

    const response = await axiosInstance.get(`/recordings?${params}`)
    return response.data
  },

  async getMeeting(id) {
    const response = await axiosInstance.get(`/recordings/${id}`)
    return response.data
  },

  async uploadRecording(formData, onProgress) {
    const response = await axiosInstance.post('/recordings/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      onUploadProgress: (progressEvent) => {
        if (onProgress) {
          const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total)
          onProgress(percentCompleted)
        }
      }
    })
    return response.data
  },

  async updateMeeting(id, data) {
    const response = await axiosInstance.patch(`/recordings/${id}`, data)
    return response.data
  },

  async deleteMeeting(id) {
    const response = await axiosInstance.delete(`/recordings/${id}`)
    return response.data
  },

  // Transcription
  async transcribeMeeting(meetingId) {
    const response = await axiosInstance.post(`/transcription/${meetingId}`)
    return response.data
  },

  async getTranscript(meetingId) {
    const response = await axiosInstance.get(`/transcription/${meetingId}`)
    return response.data
  },

  // Analysis
  async analyzeMeeting(meetingId) {
    const response = await axiosInstance.post(`/analysis/${meetingId}`)
    return response.data
  },

  // Deep Research
  async runDeepResearch(meetingId, focusAreas = []) {
    const response = await axiosInstance.post(`/research/${meetingId}/deep-research`, { focusAreas })
    return response.data
  },

  async getDeepResearch(meetingId) {
    const response = await axiosInstance.get(`/research/${meetingId}/deep-research`)
    return response.data
  },

  // Export
  async generatePowerPoint(meetingId, type = 'internal') {
    const response = await axiosInstance.post(`/export/${meetingId}/powerpoint`, { type })
    return response.data
  },

  async generatePdf(meetingId, options = {}) {
    const response = await axiosInstance.post(`/export/${meetingId}/pdf`, options)
    return response.data
  },

  async generateText(meetingId) {
    const response = await axiosInstance.post(`/export/${meetingId}/text`)
    return response.data
  },

  // Podcast
  async getVoices() {
    const response = await axiosInstance.get('/podcast/voices')
    return response.data
  },

  async generatePodcast(meetingId, voiceType = 'female', voiceId = null) {
    const response = await axiosInstance.post(`/podcast/${meetingId}`, { voiceType, voiceId })
    return response.data
  },

  async getPodcast(meetingId) {
    const response = await axiosInstance.get(`/podcast/${meetingId}`)
    return response.data
  }
}

export default api

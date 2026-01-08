/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        dw: {
          navy: '#0a1628',
          'navy-light': '#1a2d4a',
          'navy-dark': '#050d18',
          gold: '#c9a227',
          'gold-light': '#e3c766',
          'gold-dark': '#9a7b1c',
          teal: '#0d9488',
          'teal-light': '#14b8a6',
          'teal-dark': '#0f766e',
        },
        // Legacy support
        marsh: {
          blue: '#0a1628',
          'dark-blue': '#050d18',
          'light-blue': '#1a2d4a',
          accent: '#0d9488',
        }
      },
      fontFamily: {
        sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
      },
      boxShadow: {
        'premium': '0 25px 50px -12px rgb(0 0 0 / 0.25)',
        'premium-sm': '0 4px 20px rgba(10, 22, 40, 0.1)',
        'premium-lg': '0 10px 40px rgba(10, 22, 40, 0.15)',
      },
      borderRadius: {
        'xl': '16px',
        '2xl': '24px',
      },
      animation: {
        'fade-in': 'fadeIn 0.4s ease-out forwards',
        'slide-in': 'slideIn 0.3s ease-out forwards',
        'pulse-glow': 'pulseGlow 1.5s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        slideIn: {
          '0%': { opacity: '0', transform: 'translateX(-20px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' },
        },
        pulseGlow: {
          '0%, 100%': { boxShadow: '0 0 20px rgba(239, 68, 68, 0.4)' },
          '50%': { boxShadow: '0 0 40px rgba(239, 68, 68, 0.6)' },
        },
      },
    },
  },
  plugins: [],
}

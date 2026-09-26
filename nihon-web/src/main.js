import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'

// Capacitor 打包后 WebView 里没有 vite 代理，把 /api 相对路径重写到后端地址
const API_BASE = (import.meta.env.VITE_API_BASE || '').replace(/\/+$/, '')
if (API_BASE) {
  const origFetch = window.fetch.bind(window)
  window.fetch = (input, init) => {
    if (typeof input === 'string' && input.startsWith('/api/')) {
      input = API_BASE + input
    }
    return origFetch(input, init)
  }
}

createApp(App).use(router).mount('#app')

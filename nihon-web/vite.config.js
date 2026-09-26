import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import legacy from '@vitejs/plugin-legacy'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    // Capacitor WebView 可能运行在较旧的 Android WebView 上，
    // legacy 插件额外生成兼容旧浏览器的 nomodule bundle（含 polyfill），避免白屏
    legacy(),
  ],
  // 相对路径构建：Capacitor WebView 通过 capacitor://localhost 加载，不能用绝对路径
  base: './',
  server: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:5000',
        changeOrigin: true,
      },
    },
  },
  preview: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:5000',
        changeOrigin: true,
      },
    },
  },
})

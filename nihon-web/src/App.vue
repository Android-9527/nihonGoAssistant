<template>
  <div class="layout">
    <header class="topbar">
      <h1 class="brand">NihonGo Assistant</h1>
      <nav class="nav">
        <RouterLink to="/donate" class="nav-link" active-class="is-active">{{ isEn ? 'Donate' : '捐赠' }}</RouterLink>
        <RouterLink to="/home" class="nav-link" active-class="is-active">{{ isEn ? 'Home' : '主页' }}</RouterLink>
        <RouterLink to="/about" class="nav-link" active-class="is-active">{{ isEn ? 'About' : '关于' }}</RouterLink>
        <RouterLink v-if="!isLoggedIn" to="/login" class="nav-link" active-class="is-active">{{ isEn ? 'Log in' : '登录' }}</RouterLink>
        <RouterLink v-else to="/me" class="nav-link" active-class="is-active">{{ isEn ? 'Me' : '我的' }}</RouterLink>
        <button class="lang-btn" type="button" @click="toggleLang">{{ isEn ? '中文' : 'English' }}</button>
      </nav>
    </header>

    <main class="content">
      <RouterView />
    </main>
  </div>
</template>

<script>
import userStore from './store/user';
import languageStore from './store/language';

export default {
  computed: {
    isLoggedIn() {
      return userStore.isLoggedIn.value;
    },
    isEn() {
      return languageStore.isEn();
    },
  },
  methods: {
    toggleLang() {
      languageStore.toggleLang();
    },
  },
};
</script>

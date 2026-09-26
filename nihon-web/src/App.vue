<template>
  <div class="layout">
    <header class="topbar">
      <h1 class="brand">NihonGo Assistant</h1>
      <nav class="nav">
        <RouterLink to="/donate" class="nav-link" active-class="is-active">捐赠</RouterLink>
        <RouterLink to="/home" class="nav-link" active-class="is-active">主页</RouterLink>
        <RouterLink to="/about" class="nav-link" active-class="is-active">关于</RouterLink>
        <RouterLink v-if="!isLoggedIn" to="/login" class="nav-link" active-class="is-active">登录</RouterLink>
        <RouterLink v-else to="/me" class="nav-link" active-class="is-active">我的</RouterLink>
      </nav>
    </header>

    <main class="content">
      <RouterView />
    </main>
  </div>
</template>

<script>
import userStore from './store/user';

export default {
  computed: {
    isLoggedIn() {
      return userStore.isLoggedIn.value;
    },
  },
};
</script>

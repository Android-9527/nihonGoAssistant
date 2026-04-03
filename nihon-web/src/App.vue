<template>
  <div class="layout">
    <header class="topbar">
      <h1 class="brand">Nihon Assistant</h1>
      <nav class="nav">
        <RouterLink to="/home" class="nav-link" active-class="is-active">我的</RouterLink>
      </nav>
    </header>

    <main class="content">
      <RouterView />
    </main>
  </div>
</template>

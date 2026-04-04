<template>
  <div class="layout">
    <header class="topbar">
      <h1 class="brand">Nihon Assistant</h1>
      <nav class="nav">
        <RouterLink to="/donate" class="nav-link" active-class="is-active">捐赠</RouterLink>
        <RouterLink to="/home" class="nav-link" active-class="is-active">主页</RouterLink>
        <RouterLink to="/about" class="nav-link" active-class="is-active">关于</RouterLink>
      </nav>
    </header>

    <main class="content">
      <RouterView />
    </main>
  </div>
</template>

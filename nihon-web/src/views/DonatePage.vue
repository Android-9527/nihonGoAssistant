<template>
  <section class="donate-page">
    <header class="hero">
      <h1>捐赠支持</h1>
      <p>感谢你对 Nihon Assistant 的支持。</p>
    </header>

    <article class="donate-card">
      <img class="alipay-image" src="/Alipay.jpg" alt="支付宝捐赠二维码" />
      <p class="donate-note">
        如果觉得这个 Assistant 有用就使用支付宝向作者捐赠，备注邮箱作者向你发感谢信哦。
      </p>
    </article>
  </section>
</template>

<style scoped>
.donate-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.hero {
  background: linear-gradient(135deg, #e0f2fe, #eef2ff 55%, #fef9c3);
  border: 1px solid #cbd5e1;
  border-radius: 16px;
  padding: 22px;
}

.hero h1 {
  margin: 0;
  color: #0f172a;
}

.hero p {
  margin: 6px 0 0;
  color: #334155;
}

.donate-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 18px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.alipay-image {
  width: min(300px, 100%);
  border: 1px solid #d1d5db;
  border-radius: 10px;
}

.donate-note {
  margin: 0;
  color: #334155;
  font-size: 18px;
  line-height: 1.9;
  font-weight: 600;
  text-align: center;
}
</style>

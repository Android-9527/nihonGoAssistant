<template>
  <section class="auth-wrap">
    <div class="auth-card">
      <h1>{{ isRegister ? '注册账号' : '登录' }}</h1>
      <p class="auth-sub">
        {{ isRegister ? '注册后可使用测试与复习功能（记录掌握度）' : '登录后可使用测试与复习功能（记录掌握度）' }}
      </p>

      <div class="auth-tabs">
        <button
          class="auth-tab"
          :class="{ active: !isRegister }"
          @click="switchMode(false)"
        >
          登录
        </button>
        <button
          class="auth-tab"
          :class="{ active: isRegister }"
          @click="switchMode(true)"
        >
          注册
        </button>
      </div>

      <form class="auth-form" @submit.prevent="submit">
        <label class="auth-field">
          <span>邮箱</span>
          <input
            v-model.trim="email"
            type="email"
            autocomplete="email"
            placeholder="you@example.com"
            required
          />
        </label>

        <label v-if="isRegister" class="auth-field">
          <span>昵称（可选）</span>
          <input
            v-model.trim="nickname"
            type="text"
            maxlength="30"
            placeholder="默认取邮箱前缀"
          />
        </label>

        <label class="auth-field">
          <span>密码</span>
          <input
            v-model="password"
            type="password"
            :autocomplete="isRegister ? 'new-password' : 'current-password'"
            placeholder="至少 6 位"
            required
          />
        </label>

        <p v-if="errorText" class="auth-error">{{ errorText }}</p>

        <button class="auth-submit" type="submit" :disabled="loading">
          {{ loading ? '请稍候...' : isRegister ? '注册并登录' : '登录' }}
        </button>
      </form>

      <p class="auth-hint">
        游客可自由浏览全部学习内容；点击「测试」「复习」时再登录即可。
      </p>
    </div>
  </section>
</template>

<script>
import { login, register } from '../store/user';

export default {
  data() {
    return {
      isRegister: false,
      email: '',
      password: '',
      nickname: '',
      loading: false,
      errorText: '',
    };
  },
  methods: {
    switchMode(registerMode) {
      this.isRegister = registerMode;
      this.errorText = '';
    },
    async submit() {
      this.errorText = '';
      if (!this.email || !this.password) {
        this.errorText = '请填写邮箱和密码';
        return;
      }
      if (this.isRegister && this.password.length < 6) {
        this.errorText = '密码至少 6 位';
        return;
      }
      this.loading = true;
      try {
        if (this.isRegister) {
          await register(this.email, this.password, this.nickname);
        } else {
          await login(this.email, this.password);
        }
        const redirect = this.$route.query.redirect || '/home';
        this.$router.replace(redirect);
      } catch (error) {
        this.errorText = error.message || '操作失败';
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
.auth-wrap {
  display: flex;
  justify-content: center;
  padding: 30px 12px;
}

.auth-card {
  width: 100%;
  max-width: 420px;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.06);
}

.auth-card h1 {
  margin: 0;
  font-size: 22px;
  color: #0f172a;
}

.auth-sub {
  margin: 6px 0 0;
  color: #64748b;
  font-size: 13px;
}

.auth-tabs {
  margin-top: 16px;
  display: flex;
  border: 1px solid #cbd5e1;
  border-radius: 10px;
  overflow: hidden;
}

.auth-tab {
  flex: 1;
  padding: 9px 0;
  border: 0;
  background: #f8fafc;
  color: #475569;
  cursor: pointer;
  font-size: 14px;
}

.auth-tab.active {
  background: #22c55e;
  color: #fff;
  font-weight: 600;
}

.auth-form {
  margin-top: 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.auth-field {
  display: flex;
  flex-direction: column;
  gap: 5px;
  font-size: 13px;
  color: #334155;
}

.auth-field input {
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  padding: 9px 11px;
  font-size: 14px;
}

.auth-field input:focus {
  outline: 2px solid #86efac;
  border-color: #22c55e;
}

.auth-error {
  margin: 0;
  color: #b91c1c;
  font-size: 13px;
}

.auth-submit {
  border: 0;
  background: #16a34a;
  color: #fff;
  border-radius: 10px;
  padding: 11px 0;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
}

.auth-submit:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.auth-hint {
  margin: 14px 0 0;
  color: #94a3b8;
  font-size: 12px;
}
</style>

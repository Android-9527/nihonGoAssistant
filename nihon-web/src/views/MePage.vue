<template>
  <section class="me-wrap">
    <header>
      <h1>我的账户</h1>
      <p>管理登录信息与账户设置。</p>
    </header>

    <div v-if="user" class="me-card">
      <div class="me-info">
        <div class="me-row"><span>邮箱</span><strong>{{ user.email }}</strong></div>
        <div class="me-row"><span>昵称</span><strong>{{ user.nickname || '（未设置）' }}</strong></div>
        <div class="me-row"><span>注册时间</span><strong>{{ user.created_at }}</strong></div>
      </div>

      <div class="me-section">
        <h2>修改昵称</h2>
        <div class="me-form">
          <input v-model.trim="nickname" maxlength="30" placeholder="新昵称" />
          <button class="me-btn" :disabled="savingNick || !nickname" @click="saveNickname">
            {{ savingNick ? '保存中...' : '保存' }}
          </button>
        </div>
        <p v-if="nickMsg" class="me-msg" :class="{ ok: nickOk }">{{ nickMsg }}</p>
      </div>

      <div class="me-section">
        <h2>修改密码</h2>
        <div class="me-form me-form-col">
          <input v-model="oldPassword" type="password" placeholder="原密码" />
          <input v-model="newPassword" type="password" placeholder="新密码（至少 6 位）" />
          <button class="me-btn" :disabled="savingPwd || !oldPassword || !newPassword" @click="savePassword">
            {{ savingPwd ? '保存中...' : '修改密码' }}
          </button>
        </div>
        <p v-if="pwdMsg" class="me-msg" :class="{ ok: pwdOk }">{{ pwdMsg }}</p>
      </div>

      <div class="me-section">
        <button class="me-btn me-btn-danger" @click="doLogout">退出登录</button>
      </div>
    </div>

    <p v-else class="me-loading">加载账户信息中...</p>
  </section>
</template>

<script>
import userStore, { fetchMe, updateMe, logout } from '../store/user';

export default {
  data() {
    return {
      user: null,
      nickname: '',
      oldPassword: '',
      newPassword: '',
      savingNick: false,
      savingPwd: false,
      nickMsg: '',
      nickOk: false,
      pwdMsg: '',
      pwdOk: false,
    };
  },
  async mounted() {
    try {
      this.user = await fetchMe();
      this.nickname = this.user.nickname || '';
    } catch (error) {
      this.user = userStore.state.user;
    }
  },
  methods: {
    async saveNickname() {
      this.savingNick = true;
      this.nickMsg = '';
      try {
        this.user = await updateMe({ nickname: this.nickname });
        this.nickMsg = '昵称已更新';
        this.nickOk = true;
      } catch (error) {
        this.nickMsg = error.message || '更新失败';
        this.nickOk = false;
      } finally {
        this.savingNick = false;
      }
    },
    async savePassword() {
      if (this.newPassword.length < 6) {
        this.pwdMsg = '新密码至少 6 位';
        this.pwdOk = false;
        return;
      }
      this.savingPwd = true;
      this.pwdMsg = '';
      try {
        await updateMe({ old_password: this.oldPassword, new_password: this.newPassword });
        this.oldPassword = '';
        this.newPassword = '';
        this.pwdMsg = '密码已修改';
        this.pwdOk = true;
      } catch (error) {
        this.pwdMsg = error.message || '修改失败';
        this.pwdOk = false;
      } finally {
        this.savingPwd = false;
      }
    },
    async doLogout() {
      await logout();
      this.$router.replace('/home');
    },
  },
};
</script>

<style scoped>
.me-wrap {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

header h1 {
  margin: 0;
  color: #0f172a;
}

header p {
  margin: 6px 0 0;
  color: #475569;
}

.me-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 16px;
  max-width: 560px;
}

.me-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-bottom: 14px;
  border-bottom: 1px solid #f1f5f9;
}

.me-row {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  font-size: 14px;
}

.me-row span {
  color: #64748b;
}

.me-section {
  margin-top: 16px;
}

.me-section h2 {
  margin: 0 0 8px;
  font-size: 15px;
  color: #0f172a;
}

.me-form {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.me-form-col {
  flex-direction: column;
  max-width: 340px;
}

.me-form input {
  flex: 1;
  min-width: 200px;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  padding: 8px 10px;
  font-size: 14px;
}

.me-btn {
  border: 1px solid #cbd5e1;
  background: #fff;
  color: #1f2937;
  border-radius: 8px;
  padding: 8px 14px;
  cursor: pointer;
  font-size: 14px;
}

.me-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.me-btn-danger {
  border-color: #fecaca;
  background: #fff1f2;
  color: #b91c1c;
}

.me-btn-danger:hover {
  background: #fee2e2;
}

.me-msg {
  margin: 8px 0 0;
  font-size: 13px;
  color: #b91c1c;
}

.me-msg.ok {
  color: #15803d;
}

.me-loading {
  color: #64748b;
}
</style>

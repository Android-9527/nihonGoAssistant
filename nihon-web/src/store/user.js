import { reactive, computed } from 'vue';

const TOKEN_KEY = 'nihon_token';
const USER_KEY = 'nihon_user';

const state = reactive({
  token: localStorage.getItem(TOKEN_KEY) || '',
  user: null,
});

try {
  const saved = localStorage.getItem(USER_KEY);
  if (saved) state.user = JSON.parse(saved);
} catch (e) {
  // ignore corrupted saved user
}

export const isLoggedIn = computed(() => !!state.token);

export function authHeaders() {
  return state.token ? { Authorization: `Bearer ${state.token}` } : {};
}

function persist() {
  if (state.token) {
    localStorage.setItem(TOKEN_KEY, state.token);
  } else {
    localStorage.removeItem(TOKEN_KEY);
  }
  if (state.user) {
    localStorage.setItem(USER_KEY, JSON.stringify(state.user));
  } else {
    localStorage.removeItem(USER_KEY);
  }
}

export async function login(email, password) {
  const res = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || '登录失败');
  state.token = data.token;
  state.user = data.user;
  persist();
  return data.user;
}

export async function register(email, password, nickname = '') {
  const res = await fetch('/api/auth/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, nickname }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || '注册失败');
  state.token = data.token;
  state.user = data.user;
  persist();
  return data.user;
}

export async function logout() {
  try {
    await fetch('/api/auth/logout', { method: 'POST', headers: authHeaders() });
  } catch (e) {
    // network errors must not block local logout
  }
  state.token = '';
  state.user = null;
  persist();
}

export async function fetchMe() {
  const res = await fetch('/api/auth/me', { headers: authHeaders() });
  const data = await res.json();
  if (!res.ok) {
    if (res.status === 401) {
      state.token = '';
      state.user = null;
      persist();
    }
    throw new Error(data.error || '获取用户信息失败');
  }
  state.user = data.user;
  persist();
  return data.user;
}

export async function updateMe(patch) {
  const res = await fetch('/api/auth/me', {
    method: 'PUT',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(patch),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || '更新失败');
  state.user = data.user;
  persist();
  return data.user;
}

export default {
  state,
  isLoggedIn,
  authHeaders,
  login,
  register,
  logout,
  fetchMe,
  updateMe,
};

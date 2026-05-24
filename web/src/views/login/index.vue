<template>
  <div class="login-container">
    <div class="login-bg">
      <div class="bg-shape bg-shape-1"></div>
      <div class="bg-shape bg-shape-2"></div>
      <div class="bg-shape bg-shape-3"></div>
    </div>
    <a-card class="login-card" :bordered="false">
      <div class="login-header">
        <div class="login-logo">
          <icon-desktop :style="{ fontSize: '28px', color: '#fff' }" />
        </div>
        <h1>运维管理平台</h1>
        <p>企业级运维工单管理系统</p>
      </div>
      <a-form :model="form" @submit-success="handleLogin" layout="vertical">
        <a-form-item field="username" :rules="[{ required: true, message: '请输入用户名' }]">
          <a-input v-model="form.username" placeholder="请输入用户名" size="large">
            <template #prefix><icon-user /></template>
          </a-input>
        </a-form-item>
        <a-form-item field="password" :rules="[{ required: true, message: '请输入密码' }]">
          <a-input-password v-model="form.password" placeholder="请输入密码" size="large">
            <template #prefix><icon-lock /></template>
          </a-input-password>
        </a-form-item>
        <a-form-item>
          <a-button type="primary" html-type="submit" long size="large" :loading="loading" class="login-btn">
            登录
          </a-button>
        </a-form-item>
      </a-form>
      <div class="login-footer">
        <span>测试账号：admin / supervisor1 / engineer1</span>
      </div>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { Message } from '@arco-design/web-vue'

const router = useRouter()
const userStore = useUserStore()
const loading = ref(false)

const form = reactive({
  username: '',
  password: '',
})

const handleLogin = async () => {
  loading.value = true
  try {
    await userStore.login(form.username, form.password)
    Message.success('登录成功')
    router.push('/dashboard')
  } catch (error) {} finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-container {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1d2b53 0%, #0f1c3d 50%, #1a1a2e 100%);
  position: relative;
  overflow: hidden;
}

.login-bg {
  position: absolute;
  inset: 0;
  overflow: hidden;
}

.bg-shape {
  position: absolute;
  border-radius: 50%;
  opacity: 0.06;
}

.bg-shape-1 {
  width: 600px;
  height: 600px;
  background: #4f7cff;
  top: -200px;
  right: -100px;
}

.bg-shape-2 {
  width: 400px;
  height: 400px;
  background: #36cfc9;
  bottom: -100px;
  left: -100px;
}

.bg-shape-3 {
  width: 300px;
  height: 300px;
  background: #f5576c;
  top: 50%;
  left: 60%;
}

.login-card {
  width: 420px;
  border-radius: 20px !important;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3) !important;
  padding: 16px;
  position: relative;
  z-index: 1;
}

.login-header {
  text-align: center;
  margin-bottom: 32px;
}

.login-logo {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  background: linear-gradient(135deg, #4f7cff 0%, #36cfc9 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
}

.login-header h1 {
  font-size: 22px;
  font-weight: 700;
  color: #1d2129;
  margin-bottom: 6px;
}

.login-header p {
  font-size: 13px;
  color: #86909c;
}

.login-btn {
  height: 44px !important;
  font-size: 15px !important;
  margin-top: 8px;
}

.login-footer {
  text-align: center;
  margin-top: 16px;
  font-size: 12px;
  color: #c9cdd4;
}
</style>

<template>
  <a-layout class="layout">
    <a-layout-sider
      :collapsed="collapsed"
      collapsible
      @collapse="onCollapse"
      :width="240"
      :collapsed-width="64"
      class="sider"
    >
      <div class="logo">
        <div class="logo-icon">
          <Server :size="24" color="#fff" />
        </div>
        <transition name="fade">
          <span v-if="!collapsed" class="logo-text">运维管理平台</span>
        </transition>
      </div>
      <a-menu
        :selected-keys="selectedKeys"
        :style="{ width: '100%', background: 'transparent' }"
        :collapse="collapsed"
        class="sider-menu"
        @menu-item-click="onMenuClick"
      >
        <a-menu-item key="/dashboard">
          <template #icon><LayoutDashboard :size="20" color="#4e5969" /></template>
          工作台
        </a-menu-item>
        <a-menu-item key="/tickets">
          <template #icon><ClipboardList :size="20" color="#4e5969" /></template>
          工单管理
        </a-menu-item>
        <a-menu-item v-if="!isEngineer" key="/projects">
          <template #icon><FolderKanban :size="20" color="#4e5969" /></template>
          项目管理
        </a-menu-item>
        <a-menu-item v-if="isAdminOrSupervisor" key="/engineers">
          <template #icon><Users :size="20" color="#4e5969" /></template>
          工程师管理
        </a-menu-item>
        <a-menu-item v-if="isAdminOrSupervisor" key="/teams">
          <template #icon><UserCog :size="20" color="#4e5969" /></template>
          团队管理
        </a-menu-item>
        <a-menu-item key="/knowledge">
          <template #icon><BookOpen :size="20" color="#4e5969" /></template>
          知识库
        </a-menu-item>
        <a-menu-item v-if="isAdminOrSupervisor" key="/assets">
          <template #icon><Monitor :size="20" color="#4e5969" /></template>
          资产管理
        </a-menu-item>
        <a-menu-item v-if="isAdmin" key="/system">
          <template #icon><Settings :size="20" color="#4e5969" /></template>
          系统设置
        </a-menu-item>
      </a-menu>
    </a-layout-sider>
    <a-layout>
      <a-layout-header class="header">
        <div class="header-left">
          <a-breadcrumb>
            <a-breadcrumb-item>首页</a-breadcrumb-item>
            <a-breadcrumb-item>{{ currentPageTitle }}</a-breadcrumb-item>
          </a-breadcrumb>
        </div>
        <div class="header-right">
          <a-dropdown>
            <div class="user-info">
              <a-avatar :size="32" class="user-avatar">
                {{ (userStore.userInfo?.real_name || userStore.userInfo?.username || 'U').charAt(0) }}
              </a-avatar>
              <span class="user-name">{{ userStore.userInfo?.real_name || userStore.userInfo?.username }}</span>
              <a-tag :color="roleColor" size="small" style="margin-left: 8px">{{ roleText }}</a-tag>
              <icon-down style="margin-left: 4px; font-size: 12px" />
            </div>
            <template #content>
              <a-doption @click="handleLogout">
                <template #icon><LogOut :size="16" /></template>
                退出登录
              </a-doption>
            </template>
          </a-dropdown>
        </div>
      </a-layout-header>
      <a-layout-content class="content">
        <router-view v-if="profileLoaded" />
        <div v-else class="loading-wrapper">
          <a-spin :size="32" />
        </div>
      </a-layout-content>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useUserStore } from '@/stores/user'
import {
  Server, LayoutDashboard, ClipboardList, FolderKanban,
  Users, UserCog, BookOpen, Monitor, Settings, LogOut
} from 'lucide-vue-next'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const collapsed = ref(false)
const profileLoaded = ref(false)
const isMobile = ref(false)

const selectedKeys = computed(() => [route.path])

const role = computed(() => userStore.userInfo?.role || '')
const isAdmin = computed(() => role.value === 'admin')
const isAdminOrSupervisor = computed(() => role.value === 'admin' || role.value === 'supervisor')
const isEngineer = computed(() => role.value === 'engineer')

const roleColor = computed(() => ({ admin: 'red', supervisor: 'orange', engineer: 'blue' }[role.value] || 'gray'))
const roleText = computed(() => ({ admin: '管理员', supervisor: '主管', engineer: '工程师' }[role.value] || ''))

const pageTitles: Record<string, string> = {
  '/dashboard': '工作台',
  '/tickets': '工单管理',
  '/projects': '项目管理',
  '/engineers': '工程师管理',
  '/teams': '团队管理',
  '/knowledge': '知识库',
  '/assets': '资产管理',
  '/system': '系统设置',
}
const currentPageTitle = computed(() => pageTitles[route.path] || '详情')

const onCollapse = (val: boolean) => {
  collapsed.value = val
}

const onMenuClick = (key: string) => {
  router.push(key)
}

const handleLogout = () => {
  userStore.logout()
  router.push('/login')
}

const mobileQuery = window.matchMedia('(max-width: 768px)')
const onMobileChange = (e: MediaQueryListEvent | MediaQueryList) => {
  isMobile.value = e.matches
  if (e.matches) collapsed.value = true
}

onMounted(async () => {
  onMobileChange(mobileQuery)
  mobileQuery.addEventListener('change', onMobileChange)

  if (userStore.token) {
    try {
      await userStore.fetchProfile()
    } catch (e) {}
  }
  profileLoaded.value = true
})

onBeforeUnmount(() => {
  mobileQuery.removeEventListener('change', onMobileChange)
})
</script>

<style scoped>
.layout {
  height: 100vh;
}

.sider {
  background: #fff !important;
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.06);
  border-right: 1px solid #f0f1f5;
}

.sider :deep(.arco-layout-sider-trigger) {
  background: #fafbfc;
  color: #86909c;
  border-top: 1px solid #f0f1f5;
}

.sider-menu :deep(.arco-menu-item) {
  color: #1d2129;
  border-radius: 0;
  margin: 0;
  height: 44px;
  line-height: 44px;
  border-left: 3px solid transparent;
  display: flex;
  align-items: center;
  gap: 8px;
}

.sider-menu :deep(.arco-menu-item:hover) {
  color: #1d2129;
  background: #f5f7fa;
}

.sider-menu :deep(.arco-menu-item.arco-menu-selected) {
  color: #4f7cff;
  background: rgba(79, 124, 255, 0.06);
  border-left-color: #4f7cff;
  box-shadow: inset 3px 0 0 #4f7cff;
}

/* Collapsed sidebar */
.sider-menu :deep(.arco-menu-collapsed .arco-menu-item) {
  justify-content: center;
  padding: 0;
  border-left: none;
}

.sider-menu :deep(.arco-menu-collapsed .arco-menu-item.arco-menu-selected) {
  border-left: none;
  box-shadow: none;
}

.logo {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  border-bottom: 1px solid #f0f1f5;
  padding: 0 16px;
}

.logo-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  background: linear-gradient(135deg, #4f7cff 0%, #36cfc9 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.logo-text {
  color: #1d2129;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 1px;
  white-space: nowrap;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.header {
  height: 64px;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
  z-index: 10;
}

.header-left {
  display: flex;
  align-items: center;
}

.header-right {
  display: flex;
  align-items: center;
}

.user-info {
  display: flex;
  align-items: center;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 8px;
  transition: background 0.2s;
}

.user-info:hover {
  background: #f5f6fa;
}

.user-avatar {
  background: linear-gradient(135deg, #4f7cff 0%, #36cfc9 100%);
  color: #fff;
  font-weight: 600;
}

.user-name {
  margin-left: 8px;
  font-size: 14px;
  color: #1d2129;
}

.content {
  background: #f5f7fa;
  min-height: calc(100vh - 64px);
  overflow-y: auto;
}

.loading-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  height: calc(100vh - 64px);
}
</style>

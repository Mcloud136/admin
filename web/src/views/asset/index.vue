<template>
  <div style="padding: 20px">
    <a-card :bordered="false">
      <template #title>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span>资产管理</span>
          <a-button v-if="isAdminOrSupervisor" type="primary" @click="openCreate">
            <Plus :size="16" /> 添加资产
          </a-button>
        </div>
      </template>

      <a-space style="margin-bottom: 16px">
        <a-select v-model="filterType" placeholder="资产类型" allow-clear style="width: 130px" @change="fetchAssets">
          <a-option value="server">服务器</a-option>
          <a-option value="switch">交换机</a-option>
          <a-option value="router">路由器</a-option>
          <a-option value="firewall">防火墙</a-option>
          <a-option value="storage">存储设备</a-option>
          <a-option value="workstation">工作站</a-option>
          <a-option value="other">其他</a-option>
        </a-select>
        <a-select v-model="filterStatus" placeholder="状态" allow-clear style="width: 110px" @change="fetchAssets">
          <a-option value="active">在用</a-option>
          <a-option value="maintenance">维修中</a-option>
          <a-option value="retired">已报废</a-option>
          <a-option value="spare">备用</a-option>
        </a-select>
        <a-input-search v-model="filterKeyword" placeholder="搜索名称/IP/序列号" style="width: 240px" @search="fetchAssets" />
      </a-space>

      <a-table :columns="columns" :data="assets" :pagination="false">
        <template #type="{ record }">
          <a-tag color="arcoblue" size="small">{{ typeText(record.type) }}</a-tag>
        </template>
        <template #status="{ record }">
          <a-tag :color="statusColor(record.status)" size="small">{{ statusText(record.status) }}</a-tag>
        </template>
        <template #responsible="{ record }">
          {{ getUserName(record.responsible_id) }}
        </template>
        <template #action="{ record }">
          <a-space>
            <a-link @click="viewAsset(record)">查看</a-link>
            <a-link v-if="isAdminOrSupervisor" @click="editAsset(record)">编辑</a-link>
            <a-link v-if="isAdmin" status="danger" @click="handleDelete(record.id)">删除</a-link>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- Detail Drawer -->
    <a-drawer :visible="showDetail" @cancel="showDetail = false" :width="600" :footer="false">
      <template #title>{{ detailAsset?.name }}</template>
      <a-descriptions :column="2" bordered size="small" v-if="detailAsset">
        <a-descriptions-item label="资产编号">{{ detailAsset.id }}</a-descriptions-item>
        <a-descriptions-item label="资产名称">{{ detailAsset.name }}</a-descriptions-item>
        <a-descriptions-item label="类型">{{ typeText(detailAsset.type) }}</a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-tag :color="statusColor(detailAsset.status)" size="small">{{ statusText(detailAsset.status) }}</a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="IP 地址">{{ detailAsset.ip || '-' }}</a-descriptions-item>
        <a-descriptions-item label="序列号">{{ detailAsset.serial_number || '-' }}</a-descriptions-item>
        <a-descriptions-item label="品牌">{{ detailAsset.brand || '-' }}</a-descriptions-item>
        <a-descriptions-item label="型号">{{ detailAsset.model || '-' }}</a-descriptions-item>
        <a-descriptions-item label="存放位置">{{ detailAsset.location || '-' }}</a-descriptions-item>
        <a-descriptions-item label="负责人">{{ getUserName(detailAsset.responsible_id) }}</a-descriptions-item>
        <a-descriptions-item label="采购日期">{{ formatDate(detailAsset.purchase_date) || '-' }}</a-descriptions-item>
        <a-descriptions-item label="保修到期">{{ formatDate(detailAsset.warranty_date) || '-' }}</a-descriptions-item>
        <a-descriptions-item label="描述" :span="2">{{ detailAsset.description || '-' }}</a-descriptions-item>
      </a-descriptions>
    </a-drawer>

    <!-- Create/Edit Modal -->
    <a-modal v-model:visible="showModal" :title="editingId ? '编辑资产' : '添加资产'" @ok="handleSubmit" @cancel="resetForm" :width="640">
      <a-form :model="form" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="资产名称" required>
              <a-input v-model="form.name" placeholder="如: Web服务器01" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="资产类型" required>
              <a-select v-model="form.type">
                <a-option value="server">服务器</a-option>
                <a-option value="switch">交换机</a-option>
                <a-option value="router">路由器</a-option>
                <a-option value="firewall">防火墙</a-option>
                <a-option value="storage">存储设备</a-option>
                <a-option value="workstation">工作站</a-option>
                <a-option value="other">其他</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="IP 地址">
              <a-input v-model="form.ip" placeholder="192.168.1.100" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="状态">
              <a-select v-model="form.status">
                <a-option value="active">在用</a-option>
                <a-option value="maintenance">维修中</a-option>
                <a-option value="spare">备用</a-option>
                <a-option value="retired">已报废</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="品牌">
              <a-input v-model="form.brand" placeholder="如: Dell" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="型号">
              <a-input v-model="form.model" placeholder="如: PowerEdge R740" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="序列号">
              <a-input v-model="form.serial_number" placeholder="SN/IMEI" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="存放位置">
              <a-input v-model="form.location" placeholder="如: 机房A-机柜3" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="采购日期">
              <a-date-picker v-model="form.purchase_date" style="width: 100%" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="保修到期">
              <a-date-picker v-model="form.warranty_date" style="width: 100%" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="负责人">
          <a-select v-model="form.responsible_id" placeholder="选择负责人" allow-clear filterable>
            <a-option v-for="u in users" :key="u.id" :value="u.id">{{ u.real_name || u.username }}</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="描述">
          <a-textarea v-model="form.description" placeholder="资产描述备注" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import request from '@/utils/request'
import { getUserList } from '@/api/user'
import { useUserStore } from '@/stores/user'
import { Message, Modal } from '@arco-design/web-vue'
import { Plus } from 'lucide-vue-next'

const userStore = useUserStore()
const isAdmin = computed(() => userStore.userInfo?.role === 'admin')
const isAdminOrSupervisor = computed(() => userStore.userInfo?.role === 'admin' || userStore.userInfo?.role === 'supervisor')

const assets = ref<any[]>([])
const users = ref<any[]>([])
const showModal = ref(false)
const showDetail = ref(false)
const editingId = ref<number | null>(null)
const detailAsset = ref<any>(null)
const filterType = ref('')
const filterStatus = ref('')
const filterKeyword = ref('')

const defaultForm = () => ({
  name: '', type: 'server', ip: '', status: 'active', location: '',
  serial_number: '', brand: '', model: '', responsible_id: undefined as number | undefined,
  description: '', purchase_date: '', warranty_date: '',
})
const form = reactive(defaultForm())

const columns = [
  { title: 'ID', dataIndex: 'id', width: 60 },
  { title: '资产名称', dataIndex: 'name', ellipsis: true },
  { title: '类型', dataIndex: 'type', slotName: 'type', width: 80 },
  { title: 'IP 地址', dataIndex: 'ip', width: 130 },
  { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
  { title: '品牌/型号', render: ({ record }: any) => [record.brand, record.model].filter(Boolean).join(' ') || '-', width: 140 },
  { title: '位置', dataIndex: 'location', ellipsis: true, width: 120 },
  { title: '负责人', dataIndex: 'responsible_id', slotName: 'responsible', width: 80 },
  { title: '操作', slotName: 'action', width: 140 },
]

const typeText = (t: string) => ({
  server: '服务器', switch: '交换机', router: '路由器', firewall: '防火墙',
  storage: '存储设备', workstation: '工作站', other: '其他',
}[t] || t)

const statusColor = (s: string) => ({
  active: 'green', maintenance: 'orange', spare: 'blue', retired: 'gray',
}[s] || 'gray')

const statusText = (s: string) => ({
  active: '在用', maintenance: '维修中', spare: '备用', retired: '已报废',
}[s] || s)

const formatDate = (d: string | null) => d ? d.substring(0, 10) : ''

const getUserName = (id: number | null) => {
  if (!id) return '-'
  const u = users.value.find(u => u.id === id)
  return u ? (u.real_name || u.username) : `ID:${id}`
}

const fetchAssets = async () => {
  const params: any = {}
  if (filterType.value) params.type = filterType.value
  if (filterStatus.value) params.status = filterStatus.value
  if (filterKeyword.value) params.keyword = filterKeyword.value
  assets.value = (await request.get('/assets', { params }) as any) || []
}

const fetchUsers = async () => {
  try {
    const result = await getUserList({ page: 1, page_size: 200 }) as any
    users.value = result?.list || []
  } catch (e) {}
}

const openCreate = () => {
  editingId.value = null
  Object.assign(form, defaultForm())
  showModal.value = true
}

const editAsset = (a: any) => {
  editingId.value = a.id
  Object.assign(form, {
    name: a.name, type: a.type || 'server', ip: a.ip || '', status: a.status || 'active',
    location: a.location || '', serial_number: a.serial_number || '', brand: a.brand || '',
    model: a.model || '', responsible_id: a.responsible_id || undefined,
    description: a.description || '', purchase_date: formatDate(a.purchase_date),
    warranty_date: formatDate(a.warranty_date),
  })
  showModal.value = true
}

const resetForm = () => { editingId.value = null; Object.assign(form, defaultForm()) }

const handleSubmit = async () => {
  if (!form.name) { Message.warning('请输入资产名称'); return }
  try {
    if (editingId.value) {
      await request.put(`/assets/${editingId.value}`, form)
      Message.success('更新成功')
    } else {
      await request.post('/assets', form)
      Message.success('添加成功')
    }
    showModal.value = false
    resetForm()
    fetchAssets()
  } catch (e) {}
}

const viewAsset = (a: any) => { detailAsset.value = a; showDetail.value = true }

const handleDelete = (id: number) => {
  Modal.confirm({
    title: '确认删除', content: '删除后关联工单将解除绑定，确定要删除吗？',
    onOk: async () => { await request.delete(`/assets/${id}`); Message.success('已删除'); fetchAssets() },
  })
}

onMounted(() => { fetchAssets(); fetchUsers() })
</script>

<style scoped>
</style>

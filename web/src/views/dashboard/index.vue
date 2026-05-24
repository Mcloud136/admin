<template>
  <div class="dashboard">
    <!-- Welcome -->
    <div class="welcome-section">
      <div class="welcome-text">
        <h2>欢迎回来，{{ userStore.userInfo?.real_name || userStore.userInfo?.username }}</h2>
        <p>今天是 {{ today }}，祝你工作顺利</p>
      </div>
    </div>

    <!-- Stat Cards -->
    <a-row :gutter="[16, 16]" class="stat-row">
      <a-col :xs="24" :sm="12" :lg="6">
        <div class="stat-card" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%)">
          <div class="stat-card-content">
            <div class="stat-info">
              <span class="stat-label">待处理工单</span>
              <span class="stat-value">{{ stats.pending }}</span>
            </div>
            <div class="stat-icon"><Clock :size="28" color="#fff" /></div>
          </div>
        </div>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <div class="stat-card" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%)">
          <div class="stat-card-content">
            <div class="stat-info">
              <span class="stat-label">处理中工单</span>
              <span class="stat-value">{{ stats.processing }}</span>
            </div>
            <div class="stat-icon"><RefreshCw :size="28" color="#fff" /></div>
          </div>
        </div>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <div class="stat-card" style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)">
          <div class="stat-card-content">
            <div class="stat-info">
              <span class="stat-label">本月完单</span>
              <span class="stat-value">{{ stats.completed }}</span>
            </div>
            <div class="stat-icon"><CheckCircle :size="28" color="#fff" /></div>
          </div>
        </div>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <div class="stat-card" style="background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%)">
          <div class="stat-card-content">
            <div class="stat-info">
              <span class="stat-label">工单总数</span>
              <span class="stat-value">{{ stats.total }}</span>
            </div>
            <div class="stat-icon"><BarChart3 :size="28" color="#fff" /></div>
          </div>
        </div>
      </a-col>
    </a-row>

    <!-- Charts -->
    <a-row :gutter="[16, 16]" style="margin-top: 20px">
      <a-col :xs="24" :lg="16">
        <a-card title="工单趋势" :bordered="false" class="chart-card">
          <div ref="trendChartRef" style="height: 320px"></div>
        </a-card>
      </a-col>
      <a-col :xs="24" :lg="8">
        <a-card title="工单类型分布" :bordered="false" class="chart-card">
          <div ref="pieChartRef" style="height: 320px"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- Recent tickets -->
    <a-card title="最近工单" :bordered="false" style="margin-top: 20px" class="chart-card">
      <a-table :columns="columns" :data="recentTickets" :pagination="false" size="small">
        <template #priority="{ record }">
          <a-tag :color="priorityColor(record.priority)" size="small">{{ priorityText(record.priority) }}</a-tag>
        </template>
        <template #status="{ record }">
          <a-tag :color="statusColor(record.status)" size="small">{{ statusText(record.status) }}</a-tag>
        </template>
        <template #action="{ record }">
          <a-link size="small" @click="router.push(`/tickets/${record.id}`)">查看</a-link>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { getTicketList } from '@/api/ticket'
import * as echarts from 'echarts'
import { Clock, RefreshCw, CheckCircle, BarChart3 } from 'lucide-vue-next'

const router = useRouter()
const userStore = useUserStore()

const trendChartRef = ref<HTMLElement>()
const pieChartRef = ref<HTMLElement>()
let trendChart: echarts.ECharts | null = null
let pieChart: echarts.ECharts | null = null

const today = new Date().toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })

const stats = reactive({
  pending: 0,
  processing: 0,
  completed: 0,
  total: 0,
})

const recentTickets = ref<any[]>([])

const columns = [
  { title: 'ID', dataIndex: 'id', width: 60 },
  { title: '标题', dataIndex: 'title', ellipsis: true },
  { title: '优先级', dataIndex: 'priority', slotName: 'priority', width: 70 },
  { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
  { title: '创建时间', dataIndex: 'created_at', width: 170 },
  { title: '操作', slotName: 'action', width: 60 },
]

const priorityColor = (p: string) => ({ p0: 'red', p1: 'orange', p2: 'gold', p3: 'blue' }[p] || 'gray')
const priorityText = (p: string) => ({ p0: '紧急', p1: '重大', p2: '严重', p3: '普通' }[p] || p)
const statusColor = (s: string) => ({
  created: 'gray', assigned: 'blue', processing: 'cyan',
  suspended: 'orange', review: 'purple', completed: 'green', archived: 'gray'
}[s] || 'gray')
const statusText = (s: string) => ({
  created: '待派发', assigned: '已派发', processing: '处理中',
  suspended: '已挂起', review: '待验收', completed: '已完单', archived: '已归档'
}[s] || s)

const typeLabels: Record<string, string> = { fault: '故障', implement: '实施', patrol: '巡检' }
const statusLabels: Record<string, string> = {
  created: '待派发', assigned: '已派发', processing: '处理中',
  suspended: '已挂起', review: '待验收', completed: '已完单', archived: '已归档',
}

// Get last N days date labels
const getLastDays = (n: number): string[] => {
  const days: string[] = []
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date()
    d.setDate(d.getDate() - i)
    days.push(`${d.getMonth() + 1}/${d.getDate()}`)
  }
  return days
}

// Group tickets by date
const groupByDate = (tickets: any[], days: string[]) => {
  const countMap: Record<string, number> = {}
  days.forEach(d => countMap[d] = 0)
  tickets.forEach(t => {
    const d = new Date(t.created_at)
    const key = `${d.getMonth() + 1}/${d.getDate()}`
    if (key in countMap) countMap[key]++
  })
  return days.map(d => countMap[d])
}

// Group tickets by type
const groupByType = (tickets: any[]) => {
  const map: Record<string, number> = {}
  tickets.forEach(t => {
    const label = typeLabels[t.type] || t.type
    map[label] = (map[label] || 0) + 1
  })
  return Object.entries(map).map(([name, value]) => ({ name, value }))
}

const initTrendChart = (tickets: any[]) => {
  if (!trendChartRef.value) return
  trendChart = echarts.init(trendChartRef.value)
  const days = getLastDays(14)
  const data = groupByDate(tickets, days)

  trendChart.setOption({
    tooltip: { trigger: 'axis', backgroundColor: '#fff', borderColor: '#e5e6eb', textStyle: { color: '#1d2129' } },
    grid: { left: 40, right: 20, top: 20, bottom: 30 },
    xAxis: { type: 'category', data: days, axisLine: { lineStyle: { color: '#e5e6eb' } }, axisLabel: { color: '#86909c', fontSize: 11 } },
    yAxis: { type: 'value', minInterval: 1, axisLine: { show: false }, axisTick: { show: false }, splitLine: { lineStyle: { color: '#f0f1f5' } }, axisLabel: { color: '#86909c' } },
    series: [{
      type: 'line',
      data,
      smooth: true,
      symbol: 'circle',
      symbolSize: 6,
      lineStyle: { width: 3, color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [{ offset: 0, color: '#4f7cff' }, { offset: 1, color: '#36cfc9' }]) },
      areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: 'rgba(79,124,255,0.15)' }, { offset: 1, color: 'rgba(54,207,201,0.02)' }]) },
      itemStyle: { color: '#4f7cff', borderWidth: 2, borderColor: '#fff' },
    }],
  })
}

const initPieChart = (tickets: any[]) => {
  if (!pieChartRef.value) return
  pieChart = echarts.init(pieChartRef.value)
  const data = groupByType(tickets)

  pieChart.setOption({
    tooltip: { trigger: 'item', backgroundColor: '#fff', borderColor: '#e5e6eb', textStyle: { color: '#1d2129' } },
    legend: { bottom: 0, itemWidth: 10, itemHeight: 10, textStyle: { color: '#4e5969', fontSize: 12 } },
    series: [{
      type: 'pie',
      radius: ['45%', '70%'],
      center: ['50%', '45%'],
      avoidLabelOverlap: false,
      itemStyle: { borderRadius: 8, borderColor: '#fff', borderWidth: 3 },
      label: { show: true, formatter: '{b}: {c}', fontSize: 12, color: '#4e5969' },
      data: data.length > 0 ? data : [{ name: '暂无数据', value: 0 }],
      color: ['#4f7cff', '#36cfc9', '#f5576c', '#faad14', '#722ed1'],
    }],
  })
}

const handleResize = () => {
  trendChart?.resize()
  pieChart?.resize()
}

let resizeObserver: ResizeObserver | null = null

onMounted(async () => {
  window.addEventListener('resize', handleResize)

  // Watch chart containers for size changes (sidebar collapse, etc.)
  resizeObserver = new ResizeObserver(() => {
    trendChart?.resize()
    pieChart?.resize()
  })
  if (trendChartRef.value) resizeObserver.observe(trendChartRef.value)
  if (pieChartRef.value) resizeObserver.observe(pieChartRef.value)

  try {
    const result = await getTicketList({ page: 1, page_size: 200 })
    const allTickets = result?.list || []
    recentTickets.value = allTickets.slice(0, 5)
    stats.total = result?.total || 0
    stats.pending = allTickets.filter((t: any) => ['created', 'assigned'].includes(t.status)).length
    stats.processing = allTickets.filter((t: any) => t.status === 'processing').length
    stats.completed = allTickets.filter((t: any) => ['completed', 'archived'].includes(t.status)).length

    await nextTick()
    initTrendChart(allTickets)
    initPieChart(allTickets)
  } catch (e) {}
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  resizeObserver?.disconnect()
  trendChart?.dispose()
  pieChart?.dispose()
})
</script>

<style scoped>
.dashboard {
  padding: 20px;
}

.welcome-section {
  margin-bottom: 20px;
}

.welcome-text h2 {
  font-size: 22px;
  font-weight: 600;
  color: #1d2129;
  margin-bottom: 4px;
}

.welcome-text p {
  font-size: 14px;
  color: #86909c;
}

.stat-card {
  border-radius: 12px;
  padding: 20px;
  color: #fff;
  position: relative;
  overflow: hidden;
  transition: transform 0.2s, box-shadow 0.2s;
}

.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
}

.stat-card-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.stat-info {
  display: flex;
  flex-direction: column;
}

.stat-label {
  font-size: 13px;
  opacity: 0.85;
  margin-bottom: 8px;
}

.stat-value {
  font-size: 32px;
  font-weight: 700;
  line-height: 1;
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.chart-card {
  border-radius: 12px;
}
</style>

<template>
  <div class="knowledge-page">
    <!-- List View -->
    <a-card v-if="!editing && !viewing" :bordered="false">
      <template #title>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span>知识库</span>
          <a-space>
            <a-button type="primary" @click="openCreate">
              <Plus :size="16" /> 新建文档
            </a-button>
            <a-upload
              :show-file-list="false"
              accept=".docx,.doc,.xlsx,.xls,.txt,.md,.csv,.json,.xml,.yaml,.yml,.log"
              :custom-request="handleUploadDoc"
            >
              <a-button>
                <Upload :size="16" /> 上传文档
              </a-button>
            </a-upload>
          </a-space>
        </div>
      </template>

      <a-space style="margin-bottom: 16px">
        <a-select v-model="filterCategory" placeholder="全部分类" allow-clear style="width: 150px" @change="fetchArticles">
          <a-option v-for="cat in categories" :key="cat.id" :value="cat.id">{{ cat.name }}</a-option>
        </a-select>
        <a-input-search v-model="filterKeyword" placeholder="搜索文档标题..." style="width: 240px" @search="fetchArticles" />
      </a-space>

      <a-table :columns="columns" :data="articles" :pagination="false">
        <template #category="{ record }">
          <a-tag color="arcoblue" size="small">{{ getCategoryName(record.category_id) }}</a-tag>
        </template>
        <template #status="{ record }">
          <a-tag :color="record.status === 'published' ? 'green' : 'orange'" size="small">
            {{ record.status === 'published' ? '已发布' : '草稿' }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <a-space>
            <a-link @click="viewArticle(record)">查看</a-link>
            <a-link @click="editArticle(record)">编辑</a-link>
            <a-link status="danger" @click="handleDelete(record.id)">删除</a-link>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- Editor View -->
    <a-card v-if="editing" :bordered="false">
      <template #title>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span>{{ editingId ? '编辑文档' : '新建文档' }}</span>
          <a-space>
            <a-button @click="cancelEdit">取消</a-button>
            <a-button type="primary" @click="handleSave('draft')">保存草稿</a-button>
            <a-button type="primary" status="success" @click="handleSave('published')">发布</a-button>
          </a-space>
        </div>
      </template>

      <a-form layout="vertical">
        <a-row :gutter="16">
          <a-col :span="16">
            <a-form-item label="文档标题" required>
              <a-input v-model="articleForm.title" placeholder="请输入文档标题" size="large" />
            </a-form-item>
          </a-col>
          <a-col :span="4">
            <a-form-item label="所属分类">
              <a-select v-model="articleForm.category_id" placeholder="选择分类">
                <a-option v-for="cat in categories" :key="cat.id" :value="cat.id">{{ cat.name }}</a-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="4">
            <a-form-item label="标签">
              <a-input v-model="articleForm.tagsInput" placeholder="多个用逗号分隔" />
            </a-form-item>
          </a-col>
        </a-row>
      </a-form>

      <div class="editor-wrapper">
        <div class="editor-toolbar" v-if="editor">
          <a-space wrap :size="4">
            <a-tooltip content="粗体"><a-button size="mini" :type="editor.isActive('bold') ? 'primary' : 'outline'" @click="editor.chain().focus().toggleBold().run()">B</a-button></a-tooltip>
            <a-tooltip content="斜体"><a-button size="mini" :type="editor.isActive('italic') ? 'primary' : 'outline'" @click="editor.chain().focus().toggleItalic().run()"><em>I</em></a-button></a-tooltip>
            <a-tooltip content="下划线"><a-button size="mini" :type="editor.isActive('underline') ? 'primary' : 'outline'" @click="editor.chain().focus().toggleUnderline().run()"><u>U</u></a-button></a-tooltip>
            <a-tooltip content="删除线"><a-button size="mini" :type="editor.isActive('strike') ? 'primary' : 'outline'" @click="editor.chain().focus().toggleStrike().run()"><s>S</s></a-button></a-tooltip>
            <a-divider direction="vertical" />
            <a-tooltip content="一级标题"><a-button size="mini" :type="editor.isActive('heading', { level: 1 }) ? 'primary' : 'outline'" @click="editor.chain().focus().toggleHeading({ level: 1 }).run()">H1</a-button></a-tooltip>
            <a-tooltip content="二级标题"><a-button size="mini" :type="editor.isActive('heading', { level: 2 }) ? 'primary' : 'outline'" @click="editor.chain().focus().toggleHeading({ level: 2 }).run()">H2</a-button></a-tooltip>
            <a-tooltip content="三级标题"><a-button size="mini" :type="editor.isActive('heading', { level: 3 }) ? 'primary' : 'outline'" @click="editor.chain().focus().toggleHeading({ level: 3 }).run()">H3</a-button></a-tooltip>
            <a-divider direction="vertical" />
            <a-tooltip content="无序列表"><a-button size="mini" :type="editor.isActive('bulletList') ? 'primary' : 'outline'" @click="editor.chain().focus().toggleBulletList().run()">&#8226;</a-button></a-tooltip>
            <a-tooltip content="有序列表"><a-button size="mini" :type="editor.isActive('orderedList') ? 'primary' : 'outline'" @click="editor.chain().focus().toggleOrderedList().run()">1.</a-button></a-tooltip>
            <a-tooltip content="引用"><a-button size="mini" :type="editor.isActive('blockquote') ? 'primary' : 'outline'" @click="editor.chain().focus().toggleBlockquote().run()">"</a-button></a-tooltip>
            <a-tooltip content="代码块"><a-button size="mini" :type="editor.isActive('codeBlock') ? 'primary' : 'outline'" @click="editor.chain().focus().toggleCodeBlock().run()">&lt;/&gt;</a-button></a-tooltip>
            <a-divider direction="vertical" />
            <a-tooltip content="分割线"><a-button size="mini" outline @click="editor.chain().focus().setHorizontalRule().run()">&#8212;</a-button></a-tooltip>
            <a-tooltip content="撤销"><a-button size="mini" outline @click="editor.chain().focus().undo().run()">&#8630;</a-button></a-tooltip>
            <a-tooltip content="重做"><a-button size="mini" outline @click="editor.chain().focus().redo().run()">&#8631;</a-button></a-tooltip>
          </a-space>
        </div>
        <editor-content :editor="editor" class="editor-content" />
      </div>

      <a-divider>附件管理</a-divider>
      <a-upload
        :action="editingId ? `/api/knowledge/articles/${editingId}/files` : ''"
        :headers="uploadHeaders"
        :auto-upload="false"
        multiple
        ref="uploadRef"
        @change="onUploadChange"
      >
        <template #upload-button>
          <div style="padding: 12px; border: 1px dashed #c9cdd4; border-radius: 8px; text-align: center; cursor: pointer">
            <Upload :size="18" /> 点击上传附件（Word / Excel / 图片 / 文本等）
          </div>
        </template>
      </a-upload>
    </a-card>

    <!-- Detail View -->
    <a-card v-if="viewing" :bordered="false">
      <template #title>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span>{{ viewing.title }}</span>
          <a-space>
            <a-button @click="viewing = null" size="small">返回列表</a-button>
            <a-button type="primary" @click="editArticle(viewing)" size="small">编辑文档</a-button>
          </a-space>
        </div>
      </template>

      <a-descriptions :column="4" size="small" style="margin-bottom: 20px" :bordered="true">
        <a-descriptions-item label="所属分类">
          <a-tag color="arcoblue" size="small">{{ getCategoryName(viewing.category_id) }}</a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="文档状态">
          <a-tag :color="viewing.status === 'published' ? 'green' : 'orange'" size="small">
            {{ viewing.status === 'published' ? '已发布' : '草稿' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="浏览次数">{{ viewing.view_count }}</a-descriptions-item>
        <a-descriptions-item label="最后更新">{{ viewing.updated_at }}</a-descriptions-item>
      </a-descriptions>

      <div class="article-content" v-html="viewing.content_html || viewing.content"></div>

      <template v-if="viewFiles.length > 0">
        <a-divider>附件列表</a-divider>
        <a-list :data="viewFiles" :bordered="false">
          <template #item="{ item }">
            <a-list-item>
              <div style="display: flex; align-items: center; gap: 12px; width: 100%">
                <FileText :size="18" style="color: #4e5969" />
                <span>{{ item.filename }}</span>
                <span style="color: #86909c; font-size: 12px">{{ formatSize(item.filesize) }}</span>
                <div style="margin-left: auto">
                  <a-space>
                    <a-link @click="previewFile(item)">预览</a-link>
                    <a-link @click="downloadFile(item)">下载</a-link>
                  </a-space>
                </div>
              </div>
            </a-list-item>
          </template>
        </a-list>
      </template>
    </a-card>

    <!-- File Preview Modal -->
    <a-modal v-model:visible="showPreview" :title="'文件预览 - ' + previewFilename" :width="900" :footer="false">
      <div v-if="previewType === 'html'" class="preview-html" v-html="previewContent"></div>
      <div v-else-if="previewType === 'table'" style="overflow: auto; max-height: 500px">
        <table class="preview-table">
          <tr v-for="(row, i) in previewTableData" :key="i">
            <td v-for="(cell, j) in row" :key="j" :class="{ 'table-header': i === 0 }">{{ cell }}</td>
          </tr>
        </table>
      </div>
      <div v-else-if="previewType === 'text'" style="white-space: pre-wrap; font-family: monospace; padding: 16px; background: #f5f7fa; border-radius: 8px; max-height: 500px; overflow: auto; font-size: 13px">
        {{ previewContent }}
      </div>
      <div v-else style="text-align: center; padding: 40px">
        <a-empty description="该文件类型暂不支持在线预览">
          <a-button type="primary" @click="downloadCurrentFile">下载文件查看</a-button>
        </a-empty>
      </div>
    </a-modal>

    <!-- Upload Progress Modal -->
    <a-modal v-model:visible="showUploadProgress" title="正在解析文档" :footer="false" :closable="false" :mask-closable="false">
      <a-spin :size="32" style="display: flex; justify-content: center; padding: 20px">
        <span style="margin-left: 12px">正在提取文档内容，请稍候...</span>
      </a-spin>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import request from '@/utils/request'
import { useUserStore } from '@/stores/user'
import { Message, Modal } from '@arco-design/web-vue'
import { useEditor, EditorContent } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import ImageExt from '@tiptap/extension-image'
import LinkExt from '@tiptap/extension-link'
import TextAlign from '@tiptap/extension-text-align'
import Placeholder from '@tiptap/extension-placeholder'
import UnderlineExt from '@tiptap/extension-underline'
import { Node } from '@tiptap/core'
import { Plus, Upload, FileText } from 'lucide-vue-next'

const userStore = useUserStore()
const uploadHeaders = computed(() => ({ Authorization: `Bearer ${userStore.token}` }))

const articles = ref<any[]>([])
const categories = ref<any[]>([])
const editing = ref(false)
const editingId = ref<number | null>(null)
const viewing = ref<any>(null)
const viewFiles = ref<any[]>([])
const filterCategory = ref<number | undefined>(undefined)
const filterKeyword = ref('')
const uploadRef = ref<any>(null)
const showUploadProgress = ref(false)

const articleForm = reactive({
  title: '',
  category_id: undefined as number | undefined,
  tagsInput: '',
})

const showPreview = ref(false)
const previewType = ref('')
const previewContent = ref('')
const previewUrl = ref('')
const previewFilename = ref('')
const previewTableData = ref<any[][]>([])
const previewFileId = ref(0)

const columns = [
  { title: '编号', dataIndex: 'id', width: 60 },
  { title: '文档标题', dataIndex: 'title', ellipsis: true },
  { title: '分类', dataIndex: 'category_id', slotName: 'category', width: 100 },
  { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
  { title: '浏览', dataIndex: 'view_count', width: 70 },
  { title: '更新时间', dataIndex: 'updated_at', width: 170 },
  { title: '操作', slotName: 'action', width: 160 },
]

const getCategoryName = (id: number) => categories.value.find((c: any) => c.id === id)?.name || '未分类'

const formatSize = (bytes: number) => {
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
}

const ResizableImage = Node.create({
  name: 'image',
  group: 'inline',
  inline: true,
  draggable: true,
  addAttributes() {
    return {
      src: { default: null },
      alt: { default: null },
      title: { default: null },
      width: { default: null },
      height: { default: null },
    }
  },
  parseHTML() {
    return [{ tag: 'img[src]' }]
  },
  renderHTML({ HTMLAttributes }) {
    return ['img', HTMLAttributes]
  },
  addNodeView() {
    return ({ node, getPos, editor }) => {
      const container = document.createElement('span')
      container.style.cssText = 'position:relative;display:inline-block;line-height:0;max-width:100%'

      const img = document.createElement('img')
      img.src = node.attrs.src || ''
      if (node.attrs.width) img.style.width = node.attrs.width
      if (node.attrs.height) img.style.height = node.attrs.height
      img.style.cssText += ';max-width:100%;border-radius:6px;cursor:pointer;user-select:none'
      container.appendChild(img)

      const handle = document.createElement('span')
      handle.style.cssText = 'position:absolute;right:-8px;bottom:-8px;width:16px;height:16px;background:#4f7cff;border:2px solid #fff;border-radius:50%;cursor:nwse-resize;box-shadow:0 2px 6px rgba(0,0,0,0.25);display:none;z-index:10'
      container.appendChild(handle)

      const showHandle = () => { handle.style.display = 'block' }
      const hideHandle = () => { handle.style.display = 'none' }

      img.addEventListener('click', () => {
        showHandle()
        setTimeout(() => document.addEventListener('click', hideHandle, { once: true }), 10)
      })

      handle.addEventListener('mousedown', (e) => {
        e.preventDefault()
        e.stopPropagation()
        const startX = e.clientX
        const startW = img.clientWidth
        const ratio = img.naturalHeight / img.naturalWidth || 0.75

        const onMove = (ev: MouseEvent) => {
          const w = Math.max(40, startW + ev.clientX - startX)
          const h = w * ratio
          img.style.width = w + 'px'
          img.style.height = h + 'px'
        }
        const onUp = () => {
          document.removeEventListener('mousemove', onMove)
          document.removeEventListener('mouseup', onUp)
          if (typeof getPos === 'function') {
            const pos = getPos()
            editor.view.dispatch(
              editor.view.state.tr.setNodeMarkup(pos, undefined, {
                ...node.attrs,
                width: img.style.width,
                height: img.style.height,
              })
            )
          }
        }
        document.addEventListener('mousemove', onMove)
        document.addEventListener('mouseup', onUp)
      })

      return { dom: container }
    }
  },
  addCommands() {
    return {
      setImage: (options: any) => ({ commands }: any) => {
        return commands.insertContent({ type: this.name, attrs: options })
      },
    }
  },
})

const editor = useEditor({
  extensions: [
    StarterKit, ResizableImage, LinkExt,
    TextAlign.configure({ types: ['heading', 'paragraph'] }),
    Placeholder.configure({ placeholder: '在此输入文档内容...' }),
    UnderlineExt,
  ],
  content: '',
  onCreate: ({ editor: ed }) => {
    const el = ed.view.dom as HTMLElement
    el.addEventListener('paste', (e: ClipboardEvent) => {
      const items = e.clipboardData?.items
      if (!items) return
      for (const item of items) {
        if (item.type.startsWith('image/')) {
          e.preventDefault()
          const file = item.getAsFile()
          if (!file) continue
          if (file.size > 5 * 1024 * 1024) { Message.warning('图片不能超过5MB'); return }
          const reader = new FileReader()
          reader.onload = (ev) => { ed.chain().focus().setImage({ src: ev.target?.result as string }).run() }
          reader.readAsDataURL(file)
          return
        }
      }
    })
    el.addEventListener('drop', (e: DragEvent) => {
      const files = e.dataTransfer?.files
      if (!files) return
      for (const file of files) {
        if (file.type.startsWith('image/')) {
          e.preventDefault()
          if (file.size > 5 * 1024 * 1024) { Message.warning('图片不能超过5MB'); return }
          const reader = new FileReader()
          reader.onload = (ev) => { ed.chain().focus().setImage({ src: ev.target?.result as string }).run() }
          reader.readAsDataURL(file)
          return
        }
      }
    })
  },
})

// Upload document and extract content
const handleUploadDoc = async (option: any) => {
  const file = option.fileItem.file
  const ext = file.name.substring(file.name.lastIndexOf('.')).toLowerCase()
  const titleFromFile = file.name.substring(0, file.name.lastIndexOf('.'))

  showUploadProgress.value = true

  try {
    const buffer = await file.arrayBuffer()
    let content = ''
    let contentHTML = ''

    if (ext === '.docx') {
      const mammoth = await import('mammoth')
      const result = await mammoth.convertToHtml({ arrayBuffer: buffer })
      contentHTML = result.value
      content = result.value.replace(/<[^>]+>/g, '')
    } else if (ext === '.xlsx' || ext === '.xls') {
      const XLSX = await import('xlsx')
      const wb = XLSX.read(buffer, { type: 'array' })
      const ws = wb.Sheets[wb.SheetNames[0]]
      const rows = XLSX.utils.sheet_to_json(ws, { header: 1 }) as any[][]
      if (rows.length > 0) {
        let html = '<table>'
        rows.forEach((row, i) => {
          html += '<tr>'
          row.forEach(cell => {
            const tag = i === 0 ? 'th' : 'td'
            html += `<${tag}>${cell ?? ''}</${tag}>`
          })
          html += '</tr>'
        })
        html += '</table>'
        contentHTML = html
        content = rows.map(r => r.join('\t')).join('\n')
      }
    } else {
      // Text-based files
      const text = new TextDecoder().decode(buffer)
      content = text
      contentHTML = `<pre>${text.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>`
    }

    showUploadProgress.value = false

    // Open editor with extracted content
    editingId.value = null
    articleForm.title = titleFromFile
    articleForm.category_id = undefined
    articleForm.tagsInput = ''
    editing.value = true
    viewing.value = null

    if (editor.value) {
      editor.value.commands.setContent(contentHTML || content)
    }

    Message.success('文档解析完成，请检查内容后保存')
  } catch (e: any) {
    showUploadProgress.value = false
    Message.error('文档解析失败: ' + (e.message || '未知错误'))
  }
}

const fetchCategories = async () => {
  categories.value = (await request.get('/knowledge/categories') as any) || []
}

const fetchArticles = async () => {
  const params: any = {}
  if (filterCategory.value) params.category_id = filterCategory.value
  if (filterKeyword.value) params.keyword = filterKeyword.value
  articles.value = (await request.get('/knowledge/articles', { params }) as any) || []
}

const openCreate = () => {
  editingId.value = null
  articleForm.title = ''
  articleForm.category_id = undefined
  articleForm.tagsInput = ''
  editing.value = true
  viewing.value = null
  if (editor.value) editor.value.commands.setContent('')
}

const editArticle = async (a: any) => {
  viewing.value = null
  editingId.value = a.id
  try {
    const result = await request.get(`/knowledge/articles/${a.id}`) as any
    const art = result.article
    articleForm.title = art.title
    articleForm.category_id = art.category_id || undefined
    try { articleForm.tagsInput = JSON.parse(art.tags || '[]').join(', ') } catch { articleForm.tagsInput = '' }
    editing.value = true
    if (editor.value) editor.value.commands.setContent(art.content_html || art.content || '')
  } catch (e) {}
}

const cancelEdit = () => { editing.value = false; editingId.value = null }

const handleSave = async (status: string) => {
  if (!articleForm.title) { Message.warning('请输入文档标题'); return }
  const tags = articleForm.tagsInput ? articleForm.tagsInput.split(',').map(s => s.trim()).filter(Boolean) : []
  const payload = {
    title: articleForm.title,
    content: editor.value?.getText() || '',
    content_html: editor.value?.getHTML() || '',
    category_id: articleForm.category_id || 0,
    status, tags,
  }
  try {
    if (editingId.value) {
      await request.put(`/knowledge/articles/${editingId.value}`, payload)
      Message.success('文档更新成功')
    } else {
      const result = await request.post('/knowledge/articles', payload) as any
      editingId.value = result.id
      Message.success('文档创建成功')
    }
    if (status === 'published') { editing.value = false; fetchArticles() }
  } catch (e) {}
}

const viewArticle = async (a: any) => {
  try {
    const result = await request.get(`/knowledge/articles/${a.id}`) as any
    viewing.value = result.article
    viewFiles.value = result.files || []
  } catch (e) {}
}

const handleDelete = (id: number) => {
  Modal.confirm({
    title: '确认删除', content: '确定要删除此文档吗？删除后不可恢复。',
    onOk: async () => { await request.delete(`/knowledge/articles/${id}`); Message.success('文档已删除'); fetchArticles() },
  })
}

const onUploadChange = async ({ file }: any) => {
  if (file.status === 'removed' && file.response?.data?.id && editingId.value) {
    try { await request.delete(`/knowledge/articles/${editingId.value}/files/${file.response.data.id}`) } catch (e) {}
  }
}

const previewFile = async (f: any) => {
  previewFilename.value = f.filename
  previewFileId.value = f.id
  previewType.value = ''; previewContent.value = ''; previewUrl.value = ''; previewTableData.value = []
  showPreview.value = true
  const ext = f.filetype.toLowerCase()
  try {
    const resp = await fetch(`/api/knowledge/articles/${f.article_id}/files/${f.id}/download`, {
      headers: { Authorization: `Bearer ${userStore.token}` },
    })
    const buffer = await resp.arrayBuffer()
    if (ext === '.docx') {
      const mammoth = await import('mammoth')
      const result = await mammoth.convertToHtml({ arrayBuffer: buffer })
      previewContent.value = result.value; previewType.value = 'html'
    } else if (['.xlsx', '.xls'].includes(ext)) {
      const XLSX = await import('xlsx')
      const wb = XLSX.read(buffer, { type: 'array' })
      const ws = wb.Sheets[wb.SheetNames[0]]
      previewTableData.value = XLSX.utils.sheet_to_json(ws, { header: 1 }) as any[][]; previewType.value = 'table'
    } else if (['.txt', '.log', '.json', '.xml', '.yaml', '.yml', '.csv', '.md', '.sh', '.py', '.go', '.sql', '.conf', '.ini'].includes(ext)) {
      previewContent.value = new TextDecoder().decode(buffer); previewType.value = 'text'
    } else { previewType.value = 'unsupported' }
  } catch (e) { previewType.value = 'unsupported' }
}

const downloadFile = (f: any) => window.open(`/api/knowledge/articles/${f.article_id}/files/${f.id}/download`, '_blank')
const downloadCurrentFile = () => {
  const f = viewFiles.value.find((f: any) => f.id === previewFileId.value)
  if (f) downloadFile(f)
}

onMounted(() => { fetchCategories(); fetchArticles() })
onBeforeUnmount(() => { editor.value?.destroy() })
</script>

<style scoped>
.knowledge-page { padding: 20px; }
.editor-wrapper { border: 1px solid #e5e6eb; border-radius: 8px; overflow: hidden; }
.editor-toolbar { padding: 8px 12px; background: #fafbfc; border-bottom: 1px solid #e5e6eb; }
.editor-content { min-height: 400px; padding: 16px; }
.editor-content :deep(.tiptap) { outline: none; min-height: 380px; }
.editor-content :deep(.tiptap p) { margin: 0 0 8px; line-height: 1.8; }
.editor-content :deep(.tiptap h1) { font-size: 28px; margin: 20px 0 8px; font-weight: 700; }
.editor-content :deep(.tiptap h2) { font-size: 22px; margin: 16px 0 6px; font-weight: 600; }
.editor-content :deep(.tiptap h3) { font-size: 18px; margin: 12px 0 4px; font-weight: 600; }
.editor-content :deep(.tiptap ul), .editor-content :deep(.tiptap ol) { padding-left: 24px; margin: 8px 0; }
.editor-content :deep(.tiptap blockquote) { border-left: 3px solid #4f7cff; padding-left: 16px; margin: 12px 0; color: #86909c; background: #f7f8fa; border-radius: 0 8px 8px 0; }
.editor-content :deep(.tiptap pre) { background: #1e1e1e; color: #d4d4d4; padding: 16px; border-radius: 8px; font-family: 'Consolas', monospace; overflow-x: auto; }
.editor-content :deep(.tiptap img) { max-width: 100%; border-radius: 8px; margin: 8px 0; cursor: pointer; transition: box-shadow 0.15s; }
.editor-content :deep(.tiptap img.img-selected) { box-shadow: 0 0 0 3px #4f7cff; }
.article-content { line-height: 1.8; font-size: 15px; }
.article-content :deep(img) { max-width: 100%; border-radius: 8px; }
.article-content :deep(table) { border-collapse: collapse; width: 100%; margin: 12px 0; }
.article-content :deep(td), .article-content :deep(th) { border: 1px solid #e5e6eb; padding: 8px 12px; }
.article-content :deep(th) { background: #fafbfc; font-weight: 600; }
.article-content :deep(pre) { background: #1e1e1e; color: #d4d4d4; padding: 16px; border-radius: 8px; overflow-x: auto; }
.preview-html { padding: 16px; line-height: 1.7; max-height: 500px; overflow: auto; }
.preview-html :deep(img) { max-width: 100%; }
.preview-html :deep(table) { border-collapse: collapse; width: 100%; }
.preview-html :deep(td), .preview-html :deep(th) { border: 1px solid #e5e6eb; padding: 6px 12px; }
.preview-table { width: 100%; border-collapse: collapse; }
.preview-table td { border: 1px solid #e5e6eb; padding: 6px 12px; font-size: 13px; }
.preview-table .table-header { background: #fafbfc; font-weight: 600; }
</style>

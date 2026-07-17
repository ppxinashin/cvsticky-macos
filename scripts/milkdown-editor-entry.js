import { Crepe } from '@milkdown/crepe'
import { commandsCtx, editorViewCtx } from '@milkdown/kit/core'
import { imageBlockSchema } from '@milkdown/kit/component/image-block'
import { toggleMark } from '@milkdown/kit/prose/commands'
import {
  addBlockTypeCommand,
  blockquoteSchema,
  codeBlockSchema,
  insertHrCommand,
  listItemSchema,
  toggleEmphasisCommand,
  toggleInlineCodeCommand,
  toggleLinkCommand,
  toggleStrongCommand,
  turnIntoTextCommand,
  wrapInBlockTypeCommand,
  wrapInBulletListCommand,
  wrapInHeadingCommand,
  wrapInOrderedListCommand,
} from '@milkdown/kit/preset/commonmark'
import { insertTableCommand, toggleStrikethroughCommand } from '@milkdown/kit/preset/gfm'
import { $command, $markSchema, $remark, replaceAll } from '@milkdown/kit/utils'
import '@milkdown/crepe/theme/common/style.css'

const fileAsDataURL = (file) => new Promise((resolve, reject) => {
  const reader = new FileReader()
  reader.onload = () => {
    const dataURL = String(reader.result || '')
    const requestID = globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`
    window.__cvstickyImageResolvers ||= new Map()
    window.__cvstickyImageResolvers.set(requestID, { resolve, reject })
    if (window.webkit?.messageHandlers?.imageUpload) {
      window.webkit.messageHandlers.imageUpload.postMessage({
        id: requestID,
        name: file.name || '',
        dataURL,
      })
      return
    }
    window.__cvstickyImageResolvers.delete(requestID)
    resolve(dataURL)
  }
  reader.onerror = () => reject(reader.error || new Error('图片读取失败'))
  reader.readAsDataURL(file)
})

const splitUnderlineText = (parent) => {
  if (!Array.isArray(parent?.children)) return
  parent.children = parent.children.flatMap((child) => {
    if (child.type !== 'text' || !child.value.includes('++')) {
      splitUnderlineText(child)
      return child
    }
    const nodes = []
    const pattern = /\+\+(.+?)\+\+/g
    let cursor = 0
    let match
    while ((match = pattern.exec(child.value))) {
      if (match.index > cursor) nodes.push({ type: 'text', value: child.value.slice(cursor, match.index) })
      nodes.push({ type: 'underline', children: [{ type: 'text', value: match[1] }] })
      cursor = match.index + match[0].length
    }
    if (!nodes.length) return child
    if (cursor < child.value.length) nodes.push({ type: 'text', value: child.value.slice(cursor) })
    return nodes
  })
}

const remarkUnderline = $remark('cvstickyUnderlineRemark', () => function underlinePlugin() {
  const data = this.data()
  const extensions = data.toMarkdownExtensions || []
  data.toMarkdownExtensions = [
    ...extensions,
    {
      handlers: {
        underline(node, _, state, info) {
          const value = state.containerPhrasing(node, { ...info, before: '+', after: '+' })
          return `++${value}++`
        },
      },
    },
  ]
  return splitUnderlineText
})

const underlineSchema = $markSchema('cvsticky_underline', () => ({
  parseDOM: [{ tag: 'u' }, { style: 'text-decoration=underline' }],
  toDOM: () => ['u', 0],
  parseMarkdown: {
    match: (node) => node.type === 'underline',
    runner: (state, node, markType) => {
      state.openMark(markType)
      state.next(node.children)
      state.closeMark(markType)
    },
  },
  toMarkdown: {
    match: (mark) => mark.type.name === 'cvsticky_underline',
    runner: (state, mark) => state.withMark(mark, 'underline'),
  },
}))

const toggleUnderlineCommand = $command('ToggleCVStickyUnderline', (ctx) => () =>
  toggleMark(underlineSchema.type(ctx))
)

let nativeSlashPopoverOpen = false
let editorIsEditable = true
let taskInteractionContext = null

const syncCodeBlockPreviewMode = () => {
  document.querySelectorAll('.milkdown-code-block').forEach((block) => {
    block.classList.toggle(
      'cvsticky-preview-only',
      !editorIsEditable && Boolean(block.querySelector('.preview-panel'))
    )
  })
}

const applyEditableState = (crepe, editable) => {
  editorIsEditable = Boolean(editable)
  crepe.setReadonly(!editorIsEditable)
  document.documentElement.classList.toggle('cvsticky-readonly', !editorIsEditable)
  if (!editorIsEditable) nativeSlashPopoverOpen = false
  requestAnimationFrame(syncCodeBlockPreviewMode)
}

const postNativeSlashPosition = (editor, action) => {
  let posted = false
  editor.action((ctx) => {
    const view = ctx.get(editorViewCtx)
    const { selection } = view.state
    if (!selection.empty || !selection.$from.parent.isTextblock) return
    const caret = view.coordsAtPos(selection.from)
    posted = true
    window.webkit.messageHandlers.slashMenu.postMessage({
      action,
      x: caret.left,
      y: caret.top,
      width: Math.max(1, caret.right - caret.left),
      height: Math.max(1, caret.bottom - caret.top),
    })
  })
  return posted
}

const bindNativeInteractions = (perform, editor) => {
  let repositionScheduled = false
  const tryOpenSlashMenu = () => {
    if (!editorIsEditable) return false
    let shouldOpenMenu = false
    editor.action((ctx) => {
      const view = ctx.get(editorViewCtx)
      const { selection } = view.state
      if (!view.editable || !selection.empty || !selection.$from.parent.isTextblock) return
      shouldOpenMenu = true
    })
    if (!shouldOpenMenu) return false
    nativeSlashPopoverOpen = true
    postNativeSlashPosition(editor, 'show')
    return true
  }
  const schedulePopoverReposition = () => {
    if (!nativeSlashPopoverOpen || repositionScheduled) return
    repositionScheduled = true
    requestAnimationFrame(() => {
      repositionScheduled = false
      postNativeSlashPosition(editor, 'move')
    })
  }
  document.addEventListener('selectionchange', schedulePopoverReposition)
  window.addEventListener('scroll', schedulePopoverReposition, true)
  window.addEventListener('resize', schedulePopoverReposition)
  document.addEventListener('keydown', (event) => {
    if (!editorIsEditable) {
      const navigationKeys = new Set([
        'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown',
        'PageUp', 'PageDown', 'Home', 'End', 'Escape',
      ])
      if (!navigationKeys.has(event.key) || event.metaKey || event.ctrlKey || event.altKey) {
        event.preventDefault()
        event.stopImmediatePropagation()
      }
      return
    }
    const mod = event.metaKey || event.ctrlKey
    const isSlashShortcut = event.metaKey
      && !event.ctrlKey
      && !event.altKey
      && !event.shiftKey
      && event.code === 'Slash'
    if (isSlashShortcut && tryOpenSlashMenu()) {
      event.preventDefault()
      event.stopImmediatePropagation()
      return
    }
    if (event.isComposing) return
    let command
    if (event.altKey && !mod && /^Digit[1-6]$/.test(event.code)) command = `heading${event.code.slice(-1)}`
    else if (mod && !event.shiftKey && event.key.toLowerCase() === 'b') command = 'bold'
    else if (mod && !event.shiftKey && event.key.toLowerCase() === 'i') command = 'italic'
    else if (mod && !event.shiftKey && event.key.toLowerCase() === 'u') command = 'underline'
    else if (mod && !event.shiftKey && event.key.toLowerCase() === 'e') command = 'code'
    else if (mod && !event.shiftKey && event.key.toLowerCase() === 'k') command = 'link'
    else if (mod && event.shiftKey && event.key.toLowerCase() === 'x') command = 'strike'
    else if (mod && event.shiftKey && event.code === 'Digit8') command = 'bulletList'
    else if (mod && event.shiftKey && event.code === 'Digit7') command = 'orderedList'
    if (!command) return
    event.preventDefault()
    perform(command)
  }, true)

  document.addEventListener('beforeinput', (event) => {
    if (!editorIsEditable) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }, true)
  for (const eventName of ['paste', 'cut', 'drop']) {
    document.addEventListener(eventName, (event) => {
      if (!editorIsEditable) {
        event.preventDefault()
        event.stopImmediatePropagation()
      }
    }, true)
  }
}

const taskLabels = () => Array.from(document.querySelectorAll(
  '.milkdown-list-item-block .label.checked, .milkdown-list-item-block .label.unchecked'
))

const taskPositionForBlock = (view, taskType, block) => {
  const listItem = Array.from(block.children)
    .find((element) => element.classList.contains('list-item'))
  const children = listItem && Array.from(listItem.children)
    .find((element) => element.classList.contains('children'))
  const contentDOM = children && Array.from(children.children)
    .find((element) => element.classList.contains('content-dom'))
  if (!contentDOM) return null

  let position
  try {
    position = view.posAtDOM(contentDOM, 0, 1)
  } catch {
    return null
  }
  const resolved = view.state.doc.resolve(position)
  for (let depth = resolved.depth; depth > 0; depth -= 1) {
    const node = resolved.node(depth)
    if (node.type === taskType && node.attrs.checked != null) {
      return resolved.before(depth)
    }
  }
  return null
}

const taskStates = (editor) => {
  const states = []
  editor.action((ctx) => {
    const view = ctx.get(editorViewCtx)
    const taskType = listItemSchema.type(ctx)
    view.state.doc.descendants((node, position) => {
      if (node.type === taskType && node.attrs.checked != null) {
        states.push({ position, checked: Boolean(node.attrs.checked) })
      }
    })
  })
  return states
}

const toggleTaskChecked = (editor, block) => {
  let nextChecked = null
  editor.action((ctx) => {
    const view = ctx.get(editorViewCtx)
    const taskType = listItemSchema.type(ctx)
    const taskPosition = taskPositionForBlock(view, taskType, block)
    if (taskPosition == null) return
    const task = view.state.doc.nodeAt(taskPosition)
    if (!task || task.attrs.checked == null) return
    nextChecked = !Boolean(task.attrs.checked)
    view.dispatch(view.state.tr.setNodeAttribute(taskPosition, 'checked', nextChecked))
  })
  return nextChecked
}

const updateTaskControl = (control, block, checked) => {
  control.setAttribute('aria-checked', String(checked))
  control.setAttribute('aria-label', checked ? '标记为未完成' : '标记为已完成')
  block.dataset.taskChecked = String(checked)
}

const syncTaskControls = () => {
  if (!taskInteractionContext) return
  const { crepe } = taskInteractionContext
  const states = taskStates(crepe.editor)
  taskLabels().forEach((label, index) => {
    const wrapper = label.closest('.label-wrapper')
    const block = label.closest('.milkdown-list-item-block')
    if (!wrapper || !block) return

    let control = wrapper.querySelector('.cvsticky-task-checkbox')
    if (!control) {
      control = document.createElement('button')
      control.type = 'button'
      control.className = 'cvsticky-task-checkbox'
      control.setAttribute('role', 'checkbox')
      wrapper.append(control)
    }

    const state = states[index]
    const checked = state?.checked ?? label.classList.contains('checked')
    if (state) block.dataset.taskPosition = String(state.position)
    updateTaskControl(control, block, checked)
    label.style.display = 'none'
  })
}

const taskControlForEvent = (root, event) => {
  const target = event.target
  if (!(target instanceof Element)) return null
  const control = target.closest('.cvsticky-task-checkbox')
  return control && root.contains(control) ? control : null
}

const bindTaskInteractions = (root, onTaskToggle, crepe) => {
  taskInteractionContext = { crepe, onTaskToggle }
  for (const eventName of ['pointerdown', 'mousedown']) {
    root.addEventListener(eventName, (event) => {
      if (!taskControlForEvent(root, event)) return
      // Keep Milkdown's list-item node view from moving the selection. Do not
      // prevent the default button activation; click is the sole state change.
      event.stopImmediatePropagation()
    }, true)
  }
  root.addEventListener('click', (event) => {
    const control = taskControlForEvent(root, event)
    if (!control) return
    event.preventDefault()
    event.stopImmediatePropagation()
    const block = control.closest('.milkdown-list-item-block')
    if (!block) return
    const checked = toggleTaskChecked(crepe.editor, block)
    if (checked == null) {
      requestAnimationFrame(syncTaskControls)
      return
    }
    updateTaskControl(control, block, checked)
    syncTaskControls()
    onTaskToggle(crepe.getMarkdown())
    requestAnimationFrame(syncTaskControls)
  }, true)
  syncTaskControls()
  new MutationObserver(() => {
    syncTaskControls()
    if (!editorIsEditable) syncCodeBlockPreviewMode()
  }).observe(root, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['class'],
  })
}

window.__cvstickyResolveImageUpload = (requestID, path, error) => {
  const resolver = window.__cvstickyImageResolvers?.get(requestID)
  if (!resolver) return
  window.__cvstickyImageResolvers.delete(requestID)
  if (error) resolver.reject(new Error(error))
  else resolver.resolve(path)
}

window.CVStickyWYSIWYG = {
  async create({ root, markdown, editable = true, onChange, onTaskToggle, onReady, onError }) {
    try {
      const crepe = new Crepe({
        root,
        defaultValue: markdown,
        features: {
          [Crepe.Feature.TopBar]: false,
          [Crepe.Feature.AI]: false,
          [Crepe.Feature.BlockEdit]: false,
        },
        featureConfigs: {
          [Crepe.Feature.Placeholder]: {
            text: '输入正文，或按 ⌘/ 插入标题、列表、图片、表格和公式…',
          },
          [Crepe.Feature.ImageBlock]: {
            onUpload: fileAsDataURL,
            inlineOnUpload: fileAsDataURL,
            blockOnUpload: fileAsDataURL,
            inlineConfirmButton: '确定',
            blockConfirmButton: '确定',
            inlineUploadButton: '选择图片',
            blockUploadButton: '选择图片',
            inlineUploadPlaceholderText: '或粘贴图片地址',
            blockUploadPlaceholderText: '或粘贴图片地址',
            blockCaptionPlaceholderText: '图片说明',
          },
          [Crepe.Feature.LinkTooltip]: {
            editButton: '编辑链接',
            removeButton: '移除链接',
            confirmButton: '确定',
            inputPlaceholder: '粘贴或输入链接',
          },
          [Crepe.Feature.Latex]: {
            inlineEditConfirm: '确定',
          },
          [Crepe.Feature.CodeMirror]: {
            previewToggleText: (previewOnlyMode) => previewOnlyMode ? '编辑代码' : '预览结果',
          },
        },
      })
      crepe.editor.use(remarkUnderline).use(underlineSchema).use(toggleUnderlineCommand)

      crepe.on((listener) => {
        listener.markdownUpdated((_, next, previous) => {
          if (next !== previous) onChange(next)
        })
      })
      await crepe.create()
      window.__cvstickyCrepe = crepe
      bindTaskInteractions(root, onTaskToggle, crepe)
      applyEditableState(crepe, editable)
      const perform = (command, payload) => {
        if (!editorIsEditable) return
        crepe.editor.action((ctx) => {
          const commands = ctx.get(commandsCtx)
          const view = ctx.get(editorViewCtx)
          const run = (commandKey, payload) => commands.call(commandKey.key, payload)
          switch (command) {
          case 'text': run(turnIntoTextCommand); break
          case 'heading1': run(wrapInHeadingCommand, 1); break
          case 'heading2': run(wrapInHeadingCommand, 2); break
          case 'heading3': run(wrapInHeadingCommand, 3); break
          case 'heading4': run(wrapInHeadingCommand, 4); break
          case 'heading5': run(wrapInHeadingCommand, 5); break
          case 'heading6': run(wrapInHeadingCommand, 6); break
          case 'bold': run(toggleStrongCommand); break
          case 'italic': run(toggleEmphasisCommand); break
          case 'underline': run(toggleUnderlineCommand); break
          case 'strike': run(toggleStrikethroughCommand); break
          case 'code': run(toggleInlineCodeCommand); break
          case 'bulletList': run(wrapInBulletListCommand); break
          case 'orderedList': run(wrapInOrderedListCommand); break
          case 'taskList':
            run(wrapInBlockTypeCommand, { nodeType: listItemSchema.type(ctx), attrs: { checked: false } })
            break
          case 'quote': run(wrapInBlockTypeCommand, { nodeType: blockquoteSchema.type(ctx) }); break
          case 'divider': run(insertHrCommand); break
          case 'table': run(insertTableCommand, { row: payload?.row || 3, col: payload?.col || 3 }); break
          case 'mermaid':
            run(addBlockTypeCommand, { nodeType: codeBlockSchema.type(ctx), attrs: { language: 'mermaid' } })
            break
          case 'codeBlock':
            run(addBlockTypeCommand, { nodeType: codeBlockSchema.type(ctx) })
            break
          case 'math': {
            const { state } = view
            const mathType = state.schema.nodes.math_inline
            if (!mathType) break
            const value = state.doc.textBetween(state.selection.from, state.selection.to) || 'E=mc^2'
            view.dispatch(state.tr.replaceSelectionWith(mathType.create({ value })))
            break
          }
          case 'link': run(toggleLinkCommand); break
          case 'image': run(addBlockTypeCommand, { nodeType: imageBlockSchema.type(ctx) }); break
          default: break
          }
          view.focus()
        })
      }
      window.__cvstickyPerform = perform
      bindNativeInteractions(perform, crepe.editor)
      onReady()
    } catch (error) {
      onError(String(error && error.stack ? error.stack : error))
    }
  },

  setMarkdown(markdown) {
    const crepe = window.__cvstickyCrepe
    if (crepe && crepe.getMarkdown() !== markdown) crepe.editor.action(replaceAll(markdown))
    requestAnimationFrame(() => {
      syncTaskControls()
      syncCodeBlockPreviewMode()
    })
  },

  setEditable(editable) {
    const crepe = window.__cvstickyCrepe
    if (crepe) applyEditableState(crepe, editable)
  },

  refreshMarkdown(markdown) {
    const crepe = window.__cvstickyCrepe
    if (crepe) crepe.editor.action(replaceAll(markdown))
    requestAnimationFrame(() => {
      syncTaskControls()
      syncCodeBlockPreviewMode()
    })
  },

  getMarkdown() {
    return window.__cvstickyCrepe ? window.__cvstickyCrepe.getMarkdown() : ''
  },

  perform(command, payload) {
    window.__cvstickyPerform?.(command, payload)
  },

  setSlashPopoverOpen(isOpen) {
    nativeSlashPopoverOpen = Boolean(isOpen)
  },
}

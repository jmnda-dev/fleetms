import {Editor} from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import TextAlign from "@tiptap/extension-text-align"

// Flowbite-styled WYSIWYG built on Tiptap, wrapped for LiveView.
//
// The whole control sits inside a `phx-update="ignore"` container so morphdom
// never tears down the editor (Tiptap owns a ProseMirror DOM that LiveView must
// not patch). The edited HTML is mirrored into a hidden <input> on every change,
// and we dispatch a bubbling "input" event so the form's `phx-change`/
// `phx-submit` pick it up. The server is responsible for sanitizing the HTML
// before storing/rendering it — never trust this markup.
//
// Expected child elements (by data attribute):
//   [data-rt-toolbar]  — toolbar container (buttons carry data-rt-action)
//   [data-rt-content]  — div that becomes the editor surface
//   [data-rt-input]    — hidden input carrying the HTML for the form
//
// Toolbar actions (data-rt-action): bold, italic, underline, strike, h1, h2, h3,
//   paragraph, bulletList, orderedList, blockquote, code, link, unlink,
//   alignLeft, alignCenter, alignRight, undo, redo.
const ACTIVE = ["bg-gray-100", "dark:bg-gray-600", "text-gray-900", "dark:text-white"]

const RichText = {
  mounted() {
    const el = this.el
    const contentEl = el.querySelector("[data-rt-content]")
    const inputEl = el.querySelector("[data-rt-input]")
    const toolbarEl = el.querySelector("[data-rt-toolbar]")

    this.editor = new Editor({
      element: contentEl,
      extensions: [
        StarterKit.configure({link: {openOnClick: false, autolink: true}}),
        TextAlign.configure({types: ["heading", "paragraph"]})
      ],
      content: inputEl.value || "",
      editorProps: {
        attributes: {
          class:
            "format dark:format-invert max-w-none focus:outline-none px-4 py-3 min-h-[12rem]"
        }
      },
      onUpdate: ({editor}) => {
        inputEl.value = editor.isEmpty ? "" : editor.getHTML()
        inputEl.dispatchEvent(new Event("input", {bubbles: true}))
      },
      onSelectionUpdate: () => this.refreshActive(),
      onTransaction: () => this.refreshActive()
    })

    this.onToolbarClick = (e) => {
      const btn = e.target.closest("[data-rt-action]")
      if (!btn || !toolbarEl.contains(btn)) return
      e.preventDefault()
      this.run(btn.dataset.rtAction)
    }
    toolbarEl.addEventListener("click", this.onToolbarClick)
    this.toolbarEl = toolbarEl
    this.refreshActive()
  },

  run(action) {
    const chain = this.editor.chain().focus()
    switch (action) {
      case "bold": return chain.toggleBold().run()
      case "italic": return chain.toggleItalic().run()
      case "underline": return chain.toggleUnderline().run()
      case "strike": return chain.toggleStrike().run()
      case "h1": return chain.toggleHeading({level: 1}).run()
      case "h2": return chain.toggleHeading({level: 2}).run()
      case "h3": return chain.toggleHeading({level: 3}).run()
      case "paragraph": return chain.setParagraph().run()
      case "bulletList": return chain.toggleBulletList().run()
      case "orderedList": return chain.toggleOrderedList().run()
      case "blockquote": return chain.toggleBlockquote().run()
      case "code": return chain.toggleCode().run()
      case "alignLeft": return chain.setTextAlign("left").run()
      case "alignCenter": return chain.setTextAlign("center").run()
      case "alignRight": return chain.setTextAlign("right").run()
      case "undo": return chain.undo().run()
      case "redo": return chain.redo().run()
      case "unlink": return chain.unsetLink().run()
      case "link": {
        const prev = this.editor.getAttributes("link").href
        const url = window.prompt("Link URL", prev || "https://")
        if (url === null) return
        if (url === "") return chain.unsetLink().run()
        return chain.extendMarkRange("link").setLink({href: url}).run()
      }
    }
  },

  // Reflect the editor's current marks/nodes/alignment on the toolbar buttons.
  refreshActive() {
    if (!this.toolbarEl) return
    this.toolbarEl.querySelectorAll("[data-rt-action]").forEach((btn) => {
      const action = btn.dataset.rtAction
      const active = this.isActive(action)
      btn.classList.toggle("is-active", active)
      ACTIVE.forEach((c) => btn.classList.toggle(c, active))
    })
  },

  isActive(action) {
    const ed = this.editor
    switch (action) {
      case "bold": return ed.isActive("bold")
      case "italic": return ed.isActive("italic")
      case "underline": return ed.isActive("underline")
      case "strike": return ed.isActive("strike")
      case "h1": return ed.isActive("heading", {level: 1})
      case "h2": return ed.isActive("heading", {level: 2})
      case "h3": return ed.isActive("heading", {level: 3})
      case "bulletList": return ed.isActive("bulletList")
      case "orderedList": return ed.isActive("orderedList")
      case "blockquote": return ed.isActive("blockquote")
      case "code": return ed.isActive("code")
      case "link": return ed.isActive("link")
      case "alignLeft": return ed.isActive({textAlign: "left"})
      case "alignCenter": return ed.isActive({textAlign: "center"})
      case "alignRight": return ed.isActive({textAlign: "right"})
      default: return false
    }
  },

  destroyed() {
    if (this.toolbarEl && this.onToolbarClick) {
      this.toolbarEl.removeEventListener("click", this.onToolbarClick)
    }
    if (this.editor) this.editor.destroy()
  }
}

export default RichText

// A tiny signature pad: draw on the canvas with mouse/touch, and keep the drawing as a
// PNG data URL in the hook's hidden input so it rides along on the inspection's form
// submit. Only the canvas is `phx-update="ignore"` (LiveView never redraws it); the
// hidden input is server-managed so its value round-trips, and `updated()` re-applies the
// captured drawing after any server patch so an unrelated re-render can't wipe it before
// submit. "Clear" wipes both.
const SignaturePad = {
  mounted() {
    this.canvas = this.el.querySelector("[data-sig-canvas]")
    this.input = this.el.querySelector("[data-sig-input]")
    this.dataUrl = this.input.value || ""
    const clear = this.el.querySelector("[data-sig-clear]")
    const ctx = this.canvas.getContext("2d")

    // Paint the buffer white so the exported image is dark ink on white — a transparent
    // buffer would flatten to black when stored as a JPG.
    const fill = () => {
      ctx.fillStyle = "#ffffff"
      ctx.fillRect(0, 0, this.canvas.width, this.canvas.height)
    }
    fill()

    ctx.lineWidth = 2
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.strokeStyle = "#111827"

    let drawing = false

    // Map a pointer event to canvas-buffer coordinates (the CSS size differs from the
    // drawing buffer, so scale by the ratio).
    const point = (e) => {
      const rect = this.canvas.getBoundingClientRect()
      return {
        x: (e.clientX - rect.left) * (this.canvas.width / rect.width),
        y: (e.clientY - rect.top) * (this.canvas.height / rect.height),
      }
    }

    const start = (e) => {
      drawing = true
      const {x, y} = point(e)
      ctx.beginPath()
      ctx.moveTo(x, y)
      e.preventDefault()
    }

    const move = (e) => {
      if (!drawing) return
      const {x, y} = point(e)
      ctx.lineTo(x, y)
      ctx.stroke()
      e.preventDefault()
    }

    const end = () => {
      if (!drawing) return
      drawing = false
      this.dataUrl = this.canvas.toDataURL("image/png")
      this.input.value = this.dataUrl
    }

    this.canvas.addEventListener("pointerdown", start)
    this.canvas.addEventListener("pointermove", move)
    window.addEventListener("pointerup", end)
    this._end = end

    clear.addEventListener("click", () => {
      fill()
      this.dataUrl = ""
      this.input.value = ""
    })
  },

  // LiveView may re-render (and reset) the server-managed hidden input on unrelated
  // changes; restore the captured drawing so it survives until submit.
  updated() {
    if (this.dataUrl) this.input.value = this.dataUrl
  },

  destroyed() {
    if (this._end) window.removeEventListener("pointerup", this._end)
  },
}

export default SignaturePad

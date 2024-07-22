// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

// import 'svgmap/dist/svgMap.min.css';
import 'flowbite/dist/flowbite.phoenix.js'
import Alpine from "alpinejs"
// import * as Components from "../svelte/**/*.svelte"
import Hooks from "./hooks";
// import './charts';
// import './map';
// import './kanban';

import topbar from "../vendor/topbar"

window.Alpine = Alpine;
Alpine.start();


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken }, hooks: Hooks, dom: {
        onBeforeElUpdated(from, to) {
            if (from.hasAttribute('data-clone-attributes')) {
                const attributes = from.attributes;

                for (let i = 0; i < attributes.length; i++) {
                    const attribute = attributes[i];
                    to.setAttribute(attribute.name, attribute.value);
                }
            }

            if (from._x_dataStack) {
                window.Alpine.clone(from, to);
            }
        }
    }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => {
    topbar.hide()
})

// window.document.addEventListener("phx:page-loading-stop", _info => console.log("Loaded"))


// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

window.addEventListener("phx:create_download_link", (event) => {
    let link = document.createElement("a")
    link.href = event.detail.download_link
    link.style.display = 'none'
    link.target = "_blank"
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
})

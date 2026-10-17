// JS bundling for the app, driven through esbuild's JS API so we can use the
// `esbuild-svelte` plugin (the Elixir `esbuild` wrapper runs the binary directly
// and can't load JS plugins). Tailwind still runs via its own Elixir wrapper.
//
// Replicates the options the Elixir esbuild config used — entry, target, outdir,
// externals, and the `@` alias — and reproduces its NODE_PATH via `nodePaths` so
// bare imports like `phoenix` / `phoenix_live_view` resolve out of the Elixir
// deps and `phoenix-colocated/*` out of the build directory.
//
// Modes: (none) one-off build · --watch rebuild on change · --deploy minify.
import esbuild from "esbuild"
import sveltePlugin from "esbuild-svelte"

const args = process.argv.slice(2)
const watch = args.includes("--watch")
const deploy = args.includes("--deploy")
const mixEnv = process.env.MIX_ENV || "dev"

const options = {
  entryPoints: ["js/app.js"],
  bundle: true,
  platform: "browser",
  target: "es2022",
  outdir: "../priv/static/assets/js",
  logLevel: "info",
  external: ["/fonts/*", "/images/*"],
  alias: {"@": "."},
  nodePaths: ["../deps", `../_build/${mixEnv}`],
  sourcemap: watch && "inline",
  minify: deploy,
  plugins: [
    sveltePlugin({
      compilerOptions: {
        dev: !deploy,
        // The builder uses caption-style <label>s above their inputs rather than
        // id-associated ones. Silence just that a11y rule; proper association is
        // a later polish. All other warnings still surface.
        warningFilter: (w) => w.code !== "a11y_label_has_associated_control"
      }
    })
  ]
}

if (watch) {
  const ctx = await esbuild.context(options)
  await ctx.watch()
  console.log("esbuild watching for changes…")
} else {
  await esbuild.build(options)
}

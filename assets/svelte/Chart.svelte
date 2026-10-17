<script>
  // A thin ECharts wrapper. It builds the chart from `spec` (see chartOption.js) and
  // re-themes for `dark`. Only the chart types and components we actually use are
  // registered, to keep the bundle small.
  import {onMount, onDestroy} from "svelte"
  import * as echarts from "echarts/core"
  import {LineChart, BarChart} from "echarts/charts"
  import {GridComponent, TooltipComponent, LegendComponent} from "echarts/components"
  import {CanvasRenderer} from "echarts/renderers"
  import {buildOption} from "./lib/chartOption.js"

  echarts.use([LineChart, BarChart, GridComponent, TooltipComponent, LegendComponent, CanvasRenderer])

  let {spec, dark = false} = $props()

  let el
  let chart
  let resizeObserver

  onMount(() => {
    chart = echarts.init(el, null, {renderer: "canvas"})
    chart.setOption(buildOption(spec, dark))
    resizeObserver = new ResizeObserver(() => chart.resize())
    resizeObserver.observe(el)
  })

  onDestroy(() => {
    resizeObserver?.disconnect()
    chart?.dispose()
  })
</script>

<div bind:this={el} class="h-full w-full"></div>

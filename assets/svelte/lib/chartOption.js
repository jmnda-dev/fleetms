// Builds an ECharts `option` from a small, server-supplied `spec`, so all dashboard
// charts share one set of styling decisions (thin marks, rounded bar ends, recessive
// axes/grid, a crosshair tooltip, and a legend only when there are ≥2 series).
//
// spec = {
//   kind: "line" | "bar",
//   categories: string[],
//   series: [{ name, data: number[], color: 1-based palette slot }],
//   stack?: boolean,
//   valueFormat?: "number" | "money",
//   currency?: string   // when valueFormat === "money"
// }

// The data-viz skill's validated categorical palette (slots 1–2 verified for this use,
// in both modes); the dark column is the same hues stepped for the dark surface.
const PALETTE = {
  light: ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"],
  dark: ["#3987e5", "#d95926", "#199e70", "#c98500"],
}

// Recessive ink: axis labels/lines and grid split lines sit back from the data.
const INK = {
  light: {text: "#52514e", axis: "#a8a7a2", split: "#ececea", tooltipBg: "#ffffff"},
  dark: {text: "#c3c2b7", axis: "#6b6a64", split: "#2a2a28", tooltipBg: "#1f1f1e"},
}

export function buildOption(spec, dark) {
  const palette = dark ? PALETTE.dark : PALETTE.light
  const ink = dark ? INK.dark : INK.light
  const series = spec.series || []
  const multi = series.length > 1
  const money = spec.valueFormat === "money"

  const num = (v) => Number(v).toLocaleString()
  const valueLabel = (v) => (money ? `${spec.currency} ${num(v)}` : num(v))

  return {
    color: series.map((s) => palette[(s.color || 1) - 1]),
    animationDuration: 300,
    grid: {left: 4, right: 12, top: multi ? 34 : 12, bottom: 4, containLabel: true},
    tooltip: {
      trigger: "axis",
      axisPointer: {type: spec.kind === "line" ? "line" : "shadow"},
      valueFormatter: valueLabel,
      backgroundColor: ink.tooltipBg,
      borderColor: ink.split,
      textStyle: {color: ink.text},
    },
    legend: multi
      ? {
          top: 0,
          right: 0,
          icon: "roundRect",
          itemWidth: 11,
          itemHeight: 11,
          textStyle: {color: ink.text},
        }
      : undefined,
    xAxis: {
      type: "category",
      data: spec.categories,
      axisLine: {lineStyle: {color: ink.axis}},
      axisTick: {show: false},
      axisLabel: {color: ink.text},
    },
    yAxis: {
      type: "value",
      splitLine: {lineStyle: {color: ink.split}},
      axisLine: {show: false},
      axisLabel: {color: ink.text, formatter: (v) => num(v)},
    },
    series: series.map((s) => ({
      name: s.name,
      type: spec.kind === "line" ? "line" : "bar",
      data: s.data,
      ...(spec.stack ? {stack: "total"} : {}),
      ...(spec.kind === "line"
        ? {
            smooth: false,
            symbol: "circle",
            symbolSize: 8,
            showSymbol: (s.data || []).length <= 12,
            lineStyle: {width: 2},
          }
        : {barMaxWidth: 30, itemStyle: {borderRadius: [4, 4, 0, 0]}}),
    })),
  }
}

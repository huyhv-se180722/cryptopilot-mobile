// CryptoPilot metric chart page (SCR-11: open interest and long/short
// ratio; ADR-012, D-144). Lines over time in the theme of the candle chart.
// The app drives it through the Host channel; values arrive as decimal
// strings and become numbers only here, to draw. A point is drawn where it
// exists; a gap is never filled.
(function () {
  const L = LightweightCharts;
  let chart, theme, series = [], data = null;

  function post(m) { Host.postMessage(JSON.stringify(m)); }

  // left: a second unit shares the chart (open interest and its value).
  function layout(t, left) {
    return {
      layout: { background: { type: 'solid', color: t.bg }, textColor: t.text, attributionLogo: true },
      grid: { vertLines: { color: t.grid }, horzLines: { color: t.grid } },
      timeScale: { timeVisible: true, secondsVisible: false, borderColor: t.grid },
      rightPriceScale: { borderColor: t.grid },
      leftPriceScale: { visible: left, borderColor: t.grid },
    };
  }

  function hasLeft() {
    return !!data && data.lines.some(function (l) { return l.scale === 'left'; });
  }

  window.init = function (t) {
    theme = t;
    chart = L.createChart(document.getElementById('c'), Object.assign({
      autoSize: true,
      localization: { locale: 'en-US' },
      handleScroll: { vertTouchDrag: false },
    }, layout(t, false)));
    post({ type: 'ready' });
  };

  window.setTheme = function (t) {
    theme = t;
    chart.applyOptions(layout(t, hasLeft()));
  };

  // d: { offset: seconds added to every time (BR-08, the library draws UTC
  // only), lines: [{ color, scale: 'left' | 'right', format: 'amount' |
  // 'ratio', points: [[seconds, 'decimal'], …] oldest first }] }.
  window.setLines = function (d) {
    data = d;
    series.forEach(function (s) { chart.removeSeries(s); });
    series = [];
    chart.applyOptions(layout(theme, hasLeft()));
    d.lines.forEach(function (l) {
      const s = chart.addSeries(L.LineSeries, {
        color: l.color, lineWidth: 2, priceScaleId: l.scale, priceLineVisible: false,
        // Amounts in K / M / B, ratios at four decimals, as on the web.
        priceFormat: l.format === 'amount' ? { type: 'volume' } : { type: 'price', precision: 4, minMove: 0.0001 },
      });
      s.setData(l.points.map(function (p) { return { time: p[0] + d.offset, value: +p[1] }; }));
      series.push(s);
    });
    chart.timeScale().fitContent();
  };

  window.onerror = function (m) { post({ type: 'log', msg: String(m) }); };
})();

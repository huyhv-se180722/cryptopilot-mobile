// CryptoPilot chart page (ADR-012, D-144). The app drives it through the
// Host channel; prices arrive as decimal strings and become numbers only
// here, to draw. Every call is safe before data arrives.
(function () {
  const L = LightweightCharts;
  let chart, candles, theme, lines = [], extra = [], asking = false, payload = null;
  // Seconds added to every time: the library draws UTC only (BR-08).
  let offset = 0, payloadOffset = 0;

  function post(m) { Host.postMessage(JSON.stringify(m)); }

  function layout(t) {
    return {
      layout: {
        background: { type: 'solid', color: t.bg },
        textColor: t.text,
        attributionLogo: true,
        panes: { separatorColor: t.grid },
      },
      grid: { vertLines: { color: t.grid }, horzLines: { color: t.grid } },
      timeScale: { timeVisible: true, secondsVisible: false, borderColor: t.grid },
      rightPriceScale: { borderColor: t.grid },
    };
  }

  function candleColors(t) {
    return { upColor: t.up, downColor: t.down, wickUpColor: t.up, wickDownColor: t.down, borderVisible: false };
  }

  window.init = function (t) {
    theme = t;
    chart = L.createChart(document.getElementById('c'), Object.assign({
      autoSize: true,
      localization: { locale: 'en-US' },
      handleScroll: { vertTouchDrag: false },
    }, layout(t)));
    candles = chart.addSeries(L.CandlestickSeries, candleColors(t));
    chart.timeScale().subscribeVisibleLogicalRangeChange(function (r) {
      if (r && r.from < 10 && !asking && candles.data().length > 0) {
        asking = true;
        post({ type: 'more' });
      }
    });
    post({ type: 'ready' });
  };

  window.setTheme = function (t) {
    theme = t;
    chart.applyOptions(layout(t));
    candles.applyOptions(candleColors(t));
    if (payload) setIndicators(payload, true);
  };

  window.setPrecision = function (p) {
    candles.applyOptions({ priceFormat: { type: 'price', precision: p, minMove: Math.pow(10, -p) } });
  };

  // Set before the candles of a pair and timeframe; 0 for daily candles.
  window.setTimeOffset = function (seconds) { offset = seconds; };

  function time(c) { return Date.parse(c.openTime) / 1000 + offset; }

  // A forming candle (SRS 3.3.2: provisional) is drawn faded.
  function bar(c) {
    const b = { time: time(c), open: +c.open, high: +c.high, low: +c.low, close: +c.close };
    if (c.closed === false) {
      const color = (+c.close >= +c.open ? theme.up : theme.down) + '80';
      b.color = color; b.wickColor = color; b.borderColor = color;
    }
    return b;
  }

  function clearIndicators() {
    extra.forEach(function (s) { chart.removeSeries(s); });
    extra = [];
    while (chart.panes().length > 1) chart.removePane(chart.panes().length - 1);
  }

  // shift > 0: older candles went in front; keep what the Trader looks at.
  // Otherwise the list is a new one (another pair or timeframe, or the fresh
  // candles after the cached ones): the indicators on the page belong to the
  // old list, and every series shares one time scale, so their times would
  // join these candles' and the last candles would no longer be the ones
  // shown. They go first; setIndicators draws the new ones.
  window.setCandles = function (list, tag, shift) {
    const r = shift > 0 ? chart.timeScale().getVisibleLogicalRange() : null;
    if (!(shift > 0)) { clearIndicators(); payload = null; }
    candles.setData(list.map(bar));
    if (r) {
      chart.timeScale().setVisibleLogicalRange({ from: r.from + shift, to: r.to + shift });
    } else if (list.length > 0) {
      chart.timeScale().setVisibleLogicalRange({ from: Math.max(list.length - 120, 0), to: list.length + 2 });
    }
    asking = false;
    requestAnimationFrame(function () { requestAnimationFrame(function () { post({ type: 'rendered', tag: tag }); }); });
  };

  window.update = function (c) { candles.update(bar(c)); };

  function points(times, values, by) {
    return values.map(function (v, i) {
      return v == null ? { time: times[i] + by } : { time: times[i] + by, value: v };
    });
  }

  // Overlays on the price pane, panels below it (Volume, RSI, MACD), rebuilt
  // whenever the candles or the Trader's choice change.
  // again: the same payload redrawn (a new theme), at the offset it came with.
  function setIndicators(p, again) {
    payload = p;
    if (!again) payloadOffset = offset;
    const by = payloadOffset;
    clearIndicators();
    p.overlays.forEach(function (o) {
      const s = chart.addSeries(L.LineSeries, {
        color: o.color, lineWidth: 1, priceLineVisible: false, lastValueVisible: false, crosshairMarkerVisible: false,
      }, 0);
      s.setData(points(p.times, o.values, by));
      extra.push(s);
    });
    p.panels.forEach(function (panel, k) {
      panel.series.forEach(function (d) {
        const histogram = d.type === 'histogram';
        const s = chart.addSeries(histogram ? L.HistogramSeries : L.LineSeries, {
          color: d.color || theme.grid, lineWidth: 1, priceLineVisible: false, lastValueVisible: !histogram,
          crosshairMarkerVisible: false,
          priceFormat: d.volume ? { type: 'volume' } : { type: 'price', precision: 2, minMove: 0.01 },
        }, k + 1);
        if (histogram) {
          s.setData(d.values.map(function (v, i) {
            return v == null ? { time: p.times[i] + by }
              : { time: p.times[i] + by, value: v, color: (d.up[i] ? theme.up : theme.down) + '66' };
          }));
        } else {
          s.setData(points(p.times, d.values, by));
        }
        (d.levels || []).forEach(function (level) {
          s.createPriceLine({ price: level, color: theme.text, lineWidth: 1, lineStyle: 2, axisLabelVisible: false });
        });
        extra.push(s);
      });
    });
    chart.panes().forEach(function (pane, i) { if (i > 0) pane.setHeight(80); });
  }
  window.setIndicators = function (p) { setIndicators(p, false); };

  // Price lines: BR-14 levels now; entry, stop loss, take profit later.
  window.setLines = function (ls) {
    lines.forEach(function (l) { candles.removePriceLine(l); });
    lines = ls.map(function (l) {
      return candles.createPriceLine({
        price: +l.price, color: l.color, lineWidth: 1, lineStyle: 2, axisLabelVisible: true, title: l.label,
      });
    });
  };

  window.onerror = function (m) { post({ type: 'log', msg: String(m) }); };
})();

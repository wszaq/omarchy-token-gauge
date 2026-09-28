import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

// Agent token usage — standardized per-provider rows (fuel-tank remaining).
// Layout/KPIs: docs/provider-row-spec.md
// Dial look: JustGage / Dribbble 2185155 (annular band, ticks, tip needle, center %).
// Visual language: im0001gt.hw-tooltip (Style.font.*, Style.space(14), dim captions).
BarWidget {
  id: root

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(root.fg, 1.4)
  readonly property color gaugeWhite: root.fg
  readonly property color gaugeGreen: Color.accent
  readonly property color gaugeYellow: "#E8BB59"
  readonly property color gaugeOrange: "#E5A77E"
  // Hotter than theme urgent so over-limit reads from across the desk.
  readonly property color gaugeRed: "#FF4D4D"
  readonly property color gaugeIdle: Util.alpha(root.fg, 0.35)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property int panelWidth: Style.space(420)
  // Room for 3 providers + secondaries + KPI footer + hint.
  readonly property int panelMaxHeight: Style.space(720)

  property bool popupOpen: false
  property double nowMs: Date.now()

  readonly property var providers: usage.providers
  // Alarm when any primary tank is nearly empty (<10% remaining).
  readonly property bool alarming: {
    for (var i = 0; i < providers.length; i++) {
      var head = root.agentHeadline(providers[i])
      if (head && root.remainingOf(head.percent) < 0.10) return true
    }
    return false
  }

  // Shared strip: Today / 7d / Avg/d + sparkline. Sums tracked providers only.
  // recentDays[].messageCount is daily tokens. Missing provider-day is skipped
  // (no invented zeros). Avg/d is always weekTotal / 7.
  // Avoid Object.keys — some QuickJS builds have been flaky with it in bindings.
  readonly property var stripKpis: {
    var list = root.providers
    var today = 0
    var dates = []
    var totals = []
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p) continue
      today += Number(p.todayTotalTokens) || 0
      var days = p.recentDays || []
      for (var j = 0; j < days.length; j++) {
        var day = days[j]
        if (!day || !day.date) continue
        var date = String(day.date)
        var tokens = Number(day.messageCount)
        if (!isFinite(tokens) || tokens < 0) continue
        var idx = dates.indexOf(date)
        if (idx < 0) {
          dates.push(date)
          totals.push(tokens)
        } else {
          totals[idx] += tokens
        }
      }
    }
    // Sort by date ascending, keep last ≤7.
    for (var a = 0; a < dates.length; a++) {
      for (var b = a + 1; b < dates.length; b++) {
        if (dates[b] < dates[a]) {
          var td = dates[a]; dates[a] = dates[b]; dates[b] = td
          var tt = totals[a]; totals[a] = totals[b]; totals[b] = tt
        }
      }
    }
    if (dates.length > 7) {
      dates = dates.slice(dates.length - 7)
      totals = totals.slice(totals.length - 7)
    }
    var week = 0
    for (var k = 0; k < totals.length; k++) week += totals[k]
    return {
      today: today,
      week: week,
      avg: week / 7,
      series: totals
    }
  }

  function formatDuration(ms) {
    if (!(ms > 0)) return "now"
    var minutes = Math.floor(ms / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return days + "d " + (hours % 24) + "h"
    if (hours > 0) return hours + "h " + (minutes % 60) + "m"
    return Math.max(1, minutes) + "m"
  }

  function formatTokens(n) {
    return usage.formatTokenCount(n)
  }

  function currencyPrefix(currency) {
    var code = String(currency || "USD").toUpperCase()
    if (code === "USD") return "$"
    if (code === "EUR") return "€"
    if (code === "GBP") return "£"
    return code + " "
  }

  function formatMoney(value, currency) {
    var amount = Number(value)
    if (!isFinite(amount)) amount = 0
    return currencyPrefix(currency) + amount.toFixed(amount >= 100 ? 0 : 2)
  }

  function moneyLine(p) {
    var b = p && p.balance
    if (!b || !(b.funded > 0)) return ""
    var text = formatMoney(b.spent, b.currency) + " spent · "
      + formatMoney(b.funded, b.currency) + " funded · "
      + formatMoney(b.remaining, b.currency) + " left"
    if (b.estimated) text += " · est."
    return text
  }

  // Keep each provider's own limit names — no forced shared vocabulary.
  function windowTitle(label) {
    var plain = String(label || "").trim()
    return plain === "" ? "Limit" : plain
  }

  function limitPercent(limit) {
    var p = Number(limit && limit.percent)
    if (!isFinite(p)) return 0
    if (p > 1.0001) return Math.max(0, Math.min(1, p / 100))
    return Math.max(0, Math.min(1, p))
  }

  // Fuel-tank remaining from a used fraction (0–1+). Over-limit → 0 left.
  function remainingOf(usedFrac) {
    var u = Number(usedFrac)
    if (!isFinite(u)) return 0
    return Math.max(0, 1 - u)
  }

  // Hottest usage limit only — balance never drives the dial.
  // Returns { label, percent, resetsAt, index } or null.
  // `percent` is still used (for hottest pick); display uses remainingOf().
  function agentHeadline(p) {
    var best = null
    var limits = p.limits || []
    for (var i = 0; i < limits.length; i++) {
      var lim = limits[i]
      if (!lim) continue
      var raw = Number(lim.percent)
      if (!isFinite(raw)) continue
      var pct = limitPercent(lim)
      var resetsAt = String(lim.resetsAt || "")
      var resetMs = resetsAt ? Date.parse(resetsAt) : NaN
      var candidate = {
        label: windowTitle(lim.title || lim.label),
        percent: pct,
        resetsAt: isFinite(resetMs) ? resetsAt : "",
        resetMs: isFinite(resetMs) ? resetMs : Number.POSITIVE_INFINITY,
        index: i
      }
      if (!best) {
        best = candidate
        continue
      }
      if (candidate.percent > best.percent + 0.0001) {
        best = candidate
        continue
      }
      if (Math.abs(candidate.percent - best.percent) <= 0.0001) {
        if (candidate.resetMs < best.resetMs) best = candidate
      }
    }
    return best
  }

  // Solid band only (no rainbow). Colors follow remaining (fuel left):
  // ≤0 empty red · ≤10 red · ≤25 orange · ≤50 yellow · ≤75 white · >75 green
  function gaugeColor(remainingPct) {
    var n = Number(remainingPct)
    if (!isFinite(n)) n = 0
    if (n <= 0) return root.gaugeRed
    if (n <= 10) return root.gaugeRed
    if (n <= 25) return root.gaugeOrange
    if (n <= 50) return root.gaugeYellow
    if (n <= 75) return root.gaugeWhite
    return root.gaugeGreen
  }

  function gaugeColorCss(remainingPct) {
    var c = gaugeColor(remainingPct)
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
      + Math.round(c.b * 255) + ",1)"
  }

  function rgbaCss(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
      + Math.round(c.b * 255) + "," + a + ")"
  }

  function open() { root.popupOpen = true }
  function close() { root.popupOpen = false }

  readonly property bool desktopEmbedded: {
    var p = panel.parent
    while (p) {
      if (p === popup) return false
      p = p.parent
    }
    return panel.parent !== null
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Usage {
    id: usage
    settings: root.settings || ({})
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰓅"
    foreground: root.alarming ? root.gaugeRed : Color.bar.text
    iconComponent: Component {
      Text {
        text: "󰓅"
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
    onPressed: function (b) {
      if (b === Qt.RightButton) {
        usage.refreshAll(true)
      } else if (b === Qt.MiddleButton) {
        if (root.bar) root.bar.run("omarchy-start-in-vault omarchy-agent --pick")
      } else {
        root.popupOpen = !root.popupOpen
      }
    }
  }

  Timer {
    interval: 1000
    running: root.popupOpen || root.desktopEmbedded
    repeat: true
    triggeredOnStart: true
    onTriggered: root.nowMs = Date.now()
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    triggerMode: "click"
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(root.panelWidth)
    contentHeight: popup.fittedContentHeight(Math.min(panel.implicitHeight, root.panelMaxHeight))

    Flickable {
      id: flick
      width: parent.width
      height: parent.height
      contentWidth: width
      contentHeight: panel.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height + 1

      Column {
        id: panel
        width: flick.width
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            text: "󰓅"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "TOKENS"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              width: parent.width
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              text: root.providers.length === 0
                ? "No agents yet"
                : root.providers.length + " provider" + (root.providers.length === 1 ? "" : "s")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: Style.font.caption * 0.12
              width: parent.width
              elide: Text.ElideRight
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        Column {
          width: parent.width
          spacing: Style.space(14)
          visible: root.providers.length > 0

          Repeater {
            model: root.providers

            AgentRow {
              required property var modelData
              width: panel.width
              provider: modelData
            }
          }
        }

        Text {
          visible: root.providers.length === 0
          width: parent.width
          textFormat: Text.PlainText
          text: "No agent usage yet — run Claude, Codex, or Cursor."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator {
          foreground: root.fg
          visible: root.providers.length > 0
        }

        // Shared bottom KPIs — Today / 7d / Avg/d + 7d sparkline (no Cursor $).
        // Explicit height so a binding blip cannot collapse the strip to 0.
        Item {
          id: kpiStrip
          width: parent.width
          visible: root.providers.length > 0
          implicitHeight: Style.space(40)
          height: implicitHeight
          readonly property int sparkW: Style.space(72)
          readonly property int gap: Style.space(10)
          readonly property int cellW: Math.max(
            Style.space(56),
            Math.floor((width - sparkW - gap * 3) / 3)
          )

          Row {
            anchors.fill: parent
            spacing: kpiStrip.gap

            Column {
              width: kpiStrip.cellW
              spacing: Style.space(2)
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.formatTokens(root.stripKpis.today)
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "Today"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Column {
              width: kpiStrip.cellW
              spacing: Style.space(2)
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.formatTokens(root.stripKpis.week)
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "7d"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Column {
              width: kpiStrip.cellW
              spacing: Style.space(2)
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.formatTokens(root.stripKpis.avg)
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "Avg/d"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Column {
              width: kpiStrip.sparkW
              spacing: Style.space(2)

              Sparkline {
                width: parent.width
                height: Style.space(22)
                values: root.stripKpis.series
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "7d"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "right-click refresh"
          color: Util.alpha(root.fg, 0.35)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }

  // JustGage-inspired fuel dial (Bojan Djuricic / shot 2185155 language):
  // filled annular 180° band, outer ticks, tip needle across the track,
  // center value, E/F under the band ends.
  component ProviderGauge: Item {
    id: gauge
    // Remaining percent 0–100 (fuel left). Callers convert from used.
    property int percent: 0
    property bool hasValue: true
    property real displayPercent: 0
    property color valueColor: root.gaugeColor(displayPercent)
    width: Style.space(86)
    height: Style.space(62)

    Behavior on displayPercent {
      enabled: gauge.hasValue
      NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
    }

    // Never animate toward 0 when limits blip empty — freeze the last reading.
    onPercentChanged: {
      if (!gauge.hasValue) return
      displayPercent = Math.max(0, Math.min(100, percent))
    }
    onHasValueChanged: {
      if (gauge.hasValue)
        displayPercent = Math.max(0, Math.min(100, percent))
    }
    Component.onCompleted: {
      if (gauge.hasValue)
        displayPercent = Math.max(0, Math.min(100, percent))
    }

    Canvas {
      id: canvas
      anchors.fill: parent
      // Leave room under the band for E/F; value Text sits in the hollow.
      anchors.bottomMargin: Style.space(10)
      antialiasing: true
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var cx = width * 0.5
        var cy = height * 0.98
        // JustGage gaugeWidthScale≈1 → band ≈ widgetW/6.67; keep it chunky.
        var band = Math.max(9, Math.min(width, height) * 0.20)
        var ro = Math.min(width * 0.48, height * 0.92)
        var ri = Math.max(ro - band, ro * 0.42)
        var start = Math.PI
        var sweep = Math.PI
        var show = gauge.hasValue || gauge.displayPercent > 0.5
        var pct = show ? Math.max(0, Math.min(100, gauge.displayPercent)) / 100 : 0
        var solid = root.gaugeColorCss(gauge.displayPercent)
        // Stronger track contrast than a faint stroke (JustGage #edebeb feel).
        var track = root.rgbaCss(root.fg, 0.22)
        var tickDim = root.rgbaCss(root.fg, 0.30)
        var tickMaj = root.rgbaCss(root.fg, 0.55)

        function annular(a0, a1, fill) {
          if (a1 - a0 < 0.001) return
          ctx.beginPath()
          ctx.arc(cx, cy, ro, a0, a1, false)
          ctx.arc(cx, cy, ri, a1, a0, true)
          ctx.closePath()
          ctx.fillStyle = fill
          ctx.fill()
        }

        // Soft outer ticks (shot 2185155 language; major every 25%).
        var ticks = 20
        for (var t = 0; t <= ticks; t++) {
          var ang = start + sweep * (t / ticks)
          var major = (t % 5 === 0)
          var outer = ro + band * (major ? 0.42 : 0.28)
          var inner = ro + band * 0.06
          ctx.beginPath()
          ctx.strokeStyle = major ? tickMaj : tickDim
          ctx.lineWidth = major ? 1.5 : 1.0
          ctx.lineCap = "butt"
          ctx.moveTo(cx + Math.cos(ang) * inner, cy + Math.sin(ang) * inner)
          ctx.lineTo(cx + Math.cos(ang) * outer, cy + Math.sin(ang) * outer)
          ctx.stroke()
        }

        // Filled annular track + remaining level (radial ends, not round caps).
        annular(start, start + sweep, track)
        if (show && pct > 0.002)
          annular(start, start + sweep * pct, solid)

        // JustGage ndl-style tip: needle crosses the band (tip outside, base inside).
        if (show) {
          var nang = start + sweep * pct
          var dlt = Math.max(3, width * 0.035)
          var dlb = Math.max(4, width * 0.07)
          var dw = Math.max(1.6, width * 0.012)
          var tipR = ro + dlt
          var backR = ri - dlb
          var cosA = Math.cos(nang)
          var sinA = Math.sin(nang)
          var tx = cx + cosA * tipR
          var ty = cy + sinA * tipR
          var bx = cx + cosA * backR
          var by = cy + sinA * backR
          var px = -sinA * dw
          var py = cosA * dw
          ctx.beginPath()
          ctx.fillStyle = root.rgbaCss(root.fg, 0.92)
          ctx.moveTo(tx, ty)
          ctx.lineTo(bx + px, by + py)
          ctx.lineTo(bx - px, by - py)
          ctx.closePath()
          ctx.fill()
        }
      }
      Connections {
        target: gauge
        function onDisplayPercentChanged() { canvas.requestPaint() }
        function onHasValueChanged() { canvas.requestPaint() }
      }
      Connections {
        target: root
        function onFgChanged() { canvas.requestPaint() }
      }
    }

    // Center value — JustGage places the reading in the hollow of the arc.
    Text {
      id: centerValue
      anchors.horizontalCenter: parent.horizontalCenter
      // Sit in the open bowl above E/F, not on the band baseline.
      y: Math.round(parent.height * 0.40)
      textFormat: Text.PlainText
      text: gauge.hasValue ? Math.round(gauge.displayPercent) + "%" : "—"
      color: gauge.hasValue ? gauge.valueColor : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }

    // Fuel endcaps under the band midpoints (JustGage min/max placement).
    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.bottom: parent.bottom
      textFormat: Text.PlainText
      text: "E"
      color: Util.alpha(root.fg, 0.45)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.bottom: parent.bottom
      textFormat: Text.PlainText
      text: "F"
      color: Util.alpha(root.fg, 0.45)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  component AgentRow: Column {
    id: row
    property var provider: ({})

    readonly property var head: root.agentHeadline(provider)
    readonly property bool hasLimit: !!head
    // Fuel left 0–100. Hottest pick still ranks by used (head.percent).
    readonly property real usedFrac: head ? Number(head.percent) : 0
    readonly property int pct: hasLimit
      ? Math.round(root.remainingOf(row.usedFrac) * 100)
      : -1
    readonly property string resetText: head && head.resetsAt
      ? "↻ " + root.formatDuration(Date.parse(head.resetsAt) - root.nowMs)
      : ""
    readonly property string tierText: provider.tierLabel ? String(provider.tierLabel) : ""
    readonly property string todayText: root.formatTokens(provider.todayTotalTokens || 0) + " tokens today"
    readonly property string moneyText: root.moneyLine(provider)
    readonly property color rowColor: hasLimit ? root.gaugeColor(pct) : root.dim
    readonly property string metaText: {
      var bits = []
      if (row.tierText) bits.push(row.tierText)
      if (head) bits.push(head.label)
      bits.push(row.todayText)
      return bits.join(" · ")
    }
    readonly property var secondaryLimits: {
      var out = []
      var limits = provider.limits || []
      var primaryIndex = head ? head.index : -1
      for (var i = 0; i < limits.length; i++) {
        if (i === primaryIndex) continue
        var lim = limits[i]
        if (!lim) continue
        var raw = Number(lim.percent)
        if (!isFinite(raw)) continue
        var resetsAt = String(lim.resetsAt || "")
        var resetMs = resetsAt ? Date.parse(resetsAt) : NaN
        var used = root.limitPercent(lim)
        var left = Math.round(root.remainingOf(used) * 100)
        out.push({
          label: root.windowTitle(lim.title || lim.label),
          percent: left,
          resetsAt: isFinite(resetMs) ? resetsAt : ""
        })
      }
      return out
    }
    readonly property string missingLimitsText: (!hasLimit && (provider.usageStatusText || "Limits unavailable"))
      ? String(provider.usageStatusText || "Limits unavailable")
      : ""

    width: parent ? parent.width : 0
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(dial.height, rowTitle.implicitHeight, rowValue.implicitHeight)

      ProviderGauge {
        id: dial
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // Remaining only — never pass used into the dial.
        percent: row.hasLimit ? Math.max(0, Math.min(100, row.pct)) : dial.displayPercent
        hasValue: row.hasLimit
      }

      Column {
        id: rowTitle
        anchors.left: dial.right
        anchors.leftMargin: Style.space(10)
        anchors.right: rowValue.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          text: provider.providerName || provider.providerId || "Agent"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          width: parent.width
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          text: row.metaText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          width: parent.width
          elide: Text.ElideRight
        }
      }

      // Right column: remaining % + reset. Dial hollow also shows remaining.
      Column {
        id: rowValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          visible: row.hasLimit
          text: row.pct + "% left"
          color: row.rowColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          horizontalAlignment: Text.AlignRight
          anchors.right: parent.right
        }

        Text {
          textFormat: Text.PlainText
          visible: row.hasLimit && row.resetText !== ""
          text: row.resetText
          color: row.rowColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          horizontalAlignment: Text.AlignRight
          anchors.right: parent.right
        }
      }
    }

    Column {
      width: parent.width
      spacing: Style.space(4)
      leftPadding: Style.space(96)
      visible: row.secondaryLimits.length > 0 || row.moneyText !== "" || (!row.hasLimit)

      Text {
        visible: !row.hasLimit
        width: parent.width - Style.space(96)
        textFormat: Text.PlainText
        text: row.missingLimitsText || "Limits unavailable"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Repeater {
        model: row.secondaryLimits

        Row {
          required property var modelData
          width: parent.width - Style.space(96)
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            text: modelData.label
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            width: Style.space(72)
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
          }

          Meter {
            width: Math.max(Style.space(40), parent.width - Style.space(72) - Style.space(110))
            implicitHeight: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            percent: modelData.percent
            fillColor: root.gaugeColor(modelData.percent)
          }

          Text {
            textFormat: Text.PlainText
            text: modelData.percent + "% left"
              + (modelData.resetsAt
                ? " · ↻ " + root.formatDuration(Date.parse(modelData.resetsAt) - root.nowMs)
                : "")
            color: root.gaugeColor(modelData.percent)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
            width: Style.space(110)
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      Text {
        visible: row.moneyText !== ""
        width: parent.width - Style.space(96)
        textFormat: Text.PlainText
        text: row.moneyText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  component Meter: Item {
    property int percent: 0
    property color fillColor: root.gaugeColor(percent)

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: Util.alpha(root.fg, 0.12)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      radius: height / 2
      color: fillColor
      width: Math.max(parent.height, parent.width * Math.max(0, Math.min(100, percent)) / 100)
      Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // Compact KPI cell: bold value over dim caption.
  component StripKpi: Column {
    property string valueText: "0"
    property string caption: ""
    spacing: Style.space(2)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: valueText
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: caption
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  // Tiny 7d token sparkline — single stroke + soft fill, no chart library.
  component Sparkline: Canvas {
    id: spark
    property var values: []
    antialiasing: true

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
      target: root
      function onFgChanged() { spark.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var vals = spark.values || []
      var n = vals.length
      if (n === 0 || width < 2 || height < 2) return

      var padX = 1
      var padY = 2
      var w = width - padX * 2
      var h = height - padY * 2
      var max = 0
      for (var i = 0; i < n; i++) {
        var v = Number(vals[i])
        if (isFinite(v) && v > max) max = v
      }
      if (max <= 0) max = 1

      var step = n > 1 ? w / (n - 1) : 0
      var points = []
      for (var j = 0; j < n; j++) {
        var raw = Number(vals[j])
        if (!isFinite(raw) || raw < 0) raw = 0
        var x = padX + (n > 1 ? j * step : w * 0.5)
        var y = padY + h - (raw / max) * h
        points.push({ x: x, y: y })
      }

      var stroke = root.rgbaCss(root.gaugeGreen, 0.95)
      var fill = root.rgbaCss(root.gaugeGreen, 0.16)

      ctx.beginPath()
      ctx.moveTo(points[0].x, padY + h)
      for (var a = 0; a < points.length; a++)
        ctx.lineTo(points[a].x, points[a].y)
      ctx.lineTo(points[points.length - 1].x, padY + h)
      ctx.closePath()
      ctx.fillStyle = fill
      ctx.fill()

      ctx.beginPath()
      ctx.strokeStyle = stroke
      ctx.lineWidth = 1.5
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.moveTo(points[0].x, points[0].y)
      for (var b = 1; b < points.length; b++)
        ctx.lineTo(points[b].x, points[b].y)
      ctx.stroke()
    }
  }

  component PanelSeparator: Rectangle {
    property color foreground: Color.foreground
    width: parent ? parent.width : 0
    height: 1
    color: Util.alpha(foreground, 0.12)
  }
}

# Forex Dynamic EA - MQL5 Expert Advisor

This Expert Advisor (EA) connects to your Forex Dynamic app server and automatically executes trades based on signals received.

## Features

- ✅ **HTTP Polling**: Automatically fetches signals from Render server
- ✅ **Scheduled Execution**: Executes trades at exact specified timestamps (London time)
- ✅ **TP Condition Logic**: Uses 1-minute candles to determine Normal TP vs New TP
- ✅ **Daily Re-Entry System**: Automatically places daily trades (no SL, only Daily TP)
- ✅ **Independent Trade Management**: Each signal is managed independently
- ✅ **Error Alerts**: Alerts user on errors

## Installation

1. **Copy the EA file**:
   - Copy `ForexDynamicEA.mq5` to your MetaTrader 5 `MQL5/Experts/` directory
   - Example: `C:\Users\YourName\AppData\Roaming\MetaTrader 5\MQL5\Experts\ForexDynamicEA.mq5`

2. **Enable WebRequest**:
   - Open MetaTrader 5
   - Go to `Tools` → `Options` → `Expert Advisors`
   - Check `Allow WebRequest for listed URL`
   - Add: `https://forex-dynamic.onrender.com`
   - Click `OK`

3. **Compile the EA**:
   - Open MetaEditor (F4 in MT5)
   - Open `ForexDynamicEA.mq5`
   - Click `Compile` (F7)
   - Fix any errors if they appear

4. **Attach to Chart**:
   - Open any chart in MT5
   - Drag `ForexDynamicEA` from Navigator to the chart
   - Configure input parameters (see below)
   - Enable `AutoTrading` button in MT5 toolbar

## Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ServerURL` | `https://forex-dynamic.onrender.com/signals` | Server endpoint to poll for signals |
| `PollIntervalSeconds` | `30` | How often to poll server (seconds) |
| `MagicNumber` | `123456` | Magic number to identify EA trades |
| `EnableAlerts` | `true` | Show alerts on errors/trades |
| `TimeZone` | `GMT+0` | Time zone (London = GMT+0) |

## How It Works

### 1. Signal Reception
- EA polls the server every `PollIntervalSeconds` seconds
- Parses JSON response and extracts trade signals
- Stores signals until execution time

### 2. Trade Execution
- Executes trades at **exact timestamp** specified in signal (London time)
- Ignores spread/slippage - executes at market price
- Sets TP and SL as specified in signal

### 3. TP Condition Logic
- Uses **1-minute candles** to check prices at:
  - Time 1: Previous day at `tpCondition1` (e.g., 22:25)
  - Time 2: Entry day at `tpCondition2` (e.g., 11:00)
- For **SELL**: If Time1 price > Time2 price → use New TP, else Normal TP
- For **BUY**: If Time1 price < Time2 price → use Normal TP, else New TP
- Updates TP automatically after condition time

### 4. Daily Re-Entry System
- Starts **next calendar day** after main trade is placed
- Places one daily trade per day at the same time as main entry
- **No Stop Loss** - only uses Daily TP
- Daily TP is **capped** to not exceed main trade TP level
- Stops immediately if main trade closes

## Signal Format

The EA expects signals in this JSON format (from server):

```json
{
  "tradeId": "unique-id",
  "symbol": "GBPNZD",
  "direction": "SELL",
  "entryTime": "2025-11-20 11:00:00",
  "entryPrice": 0.0,
  "tp": 38,
  "sl": 0,
  "tpCondition1": "22:25",
  "tpCondition2": "11:00",
  "newTP": 18,
  "lot": 0.02,
  "isDaily": true,
  "dailyTP": 18,
  "dailyLot": 0.01,
  "accountName": "Main EA",
  "brand": "MY FOREX TRADE"
}
```

## Multiple Accounts

To use on multiple accounts:
1. Install the EA on each MT5 terminal/account
2. All EAs will poll the same server URL
3. Each EA will execute trades on its own account
4. Use different `MagicNumber` if you want to distinguish accounts

## Troubleshooting

### "WebRequest failed: 4060"
- **Solution**: Add server URL to allowed URLs in MT5 settings (see Installation step 2)

### "Symbol not found"
- **Solution**: Make sure the symbol exists in your broker's symbol list
- Check symbol name matches exactly (e.g., "GBPNZD" vs "GBPNZD.")

### Trades not executing
- Check `AutoTrading` is enabled in MT5
- Check server URL is accessible
- Check signal `entryTime` is in the future (EA executes at exact time)
- Check logs in `Experts` tab

### TP Condition not working
- Ensure 1-minute chart data is available
- Check `tpCondition1` and `tpCondition2` times are correct
- Verify `newTP` value is set in signal

## Notes

- **Time Zone**: EA converts London time (GMT+0) to server time. Ensure your MT5 server time is correct.
- **Pips Calculation**: Handles 3/5 digit brokers automatically
- **Daily Trades**: Only execute if main trade is still open
- **Error Handling**: All errors are logged and alerted (if enabled)

## Support

For issues or questions, check:
- MT5 `Experts` tab for error logs
- Server logs at Render dashboard
- App settings to verify signal format


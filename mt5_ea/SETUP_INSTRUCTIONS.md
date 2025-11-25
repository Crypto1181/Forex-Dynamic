# Forex Dynamic EA - Setup Instructions

## Quick Start Guide

### Step 1: Enable WebRequest in MT5

**CRITICAL**: You must enable WebRequest before the EA can work!

1. Open MetaTrader 5
2. Click `Tools` → `Options`
3. Go to `Expert Advisors` tab
4. Check `Allow WebRequest for listed URL`
5. Click `Add` button
6. Enter: `https://forex-dynamic.onrender.com`
7. Click `OK` to save

**Without this step, the EA will fail with error 4060!**

### Step 2: Install the EA

1. Locate your MT5 data folder:
   - Windows: `C:\Users\YourName\AppData\Roaming\MetaTrader 5\`
   - Or click `File` → `Open Data Folder` in MT5

2. Navigate to `MQL5\Experts\` folder

3. Copy `ForexDynamicEA.mq5` into this folder

4. Restart MT5 (or press F5 in Navigator to refresh)

### Step 3: Compile the EA

1. Press `F4` in MT5 to open MetaEditor
2. In Navigator, find `ForexDynamicEA.mq5` under `Experts`
3. Double-click to open
4. Press `F7` to compile
5. Check `Errors` tab - should show "0 error(s), 0 warning(s)"

### Step 4: Attach to Chart

1. Open any chart in MT5 (e.g., GBPUSD)
2. In Navigator, find `ForexDynamicEA` under `Expert Advisors`
3. Drag and drop onto the chart
4. Configure parameters:
   - `ServerURL`: `https://forex-dynamic.onrender.com/signals`
   - `PollIntervalSeconds`: `30` (or your preference)
   - `MagicNumber`: `123456` (or unique number per account)
   - `EnableAlerts`: `true`
5. Click `OK`

### Step 5: Enable AutoTrading

1. In MT5 toolbar, click `AutoTrading` button (should turn green)
2. EA will start polling server immediately
3. Check `Experts` tab for logs

## Testing

### Test Server Connection

1. Open browser and go to: `https://forex-dynamic.onrender.com/signals`
2. Should see JSON response with signals array
3. If you see this, server is working

### Test EA Connection

1. Attach EA to chart
2. Check `Experts` tab in MT5
3. Should see: "Forex Dynamic EA initialized"
4. Should see: "New signal received: ..." (if signals exist)

### Test Trade Execution

1. Create a test signal in your app with entry time 1-2 minutes in the future
2. Wait for EA to poll (check `Experts` tab)
3. At execution time, EA should place trade
4. Check `Trade` tab to see executed trade

## Configuration Tips

### For Multiple Accounts

- Use different `MagicNumber` for each account (e.g., 123456, 123457, 123458)
- This helps identify which EA placed which trade

### Poll Interval

- `30 seconds`: Good balance (not too frequent, not too slow)
- `10 seconds`: More responsive but more server requests
- `60 seconds`: Less server load but slower signal detection

### Time Zone

- EA assumes server time matches London time (GMT+0)
- If your broker uses different timezone, adjust `entryTime` conversion in code
- Check your broker's server time in MT5: `View` → `Market Watch` → Right-click → `Server Time`

## Common Issues

### Issue: "WebRequest failed: 4060"
**Solution**: You didn't add the URL to allowed list. Go back to Step 1.

### Issue: "Symbol not found"
**Solution**: 
- Check symbol name in signal matches broker's symbol exactly
- Some brokers use "." instead of no separator (e.g., "GBPNZD." vs "GBPNZD")
- Check `Market Watch` to see available symbols

### Issue: EA not executing trades
**Checklist**:
- ✅ `AutoTrading` button is green?
- ✅ Signal `entryTime` is in the future?
- ✅ Server is accessible?
- ✅ Symbol exists in broker?
- ✅ Account has enough margin?

### Issue: TP Condition not working
**Solution**:
- Ensure 1-minute chart data is downloaded
- Right-click chart → `Charts` → `1 Minute` to ensure data exists
- Check `tpCondition1` and `tpCondition2` times are correct format (HH:MM)

## Monitoring

### Check EA Status

1. `Experts` tab: Shows EA logs and errors
2. `Trade` tab: Shows executed trades
3. `Journal` tab: Shows system messages

### Check Signal Reception

Look for these messages in `Experts` tab:
- "Forex Dynamic EA initialized" - EA started
- "New signal received: GBPNZD SELL at 2025.11.20 11:00" - Signal received
- "Trade executed: GBPNZD SELL Ticket: 12345678" - Trade placed

### Check Errors

All errors are logged with "ERROR:" prefix:
- "ERROR: WebRequest failed: ..." - Connection issue
- "ERROR: Symbol GBPNZD not found" - Symbol issue
- "ERROR: Trade execution failed: ..." - Trade issue

## Next Steps

1. ✅ EA installed and running
2. ✅ Server connection working
3. ✅ Test signal executed successfully
4. ✅ Ready for live trading!

## Support

If you encounter issues:
1. Check `Experts` tab for error messages
2. Verify server URL is accessible in browser
3. Check MT5 `Journal` tab for system errors
4. Verify all setup steps were completed


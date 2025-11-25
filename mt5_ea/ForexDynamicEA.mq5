//+------------------------------------------------------------------+
//|                                          ForexDynamicEA.mq5      |
//|                        Forex Dynamic Trade Signal EA             |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Forex Dynamic"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Input parameters
input string ServerURL = "https://forex-dynamic.onrender.com/signals";  // Server URL
input int    PollIntervalSeconds = 10;                                  // Poll interval (seconds) - reduced for faster signal pickup
input int    MagicNumber = 123456;                                      // Magic number for trades
input bool   EnableAlerts = true;                                        // Enable alerts
input string SignalTimeZone = "GMT+0";                                  // Timezone of entryTime from server (e.g., "GMT+0" for UK/London, "GMT+3" for GMT+3)
input bool   ExecuteImmediatelyOnReceipt = false;                       // Execute as soon as signal is received (ignore entryTime)
input int    ImmediateExecutionWindowSeconds = 300;                     // How long after receipt immediate execution is allowed
input int    EntryExecutionToleranceSeconds = 0;                        // Execute this many seconds before/after entryTime (default exact time)

//--- Multi-Account Configuration (up to 3 accounts)
input string Account1Name = "";                                          // Account 1 Name (leave empty to disable)
input string Channel1Name = "";                                          // Channel 1 Name (e.g., "FUNDED TRADING PLUS")
input string Account2Name = "";                                          // Account 2 Name (leave empty to disable)
input string Channel2Name = "";                                          // Channel 2 Name
input string Account3Name = "";                                          // Account 3 Name (leave empty to disable)
input string Channel3Name = "";                                          // Channel 3 Name

//--- Global variables
CTrade trade;
CPositionInfo position;
CAccountInfo account;

struct SignalData
{
   string tradeId;           // Unique trade ID
   string symbol;            // Symbol (e.g., "GBPNZD")
   string direction;         // "BUY" or "SELL"
   datetime entryTime;       // Entry time (London time converted to server time)
   double entryPrice;        // Entry price (0 if not specified)
   double tp;                // Take Profit in pips
   double sl;                // Stop Loss in pips
   string tpCondition1;       // TP Condition Time 1 (HH:MM)
   string tpCondition2;       // TP Condition Time 2 (HH:MM)
   double newTP;             // New TP value in pips
   double lot;               // Lot size
   bool isDaily;             // Daily re-entry enabled
   double dailyTP;           // Daily TP in pips
   double dailyLot;          // Daily lot size
   string accountName;        // Account name
   string brand;             // Brand identifier
   datetime receivedAt;      // When signal was received
   datetime firstSeenAt;     // When EA first fetched the signal
   bool isExecuted;          // Has main trade been executed
   ulong mainTicket;         // Main trade ticket
   datetime lastDailyDate;   // Last daily trade date
   bool dailyActive;         // Is daily re-entry active
   bool symbolNotFound;      // Flag to mark if symbol is not available
};

SignalData signals[];
datetime lastPollTime = 0;
string lastError = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   ArrayResize(signals, 0);
   lastPollTime = 0;
   
   // Sync with existing positions to prevent re-execution
   SyncWithExistingPositions();
   
   // Get current account name for logging
   string currentAccountName = account.Name();
   Print("========================================");
   Print("Forex Dynamic EA initialized");
   Print("========================================");
   Print("Current MT5 Account: ", currentAccountName);
   Print("Server URL: ", ServerURL);
   Print("Poll interval: ", PollIntervalSeconds, " seconds");
   Print("Signal Timezone: ", SignalTimeZone, " (entryTime from server is in this timezone)");
   
   // CRITICAL: Check if AutoTrading is enabled
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      string error = "WARNING: AutoTrading is DISABLED in MT5! Enable it in Tools->Options->Expert Advisors->Allow automated trading";
      Print("WARNING: ", error);
      Print("EA will continue but trades will NOT execute until AutoTrading is enabled");
      if(EnableAlerts) Alert("EA Warning: ", error);
      // Don't fail initialization - allow EA to run and check again at execution time
   }
   else
   {
      Print("✓ AutoTrading: ENABLED");
   }
   
   // Check if trading is allowed on this account
   if(!account.TradeAllowed())
   {
      string error = "WARNING: Trading is NOT ALLOWED on this account!";
      Print("WARNING: ", error);
      Print("EA will continue but trades will NOT execute until trading is allowed");
      if(EnableAlerts) Alert("EA Warning: ", error);
      // Don't fail initialization - allow EA to run and check again at execution time
   }
   else
   {
      Print("✓ Trading: ALLOWED");
   }
   
   // Check account balance
   double balance = account.Balance();
   double equity = account.Equity();
   Print("Account Balance: ", balance, " | Equity: ", equity);
   
   // Check if account is demo
   if(account.TradeMode() == ACCOUNT_TRADE_MODE_DEMO)
      Print("Account Type: DEMO");
   else
      Print("Account Type: REAL");
   
   // Display MT5 server timezone info
   MqlDateTime serverDt;
   TimeToStruct(TimeCurrent(), serverDt);
   datetime serverGMT = TimeGMT();
   int serverOffsetHours = (int)((TimeCurrent() - serverGMT) / 3600);
   Print("MT5 Server Timezone: GMT", (serverOffsetHours >= 0 ? "+" : ""), serverOffsetHours);
   Print("Current MT5 Server Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current GMT Time: ", TimeToString(serverGMT, TIME_DATE|TIME_MINUTES));
   Print("--- Signal Matching: EA will process signals where signal's accountName and brand match configured values ---");
   
   // Display configured accounts
   int accountCount = 0;
   if(Account1Name != "" && Channel1Name != "")
   {
      Print("Configured Account 1: Signal Account='", Account1Name, "' | Signal Channel='", Channel1Name, "'");
      accountCount++;
   }
   if(Account2Name != "" && Channel2Name != "")
   {
      Print("Configured Account 2: Signal Account='", Account2Name, "' | Signal Channel='", Channel2Name, "'");
      accountCount++;
   }
   if(Account3Name != "" && Channel3Name != "")
   {
      Print("Configured Account 3: Signal Account='", Account3Name, "' | Signal Channel='", Channel3Name, "'");
      accountCount++;
   }
   
   if(accountCount == 0)
   {
      string error = "⚠️⚠️⚠️ CRITICAL: No accounts configured! ⚠️⚠️⚠️";
      Print("========================================");
      Print("ERROR: ", error);
      Print("You MUST configure at least one account:");
      Print("  - Account 1 Name: (e.g., 'My Forex Trade')");
      Print("  - Channel 1 Name: (e.g., 'MY FOREX TRADE')");
      Print("Without this, NO signals will be processed!");
      Print("========================================");
      if(EnableAlerts) Alert("EA Error: ", error);
   }
   else
   {
      Print("✓ Account configuration: ", accountCount, " account(s) configured");
   }
   
   Print("========================================");
   
   if(EnableAlerts)
      Alert("Forex Dynamic EA started");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Forex Dynamic EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentTime = TimeCurrent();
   
   // Poll for new signals
   if(currentTime - lastPollTime >= PollIntervalSeconds)
   {
      Print("========================================");
      Print("=== POLLING FOR SIGNALS ===");
      Print("Current Time: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      Print("Signals in queue BEFORE poll: ", ArraySize(signals));
      PollSignals();
      lastPollTime = currentTime;
      Print("Signals in queue AFTER poll: ", ArraySize(signals));
      
      // Clean up old signals periodically (every poll)
      CleanupOldSignals();
      
      // Debug: Print all signals status
      PrintSignalStatus();
      Print("========================================");
      
      // After polling, immediately check for trades that should execute
      // This ensures new signals are processed right away
      CheckScheduledTrades();
   }
   
   // Check for scheduled trades (run every tick)
   CheckScheduledTrades();
   
   // Check for daily re-entries
   CheckDailyReEntries();
   
   // Check TP conditions for pending trades
   CheckTPConditions();
}

//+------------------------------------------------------------------+
//| Poll server for new signals                                      |
//+------------------------------------------------------------------+
void PollSignals()
{
   datetime pollTime = TimeCurrent();
   Print("========================================");
   Print("=== POLLING SERVER FOR SIGNALS ===");
   Print("Server URL: ", ServerURL);
   Print("Poll Time (MT5 Server): ", TimeToString(pollTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   Print("Poll Time (GMT): ", TimeToString(TimeGMT(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   Print("Poll Time (Local PC): ", TimeToString(TimeLocal(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   
   char data[];
   char result[];
   string headers;
   
   int timeout = 5000; // 5 seconds
   
   ResetLastError();
   
   int res = WebRequest("GET", ServerURL, "", timeout, data, result, headers);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060)
      {
         lastError = "WebRequest: Add 'https://forex-dynamic.onrender.com' to allowed URLs in Tools->Options->Expert Advisors";
         Print("ERROR: ", lastError);
         if(EnableAlerts) Alert("EA Error: ", lastError);
         return;
      }
      lastError = "WebRequest failed: " + IntegerToString(error);
      Print("ERROR: ", lastError);
      return;
   }
   
   // Parse JSON response
   string jsonResponse = CharArrayToString(result);
   Print("Server response received, length: ", StringLen(jsonResponse));
   if(StringLen(jsonResponse) > 0)
   {
      Print("First 300 chars: ", StringSubstr(jsonResponse, 0, 300));
   }
   ParseSignalsJSON(jsonResponse);
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Parse JSON response and extract signals                          |
//+------------------------------------------------------------------+
void ParseSignalsJSON(string json)
{
   Print("Parsing JSON response...");
   
   // Check if response says "No signals available"
   if(StringFind(json, "No signals available") >= 0 || StringFind(json, "\"signals\":[]") >= 0)
   {
      Print("Server response: No signals available at this time");
      Print("This is normal if you haven't sent any signals yet");
      Print("Make sure you:");
      Print("  1. Created a signal in the app");
      Print("  2. Selected the correct account/channel");
      Print("  3. Sent the signal");
      return;
   }
   
   // Find signals array
   int signalsStart = StringFind(json, "\"signals\":[");
   if(signalsStart == -1)
   {
      Print("WARNING: No signals array found in response");
      Print("Full response: ", json);
      Print("Looking for 'signals' key...");
      if(StringFind(json, "signals") >= 0)
         Print("Found 'signals' but not in expected format");
      return;
   }
   
   Print("Found signals array at position: ", signalsStart);
   
   signalsStart = StringFind(json, "[", signalsStart);
   if(signalsStart == -1) 
   {
      Print("ERROR: Could not find opening bracket");
      return;
   }
   
   int signalsEnd = StringFind(json, "]", signalsStart);
   if(signalsEnd == -1) 
   {
      Print("ERROR: Could not find closing bracket");
      return;
   }
   
   string signalsArray = StringSubstr(json, signalsStart + 1, signalsEnd - signalsStart - 1);
   Print("Signals array extracted, length: ", StringLen(signalsArray));
   
   // Parse each signal
   int signalCount = 0;
   int pos = 0;
   while(pos < StringLen(signalsArray))
   {
      int signalStart = StringFind(signalsArray, "{", pos);
      if(signalStart == -1) break;
      
      int signalEnd = FindMatchingBrace(signalsArray, signalStart);
      if(signalEnd == -1) break;
      
      string signalJson = StringSubstr(signalsArray, signalStart, signalEnd - signalStart + 1);
      Print("Parsing signal ", signalCount + 1, ": ", StringSubstr(signalJson, 0, 100), "...");
      ParseSignal(signalJson);
      signalCount++;
      
      pos = signalEnd + 1;
   }
   
   Print("Parsed ", signalCount, " signal(s) from server");
}

//+------------------------------------------------------------------+
//| Find matching closing brace                                     |
//+------------------------------------------------------------------+
int FindMatchingBrace(string str, int startPos)
{
   int depth = 0;
   for(int i = startPos; i < StringLen(str); i++)
   {
      if(StringGetCharacter(str, i) == '{') depth++;
      if(StringGetCharacter(str, i) == '}') 
      {
         depth--;
         if(depth == 0) return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Parse individual signal                                          |
//+------------------------------------------------------------------+
void ParseSignal(string signalJson)
{
   SignalData signal;
   ZeroMemory(signal);
   
   // Extract fields using string functions
   signal.tradeId = ExtractJSONValue(signalJson, "tradeId");
   signal.symbol = ExtractJSONValue(signalJson, "symbol");
   signal.direction = ExtractJSONValue(signalJson, "direction");
   
   string entryTimeStr = ExtractJSONValue(signalJson, "entryTime");
   Print("DEBUG: Raw entryTime from JSON: '", entryTimeStr, "'");
   Print("DEBUG: Signal Timezone setting: ", SignalTimeZone);
   signal.entryTime = ParseDateTime(entryTimeStr);
   datetime currentTime = TimeCurrent();
   long timeDiff = (long)(signal.entryTime - currentTime);
   Print("DEBUG: Parsed entryTime (MT5 Server): ", TimeToString(signal.entryTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   Print("DEBUG: Current MT5 Server Time: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   Print("DEBUG: Time difference: ", timeDiff, " seconds (", timeDiff/60, " minutes)");
   if(timeDiff > 0)
      Print("DEBUG: Entry time is ", timeDiff, "s (", timeDiff/60, " minutes) in the FUTURE");
   else if(timeDiff < 0)
      Print("DEBUG: Entry time is ", -timeDiff, "s (", -timeDiff/60, " minutes) in the PAST");
   else
      Print("DEBUG: Entry time is NOW");
   
   signal.entryPrice = StringToDouble(ExtractJSONValue(signalJson, "entryPrice"));
   signal.tp = StringToDouble(ExtractJSONValue(signalJson, "tp"));
   signal.sl = StringToDouble(ExtractJSONValue(signalJson, "sl"));
   signal.tpCondition1 = ExtractJSONValue(signalJson, "tpCondition1");
   signal.tpCondition2 = ExtractJSONValue(signalJson, "tpCondition2");
   signal.newTP = StringToDouble(ExtractJSONValue(signalJson, "newTP"));
   signal.lot = StringToDouble(ExtractJSONValue(signalJson, "lot"));
   
   string isDailyStr = ExtractJSONValue(signalJson, "isDaily");
   signal.isDaily = (isDailyStr == "true" || isDailyStr == "1");
   
   signal.dailyTP = StringToDouble(ExtractJSONValue(signalJson, "dailyTP"));
   signal.dailyLot = StringToDouble(ExtractJSONValue(signalJson, "dailyLot"));
   signal.accountName = ExtractJSONValue(signalJson, "accountName");
   signal.brand = ExtractJSONValue(signalJson, "brand");
   
   // Also check for channelName field (if brand is empty, use channelName)
   string channelName = ExtractJSONValue(signalJson, "channelName");
   if(signal.brand == "" && channelName != "")
      signal.brand = channelName;
   
   // Parse server's receivedAt for freshness checks
   string receivedAtStr = ExtractJSONValue(signalJson, "receivedAt");
   signal.receivedAt = ParseDateTime(receivedAtStr);
   signal.firstSeenAt = TimeCurrent();  // When EA actually fetched this signal
   Print("DEBUG: Signal receivedAt (server): ", TimeToString(signal.receivedAt, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
         " | EA firstSeenAt (MT5): ", TimeToString(signal.firstSeenAt, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   
   signal.isExecuted = false;
   signal.mainTicket = 0;
   signal.lastDailyDate = 0;
   signal.dailyActive = false;
   signal.symbolNotFound = false;
   
   // Check if signal matches current account and channel
   Print("Checking signal match: Account='", signal.accountName, "' | Brand='", signal.brand, "' | Symbol='", signal.symbol, "'");
   if(!IsSignalForThisAccount(signal))
   {
      // Signal is not for this account, skip it
      Print("Signal rejected - not for this account/channel");
      return;
   }
   Print("Signal MATCHED - will be processed");
   
   // Check if signal already exists
   bool exists = false;
   for(int i = 0; i < ArraySize(signals); i++)
   {
      if(signals[i].tradeId == signal.tradeId)
      {
         exists = true;
         break;
      }
   }
   
   if(!exists && signal.tradeId != "")
   {
      datetime currentTime = TimeCurrent();
      
      // FILTER: Process signals with entryTime in the future or recent past (within 2 hours)
      // This allows execution of signals that are slightly past entry time
      long timeDiff = (long)(signal.entryTime - currentTime);
      
      // Skip signals that are too old (more than 2 hours in the past)
      // This gives more time for execution while still filtering very old signals
      if(timeDiff < -7200)  // 2 hours instead of 1 hour
      {
         Print("Skipping very old signal: ", signal.symbol, " | Entry: ", TimeToString(signal.entryTime, TIME_DATE|TIME_MINUTES), 
               " | Current: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES), 
               " | Diff: ", timeDiff, "s | Trade ID: ", signal.tradeId);
         return;  // Don't add very old signals
      }
      
      // Log signal being added
      if(timeDiff < 0)
         Print("⚠️ Adding signal (entry time PASSED): ", signal.symbol, " ", signal.direction, 
               " | Entry: ", TimeToString(signal.entryTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
               " | Current: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
               " | Passed by: ", -timeDiff, "s | Trade ID: ", signal.tradeId);
      else
         Print("⏳ Adding signal (waiting for entry): ", signal.symbol, " ", signal.direction, 
               " | Entry: ", TimeToString(signal.entryTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
               " | Current: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
               " | Wait: ", timeDiff, "s | Trade ID: ", signal.tradeId);
      
      // Don't validate symbol here - do it at execution time
      // This allows symbols to be added to Market Watch or become available later
      
      int size = ArraySize(signals);
      ArrayResize(signals, size + 1);
      signals[size] = signal;
      
      Print("✓✓✓ Signal ADDED to queue #", size, ": ", signal.symbol, " ", signal.direction, 
            " | Entry: ", TimeToString(signal.entryTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), 
            " | Account: ", signal.accountName, " | Channel: ", signal.brand, 
            " | Trade ID: ", signal.tradeId);
      
      // If entry time has already passed, try to execute immediately
      if(timeDiff < 0 && timeDiff > -7200)  // Past but within 2 hours
      {
         Print("🚀 Entry time has passed - will attempt execution on next tick");
      }
   }
}

//+------------------------------------------------------------------+
//| Normalize string for comparison (trim and convert to uppercase)  |
//+------------------------------------------------------------------+
string NormalizeString(string str)
{
   // Remove leading/trailing whitespace
   string normalized = str;
   int len = StringLen(normalized);
   int start = 0;
   int end = len - 1;
   
   // Find start (skip leading spaces)
   while(start < len && StringGetCharacter(normalized, start) == ' ')
      start++;
   
   // Find end (skip trailing spaces)
   while(end >= start && StringGetCharacter(normalized, end) == ' ')
      end--;
   
   if(start > end)
      return "";
   
   normalized = StringSubstr(normalized, start, end - start + 1);
   
   // Convert to uppercase for case-insensitive comparison
   StringToUpper(normalized);
   
   return normalized;
}

//+------------------------------------------------------------------+
//| Check if signal matches configured account and channel           |
//+------------------------------------------------------------------+
bool IsSignalForThisAccount(SignalData &signal)
{
   // Get current MT5 account name for logging
   string currentAccountName = account.Name();
   
   // Normalize signal values (case-insensitive, trimmed)
   string signalAccount = NormalizeString(signal.accountName);
   string signalBrand = NormalizeString(signal.brand);
   
   // Check each configured account
   // The EA processes signals based on signal's accountName and brand matching the configured values
   // Account 1
   if(Account1Name != "" && Channel1Name != "")
   {
      // Normalize configured values
      string configAccount1 = NormalizeString(Account1Name);
      string configChannel1 = NormalizeString(Channel1Name);
      
      // Match: Signal's accountName matches Account1Name AND signal's channel matches Channel1Name (case-insensitive)
      if(signalAccount == configAccount1 && signalBrand == configChannel1)
      {
         Print("✓✓✓ Signal MATCHED Account 1: ", Account1Name, " | Channel: ", Channel1Name, " | Current MT5: ", currentAccountName);
         return true;
      }
   }
   
   // Account 2
   if(Account2Name != "" && Channel2Name != "")
   {
      string configAccount2 = NormalizeString(Account2Name);
      string configChannel2 = NormalizeString(Channel2Name);
      
      if(signalAccount == configAccount2 && signalBrand == configChannel2)
      {
         Print("✓✓✓ Signal MATCHED Account 2: ", Account2Name, " | Channel: ", Channel2Name, " | Current MT5: ", currentAccountName);
         return true;
      }
   }
   
   // Account 3
   if(Account3Name != "" && Channel3Name != "")
   {
      string configAccount3 = NormalizeString(Account3Name);
      string configChannel3 = NormalizeString(Channel3Name);
      
      if(signalAccount == configAccount3 && signalBrand == configChannel3)
      {
         Print("✓✓✓ Signal MATCHED Account 3: ", Account3Name, " | Channel: ", Channel3Name, " | Current MT5: ", currentAccountName);
         return true;
      }
   }
   
   // Signal doesn't match any configured account
   Print("✗ Signal REJECTED - Signal Account: '", signal.accountName, "' | Signal Channel: '", signal.brand, "'");
   Print("  Configured Account1: '", Account1Name, "' | Channel1: '", Channel1Name, "'");
   Print("  Normalized comparison - Signal: Account='", signalAccount, "' Brand='", signalBrand, "'");
   if(Account1Name != "")
      Print("  Normalized comparison - Config: Account='", NormalizeString(Account1Name), "' Brand='", NormalizeString(Channel1Name), "'");
   Print("  Current MT5 Account: ", currentAccountName);
   return false;
}

//+------------------------------------------------------------------+
//| Extract JSON value by key                                        |
//+------------------------------------------------------------------+
string ExtractJSONValue(string json, string key)
{
   string searchKey = "\"" + key + "\"";
   int keyPos = StringFind(json, searchKey);
   if(keyPos == -1) return "";
   
   int colonPos = StringFind(json, ":", keyPos);
   if(colonPos == -1) return "";
   
   int valueStart = colonPos + 1;
   // Skip whitespace
   while(valueStart < StringLen(json) && StringGetCharacter(json, valueStart) == ' ') valueStart++;
   
   int valueEnd = valueStart;
   char firstChar = (char)StringGetCharacter(json, valueStart);
   
   if(firstChar == '"')
   {
      // String value
      valueStart++;
      valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd == -1) return "";
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   else if(firstChar == '{' || firstChar == '[')
   {
      // Object or array - return empty for now
      return "";
   }
   else
   {
      // Number or boolean
      valueEnd = valueStart;
      while(valueEnd < StringLen(json))
      {
         char c = (char)StringGetCharacter(json, valueEnd);
         if(c == ',' || c == '}' || c == ']' || c == ' ') break;
         valueEnd++;
      }
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
}

//+------------------------------------------------------------------+
//| Parse datetime string (YYYY-MM-DD HH:MM:SS) and convert to MT5 server time |
//+------------------------------------------------------------------+
datetime ParseDateTime(string dateTimeStr)
{
   // Format: "2025-11-20 11:00:00"
   // The timezone of this string is specified by SignalTimeZone parameter
   // We convert it to MT5 server time for accurate trade execution
   
   if(StringLen(dateTimeStr) < 16) return 0;
   
   int year = (int)StringToInteger(StringSubstr(dateTimeStr, 0, 4));
   int month = (int)StringToInteger(StringSubstr(dateTimeStr, 5, 2));
   int day = (int)StringToInteger(StringSubstr(dateTimeStr, 8, 2));
   int hour = (int)StringToInteger(StringSubstr(dateTimeStr, 11, 2));
   int minute = (int)StringToInteger(StringSubstr(dateTimeStr, 14, 2));
   
   // Get timezone offset from SignalTimeZone parameter (e.g., "GMT+0", "GMT+3", "GMT-5")
   int signalTZOffset = ParseTimeZoneOffset(SignalTimeZone);
   
   // Get MT5 server timezone offset from GMT (in seconds)
   datetime serverGMT = TimeGMT();
   int serverTZOffset = (int)(TimeCurrent() - serverGMT);  // Server offset from GMT in seconds
   
   // Create MqlDateTime structure for the signal time
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;
   dt.day_of_week = 0;
   dt.day_of_year = 0;
   
   // Convert to datetime (this creates a datetime assuming local system timezone)
   // We need to adjust it to account for the signal's timezone
   datetime signalTime = StructToTime(dt);
   
   // Calculate the difference: signal timezone -> GMT -> MT5 server timezone
   // Step 1: Convert signal time (in SignalTimeZone) to GMT
   datetime gmtTime = signalTime - signalTZOffset;
   // Step 2: Convert GMT to MT5 server time
   datetime serverTime = gmtTime + serverTZOffset;
   
   // Debug timezone conversion (only for new signals to avoid spam)
   static datetime lastDebugTime = 0;
   if(TimeCurrent() - lastDebugTime > 60)  // Log once per minute max
   {
      Print("DEBUG Timezone Conversion:");
      Print("  Signal time (raw): ", TimeToString(signalTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      Print("  Signal timezone offset: ", signalTZOffset, "s (", signalTZOffset/3600, " hours)");
      Print("  GMT time: ", TimeToString(gmtTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      Print("  MT5 server offset: ", serverTZOffset, "s (", serverTZOffset/3600, " hours)");
      Print("  Final server time: ", TimeToString(serverTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      Print("  Current MT5 time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      lastDebugTime = TimeCurrent();
   }
   
   return serverTime;
}

//+------------------------------------------------------------------+
//| Parse timezone offset from string like "GMT+0", "GMT+3", "GMT-5" |
//+------------------------------------------------------------------+
int ParseTimeZoneOffset(string tzStr)
{
   // Default to GMT+0 if parsing fails
   int offset = 0;
   
   // Find the sign and number (e.g., "GMT+0", "GMT+3", "GMT-5")
   int plusPos = StringFind(tzStr, "+");
   int minusPos = StringFind(tzStr, "-");
   
   if(plusPos > 0)
   {
      string offsetStr = StringSubstr(tzStr, plusPos + 1);
      int hours = (int)StringToInteger(offsetStr);
      offset = hours * 3600;  // Convert hours to seconds
   }
   else if(minusPos > 0)
   {
      string offsetStr = StringSubstr(tzStr, minusPos + 1);
      int hours = (int)StringToInteger(offsetStr);
      offset = -hours * 3600;  // Convert hours to seconds (negative)
   }
   
   return offset;
}

//+------------------------------------------------------------------+
//| Sync with existing positions on EA restart                      |
//+------------------------------------------------------------------+
void SyncWithExistingPositions()
{
   // Check all open positions with our magic number
   int totalPositions = PositionsTotal();
   int syncedCount = 0;
   
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(position.SelectByTicket(ticket))
      {
         if(position.Magic() == MagicNumber)
         {
            string comment = position.Comment();
            // Check if this is a main trade (not a daily trade)
            if(StringFind(comment, "Forex Dynamic") >= 0 && StringFind(comment, "Daily") < 0)
            {
               syncedCount++;
               Print("Found existing main position: Ticket=", ticket, " Symbol=", position.Symbol(), " Comment=", comment);
            }
         }
      }
   }
   
   if(syncedCount > 0)
      Print("Synced with ", syncedCount, " existing position(s)");
}

//+------------------------------------------------------------------+
//| Check if a trade already exists for this signal                |
//+------------------------------------------------------------------+
bool TradeExistsForSignal(SignalData &signal)
{
   // Check all open positions
   int totalPositions = PositionsTotal();
   
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(position.SelectByTicket(ticket))
      {
         // Check if this position matches our signal
         if(position.Magic() == MagicNumber && 
            position.Symbol() == signal.symbol)
         {
            string comment = position.Comment();
            // Check if it's a main trade (not daily) for this symbol
            if(StringFind(comment, "Forex Dynamic") >= 0 && StringFind(comment, "Daily") < 0)
            {
               // Additional check: Verify direction matches
               bool directionMatch = false;
               if(signal.direction == "BUY" && position.PositionType() == POSITION_TYPE_BUY)
                  directionMatch = true;
               else if(signal.direction == "SELL" && position.PositionType() == POSITION_TYPE_SELL)
                  directionMatch = true;
               
               if(directionMatch)
               {
                  // Check if entry time is close (within 1 hour) - this helps match the signal
                  datetime posOpenTime = (datetime)position.Time();
                  long timeDiff = (long)(posOpenTime - signal.entryTime);
                  if(timeDiff < 0) timeDiff = -timeDiff;  // Absolute value
                  if(timeDiff < 3600)  // Within 1 hour
                  {
                     return true;  // Trade exists
                  }
               }
            }
         }
      }
   }
   
   return false;  // No matching trade found
}

//+------------------------------------------------------------------+
//| Find main ticket for a signal                                    |
//+------------------------------------------------------------------+
ulong FindMainTicketForSignal(SignalData &signal)
{
   // Search for existing position matching this signal
   int totalPositions = PositionsTotal();
   
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(position.SelectByTicket(ticket))
      {
         if(position.Magic() == MagicNumber && 
            position.Symbol() == signal.symbol)
         {
            string comment = position.Comment();
            if(StringFind(comment, "Forex Dynamic") >= 0 && StringFind(comment, "Daily") < 0)
            {
               // Check direction
               bool directionMatch = false;
               if(signal.direction == "BUY" && position.PositionType() == POSITION_TYPE_BUY)
                  directionMatch = true;
               else if(signal.direction == "SELL" && position.PositionType() == POSITION_TYPE_SELL)
                  directionMatch = true;
               
               if(directionMatch)
               {
                  datetime posOpenTime = (datetime)position.Time();
                  long timeDiff = (long)(posOpenTime - signal.entryTime);
                  if(timeDiff < 0) timeDiff = -timeDiff;  // Absolute value
                  if(timeDiff < 3600)  // Within 1 hour
                  {
                     return ticket;  // Found matching ticket
                  }
               }
            }
         }
      }
   }
   
   return 0;  // Not found
}

//+------------------------------------------------------------------+
//| Clean up old signals that are no longer needed                  |
//+------------------------------------------------------------------+
void CleanupOldSignals()
{
   datetime currentTime = TimeCurrent();
   int removedCount = 0;
   
   // Remove signals that are:
   // 1. Executed and more than 24 hours old, OR
   // 2. Not executed but entry time is more than 24 hours in the past
   for(int i = ArraySize(signals) - 1; i >= 0; i--)
   {
      bool shouldRemove = false;
      
      if(signals[i].isExecuted)
      {
         // Executed signal: remove if main trade is closed and it's been 24+ hours
         if(signals[i].mainTicket > 0)
         {
            if(!position.SelectByTicket(signals[i].mainTicket))
            {
               // Main trade is closed, check if it's been 24+ hours
               long timeSinceEntry = (long)(currentTime - signals[i].entryTime);
               if(timeSinceEntry > 86400)  // 24 hours
               {
                  shouldRemove = true;
               }
            }
         }
         else
         {
            // No main ticket but marked as executed - might be old, remove after 24 hours
            long timeSinceEntry = (long)(currentTime - signals[i].entryTime);
            if(timeSinceEntry > 86400)
            {
               shouldRemove = true;
            }
         }
      }
      else
      {
         // Not executed: remove if entry time is more than 24 hours in the past
         long timeSinceEntry = (long)(currentTime - signals[i].entryTime);
         if(timeSinceEntry > 86400)  // 24 hours
         {
            shouldRemove = true;
         }
      }
      
      if(shouldRemove)
      {
         // Remove this signal from array
         for(int j = i; j < ArraySize(signals) - 1; j++)
         {
            signals[j] = signals[j + 1];
         }
         ArrayResize(signals, ArraySize(signals) - 1);
         removedCount++;
      }
   }
   
   if(removedCount > 0)
   {
      Print("Cleaned up ", removedCount, " old signal(s) from memory");
   }
}

//+------------------------------------------------------------------+
//| Print status of all signals for debugging                        |
//+------------------------------------------------------------------+
void PrintSignalStatus()
{
   if(ArraySize(signals) == 0)
   {
      Print("No signals in queue");
      return;
   }
   
   Print("=== SIGNAL STATUS ===");
   for(int i = 0; i < ArraySize(signals); i++)
   {
      Print("Signal ", i, ": ", signals[i].symbol, " ", signals[i].direction,
            " | Executed: ", signals[i].isExecuted ? "YES" : "NO",
            " | SymbolNotFound: ", signals[i].symbolNotFound ? "YES" : "NO",
            " | Entry: ", TimeToString(signals[i].entryTime, TIME_DATE|TIME_MINUTES),
            " | TradeID: ", StringSubstr(signals[i].tradeId, 0, 8), "...");
   }
   Print("=====================");
}

//+------------------------------------------------------------------+
//| Check for scheduled trades to execute                           |
//+------------------------------------------------------------------+
void CheckScheduledTrades()
{
   datetime currentTime = TimeCurrent();
   
   // Debug: Log how many signals we're checking (but not every tick to avoid spam)
   static datetime lastCheckLog = 0;
   int totalSignals = ArraySize(signals);
   if(totalSignals > 0 && (currentTime - lastCheckLog >= 60))  // Log once per minute
   {
      Print("=== CHECKING ", totalSignals, " SIGNAL(S) FOR EXECUTION ===");
      Print("Current Time: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      lastCheckLog = currentTime;
   }
   
   for(int i = 0; i < ArraySize(signals); i++)
   {
      // Debug each signal
      Print("Signal ", i, " check: Symbol=", signals[i].symbol, 
            " | Executed=", signals[i].isExecuted ? "YES" : "NO",
            " | SymbolNotFound=", signals[i].symbolNotFound ? "YES" : "NO",
            " | TradeID=", signals[i].tradeId);
      
      if(signals[i].isExecuted) 
      {
         Print("  -> Skipped: Already executed");
         continue;
      }
      
      // DON'T skip if symbolNotFound - try to find it at execution time
      // This allows symbols to be added to Market Watch or become available
      // if(signals[i].symbolNotFound) 
      // {
      //    Print("  -> Skipped: Symbol not found (will retry at execution)");
      //    continue;
      // }
      
      if(signals[i].tradeId == "") 
      {
         Print("  -> Skipped: No TradeID");
         continue;
      }
      
      // Calculate time differences
      long timeDiff = (long)(currentTime - signals[i].entryTime);
      long secondsSinceReceived = (signals[i].receivedAt > 0) ? (long)(currentTime - signals[i].receivedAt) : 0;
      long secondsSinceFirstSeen = (signals[i].firstSeenAt > 0) ? (long)(currentTime - signals[i].firstSeenAt) : secondsSinceReceived;
      
      // FILTER: Skip signals that are too old (more than 2 hours past entry time)
      // This prevents executing very old signals while allowing scheduled future signals
      if(timeDiff > 7200)  // More than 2 hours past entry time
      {
         Print("Skipping very old signal: ", signals[i].symbol, " | Entry: ", 
               TimeToString(signals[i].entryTime, TIME_DATE|TIME_MINUTES), 
               " | Current: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES),
               " | Trade ID: ", signals[i].tradeId);
         signals[i].isExecuted = true;  // Mark as executed to prevent further processing
         continue;
      }
      
      // Check if trade already exists (prevent re-execution on EA restart)
      if(TradeExistsForSignal(signals[i]))
      {
         Print("Trade already exists for signal: ", signals[i].tradeId, " - Marking as executed");
         signals[i].isExecuted = true;
         signals[i].dailyActive = signals[i].isDaily;
         // Try to find the main ticket
         signals[i].mainTicket = FindMainTicketForSignal(signals[i]);
         continue;
      }
      
      // Calculate time differences
      long secondsUntilEntry = (long)(signals[i].entryTime - currentTime);
      long secondsSinceEntry = -secondsUntilEntry;
      datetime earliestExecutionTime = signals[i].entryTime;
      if(EntryExecutionToleranceSeconds > 0)
         earliestExecutionTime -= EntryExecutionToleranceSeconds;
      long secondsUntilEarliest = (long)(earliestExecutionTime - currentTime);
      
      Print("  -> Entry time check: Entry=", TimeToString(signals[i].entryTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " | Current=", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " | TimeDiff=", timeDiff, "s");
      Print("  -> Signal received: ", TimeToString(signals[i].receivedAt, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " | Seconds since received: ", secondsSinceReceived, "s");
      
      bool serverFresh = (signals[i].receivedAt == 0) ? true : (secondsSinceReceived >= 0 && secondsSinceReceived <= ImmediateExecutionWindowSeconds);
      bool localFresh = (signals[i].firstSeenAt == 0) ? true : (secondsSinceFirstSeen >= 0 && secondsSinceFirstSeen <= ImmediateExecutionWindowSeconds);
      bool immediateWindowActive = serverFresh && localFresh;
      bool shouldExecute = false;
      
      if(ExecuteImmediatelyOnReceipt && immediateWindowActive)
      {
         // Signal was just received - execute immediately regardless of entryTime
         Print("  -> ✅ ExecuteImmediatelyOnReceipt=TRUE and signal received ", secondsSinceReceived, "s ago - executing now");
         shouldExecute = true;
      }
      else
      {
         if(secondsUntilEarliest <= 0)
         {
            shouldExecute = true;
            if(secondsSinceEntry >= 0)
               Print("  -> ✅ Entry time reached ", secondsSinceEntry, "s ago - executing");
            else
               Print("  -> ✅ Within early tolerance (", EntryExecutionToleranceSeconds, "s) - executing");
         }
         else
         {
            Print("  -> ⏳ Waiting ", secondsUntilEarliest, "s until scheduled entry window");
         }
      }
      
      if(shouldExecute)
      {
         Print("========================================");
         Print(">>> 🚀 EXECUTING TRADE NOW 🚀 <<<");
         Print("Signal: ", signals[i].symbol, " ", signals[i].direction);
         Print("Signal Received At: ", TimeToString(signals[i].receivedAt, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
         Print("Entry Time (from signal): ", TimeToString(signals[i].entryTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
         Print("Current Time: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
         Print("Time Since Received: ", secondsSinceReceived, " seconds");
         Print("Lot Size: ", signals[i].lot);
         Print("TP: ", signals[i].tp, " pips");
         Print("SL: ", signals[i].sl, " pips");
         Print("Trade ID: ", signals[i].tradeId);
         Print("========================================");
         ExecuteTrade(signals[i]);
      }
      else
      {
         if(ExecuteImmediatelyOnReceipt && !immediateWindowActive && secondsSinceFirstSeen > ImmediateExecutionWindowSeconds)
            Print("  -> ⏸️ Immediate window expired (first seen ", secondsSinceFirstSeen, "s ago) - waiting for entryTime");
         
         if(secondsUntilEarliest > 0)
            Print("  -> ⏳ Waiting: ", secondsUntilEarliest, " seconds (", secondsUntilEarliest/60, " minutes) until entry window");
      }
   }
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(SignalData &signal)
{
   // Double-check: Prevent duplicate execution
   if(TradeExistsForSignal(signal))
   {
      Print("WARNING: Trade already exists for signal: ", signal.tradeId, " - Skipping execution");
      signal.isExecuted = true;
      signal.dailyActive = signal.isDaily;
      signal.mainTicket = FindMainTicketForSignal(signal);
      return;
   }
   
   // CRITICAL: Verify AutoTrading is still enabled
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      string error = "AutoTrading was disabled! Cannot execute trade.";
      Print("ERROR: ", error, " | Symbol: ", signal.symbol, " | Trade ID: ", signal.tradeId);
      if(EnableAlerts) Alert("EA Error: ", error);
      return;
   }
   
   // CRITICAL: Verify trading is still allowed
   if(!account.TradeAllowed())
   {
      string error = "Trading is not allowed! Cannot execute trade.";
      Print("ERROR: ", error, " | Symbol: ", signal.symbol, " | Trade ID: ", signal.tradeId);
      if(EnableAlerts) Alert("EA Error: ", error);
      return;
   }
   
   // Try to select symbol - attempt multiple times with different methods
   bool symbolSelected = false;
   
   // Method 1: Try direct selection
   if(SymbolSelect(signal.symbol, true))
   {
      symbolSelected = true;
      Print("Symbol selected: ", signal.symbol);
   }
   else
   {
      // Method 2: Try adding to Market Watch first
      Print("Attempting to add ", signal.symbol, " to Market Watch...");
      if(SymbolSelect(signal.symbol, true))
      {
         symbolSelected = true;
         Print("Symbol added to Market Watch: ", signal.symbol);
      }
      else
      {
         // Method 3: Try with different symbol name variations (common broker differences)
         string symbolVariations[];
         ArrayResize(symbolVariations, 3);
         symbolVariations[0] = signal.symbol;  // Original
         symbolVariations[1] = signal.symbol + "#";  // Some brokers use #
         symbolVariations[2] = signal.symbol + "m";  // Some use 'm' suffix
         
         for(int v = 0; v < 3; v++)
         {
            if(SymbolSelect(symbolVariations[v], true))
            {
               Print("Found symbol variation: ", symbolVariations[v], " (original was ", signal.symbol, ")");
               signal.symbol = symbolVariations[v];  // Update to working symbol
               symbolSelected = true;
               break;
            }
         }
      }
   }
   
   if(!symbolSelected)
   {
      string error = "Symbol " + signal.symbol + " not found - Check if symbol exists in your broker";
      Print("ERROR: ", error, " | Trade ID: ", signal.tradeId);
      Print("TIP: Add ", signal.symbol, " to Market Watch manually (Right-click Market Watch -> Show All)");
      if(EnableAlerts) Alert("EA Error: ", error);
      signal.symbolNotFound = true;
      return;
   }
   
   // Verify symbol is actually available for trading
   if(!SymbolInfoInteger(signal.symbol, SYMBOL_SELECT))
   {
      string error = "Symbol " + signal.symbol + " is not available for trading";
      Print("ERROR: ", error, " | Trade ID: ", signal.tradeId);
      if(EnableAlerts) Alert("EA Error: ", error);
      signal.symbolNotFound = true;
      return;
   }
   
   // Check if symbol is visible in Market Watch
   if(!SymbolInfoInteger(signal.symbol, SYMBOL_VISIBLE))
   {
      Print("WARNING: Symbol ", signal.symbol, " is not visible in Market Watch - Adding it");
      SymbolSelect(signal.symbol, true);
   }
   
   // Verify symbol is tradeable
   if(SymbolInfoInteger(signal.symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
   {
      string error = "Symbol " + signal.symbol + " trading is DISABLED by broker";
      Print("ERROR: ", error, " | Trade ID: ", signal.tradeId);
      if(EnableAlerts) Alert("EA Error: ", error);
      signal.symbolNotFound = true;
      return;
   }
   
   // Check minimum lot size
   double minLot = SymbolInfoDouble(signal.symbol, SYMBOL_VOLUME_MIN);
   if(signal.lot < minLot)
   {
      string error = "Lot size " + DoubleToString(signal.lot, 2) + " is below minimum " + DoubleToString(minLot, 2);
      Print("ERROR: ", error, " | Symbol: ", signal.symbol, " | Trade ID: ", signal.tradeId);
      if(EnableAlerts) Alert("EA Error: ", error);
      return;
   }
   
   double price = 0;
   double slPrice = 0;
   double tpPrice = 0;
   ENUM_ORDER_TYPE orderType;
   
   if(signal.direction == "BUY")
   {
      orderType = ORDER_TYPE_BUY;
      price = SymbolInfoDouble(signal.symbol, SYMBOL_ASK);
      
      double point = SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(signal.symbol, SYMBOL_DIGITS);
      
      // Calculate TP
      double tpPips = signal.tp;
      tpPrice = price + (tpPips * point * (digits == 3 || digits == 5 ? 10 : 1));
      
      // Calculate SL
      if(signal.sl > 0)
      {
         double slPips = signal.sl;
         slPrice = price - (slPips * point * (digits == 3 || digits == 5 ? 10 : 1));
      }
   }
   else if(signal.direction == "SELL")
   {
      orderType = ORDER_TYPE_SELL;
      price = SymbolInfoDouble(signal.symbol, SYMBOL_BID);
      
      double point = SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(signal.symbol, SYMBOL_DIGITS);
      
      // Calculate TP
      double tpPips = signal.tp;
      tpPrice = price - (tpPips * point * (digits == 3 || digits == 5 ? 10 : 1));
      
      // Calculate SL
      if(signal.sl > 0)
      {
         double slPips = signal.sl;
         slPrice = price + (slPips * point * (digits == 3 || digits == 5 ? 10 : 1));
      }
   }
   else
   {
      Print("ERROR: Invalid direction: ", signal.direction);
      return;
   }
   
   // Normalize prices
   tpPrice = NormalizeDouble(tpPrice, (int)SymbolInfoInteger(signal.symbol, SYMBOL_DIGITS));
   if(signal.sl > 0) slPrice = NormalizeDouble(slPrice, (int)SymbolInfoInteger(signal.symbol, SYMBOL_DIGITS));
   
   // Execute trade
   Print("Attempting to execute trade: ", signal.symbol, " ", signal.direction, 
         " | Lot: ", signal.lot, " | Price: ", price, " | SL: ", slPrice, " | TP: ", tpPrice);
   
   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
      result = trade.Buy(signal.lot, signal.symbol, price, slPrice, tpPrice, "Forex Dynamic");
   else
      result = trade.Sell(signal.lot, signal.symbol, price, slPrice, tpPrice, "Forex Dynamic");
   
   if(result)
   {
      signal.mainTicket = trade.ResultOrder();
      signal.isExecuted = true;
      signal.dailyActive = signal.isDaily;
      
      Print("========================================");
      Print("✓✓✓ TRADE EXECUTED SUCCESSFULLY ✓✓✓");
      Print("Symbol: ", signal.symbol);
      Print("Direction: ", signal.direction);
      Print("Ticket: ", signal.mainTicket);
      Print("Lot: ", signal.lot);
      Print("Entry Price: ", price);
      Print("TP: ", tpPrice);
      Print("SL: ", slPrice);
      Print("Trade ID: ", signal.tradeId);
      Print("========================================");
      
      if(EnableAlerts)
         Alert("Trade executed: ", signal.symbol, " ", signal.direction);
   }
   else
   {
      uint retcode = trade.ResultRetcode();
      string retcodeDescription = trade.ResultRetcodeDescription();
      double dealVolume = trade.ResultVolume();
      double dealPrice = trade.ResultPrice();
      string dealComment = trade.ResultComment();
      
      Print("========================================");
      Print("✗✗✗ TRADE EXECUTION FAILED ✗✗✗");
      Print("Symbol: ", signal.symbol);
      Print("Direction: ", signal.direction);
      Print("Retcode: ", retcode);
      Print("Description: ", retcodeDescription);
      Print("Deal Volume: ", dealVolume);
      Print("Deal Price: ", dealPrice);
      Print("Comment: ", dealComment);
      Print("Trade ID: ", signal.tradeId);
      Print("========================================");
      
      string error = "Trade execution failed: Retcode=" + IntegerToString((int)retcode) + " | " + retcodeDescription;
      if(EnableAlerts) Alert("EA Error: ", error);
   }
}

//+------------------------------------------------------------------+
//| Check TP conditions and update TP if needed                      |
//+------------------------------------------------------------------+
void CheckTPConditions()
{
   for(int i = 0; i < ArraySize(signals); i++)
   {
      if(!signals[i].isExecuted) continue;
      if(signals[i].tpCondition1 == "" || signals[i].tpCondition2 == "") continue;
      if(signals[i].newTP <= 0) continue;
      
      // Check if we need to evaluate TP condition
      datetime currentTime = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      // Parse condition times
      int cond1Hour = (int)StringToInteger(StringSubstr(signals[i].tpCondition1, 0, 2));
      int cond1Min = (int)StringToInteger(StringSubstr(signals[i].tpCondition1, 3, 2));
      int cond2Hour = (int)StringToInteger(StringSubstr(signals[i].tpCondition2, 0, 2));
      int cond2Min = (int)StringToInteger(StringSubstr(signals[i].tpCondition2, 3, 2));
      
      // Check if we're past condition time 2
      if(dt.hour > cond2Hour || (dt.hour == cond2Hour && dt.min >= cond2Min))
      {
         // Evaluate TP condition using 1-minute candles
         double price1 = GetPriceAtTime(signals[i].symbol, cond1Hour, cond1Min, signals[i].entryTime);
         double price2 = GetPriceAtTime(signals[i].symbol, cond2Hour, cond2Min, signals[i].entryTime);
         
         if(price1 > 0 && price2 > 0)
         {
            bool useNewTP = false;
            
            if(signals[i].direction == "SELL")
            {
               useNewTP = (price1 > price2);
            }
            else // BUY
            {
               useNewTP = (price1 < price2);
            }
            
            if(useNewTP)
            {
               // Update TP to newTP
               if(position.SelectByTicket(signals[i].mainTicket))
               {
                  double newTPPrice = CalculateTPPrice(signals[i].symbol, signals[i].direction, position.PriceOpen(), signals[i].newTP);
                  trade.PositionModify(signals[i].mainTicket, position.StopLoss(), newTPPrice);
                  Print("TP updated to New TP for signal: ", signals[i].tradeId);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get price at specific time using 1-minute candles                |
//+------------------------------------------------------------------+
double GetPriceAtTime(string symbol, int hour, int minute, datetime entryDate)
{
   MqlDateTime entryDt;
   TimeToStruct(entryDate, entryDt);
   
   // For condition 1, use previous day
   datetime targetTime = 0;
   if(hour == entryDt.hour && minute == entryDt.min)
   {
      // Condition 2 - same day as entry
      targetTime = entryDate;
   }
   else
   {
      // Condition 1 - previous day
      targetTime = entryDate - 86400; // Subtract 1 day
      MqlDateTime targetDt;
      TimeToStruct(targetTime, targetDt);
      targetDt.hour = hour;
      targetDt.min = minute;
      targetDt.sec = 0;
      targetTime = StructToTime(targetDt);
   }
   
   // Get 1-minute candle close price
   // Find the bar index for the target time
   int totalBars = Bars(symbol, PERIOD_M1);
   if(totalBars == 0) return 0;
   
   int barIndex = -1;
   for(int i = 0; i < totalBars; i++)
   {
      datetime barTime = iTime(symbol, PERIOD_M1, i);
      if(barTime <= targetTime)
      {
         barIndex = i;
         break;
      }
   }
   
   if(barIndex < 0) return 0;
   
   double close[];
   ArraySetAsSeries(close, true);
   int copied = CopyClose(symbol, PERIOD_M1, barIndex, 1, close);
   
   if(copied > 0)
      return close[0];
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate TP price from pips                                     |
//+------------------------------------------------------------------+
double CalculateTPPrice(string symbol, string direction, double entryPrice, double tpPips)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double multiplier = (digits == 3 || digits == 5) ? 10 : 1;
   
   if(direction == "BUY")
      return NormalizeDouble(entryPrice + (tpPips * point * multiplier), digits);
   else
      return NormalizeDouble(entryPrice - (tpPips * point * multiplier), digits);
}

//+------------------------------------------------------------------+
//| Check for daily re-entries                                       |
//+------------------------------------------------------------------+
void CheckDailyReEntries()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime currentDt;
   TimeToStruct(currentTime, currentDt);
   
   for(int i = 0; i < ArraySize(signals); i++)
   {
      if(!signals[i].dailyActive) continue;
      if(!signals[i].isExecuted) continue;
      if(signals[i].symbolNotFound) continue;  // Skip signals with unavailable symbols
      if(signals[i].mainTicket == 0) continue;  // No main ticket means no main trade
      
      // CRITICAL: Verify main trade exists and is still open
      if(!position.SelectByTicket(signals[i].mainTicket))
      {
         // Main trade doesn't exist - disable daily trades
         Print("Main trade not found for signal: ", signals[i].tradeId, " Ticket: ", signals[i].mainTicket, " - Disabling daily trades");
         signals[i].dailyActive = false;
         continue;
      }
      
      // Additional verification: Check if position is actually open
      if(position.Magic() != MagicNumber)
      {
         Print("Main trade magic number mismatch for signal: ", signals[i].tradeId, " - Disabling daily trades");
         signals[i].dailyActive = false;
         continue;
      }
      
      // CRITICAL: Daily trades should only start the NEXT day after main trade entry
      // Not on the same day as the main trade
      MqlDateTime entryDt;
      TimeToStruct(signals[i].entryTime, entryDt);
      
      // Check if current date is the same as entry date - if so, skip (too early)
      if(currentDt.day == entryDt.day && 
         currentDt.mon == entryDt.mon &&
         currentDt.year == entryDt.year)
      {
         continue;  // Same day as entry - daily trades start tomorrow
      }
      
      // Check if we've already placed daily today
      if(signals[i].lastDailyDate > 0)
      {
         MqlDateTime lastDailyDt;
         TimeToStruct(signals[i].lastDailyDate, lastDailyDt);
         
         if(currentDt.day == lastDailyDt.day && 
            currentDt.mon == lastDailyDt.mon &&
            currentDt.year == lastDailyDt.year)
         {
            continue; // Already placed daily today
         }
      }
      
      // We're past the entry day, check if we're at or past entry time on current day
      if(currentDt.hour > entryDt.hour || (currentDt.hour == entryDt.hour && currentDt.min >= entryDt.min))
      {
         // Place daily re-entry (only after the entry day has passed)
         ExecuteDailyTrade(signals[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute daily re-entry trade                                     |
//+------------------------------------------------------------------+
void ExecuteDailyTrade(SignalData &signal)
{
   // CRITICAL: Verify main trade exists before placing daily trade
   if(signal.mainTicket == 0)
   {
      Print("ERROR: Cannot place daily trade - No main ticket for signal: ", signal.tradeId);
      signal.dailyActive = false;
      return;
   }
   
   // Verify main trade is still open
   if(!position.SelectByTicket(signal.mainTicket))
   {
      Print("ERROR: Main trade not found for daily trade - Signal: ", signal.tradeId, " Ticket: ", signal.mainTicket);
      signal.dailyActive = false;
      return;
   }
   
   // Additional verification: Check magic number
   if(position.Magic() != MagicNumber)
   {
      Print("ERROR: Main trade magic mismatch for daily trade - Signal: ", signal.tradeId);
      signal.dailyActive = false;
      return;
   }
   
   // Check if symbol exists and is available
   if(!SymbolSelect(signal.symbol, true))
   {
      if(!signal.symbolNotFound)
      {
         Print("ERROR: Symbol ", signal.symbol, " not found for daily trade - Trade ID: ", signal.tradeId);
         signal.symbolNotFound = true;
      }
      return;
   }
   
   // Verify symbol is actually available for trading
   if(!SymbolInfoInteger(signal.symbol, SYMBOL_SELECT))
   {
      if(!signal.symbolNotFound)
      {
         Print("ERROR: Symbol ", signal.symbol, " is not available for trading - Trade ID: ", signal.tradeId);
         signal.symbolNotFound = true;
      }
      return;
   }
   
   double mainTPPrice = position.TakeProfit();
   double currentPrice = (signal.direction == "BUY") ? 
                         SymbolInfoDouble(signal.symbol, SYMBOL_ASK) : 
                         SymbolInfoDouble(signal.symbol, SYMBOL_BID);
   
   // Calculate daily TP
   double dailyTPPrice = CalculateTPPrice(signal.symbol, signal.direction, currentPrice, signal.dailyTP);
   
   // Cap daily TP to not exceed main TP
   if(signal.direction == "BUY")
   {
      if(dailyTPPrice > mainTPPrice) dailyTPPrice = mainTPPrice;
   }
   else
   {
      if(dailyTPPrice < mainTPPrice) dailyTPPrice = mainTPPrice;
   }
   
   // Use daily lot if specified, otherwise use main lot
   double lotSize = (signal.dailyLot > 0) ? signal.dailyLot : signal.lot;
   
   // Execute daily trade (no SL)
   bool result = false;
   if(signal.direction == "BUY")
      result = trade.Buy(lotSize, signal.symbol, currentPrice, 0, dailyTPPrice, "Forex Dynamic Daily");
   else
      result = trade.Sell(lotSize, signal.symbol, currentPrice, 0, dailyTPPrice, "Forex Dynamic Daily");
   
   if(result)
   {
      signal.lastDailyDate = TimeCurrent();
      Print("Daily trade executed: ", signal.symbol, " ", signal.direction, " Ticket: ", trade.ResultOrder());
      
      if(EnableAlerts)
         Alert("Daily trade executed: ", signal.symbol, " ", signal.direction);
   }
   else
   {
      string error = "Daily trade execution failed: " + IntegerToString(trade.ResultRetcode());
      Print("ERROR: ", error);
      if(EnableAlerts) Alert("EA Error: ", error);
   }
}

//+------------------------------------------------------------------+


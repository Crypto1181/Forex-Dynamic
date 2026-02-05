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
   string entryType;         // Entry type ("TIME" or "PRICE")
   datetime receivedAt;      // When signal was received
   datetime firstSeenAt;     // When EA first fetched the signal
   bool isExecuted;          // Has main trade been executed
   ulong mainTicket;         // Main trade ticket
   datetime lastDailyDate;   // Last daily trade date
   bool dailyActive;         // Is daily re-entry active
   bool symbolNotFound;      // Flag to mark if symbol is not available
   double originalTPPrice;   // Original TP price when trade was opened (for 50% rule)
   double originalEntryPrice; // Original entry price when trade was opened (for 50% rule)
   datetime tradeOpenTime;  // When position was actually opened (broker server time)
   bool tpModified;         // Track if TP has been modified to 50% (prevent re-modification)
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
   
   // Monitor and update daily trades (ensure TP doesn't exceed main TP)
   MonitorAndUpdateDailyTrades();
   
   // Monitor all daily trades (even those not linked to signals - for EA restart scenarios)
   MonitorAllDailyTrades();
   
   // Close daily trades if main trade is closed
   CloseDailyTradesIfMainClosed();
   
   // Check and apply TP modification rules (50% rule at market open)
   CheckTPModificationRules();
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
      
      if(error == 4014)
      {
         lastError = "WebRequest: URL not allowed. Add '" + ServerURL + "' to allowed URLs in Tools->Options->Expert Advisors";
         Print("ERROR 4014: ", lastError);
         if(EnableAlerts) Alert("EA Error: ", lastError);
         return;
      }
      
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
   
   // CRITICAL: Sync with existing positions AFTER parsing signals
   // This ensures that even if we restarted, we link the newly fetched (but potentially old) signals
   // to the existing open trades.
   SyncWithExistingPositions();
   
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
   
   // Track IDs found on server for synchronization
   string serverTradeIds[];
   int serverIdCount = 0;
   
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
      
      // Extract ID to track existence
      string currentId = ExtractJSONValue(signalJson, "tradeId");
      if(currentId != "")
      {
         ArrayResize(serverTradeIds, serverIdCount + 1);
         serverTradeIds[serverIdCount] = currentId;
         serverIdCount++;
      }
      
      Print("Parsing signal ", signalCount + 1, ": ", StringSubstr(signalJson, 0, 100), "...");
      ParseSignal(signalJson);
      signalCount++;
      
      pos = signalEnd + 1;
   }
   
   Print("Parsed ", signalCount, " signal(s) from server");
   
   // SYNC: Remove local signals that are no longer on the server
   if(signalCount > 0 || StringFind(json, "\"signals\":[]") >= 0) // Only sync if we successfully parsed something or got explicit empty list
   {
      for(int i = ArraySize(signals) - 1; i >= 0; i--)
      {
         bool found = false;
         for(int k = 0; k < serverIdCount; k++)
         {
            if(signals[i].tradeId == serverTradeIds[k])
            {
               found = true;
               break;
            }
         }
         
         if(!found)
         {
            Print("❌ Signal deleted from server, removing from EA: ", signals[i].symbol, " (ID: ", signals[i].tradeId, ")");
            RemoveSignalAt(i);
         }
      }
   }
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
   signal.entryType = ExtractJSONValue(signalJson, "entryType");
   if(signal.entryType == "") signal.entryType = "TIME"; // Default to TIME if missing
   
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
   signal.originalTPPrice = 0;
   signal.originalEntryPrice = 0;
   signal.tradeOpenTime = 0;
   signal.tpModified = false;
   
   // Check if signal matches current account and channel
   Print("Checking signal match: Account='", signal.accountName, "' | Brand='", signal.brand, "' | Symbol='", signal.symbol, "'");
   if(!IsSignalForThisAccount(signal))
   {
      // Signal is not for this account, skip it
      Print("Signal rejected - not for this account/channel");
      return;
   }
   
   // Check entry type - this EA only handles TIME signals
   if(signal.entryType == "PRICE")
   {
      Print("Signal rejected - entryType is PRICE (this EA only handles TIME/DATE signals)");
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
      // UNLESS they are daily signals (need to be kept for daily re-entries)
      // OR if we already have a trade for this signal (need to be kept for management)
      if(timeDiff < -7200)  // 2 hours instead of 1 hour
      {
         bool keepSignal = false;
         
         // Keep if it's a daily signal
         if(signal.isDaily)
         {
            Print("Keeping old signal because isDaily=true: ", signal.tradeId);
            keepSignal = true;
         }
         
         // Keep if we have an open trade for it
         if(!keepSignal && TradeExistsForSignal(signal))
         {
            Print("Keeping old signal because trade exists: ", signal.tradeId);
            keepSignal = true;
         }
         
         if(!keepSignal)
         {
            Print("Skipping very old signal: ", signal.symbol, " | Entry: ", TimeToString(signal.entryTime, TIME_DATE|TIME_MINUTES), 
                  " | Current: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES), 
                  " | Diff: ", timeDiff, "s | Trade ID: ", signal.tradeId);
            return;  // Don't add very old signals
         }
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
//| Remove signal at index                                           |
//+------------------------------------------------------------------+
void RemoveSignalAt(int index)
{
   int size = ArraySize(signals);
   if(index >= 0 && index < size)
   {
      // Shift elements down
      for(int i = index; i < size - 1; i++)
      {
         signals[i] = signals[i+1];
      }
      // Resize
      ArrayResize(signals, size - 1);
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
   int syncedMainCount = 0;
   int syncedDailyCount = 0;
   
   // First pass: Find all main trades and try to link them to signals
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
               syncedMainCount++;
               string symbol = position.Symbol();
               ENUM_POSITION_TYPE posType = position.PositionType();
               string direction = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               datetime openTime = (datetime)position.Time();
               
               Print("Found existing main position: Ticket=", ticket, " Symbol=", symbol, " Direction=", direction, " Comment=", comment);
               
               // Try to find matching signal in the array
               bool foundMatch = false;
               for(int s = 0; s < ArraySize(signals); s++)
               {
                  if(signals[s].symbol == symbol && 
                     signals[s].direction == direction &&
                     !signals[s].isExecuted)
                  {
                     // Check if entry time is close (within 2 hours)
                     long timeDiff = (long)(openTime - signals[s].entryTime);
                     if(timeDiff < 0) timeDiff = -timeDiff;  // Absolute value
                     if(timeDiff < 7200)  // Within 2 hours
                     {
                        // Link this signal to the existing main trade
                        signals[s].isExecuted = true;
                        signals[s].mainTicket = ticket;
                        signals[s].dailyActive = signals[s].isDaily;  // Activate daily if enabled
                        
                        // Store original TP and entry price for TP modification rule
                        signals[s].originalEntryPrice = position.PriceOpen();
                        double currentTP = position.TakeProfit();
                        signals[s].tradeOpenTime = (datetime)position.Time();
                        
                        // Try to determine if TP was already modified
                        // We'll use the signal's original TP value if available, otherwise use current TP
                        if(signals[s].tp > 0)
                        {
                           // Calculate what original TP should be based on signal
                           double point = SymbolInfoDouble(signals[s].symbol, SYMBOL_POINT);
                           int digits = (int)SymbolInfoInteger(signals[s].symbol, SYMBOL_DIGITS);
                           double multiplier = (digits == 3 || digits == 5) ? 10 : 1;
                           
                           double calculatedOriginalTP = 0;
                           if(signals[s].direction == "BUY")
                              calculatedOriginalTP = signals[s].originalEntryPrice + (signals[s].tp * point * multiplier);
                           else
                              calculatedOriginalTP = signals[s].originalEntryPrice - (signals[s].tp * point * multiplier);
                           
                           signals[s].originalTPPrice = calculatedOriginalTP;
                           
                           // Check if current TP is approximately 50% of original (within 5% tolerance)
                           double originalDistance = MathAbs(calculatedOriginalTP - signals[s].originalEntryPrice);
                           double currentDistance = MathAbs(currentTP - signals[s].originalEntryPrice);
                           double expectedDistance = originalDistance * 0.5;
                           
                           if(MathAbs(currentDistance - expectedDistance) / expectedDistance < 0.05)  // Within 5% tolerance
                           {
                              signals[s].tpModified = true;  // TP appears to be already modified
                              Print("  Detected: TP appears to be already modified (50% rule applied)");
                           }
                           else
                           {
                              signals[s].tpModified = false;
                           }
                        }
                        else
                        {
                           // No signal TP info, use current TP as original and assume not modified
                           signals[s].originalTPPrice = currentTP;
                           signals[s].tpModified = false;
                        }
                        
                        Print("✓ Linked existing main trade to signal: ", signals[s].tradeId, " | Daily active: ", (signals[s].dailyActive ? "YES" : "NO"));
                        Print("  Stored values - Entry: ", signals[s].originalEntryPrice, " | Original TP: ", signals[s].originalTPPrice, " | Current TP: ", currentTP);
                        Print("  TP Modified: ", (signals[s].tpModified ? "YES" : "NO"));
                        foundMatch = true;
                        break;
                     }
                  }
               }
               
               // If no signal match found, we can't fully sync, but at least we know the trade exists
               if(!foundMatch)
               {
                  Print("⚠️ Main trade found but no matching signal in queue - Trade may have been placed before EA restart");
               }
            }
         }
      }
   }
   
   // Second pass: Find all daily trades and verify they're linked to signals
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(position.SelectByTicket(ticket))
      {
         if(position.Magic() == MagicNumber)
         {
            string comment = position.Comment();
            // Check if this is a daily trade
            if(StringFind(comment, "Forex Dynamic Daily") >= 0)
            {
               syncedDailyCount++;
               string symbol = position.Symbol();
               ENUM_POSITION_TYPE posType = position.PositionType();
               string direction = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               
               Print("Found existing daily trade: Ticket=", ticket, " Symbol=", symbol, " Direction=", direction);
               
               // Try to find matching signal with daily active
               bool foundMatch = false;
               for(int s = 0; s < ArraySize(signals); s++)
               {
                  if(signals[s].symbol == symbol && 
                     signals[s].direction == direction &&
                     signals[s].isExecuted &&
                     signals[s].mainTicket > 0)
                  {
                     // Verify main trade still exists
                     if(position.SelectByTicket(signals[s].mainTicket))
                     {
                        // Ensure daily is active for this signal
                        if(!signals[s].dailyActive && signals[s].isDaily)
                        {
                           signals[s].dailyActive = true;
                           Print("✓ Reactivated daily re-entry for signal: ", signals[s].tradeId);
                        }
                        foundMatch = true;
                        break;
                     }
                  }
               }
               
               if(!foundMatch)
               {
                  Print("⚠️ Daily trade found but no matching active signal - Daily trade will be monitored");
               }
            }
         }
      }
   }
   
   if(syncedMainCount > 0 || syncedDailyCount > 0)
   {
      Print("========================================");
      Print("✓ Synced with existing positions:");
      Print("  Main trades: ", syncedMainCount);
      Print("  Daily trades: ", syncedDailyCount);
      Print("========================================");
   }
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
//| Find and select symbol with comprehensive search                |
//+------------------------------------------------------------------+
bool FindAndSelectSymbol(string &symbolName)
{
   string originalSymbol = symbolName;  // Store original for validation
   string baseSymbol = StringToUpper(symbolName);  // Normalize for comparison
   
   Print("========================================");
   Print("SEARCHING FOR SYMBOL: '", symbolName, "'");
   Print("========================================");
   
   // Method 1: Try direct selection (original name)
   Print("Method 1: Trying direct selection: '", symbolName, "'");
   if(SymbolSelect(symbolName, true))
   {
      if(SymbolInfoInteger(symbolName, SYMBOL_SELECT))
      {
         // CRITICAL VALIDATION: Ensure the symbol we found actually matches what we're looking for
         string foundSymbolUpper = StringToUpper(symbolName);
         if(foundSymbolUpper == baseSymbol)
         {
            Print("✓✓✓ Symbol found (direct): '", symbolName, "'");
            return true;
         }
         else
         {
            Print("✗ REJECTED: Symbol '", symbolName, "' does not match '", originalSymbol, "'");
         }
      }
   }
   
   // Method 2: Try common symbol variations (broker-specific suffixes/prefixes)
   string variations[];
   int varCount = 20;  // Increased from 3 to handle more broker variations
   ArrayResize(variations, varCount);
   
   // Common suffixes used by different brokers
   variations[0] = symbolName;           // Original
   variations[1] = symbolName + "#";     // Some brokers use #
   variations[2] = symbolName + "m";     // Some use 'm' suffix
   variations[3] = symbolName + "c";     // Common suffix
   variations[4] = symbolName + "i";     // Common suffix
   variations[5] = symbolName + "pro";    // Pro account suffix
   variations[6] = symbolName + "micro";  // Micro account
   variations[7] = symbolName + "mini";   // Mini account
   variations[8] = symbolName + "e";      // ECN suffix
   variations[9] = symbolName + "z";      // Common suffix
   variations[10] = symbolName + "x";     // Common suffix
   variations[11] = symbolName + ".";     // Dot suffix
   variations[12] = symbolName + "-";     // Dash suffix
   variations[13] = symbolName + "_";     // Underscore suffix
   variations[14] = symbolName + "1";     // Number suffix
   variations[15] = symbolName + "2";     // Number suffix
   // Convert to lowercase manually (MQL5 doesn't have StringToLower)
   string symbolLower = symbolName;
   for(int l = 0; l < StringLen(symbolLower); l++)
   {
      ushort ch = StringGetCharacter(symbolLower, l);
      if(ch >= 'A' && ch <= 'Z')
         StringSetCharacter(symbolLower, l, (ushort)(ch + 32));  // Convert to lowercase (explicit cast)
   }
   variations[16] = symbolLower;  // Lowercase
   variations[17] = StringToUpper(symbolName);  // Uppercase (already done, but keep for consistency)
   variations[18] = "." + symbolName;     // Dot prefix
   variations[19] = symbolName + "raw";   // Raw spread suffix
   
   Print("Method 2: Trying ", varCount, " known symbol variations...");
   for(int v = 0; v < varCount; v++)
   {
      if(variations[v] == "") continue;
      
      Print("  Trying variation ", v, ": '", variations[v], "'");
      if(SymbolSelect(variations[v], true))
      {
         if(SymbolInfoInteger(variations[v], SYMBOL_SELECT))
         {
            // CRITICAL VALIDATION: Ensure the found symbol actually matches our search
            // The found symbol must START with our base symbol (case-insensitive)
            string foundUpper = StringToUpper(variations[v]);
            if(StringFind(foundUpper, baseSymbol) == 0)  // Must start with our symbol
            {
               // Additional check: length should be reasonable (our symbol + small suffix)
               int baseLen = StringLen(baseSymbol);
               int foundLen = StringLen(foundUpper);
               if(foundLen >= baseLen && foundLen <= baseLen + 6)  // Allow up to 6 char suffix
               {
                  Print("✓✓✓ Found VALIDATED symbol variation: '", variations[v], "' (original was '", originalSymbol, "')");
                  symbolName = variations[v];  // Update to working symbol
                  return true;
               }
               else
               {
                  Print("  ✗ REJECTED: Length mismatch - found: ", foundLen, ", expected: ", baseLen, " to ", baseLen + 6);
               }
            }
            else
            {
               Print("  ✗ REJECTED: '", variations[v], "' does not start with '", originalSymbol, "'");
            }
         }
      }
   }
   
   // REMOVED Method 3: General broker symbol search - TOO DANGEROUS
   // It was causing wrong symbol matches (e.g., XAUUSD -> EURUSD)
   // Only use known, safe variations from Method 2
   
   Print("========================================");
   Print("✗✗✗ SYMBOL NOT FOUND: '", originalSymbol, "'");
   Print("Tried ", varCount + 1, " known variations but none matched");
   Print("The symbol may not be available on this broker");
   Print("========================================");
   return false;
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
   
   // Try to find and select symbol using comprehensive search
   string originalSymbol = signal.symbol;
   bool symbolSelected = FindAndSelectSymbol(signal.symbol);
   
   if(!symbolSelected)
   {
      string error = "Symbol '" + originalSymbol + "' not found - Check if symbol exists in your broker";
      Print("========================================");
      Print("ERROR: ", error, " | Trade ID: ", signal.tradeId);
      Print("Searched for: ", originalSymbol);
      Print("Tried 20+ symbol variations and scanned all broker symbols");
      Print("TIP: Check Market Watch -> Right-click -> Show All");
      Print("TIP: Look for symbols containing '", originalSymbol, "' in the broker's symbol list");
      Print("========================================");
      if(EnableAlerts) Alert("EA Error: ", error);
      signal.symbolNotFound = true;
      return;
   }
   
   if(originalSymbol != signal.symbol)
   {
      Print("========================================");
      Print("✓ Symbol name updated: '", originalSymbol, "' -> '", signal.symbol, "'");
      Print("========================================");
   }
   else
   {
      Print("========================================");
      Print("✓ Using original symbol: '", signal.symbol, "'");
      Print("========================================");
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
      
      // Store original TP and entry price for 50% modification rule
      // Get actual position data to ensure accuracy
      if(position.SelectByTicket(signal.mainTicket))
      {
         signal.originalEntryPrice = position.PriceOpen();
         signal.originalTPPrice = position.TakeProfit();
         signal.tradeOpenTime = (datetime)position.Time();
         signal.tpModified = false;
         
         Print("Stored original values for TP modification rule:");
         Print("  Entry Price: ", signal.originalEntryPrice);
         Print("  Original TP: ", signal.originalTPPrice);
         Print("  Trade Open Time: ", TimeToString(signal.tradeOpenTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      }
      else
      {
         // Fallback: use calculated values if position not found immediately
         signal.originalEntryPrice = price;
         signal.originalTPPrice = tpPrice;
         signal.tradeOpenTime = TimeCurrent();
         signal.tpModified = false;
         Print("WARNING: Could not select position immediately, using calculated values");
      }
      
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
   
   // Try to find and select symbol using comprehensive search
   string originalSymbol = signal.symbol;
   bool symbolSelected = FindAndSelectSymbol(signal.symbol);
   
   if(!symbolSelected)
   {
      if(!signal.symbolNotFound)
      {
         Print("ERROR: Symbol '", originalSymbol, "' not found for daily trade - Trade ID: ", signal.tradeId);
         Print("Searched for: ", originalSymbol);
         Print("Tried 20+ symbol variations and scanned all broker symbols");
         signal.symbolNotFound = true;
      }
      return;
   }
   
   if(originalSymbol != signal.symbol)
   {
      Print("Symbol name updated for daily trade: '", originalSymbol, "' -> '", signal.symbol, "'");
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
   
   // Cap daily TP to not exceed main TP distance from entry
   // For BUY: daily TP should be <= main TP (not higher than main TP)
   // For SELL: daily TP should be >= main TP (not lower than main TP, which would be further from entry)
   if(signal.direction == "BUY")
   {
      if(dailyTPPrice > mainTPPrice) dailyTPPrice = mainTPPrice;
   }
   else  // SELL
   {
      // For SELL: daily TP should be >= main TP (closer to entry or equal)
      // Only cap if daily TP goes below main TP (further from entry than main TP)
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
//| Monitor and update daily trades TP to ensure it doesn't exceed main TP |
//+------------------------------------------------------------------+
void MonitorAndUpdateDailyTrades()
{
   for(int i = 0; i < ArraySize(signals); i++)
   {
      if(!signals[i].dailyActive) continue;
      if(!signals[i].isExecuted) continue;
      if(signals[i].mainTicket == 0) continue;
      
      // Verify main trade is still open
      if(!position.SelectByTicket(signals[i].mainTicket))
      {
         continue;  // Main trade closed - will be handled by CloseDailyTradesIfMainClosed()
      }
      
      // Get current main TP (EA only READS main TP, never modifies it - manual changes are allowed)
      // This ensures daily trades respect the current main TP, even if manually changed
      double mainTPPrice = position.TakeProfit();
      if(mainTPPrice <= 0) continue;  // No TP set on main trade
      
      // Find all daily trades for this signal
      int totalPositions = PositionsTotal();
      for(int p = 0; p < totalPositions; p++)
      {
         ulong ticket = PositionGetTicket(p);
         if(ticket == 0) continue;
         
         if(position.SelectByTicket(ticket))
         {
            // Check if this is a daily trade for this signal
            if(position.Magic() == MagicNumber &&
               position.Symbol() == signals[i].symbol &&
               StringFind(position.Comment(), "Forex Dynamic Daily") >= 0)
            {
               // Verify direction matches
               bool directionMatch = false;
               if(signals[i].direction == "BUY" && position.PositionType() == POSITION_TYPE_BUY)
                  directionMatch = true;
               else if(signals[i].direction == "SELL" && position.PositionType() == POSITION_TYPE_SELL)
                  directionMatch = true;
               
               if(directionMatch)
               {
                  double dailyTPPrice = position.TakeProfit();
                  double dailyEntryPrice = position.PriceOpen();
                  double currentPrice = (signals[i].direction == "BUY") ? 
                                       SymbolInfoDouble(signals[i].symbol, SYMBOL_BID) : 
                                       SymbolInfoDouble(signals[i].symbol, SYMBOL_ASK);
                  bool needsUpdate = false;
                  
                  // Check if daily TP exceeds main TP distance from entry
                  // For BUY: daily TP should be <= main TP (not higher than main TP)
                  // For SELL: daily TP should be >= main TP (not lower than main TP, which would be further from entry)
                  if(signals[i].direction == "BUY")
                  {
                     if(dailyTPPrice > mainTPPrice)
                     {
                        // CRITICAL: Check if setting daily TP to main TP would cause immediate loss
                        if(mainTPPrice >= currentPrice)
                        {
                           needsUpdate = true;
                           dailyTPPrice = mainTPPrice;
                           Print("⚠️ Daily TP (", dailyTPPrice, ") exceeds main TP (", mainTPPrice, ") - Updating daily trade ticket: ", ticket);
                        }
                        else
                        {
                           Print("⚠️ WARNING: Cannot update daily TP to main TP (", mainTPPrice, ") - it's below current price (", currentPrice, ")");
                           Print("   This would cause immediate loss. Keeping daily TP unchanged: ", dailyTPPrice);
                           Print("   Daily Entry: ", dailyEntryPrice, " | Current Price: ", currentPrice);
                        }
                     }
                  }
                  else  // SELL
                  {
                     // For SELL: daily TP should be >= main TP (closer to entry or equal)
                     // Only cap if daily TP goes below main TP (further from entry than main TP) or is 0
                     if(dailyTPPrice < mainTPPrice || dailyTPPrice == 0)
                     {
                        // CRITICAL: Check if setting daily TP to main TP would cause immediate loss
                        if(mainTPPrice <= currentPrice)
                        {
                           needsUpdate = true;
                           dailyTPPrice = mainTPPrice;
                           Print("⚠️ Daily TP (", dailyTPPrice, ") is below main TP (", mainTPPrice, ") or is 0 - Updating daily trade ticket: ", ticket);
                        }
                        else
                        {
                           Print("⚠️ WARNING: Cannot update daily TP to main TP (", mainTPPrice, ") - it's above current price (", currentPrice, ")");
                           Print("   This would cause immediate loss. Keeping daily TP unchanged: ", dailyTPPrice);
                           Print("   Daily Entry: ", dailyEntryPrice, " | Current Price: ", currentPrice);
                        }
                     }
                  }
                  
                  // Update daily TP if needed
                  if(needsUpdate)
                  {
                     bool result = trade.PositionModify(ticket, position.StopLoss(), dailyTPPrice);
                     if(result)
                     {
                        Print("✅ Updated daily trade TP - Ticket: ", ticket, " | Symbol: ", signals[i].symbol, 
                              " | New TP: ", dailyTPPrice, " | Main TP: ", mainTPPrice);
                     }
                     else
                     {
                        Print("❌ Failed to update daily trade TP - Ticket: ", ticket, " | Retcode: ", trade.ResultRetcode());
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close daily trades if main trade is closed                      |
//+------------------------------------------------------------------+
void CloseDailyTradesIfMainClosed()
{
   for(int i = 0; i < ArraySize(signals); i++)
   {
      if(!signals[i].dailyActive) continue;
      if(!signals[i].isExecuted) continue;
      if(signals[i].mainTicket == 0) continue;
      
      // Check if main trade is still open
      bool mainTradeOpen = position.SelectByTicket(signals[i].mainTicket);
      
      if(!mainTradeOpen)
      {
         // Main trade is closed - close all daily trades for this signal
         Print("⚠️ Main trade closed (Ticket: ", signals[i].mainTicket, ") - Closing all daily trades for signal: ", signals[i].tradeId);
         
         int totalPositions = PositionsTotal();
         int closedCount = 0;
         
         for(int p = totalPositions - 1; p >= 0; p--)  // Iterate backwards to avoid index issues
         {
            ulong ticket = PositionGetTicket(p);
            if(ticket == 0) continue;
            
            if(position.SelectByTicket(ticket))
            {
               // Check if this is a daily trade for this signal
               if(position.Magic() == MagicNumber &&
                  position.Symbol() == signals[i].symbol &&
                  StringFind(position.Comment(), "Forex Dynamic Daily") >= 0)
               {
                  // Verify direction matches
                  bool directionMatch = false;
                  if(signals[i].direction == "BUY" && position.PositionType() == POSITION_TYPE_BUY)
                     directionMatch = true;
                  else if(signals[i].direction == "SELL" && position.PositionType() == POSITION_TYPE_SELL)
                     directionMatch = true;
                  
                  if(directionMatch)
                  {
                     // Close the daily trade
                     bool result = trade.PositionClose(ticket);
                     if(result)
                     {
                        closedCount++;
                        Print("✅ Closed daily trade - Ticket: ", ticket, " | Symbol: ", signals[i].symbol, 
                              " | Reason: Main trade closed");
                     }
                     else
                     {
                        Print("❌ Failed to close daily trade - Ticket: ", ticket, " | Retcode: ", trade.ResultRetcode());
                     }
                  }
               }
            }
         }
         
         if(closedCount > 0)
         {
            Print("✅ Closed ", closedCount, " daily trade(s) because main trade was closed");
            signals[i].dailyActive = false;  // Disable daily trades for this signal
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Monitor all daily trades (even those not linked to signals)     |
//| This ensures daily trades are managed even after EA restart     |
//+------------------------------------------------------------------+
void MonitorAllDailyTrades()
{
   int totalPositions = PositionsTotal();
   
   // Find all daily trades
   for(int p = 0; p < totalPositions; p++)
   {
      ulong dailyTicket = PositionGetTicket(p);
      if(dailyTicket == 0) continue;
      
      if(!position.SelectByTicket(dailyTicket)) continue;
      
      // Check if this is a daily trade
      if(position.Magic() == MagicNumber &&
         StringFind(position.Comment(), "Forex Dynamic Daily") >= 0)
      {
         string dailySymbol = position.Symbol();
         ENUM_POSITION_TYPE dailyType = position.PositionType();
         double dailyTPPrice = position.TakeProfit();
         
         // Find the corresponding main trade (same symbol, same direction, not daily)
         ulong mainTicket = 0;
         double mainTPPrice = 0;
         bool mainTradeFound = false;
         
         for(int m = 0; m < totalPositions; m++)
         {
            ulong ticket = PositionGetTicket(m);
            if(ticket == 0 || ticket == dailyTicket) continue;
            
            if(position.SelectByTicket(ticket))
            {
               if(position.Magic() == MagicNumber &&
                  position.Symbol() == dailySymbol &&
                  position.PositionType() == dailyType &&
                  StringFind(position.Comment(), "Forex Dynamic") >= 0 &&
                  StringFind(position.Comment(), "Daily") < 0)
               {
                  // Found the main trade
                  mainTicket = ticket;
                  mainTPPrice = position.TakeProfit();
                  mainTradeFound = true;
                  break;
               }
            }
         }
         
         if(!mainTradeFound)
         {
            // No main trade found - this daily trade is orphaned
            // Don't close it automatically, but log it
            static datetime lastOrphanLog = 0;
            if(TimeCurrent() - lastOrphanLog > 3600)  // Log once per hour
            {
               Print("⚠️ Orphaned daily trade found: Ticket=", dailyTicket, " Symbol=", dailySymbol, " - No main trade found");
               lastOrphanLog = TimeCurrent();
            }
            continue;
         }
         
         if(mainTPPrice <= 0) continue;  // Main trade has no TP
         
         // Get current price to check if TP modification would cause loss
         double currentPrice = (dailyType == POSITION_TYPE_BUY) ? 
                              SymbolInfoDouble(dailySymbol, SYMBOL_BID) : 
                              SymbolInfoDouble(dailySymbol, SYMBOL_ASK);
         double dailyEntryPrice = position.PriceOpen();
         
         // Check if daily TP needs to be capped
         bool needsUpdate = false;
         double newDailyTP = dailyTPPrice;
         
         if(dailyType == POSITION_TYPE_BUY)
         {
            // For BUY: daily TP should be <= main TP
            if(dailyTPPrice > mainTPPrice)
            {
               // CRITICAL: Check if setting daily TP to main TP would cause immediate loss
               if(mainTPPrice >= currentPrice)
               {
                  needsUpdate = true;
                  newDailyTP = mainTPPrice;
               }
               else
               {
                  Print("⚠️ WARNING: Cannot update orphaned daily TP to main TP (", mainTPPrice, ") - it's below current price (", currentPrice, ")");
                  Print("   This would cause immediate loss. Keeping daily TP unchanged: ", dailyTPPrice);
                  Print("   Daily Entry: ", dailyEntryPrice, " | Current Price: ", currentPrice);
               }
            }
         }
         else  // SELL
         {
            // For SELL: daily TP should be >= main TP (closer to entry or equal)
            if(dailyTPPrice < mainTPPrice || dailyTPPrice == 0)
            {
               // CRITICAL: Check if setting daily TP to main TP would cause immediate loss
               if(mainTPPrice <= currentPrice)
               {
                  needsUpdate = true;
                  newDailyTP = mainTPPrice;
               }
               else
               {
                  Print("⚠️ WARNING: Cannot update orphaned daily TP to main TP (", mainTPPrice, ") - it's above current price (", currentPrice, ")");
                  Print("   This would cause immediate loss. Keeping daily TP unchanged: ", dailyTPPrice);
                  Print("   Daily Entry: ", dailyEntryPrice, " | Current Price: ", currentPrice);
               }
            }
         }
         
         // Update daily TP if needed
         if(needsUpdate)
         {
            // Re-select the daily position to get current SL
            if(position.SelectByTicket(dailyTicket))
            {
               bool result = trade.PositionModify(dailyTicket, position.StopLoss(), newDailyTP);
               if(result)
               {
                  Print("✅ Updated orphaned daily trade TP - Ticket: ", dailyTicket, " | Symbol: ", dailySymbol, 
                        " | New TP: ", newDailyTP, " | Main TP: ", mainTPPrice);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if current time is market open (00:00 broker server time)  |
//+------------------------------------------------------------------+
bool IsMarketOpen()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Market open is at 00:00:00 broker server time
   // Check if we're at the start of a new trading day (00:00:00 to 00:00:59)
   if(dt.hour == 0 && dt.min == 0 && dt.sec < 60)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate number of trading days since trade was opened         |
//| Returns: 1 = Day 1 (opening day), 2 = Day 2, 3 = Day 3, etc.   |
//+------------------------------------------------------------------+
int GetTradingDaysSinceOpen(datetime tradeOpenTime)
{
   datetime currentTime = TimeCurrent();
   MqlDateTime openDt, currentDt;
   TimeToStruct(tradeOpenTime, openDt);
   TimeToStruct(currentTime, currentDt);
   
   // Calculate difference in days
   // If same day, return 1 (Day 1)
   if(openDt.year == currentDt.year && 
      openDt.mon == currentDt.mon && 
      openDt.day == currentDt.day)
   {
      return 1;  // Still on opening day
   }
   
   // Calculate days difference
   datetime openDayStart = StringToTime(IntegerToString(openDt.year) + "." + 
                                        IntegerToString(openDt.mon) + "." + 
                                        IntegerToString(openDt.day) + " 00:00:00");
   datetime currentDayStart = StringToTime(IntegerToString(currentDt.year) + "." + 
                                           IntegerToString(currentDt.mon) + "." + 
                                           IntegerToString(currentDt.day) + " 00:00:00");
   
   long secondsDiff = (long)(currentDayStart - openDayStart);
   int daysDiff = (int)(secondsDiff / 86400);  // 86400 seconds per day
   
   return daysDiff + 1;  // +1 because Day 1 is the opening day
}

//+------------------------------------------------------------------+
//| Get hour and minute from datetime (broker server time)          |
//+------------------------------------------------------------------+
int GetHour(datetime dt)
{
   MqlDateTime dtStruct;
   TimeToStruct(dt, dtStruct);
   return dtStruct.hour;
}

int GetMinute(datetime dt)
{
   MqlDateTime dtStruct;
   TimeToStruct(dt, dtStruct);
   return dtStruct.min;
}

//+------------------------------------------------------------------+
//| Check and apply TP modification rules (50% rule at market open)  |
//| Rule A: Trades opened 00:00-16:59 → Modify TP at Day 2 market open |
//| Rule B: Trades opened 17:00-market close → Modify TP at Day 3 market open |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check and apply TP modification rules (50% rule at market open)  |
//| Rule A: Trades opened 00:00-16:59 → Modify TP at Day 2 market open |
//| Rule B: Trades opened 17:00-market close → Modify TP at Day 3 market open |
//+------------------------------------------------------------------+
void CheckTPModificationRules()
{
   // We check every tick, but only act if conditions are met and NOT yet modified.
   // This handles cases where EA was offline at exactly 00:00.
   
   datetime currentTime = TimeCurrent();
   
   // Check all executed signals with open trades
   for(int i = 0; i < ArraySize(signals); i++)
   {
      if(!signals[i].isExecuted) continue;
      if(signals[i].mainTicket == 0) continue;
      if(signals[i].tpModified) continue;  // Already modified, skip
      if(signals[i].tradeOpenTime == 0) continue;  // No open time stored, skip
      if(signals[i].originalTPPrice <= 0) continue;  // No original TP, skip
      if(signals[i].originalEntryPrice <= 0) continue;  // No entry price, skip
      
      // Verify main trade is still open
      if(!position.SelectByTicket(signals[i].mainTicket))
      {
         continue;  // Trade closed, skip
      }
      
      // Get trade open time details
      int openHour = GetHour(signals[i].tradeOpenTime);
      
      // Calculate trading days since open
      int daysSinceOpen = GetTradingDaysSinceOpen(signals[i].tradeOpenTime);
      
      bool shouldModify = false;
      string ruleApplied = "";
      
      // Rule A: Trades opened 00:00-16:59 → Modify at Day 2 market open (or first chance on Day 2+)
      if(openHour >= 0 && openHour < 17)  // 00:00 to 16:59
      {
         if(daysSinceOpen >= 2)  // Day 2 or later
         {
            shouldModify = true;
            ruleApplied = "Rule A (00:00-16:59 → Day 2+)";
         }
      }
      // Rule B: Trades opened 17:00-market close → Modify at Day 3 market open (or first chance on Day 3+)
      else if(openHour >= 17)  // 17:00 to market close (23:59)
      {
         if(daysSinceOpen >= 3)  // Day 3 or later
         {
            shouldModify = true;
            ruleApplied = "Rule B (17:00-close → Day 3+)";
         }
      }
      
      if(shouldModify)
      {
         // Get current price to ensure TP modification doesn't cause immediate loss
         double currentPrice = 0;
         if(signals[i].direction == "BUY")
         {
            currentPrice = SymbolInfoDouble(signals[i].symbol, SYMBOL_BID);
         }
         else  // SELL
         {
            currentPrice = SymbolInfoDouble(signals[i].symbol, SYMBOL_ASK);
         }
         
         // Calculate 50% of original TP distance
         double originalTPDistance = 0;
         if(signals[i].direction == "BUY")
         {
            originalTPDistance = signals[i].originalTPPrice - signals[i].originalEntryPrice;
         }
         else  // SELL
         {
            originalTPDistance = signals[i].originalEntryPrice - signals[i].originalTPPrice;
         }
         
         double newTPDistance = originalTPDistance * 0.5;  // 50% of original
         double newTPPrice = 0;
         
         if(signals[i].direction == "BUY")
         {
            newTPPrice = signals[i].originalEntryPrice + newTPDistance;
            
            // CRITICAL: Ensure new TP is not below current price (would cause immediate loss)
            // If new TP would be below current price, use current price as minimum
            if(newTPPrice < currentPrice)
            {
               // Only print this once or occasionally to avoid spam
               static datetime lastWarnTime = 0;
               if(currentTime - lastWarnTime > 60)
               {
                  Print("⚠️ WARNING: Calculated TP (", newTPPrice, ") is below current price (", currentPrice, ")");
                  Print("   This would cause immediate loss. Skipping TP modification for now.");
                  lastWarnTime = currentTime;
               }
               continue;  // Skip modification to prevent loss
            }
         }
         else  // SELL
         {
            newTPPrice = signals[i].originalEntryPrice - newTPDistance;
            
            // CRITICAL: Ensure new TP is not above current price (would cause immediate loss)
            // If new TP would be above current price, use current price as maximum
            if(newTPPrice > currentPrice)
            {
               static datetime lastWarnTime = 0;
               if(currentTime - lastWarnTime > 60)
               {
                  Print("⚠️ WARNING: Calculated TP (", newTPPrice, ") is above current price (", currentPrice, ")");
                  Print("   This would cause immediate loss. Skipping TP modification for now.");
                  lastWarnTime = currentTime;
               }
               continue;  // Skip modification to prevent loss
            }
         }
         
         // Normalize price
         int digits = (int)SymbolInfoInteger(signals[i].symbol, SYMBOL_DIGITS);
         newTPPrice = NormalizeDouble(newTPPrice, digits);
         
         Print("========================================");
         Print(">>> APPLYING TP MODIFICATION <<<");
         Print("Rule: ", ruleApplied);
         Print("Symbol: ", signals[i].symbol);
         Print("Direction: ", signals[i].direction);
         Print("Ticket: ", signals[i].mainTicket);
         Print("Days Since Open: ", daysSinceOpen);
         Print("Current Price: ", currentPrice);
         Print("Original Entry: ", signals[i].originalEntryPrice);
         Print("Original TP: ", signals[i].originalTPPrice);
         Print("Original TP Distance: ", originalTPDistance);
         Print("New TP Distance (50%): ", newTPDistance);
         Print("New TP Price: ", newTPPrice);
         Print("========================================");
         
         // Modify TP
         bool result = trade.PositionModify(signals[i].mainTicket, position.StopLoss(), newTPPrice);
         
         if(result)
         {
            signals[i].tpModified = true;  // Mark as modified to prevent re-modification
            Print("✅ TP successfully modified to 50% of original distance");
            Print("   TP will NOT be modified again");
            
            if(EnableAlerts)
               Alert("TP Modified: ", signals[i].symbol, " ", signals[i].direction, " - TP set to 50%");
         }
         else
         {
            uint retcode = trade.ResultRetcode();
            string retcodeDescription = trade.ResultRetcodeDescription();
            Print("❌ Failed to modify TP - Retcode: ", retcode, " | ", retcodeDescription);
         }
      }
   }
}

//+------------------------------------------------------------------+


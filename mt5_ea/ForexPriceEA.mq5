//+------------------------------------------------------------------+
//|                                           ForexPriceEA.mq5      |
//|                        Forex Price Entry EA                     |
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
input int    PollIntervalSeconds = 10;                                  // Poll interval (seconds)
input int    MagicNumber = 777777;                                      // Magic number for Price EA
input bool   EnableAlerts = true;                                        // Enable alerts
input string SignalTimeZone = "GMT+0";                                  // Timezone of entryTime (for daily fixed time)

//--- Multi-Account Configuration
input string Account1Name = "";                                          // Account 1 Name
input string Channel1Name = "";                                          // Channel 1 Name
input string Account2Name = "";                                          // Account 2 Name
input string Channel2Name = "";                                          // Channel 2 Name

//--- Global variables
CTrade trade;
CPositionInfo position;
CAccountInfo account;

struct PriceSignal
{
   string tradeId;           // Unique trade ID
   string symbol;            // Symbol
   string direction;         // "BUY" or "SELL"
   double entryPrice;        // Reference Entry Price (for Main TP calc)
   double tp;                // Main TP in Pips (Global Goal)
   double sl;                // Stop Loss (Global or per trade?) - We'll apply to daily trades
   double dailyTP;           // Small TP for daily trades (e.g., 20 pips)
   double dailyLot;          // Lot size for daily trades
   datetime dailyEntryTime;  // Time of day to open daily trades
   
   string accountName;
   string brand;
   string entryType;         // Must be "PRICE"
   
   // State tracking
   bool isGlobalTPHit;       // If true, stop everything
   bool isActivated;         // If true, strategy has started (price hit entry)
   int lastTradeDay;         // Day of year of last trade
   double mainTPPrice;       // Calculated Price Level for Global TP
   bool isInitialized;       // Flag for init
};

PriceSignal signals[];
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
   
   // Get current account name for logging
   string currentAccountName = account.Name();
   Print("========================================");
   Print("Forex Price Entry EA initialized");
   Print("========================================");
   Print("Current MT5 Account: ", currentAccountName);
   Print("Magic Number: ", MagicNumber);
   Print("Server URL: ", ServerURL);
   Print("Poll interval: ", PollIntervalSeconds, " seconds");
   Print("Signal Timezone: ", SignalTimeZone);
   
   // CRITICAL: Check if AutoTrading is enabled
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      string error = "WARNING: AutoTrading is DISABLED in MT5! Enable it in Tools->Options->Expert Advisors->Allow automated trading";
      Print("WARNING: ", error);
      Print("EA will continue but trades will NOT execute until AutoTrading is enabled");
      if(EnableAlerts) Alert("EA Warning: ", error);
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
   
   if(accountCount == 0)
   {
      Print("========================================");
      Print("NOTICE: No accounts configured.");
      Print("        EA will run in 'Promiscuous Mode' and accept ALL signals.");
      Print("        To filter signals, configure Account/Channel names in inputs.");
      Print("========================================");
   }
   else
   {
      Print("✓ Account configuration: ", accountCount, " account(s) configured");
   }
   
   Print("========================================");
   
   if(EnableAlerts)
      Alert("Forex Price Entry EA started");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Forex Price Entry EA stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentTime = TimeCurrent();
   
   // Poll for signals
   if(currentTime - lastPollTime >= PollIntervalSeconds)
   {
      Print("========================================");
      Print("=== POLLING FOR SIGNALS ===");
      Print("Current Time: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      Print("Signals in queue BEFORE poll: ", ArraySize(signals));
      
      PollSignals();
      
      Print("Signals in queue AFTER poll: ", ArraySize(signals));
      
      SyncWithExistingPositions(); // Sync state with open trades
      lastPollTime = currentTime;
      
      Print("========================================");
   }
   
   // Process each active signal
   for(int i = 0; i < ArraySize(signals); i++)
   {
      ProcessSignal(signals[i]);
   }
}

//+------------------------------------------------------------------+
//| Sync with existing positions/history to prevent duplicate trades |
//+------------------------------------------------------------------+
void SyncWithExistingPositions()
{
   // 1. Check Open Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(position.SelectByTicket(ticket))
      {
         if(position.Magic() != MagicNumber) continue;
         
         string comment = position.Comment();
         // Find matching signal
         for(int j = 0; j < ArraySize(signals); j++)
         {
            if(signals[j].tradeId == comment)
            {
               // If it's a daily trade (check creation time)
               datetime openTime = (datetime)position.Time();
               if(DayOfYear(openTime) == DayOfYear(TimeCurrent()))
               {
                  signals[j].lastTradeDay = DayOfYear(TimeCurrent());
               }
               // If any trade exists, it must have been activated
               signals[j].isActivated = true;
            }
         }
      }
   }
   
   // 2. Check History (for closed trades today)
   HistorySelect(iTime(NULL, PERIOD_D1, 0), TimeCurrent());
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         if(magic != MagicNumber) continue;
         
         string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         
         if(entry == DEAL_ENTRY_IN) // Only check entry deals
         {
            for(int j = 0; j < ArraySize(signals); j++)
            {
               if(signals[j].tradeId == comment)
               {
                  datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                  if(DayOfYear(dealTime) == DayOfYear(TimeCurrent()))
                  {
                     signals[j].lastTradeDay = DayOfYear(TimeCurrent());
                  }
                  // If any trade exists, it must have been activated
                  signals[j].isActivated = true;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Process a single signal                                          |
//+------------------------------------------------------------------+
void ProcessSignal(PriceSignal &signal)
{
   // 1. Initialize Main TP Price if needed
   if(!signal.isInitialized)
   {
      double point = SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(signal.symbol, SYMBOL_DIGITS);
      
      // Adjust point for 3/5 digit brokers
      double adjustedPoint = point;
      if(digits == 3 || digits == 5) adjustedPoint *= 10;
      
      if(signal.direction == "BUY")
         signal.mainTPPrice = signal.entryPrice + (signal.tp * adjustedPoint);
      else
         signal.mainTPPrice = signal.entryPrice - (signal.tp * adjustedPoint);
         
      signal.isInitialized = true;
      Print("Signal ", signal.symbol, " Initialized. Main TP Level: ", signal.mainTPPrice, " Entry Price: ", signal.entryPrice);
   }
   
   // 2. Check if Global TP Hit
   if(signal.isGlobalTPHit) return; // Stop if already hit
   
   double currentPrice = 0;
   if(signal.direction == "BUY")
      currentPrice = SymbolInfoDouble(signal.symbol, SYMBOL_BID);
   else
      currentPrice = SymbolInfoDouble(signal.symbol, SYMBOL_ASK);
      
   bool tpReached = false;
   if(signal.direction == "BUY" && currentPrice >= signal.mainTPPrice) tpReached = true;
   if(signal.direction == "SELL" && currentPrice <= signal.mainTPPrice) tpReached = true;
   
   if(tpReached)
   {
      signal.isGlobalTPHit = true;
      Print(">>> GLOBAL TP HIT for ", signal.symbol, "! Stopping new trades. <<<");
      return;
   }
   
   // 3. Check Activation (Price Entry)
   if(!signal.isActivated)
   {
      // Check if price is near entry price (within 5 pips)
      // or if we should just activate if it crosses?
      // Simple logic: If price touches EntryPrice range (+/- 5 pips)
      
      double point = SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(signal.symbol, SYMBOL_DIGITS);
      double adjustedPoint = point;
      if(digits == 3 || digits == 5) adjustedPoint *= 10;
      
      double dist = MathAbs(currentPrice - signal.entryPrice);
      if(dist <= 50 * point) // 5 pips (assuming 50 points for 5-digit)
      {
         signal.isActivated = true;
         Print("Signal ", signal.symbol, " ACTIVATED at price ", currentPrice);
      }
      else
      {
         return; // Not yet activated, wait
      }
   }
   
   // 4. Check Daily Entry Time
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   MqlDateTime entryDt;
   TimeToStruct(signal.dailyEntryTime, entryDt);
   
   // Check if time matches (Hour and Minute) and we haven't traded today
   if(dt.hour == entryDt.hour && dt.min == entryDt.min && dt.day_of_year != signal.lastTradeDay)
   {
      // Open Daily Trade
      Print("Time match for ", signal.symbol, "! Opening daily trade...");
      OpenDailyTrade(signal);
   }
}

//+------------------------------------------------------------------+
//| Open Daily Trade                                                 |
//+------------------------------------------------------------------+
void OpenDailyTrade(PriceSignal &signal)
{
   double price = 0;
   double sl = 0;
   double tp = 0;
   
   double point = SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(signal.symbol, SYMBOL_DIGITS);
   double adjustedPoint = point;
   if(digits == 3 || digits == 5) adjustedPoint *= 10;
   
   ENUM_ORDER_TYPE orderType;
   
   if(signal.direction == "BUY")
   {
      orderType = ORDER_TYPE_BUY;
      price = SymbolInfoDouble(signal.symbol, SYMBOL_ASK);
      if(signal.sl > 0) sl = price - (signal.sl * adjustedPoint);
      if(signal.dailyTP > 0) tp = price + (signal.dailyTP * adjustedPoint);
   }
   else
   {
      orderType = ORDER_TYPE_SELL;
      price = SymbolInfoDouble(signal.symbol, SYMBOL_BID);
      if(signal.sl > 0) sl = price + (signal.sl * adjustedPoint);
      if(signal.dailyTP > 0) tp = price - (signal.dailyTP * adjustedPoint);
   }
   
   if(trade.PositionOpen(signal.symbol, orderType, signal.dailyLot, price, sl, tp, signal.tradeId))
   {
      Print("Daily trade opened for ", signal.symbol);
      signal.lastTradeDay = DayOfYear(TimeCurrent()); // Mark as done for today
   }
   else
   {
      Print("Error opening trade: ", GetLastError());
   }
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
}

//+------------------------------------------------------------------+
//| Parse JSON                                                       |
//+------------------------------------------------------------------+
void ParseSignalsJSON(string json)
{
   int signalsStart = StringFind(json, "\"signals\":[");
   if(signalsStart == -1) return;
   
   // Find end of signals array
   int arrayDepth = 0;
   int signalsEnd = -1;
   for(int i = signalsStart + 10; i < StringLen(json); i++)
   {
      ushort c = StringGetCharacter(json, i);
      if(c == '[') arrayDepth++;
      if(c == ']')
      {
         if(arrayDepth == 0)
         {
            signalsEnd = i;
            break;
         }
         arrayDepth--;
      }
   }
   
   if(signalsEnd == -1) return;
   
   string signalsArray = StringSubstr(json, signalsStart + 10, signalsEnd - (signalsStart + 10));
   
   // Track IDs found on server for synchronization
   string serverTradeIds[];
   int serverIdCount = 0;
   
   int pos = 0;
   while(pos < StringLen(signalsArray))
   {
      int start = StringFind(signalsArray, "{", pos);
      if(start == -1) break;
      
      int end = FindMatchingBrace(signalsArray, start);
      if(end == -1) break;
      
      string signalJson = StringSubstr(signalsArray, start, end - start + 1);
      
      // Extract ID to track existence
      string currentId = ExtractJSONValue(signalJson, "tradeId");
      if(currentId != "")
      {
         ArrayResize(serverTradeIds, serverIdCount + 1);
         serverTradeIds[serverIdCount] = currentId;
         serverIdCount++;
      }
      
      UpdateOrAddSignal(signalJson);
      
      pos = end + 1;
   }
   
   // SYNC: Remove local signals that are no longer on the server
   // Only sync if we successfully parsed something or got explicit empty list
   if(serverIdCount > 0 || StringLen(signalsArray) < 50) 
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

void UpdateOrAddSignal(string json)
{
   string entryType = ExtractJSONValue(json, "entryType");
   double ePrice = StringToDouble(ExtractJSONValue(json, "entryPrice"));

   // Relaxed Check: Accept if type is PRICE OR if it has a valid entry price (fallback)
   if(entryType != "PRICE") 
   {
      if(ePrice > 0.00001)
      {
         // It has a price, so we'll treat it as a PRICE signal even if type is missing/wrong
         // Print("⚠️ NOTICE: Signal entryType is '", entryType, "' but has Entry Price ", ePrice, ". Processing as PRICE signal.");
      }
      else
      {
         // It's likely a Time signal (Price=0) or invalid. Ignore it.
         // Print("Ignoring non-PRICE signal (Price=0, Type=", entryType, "): ", ExtractJSONValue(json, "symbol"));
         return; 
      }
   }
   
   string tradeId = ExtractJSONValue(json, "tradeId");
   
   // Check if exists
   for(int i = 0; i < ArraySize(signals); i++)
   {
      if(signals[i].tradeId == tradeId) return; // Already exists
   }
   
   // Add new
   int size = ArraySize(signals);
   ArrayResize(signals, size + 1);
   
   signals[size].tradeId = tradeId;
   signals[size].symbol = ExtractJSONValue(json, "symbol");
   signals[size].direction = ExtractJSONValue(json, "direction");
   signals[size].entryPrice = ePrice;
   signals[size].tp = StringToDouble(ExtractJSONValue(json, "tp")); // Main TP
   signals[size].sl = StringToDouble(ExtractJSONValue(json, "sl"));
   signals[size].dailyTP = StringToDouble(ExtractJSONValue(json, "dailyTP"));
   signals[size].dailyLot = StringToDouble(ExtractJSONValue(json, "dailyLot"));
   
   // Parse Daily Entry Time (from entryTime field)
   string entryTimeStr = ExtractJSONValue(json, "entryTime");
   signals[size].dailyEntryTime = StringToTime(entryTimeStr); 
   
   signals[size].accountName = ExtractJSONValue(json, "accountName");
   signals[size].brand = ExtractJSONValue(json, "brand");
   signals[size].entryType = (entryType == "" ? "PRICE (Inferred)" : entryType);
   
   signals[size].isGlobalTPHit = false;
   signals[size].isActivated = false;
   signals[size].lastTradeDay = -1;
   signals[size].isInitialized = false;
   
   // Check if signal matches configured account and channel
   if(!IsSignalForThisAccount(signals[size]))
   {
      ArrayResize(signals, size); // Remove the added signal
      return;
   }
   
   Print("✓✓✓ Added new PRICE signal: ", signals[size].symbol, " ", signals[size].direction, " @ ", signals[size].entryPrice);
   Print("  TP: ", signals[size].tp, " | SL: ", signals[size].sl);
   Print("  Account: ", signals[size].accountName, " | Channel: ", signals[size].brand);
   Print("  Trade ID: ", signals[size].tradeId);
   if(entryType != "PRICE") Print("  Note: Signal accepted based on Entry Price (Type='", entryType, "')");
   
   if(EnableAlerts)
      Alert("NEW PRICE SIGNAL: ", signals[size].symbol, " ", signals[size].direction, " @ ", signals[size].entryPrice);
}

string ExtractJSONValue(string json, string key)
{
   string search = "\"" + key + "\":";
   int start = StringFind(json, search);
   if(start == -1) return "";
   
   start += StringLen(search);
   
   // Skip whitespace
   while(start < StringLen(json) && (StringGetCharacter(json, start) == ' ' || StringGetCharacter(json, start) == '\t'))
      start++;
      
   bool isString = (StringGetCharacter(json, start) == '\"');
   if(isString) start++;
   
   int end;
   if(isString)
      end = StringFind(json, "\"", start);
   else
   {
      end = start;
      while(end < StringLen(json))
      {
         ushort c = StringGetCharacter(json, end);
         if(c == ',' || c == '}' || c == ']' || c == ' ' || c == '\n') break;
         end++;
      }
   }
   
   if(end == -1) return "";
   return StringSubstr(json, start, end - start);
}

int DayOfYear(datetime dt)
{
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   return mdt.day_of_year;
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
bool IsSignalForThisAccount(PriceSignal &signal)
{
   // Get current MT5 account name for logging
   string currentAccountName = account.Name();
   
   // Normalize signal values (case-insensitive, trimmed)
   string signalAccount = NormalizeString(signal.accountName);
   string signalBrand = NormalizeString(signal.brand);
   
   // Check each configured account
   // The EA processes signals based on signal's accountName and brand matching the configured values
   
   // If NO accounts are configured, accept ALL signals (Promiscuous Mode)
   if(Account1Name == "" && Channel1Name == "" && Account2Name == "" && Channel2Name == "")
   {
      // Print("✓ Signal ACCEPTED (Promiscuous Mode) - No filters configured");
      return true;
   }

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
   
   // Signal doesn't match any configured account
   Print("✗ Signal REJECTED - Signal Account: '", signal.accountName, "' | Signal Channel: '", signal.brand, "'");
   Print("  Configured Account1: '", Account1Name, "' | Channel1: '", Channel1Name, "'");
   Print("  Normalized comparison - Signal: Account='", signalAccount, "' Brand='", signalBrand, "'");
   if(Account1Name != "")
      Print("  Normalized comparison - Config: Account='", NormalizeString(Account1Name), "' Brand='", NormalizeString(Channel1Name), "'");
   Print("  Current MT5 Account: ", currentAccountName);
   return false;
}

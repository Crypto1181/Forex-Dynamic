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
   
   Print("Forex Price Entry EA initialized");
   Print("Magic Number: ", MagicNumber);
   
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
      PollSignals();
      SyncWithExistingPositions(); // Sync state with open trades
      lastPollTime = currentTime;
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
   char data[];
   char result[];
   string headers;
   int timeout = 5000;
   
   ResetLastError();
   int res = WebRequest("GET", ServerURL, "", timeout, data, result, headers);
   
   if(res == -1)
   {
      Print("WebRequest failed: ", GetLastError());
      return;
   }
   
   string jsonResponse = CharArrayToString(result);
   ParseSignalsJSON(jsonResponse);
}

//+------------------------------------------------------------------+
//| Parse JSON                                                       |
//+------------------------------------------------------------------+
void ParseSignalsJSON(string json)
{
   // Basic parsing logic similar to ForexDynamicEA but strictly for PRICE signals
   int signalsStart = StringFind(json, "\"signals\":[");
   if(signalsStart == -1) return;
   
   string signalsArray = StringSubstr(json, signalsStart + 10); // Skip "signals":[
   // Note: Robust JSON parsing would be better, but we'll use simple extraction for now
   // ... (Simplified for brevity, assuming standard format)
   
   // Iterate and parse individual signals
   int pos = 0;
   while(true)
   {
      int start = StringFind(json, "{", pos);
      if(start == -1) break;
      int end = FindMatchingBrace(json, start);
      if(end == -1) break;
      
      string signalJson = StringSubstr(json, start, end - start + 1);
      UpdateOrAddSignal(signalJson);
      
      pos = end + 1;
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
   if(entryType != "PRICE") return; // Ignore non-Price signals
   
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
   signals[size].entryPrice = StringToDouble(ExtractJSONValue(json, "entryPrice"));
   signals[size].tp = StringToDouble(ExtractJSONValue(json, "tp")); // Main TP
   signals[size].sl = StringToDouble(ExtractJSONValue(json, "sl"));
   signals[size].dailyTP = StringToDouble(ExtractJSONValue(json, "dailyTP"));
   signals[size].dailyLot = StringToDouble(ExtractJSONValue(json, "dailyLot"));
   
   // Parse Daily Entry Time (from entryTime field)
   string entryTimeStr = ExtractJSONValue(json, "entryTime");
   signals[size].dailyEntryTime = StringToTime(entryTimeStr); 
   
   signals[size].accountName = ExtractJSONValue(json, "accountName");
   signals[size].brand = ExtractJSONValue(json, "brand");
   signals[size].entryType = entryType;
   
   signals[size].isGlobalTPHit = false;
   signals[size].isActivated = false;
   signals[size].lastTradeDay = -1;
   signals[size].isInitialized = false;
   
   Print("Added new PRICE signal: ", signals[size].symbol);
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

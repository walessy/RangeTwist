//+------------------------------------------------------------------+
//|                            RangeTwistCustomSymbolIndicator.mq5 |
//+------------------------------------------------------------------+
#property copyright "Based on RangeTwist by Amos"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_NONE

// Input parameters
input string SourceSymbol = "";            // Source symbol (empty = current)
input string CustomSymbolSuffix = "_FLAT"; // Suffix for custom symbol
input int    RangeSize = 25;               // Range size in points
input bool   NormalizeValues = true;       // Normalize values to 0-100 range
input int    UpdateInterval = 2000;        // Update interval in milliseconds
input bool   ShowSymbolOnChart = true;     // Show custom symbol on chart
input int    HistoryBars = 500;            // Number of historical bars to process

// Indicator buffers
double DummyBuffer[];

// RangeTwist variables
double currentLevel = 0;
double prevLevel = 0;
bool upTrend = true;
double pointValue;
string actualSourceSymbol;
string customSymbolName;

// For tracking updates
ulong chartId = 0;
int updateCounter = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up buffers
   SetIndexBuffer(0, DummyBuffer, INDICATOR_DATA);
   
   // Determine source symbol
   actualSourceSymbol = (SourceSymbol == "") ? _Symbol : SourceSymbol;
   customSymbolName = actualSourceSymbol + CustomSymbolSuffix;
   
   // Create custom symbol on initialization
   if(!CreateOrUpdateCustomSymbol())
   {
      Print("Failed to create custom symbol on initialization");
      // Continue anyway, we'll try again on tick
   }
   
   // Open custom symbol chart if requested
   if(ShowSymbolOnChart)
   {
      chartId = ChartOpen(customSymbolName, PERIOD_CURRENT);
      if(chartId == 0)
         Print("Failed to open chart for ", customSymbolName);
      else
         Print("Chart opened with ID: ", chartId);
   }
   
   // Set up timer for periodic updates
   EventSetTimer(UpdateInterval / 1000.0); // Convert milliseconds to seconds
   
   Comment("RangeTwist Custom Symbol Indicator running...");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Main calculation is handled on timer events
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer event handler function                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   updateCounter++;
   
   // Update the custom symbol
   if(CreateOrUpdateCustomSymbol())
   {
      // Force redraw of both charts
      ChartRedraw(); // Current chart
      
      // Try to redraw the custom symbol chart if it exists
      if(chartId != 0 && ChartPeriod(chartId) > 0)
      {
         // Change timeframe slightly to force refresh
         ENUM_TIMEFRAMES current = (ENUM_TIMEFRAMES)ChartPeriod(chartId);
         ChartSetSymbolPeriod(chartId, customSymbolName, PERIOD_M1);
         ChartSetSymbolPeriod(chartId, customSymbolName, current);
      }
   }
   else
   {
      Print("Failed to update custom symbol on timer event");
   }
   
   // Update comment to show activity
   Comment("RangeTwist Custom Symbol Indicator running... Updates: ", updateCounter);
}

//+------------------------------------------------------------------+
//| Create or update custom symbol                                   |
//+------------------------------------------------------------------+
bool CreateOrUpdateCustomSymbol()
{
   // Create or select custom symbol
   if(!CustomSymbolExists(customSymbolName))
   {
      if(!CreateCustomSymbol(customSymbolName))
      {
         Print("Failed to create custom symbol!");
         return false;
      }
   }
   else
   {
      if(!SymbolSelect(customSymbolName, true))
      {
         Print("Failed to select custom symbol!");
         return false;
      }
   }
   
   // Process historical data and create flattened representation
   if(!ProcessAndFlattenData())
   {
      Print("Failed to process data!");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if custom symbol exists                                    |
//+------------------------------------------------------------------+
bool CustomSymbolExists(string symbol_name)
{
   for(int i = 0; i < SymbolsTotal(false); i++)
   {
      if(SymbolName(i, false) == symbol_name)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Create new custom symbol                                         |
//+------------------------------------------------------------------+
bool CreateCustomSymbol(string symbol_name)
{
   // Get properties from source symbol
   string base_currency = SymbolInfoString(actualSourceSymbol, SYMBOL_CURRENCY_BASE);
   string profit_currency = SymbolInfoString(actualSourceSymbol, SYMBOL_CURRENCY_PROFIT);
   int digits = (int)SymbolInfoInteger(actualSourceSymbol, SYMBOL_DIGITS);
   
   // Create custom symbol
   if(!CustomSymbolCreate(symbol_name, "Custom"))
   {
      Print("Error creating custom symbol: ", GetLastError());
      return false;
   }
   
   // Configure custom symbol properties
   CustomSymbolSetInteger(symbol_name, SYMBOL_DIGITS, digits);
   CustomSymbolSetInteger(symbol_name, SYMBOL_CHART_MODE, CHART_LINE);
   CustomSymbolSetDouble(symbol_name, SYMBOL_POINT, SymbolInfoDouble(actualSourceSymbol, SYMBOL_POINT));
   CustomSymbolSetDouble(symbol_name, SYMBOL_TRADE_TICK_SIZE, SymbolInfoDouble(actualSourceSymbol, SYMBOL_TRADE_TICK_SIZE));
   CustomSymbolSetString(symbol_name, SYMBOL_DESCRIPTION, "Flattened " + actualSourceSymbol + " Range Representation");
   
   return true;
}

//+------------------------------------------------------------------+
//| Process historical data and create flattened representation      |
//+------------------------------------------------------------------+
bool ProcessAndFlattenData()
{
   // Get historical data for source symbol
   MqlRates rates[];
   if(CopyRates(actualSourceSymbol, PERIOD_CURRENT, 0, HistoryBars, rates) <= 0)
   {
      Print("Error copying rates: ", GetLastError());
      return false;
   }
   
   // Sort rates from oldest to newest
   ArraySetAsSeries(rates, false);
   
   // Initialize RangeTwist variables
   pointValue = SymbolInfoDouble(actualSourceSymbol, SYMBOL_POINT);
   currentLevel = rates[0].close;
   prevLevel = rates[0].close;
   upTrend = true;
   
   // Array for flattened data
   MqlRates flatRates[];
   ArrayResize(flatRates, ArraySize(rates));
   
   // Process each bar using RangeTwist logic and flatten
   double minValue = currentLevel;
   double maxValue = currentLevel;
   double rangeInPoints = RangeSize * pointValue;
   
   for(int i = 0; i < ArraySize(rates); i++)
   {
      // Calculate range level using RangeTwist logic
      CalculateRangeLevel(rates[i].high, rates[i].low, rangeInPoints);
      
      // Store result in flattened rates
      flatRates[i].time = rates[i].time;
      flatRates[i].open = flatRates[i].high = flatRates[i].low = flatRates[i].close = currentLevel;
      flatRates[i].tick_volume = rates[i].tick_volume;
      flatRates[i].real_volume = rates[i].real_volume;
      flatRates[i].spread = rates[i].spread;
      
      // Track min/max for normalization
      if(currentLevel < minValue) minValue = currentLevel;
      if(currentLevel > maxValue) maxValue = currentLevel;
   }
   
   // Normalize values if requested
   if(NormalizeValues && maxValue > minValue)
   {
      double range = maxValue - minValue;
      for(int i = 0; i < ArraySize(flatRates); i++)
      {
         double normalizedValue = 100 * (flatRates[i].close - minValue) / range;
         flatRates[i].open = flatRates[i].high = flatRates[i].low = flatRates[i].close = normalizedValue;
      }
   }
   
   // Delete all existing rates first
   CustomRatesDelete(customSymbolName, (datetime)0, TimeCurrent());
   
   // Add flattened rates to custom symbol
   if(!CustomRatesUpdate(customSymbolName, flatRates))
   {
      Print("Error updating custom rates: ", GetLastError());
      return false;
   }
   
   // Create a series of ticks to force chart updates
   MqlTick ticks[1];
   ZeroMemory(ticks[0]);
   
   // Set the tick data
   ticks[0].time = TimeCurrent();
   ticks[0].bid = ticks[0].ask = flatRates[ArraySize(flatRates)-1].close;
   ticks[0].last = flatRates[ArraySize(flatRates)-1].close;
   ticks[0].volume = 1;
   ticks[0].flags = TICK_FLAG_BID | TICK_FLAG_ASK | TICK_FLAG_LAST;
   
   // Add ticks
   if(!CustomTicksAdd(customSymbolName, ticks))
   {
      Print("Error adding custom ticks: ", GetLastError());
      // Continue anyway as this is not critical
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate range level for bar (based on RangeTwist logic)        |
//+------------------------------------------------------------------+
void CalculateRangeLevel(double high, double low, double range)
{
   if(upTrend)
   {
      if(high >= currentLevel + range)
      {
         // Move the line up
         prevLevel = currentLevel;
         currentLevel = currentLevel + range;
      }
      else if(low <= currentLevel - range)
      {
         // Trend has reversed to down
         prevLevel = currentLevel;
         upTrend = false;
         currentLevel = currentLevel - range;
      }
   }
   else // downtrend
   {
      if(low <= currentLevel - range)
      {
         // Move the line down
         prevLevel = currentLevel;
         currentLevel = currentLevel - range;
      }
      else if(high >= currentLevel + range)
      {
         // Trend has reversed to up
         prevLevel = currentLevel;
         upTrend = true;
         currentLevel = currentLevel + range;
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Kill the timer
   EventKillTimer();
   
   // Clear the comment
   Comment("");
   
   // We keep the custom symbol even after indicator removal
   // This allows for using the custom symbol in other charts
   Print("RangeTwist Custom Symbol Indicator removed. Custom symbol remains available.");
}
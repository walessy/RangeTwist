//+------------------------------------------------------------------+
//|                      MTF_RangeBarWithTrendLines.mq5              |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website/Email"
#property version   "1.00"
#property description "Multi-timeframe Range Bar Indicator with Trend Lines"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots 0
double g_dummy_buffer[];
#property indicator_separate_window 0

// Input parameters for range bars
input int    RangeSize = 100;           // Range size in points
input color  UpColor = clrLimeGreen;    // Color for up bars
input color  DownColor = clrRed;        // Color for down bars
input int    BarWidth = 2;              // Width of bars in pixels
input bool   ShowValues = false;        // Show price values on bars
input bool   DrawLines = true;          // Draw lines instead of rectangles
input int    LineWidth = 3;             // Width of lines (if using lines)
input int    LineOffset = 5;            // Offset in points for line placement

// MTF Parameters
input string MTFSymbol = "";            // Symbol to use (empty = current)

// Define enum for timeframe selection
enum ENUM_MTF_TIMEFRAMES
{
   CURRENT_TF = 0,   // Current Timeframe
   USE_M1     = 1,   // M1
   USE_M5     = 2,   // M5
   USE_M15    = 3,   // M15
   USE_M30    = 4,   // M30
   USE_H1     = 5,   // H1
   USE_H4     = 6,   // H4
   USE_D1     = 7,   // D1
   USE_W1     = 8,   // W1
   USE_MN1    = 9,   // MN1
   USE_ALL    = 10,  // All Timeframes
};

input ENUM_MTF_TIMEFRAMES TimeFrameSelection = CURRENT_TF; // Timeframe to use
input bool   AutoRefresh = true;         // Auto refresh on new bars
input int    RefreshBars = 10;           // Number of bars to check for refresh

// Global variables
string g_symbol;                         // Symbol to process
datetime g_lastTime = 0;                 // Last processed time
int g_barCount = 0;                      // Number of range bars created
double g_lastPrice = 0;                  // Last price for range calculation
datetime g_lastBarTime = 0;              // Time of last processed bar
bool g_initialized = false;              // Flag to track initialization

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffer (dummy buffer for proper indicator recognition)
   SetIndexBuffer(0, g_dummy_buffer, INDICATOR_CALCULATIONS);

   // Determine which symbol to use
   g_symbol = _Symbol;
   if(MTFSymbol != "")
      g_symbol = MTFSymbol;
   
   Print("Initializing MTF Range Bar indicator for symbol: ", g_symbol);
   
   // Reset all range bar data
   ResetRangeBars();
   
   // Process historical data on initialization
   ProcessHistoricalData();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all objects created by this indicator
   string objPrefix = "MTF_RangeBar_";
   ObjectsDeleteAll(0, objPrefix);
   
   Print("Indicator removed, all objects deleted");
}

//+------------------------------------------------------------------+
//| Reset all range bar data                                          |
//+------------------------------------------------------------------+
void ResetRangeBars()
{
   g_barCount = 0;
   g_lastPrice = 0;
   g_lastTime = 0;
   g_lastBarTime = 0;
   g_initialized = false;
   
   string objPrefix = "MTF_RangeBar_";
   ObjectsDeleteAll(0, objPrefix);
}

//+------------------------------------------------------------------+
//| Process historical data for the indicator                         |
//+------------------------------------------------------------------+
void ProcessHistoricalData()
{
   Print("Processing historical data...");
   
   // Process based on timeframe selection
   switch(TimeFrameSelection)
   {
      case CURRENT_TF:
         Print("Processing current timeframe: ", EnumToString(_Period));
         ProcessTimeframe(g_symbol, _Period);
         break;
         
      case USE_M1:
         Print("Processing M1 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_M1);
         break;
         
      case USE_M5:
         Print("Processing M5 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_M5);
         break;
         
      case USE_M15:
         Print("Processing M15 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_M15);
         break;
         
      case USE_M30:
         Print("Processing M30 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_M30);
         break;
         
      case USE_H1:
         Print("Processing H1 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_H1);
         break;
         
      case USE_H4:
         Print("Processing H4 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_H4);
         break;
         
      case USE_D1:
         Print("Processing D1 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_D1);
         break;
         
      case USE_W1:
         Print("Processing W1 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_W1);
         break;
         
      case USE_MN1:
         Print("Processing MN1 timeframe...");
         ProcessTimeframe(g_symbol, PERIOD_MN1);
         break;
         
      case USE_ALL:
         Print("Processing ALL timeframes...");
         ProcessTimeframe(g_symbol, PERIOD_M1);
         ProcessTimeframe(g_symbol, PERIOD_M5);
         ProcessTimeframe(g_symbol, PERIOD_M15);
         ProcessTimeframe(g_symbol, PERIOD_M30);
         ProcessTimeframe(g_symbol, PERIOD_H1);
         ProcessTimeframe(g_symbol, PERIOD_H4);
         ProcessTimeframe(g_symbol, PERIOD_D1);
         ProcessTimeframe(g_symbol, PERIOD_W1);
         ProcessTimeframe(g_symbol, PERIOD_MN1);
         break;
   }
   
   Print("Historical data processing completed!");
}

//+------------------------------------------------------------------+
//| Process one timeframe                                             |
//+------------------------------------------------------------------+
void ProcessTimeframe(string symbol, ENUM_TIMEFRAMES timeframe)
{
   // Prefix for object names
   string objPrefix = "MTF_RangeBar_" + symbol + "_" + EnumToString(timeframe) + "_";
   
   // Clear any existing objects with our prefix if starting fresh
   if(!g_initialized)
   {
      ObjectsDeleteAll(0, objPrefix);
   }
   
   // Get symbol point value
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculate the price offset amount
   double offsetAmount = LineOffset * point;
   
   // Get MAXIMUM available history
   datetime start_time;
   datetime end_time = TimeCurrent();
   
   if(g_initialized)
   {
      // If already initialized, only process recent bars
      start_time = g_lastBarTime;
   }
   else
   {
      // First run - process all history
      start_time = D'1970.01.01 00:00';  // Very old date to get all history
   }
   
   // Print processing info
   Print("Processing ", symbol, " on ", EnumToString(timeframe), " from ", 
         TimeToString(start_time, TIME_DATE|TIME_MINUTES), " to ", 
         TimeToString(end_time, TIME_DATE|TIME_MINUTES));
   
   // Force load the history
   int available_bars = Bars(symbol, timeframe, start_time, end_time);
   Print("Available bars: ", available_bars);
   
   if(available_bars <= 0)
   {
      Print("No historical data available for ", symbol, " on ", EnumToString(timeframe), " timeframe");
      return;
   }
   
   // Process in chunks if necessary for very large datasets
   const int CHUNK_SIZE = 500000; // Process data in chunks to avoid memory errors
   int chunks_needed = (int)MathCeil((double)available_bars / CHUNK_SIZE);
   
   Print("Processing data in ", chunks_needed, " chunks");
   Print("Range size: ", RangeSize, " points = ", RangeSize * point, " in price");
   
   int total_processed = 0;
   bool first_bar = !g_initialized;
   
   // Process all chunks
   for(int chunk = 0; chunk < chunks_needed; chunk++)
   {
      // Calculate range for this chunk
      int start_pos = chunk * CHUNK_SIZE;
      int bars_to_copy = MathMin(CHUNK_SIZE, available_bars - total_processed);
      
      Print("Processing chunk ", chunk+1, "/", chunks_needed, " - bars ", start_pos, " to ", start_pos + bars_to_copy - 1);
      
      // Get data for this chunk
      MqlRates rates[];
      if(CopyRates(symbol, timeframe, start_pos, bars_to_copy, rates) <= 0)
      {
         Print("Failed to copy data for chunk ", chunk+1);
         
         // Try a smaller chunk as fallback
         bars_to_copy = MathMax(1000, bars_to_copy / 10);
         if(CopyRates(symbol, timeframe, start_pos, bars_to_copy, rates) <= 0)
         {
            Print("Fallback copy also failed. Skipping to next chunk.");
            total_processed += bars_to_copy;
            continue;
         }
      }
      
      int rates_count = ArraySize(rates);
      Print("Copied ", rates_count, " bars for processing");
      
      // Process this chunk of data
      for(int i = 0; i < rates_count; i++)
      {
         // For the very first bar, just record the price
         if(first_bar)
         {
            g_lastPrice = rates[i].close;
            g_lastTime = rates[i].time;
            g_lastBarTime = rates[i].time;
            first_bar = false;
            continue;
         }
         
         double currentPrice = rates[i].close;
         datetime currentTime = rates[i].time;
         
         // Update last bar time for subsequent refreshes
         if(currentTime > g_lastBarTime)
            g_lastBarTime = currentTime;
         
         // If price moved enough, create a range bar
         double priceDiff = MathAbs(currentPrice - g_lastPrice);
         double rangeAmount = RangeSize * point;
         
         if(priceDiff >= rangeAmount)
         {
            // Create range bar
            string objName = objPrefix + IntegerToString(g_barCount);
            bool isUp = currentPrice > g_lastPrice;
            color barColor = isUp ? UpColor : DownColor;
            
            if(DrawLines)
            {
               if(isUp)
               {
                  // Bullish trend - draw line below the price move
                  // Use the lowest price points
                  double lowPoint1 = MathMin(g_lastPrice, currentPrice) - offsetAmount;
                  double lowPoint2 = lowPoint1;
                  
                  if(ObjectCreate(0, objName, OBJ_TREND, 0, g_lastTime, lowPoint1, currentTime, lowPoint2))
                  {
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
                     ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  }
               }
               else
               {
                  // Bearish trend - draw line above the price move
                  // Use the highest price points
                  double highPoint1 = MathMax(g_lastPrice, currentPrice) + offsetAmount;
                  double highPoint2 = highPoint1;
                  
                  if(ObjectCreate(0, objName, OBJ_TREND, 0, g_lastTime, highPoint1, currentTime, highPoint2))
                  {
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
                     ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  }
               }
               
               // Only log progress periodically
               if(g_barCount % 100 == 0)
               {
                  Print("Created trend line #", g_barCount, 
                       " at ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES),
                       " price: ", DoubleToString(currentPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
               }
            }
            else
            {
               // Create a rectangle for this range bar
               if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, g_lastTime, g_lastPrice, currentTime, currentPrice))
               {
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                  ObjectSetInteger(0, objName, OBJPROP_FILL, true);
                  ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, BarWidth);
                  ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  
                  // Only log progress periodically
                  if(g_barCount % 100 == 0)
                  {
                     Print("Created range bar #", g_barCount, 
                          " at ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES),
                          " price: ", DoubleToString(currentPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
                  }
               }
            }
            
            // Add text label if requested
            if(ShowValues)
            {
               string labelName = objPrefix + "Label_" + IntegerToString(g_barCount);
               string labelText = DoubleToString(g_lastPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + 
                                " → " + 
                                DoubleToString(currentPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
               
               ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, (g_lastPrice + currentPrice) / 2);
               ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
               ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
               ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
               ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            }
            
            // Update for next bar
            g_lastPrice = currentPrice;
            g_lastTime = currentTime;
            g_barCount++;
         }
      }
      
      // Update count of processed bars
      total_processed += rates_count;
      
      // Give MT5 a chance to process events
      Sleep(10);
      ChartRedraw(0);
   }
   
   // Report final results
   Print("Processed ", total_processed, " price bars from ", symbol, " ", EnumToString(timeframe));
   Print("Total range bars: ", g_barCount);
   
   // Set the initialized flag
   g_initialized = true;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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
   // Check if we need to refresh
   if(!AutoRefresh)
      return(rates_total);
   
   // Only refresh if we have new bars
   static datetime last_chart_time = 0;
   if(rates_total == 0)
      return(0);
      
   datetime current_time = time[rates_total-1];
   
   // If same bar, no need to refresh
   if(current_time == last_chart_time)
      return(rates_total);
      
   // Update last processed time
   last_chart_time = current_time;
   
   // Check if it's been enough bars to refresh
   static int bar_counter = 0;
   
   bar_counter++;
   if(bar_counter < RefreshBars)
      return(rates_total);
      
   bar_counter = 0;
   
   Print("New data detected. Refreshing Range Bars...");
   
   // Process new data since last update
   ProcessHistoricalData();
   
   return(rates_total);
}
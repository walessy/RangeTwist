//+------------------------------------------------------------------+
//|                                    RangeTwist_TurningPoints.mq5 |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2
#property indicator_type1   DRAW_ARROW  // Up arrows
#property indicator_color1  clrLime     // Up arrow color
#property indicator_width1  3           // Arrow width
#property indicator_type2   DRAW_ARROW  // Down arrows
#property indicator_color2  clrRed      // Down arrow color
#property indicator_width2  3           // Arrow width

// For line chart compatibility
#property description "RangeTwist Turning Points Indicator - Optimized for Line Charts"

// Input parameters
input int    InitialRangeSize = 25;     // Range size in points
input bool   AutoRangeSize = true;      // Automatically adjust range size based on ATR
input int    ATRPeriod = 14;            // ATR period for auto range
input double ATRMultiplier = 2.0;       // Multiplier for ATR to set range
input color  UpArrowColor = clrLime;    // Color for up turning point arrow
input color  DownArrowColor = clrRed;   // Color for down turning point arrow
input int    UpArrowCode = 233;         // Character code for up arrow
input int    DownArrowCode = 234;       // Character code for down arrow
input int    ArrowSize = 3;             // Size of the arrow (1-5)
input double ArrowOffset = 1.0;         // Arrow distance from price
input bool   UseClosePrice = true;      // Use only close prices (for line charts)
input bool   ShowStats = true;          // Show statistics on chart

// Buffers
double UpArrowBuffer[];      // Buffer for up arrows
double DownArrowBuffer[];    // Buffer for down arrows
double CurrentRangeBuffer[]; // Current range size for data window
double HighBuffer[];         // High price or turning point value
double LowBuffer[];          // Low price or turning point value
double LastPriceBuffer[];    // Last trigger price

// State variables
double currentLevel = 0;
double highestSinceReversal = 0;
double lowestSinceReversal = 0;
bool upTrend = true;
double point;
int currentRangeSize;
int lastSignalBar = 0;
double atr = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   SetIndexBuffer(0, UpArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DownArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, CurrentRangeBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, LastPriceBuffer, INDICATOR_DATA);
   
   // Initialize buffers with EMPTY_VALUE
   ArrayInitialize(UpArrowBuffer, EMPTY_VALUE);
   ArrayInitialize(DownArrowBuffer, EMPTY_VALUE);
   ArrayInitialize(CurrentRangeBuffer, EMPTY_VALUE);
   ArrayInitialize(HighBuffer, EMPTY_VALUE);
   ArrayInitialize(LowBuffer, EMPTY_VALUE);
   ArrayInitialize(LastPriceBuffer, EMPTY_VALUE);
   
   // Set up arrow properties
   PlotIndexSetInteger(0, PLOT_ARROW, UpArrowCode);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, UpArrowColor);
   PlotIndexSetString(0, PLOT_LABEL, "Up Turning Point");
   
   PlotIndexSetInteger(1, PLOT_ARROW, DownArrowCode);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, DownArrowColor);
   PlotIndexSetString(1, PLOT_LABEL, "Down Turning Point");

   // Hide other buffers from display
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(2, PLOT_LABEL, "Current Range Size");
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(3, PLOT_LABEL, "High Value");
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(4, PLOT_LABEL, "Low Value");
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(5, PLOT_LABEL, "Last Price");
   
   // Initialize state variables
   point = _Point;
   currentRangeSize = InitialRangeSize;
   
   Print("RangeTwist_TurningPoints initialized. Initial range size: ", InitialRangeSize);
   
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
   // Check if we have enough bars
   if(rates_total < 50) return(0);
   
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset indicators and initialize
      ArrayInitialize(UpArrowBuffer, EMPTY_VALUE);
      ArrayInitialize(DownArrowBuffer, EMPTY_VALUE);
      
      // Initialize starting values
      int startBar = MathMin(50, rates_total-1);  // Start from a reasonable point
      currentLevel = close[startBar];
      highestSinceReversal = close[startBar];
      lowestSinceReversal = close[startBar];
      upTrend = true;
      lastSignalBar = startBar;
      
      Print("Indicator initialized with close price: ", currentLevel, " at bar ", startBar);
   }
   
   int start;
   
   // Determine the starting point for calculation
   if(prev_calculated == 0)
   {
      // First time calculation - start from the beginning but skip some initial bars
      start = 50; // Skip first 50 bars for stability
      if(start >= rates_total) start = rates_total - 2;
   }
   else
   {
      // Regular calculation - start from the previous bar
      start = prev_calculated - 1;
      if(start < 0) start = 0;
   }
   
   // Calculate the ATR if auto range size is enabled
   if(AutoRangeSize) {
      atr = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod, start);
      if(atr > 0) {
         currentRangeSize = (int)MathRound(atr / _Point * ATRMultiplier);
         if(currentRangeSize < 5) currentRangeSize = 5; // Minimum range size
      }
   }
   
   // Process all required bars
   for(int i = start; i < rates_total; i++)
   {
      // Make sure we have all arrays updated with EMPTY_VALUE as default
      UpArrowBuffer[i] = EMPTY_VALUE;
      DownArrowBuffer[i] = EMPTY_VALUE;
      
      // Define which price to use (close for line charts, or high/low for candlestick)
      double currentPrice, highPrice, lowPrice;
      
      if(UseClosePrice) {
         // For line charts, use only closing prices
         currentPrice = close[i];
         highPrice = close[i];
         lowPrice = close[i];
      } else {
         // For candlestick charts, use high and low
         currentPrice = close[i];
         highPrice = high[i];
         lowPrice = low[i];
      }
      
      // Update highest and lowest since last reversal
      if(currentPrice > highestSinceReversal) highestSinceReversal = currentPrice;
      if(currentPrice < lowestSinceReversal || lowestSinceReversal == 0) lowestSinceReversal = currentPrice;
      
      // Store current values
      HighBuffer[i] = highestSinceReversal;
      LowBuffer[i] = lowestSinceReversal;
      CurrentRangeBuffer[i] = currentRangeSize * point;
      LastPriceBuffer[i] = currentLevel;
      
      // Calculate the range in price
      double range = currentRangeSize * point;
      
      // Check for turning points
      if(upTrend)
      {
         // We're in an uptrend, looking for a peak and reversal down
         if(currentPrice >= currentLevel + range)
         {
            // Price continues up, adjust the current level
            currentLevel = currentLevel + range;
            highestSinceReversal = currentPrice;
            LastPriceBuffer[i] = currentLevel;
         }
         else if(currentPrice <= highestSinceReversal - range)
         {
            // We've dropped enough from the high to signal a downtrend
            // This is a turning point - place a down arrow
            
            // Only signal if we haven't signaled recently
            if(i - lastSignalBar > 3) {
               DownArrowBuffer[i] = highestSinceReversal + range * ArrowOffset;
               
               if(ShowStats) {
                  Print("DOWN turning point at bar ", i, " price: ", 
                       DoubleToString(highestSinceReversal, _Digits), 
                       " drop of ", DoubleToString(highestSinceReversal - currentPrice, _Digits));
               }
               
               // Update state
               upTrend = false;
               currentLevel = currentPrice;
               lowestSinceReversal = currentPrice;
               lastSignalBar = i;
            }
         }
      }
      else
      {
         // We're in a downtrend, looking for a bottom and reversal up
         if(currentPrice <= currentLevel - range)
         {
            // Price continues down, adjust the current level
            currentLevel = currentLevel - range;
            lowestSinceReversal = currentPrice;
            LastPriceBuffer[i] = currentLevel;
         }
         else if(currentPrice >= lowestSinceReversal + range)
         {
            // We've risen enough from the low to signal an uptrend
            // This is a turning point - place an up arrow
            
            // Only signal if we haven't signaled recently
            if(i - lastSignalBar > 3) {
               UpArrowBuffer[i] = lowestSinceReversal - range * ArrowOffset;
               
               if(ShowStats) {
                  Print("UP turning point at bar ", i, " price: ", 
                       DoubleToString(lowestSinceReversal, _Digits),
                       " rise of ", DoubleToString(currentPrice - lowestSinceReversal, _Digits));
               }
               
               // Update state
               upTrend = true;
               currentLevel = currentPrice;
               highestSinceReversal = currentPrice;
               lastSignalBar = i;
            }
         }
      }
   }
   
   // Update info on chart
   if(ShowStats) {
      string info = StringFormat("Range: %d points (%.5f)\nCurrent Trend: %s", 
                                currentRangeSize, currentRangeSize * point, 
                                upTrend ? "UP" : "DOWN");
                                
      if(AutoRangeSize) {
         info += StringFormat("\nATR(%d): %.5f", ATRPeriod, atr);
      }
      
      Comment(info);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate ATR (Average True Range)                               |
//+------------------------------------------------------------------+
double iATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift)
{
   double atr[];
   int handle = iATR(symbol, timeframe, period);
   
   if(handle == INVALID_HANDLE) {
      Print("Error creating ATR indicator");
      return 0;
   }
   
   if(CopyBuffer(handle, 0, shift, 1, atr) <= 0) {
      Print("Error copying ATR data");
      return 0;
   }
   
   IndicatorRelease(handle);
   return atr[0];
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear the chart comment
   Comment("");
}
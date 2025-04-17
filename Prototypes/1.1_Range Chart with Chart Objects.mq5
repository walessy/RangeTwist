//+------------------------------------------------------------------+
//|                                              RangeChartObj.mq5   |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website/Email"
#property version   "1.00"
#property indicator_chart_window

// Input parameters
input int    RangeSize = 25;            // Range size in points
input bool   ShowWicks = true;          // Show high/low wicks
input color  UpColor = clrLime;         // Color for up candles
input color  DownColor = clrRed;        // Color for down candles
input int    CandleWidth = 5;           // Width of the candles in bars

// Global variables
double currentOpen = 0;
double currentHigh = 0;
double currentLow = 0;
double currentClose = 0;
double prevClose = 0;
bool upTrend = true;
double point;
string prefix;
int barCounter = 0;
datetime baseTime;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get point value
   point = _Point;
   
   // Create a unique prefix for our objects
   prefix = "RangeChart_" + IntegerToString(MathRand()) + "_";
   
   // Clean any previous objects
   DeleteAllObjects();
   
   // Get base time for drawing - making sure to check the result
   datetime time_arr[];
   if(CopyTime(_Symbol, _Period, 0, 1, time_arr) > 0)
   {
      baseTime = time_arr[0];
   }
   else
   {
      // Fallback to current time if we can't get chart time
      baseTime = TimeCurrent();
      Print("Failed to get chart time, using current time: ", TimeToString(baseTime));
   }
   
   // Initialize range chart
   InitializeRangeChart();
   
   ChartRedraw();
   
   // Set a timer for continuous updates
   EventSetTimer(1);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Get current price
   MqlTick lastTick;
   if(SymbolInfoTick(_Symbol, lastTick))
   {
      ProcessPrice(lastTick.ask, lastTick.ask, lastTick.bid, lastTick.ask);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all created objects
   DeleteAllObjects();
   
   // Kill the timer
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Delete all objects created by this indicator                     |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   ObjectsDeleteAll(0, prefix);
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
   // Check if we have any bars
   if(rates_total <= 0)
      return(0);
   
   // Process only at new bar or init (for historical data)
   if(prev_calculated == 0 || rates_total != prev_calculated)
   {
      // Update base time - using the latest available time
      int last_idx = rates_total - 1;
      if(last_idx >= 0)  // Safety check
      {
         baseTime = time[last_idx];
         Print("Updated base time to: ", TimeToString(baseTime));
      }
      
      // At first calculation, initialize with first bar
      if(prev_calculated == 0)
         InitializeRangeChart();
      
      // On new bar, process the price data
      if(last_idx >= 0)  // Safety check
         ProcessPrice(open[last_idx], high[last_idx], low[last_idx], close[last_idx]);
   }
   
   ChartRedraw();
   
   // Return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Initialize range chart                                           |
//+------------------------------------------------------------------+
void InitializeRangeChart()
{
   // Initialize with the first available price
   MqlTick lastTick;
   if(SymbolInfoTick(_Symbol, lastTick))
   {
      currentOpen = lastTick.ask;
      currentHigh = lastTick.ask;
      currentLow = lastTick.bid;
      currentClose = lastTick.ask;
      prevClose = lastTick.ask;
      upTrend = true;
      barCounter = 0;
      
      Print("Initialized with tick data - Ask: ", DoubleToString(lastTick.ask, _Digits), 
            " Bid: ", DoubleToString(lastTick.bid, _Digits));
   }
   else
   {
      // Fallback to using CopyRates if SymbolInfoTick fails
      MqlRates rates[];
      if(CopyRates(_Symbol, _Period, 0, 1, rates) > 0)
      {
         currentOpen = rates[0].open;
         currentHigh = rates[0].high;
         currentLow = rates[0].low;
         currentClose = rates[0].close;
         prevClose = rates[0].close;
         upTrend = true;
         barCounter = 0;
         
         Print("Initialized with rates data - O: ", DoubleToString(rates[0].open, _Digits), 
               " H: ", DoubleToString(rates[0].high, _Digits),
               " L: ", DoubleToString(rates[0].low, _Digits),
               " C: ", DoubleToString(rates[0].close, _Digits));
      }
      else
      {
         Print("Failed to initialize price data");
      }
   }
}

//+------------------------------------------------------------------+
//| Process each new price update                                    |
//+------------------------------------------------------------------+
void ProcessPrice(double open, double high, double low, double close)
{
   // Check if we need to create a new range bar
   double range = RangeSize * point;
   bool newBar = false;
   
   if(upTrend)
   {
      // In uptrend, check if price moved up by range or reversed
      if(high >= currentHigh + range)
      {
         // Create a new up bar
         barCounter++;
         CreateRangeCandle(currentHigh, currentHigh + range, currentHigh, currentHigh + range, true);
         
         // Update current values
         currentHigh = currentHigh + range;
         currentLow = currentHigh;
         currentClose = currentHigh;
         prevClose = currentClose;
         newBar = true;
      }
      else if(low <= currentHigh - range)
      {
         // Reversal to downtrend
         upTrend = false;
         
         // Create a new down bar
         barCounter++;
         CreateRangeCandle(currentHigh, currentHigh, currentHigh - range, currentHigh - range, false);
         
         // Update current values
         currentLow = currentHigh - range;
         currentClose = currentLow;
         prevClose = currentClose;
         newBar = true;
      }
   }
   else
   {
      // In downtrend, check if price moved down by range or reversed
      if(low <= currentLow - range)
      {
         // Create a new down bar
         barCounter++;
         CreateRangeCandle(currentLow, currentLow, currentLow - range, currentLow - range, false);
         
         // Update current values
         currentHigh = currentLow;
         currentLow = currentLow - range;
         currentClose = currentLow;
         prevClose = currentClose;
         newBar = true;
      }
      else if(high >= currentLow + range)
      {
         // Reversal to uptrend
         upTrend = true;
         
         // Create a new up bar
         barCounter++;
         CreateRangeCandle(currentLow, currentLow + range, currentLow, currentLow + range, true);
         
         // Update current values
         currentHigh = currentLow + range;
         currentLow = currentLow;
         currentClose = currentHigh;
         prevClose = currentClose;
         newBar = true;
      }
   }
   
   if(newBar)
      ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create a range candle using chart objects                        |
//+------------------------------------------------------------------+
void CreateRangeCandle(double open, double high, double low, double close, bool isUp)
{
   color candleColor = isUp ? UpColor : DownColor;
   
   // Calculate time coordinates (we position candles horizontally from right to left)
   // baseTime is the rightmost time on chart, then we space candles to the left
   datetime leftTime = baseTime - (barCounter * PeriodSeconds() * CandleWidth);
   datetime rightTime = leftTime + (PeriodSeconds() * CandleWidth);
   
   // Names for our objects
   string bodyName = prefix + "Body_" + IntegerToString(barCounter);
   string highWickName = prefix + "HighWick_" + IntegerToString(barCounter);
   string lowWickName = prefix + "LowWick_" + IntegerToString(barCounter);
   
   // Create the candle body
   if(!ObjectCreate(0, bodyName, OBJ_RECTANGLE, 0, leftTime, open, rightTime, close))
   {
      Print("Failed to create candle body: ", GetLastError());
      return;
   }
   
   // Set body properties
   ObjectSetInteger(0, bodyName, OBJPROP_COLOR, candleColor);
   ObjectSetInteger(0, bodyName, OBJPROP_FILL, true);
   ObjectSetInteger(0, bodyName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bodyName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bodyName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bodyName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, bodyName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, bodyName, OBJPROP_TOOLTIP, "Range: " + DoubleToString(RangeSize) + " points");
   
   // Add wicks if enabled
   if(ShowWicks)
   {
      // Calculate middle time for wicks
      datetime midTime = leftTime + (PeriodSeconds() * CandleWidth / 2);
      
      // High wick
      if(high > MathMax(open, close))
      {
         if(!ObjectCreate(0, highWickName, OBJ_TREND, 0, midTime, MathMax(open, close), midTime, high))
         {
            Print("Failed to create high wick: ", GetLastError());
         }
         else
         {
            ObjectSetInteger(0, highWickName, OBJPROP_COLOR, candleColor);
            ObjectSetInteger(0, highWickName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, highWickName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, highWickName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, highWickName, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, highWickName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, highWickName, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, highWickName, OBJPROP_HIDDEN, true);
         }
      }
      
      // Low wick
      if(low < MathMin(open, close))
      {
         if(!ObjectCreate(0, lowWickName, OBJ_TREND, 0, midTime, MathMin(open, close), midTime, low))
         {
            Print("Failed to create low wick: ", GetLastError());
         }
         else
         {
            ObjectSetInteger(0, lowWickName, OBJPROP_COLOR, candleColor);
            ObjectSetInteger(0, lowWickName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lowWickName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lowWickName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lowWickName, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, lowWickName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lowWickName, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, lowWickName, OBJPROP_HIDDEN, true);
         }
      }
   }
   
   // Print debug info
   Print("Created candle #", barCounter, " at time ", TimeToString(leftTime), " - ", TimeToString(rightTime),
         " O:", DoubleToString(open, _Digits), " H:", DoubleToString(high, _Digits), 
         " L:", DoubleToString(low, _Digits), " C:", DoubleToString(close, _Digits));
}
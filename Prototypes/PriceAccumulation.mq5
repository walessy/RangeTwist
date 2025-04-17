//+------------------------------------------------------------------+
//|                                 PriceAccumulation.mq5            |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website/Email"
#property version   "1.00"
#property indicator_chart_window

// Input parameters
input int      RangeSize = 10;              // Range size in pips
input bool     StartAtMidnight = true;      // True: Start at 00:00, False: Start at session start
input color    UpColor = clrLime;           // Color for up rectangles
input color    DownColor = clrRed;          // Color for down rectangles
input int      RectWidth = 5;               // Rectangle width in bars

// Global variables
double         point;
double         pipValue;
string         prefix;
int            rectangleCounter = 0;
bool           upTrend = true;
double         currentHigh = 0;
double         currentLow = 0;
double         currentClose = 0;
double         prevClose = 0;
datetime       lastResetTime = 0;
bool           initialized = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get point value and convert to pips
   point = _Point;
   pipValue = point * 10;  // Standard conversion from points to pips
   
   // Create a unique prefix for our objects
   prefix = "PriceAccum_" + IntegerToString(MathRand()) + "_";
   
   // Clean any previous objects
   DeleteAllObjects();
   
   // Initialize indicator
   ResetIndicator();
   
   // Set timer for continuous updates
   EventSetTimer(1);
   
   return(INIT_SUCCEEDED);
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
//| Reset indicator values                                           |
//+------------------------------------------------------------------+
void ResetIndicator()
{
   // Get current price to start fresh
   MqlTick lastTick;
   if(SymbolInfoTick(_Symbol, lastTick))
   {
      currentHigh = lastTick.ask;
      currentLow = lastTick.bid;
      currentClose = (lastTick.ask + lastTick.bid) / 2;
      prevClose = currentClose;
      upTrend = true;
      rectangleCounter = 0;
      
      // Remember the reset time
      lastResetTime = TimeCurrent();
      
      Print("Indicator reset at ", TimeToString(lastResetTime));
      initialized = true;
   }
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Check if we need to reset based on time
   CheckResetTime();
   
   // Get current price
   MqlTick lastTick;
   if(SymbolInfoTick(_Symbol, lastTick))
   {
      // Process current prices
      ProcessPrice(lastTick.ask, lastTick.ask, lastTick.bid, (lastTick.ask + lastTick.bid) / 2);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Check if we need to reset based on time                          |
//+------------------------------------------------------------------+
void CheckResetTime()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime currentTimeStruct, lastResetTimeStruct;
   
   TimeToStruct(currentTime, currentTimeStruct);
   TimeToStruct(lastResetTime, lastResetTimeStruct);
   
   bool needsReset = false;
   
   if(StartAtMidnight)
   {
      // Reset at midnight
      if(currentTimeStruct.day != lastResetTimeStruct.day)
      {
         needsReset = true;
      }
   }
   else
   {
      // Reset at session start (market opening)
      datetime sessionStart = 0;
      datetime sessionEnd = 0;
      
      // Get session times for the current day
      if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)currentTimeStruct.day_of_week, 0, sessionStart, sessionEnd))
      {
         MqlDateTime sessionStartStruct;
         TimeToStruct(sessionStart, sessionStartStruct);
         
         // Adjust to current day
         sessionStartStruct.day = currentTimeStruct.day;
         sessionStartStruct.mon = currentTimeStruct.mon;
         sessionStartStruct.year = currentTimeStruct.year;
         
         // Convert back to datetime
         datetime todaySessionStart = StructToTime(sessionStartStruct);
         
         // Check if we've crossed a session boundary
         if(lastResetTime < todaySessionStart && currentTime >= todaySessionStart)
         {
            needsReset = true;
         }
      }
   }
   
   if(needsReset)
   {
      // Reset the indicator and clear all objects
      DeleteAllObjects();
      ResetIndicator();
   }
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
   // Check if initialized
   if(!initialized && rates_total > 0)
   {
      ResetIndicator();
   }
   
   // Process new bars
   if(rates_total > prev_calculated)
   {
      for(int i = prev_calculated > 0 ? prev_calculated - 1 : 0; i < rates_total; i++)
      {
         ProcessPrice(open[i], high[i], low[i], close[i]);
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Process price data and create rectangles when needed             |
//+------------------------------------------------------------------+
void ProcessPrice(double open, double high, double low, double close)
{
   // Convert RangeSize from pips to points
   double range = RangeSize * pipValue;
   
   if(upTrend)
   {
      // In uptrend, check if price moved up by range or reversed
      if(high >= currentHigh + range)
      {
         // Create a new up rectangle
         CreateRangeRectangle(currentHigh, currentHigh + range, true);
         
         // Update current values
         currentHigh = currentHigh + range;
         currentLow = currentHigh;
         currentClose = currentHigh;
         prevClose = currentClose;
      }
      else if(low <= currentHigh - range)
      {
         // Reversal to downtrend
         upTrend = false;
         
         // Create a new down rectangle
         CreateRangeRectangle(currentHigh, currentHigh - range, false);
         
         // Update current values
         currentLow = currentHigh - range;
         currentClose = currentLow;
         prevClose = currentClose;
      }
   }
   else
   {
      // In downtrend, check if price moved down by range or reversed
      if(low <= currentLow - range)
      {
         // Create a new down rectangle
         CreateRangeRectangle(currentLow, currentLow - range, false);
         
         // Update current values
         currentHigh = currentLow;
         currentLow = currentLow - range;
         currentClose = currentLow;
         prevClose = currentClose;
      }
      else if(high >= currentLow + range)
      {
         // Reversal to uptrend
         upTrend = true;
         
         // Create a new up rectangle
         CreateRangeRectangle(currentLow, currentLow + range, true);
         
         // Update current values
         currentHigh = currentLow + range;
         currentLow = currentLow;
         currentClose = currentHigh;
         prevClose = currentClose;
      }
   }
}

//+------------------------------------------------------------------+
//| Create a range rectangle                                         |
//+------------------------------------------------------------------+
void CreateRangeRectangle(double startPrice, double endPrice, bool isUp)
{
   rectangleCounter++;
   color rectColor = isUp ? UpColor : DownColor;
   
   // Get the current time for the right edge of the rectangle
   datetime currentTime = TimeCurrent();
   
   // Calculate left time (width back from current time)
   datetime leftTime = currentTime - (PeriodSeconds() * RectWidth);
   
   // Create rectangle name
   string rectName = prefix + "Rect_" + IntegerToString(rectangleCounter);
   
   // Create the rectangle
   if(!ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, leftTime, startPrice, currentTime, endPrice))
   {
      Print("Failed to create rectangle: ", GetLastError());
      return;
   }
   
   // Set rectangle properties
   ObjectSetInteger(0, rectName, OBJPROP_COLOR, rectColor);
   ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
   ObjectSetInteger(0, rectName, OBJPROP_BACK, false);
   ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, rectName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, true);
   
   // Create tooltip with information
   string direction = isUp ? "UP" : "DOWN";
   double pips = MathAbs(endPrice - startPrice) / pipValue;
   string tooltip = direction + " move of " + DoubleToString(pips, 1) + 
                    " pips from " + DoubleToString(startPrice, _Digits) + 
                    " to " + DoubleToString(endPrice, _Digits);
   ObjectSetString(0, rectName, OBJPROP_TOOLTIP, tooltip);
   
   Print("Created ", direction, " rectangle #", rectangleCounter, " from ", 
         DoubleToString(startPrice, _Digits), " to ", DoubleToString(endPrice, _Digits));
}
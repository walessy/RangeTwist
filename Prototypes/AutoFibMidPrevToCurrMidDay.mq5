//+------------------------------------------------------------------+
//|                                        AutoFib12PM.mq5             |
//|                                           Copyright 2025           |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//#define DEBUG

// Input parameters
input color    FibLinesColor      = clrDodgerBlue;   // Fibonacci lines color
input int      FibLinesWidth      = 2;               // Fibonacci lines width
input ENUM_LINE_STYLE FibLinesStyle = STYLE_SOLID;   // Fibonacci lines style
input color    FibLevelColor      = clrRed;          // Level labels color
input int      FibLevelFontSize   = 10;              // Level labels font size
input bool     ShowFibLevels      = true;            // Show Fibonacci levels
input bool     ShowExtensions     = false;           // Show Fibonacci extensions
input bool     ShowPriceLabels    = true;            // Show price labels
input bool     AutoRefresh        = true;            // Auto refresh every minute (Always enabled)
input bool     HighlightKeyLevels = true;            // Highlight 0.5 and 0.618 levels
input int      HistoricalDays     = 5;               // Number of historical days to show (0-20)
input color    HistoricalColor    = clrDarkGray;     // Color for historical Fibonacci levels
input bool     AlwaysShowLatest   = true;            // Always show latest Fibonacci even before 12PM
input bool     ExtendCurrentDat  = false;

// Fibonacci levels
double FibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
double FibExtensions[] = {1.272, 1.618, 2.0, 2.618};

// Global variables
datetime lastDayProcessed = 0;
datetime lastTimeframe=0;
int fibObjectsCounter = 0;
datetime lastRefreshTime = 0;
bool fibDrawn = false;
datetime processedDays[20]; // Store dates of processed days for historical tracking

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator properties
   IndicatorSetString(INDICATOR_SHORTNAME, "Auto Fibonacci 12PM");
   
   // Check if timeframe is appropriate
   //if(Period() > PERIOD_H1)
   //{
   //   Print("Indicator requires H1 or lower timeframe for precision!");
   //   return(INIT_FAILED);
   //}
   
   // Check historical days limit
   if(HistoricalDays > 20)
   {
      Print("Warning: Maximum historical days is 20. Setting to 20.");
   }
   
   // Reset tracking variables
   lastDayProcessed = 0;
   fibDrawn = false;
   ArrayInitialize(processedDays, 0);
   
   // Set timer for auto refresh - always on now
   EventSetTimer(60); // Check every minute
   
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
   if(Period() != lastTimeframe)
   {
      lastTimeframe = Period();
      lastDayProcessed = 0;  // Reset to force recalculation
      fibDrawn = false;
      DeleteFibObjects();    // Clean up all objects
   }

   // Always force recalculation
   if(!AlwaysShowLatest && fibDrawn)
   {
      // Only skip calculation if AlwaysShowLatest is off and we already drew today
      return(rates_total);
   }
   
   // Get current time
   MqlDateTime currTime;
   datetime currentTime = TimeCurrent();
   TimeToStruct(currentTime, currTime);
   
   // Process only once per day when 12PM candle is completed
   datetime currentDay = StringToTime(StringFormat("%04d.%02d.%02d", 
                         currTime.year, currTime.mon, currTime.day));
   
   // For auto-refresh, limit processing to once per minute
   if((currentTime - lastRefreshTime) < 60)
      return(rates_total);
      
   lastRefreshTime = currentTime;
   
   // Make sure 12PM has passed (12:00 + 1 hour to ensure we have the completed candle)
   bool is12PMPassed = currTime.hour >= 12;
   
   // If 12PM hasn't passed yet today AND AlwaysShowLatest is enabled, 
   // still try to draw provisional Fibonacci levels
   if(!is12PMPassed && lastDayProcessed != currentDay)
   {
      // For provisional display, try using previous day data with current day's lowest low so far
      datetime prevDayDate = currentDay - 86400; // Subtract one day in seconds
      
      // Find previous day's 12PM high
      datetime prevDay12PM = 0;
      double prevDay12PMHigh = 0;
      bool foundPrevDay = false;
      
      for(int i = 0; i < rates_total; i++)
      {
         MqlDateTime canTime;
         TimeToStruct(time[i], canTime);
         datetime canDate = StringToTime(StringFormat("%04d.%02d.%02d", 
                          canTime.year, canTime.mon, canTime.day));
                          
         if(canDate == prevDayDate && canTime.hour == 12)
         {
            prevDay12PM = time[i];
            prevDay12PMHigh = high[i];
            
            // Find highest high in the 12PM hour
            for(int j = i; j < rates_total; j++)
            {
               MqlDateTime nextTime;
               TimeToStruct(time[j], nextTime);
               
               datetime nextDate = StringToTime(StringFormat("%04d.%02d.%02d", 
                               nextTime.year, nextTime.mon, nextTime.day));
                               
               if(nextDate != prevDayDate || nextTime.hour > 12)
                  break;
                  
               if(high[j] > prevDay12PMHigh)
                  prevDay12PMHigh = high[j];
            }
            
            foundPrevDay = true;
            break;
         }
      }
      
      if(foundPrevDay)
      {
         // For the current day, since 12PM hasn't passed, use the lowest low so far today
         double currentDayLowSoFar = 999999999;
         
         for(int i = 0; i < rates_total; i++)
         {
            MqlDateTime canTime;
            TimeToStruct(time[i], canTime);
            datetime canDate = StringToTime(StringFormat("%04d.%02d.%02d", 
                           canTime.year, canTime.mon, canTime.day));
                           
            if(canDate == currentDay)
            {
               if(low[i] < currentDayLowSoFar)
                  currentDayLowSoFar = low[i];
            }
         }
         
         // Draw provisional Fibonacci using current lowest price
         if(currentDayLowSoFar < 999999999)
         {
            //11/03/2025 07:25 switched prevDay12PMHigh prevDay12PMHigh
            //11/03/2025 07:25 Think it needs to be this  
            DrawFibonacciLevels(time[0], currentDayLowSoFar, prevDay12PMHigh,prevDay12PM, true);
            //DrawFibonacciLevels(prevDay12PMHigh,prevDay12PM, time[0], currentDayLowSoFar, true);
            Comment("Auto Fibonacci 12PM (EARLY PROVISIONAL)\n",
                   "Using previous day 12PM high and current day's lowest price\n",
                   "Will update automatically after 12PM today");
                   
            // Process historical Fibonacci levels if requested
            if(HistoricalDays > 0)
            {
               ProcessHistoricalFibonacci(rates_total, time, low,high); //11/03/2025 07:25 switched high, low
            }
            
            return(rates_total);
         }
      }
   }
   
   // Check if enough data is available
   if(rates_total < 48)  // Need at least 2 days of data
   {
      Comment("Auto Fibonacci 12PM: Not enough historical data. Need at least 2 days.");
      return(rates_total);
   }
   
   // Find previous and current 12 PM candles
   datetime prevDay12PM = 0, currDay12PM = 0;
   double prevDay12PMHigh = 0, currDay12PMLow = 0;
   
   // Scan for the 12PM candles
   for(int i = 0; i < rates_total; i++)
   {
      MqlDateTime tempTime;
      TimeToStruct(time[i], tempTime);
      
      // Find the previous day's 12PM candle
      if(tempTime.day == currTime.day - 1 || (tempTime.day > 25 && currTime.day < 5))
      {
         if(tempTime.hour == 12 && (tempTime.min == 0 || tempTime.min < Period()))
         {
            prevDay12PM = time[i];
            prevDay12PMHigh = high[i];
            
            // Look for highest high in the 12PM candle
            for(int j = i; j < rates_total; j++)
            {
               MqlDateTime nextTime;
               TimeToStruct(time[j], nextTime);
               
               if(nextTime.hour > 12 || nextTime.day != tempTime.day)
                  break;
                  
               if(high[j] > prevDay12PMHigh)
                  prevDay12PMHigh = high[j];
            }
            
            break;
         }
      }
   }
   
   // Now find current day 12PM candle
   for(int i = 0; i < rates_total; i++)
   {
      MqlDateTime tempTime;
      TimeToStruct(time[i], tempTime);
      
      if(tempTime.day == currTime.day)
      {
         if(tempTime.hour == 12 && (tempTime.min == 0 || tempTime.min < Period()))
         {
            currDay12PM = time[i];
            currDay12PMLow = low[i];
            
            // Look for lowest low in the 12PM candle
            for(int j = i; j < rates_total; j++)
            {
               MqlDateTime nextTime;
               TimeToStruct(time[j], nextTime);
               
               if(nextTime.hour > 12 || nextTime.day != tempTime.day)
                  break;
                  
               if(low[j] < currDay12PMLow || currDay12PMLow == 0)
                  currDay12PMLow = low[j];
            }
            
            break;
         }
      }
   }
   
   // If 12PM on current day hasn't formed yet, we can't complete the Fibonacci
   if(!is12PMPassed || currDay12PM == 0 || currDay12PMLow == 0)
   {
      // If we have previous day's data, at least try to forecast with current price
      if(prevDay12PM != 0 && prevDay12PMHigh != 0)
      {
         currDay12PMLow = close[0]; // Use current price as substitute
         currDay12PM = time[0];
         DrawFibonacciLevels(prevDay12PM, prevDay12PMHigh, currDay12PM, currDay12PMLow, true);
         Comment("Auto Fibonacci 12PM: PROVISIONAL - Using current price until 12PM completes");
      }
      else
      {
         Comment("Auto Fibonacci 12PM: Waiting for 12PM candle to complete");
      }
      
      return(rates_total);
   }
   
   // Make sure we found both valid points
   if(prevDay12PM == 0 || prevDay12PMHigh == 0)
   {
      Comment("Auto Fibonacci 12PM: Could not find previous day 12PM high");
      return(rates_total);
   }
   
   // Draw Fibonacci levels
   DrawFibonacciLevels(prevDay12PM, prevDay12PMHigh, currDay12PM, currDay12PMLow, false);
   
   // Update processed day
   lastDayProcessed = currentDay;
   fibDrawn = true;
   
   // Process historical Fibonacci levels if requested
   if(HistoricalDays > 0)
   {
      ProcessHistoricalFibonacci(rates_total, time, high, low);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Force recalculation on timer event if auto-refresh is enabled
   if(AutoRefresh)
      ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw Fibonacci levels                                            |
//+------------------------------------------------------------------+
void DrawFibonacciLevels(datetime time1, double price1, datetime time2, double price2, bool isProvisional)
{
   // Remove previous Fibonacci objects
   DeleteFibObjects();
   
   // Create base Fibonacci object
   string fibName = StringFormat("FibRetracement_%d", fibObjectsCounter++);
   ObjectCreate(0, fibName, OBJ_FIBO, 0, time1, price1, time2, price2);
   
   // Set object properties
   ObjectSetInteger(0, fibName, OBJPROP_COLOR, FibLinesColor);
   ObjectSetInteger(0, fibName, OBJPROP_STYLE, FibLinesStyle);
   ObjectSetInteger(0, fibName, OBJPROP_WIDTH, FibLinesWidth);
   ObjectSetInteger(0, fibName, OBJPROP_BACK, false);  // Draw on foreground
   ObjectSetInteger(0, fibName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, fibName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, fibName, OBJPROP_RAY_RIGHT, false);
   
   // Add labels at start and end points
   if(ShowPriceLabels)
   {
      // Start point label
      string startLabel = StringFormat("FibStart_%d", fibObjectsCounter-1);
      ObjectCreate(0, startLabel, OBJ_TEXT, 0, time1, price1);
      ObjectSetString(0, startLabel, OBJPROP_TEXT, StringFormat("High: %.5f", price1));
      ObjectSetInteger(0, startLabel, OBJPROP_COLOR, FibLevelColor);
      ObjectSetInteger(0, startLabel, OBJPROP_FONTSIZE, FibLevelFontSize);
      ObjectSetInteger(0, startLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      
      // End point label
      string endLabel = StringFormat("FibEnd_%d", fibObjectsCounter-1);
      ObjectCreate(0, endLabel, OBJ_TEXT, 0, time2, price2);
      ObjectSetString(0, endLabel, OBJPROP_TEXT, StringFormat("Low: %.5f", price2));
      ObjectSetInteger(0, endLabel, OBJPROP_COLOR, FibLevelColor);
      ObjectSetInteger(0, endLabel, OBJPROP_FONTSIZE, FibLevelFontSize);
      ObjectSetInteger(0, endLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
   
   // Set Fibonacci levels
   int totalLevels = 0;
   if(ShowFibLevels)
   {
      totalLevels = ArraySize(FibLevels);
      for(int i = 0; i < totalLevels; i++)
      {
         ObjectSetDouble(0, fibName, OBJPROP_LEVELVALUE, i, FibLevels[i]);
         ObjectSetString(0, fibName, OBJPROP_LEVELTEXT, i, DoubleToString(FibLevels[i], 3) + " (" + DoubleToString(price1 - ((price1 - price2) * FibLevels[i]), 5) + ")");
      }
   }
   
   // Add extension levels if requested
   if(ShowExtensions)
   {
      int extensionsCount = ArraySize(FibExtensions);
      for(int i = 0; i < extensionsCount; i++)
      {
         ObjectSetDouble(0, fibName, OBJPROP_LEVELVALUE, totalLevels + i, FibExtensions[i]);
         ObjectSetString(0, fibName, OBJPROP_LEVELTEXT, totalLevels + i, DoubleToString(FibExtensions[i], 3) + " (" + DoubleToString(price1 - ((price1 - price2) * FibExtensions[i]), 5) + ")");
      }
      totalLevels += extensionsCount;
   }
   
   // Set level colors and styles
   ObjectSetInteger(0, fibName, OBJPROP_LEVELS, totalLevels);
   
   for(int i = 0; i < totalLevels; i++)
   {
      // Special formatting for key levels if enabled
      if(HighlightKeyLevels && (i == 3 || i == 4))  // 0.5 and 0.618 levels (index 3 and 4)
      {
         ObjectSetInteger(0, fibName, OBJPROP_LEVELCOLOR, i, clrRed);     // Highlight color
         ObjectSetInteger(0, fibName, OBJPROP_LEVELWIDTH, i, FibLinesWidth + 1); // Thicker line
      }
      else
      {
         ObjectSetInteger(0, fibName, OBJPROP_LEVELCOLOR, i, FibLinesColor);
         ObjectSetInteger(0, fibName, OBJPROP_LEVELWIDTH, i, FibLinesWidth);
      }
      
      ObjectSetInteger(0, fibName, OBJPROP_LEVELSTYLE, i, FibLinesStyle);
   }
   
   // Draw horizontal price lines at each Fibonacci level for better visibility
   if(ShowFibLevels)
   {
      for(int i = 0; i < ArraySize(FibLevels); i++)
      {
         double levelPrice = price1 - ((price1 - price2) * FibLevels[i]);
         string hLineName = StringFormat("FibHLine_%d_%d", fibObjectsCounter-1, i);
         
         // Create horizontal line
         ObjectCreate(0, hLineName, OBJ_HLINE, 0, 0, levelPrice);
         
         // Set line properties
         if(HighlightKeyLevels && (i == 3 || i == 4))  // 0.5 and 0.618 levels
         {
            ObjectSetInteger(0, hLineName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, hLineName, OBJPROP_WIDTH, FibLinesWidth + 1);
            ObjectSetInteger(0, hLineName, OBJPROP_STYLE, STYLE_DASH);
         }
         else
         {
            ObjectSetInteger(0, hLineName, OBJPROP_COLOR, FibLinesColor);
            ObjectSetInteger(0, hLineName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, hLineName, OBJPROP_STYLE, STYLE_DOT);
         }
         
         ObjectSetInteger(0, hLineName, OBJPROP_BACK, true);
         ObjectSetString(0, hLineName, OBJPROP_TOOLTIP, StringFormat("Fib %.3f: %.5f", FibLevels[i], levelPrice));
      }
   }
   
   // Add extension horizontal lines if requested
   if(ShowExtensions)
   {
      for(int i = 0; i < ArraySize(FibExtensions); i++)
      {
         double levelPrice = price1 - ((price1 - price2) * FibExtensions[i]);
         string hLineName = StringFormat("FibExtHLine_%d_%d", fibObjectsCounter-1, i);
         
         // Create horizontal line
         ObjectCreate(0, hLineName, OBJ_HLINE, 0, 0, levelPrice);
         
         // Set line properties
         ObjectSetInteger(0, hLineName, OBJPROP_COLOR, FibLinesColor);
         ObjectSetInteger(0, hLineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, hLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, hLineName, OBJPROP_BACK, true);
         ObjectSetString(0, hLineName, OBJPROP_TOOLTIP, StringFormat("Fib Ext %.3f: %.5f", FibExtensions[i], levelPrice));
      }
   }
   
   // Comment with details
   string status = isProvisional ? "PROVISIONAL" : "CONFIRMED";
   string comment = StringFormat("Auto Fibonacci 12PM (%s)\nPrevious day 12PM High: %.5f\nCurrent day 12PM Low: %.5f", 
                   status, price1, price2);
                   
   // Add historical info to comment if enabled
   if(HistoricalDays > 0)
   {
      comment += StringFormat("\nShowing %d historical days", HistoricalDays);
   }
   
   Comment(comment);
   
   // Force redraw to make sure everything is visible
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete all Fibonacci objects created by this indicator           |
//+------------------------------------------------------------------+
void DeleteFibObjects()
{
   int totalObjects = ObjectsTotal(0);
   
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objectName = ObjectName(0, i);
      if(StringFind(objectName, "FibRetracement_") == 0 ||
         StringFind(objectName, "FibStart_") == 0 ||
         StringFind(objectName, "FibEnd_") == 0 ||
         StringFind(objectName, "FibHLine_") == 0 ||
         StringFind(objectName, "FibExtHLine_") == 0 ||
         StringFind(objectName, "HistFib_") == 0)
      {
         ObjectDelete(0, objectName);
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove all objects created by this indicator
   DeleteFibObjects();
   Comment("");
   
   // Kill timer
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Process historical Fibonacci levels                               |
//+------------------------------------------------------------------+
void ProcessHistoricalFibonacci(const int rates_total, const datetime &time[], const double &high[], const double &low[])
{
   int actualHistDays = MathMin(HistoricalDays, 20);
   if(actualHistDays <= 0) return;
   
   // Current date information
   MqlDateTime currTime;
   TimeToStruct(TimeCurrent(), currTime);
   
   // Arrays to store found data
   datetime histDays[20];
   datetime histPrevDay12PM[20];
   datetime histCurrDay12PM[20];
   double histPrevDayHigh[20];
   double histCurrDayLow[20];
   int daysFound = 0;
   
   // Start from yesterday and go back
   for(int dayOffset = 1; dayOffset <= actualHistDays + 1; dayOffset++)
   {
      // Skip today
      if(dayOffset == 0) continue;
      
      // Calculate the date for current historical day and previous day
      MqlDateTime tempTime = currTime;
      tempTime.day -= dayOffset;
      
      // Handle month/year rollover
      while(tempTime.day < 1)
      {
         tempTime.mon--;
         if(tempTime.mon < 1)
         {
            tempTime.year--;
            tempTime.mon = 12;
         }
         
         // Set to last day of previous month (simplified)
         if(tempTime.mon == 2)
            tempTime.day += 28;
         else if(tempTime.mon == 4 || tempTime.mon == 6 || tempTime.mon == 9 || tempTime.mon == 11)
            tempTime.day += 30;
         else
            tempTime.day += 31;
      }
      
      // Store current historical day
      datetime histDay = StringToTime(StringFormat("%04d.%02d.%02d", 
                         tempTime.year, tempTime.mon, tempTime.day));
      
      // Calculate the previous day
      MqlDateTime prevTempTime = tempTime;
      prevTempTime.day -= 1;
      
      // Handle month/year rollover for previous day
      if(prevTempTime.day < 1)
      {
         prevTempTime.mon--;
         if(prevTempTime.mon < 1)
         {
            prevTempTime.year--;
            prevTempTime.mon = 12;
         }
         
         // Set to last day of previous month (simplified)
         if(prevTempTime.mon == 2)
            prevTempTime.day = 28;
         else if(prevTempTime.mon == 4 || prevTempTime.mon == 6 || prevTempTime.mon == 9 || prevTempTime.mon == 11)
            prevTempTime.day = 30;
         else
            prevTempTime.day = 31;
      }
      
      // Find previous day's high and current day's low (any hour, not just 12PM)
      datetime prevDayTime = 0, currDayTime = 0;
      double prevDayHigh = 0, currDayLow = 0;
      
      // Scan for both days' extremes
      for(int i = 0; i < rates_total; i++)
      {
         MqlDateTime canTime;
         TimeToStruct(time[i], canTime);
         
         // Look for previous day's high
         if(canTime.year == prevTempTime.year && canTime.mon == prevTempTime.mon && canTime.day == prevTempTime.day)
         {
            // First time we find the previous day
            if(prevDayTime == 0)
            {
               prevDayTime = time[i];
               prevDayHigh = high[i];
            }
            
            // Update high if higher
            if(high[i] > prevDayHigh)
            {
               prevDayHigh = high[i];
            }
         }
         
         // Look for current day's low
         if(canTime.year == tempTime.year && canTime.mon == tempTime.mon && canTime.day == tempTime.day)
         {
            // First time we find the current day
            if(currDayTime == 0)
            {
               currDayTime = time[i];
               currDayLow = low[i];
            }
            
            // Update low if lower
            if(low[i] < currDayLow || currDayLow == 0)
            {
               currDayLow = low[i];
            }
         }
      }
      
      // If we found valid data for this historical day, store it
      if(prevDayTime != 0 && currDayTime != 0 && prevDayHigh != 0 && currDayLow != 0)
      {
         histDays[daysFound] = histDay;
         histPrevDay12PM[daysFound] = prevDayTime;
         histCurrDay12PM[daysFound] = currDayTime;
         histPrevDayHigh[daysFound] = prevDayHigh;
         histCurrDayLow[daysFound] = currDayLow;
         daysFound++;
         
         // Draw the historical Fibonacci with faded color
         DrawHistoricalFibonacci(prevDayTime, prevDayHigh, currDayTime, currDayLow, dayOffset);
      }
      
      // Stop if we found enough days or reached the limit
      if(daysFound >= actualHistDays) break;
   }
   
   #ifdef DEBUG Print("Historical Fibonacci: Found and drawn ", daysFound, " historical days using daily high/low"); #endif 
}

//+------------------------------------------------------------------+
//| Draw historical Fibonacci levels with lower opacity              |
//+------------------------------------------------------------------+
void DrawHistoricalFibonacci(datetime time1, double price1, datetime time2, double price2, int dayOffset)
{
   // Create name for this historical Fibonacci
   string fibName = StringFormat("HistFib_%d_%d", dayOffset, fibObjectsCounter);
   
   // Create historical Fibonacci object
   ObjectCreate(0, fibName, OBJ_FIBO, 0, time1, price1, time2, price2);
   
   // Set object properties with reduced visibility
   ObjectSetInteger(0, fibName, OBJPROP_COLOR, HistoricalColor);
   ObjectSetInteger(0, fibName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, fibName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, fibName, OBJPROP_BACK, true);
   ObjectSetInteger(0, fibName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, fibName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, fibName, OBJPROP_RAY_RIGHT, false); // No ray for historical
   
   // Get date strings for label
   MqlDateTime t1, t2;
   TimeToStruct(time1, t1);
   TimeToStruct(time2, t2);
   string dateLabel = StringFormat("%02d.%02d → %02d.%02d", t1.day, t1.mon, t2.day, t2.mon);
   
   // Set Fibonacci levels
   if(ShowFibLevels)
   {
      for(int i = 0; i < ArraySize(FibLevels); i++)
      {
         ObjectSetDouble(0, fibName, OBJPROP_LEVELVALUE, i, FibLevels[i]);
         ObjectSetString(0, fibName, OBJPROP_LEVELTEXT, i, dateLabel + " " + DoubleToString(FibLevels[i], 3));
      }
   }
   
   // Add extension levels if requested
   if(ShowExtensions)
   {
      int levelCount = ArraySize(FibLevels);
      for(int i = 0; i < ArraySize(FibExtensions); i++)
      {
         ObjectSetDouble(0, fibName, OBJPROP_LEVELVALUE, levelCount + i, FibExtensions[i]);
         ObjectSetString(0, fibName, OBJPROP_LEVELTEXT, levelCount + i, dateLabel + " " + DoubleToString(FibExtensions[i], 3));
      }
   }
   
   // Set all level properties
   ObjectSetInteger(0, fibName, OBJPROP_LEVELS, ArraySize(FibLevels) + (ShowExtensions ? ArraySize(FibExtensions) : 0));
   
   for(int i = 0; i < ObjectGetInteger(0, fibName, OBJPROP_LEVELS); i++)
   {
      ObjectSetInteger(0, fibName, OBJPROP_LEVELCOLOR, i, HistoricalColor);
      ObjectSetInteger(0, fibName, OBJPROP_LEVELSTYLE, i, STYLE_DOT);
      ObjectSetInteger(0, fibName, OBJPROP_LEVELWIDTH, i, 1);
   }
}
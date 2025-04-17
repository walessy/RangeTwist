//+------------------------------------------------------------------+
//|                       MiddayAccumulationLines.mq5                |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website/Email"
#property version   "1.00"
#property script_show_inputs
#property strict

// Input parameters
input color  BullishColor = clrLimeGreen;   // Color for bullish candles
input color  BearishColor = clrRed;         // Color for bearish candles
input int    LineWidth = 2;                 // Width of lines in pixels
input bool   ShowValues = false;            // Show price values on lines
input bool   IncludeWeekends = false;       // Include weekend days

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Prefix for object names
   string objPrefix = "MidDayAccum_";
   
   // Clear any existing objects with our prefix
   ObjectsDeleteAll(0, objPrefix);
   
   // Get chart timeframe - works best with daily charts
   if(_Period > PERIOD_D1)
   {
      MessageBox("This script works best on D1 or lower timeframes", "Timeframe Warning", MB_ICONWARNING);
   }
   
   // Define midday time
   int midday_hour = 12;
   
   // Get available history
   datetime start_time = D'1970.01.01 00:00';  // Very old date to get all history
   datetime end_time = TimeCurrent();
   
   // First try to force load the full history
   Print("Loading historical data...");
   int available_bars = Bars(_Symbol, _Period, start_time, end_time);
   
   Print("Available bars: ", available_bars);
   
   if(available_bars <= 0)
   {
      Print("No historical data available");
      return;
   }
   
   // Get rates data
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, available_bars, rates) <= 0)
   {
      Print("Failed to copy rates data");
      return;
   }
   
   int rates_count = ArraySize(rates);
   Print("Copied ", rates_count, " bars for processing");
   
   // Variables for tracking
   int linesCount = 0;
   double accumulatedValue = 0;
   datetime lastMidDayTime = 0;
   double lastMidDayPrice = 0;
   bool firstMidDayFound = false;
   
   // Create a mapping of days to find midday candles
   datetime midday_candles[];
   int midday_count = 0;
   
   // First find all midday candles
   for(int i = rates_count - 1; i >= 0; i--)
   {
      MqlDateTime candle_time;
      TimeToStruct(rates[i].time, candle_time);
      
      // Skip weekends if requested
      if(!IncludeWeekends && (candle_time.day_of_week == 0 || candle_time.day_of_week == 6))
         continue;
      
      // For daily charts, each bar is a day, so we use those directly
      if(_Period == PERIOD_D1)
      {
         ArrayResize(midday_candles, midday_count + 1);
         midday_candles[midday_count++] = rates[i].time;
      }
      // For intraday charts, find candles that are closest to midday
      else
      {
         // Check if this candle is from a new day compared to previous
         if(i < rates_count - 1)
         {
            MqlDateTime prev_time;
            TimeToStruct(rates[i+1].time, prev_time);
            
            if(candle_time.day != prev_time.day || 
               candle_time.mon != prev_time.mon || 
               candle_time.year != prev_time.year)
            {
               // Find the candle closest to midday for this day
               datetime day_start = StringToTime(
                  StringFormat("%04d.%02d.%02d 00:00:00", 
                  candle_time.year, candle_time.mon, candle_time.day));
                  
               datetime target_midday = day_start + midday_hour * 3600;
               
               // Find closest candle
               datetime closest_time = rates[i].time;
               int j = i;
               
               while(j >= 0)
               {
                  MqlDateTime check_time;
                  TimeToStruct(rates[j].time, check_time);
                  
                  // If we've moved to the next day, break
                  if(check_time.day != candle_time.day || 
                     check_time.mon != candle_time.mon || 
                     check_time.year != candle_time.year)
                     break;
                  
                  // Check if this candle is closer to midday
                  if(MathAbs((int)rates[j].time - (int)target_midday) < 
                     MathAbs((int)closest_time - (int)target_midday))
                  {
                     closest_time = rates[j].time;
                  }
                  
                  j--;
               }
               
               // Save this midday candle
               ArrayResize(midday_candles, midday_count + 1);
               midday_candles[midday_count++] = closest_time;
            }
         }
      }
   }
   
   Print("Found ", midday_count, " midday candles for processing");
   
   // Now process the midday candles to create accumulation lines
   if(midday_count > 0)
   {
      // Start with the first midday candle
      int first_index = -1;
      for(int i = 0; i < rates_count; i++)
      {
         if(rates[i].time == midday_candles[0])
         {
            first_index = i;
            break;
         }
      }
      
      if(first_index >= 0)
      {
         lastMidDayTime = midday_candles[0];
         lastMidDayPrice = rates[first_index].open;
         accumulatedValue = lastMidDayPrice;
         firstMidDayFound = true;
         
         // Process each subsequent day
         for(int m = 1; m < midday_count; m++)
         {
            datetime currentMidDayTime = midday_candles[m];
            
            // Find candle index for this midday
            int current_index = -1;
            for(int i = 0; i < rates_count; i++)
            {
               if(rates[i].time == currentMidDayTime)
               {
                  current_index = i;
                  break;
               }
            }
            
            if(current_index >= 0)
            {
               double currentMidDayOpen = rates[current_index].open;
               double previousClose = 0;
               
               // Find the previous day's close
               for(int i = current_index - 1; i >= 0; i--)
               {
                  MqlDateTime check_time, current_mid_time;
                  TimeToStruct(rates[i].time, check_time);
                  TimeToStruct(currentMidDayTime, current_mid_time);
                  
                  if(check_time.day != current_mid_time.day || 
                     check_time.mon != current_mid_time.mon || 
                     check_time.year != current_mid_time.year)
                  {
                     previousClose = rates[i].close;
                     break;
                  }
               }
               
               // Calculate new accumulated value
               // For daily charts, accumulate from day to day
               if(_Period == PERIOD_D1)
               {
                  double dailyChange = currentMidDayOpen - previousClose;
                  accumulatedValue += dailyChange;
               }
               // For intraday, use the change from prev midday to current midday
               else
               {
                  double dailyChange = currentMidDayOpen - lastMidDayPrice;
                  accumulatedValue += dailyChange;
               }
               
               // Create a new line
               string objName = objPrefix + IntegerToString(linesCount);
               
               // FIXED: Determine line color based on whether accumulated value is higher or lower
               // than the previous value (not lastMidDayPrice)
               bool isUp = accumulatedValue < lastMidDayPrice;
               color lineColor = isUp ? BullishColor : BearishColor;
               
               // Draw a trend line from previous midday to current midday
               if(ObjectCreate(0, objName, OBJ_TREND, 0, lastMidDayTime, lastMidDayPrice, currentMidDayTime, accumulatedValue))
               {
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
                  ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
                  ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                  ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                  ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  
                  // Only log progress periodically
                  if(linesCount % 20 == 0)
                  {
                     Print("Created accumulation line #", linesCount, 
                           " at ", TimeToString(currentMidDayTime, TIME_DATE),
                           " value: ", DoubleToString(accumulatedValue, _Digits));
                  }
                  
                  linesCount++;
               }
               
               // Add text label if requested
               if(ShowValues)
               {
                  string labelName = objPrefix + "Label_" + IntegerToString(linesCount-1);
                  string labelText = DoubleToString(accumulatedValue, _Digits);
                  
                  ObjectCreate(0, labelName, OBJ_TEXT, 0, currentMidDayTime, accumulatedValue);
                  ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
                  ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
                  ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
                  ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
                  ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
               }
               
               // Update for next iteration
               lastMidDayTime = currentMidDayTime;
               lastMidDayPrice = accumulatedValue;
            }
         }
      }
   }
   
   // Report final results
   Print("Created ", linesCount, " accumulation lines");
   ChartRedraw(0);
}
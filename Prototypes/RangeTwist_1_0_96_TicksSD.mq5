//+------------------------------------------------------------------+
//|                                                RangeTwistTick.mq5 |
//|                                                                   |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Based on RangeTwist by Amos"
#property version   "1.0.0"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   4

// Main line plot (RangeTwist line)
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2
#property indicator_label1  "Range Line"

// Standard deviation lines
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_width2  1
#property indicator_style2  STYLE_DASH
#property indicator_label2  "1 StdDev"

#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_width3  1
#property indicator_style3  STYLE_DASH
#property indicator_label3  "2 StdDev"

#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMagenta
#property indicator_width4  1
#property indicator_style4  STYLE_DASH
#property indicator_label4  "3 StdDev"

// Input parameters
input color  UpColor = clrLime;         // Color for up trend
input color  DownColor = clrRed;        // Color for down trend
input int    RangeSize = 25;            // Range size in points
input bool   UseTickData = true;        // Use tick data instead of bar data

// Indicator buffers
double LineBuffer[];      // Main range line
double ColorBuffer[];     // Color index for the main line
double StdDev1Buffer[];   // 1 Standard Deviation
double StdDev2Buffer[];   // 2 Standard Deviations
double StdDev3Buffer[];   // 3 Standard Deviations
double LegPeriods[];      // Store leg durations
double SquaredDiffs[];    // Sum of squared differences

// Global variables
double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;
double mean = 0;
double sumSquared = 0;
double stdDev = 0;
int legCount = 0;
int currentLegStart = 0;
datetime lastTickTime = 0;

// Arrays to store leg data for statistics
double legLevels[];       // Store price levels at each leg
datetime legTimes[];      // Store times of each leg change
datetime currentTickTime;

// For real-time tick tracking
MqlTick lastTick;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, StdDev1Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, StdDev2Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, StdDev3Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, LegPeriods, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, SquaredDiffs, INDICATOR_CALCULATIONS);

   // Initialize with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   ArrayInitialize(StdDev1Buffer, EMPTY_VALUE);
   ArrayInitialize(StdDev2Buffer, EMPTY_VALUE);
   ArrayInitialize(StdDev3Buffer, EMPTY_VALUE);
   
   // Initialize arrays for leg data
   ArrayResize(legLevels, 1000);  // Allow for up to 1000 legs
   ArrayResize(legTimes, 1000);   // Allow for up to 1000 legs
   
   // Set plot properties
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   
   // Set point value for the current symbol
   point = _Point;
   
   // Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "RangeTwistTick");
   
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
   // Ensure we have enough bars
   if(rates_total < 2) return(0);
   
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset indicators and initialize
      ArrayInitialize(LineBuffer, EMPTY_VALUE);
      ArrayInitialize(StdDev1Buffer, EMPTY_VALUE);
      ArrayInitialize(StdDev2Buffer, EMPTY_VALUE);
      ArrayInitialize(StdDev3Buffer, EMPTY_VALUE);
      
      // Reset leg data
      legCount = 0;
      ArrayInitialize(legLevels, 0);
      ArrayInitialize(legTimes, 0);
      
      // Initialize with current price
      if(rates_total > 0)
      {
         currentLevel = close[rates_total-1]; // Use the most recent close
         prevLevel = currentLevel;
         lastRangeBarIndex = rates_total-1;
         upTrend = true;
         
         // Fill the buffer with the current level
         for(int i=0; i<rates_total; i++)
         {
            LineBuffer[i] = currentLevel;
            ColorBuffer[i] = 0; // Start with up color
         }
         
         // Record initial leg
         legLevels[0] = currentLevel;
         legTimes[0] = time[rates_total-1];
         legCount = 1; // Start with 1 leg
         currentLegStart = rates_total-1;
         
         // Print debug info
         Print("Indicator initialized at price: ", currentLevel, " at time: ", TimeToString(time[rates_total-1]));
      }
   }
   
   // Determine start position for calculations
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   // If we're using tick data, get the latest tick
   if(UseTickData)
   {
      bool gotTick = SymbolInfoTick(_Symbol, lastTick);
      if(gotTick)
      {
         currentTickTime = lastTick.time;
         // Only process the tick if it's new
         if(currentTickTime != lastTickTime)
         {
            lastTickTime = currentTickTime;
            CheckTickForRange(lastTick, rates_total-1, time[rates_total-1]);
         }
      }
   }
   else
   {
      // Traditional bar-based processing
      for(int i = start; i < rates_total; i++)
      {
         CalculateRange(i, high[i], low[i], rates_total, time[i]);
      }
   }
   
   // Calculate standard deviations after all range levels are set
   CalculateStatistics(rates_total);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Process each tick for range breakouts                            |
//+------------------------------------------------------------------+
void CheckTickForRange(MqlTick &tick, int currentBarIndex, datetime barTime)
{
   double range = RangeSize * point;
   double tickPrice = tick.last; // Using last price from the tick
   bool levelChanged = false;
   
   prevLevel = currentLevel; // Store previous level
   
   if(upTrend)
   {
      if(tickPrice >= currentLevel + range)
      {
         // Move the line up
         currentLevel = currentLevel + range;
         LineBuffer[currentBarIndex] = currentLevel;
         ColorBuffer[currentBarIndex] = 0; // Up color
         lastRangeBarIndex = currentBarIndex;
         levelChanged = true;
         
         // Record leg data for continued trend moves
         RecordLegData(barTime);
         Print("Up move at price: ", tickPrice, " New level: ", currentLevel);
      }
      else if(tickPrice <= currentLevel - range)
      {
         // Trend has reversed to down
         upTrend = false;
         currentLevel = currentLevel - range;
         LineBuffer[currentBarIndex] = currentLevel;
         ColorBuffer[currentBarIndex] = 1; // Down color
         lastRangeBarIndex = currentBarIndex;
         levelChanged = true;
         
         // Record leg data for trend reversals
         RecordLegData(barTime);
         Print("Trend reversed DOWN at price: ", tickPrice, " New level: ", currentLevel);
      }
      else
      {
         // No change in level, update the current bar
         LineBuffer[currentBarIndex] = currentLevel;
         ColorBuffer[currentBarIndex] = 0; // Up color
      }
   }
   else // downtrend
   {
      if(tickPrice <= currentLevel - range)
      {
         // Move the line down
         currentLevel = currentLevel - range;
         LineBuffer[currentBarIndex] = currentLevel;
         ColorBuffer[currentBarIndex] = 1; // Down color
         lastRangeBarIndex = currentBarIndex;
         levelChanged = true;
         
         // Record leg data for continued trend moves
         RecordLegData(barTime);
         Print("Down move at price: ", tickPrice, " New level: ", currentLevel);
      }
      else if(tickPrice >= currentLevel + range)
      {
         // Trend has reversed to up
         upTrend = true;
         currentLevel = currentLevel + range;
         LineBuffer[currentBarIndex] = currentLevel;
         ColorBuffer[currentBarIndex] = 0; // Up color
         lastRangeBarIndex = currentBarIndex;
         levelChanged = true;
         
         // Record leg data for trend reversals
         RecordLegData(barTime);
         Print("Trend reversed UP at price: ", tickPrice, " New level: ", currentLevel);
      }
      else
      {
         // No change in level, update the current bar
         LineBuffer[currentBarIndex] = currentLevel;
         ColorBuffer[currentBarIndex] = 1; // Down color
      }
   }
   
   // Fill previous bars with current value to avoid gaps
   for(int i = 0; i < currentBarIndex; i++)
   {
      if(LineBuffer[i] == EMPTY_VALUE)
      {
         LineBuffer[i] = currentLevel;
         ColorBuffer[i] = upTrend ? 0 : 1;
      }
   }
   
   // Calculate squared difference for statistics
   if(levelChanged) {
      double diff = currentLevel - prevLevel;
      SquaredDiffs[currentBarIndex] = diff * diff;
   }
}

//+------------------------------------------------------------------+
//| Record data for each leg                                         |
//+------------------------------------------------------------------+
void RecordLegData(datetime barTime)
{
   // Make sure we don't exceed array bounds
   if(legCount >= ArraySize(legLevels))
   {
      ArrayResize(legLevels, legCount + 100);
      ArrayResize(legTimes, legCount + 100);
   }
   
   // Store leg data
   legLevels[legCount] = currentLevel;
   legTimes[legCount] = barTime;
   
   // Calculate leg duration if we have at least two leg points
   if(legCount > 0)
   {
      // Duration in seconds
      long duration = barTime - legTimes[legCount-1];
      LegPeriods[legCount] = (double)duration;
   }
   
   legCount++;
   
   Print("Leg #", legCount, " recorded at level: ", currentLevel, " time: ", TimeToString(barTime));
}

//+------------------------------------------------------------------+
//| Calculate range levels (for bar data mode)                       |
//+------------------------------------------------------------------+
void CalculateRange(int bar_index, double high, double low, int rates_total, datetime barTime)
{
   double range = RangeSize * point;
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   prevLevel = currentLevel; // Store previous level
   
   if(upTrend)
   {
      if(high >= currentLevel + range)
      {
         // Move the line up
         currentLevel = currentLevel + range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
      }
      else if(low <= currentLevel - range)
      {
         // Trend has reversed to down
         upTrend = false;
         currentLevel = currentLevel - range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
         
         // Record leg data
         RecordLegData(barTime);
      }
      else
      {
         // No change in level, copy the last value
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
      }
   }
   else // downtrend
   {
      if(low <= currentLevel - range)
      {
         // Move the line down
         currentLevel = currentLevel - range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
      }
      else if(high >= currentLevel + range)
      {
         // Trend has reversed to up
         upTrend = true;
         currentLevel = currentLevel + range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
         
         // Record leg data
         RecordLegData(barTime);
      }
      else
      {
         // No change in level, copy the last value
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
      }
   }
   
   // Calculate squared difference for statistics
   if(prevLevel != currentLevel) {
      double diff = currentLevel - prevLevel;
      SquaredDiffs[bar_index] = diff * diff;
   }
}

//+------------------------------------------------------------------+
//| Calculate statistical measures                                   |
//+------------------------------------------------------------------+
void CalculateStatistics(int bars)
{
   // Only perform calculations if we have recorded legs
   if(legCount <= 0) 
   {
      Comment("No legs recorded yet. Waiting for price movement...");
      return;
   }
   
   // Debug output - print all leg values
   string debugLegs = "";
   for(int i=0; i < MathMin(legCount, 10); i++)
   {
      debugLegs += StringFormat("Leg %d: %.5f at %s\n", 
                   i, legLevels[i], TimeToString(legTimes[i]));
   }
   Print("Debug leg data:\n", debugLegs);
   
   // Calculate mean using only the leg levels
   double sum = 0;
   
   // First pass: calculate mean of leg levels
   for(int i = 0; i < legCount; i++)
   {
      sum += legLevels[i];
   }
   
   mean = sum / legCount;
   
   // Second pass: calculate standard deviation using only leg levels
   sumSquared = 0;
   for(int i = 0; i < legCount; i++)
   {
      double diff = legLevels[i] - mean;
      sumSquared += diff * diff;
   }
   
   if(legCount > 1)
      stdDev = MathSqrt(sumSquared / (legCount - 1));
   else
      stdDev = 0;
   
   // Calculate and plot standard deviation levels for all bars
   for(int i = 0; i < bars; i++)
   {
      StdDev1Buffer[i] = mean + stdDev;
      StdDev2Buffer[i] = mean + 2 * stdDev;
      StdDev3Buffer[i] = mean + 3 * stdDev;
   }
   
   // Calculate average leg duration in appropriate time units
   string durationUnit = "seconds";
   double avgLegDuration = 0;
   
   if(legCount > 1)
   {
      double sumDuration = 0;
      int validLegs = 0;
      
      for(int i = 1; i < legCount; i++) // Start from 1 to have valid durations
      {
         if(LegPeriods[i] > 0)
         {
            sumDuration += LegPeriods[i];
            validLegs++;
         }
      }
      
      if(validLegs > 0)
         avgLegDuration = sumDuration / validLegs;
      
      // Convert to more readable units if needed
      if(avgLegDuration > 86400) // More than a day
      {
         avgLegDuration /= 86400;
         durationUnit = "days";
      }
      else if(avgLegDuration > 3600) // More than an hour
      {
         avgLegDuration /= 3600;
         durationUnit = "hours";
      }
      else if(avgLegDuration > 60) // More than a minute
      {
         avgLegDuration /= 60;
         durationUnit = "minutes";
      }
   }
   
   // Get current price for comparison
   double currentPrice = 0;
   MqlTick latestTick;
   if(SymbolInfoTick(_Symbol, latestTick))
   {
      currentPrice = latestTick.last;
   }
   
   // Display statistics on the chart
   string infoText = "Current Price: " + DoubleToString(currentPrice, 5) +
                     "\nCurrent Level: " + DoubleToString(currentLevel, 5) +
                     "\nMean: " + DoubleToString(mean, 5) + 
                     "\nStdDev: " + DoubleToString(stdDev, 5) +
                     "\nSum Squared: " + DoubleToString(sumSquared, 2) +
                     "\nLeg Count: " + IntegerToString(legCount) +
                     "\nAvg Leg Duration: " + DoubleToString(avgLegDuration, 2) + " " + durationUnit +
                     "\nData Mode: " + (UseTickData ? "Tick Data" : "Bar Data") +
                     "\nTrend: " + (upTrend ? "UP" : "DOWN");
   
   Comment(infoText);
}
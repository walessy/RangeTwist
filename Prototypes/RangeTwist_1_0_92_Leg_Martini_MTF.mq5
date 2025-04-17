//+------------------------------------------------------------------+
//|                                         RangeTwist_MTF.mq5      |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   3
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed, clrGray
#property indicator_color2  clrAqua, clrMagenta, clrSilver
#property indicator_color3  clrGold, clrIndigo, clrDimGray
#property indicator_width1  2
#property indicator_width2  2
#property indicator_width3  2

// Main timeframe parameters
input int    InitialRangeSize = 25;     // Initial range size in points
input bool   ForceCommonRangeSize = true; // Force all timeframes to use same range size
input int    MaxLegsToTrack = 5;        // Number of legs to track for statistics
input double TrendFactor = 1.2;         // Range adjustment factor for strong trends
input double ChoppyFactor = 0.8;        // Range adjustment factor for choppy markets
input double VolatilityCapFactor = 2.0; // Max allowed deviation from average (multiplier)

// Multi-timeframe settings
input ENUM_TIMEFRAMES TimeFrame1 = PERIOD_CURRENT; // Primary timeframe
input ENUM_TIMEFRAMES TimeFrame2 = PERIOD_H1;      // Secondary timeframe
input ENUM_TIMEFRAMES TimeFrame3 = PERIOD_H4;      // Tertiary timeframe
input bool   EnableTF1 = true;          // Enable primary timeframe
input bool   EnableTF2 = true;          // Enable secondary timeframe
input bool   EnableTF3 = true;          // Enable tertiary timeframe
input int    SyncAlignmentMode = 1;     // Alignment mode: 0-None, 1-Standard, 2-Strict

// Visual settings
input color  UpColor = clrLime;         // TF1 - Up trend color
input color  DownColor = clrRed;        // TF1 - Down trend color
input color  FlatColor = clrGray;       // TF1 - No trend color
input color  UpColor2 = clrAqua;        // TF2 - Up trend color
input color  DownColor2 = clrMagenta;   // TF2 - Down trend color
input color  FlatColor2 = clrSilver;    // TF2 - No trend color
input color  UpColor3 = clrGold;        // TF3 - Up trend color
input color  DownColor3 = clrIndigo;    // TF3 - Down trend color
input color  FlatColor3 = clrDimGray;   // TF3 - No trend color

// General settings
input bool   IncLstCndl = false;        // Include last candle
input bool   EnableDynamicRange = true; // Enable dynamic range calculation
input bool   ShowStats = true;          // Show statistics on chart

// Buffers for all timeframes
double LineBuffer1[];         // Range line TF1
double ColorBuffer1[];        // Color index for TF1
double LineBuffer2[];         // Range line TF2
double ColorBuffer2[];        // Color index for TF2
double LineBuffer3[];         // Range line TF3
double ColorBuffer3[];        // Color index for TF3

// Data used by all timeframes
struct TimeframeData {
   double currentLevel;
   double prevLevel;
   int lastRangeBarIndex;
   bool upTrend;
   int currentRangeSize;
   datetime lastBarTime;
   int currentBar;           // Current bar being processed
};

TimeframeData tf1Data, tf2Data, tf3Data;

// Leg history tracking
struct LegInfo {
   double size;              // Size of the leg in points
   bool isUpleg;             // Direction of the leg
   datetime time;            // Time when leg completed
};

// Separate leg histories for each timeframe
LegInfo legHistoryTF1[];
LegInfo legHistoryTF2[];
LegInfo legHistoryTF3[];

// Global variables
double point;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   SetIndexBuffer(0, LineBuffer1, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer1, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, LineBuffer2, INDICATOR_DATA);
   SetIndexBuffer(3, ColorBuffer2, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, LineBuffer3, INDICATOR_DATA);
   SetIndexBuffer(5, ColorBuffer3, INDICATOR_COLOR_INDEX);
   
   // Initialize buffers with EMPTY_VALUE
   ArrayInitialize(LineBuffer1, EMPTY_VALUE);
   ArrayInitialize(LineBuffer2, EMPTY_VALUE);
   ArrayInitialize(LineBuffer3, EMPTY_VALUE);
   
   // Set up colors and styles for each timeframe
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, FlatColor);
   PlotIndexSetString(0, PLOT_LABEL, "Range Line TF1 (" + TimeframeToString(TimeFrame1) + ")");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, UpColor2);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, DownColor2);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 2, FlatColor2);
   PlotIndexSetString(1, PLOT_LABEL, "Range Line TF2 (" + TimeframeToString(TimeFrame2) + ")");
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2);
   
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, UpColor3);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 1, DownColor3);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 2, FlatColor3);
   PlotIndexSetString(2, PLOT_LABEL, "Range Line TF3 (" + TimeframeToString(TimeFrame3) + ")");
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 2);
   
   // Hide plots based on settings
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, EnableTF1 ? DRAW_COLOR_LINE : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, EnableTF2 ? DRAW_COLOR_LINE : DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, EnableTF3 ? DRAW_COLOR_LINE : DRAW_NONE);
   
   // Enhanced tooltip information for each buffer
   string tf1Tooltip = "TF1 (" + TimeframeToString(TimeFrame1) + ") Level: %$[close]\nRange Size: " + IntegerToString(InitialRangeSize);
   string tf2Tooltip = "TF2 (" + TimeframeToString(TimeFrame2) + ") Level: %$[close]\nRange Size: " + IntegerToString(InitialRangeSize);
   string tf3Tooltip = "TF3 (" + TimeframeToString(TimeFrame3) + ") Level: %$[close]\nRange Size: " + IntegerToString(InitialRangeSize);
   
   PlotIndexSetString(0, PLOT_TOOLTIP, tf1Tooltip);
   PlotIndexSetString(1, PLOT_TOOLTIP, tf2Tooltip);
   PlotIndexSetString(2, PLOT_TOOLTIP, tf3Tooltip);
   
   // Initialize state variables
   point = _Point;
   
   // Initialize all timeframe data
   InitializeTimeframeData(tf1Data, InitialRangeSize);
   InitializeTimeframeData(tf2Data, InitialRangeSize);
   InitializeTimeframeData(tf3Data, InitialRangeSize);
   
   // Initialize leg history arrays
   ArrayResize(legHistoryTF1, 0);
   ArrayResize(legHistoryTF2, 0);
   ArrayResize(legHistoryTF3, 0);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize timeframe data structure                              |
//+------------------------------------------------------------------+
void InitializeTimeframeData(TimeframeData &data, int rangeSize)
{
   data.currentLevel = 0;
   data.prevLevel = 0;
   data.lastRangeBarIndex = 0;
   data.upTrend = true;
   data.currentRangeSize = rangeSize;
   data.lastBarTime = 0;
   data.currentBar = 0;
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
   if(rates_total < 2) return(0);
   
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset buffers
      ArrayInitialize(LineBuffer1, EMPTY_VALUE);
      ArrayInitialize(LineBuffer2, EMPTY_VALUE);
      ArrayInitialize(LineBuffer3, EMPTY_VALUE);
      
      // Reset leg histories
      ArrayResize(legHistoryTF1, 0);
      ArrayResize(legHistoryTF2, 0);
      ArrayResize(legHistoryTF3, 0);
      
      // Initialize values for each timeframe
      if(rates_total > 0 && EnableTF1)
      {
         tf1Data.currentLevel = close[0];
         tf1Data.prevLevel = close[0];
         LineBuffer1[0] = tf1Data.currentLevel;
         ColorBuffer1[0] = 2; // Start with flat color
      }
      
      if(rates_total > 0 && EnableTF2)
      {
         tf2Data.currentLevel = close[0];
         tf2Data.prevLevel = close[0];
         LineBuffer2[0] = tf2Data.currentLevel;
         ColorBuffer2[0] = 2; // Start with flat color
      }
      
      if(rates_total > 0 && EnableTF3)
      {
         tf3Data.currentLevel = close[0];
         tf3Data.prevLevel = close[0];
         LineBuffer3[0] = tf3Data.currentLevel;
         ColorBuffer3[0] = 2; // Start with flat color
      }
   }
   
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   int limit = rates_total;
   
   // Calculate for each timeframe
   if(EnableTF1) {
      CalculateTimeframe(rates_total, start, limit, time, high, low, close, TimeFrame1, 
                         tf1Data, legHistoryTF1, LineBuffer1, ColorBuffer1);
   }
   
   if(EnableTF2) {
      CalculateTimeframe(rates_total, start, limit, time, high, low, close, TimeFrame2, 
                         tf2Data, legHistoryTF2, LineBuffer2, ColorBuffer2);
   }
   
   if(EnableTF3) {
      CalculateTimeframe(rates_total, start, limit, time, high, low, close, TimeFrame3, 
                         tf3Data, legHistoryTF3, LineBuffer3, ColorBuffer3);
   }
   
   // Show statistics if enabled
   if(ShowStats) {
      PrintMTFStatistics();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate for a specific timeframe                               |
//+------------------------------------------------------------------+
void CalculateTimeframe(const int rates_total, 
                      const int start, 
                      const int limit,
                      const datetime &time[],
                      const double &high[],
                      const double &low[],
                      const double &close[],
                      ENUM_TIMEFRAMES timeframe,
                      TimeframeData &tfData,
                      LegInfo &legHistory[],
                      double &lineBuffer[],
                      double &colorBuffer[])
{
   // If using current timeframe, process directly
   if(timeframe == PERIOD_CURRENT || timeframe == Period()) {
      for(int i = start; i < limit; i++) {
         if(i == rates_total - 1 && !IncLstCndl) {
            // Skip last candle if configured
            if(i > 0) {
               lineBuffer[i] = lineBuffer[i-1];
               colorBuffer[i] = colorBuffer[i-1];
            }
         } else {
            // Update range dynamically if enabled
            if(EnableDynamicRange && ArraySize(legHistory) > 0) {
               tfData.currentRangeSize = CalculateDynamicRangeSize(legHistory);
            }
            
            // Calculate range for current bar
            CalculateRange(i, high[i], low[i], rates_total, time[i], tfData, legHistory, lineBuffer, colorBuffer);
         }
      }
   } else {
      // This is a different timeframe - need to map its data to current chart
      MqlRates rates[];
      
      // Get rates for the specified timeframe
      int copied = CopyRates(Symbol(), timeframe, 0, rates_total, rates);
      if(copied > 0) {
         // Process each bar from current chart
         for(int i = start; i < limit; i++) {
            if(i == rates_total - 1 && !IncLstCndl) {
               // Skip last candle if configured
               if(i > 0) {
                  lineBuffer[i] = lineBuffer[i-1];
                  colorBuffer[i] = colorBuffer[i-1];
               }
               continue;
            }
            
            // Find the bar from higher timeframe that contains this time
            datetime current_time = time[i];
            
            // If it's the first calculation, initialize
            if(tfData.currentLevel == 0) {
               tfData.currentLevel = close[i];
               tfData.prevLevel = close[i];
               lineBuffer[i] = tfData.currentLevel;
               colorBuffer[i] = 2; // Flat color
               continue;
            }
            
            // Find the corresponding higher timeframe bar using a more precise method
            bool found = false;
            MqlRates higher_bar;
            int bar_shift = iBarShift(Symbol(), timeframe, current_time, false);
            
            if(bar_shift != -1) {
               // Successfully found the corresponding bar
               datetime bar_time = iTime(Symbol(), timeframe, bar_shift);
               
               // Get the complete bar data
               MqlRates bar_data[1];
               if(CopyRates(Symbol(), timeframe, bar_shift, 1, bar_data) == 1) {
                  higher_bar = bar_data[0];
                  found = true;
               }
            }
            
            // Fallback to manual search if iBarShift failed
            if(!found) {
               for(int j = 0; j < copied; j++) {
                  // Check if this bar's time falls within the higher timeframe bar
                  if(timeframe == PERIOD_MN1 || timeframe == PERIOD_W1) {
                     // For weekly/monthly, just compare if time is greater than bar open time
                     if(current_time >= rates[j].time && 
                        (j == copied - 1 || current_time < rates[j+1].time)) {
                        higher_bar = rates[j];
                        found = true;
                        break;
                     }
                  } else {
                     // For other timeframes, calculate bar time range
                     datetime bar_start = rates[j].time;
                     datetime bar_end = (j < copied - 1) ? rates[j+1].time : bar_start + PeriodSeconds(timeframe);
                     
                     if(current_time >= bar_start && current_time < bar_end) {
                        higher_bar = rates[j];
                        found = true;
                        break;
                     }
                  }
               }
            }
            
            // If we found a corresponding higher TF bar
            if(found) {
               // Check if this is a new bar in the higher timeframe
               bool isNewBar = (higher_bar.time != tfData.lastBarTime);
               tfData.lastBarTime = higher_bar.time;
               
               // If it's a new higher TF bar, update the range if needed
               if(isNewBar && EnableDynamicRange && ArraySize(legHistory) > 0) {
                  tfData.currentRangeSize = CalculateDynamicRangeSize(legHistory);
               }
               
               // For proper alignment between timeframes, we need to:
               // 1. Calculate range levels at exact higher timeframe bar boundaries
               // 2. Propagate those levels across all current timeframe bars
               
               if(SyncAlignmentMode == 2) {
                  // Strict alignment - only calculate at the exact timeframe shift points
                  // and ensure all other bars precisely match
                  if(isNewBar) {
                     // Calculate range using the higher timeframe bar data
                     CalculateRange(i, higher_bar.high, higher_bar.low, rates_total, higher_bar.time, 
                                  tfData, legHistory, lineBuffer, colorBuffer);
                                  
                     // Go back and update all bars since the last calculation to match this level
                     if(tfData.currentBar > 0) {
                        for(int k = tfData.currentBar; k < i; k++) {
                           lineBuffer[k] = tfData.currentLevel;
                           colorBuffer[k] = colorBuffer[i];
                        }
                     }
                  } else {
                     // Not a new bar, propagate the level
                     lineBuffer[i] = tfData.currentLevel;
                     colorBuffer[i] = colorBuffer[tfData.currentBar];
                  }
               } else if(SyncAlignmentMode == 1) {
                  // Standard alignment - calculate at timeframe boundaries but allow for some flexibility
                  if(isNewBar || i == start) {
                     // Calculate range using the higher timeframe bar data with adjusted range
                     // For better alignment, force the range size to be identical to current timeframe
                     int savedRangeSize = tfData.currentRangeSize;
                     
                     // When timeframe is not current, align range size with current TF for consistency
                     if(timeframe != PERIOD_CURRENT && timeframe != Period() && tf1Data.currentRangeSize > 0) {
                        tfData.currentRangeSize = tf1Data.currentRangeSize;
                     }
                     
                     CalculateRange(i, higher_bar.high, higher_bar.low, rates_total, higher_bar.time, 
                                  tfData, legHistory, lineBuffer, colorBuffer);
                                  
                     // Restore original range size for future dynamic calculations
                     if(savedRangeSize != tfData.currentRangeSize) {
                        tfData.currentRangeSize = savedRangeSize;
                     }
                  } else {
                     // Not a new bar, propagate the level from the last calculation
                     lineBuffer[i] = lineBuffer[i-1];
                     colorBuffer[i] = colorBuffer[i-1];
                  }
               } else {
                  // No special alignment - just calculate normally
                  CalculateRange(i, higher_bar.high, higher_bar.low, rates_total, higher_bar.time, 
                               tfData, legHistory, lineBuffer, colorBuffer);
               }
               
               // Store the exact level in the data structure for current bar
               // This helps ensure alignment across all visual outputs
               tfData.currentBar = i;
            } else {
               // No corresponding higher TF bar found, copy previous value
               if(i > 0) {
                  lineBuffer[i] = lineBuffer[i-1];
                  colorBuffer[i] = colorBuffer[i-1];
               } else {
                  lineBuffer[i] = close[i];
                  colorBuffer[i] = 2; // Flat color
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate range level for each bar                               |
//+------------------------------------------------------------------+
void CalculateRange(int bar_index, double high, double low, int rates_total, datetime time,
                  TimeframeData &tfData, LegInfo &legHistory[], double &lineBuffer[], double &colorBuffer[])
{
   double range = tfData.currentRangeSize * point;
   bool legCompleted = false;
   bool wasUpTrend = tfData.upTrend;
   double oldLevel = tfData.currentLevel;
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(tfData.upTrend)
   {
      if(high >= tfData.currentLevel + range)
      {
         // Move the line up
         tfData.prevLevel = tfData.currentLevel;
         tfData.currentLevel = tfData.currentLevel + range;
         lineBuffer[bar_index] = tfData.currentLevel;
         colorBuffer[bar_index] = 0; // Up color
         tfData.lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(low <= tfData.currentLevel - range)
      {
         // Trend has reversed to down
         tfData.prevLevel = tfData.currentLevel;
         tfData.upTrend = false;
         tfData.currentLevel = tfData.currentLevel - range;
         lineBuffer[bar_index] = tfData.currentLevel;
         colorBuffer[bar_index] = 1; // Down color
         tfData.lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else
      {
         // No change in level, copy the last value
         lineBuffer[bar_index] = tfData.currentLevel;
         colorBuffer[bar_index] = 0; // Up color
      }
   }
   else // downtrend
   {
      if(low <= tfData.currentLevel - range)
      {
         // Move the line down
         tfData.prevLevel = tfData.currentLevel;
         tfData.currentLevel = tfData.currentLevel - range;
         lineBuffer[bar_index] = tfData.currentLevel;
         colorBuffer[bar_index] = 1; // Down color
         tfData.lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(high >= tfData.currentLevel + range)
      {
         // Trend has reversed to up
         tfData.prevLevel = tfData.currentLevel;
         tfData.upTrend = true;
         tfData.currentLevel = tfData.currentLevel + range;
         lineBuffer[bar_index] = tfData.currentLevel;
         colorBuffer[bar_index] = 0; // Up color
         tfData.lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else
      {
         // No change in level, copy the last value
         lineBuffer[bar_index] = tfData.currentLevel;
         colorBuffer[bar_index] = 1; // Down color
      }
   }
   
   // If a leg was completed, add it to history
   if(legCompleted) {
      AddCompletedLeg(MathAbs(tfData.currentLevel - tfData.prevLevel) / point, wasUpTrend, time, legHistory);
   }
}

//+------------------------------------------------------------------+
//| Add a completed leg to history                                  |
//+------------------------------------------------------------------+
void AddCompletedLeg(double size, bool isUpleg, datetime time, LegInfo &legHistory[])
{
   // Create new leg info
   LegInfo newLeg;
   newLeg.size = size;
   newLeg.isUpleg = isUpleg;
   newLeg.time = time;
   
   // Add to array
   int historySize = ArraySize(legHistory);
   ArrayResize(legHistory, historySize + 1);
   legHistory[historySize] = newLeg;
   
   // If we have more legs than we want to track, remove oldest
   if(ArraySize(legHistory) > MaxLegsToTrack) {
      for(int i = 0; i < ArraySize(legHistory) - 1; i++) {
         legHistory[i] = legHistory[i + 1];
      }
      ArrayResize(legHistory, MaxLegsToTrack);
   }
}

//+------------------------------------------------------------------+
//| Print statistics for all enabled timeframes                      |
//+------------------------------------------------------------------+
void PrintMTFStatistics()
{
   string info = "";
   
   // Add TF1 stats if enabled
   if(EnableTF1) {
      info += "Timeframe 1 (" + TimeframeToString(TimeFrame1) + "):\n";
      info += GetTimeframeStats(legHistoryTF1, tf1Data.currentRangeSize);
      info += "\n\n";
   }
   
   // Add TF2 stats if enabled
   if(EnableTF2) {
      info += "Timeframe 2 (" + TimeframeToString(TimeFrame2) + "):\n";
      info += GetTimeframeStats(legHistoryTF2, tf2Data.currentRangeSize);
      info += "\n\n";
   }
   
   // Add TF3 stats if enabled
   if(EnableTF3) {
      info += "Timeframe 3 (" + TimeframeToString(TimeFrame3) + "):\n";
      info += GetTimeframeStats(legHistoryTF3, tf3Data.currentRangeSize);
   }
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| Get statistics for a specific timeframe                          |
//+------------------------------------------------------------------+
string GetTimeframeStats(LegInfo &legHistory[], int currentRangeSize)
{
   int count = ArraySize(legHistory);
   if(count == 0) return "No data yet";
   
   string info = "Leg History (newest first): ";
   for(int i = count - 1; i >= 0; i--) {
      info += StringFormat("%s%.1f", legHistory[i].isUpleg ? "↑" : "↓", legHistory[i].size);
      if(i > 0) info += ", ";
   }
   
   double avgSize = CalculateAverageLegSize(legHistory);
   double stdDev = CalculateStandardDeviation(legHistory, avgSize);
   int consecutiveCount = CalculateConsecutiveLegs(legHistory);
   
   info += StringFormat("\nAvg Size: %.1f | StdDev: %.1f | Consecutive: %d | Current Range: %d", 
                         avgSize, stdDev, consecutiveCount, currentRangeSize);
                         
   // Calculate volatility ratio (higher = more volatile)
   double volatilityRatio = stdDev / avgSize;
   info += StringFormat("\nVolatility Ratio: %.2f", volatilityRatio);
   
   // Add market type classification
   string marketType = "Undefined";
   if(volatilityRatio < 0.2) marketType = "Low Volatility";
   else if(volatilityRatio < 0.5) marketType = "Normal";
   else marketType = "High Volatility";
   
   if(consecutiveCount >= 3) marketType += " Trending";
   else if(count > 1 && legHistory[count-1].isUpleg != legHistory[count-2].isUpleg) marketType += " Choppy";
   
   info += StringFormat("\nMarket Type: %s", marketType);
   
   return info;
}

//+------------------------------------------------------------------+
//| Calculate average leg size                                       |
//+------------------------------------------------------------------+
double CalculateAverageLegSize(LegInfo &legHistory[])
{
   int count = ArraySize(legHistory);
   if(count == 0) return InitialRangeSize;
   
   double sum = 0;
   for(int i = 0; i < count; i++) {
      sum += legHistory[i].size;
   }
   
   return sum / count;
}

//+------------------------------------------------------------------+
//| Calculate standard deviation of leg sizes                        |
//+------------------------------------------------------------------+
double CalculateStandardDeviation(LegInfo &legHistory[], double avg)
{
   int count = ArraySize(legHistory);
   if(count <= 1) return 0;
   
   double sumSquaredDiff = 0;
   
   for(int i = 0; i < count; i++) {
      double diff = legHistory[i].size - avg;
      sumSquaredDiff += diff * diff;
   }
   
   return MathSqrt(sumSquaredDiff / count);
}

//+------------------------------------------------------------------+
//| Calculate consecutive legs in same direction                     |
//+------------------------------------------------------------------+
int CalculateConsecutiveLegs(LegInfo &legHistory[])
{
   int count = ArraySize(legHistory);
   if(count <= 1) return count;
   
   int consecutive = 1;
   bool direction = legHistory[count - 1].isUpleg;
   
   for(int i = count - 2; i >= 0; i--) {
      if(legHistory[i].isUpleg == direction) {
         consecutive++;
      } else {
         break;
      }
   }
   
   return consecutive;
}

//+------------------------------------------------------------------+
//| Calculate weighted average based on recency                      |
//+------------------------------------------------------------------+
double CalculateWeightedAverage(LegInfo &legHistory[])
{
   int count = ArraySize(legHistory);
   if(count == 0) return InitialRangeSize;
   
   double sum = 0;
   double weightSum = 0;
   
   // More recent legs get higher weights
   for(int i = 0; i < count; i++) {
      double weight = 1.0 + (i / (double)count); // Weight increases with recency
      sum += legHistory[i].size * weight;
      weightSum += weight;
   }
   
   return sum / weightSum;
}

//+------------------------------------------------------------------+
//| Calculate dynamic range size                                     |
//+------------------------------------------------------------------+
int CalculateDynamicRangeSize(LegInfo &legHistory[])
{
   // Get average leg size (with more weight to recent legs)
   double avgLegSize = CalculateWeightedAverage(legHistory);
   
   // Get standard deviation for volatility measurement
   double stdDev = CalculateStandardDeviation(legHistory, avgLegSize);
   
   // Get consecutive legs count
   int consecutiveCount = CalculateConsecutiveLegs(legHistory);
   
   // Calculate adjustment factor based on market conditions
   double adjustmentFactor = 1.0;
   
   // Strong trend (3+ legs in same direction)
   if(consecutiveCount >= 3) {
      adjustmentFactor = TrendFactor; // Increase range size
   }
   
   // Choppy market (alternating directions)
   int legCount = ArraySize(legHistory);
   if(consecutiveCount == 1 && legCount > 1 && legHistory[legCount-1].isUpleg != legHistory[legCount-2].isUpleg) {
      adjustmentFactor = ChoppyFactor; // Decrease range size
   }
   
   // Calculate volatility ratio
   double volatilityRatio = stdDev / avgLegSize;
   
   // Adjust factor based on volatility
   if(volatilityRatio > 0.5) {
      // High volatility - increase range slightly to avoid whipsaws
      adjustmentFactor *= 1.1;
   } else if(volatilityRatio < 0.2) {
      // Low volatility - decrease range slightly for more precision
      adjustmentFactor *= 0.9;
   }
   
   // Calculate new range size with adjustment
   double newRangeSize = avgLegSize * adjustmentFactor;
   
   // Cap extreme values - don't let range deviate too far from average
   double upperLimit = avgLegSize * VolatilityCapFactor;
   double lowerLimit = avgLegSize / VolatilityCapFactor;
   
   if(newRangeSize > upperLimit) newRangeSize = upperLimit;
   if(newRangeSize < lowerLimit) newRangeSize = lowerLimit;
   
   // Ensure minimum range size
   if(newRangeSize < 5) newRangeSize = 5;
   
   return (int)MathRound(newRangeSize);
}

//+------------------------------------------------------------------+
//| Convert timeframe enum to string                                 |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe) {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "Current";
   }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear the chart comment
   Comment("");
}
//+------------------------------------------------------------------+
//|                                   RangeTwist_MTF.mq5             |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   3
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrLime, clrRed
#property indicator_width2  1
#property indicator_style2  STYLE_DASH
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrLime, clrRed
#property indicator_width3  1
#property indicator_style3  STYLE_DOT

// Input parameters
input int    RangeSize = 25;              // Base range size in points
input bool   IncLstCndl = false;        // Include last candle in calculations
input ENUM_TIMEFRAMES TimeFrame1 = PERIOD_CURRENT; // Primary timeframe
input ENUM_TIMEFRAMES TimeFrame2 = PERIOD_H1;      // Secondary timeframe
input ENUM_TIMEFRAMES TimeFrame3 = PERIOD_D1;      // Tertiary timeframe
input int    MaxLegsToTrack = 10;         // Number of legs to track for statistics
input color  UpColor = clrLime;           // Color for up trend
input color  DownColor = clrRed;          // Color for down trend
input bool   EnableDynamicRange = true;   // Enable dynamic range calculation
input bool   ShowStats = true;            // Show statistics on chart

// Buffers
double LineBuffer1[];        // Primary timeframe line
double ColorBuffer1[];       // Primary timeframe color
double LineBuffer2[];        // Secondary timeframe line
double ColorBuffer2[];       // Secondary timeframe color
double LineBuffer3[];        // Tertiary timeframe line
double ColorBuffer3[];       // Tertiary timeframe color

// Leg history structure
struct LegInfo {
   double size;              // Size of the leg in points
   bool isUpleg;             // Direction of the leg
   datetime time;            // Time when leg completed
   double level;             // Price level where the leg completed
};

// Structure to hold data for each timeframe
struct TimeframeData {
   double currentLevel;      // Current range level
   double prevLevel;         // Previous range level
   int lastRangeBarIndex;    // Bar index of last range change
   bool upTrend;             // Current trend direction
   int currentRangeSize;     // Current dynamic range size
   LegInfo legHistory[];     // Array to store leg history
};

// Array of timeframe data
TimeframeData tfData[3];     // For 3 timeframes

// Indicator handles for higher timeframes
int handle_tf2;              // Handle for secondary timeframe
int handle_tf3;              // Handle for tertiary timeframe

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
   
   // Set up colors and styles
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  
   PlotIndexSetString(0, PLOT_LABEL, StringFormat("Range (%s)", GetTimeframeString(TimeFrame1)));
   
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, UpColor);    
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, DownColor);  
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("Range (%s)", GetTimeframeString(TimeFrame2)));
   
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, UpColor);    
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 1, DownColor);  
   PlotIndexSetString(2, PLOT_LABEL, StringFormat("Range (%s)", GetTimeframeString(TimeFrame3)));
   
   // Initialize timeframe data
   for(int i = 0; i < 3; i++) {
      tfData[i].currentLevel = 0;
      tfData[i].prevLevel = 0;
      tfData[i].lastRangeBarIndex = 0;
      tfData[i].upTrend = true;
      tfData[i].currentRangeSize = RangeSize;
      ArrayResize(tfData[i].legHistory, 0);
   }
   
   // Create indicator handles for higher timeframes
   if(TimeFrame2 != PERIOD_CURRENT) {
      handle_tf2 = iCustom(_Symbol, TimeFrame2, "RangeTwist_1_0_3", RangeSize, UpColor, DownColor, false);
      if(handle_tf2 == INVALID_HANDLE) {
         Print("Error creating handle for second timeframe");
         return(INIT_FAILED);
      }
   }
   
   if(TimeFrame3 != PERIOD_CURRENT) {
      handle_tf3 = iCustom(_Symbol, TimeFrame3, "RangeTwist_1_0_3", RangeSize, UpColor, DownColor, false);
      if(handle_tf3 == INVALID_HANDLE) {
         Print("Error creating handle for third timeframe");
         return(INIT_FAILED);
      }
   }
   
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
   if(rates_total < 2) return(0);
   
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset indicators and initialize
      ArrayInitialize(LineBuffer1, EMPTY_VALUE);
      ArrayInitialize(LineBuffer2, EMPTY_VALUE);
      ArrayInitialize(LineBuffer3, EMPTY_VALUE);
      
      for(int i = 0; i < 3; i++) {
         ArrayResize(tfData[i].legHistory, 0);
      }
      
      // Initialize the first range value for primary timeframe
      if(rates_total > 0)
      {
         tfData[0].currentLevel = close[0];
         tfData[0].prevLevel = close[0];
         tfData[0].lastRangeBarIndex = 0;
         tfData[0].upTrend = true;
         tfData[0].currentRangeSize = RangeSize;
         
         LineBuffer1[0] = tfData[0].currentLevel;
         ColorBuffer1[0] = 0; // Start with up color
      }
   }
   
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   int limit = rates_total;
   
   // Calculate primary timeframe (current chart timeframe)
   for(int i = start; i < limit; i++)
   {
      if(i == rates_total - 1 && !IncLstCndl) {
         // For the last candle, when we don't want to include it in calculations
         // Copy the previous value to maintain continuity
         if(i > 0) {
            LineBuffer1[i] = LineBuffer1[i-1];
            ColorBuffer1[i] = ColorBuffer1[i-1];
         }
      } else {
         // Check if we should update range size dynamically
         if(EnableDynamicRange && ArraySize(tfData[0].legHistory) > 0) {
            tfData[0].currentRangeSize = CalculateDynamicRangeSize(0);
         }
         
         // Calculate using current range size
         CalculateRange(0, i, high[i], low[i], rates_total, time[i]);
         LineBuffer1[i] = tfData[0].currentLevel;
         ColorBuffer1[i] = tfData[0].upTrend ? 0 : 1;
      }
   }
   
   // Get data from secondary timeframe
   if(TimeFrame2 != PERIOD_CURRENT && handle_tf2 != INVALID_HANDLE) {
      CopyDataFromHigherTimeframe(handle_tf2, LineBuffer2, ColorBuffer2, rates_total, time);
   }
   
   // Get data from tertiary timeframe
   if(TimeFrame3 != PERIOD_CURRENT && handle_tf3 != INVALID_HANDLE) {
      CopyDataFromHigherTimeframe(handle_tf3, LineBuffer3, ColorBuffer3, rates_total, time);
   }
   
   // Display statistics if enabled
   if(ShowStats) {
      DisplayMultiTimeframeStats(rates_total - 1, time);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Copy data from higher timeframe indicator                        |
//+------------------------------------------------------------------+
void CopyDataFromHigherTimeframe(int handle, double &lineBuffer[], double &colorBuffer[], int rates_total, const datetime &time[])
{
   double values[];
   double colors[];
   
   if(CopyBuffer(handle, 0, 0, rates_total, values) <= 0) {
      Print("Error copying values from higher timeframe: ", GetLastError());
      return;
   }
   
   if(CopyBuffer(handle, 1, 0, rates_total, colors) <= 0) {
      Print("Error copying colors from higher timeframe: ", GetLastError());
      return;
   }
   
   // Map higher timeframe values to current timeframe
   datetime higher_times[];
   if(!TimeframeTimeArray(handle, rates_total, higher_times)) {
      Print("Error getting higher timeframe times");
      return;
   }
   
   // Map higher timeframe values to current timeframe chart
   for(int i = 0; i < rates_total; i++) {
      lineBuffer[i] = EMPTY_VALUE;
      colorBuffer[i] = 0;
   }
   
   int higher_count = ArraySize(higher_times);
   int current_pos = rates_total - 1;
   
   // Walk backward through current timeframe
   for(int i = rates_total - 1; i >= 0 && current_pos >= 0; i--) {
      // Find corresponding bar in higher timeframe
      datetime current_time = time[i];
      
      for(int j = higher_count - 1; j >= 0; j--) {
         if(higher_times[j] <= current_time) {
            lineBuffer[i] = values[j];
            colorBuffer[i] = colors[j];
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate range level for each bar                               |
//+------------------------------------------------------------------+
void CalculateRange(int tfIndex, int bar_index, double high, double low, int rates_total, datetime time)
{
   double range = tfData[tfIndex].currentRangeSize * _Point;
   bool legCompleted = false;
   bool wasUpTrend = tfData[tfIndex].upTrend;
   double oldLevel = tfData[tfIndex].currentLevel;
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(tfData[tfIndex].upTrend)
   {
      if(high >= tfData[tfIndex].currentLevel + range)
      {
         // Move the line up
         tfData[tfIndex].prevLevel = tfData[tfIndex].currentLevel;
         tfData[tfIndex].currentLevel = tfData[tfIndex].currentLevel + range;
         tfData[tfIndex].lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(low <= tfData[tfIndex].currentLevel - range)
      {
         // Trend has reversed to down
         tfData[tfIndex].prevLevel = tfData[tfIndex].currentLevel;
         tfData[tfIndex].upTrend = false;
         tfData[tfIndex].currentLevel = tfData[tfIndex].currentLevel - range;
         tfData[tfIndex].lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
   }
   else // downtrend
   {
      if(low <= tfData[tfIndex].currentLevel - range)
      {
         // Move the line down
         tfData[tfIndex].prevLevel = tfData[tfIndex].currentLevel;
         tfData[tfIndex].currentLevel = tfData[tfIndex].currentLevel - range;
         tfData[tfIndex].lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(high >= tfData[tfIndex].currentLevel + range)
      {
         // Trend has reversed to up
         tfData[tfIndex].prevLevel = tfData[tfIndex].currentLevel;
         tfData[tfIndex].upTrend = true;
         tfData[tfIndex].currentLevel = tfData[tfIndex].currentLevel + range;
         tfData[tfIndex].lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
   }
   
   // If a leg was completed, add it to history
   if(legCompleted) {
      AddCompletedLeg(tfIndex, MathAbs(tfData[tfIndex].currentLevel - tfData[tfIndex].prevLevel) / _Point, 
                     wasUpTrend, time, tfData[tfIndex].currentLevel);
   }
}

//+------------------------------------------------------------------+
//| Add a completed leg to history                                   |
//+------------------------------------------------------------------+
void AddCompletedLeg(int tfIndex, double size, bool isUpleg, datetime time, double level)
{
   // Create new leg info
   LegInfo newLeg;
   newLeg.size = size;
   newLeg.isUpleg = isUpleg;
   newLeg.time = time;
   newLeg.level = level;
   
   // Add to array
   int historySize = ArraySize(tfData[tfIndex].legHistory);
   ArrayResize(tfData[tfIndex].legHistory, historySize + 1);
   tfData[tfIndex].legHistory[historySize] = newLeg;
   
   // If we have more legs than we want to track, remove oldest
   if(ArraySize(tfData[tfIndex].legHistory) > MaxLegsToTrack) {
      for(int i = 0; i < ArraySize(tfData[tfIndex].legHistory) - 1; i++) {
         tfData[tfIndex].legHistory[i] = tfData[tfIndex].legHistory[i + 1];
      }
      ArrayResize(tfData[tfIndex].legHistory, MaxLegsToTrack);
   }
   
   // Check for multi-timeframe fractal patterns
   AnalyzeMultiTimeframeFractals();
}

//+------------------------------------------------------------------+
//| Calculate average leg size                                       |
//+------------------------------------------------------------------+
double CalculateAverageLegSize(int tfIndex)
{
   int count = ArraySize(tfData[tfIndex].legHistory);
   if(count == 0) return RangeSize;
   
   double sum = 0;
   for(int i = 0; i < count; i++) {
      sum += tfData[tfIndex].legHistory[i].size;
   }
   
   return sum / count;
}

//+------------------------------------------------------------------+
//| Calculate standard deviation of leg sizes                        |
//+------------------------------------------------------------------+
double CalculateStandardDeviation(int tfIndex)
{
   int count = ArraySize(tfData[tfIndex].legHistory);
   if(count <= 1) return 0;
   
   double avg = CalculateAverageLegSize(tfIndex);
   double sumSquaredDiff = 0;
   
   for(int i = 0; i < count; i++) {
      double diff = tfData[tfIndex].legHistory[i].size - avg;
      sumSquaredDiff += diff * diff;
   }
   
   return MathSqrt(sumSquaredDiff / count);
}

//+------------------------------------------------------------------+
//| Calculate consecutive legs in same direction                     |
//+------------------------------------------------------------------+
int CalculateConsecutiveLegs(int tfIndex)
{
   int count = ArraySize(tfData[tfIndex].legHistory);
   if(count <= 1) return count;
   
   int consecutive = 1;
   bool direction = tfData[tfIndex].legHistory[count - 1].isUpleg;
   
   for(int i = count - 2; i >= 0; i--) {
      if(tfData[tfIndex].legHistory[i].isUpleg == direction) {
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
double CalculateWeightedAverage(int tfIndex)
{
   int count = ArraySize(tfData[tfIndex].legHistory);
   if(count == 0) return RangeSize;
   
   double sum = 0;
   double weightSum = 0;
   
   // More recent legs get higher weights
   for(int i = 0; i < count; i++) {
      double weight = 1.0 + (i / (double)count); // Weight increases with recency
      sum += tfData[tfIndex].legHistory[i].size * weight;
      weightSum += weight;
   }
   
   return sum / weightSum;
}

//+------------------------------------------------------------------+
//| Calculate dynamic range size                                     |
//+------------------------------------------------------------------+
int CalculateDynamicRangeSize(int tfIndex)
{
   // Get average leg size (with more weight to recent legs)
   double avgLegSize = CalculateWeightedAverage(tfIndex);
   
   // Get standard deviation for volatility measurement
   double stdDev = CalculateStandardDeviation(tfIndex);
   
   // Get consecutive legs count
   int consecutiveCount = CalculateConsecutiveLegs(tfIndex);
   
   // Calculate adjustment factor based on market conditions
   double adjustmentFactor = 1.0;
   
   // Strong trend (3+ legs in same direction)
   if(consecutiveCount >= 3) {
      adjustmentFactor = 1.2; // Increase range size
   }
   
   // Choppy market (alternating directions)
   int legCount = ArraySize(tfData[tfIndex].legHistory);
   if(consecutiveCount == 1 && legCount > 1 && 
      tfData[tfIndex].legHistory[legCount-1].isUpleg != tfData[tfIndex].legHistory[legCount-2].isUpleg) {
      adjustmentFactor = 0.8; // Decrease range size
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
   double upperLimit = avgLegSize * 2.0;
   double lowerLimit = avgLegSize / 2.0;
   
   if(newRangeSize > upperLimit) newRangeSize = upperLimit;
   if(newRangeSize < lowerLimit) newRangeSize = lowerLimit;
   
   // Ensure minimum range size
   if(newRangeSize < 5) newRangeSize = 5;
   
   return (int)MathRound(newRangeSize);
}

//+------------------------------------------------------------------+
//| Display multi-timeframe statistics                               |
//+------------------------------------------------------------------+
void DisplayMultiTimeframeStats(int currentBar, const datetime &time[])
{
   string info = "===== MULTI-TIMEFRAME RANGE ANALYSIS =====\n\n";
   
   // Add data for each timeframe
   string tfNames[3] = {GetTimeframeString(TimeFrame1), 
                       GetTimeframeString(TimeFrame2), 
                       GetTimeframeString(TimeFrame3)};
   
   for(int tf = 0; tf < 3; tf++) {
      int legCount = ArraySize(tfData[tf].legHistory);
      if(legCount == 0) continue;
      
      info += StringFormat("--- %s Timeframe ---\n", tfNames[tf]);
      
      // Current trend and level
      info += StringFormat("Current: %s trend at %.5f | Range Size: %d points\n", 
                         tfData[tf].upTrend ? "Up" : "Down", 
                         tfData[tf].currentLevel,
                         tfData[tf].currentRangeSize);
      
      // Leg history
      info += "Recent Legs: ";
      int legsToShow = MathMin(5, legCount);
      for(int i = legCount - 1; i >= MathMax(0, legCount - legsToShow); i--) {
         info += StringFormat("%s%.1f", tfData[tf].legHistory[i].isUpleg ? "↑" : "↓", tfData[tf].legHistory[i].size);
         if(i > MathMax(0, legCount - legsToShow)) info += ", ";
      }
      
      // Leg statistics
      double avgSize = CalculateAverageLegSize(tf);
      double stdDev = CalculateStandardDeviation(tf);
      int consecutiveCount = CalculateConsecutiveLegs(tf);
      
      info += StringFormat("\nStats: Avg Size: %.1f | StdDev: %.1f | Consecutive: %d\n", 
                         avgSize, stdDev, consecutiveCount);
      
      // Market type classification
      double volatilityRatio = stdDev / avgSize;
      string marketType = "Undefined";
      if(volatilityRatio < 0.2) marketType = "Low Volatility";
      else if(volatilityRatio < 0.5) marketType = "Normal";
      else marketType = "High Volatility";
      
      if(consecutiveCount >= 3) marketType += " Trending";
      else if(legCount > 1 && tfData[tf].legHistory[legCount-1].isUpleg != tfData[tf].legHistory[legCount-2].isUpleg) 
         marketType += " Choppy";
      
      info += StringFormat("Market Type: %s\n\n", marketType);
   }
   
   // Multi-timeframe alignment analysis
   info += "--- TIMEFRAME ALIGNMENT ---\n";
   
   bool tf1Up = tfData[0].upTrend;
   bool tf2Up = tfData[1].upTrend;
   bool tf3Up = tfData[2].upTrend;
   
   if(tf1Up == tf2Up && tf2Up == tf3Up) {
      info += StringFormat("All timeframes aligned %s\n", tf1Up ? "BULLISH" : "BEARISH");
   }
   else if(tf2Up == tf3Up) {
      info += StringFormat("Higher timeframes aligned %s, current timeframe %s\n", 
                         tf2Up ? "BULLISH" : "BEARISH", 
                         tf1Up ? "BULLISH" : "BEARISH");
   }
   else {
      info += "Mixed directional bias across timeframes\n";
   }
   
   // Add fractal analysis if available
   string fractalInfo = GetFractalPatternInfo();
   if(fractalInfo != "") {
      info += "\n--- FRACTAL PATTERNS ---\n" + fractalInfo;
   }
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| Analyze multi-timeframe fractal patterns                         |
//+------------------------------------------------------------------+
void AnalyzeMultiTimeframeFractals()
{
   // Implement fractal pattern detection across timeframes
   // This would check for specific leg patterns that might form across
   // different timeframes simultaneously
   
   // Implementation would depend on the specific patterns you want to detect
}

//+------------------------------------------------------------------+
//| Get fractal pattern information                                  |
//+------------------------------------------------------------------+
string GetFractalPatternInfo()
{
   // This would return information about detected fractal patterns
   // For now, return empty string as placeholder
   return "";
}

//+------------------------------------------------------------------+
//| Get timeframe name as string                                     |
//+------------------------------------------------------------------+
string GetTimeframeString(ENUM_TIMEFRAMES tf)
{
   switch(tf) {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "Current";
   }
}

//+------------------------------------------------------------------+
//| Get time array for a higher timeframe                            |
//+------------------------------------------------------------------+
bool TimeframeTimeArray(int handle, int count, datetime &times[])
{
   // This helper function gets the time array from a higher timeframe indicator
   // Used for mapping higher timeframe values to current timeframe
   
   // Implementation depends on the indicator's time handling
   // For now, this is a placeholder
   ArrayResize(times, count);
   return true;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(handle_tf2 != INVALID_HANDLE) {
      IndicatorRelease(handle_tf2);
   }
   
   if(handle_tf3 != INVALID_HANDLE) {
      IndicatorRelease(handle_tf3);
   }
   
   // Clear the chart comment
   Comment("");
}
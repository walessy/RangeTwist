//+------------------------------------------------------------------+
//|                                  RangeTwist_Bollinger.mq5 |
//+------------------------------------------------------------------+
#property copyright "Amos (Modified)"
#property link      "amoswales@gmail.com"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   7
// Main range line
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed, clrGray
#property indicator_width1  2
// Bollinger bands
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_width2  1
#property indicator_style2  STYLE_SOLID
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_width3  1
#property indicator_style3  STYLE_SOLID
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRoyalBlue
#property indicator_width4  1
#property indicator_style4  STYLE_SOLID
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRoyalBlue
#property indicator_width5  1
#property indicator_style5  STYLE_SOLID
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrBlue
#property indicator_width6  1
#property indicator_style6  STYLE_SOLID
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrBlue
#property indicator_width7  1
#property indicator_style7  STYLE_SOLID

// Input parameters
input int    InitialRangeSize = 25;     // Initial range size in points
input int    MaxLegsToTrack = 5;        // Number of legs to track for statistics
input double TrendFactor = 1.2;         // Range adjustment factor for strong trends
input double ChoppyFactor = 0.8;        // Range adjustment factor for choppy markets
input double VolatilityCapFactor = 2.0; // Max allowed deviation from average (multiplier)
input color  UpColor = clrLime;         // Color for up trend
input color  DownColor = clrRed;        // Color for down trend
input color  FlatColor = clrGray;       // Color for no trend
input bool   IncLstCndl = false;        // Include last candle
input bool   EnableDynamicRange = true; // Enable dynamic range calculation
input bool   ShowStats = true;          // Show statistics on chart
input double BollingerFactor1 = 1.0;    // 1st Bollinger band multiplier
input double BollingerFactor2 = 2.0;    // 2nd Bollinger band multiplier
input double BollingerFactor3 = 3.0;    // 3rd Bollinger band multiplier

// Buffers
double LineBuffer[];         // Range line (mean)
double ColorBuffer[];        // Color index for line
double SD1_Upper_Buffer[];   // +1 standard deviation
double SD1_Lower_Buffer[];   // -1 standard deviation
double SD2_Upper_Buffer[];   // +2 standard deviation
double SD2_Lower_Buffer[];   // -2 standard deviation
double SD3_Upper_Buffer[];   // +3 standard deviation
double SD3_Lower_Buffer[];   // -3 standard deviation
double CurrentRangeBuffer[]; // Current range size for data window
double LegCountBuffer[];     // Count of consecutive legs in same direction

// State variables
double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;
int currentRangeSize;

// Array to store price deviation from mean for calculating true standard deviation
double priceDeviation[];
int deviationCount = 0;
int maxDeviationPoints = 100; // Maximum number of points to store for SD calculation

// Leg history tracking
struct LegInfo {
   double size;              // Size of the leg in points
   bool isUpleg;             // Direction of the leg
   datetime time;            // Time when leg completed
};

LegInfo legHistory[];        // Array to store leg history

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, SD1_Upper_Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, SD1_Lower_Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, SD2_Upper_Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, SD2_Lower_Buffer, INDICATOR_DATA);
   SetIndexBuffer(6, SD3_Upper_Buffer, INDICATOR_DATA);
   SetIndexBuffer(7, SD3_Lower_Buffer, INDICATOR_DATA);
   SetIndexBuffer(8, CurrentRangeBuffer, INDICATOR_DATA);
   SetIndexBuffer(9, LegCountBuffer, INDICATOR_DATA);
   
   // Initialize all buffers with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   ArrayInitialize(SD1_Upper_Buffer, EMPTY_VALUE);
   ArrayInitialize(SD1_Lower_Buffer, EMPTY_VALUE);
   ArrayInitialize(SD2_Upper_Buffer, EMPTY_VALUE);
   ArrayInitialize(SD2_Lower_Buffer, EMPTY_VALUE);
   ArrayInitialize(SD3_Upper_Buffer, EMPTY_VALUE);
   ArrayInitialize(SD3_Lower_Buffer, EMPTY_VALUE);
   ArrayInitialize(CurrentRangeBuffer, EMPTY_VALUE);
   ArrayInitialize(LegCountBuffer, EMPTY_VALUE);
   
   // Set up colors and styles
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, FlatColor);  // Index 2 = Flat color
   PlotIndexSetString(0, PLOT_LABEL, "Range Line (Mean)");
   
   // Set up labels for Bollinger bands
   PlotIndexSetString(1, PLOT_LABEL, "+1 Bollinger");
   PlotIndexSetString(2, PLOT_LABEL, "-1 Bollinger");
   PlotIndexSetString(3, PLOT_LABEL, "+2 Bollinger");
   PlotIndexSetString(4, PLOT_LABEL, "-2 Bollinger");
   PlotIndexSetString(5, PLOT_LABEL, "+3 Bollinger");
   PlotIndexSetString(6, PLOT_LABEL, "-3 Bollinger");
   
   // Initialize deviation array for standard deviation calculation
   ArrayResize(priceDeviation, maxDeviationPoints);
   ArrayInitialize(priceDeviation, 0);
   deviationCount = 0;
   
   // Initialize state variables
   point = _Point;
   currentRangeSize = InitialRangeSize;
   
   // Initialize leg history array
   ArrayResize(legHistory, 0);
   
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
      ArrayInitialize(LineBuffer, EMPTY_VALUE);
      ArrayInitialize(SD1_Upper_Buffer, EMPTY_VALUE);
      ArrayInitialize(SD1_Lower_Buffer, EMPTY_VALUE);
      ArrayInitialize(SD2_Upper_Buffer, EMPTY_VALUE);
      ArrayInitialize(SD2_Lower_Buffer, EMPTY_VALUE);
      ArrayInitialize(SD3_Upper_Buffer, EMPTY_VALUE);
      ArrayInitialize(SD3_Lower_Buffer, EMPTY_VALUE);
      ArrayResize(legHistory, 0);
      
      // Reset deviation array
      ArrayInitialize(priceDeviation, 0);
      deviationCount = 0;
      
      // Initialize the first range value
      if(rates_total > 0)
      {
         currentLevel = close[0];
         prevLevel = close[0];
         lastRangeBarIndex = 0;
         upTrend = true;
         LineBuffer[0] = currentLevel;
         ColorBuffer[0] = 2; // Start with flat color
         currentRangeSize = InitialRangeSize;
      }
   }
   
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   int limit = rates_total;
      
   for(int i = start; i < limit; i++)
   {      
      if(i == rates_total - 1 && !IncLstCndl) {
         // For the last candle, when we don't want to include it in calculations
         // Copy the previous value to maintain continuity
         if(i > 0) {
            LineBuffer[i] = LineBuffer[i-1];
            ColorBuffer[i] = ColorBuffer[i-1];
            SD1_Upper_Buffer[i] = SD1_Upper_Buffer[i-1];
            SD1_Lower_Buffer[i] = SD1_Lower_Buffer[i-1];
            SD2_Upper_Buffer[i] = SD2_Upper_Buffer[i-1];
            SD2_Lower_Buffer[i] = SD2_Lower_Buffer[i-1];
            SD3_Upper_Buffer[i] = SD3_Upper_Buffer[i-1];
            SD3_Lower_Buffer[i] = SD3_Lower_Buffer[i-1];
         }
      } else {
         // Check if we should update range size dynamically
         if(EnableDynamicRange && ArraySize(legHistory) > 0) {
            currentRangeSize = CalculateDynamicRangeSize();
         }
         
         // Calculate using current range size
         CalculateRange(i, high[i], low[i], close[i], rates_total, time[i]);
         
         // Record price deviation for standard deviation calculation
         RecordPriceDeviation(close[i], LineBuffer[i]);
         
         // Update Bollinger bands
         UpdateBollingerBands(i);
      }
      
      // Update data window buffers
      CurrentRangeBuffer[i] = currentRangeSize;
      LegCountBuffer[i] = CalculateConsecutiveLegs();
   }
      
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Record price deviation from mean for standard deviation calculation |
//+------------------------------------------------------------------+
void RecordPriceDeviation(double price, double mean)
{
   if(mean == EMPTY_VALUE) return;
   
   // Record absolute deviation in points
   double deviation = MathAbs(price - mean) / point;
   
   // Add to circular buffer
   priceDeviation[deviationCount % maxDeviationPoints] = deviation;
   deviationCount++;
}

//+------------------------------------------------------------------+
//| Calculate true standard deviation from price deviations          |
//+------------------------------------------------------------------+
double CalculateTrueStandardDeviation()
{
   int count = MathMin(deviationCount, maxDeviationPoints);
   if(count < 2) return currentRangeSize; // Default to current range if not enough data
   
   double sum = 0;
   double sumSquared = 0;
   
   for(int i = 0; i < count; i++) {
      sum += priceDeviation[i];
      sumSquared += priceDeviation[i] * priceDeviation[i];
   }
   
   double mean = sum / count;
   double variance = (sumSquared / count) - (mean * mean);
   
   return MathSqrt(variance);
}

//+------------------------------------------------------------------+
//| Calculate range level for each bar                               |
//+------------------------------------------------------------------+
void CalculateRange(int bar_index, double high, double low, double close, int rates_total, datetime time)
{
   double range = currentRangeSize * point;
   bool legCompleted = false;
   bool wasUpTrend = upTrend;
   double oldLevel = currentLevel;
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(upTrend)
   {
      if(high >= currentLevel + range)
      {
         // Move the line up
         prevLevel = currentLevel;
         currentLevel = currentLevel + range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(low <= currentLevel - range)
      {
         // Trend has reversed to down
         prevLevel = currentLevel;
         upTrend = false;
         currentLevel = currentLevel - range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
         legCompleted = true;
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
         prevLevel = currentLevel;
         currentLevel = currentLevel - range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(high >= currentLevel + range)
      {
         // Trend has reversed to up
         prevLevel = currentLevel;
         upTrend = true;
         currentLevel = currentLevel + range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else
      {
         // No change in level, copy the last value
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
      }
   }
   
   // If a leg was completed, add it to history
   if(legCompleted) {
      AddCompletedLeg(MathAbs(currentLevel - prevLevel) / point, wasUpTrend, time);
   }
}

//+------------------------------------------------------------------+
//| Update Bollinger bands for each bar                              |
//+------------------------------------------------------------------+
void UpdateBollingerBands(int bar_index)
{
   // Get the true standard deviation based on actual price deviations
   double trueSD = CalculateTrueStandardDeviation() * point;
   
   // If not enough data yet, use current range as a fallback
   if(trueSD <= 0) trueSD = currentRangeSize * point;
   
   // Set Bollinger bands with user-defined multipliers
   SD1_Upper_Buffer[bar_index] = LineBuffer[bar_index] + BollingerFactor1 * trueSD;
   SD1_Lower_Buffer[bar_index] = LineBuffer[bar_index] - BollingerFactor1 * trueSD;
   
   SD2_Upper_Buffer[bar_index] = LineBuffer[bar_index] + BollingerFactor2 * trueSD;
   SD2_Lower_Buffer[bar_index] = LineBuffer[bar_index] - BollingerFactor2 * trueSD;
   
   SD3_Upper_Buffer[bar_index] = LineBuffer[bar_index] + BollingerFactor3 * trueSD;
   SD3_Lower_Buffer[bar_index] = LineBuffer[bar_index] - BollingerFactor3 * trueSD;
}

//+------------------------------------------------------------------+
//| Add a completed leg to history                                  |
//+------------------------------------------------------------------+
void AddCompletedLeg(double size, bool isUpleg, datetime time)
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
   
   // Print leg statistics
   if(ShowStats) {
      PrintLegStatistics();
   }
}

//+------------------------------------------------------------------+
//| Print leg history statistics                                     |
//+------------------------------------------------------------------+
void PrintLegStatistics()
{
   int count = ArraySize(legHistory);
   if(count == 0) return;
   
   string info = "Leg History (newest first): ";
   for(int i = count - 1; i >= 0; i--) {
      info += StringFormat("%s%.1f", legHistory[i].isUpleg ? "↑" : "↓", legHistory[i].size);
      if(i > 0) info += ", ";
   }
   
   double avgSize = CalculateAverageLegSize();
   double stdDev = CalculateStandardDeviation();
   int consecutiveCount = CalculateConsecutiveLegs();
   
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
   
   // Add true standard deviation value
   double trueSD = CalculateTrueStandardDeviation();
   info += StringFormat("\nTrue SD: %.1f points | Bollinger Bands: %.1f, %.1f, %.1f", 
                        trueSD,
                        BollingerFactor1 * trueSD,
                        BollingerFactor2 * trueSD,
                        BollingerFactor3 * trueSD);
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| Calculate average leg size                                       |
//+------------------------------------------------------------------+
double CalculateAverageLegSize()
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
double CalculateStandardDeviation()
{
   int count = ArraySize(legHistory);
   if(count <= 1) return 0;
   
   double avg = CalculateAverageLegSize();
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
int CalculateConsecutiveLegs()
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
double CalculateWeightedAverage()
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
int CalculateDynamicRangeSize()
{
   // Get average leg size (with more weight to recent legs)
   double avgLegSize = CalculateWeightedAverage();
   
   // Get standard deviation for volatility measurement
   double stdDev = CalculateStandardDeviation();
   
   // Get consecutive legs count
   int consecutiveCount = CalculateConsecutiveLegs();
   
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
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear the chart comment
   Comment("");
}
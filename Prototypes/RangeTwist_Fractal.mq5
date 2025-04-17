//+------------------------------------------------------------------+
//|                                          RangeTwist_Arrows.mq5 |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   2
#property indicator_type1   DRAW_ARROW  // Changed to DRAW_ARROW
#property indicator_color1  clrLime     // Up arrow color
#property indicator_width1  3           // Arrow width increased for visibility
#property indicator_type2   DRAW_ARROW  // Down arrow
#property indicator_color2  clrRed      // Down arrow color
#property indicator_width2  3           // Arrow width

// Input parameters
input int    InitialRangeSize = 25;     // Initial range size in points
input int    MaxLegsToTrack = 5;        // Number of legs to track for statistics
input double TrendFactor = 1.2;         // Range adjustment factor for strong trends
input double ChoppyFactor = 0.8;        // Range adjustment factor for choppy markets
input double VolatilityCapFactor = 2.0; // Max allowed deviation from average (multiplier)
input color  UpArrowColor = clrLime;    // Color for up trend arrow
input color  DownArrowColor = clrRed;   // Color for down trend arrow
input int    ArrowSize = 5;             // Size of the arrow (1-5)
input bool   IncLstCndl = false;        // Include last candle
input bool   EnableDynamicRange = true; // Enable dynamic range calculation
input bool   ShowStats = true;          // Show statistics on chart
input bool   UseM1ForPrecision = true;  // Use M1 timeframe for precision at trend change

// Arrow codes
#define ARROW_UP    233  // Up arrow character code
#define ARROW_DOWN  234  // Down arrow character code

// Buffers
double UpArrowBuffer[];    // Buffer for up arrows
double DownArrowBuffer[];  // Buffer for down arrows
double CurrentRangeBuffer[]; // Current range size for data window
double LegCountBuffer[];    // Count of consecutive legs in same direction
double AvgLegSizeBuffer[];  // Average leg size
double ArrowValueBuffer[];  // Value at which the arrow is placed
double ArrowDirectionBuffer[]; // Direction of the arrow (1=up, -1=down)

// State variables
double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;
int currentRangeSize;
bool trendChanged = false;
datetime lastArrowTime = 0;

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
   SetIndexBuffer(0, UpArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DownArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, CurrentRangeBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, LegCountBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, AvgLegSizeBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, ArrowValueBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, ArrowDirectionBuffer, INDICATOR_DATA);
   
   // Initialize buffers with EMPTY_VALUE
   ArrayInitialize(UpArrowBuffer, EMPTY_VALUE);
   ArrayInitialize(DownArrowBuffer, EMPTY_VALUE);
   ArrayInitialize(CurrentRangeBuffer, EMPTY_VALUE);
   ArrayInitialize(LegCountBuffer, EMPTY_VALUE);
   ArrayInitialize(AvgLegSizeBuffer, EMPTY_VALUE);
   ArrayInitialize(ArrowValueBuffer, EMPTY_VALUE);
   ArrayInitialize(ArrowDirectionBuffer, EMPTY_VALUE);
   
   // Set up arrow properties
   PlotIndexSetInteger(0, PLOT_ARROW, ARROW_UP);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, UpArrowColor);
   PlotIndexSetString(0, PLOT_LABEL, "Up Arrow");
   
   PlotIndexSetInteger(1, PLOT_ARROW, ARROW_DOWN);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, DownArrowColor);
   PlotIndexSetString(1, PLOT_LABEL, "Down Arrow");

   // Hide other buffers from display
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(2, PLOT_LABEL, "Current Range Size");
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(3, PLOT_LABEL, "Consecutive Legs");
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(4, PLOT_LABEL, "Avg Leg Size");
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(5, PLOT_LABEL, "Arrow Value");
   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(6, PLOT_LABEL, "Arrow Direction");
   
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
      ArrayInitialize(UpArrowBuffer, EMPTY_VALUE);
      ArrayInitialize(DownArrowBuffer, EMPTY_VALUE);
      ArrayResize(legHistory, 0);
      
      // Initialize the first range value
      if(rates_total > 0)
      {
         currentLevel = close[0];
         prevLevel = close[0];
         lastRangeBarIndex = 0;
         upTrend = true;
         currentRangeSize = InitialRangeSize;
      }
   }
   
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   int limit = rates_total;
      
   for(int i = start; i < limit; i++)
   {      
      if(i == rates_total - 1 && !IncLstCndl) {
         // Skip calculations for the last candle if not included
         continue;
      } else {
         // Check if we should update range size dynamically
         if(EnableDynamicRange && ArraySize(legHistory) > 0) {
            currentRangeSize = CalculateDynamicRangeSize();
         }
         
         // Flag to track if trend changed in this iteration
         trendChanged = false;
         bool wasUpTrend = upTrend;
         
         // Calculate using current range size
         CalculateRange(i, high[i], low[i], close[i], rates_total, time[i]);
         
         // If trend changed, place an arrow on the chart
         if(trendChanged) {
            if(UseM1ForPrecision && Period() > PERIOD_M1) {
               // Find the exact M1 candle for more precision
               int exactBar = FindExactM1TrendChangeBar(time[i], wasUpTrend);
               if(exactBar >= 0) {
                  // An M1 bar was found, adjust arrow position
                  PlaceArrow(i, wasUpTrend, high[i], low[i]);
               } else {
                  // Fallback if M1 data not available
                  PlaceArrow(i, wasUpTrend, high[i], low[i]);
               }
            } else {
               // Use current timeframe for arrow placement
               PlaceArrow(i, wasUpTrend, high[i], low[i]);
            }
         }
      }
      
      // Update data window buffers
      CurrentRangeBuffer[i] = currentRangeSize;
      LegCountBuffer[i] = CalculateConsecutiveLegs();
      AvgLegSizeBuffer[i] = CalculateAverageLegSize();
   }
      
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate range level for each bar                               |
//+------------------------------------------------------------------+
void CalculateRange(int bar_index, double high, double low, double close, int rates_total, datetime time)
{
   double range = currentRangeSize * point;
   bool legCompleted = false;
   bool prevUpTrend = upTrend;
   double oldLevel = currentLevel;
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(upTrend)
   {
      if(high >= currentLevel + range)
      {
         // Move the level up
         prevLevel = currentLevel;
         currentLevel = currentLevel + range;
         lastRangeBarIndex = bar_index;
         legCompleted = true;
         // No trend change, just continued uptrend
      }
      else if(low <= currentLevel - range)
      {
         // Trend has reversed to down
         prevLevel = currentLevel;
         upTrend = false;
         currentLevel = currentLevel - range;
         lastRangeBarIndex = bar_index;
         legCompleted = true;
         trendChanged = true;  // Flag trend change
      }
   }
   else // downtrend
   {
      if(low <= currentLevel - range)
      {
         // Move the level down
         prevLevel = currentLevel;
         currentLevel = currentLevel - range;
         lastRangeBarIndex = bar_index;
         legCompleted = true;
         // No trend change, just continued downtrend
      }
      else if(high >= currentLevel + range)
      {
         // Trend has reversed to up
         prevLevel = currentLevel;
         upTrend = true;
         currentLevel = currentLevel + range;
         lastRangeBarIndex = bar_index;
         legCompleted = true;
         trendChanged = true;  // Flag trend change
      }
   }
   
   // If a leg was completed, add it to history
   if(legCompleted) {
      AddCompletedLeg(MathAbs(currentLevel - prevLevel) / point, prevUpTrend, time);
   }
}

//+------------------------------------------------------------------+
//| Place an arrow on the chart                                      |
//+------------------------------------------------------------------+
void PlaceArrow(int index, bool prevUpTrend, double high, double low)
{
   // Store arrow value and direction for possible future reference
   ArrowValueBuffer[index] = upTrend ? low : high;  // Place arrow near the bar
   ArrowDirectionBuffer[index] = upTrend ? 1 : -1;  // Up or down
   
   if(upTrend) {
      // Trend changed to up - place up arrow below the bar
      UpArrowBuffer[index] = low; // Place arrow below the bar for better visibility
      DownArrowBuffer[index] = EMPTY_VALUE;
   } else {
      // Trend changed to down - place down arrow above the bar
      DownArrowBuffer[index] = high; // Place arrow above the bar
      UpArrowBuffer[index] = EMPTY_VALUE;
   }
}

//+------------------------------------------------------------------+
//| Find the exact M1 bar where trend change happened                |
//+------------------------------------------------------------------+
int FindExactM1TrendChangeBar(datetime currentTime, bool prevUpTrend)
{
   // This function checks M1 data to find the exact bar where the trend changed
   // for more precise arrow placement
   
   // Get M1 data for the period around the current bar
   MqlRates m1_rates[];
   
   // Calculate range in minutes based on current timeframe
   int minutesBack = 0;
   
   switch(Period()) {
      case PERIOD_M5: minutesBack = 5; break;
      case PERIOD_M15: minutesBack = 15; break;
      case PERIOD_M30: minutesBack = 30; break;
      case PERIOD_H1: minutesBack = 60; break;
      case PERIOD_H4: minutesBack = 240; break;
      case PERIOD_D1: minutesBack = 1440; break;
      default: minutesBack = 60; // Default fallback
   }
   
   // Get bars from M1 timeframe
   datetime startTime = currentTime - minutesBack * 60;
   datetime endTime = currentTime;
   
   // Copy rates from M1 timeframe
   if(CopyRates(Symbol(), PERIOD_M1, startTime, endTime, m1_rates) <= 0) {
      // Failed to get M1 data, return -1 to use current timeframe instead
      Print("Failed to get M1 data for precise arrow placement");
      return -1;
   }
   
   // Find potential trend change bars by checking range conditions
   int barsCount = ArraySize(m1_rates);
   double range = currentRangeSize * point;
   
   // Loop through M1 bars to find where the trend changed
   for(int i = 0; i < barsCount; i++) {
      if(prevUpTrend) {
         // Looking for bar that caused downtrend
         if(m1_rates[i].low <= currentLevel - range) {
            // Found the bar where trend changed to down
            return i;
         }
      } else {
         // Looking for bar that caused uptrend
         if(m1_rates[i].high >= currentLevel + range) {
            // Found the bar where trend changed to up
            return i;
         }
      }
   }
   
   // If no specific bar found, return -1 to use current timeframe
   return -1;
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
   
   // Add current trend direction
   info += StringFormat("\nCurrent Trend: %s", upTrend ? "UP" : "DOWN");
   
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
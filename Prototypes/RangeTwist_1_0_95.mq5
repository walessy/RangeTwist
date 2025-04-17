//+------------------------------------------------------------------+
//|                                        RangeTwist_Dynamic.mq5 |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed, clrGray
#property indicator_width1  2

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

// Buffers
double LineBuffer[];         // Range line
double ColorBuffer[];        // Color index for line
double CurrentRangeBuffer[]; // Current range size for data window
double LegCountBuffer[];     // Count of consecutive legs in same direction
double AvgLegSizeBuffer[];   // Average leg size
double DummyBuffer[];        // Dummy buffer to complete required buffers

// State variables
double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;
int currentRangeSize;

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
   // Set up indicator buffers for plotting
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   
   // Set up additional data buffers (not plotted)
   SetIndexBuffer(2, DummyBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, CurrentRangeBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, LegCountBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, AvgLegSizeBuffer, INDICATOR_CALCULATIONS);
   
   // Initialize buffers with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   ArrayInitialize(ColorBuffer, 0);
   ArrayInitialize(CurrentRangeBuffer, EMPTY_VALUE);
   ArrayInitialize(LegCountBuffer, EMPTY_VALUE);
   ArrayInitialize(AvgLegSizeBuffer, EMPTY_VALUE);
   
   // Set up colors and styles
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, FlatColor);  // Index 2 = Flat color
   PlotIndexSetString(0, PLOT_LABEL, "Range Line");
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 0);
   
   // Set indicator name for Data Window
   IndicatorSetString(INDICATOR_SHORTNAME, "RangeTwist Dynamic");
   
   // Initialize state variables
   point = _Point;
   currentRangeSize = InitialRangeSize;
   if(currentRangeSize < 1) currentRangeSize = 1;
   
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
      ArrayResize(legHistory, 0);
      
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
         if(currentRangeSize < 1) currentRangeSize = 1;
      }
   }
   
   // Calculate start and limit indices
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   // Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      // For the last candle, when we don't want to include it in calculations
      if(i == rates_total - 1 && !IncLstCndl) {
         // Copy the previous value to maintain continuity
         if(i > 0) {
            LineBuffer[i] = LineBuffer[i-1];
            ColorBuffer[i] = ColorBuffer[i-1];
         }
      } else {
         // Check if we should update range size dynamically
         if(EnableDynamicRange && ArraySize(legHistory) > 0) {
            currentRangeSize = CalculateDynamicRangeSize();
         }
         
         // Calculate using current range size
         CalculateRange(i, high[i], low[i], rates_total, time[i]);
      }
      
      // Update data window buffers
      CurrentRangeBuffer[i] = currentRangeSize;
      LegCountBuffer[i] = CalculateConsecutiveLegs();
      AvgLegSizeBuffer[i] = CalculateAverageLegSize();
   }
   
   // Debug information
   if(ShowStats && rates_total > 0) {
      PrintLegStatistics();
   }
   
   // Return value must be rates_total for indicators
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate range level for each bar                               |
//+------------------------------------------------------------------+
void CalculateRange(int bar_index, double high, double low, int rates_total, datetime time)
{
   // Calculate range size ensuring it's at least 0.5 point
   double range = MathMax(point * 0.5, currentRangeSize * point);
   
   bool legCompleted = false;
   bool wasUpTrend = upTrend;
   
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
   double volatilityRatio = stdDev > 0 && avgSize > 0 ? stdDev / avgSize : 0;
   info += StringFormat("\nVolatility Ratio: %.2f", volatilityRatio);
   
   // Add market type classification
   string marketType = "Undefined";
   if(volatilityRatio < 0.2) marketType = "Low Volatility";
   else if(volatilityRatio < 0.5) marketType = "Normal";
   else marketType = "High Volatility";
   
   if(consecutiveCount >= 3) marketType += " Trending";
   else if(count > 1 && legHistory[count-1].isUpleg != legHistory[count-2].isUpleg) marketType += " Choppy";
   
   info += StringFormat("\nMarket Type: %s", marketType);
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| Calculate average leg size                                       |
//+------------------------------------------------------------------+
double CalculateAverageLegSize()
{
   int count = ArraySize(legHistory);
   if(count == 0) return MathMax(1, InitialRangeSize);
   
   double sum = 0;
   for(int i = 0; i < count; i++) {
      sum += legHistory[i].size;
   }
   
   return MathMax(1, sum / count);
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
   if(count == 0) return MathMax(1, InitialRangeSize);
   
   double sum = 0;
   double weightSum = 0;
   
   // More recent legs get higher weights
   for(int i = 0; i < count; i++) {
      double weight = 1.0 + (i / (double)count); // Weight increases with recency
      sum += legHistory[i].size * weight;
      weightSum += weight;
   }
   
   return MathMax(1, sum / weightSum);
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
   double volatilityRatio = stdDev > 0 && avgLegSize > 0 ? stdDev / avgLegSize : 0;
   
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
   
   // Cap extreme values
   double upperLimit = avgLegSize * VolatilityCapFactor;
   double lowerLimit = 1; // Minimum range size of 1 point
   
   if(newRangeSize > upperLimit) newRangeSize = upperLimit;
   if(newRangeSize < lowerLimit) newRangeSize = lowerLimit;
   
   return MathMax(1, (int)MathRound(newRangeSize));
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear the chart comment
   Comment("");
}
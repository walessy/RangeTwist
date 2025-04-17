//+------------------------------------------------------------------+
//|                                   RangeTwist_Adaptive_ZigZag.mq5 |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed, clrGray
#property indicator_width1  2

// Input parameters
input int    InitialRangeSize = 25;         // Initial range size in points (smaller = more frequent signals)
input int    MaxLegsToTrack = 5;            // Number of legs to track for statistics
input double TrendFactor = 1.2;             // Range adjustment factor for strong trends
input double ChoppyFactor = 0.8;            // Range adjustment factor for choppy markets
input double VolatilityCapFactor = 2.0;     // Max allowed deviation from average (multiplier)
input double MinThresholdMultiplier = 0.5;  // Minimum threshold as % of base (preserve zigzag)
input double MaxThresholdMultiplier = 2.0;  // Maximum threshold as % of base (preserve zigzag)
input int    ThresholdSmoothingPeriods = 3; // Periods for threshold smoothing (stability)
input bool   EnableAdaptiveRange = true;    // Enable adaptive range calculation
input bool   AutoInstrumentCalibration = true; // Automatically calibrate for instrument
input bool   AutoTimeframeCalibration = true;  // Automatically calibrate for timeframe
input color  UpColor = clrLime;             // Color for up trend
input color  DownColor = clrRed;            // Color for down trend
input color  FlatColor = clrGray;           // Color for no trend
input bool   IncludeLastCandle = false;     // Include last candle in calculations
input bool   ShowStats = true;              // Show statistics on chart

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

// Variables for threshold smoothing
double recentThresholds[];  // Array to store recent threshold values

// Instrument calibration variables
double instrumentVolatilityFactor = 1.0;
double timeframeScalingFactor = 1.0;

// Leg history tracking
struct LegInfo {
   double size;              // Size of the leg in points
   bool isUpleg;             // Direction of the leg
   datetime time;            // Time when leg completed
   int duration;             // Duration in bars
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
   IndicatorSetString(INDICATOR_SHORTNAME, "RangeTwist Adaptive ZigZag");
   
   // Initialize state variables
   point = _Point;
   currentRangeSize = InitialRangeSize;
   if(currentRangeSize < 1) currentRangeSize = 1;
   
   // Initialize leg history array
   ArrayResize(legHistory, 0);
   
   // Initialize threshold smoothing
   InitThresholdSmoothing();
   
   // Perform auto-calibration if enabled
   if(AutoInstrumentCalibration) {
      instrumentVolatilityFactor = CalculateInstrumentVolatility();
      Print("Auto-calibrated instrument volatility factor for ", _Symbol, ": ", instrumentVolatilityFactor);
   }
   
   if(AutoTimeframeCalibration) {
      timeframeScalingFactor = CalculateTimeframeScaling();
      Print("Auto-calibrated timeframe scaling factor for ", EnumToString((ENUM_TIMEFRAMES)_Period), ": ", timeframeScalingFactor);
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
      if(i == rates_total - 1 && !IncludeLastCandle) {
         // Copy the previous value to maintain continuity
         if(i > 0) {
            LineBuffer[i] = LineBuffer[i-1];
            ColorBuffer[i] = ColorBuffer[i-1];
         }
      } else {
         // Check if we should update range size dynamically
         if(EnableAdaptiveRange && ArraySize(legHistory) > 0) {
            currentRangeSize = CalculateAdaptiveRangeSize();
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
//| Initialize threshold smoothing                                   |
//+------------------------------------------------------------------+
void InitThresholdSmoothing()
{
    // Resize array for smoothing periods
    ArrayResize(recentThresholds, ThresholdSmoothingPeriods);
    
    // Initialize with the initial range size
    for(int i = 0; i < ThresholdSmoothingPeriods; i++) {
        recentThresholds[i] = InitialRangeSize;
    }
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
   int legStartBar = lastRangeBarIndex;
   
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
      int legDuration = bar_index - legStartBar;
      AddCompletedLeg(MathAbs(currentLevel - prevLevel) / point, wasUpTrend, time, legDuration);
   }
}

//+------------------------------------------------------------------+
//| Add a completed leg to history                                  |
//+------------------------------------------------------------------+
void AddCompletedLeg(double size, bool isUpleg, datetime time, int duration)
{
   // Create new leg info
   LegInfo newLeg;
   newLeg.size = size;
   newLeg.isUpleg = isUpleg;
   newLeg.time = time;
   newLeg.duration = duration;
   
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
      info += StringFormat("%s%.1f (%db)", 
                           legHistory[i].isUpleg ? "↑" : "↓", 
                           legHistory[i].size,
                           legHistory[i].duration);
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
   
   // Add calibration info
   if(AutoInstrumentCalibration || AutoTimeframeCalibration) {
      info += StringFormat("\nCalibration: Instr=%.2f, TF=%.2f", 
                           instrumentVolatilityFactor, timeframeScalingFactor);
   }
   
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
//| Calculate adaptive range size                                    |
//+------------------------------------------------------------------+
int CalculateAdaptiveRangeSize()
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
   
   // Calculate raw range size with market condition adjustment
   double rawRangeSize = avgLegSize * adjustmentFactor;
   
   // Apply calibration factors if enabled
   if(AutoInstrumentCalibration) {
      rawRangeSize *= instrumentVolatilityFactor;
   }
   
   if(AutoTimeframeCalibration) {
      rawRangeSize *= timeframeScalingFactor;
   }
   
   // Apply min/max constraints to maintain zigzag appearance
   double baseThreshold = InitialRangeSize;
   double minThreshold = baseThreshold * MinThresholdMultiplier;
   double maxThreshold = baseThreshold * MaxThresholdMultiplier;
   
   if(rawRangeSize < minThreshold) rawRangeSize = minThreshold;
   if(rawRangeSize > maxThreshold) rawRangeSize = maxThreshold;
   
   // Apply smoothing to prevent rapid threshold changes
   // Shift values in the array
   for(int i = ThresholdSmoothingPeriods - 1; i > 0; i--) {
      recentThresholds[i] = recentThresholds[i-1];
   }
   recentThresholds[0] = rawRangeSize;
   
   // Calculate simple average
   double smoothedRangeSize = 0;
   for(int i = 0; i < ThresholdSmoothingPeriods; i++) {
      smoothedRangeSize += recentThresholds[i];
   }
   smoothedRangeSize /= ThresholdSmoothingPeriods;
   
   return MathMax(1, (int)MathRound(smoothedRangeSize));
}

//+------------------------------------------------------------------+
//| Calculate timeframe scaling factor                               |
//+------------------------------------------------------------------+
double CalculateTimeframeScaling()
{
   // Base period in minutes
   double basePeriod = 5.0; // Using M5 as reference
   
   // Current timeframe in minutes
   double currentPeriod;
   switch(_Period) {
      case PERIOD_M1:  currentPeriod = 1; break;
      case PERIOD_M5:  currentPeriod = 5; break;
      case PERIOD_M15: currentPeriod = 15; break;
      case PERIOD_M30: currentPeriod = 30; break;
      case PERIOD_H1:  currentPeriod = 60; break;
      case PERIOD_H4:  currentPeriod = 240; break;
      case PERIOD_D1:  currentPeriod = 1440; break;
      case PERIOD_W1:  currentPeriod = 10080; break;
      case PERIOD_MN1: currentPeriod = 43200; break;
      default:         currentPeriod = _Period;
   }
   
   // Calculate scaling - square root relationship works well for timeframes
   // (prevents extreme values while still providing appropriate scaling)
   return MathSqrt(currentPeriod / basePeriod);
}

//+------------------------------------------------------------------+
//| Calculate instrument volatility factor                           |
//+------------------------------------------------------------------+
double CalculateInstrumentVolatility()
{
   // Use ATR for volatility measurement
   int atrPeriod = 14;
   int barsToAnalyze = MathMin(200, Bars(_Symbol, _Period));
   
   if(barsToAnalyze < atrPeriod) {
      return 1.0; // Not enough data
   }
   
   // Calculate ATR manually
   double sumTR = 0;
   for(int i = 1; i < atrPeriod + 1; i++) {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      double prevClose = iClose(_Symbol, _Period, i+1);
      
      // True Range calculation
      double trueRange = MathMax(high - low, MathMax(MathAbs(high - prevClose), MathAbs(low - prevClose)));
      sumTR += trueRange;
   }
   
   double atr = sumTR / atrPeriod;
   
   // Convert to points
   double atrPoints = atr / _Point;
   
   // Compare to reference instrument's ATR
   // (using EURUSD M5 with typical ATR of ~80 points as reference)
   double referenceATR = 80.0;
   double volatilityRatio = atrPoints / referenceATR;
   
   // Apply square root to moderate extreme values
   return MathSqrt(volatilityRatio);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear the chart comment
   Comment("");
}
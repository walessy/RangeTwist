//+------------------------------------------------------------------+
//|                                        RangeTwist_Dynamic.mq5 |
//+------------------------------------------------------------------+
//Also Saved as Martini
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 17
#property indicator_plots   7
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed, clrGray
#property indicator_width1  2

// Standard deviation bands
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_width2  1
#property indicator_style2  STYLE_DOT
#property indicator_label2  "1SD Upper"

#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_width3  1
#property indicator_style3  STYLE_DOT
#property indicator_label3  "1SD Lower"

#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRoyalBlue
#property indicator_width4  1
#property indicator_style4  STYLE_DOT
#property indicator_label4  "2SD Upper"

#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRoyalBlue
#property indicator_width5  1
#property indicator_style5  STYLE_DOT
#property indicator_label5  "2SD Lower"

#property indicator_type6   DRAW_LINE
#property indicator_color6  clrNavy
#property indicator_width6  1
#property indicator_style6  STYLE_DOT
#property indicator_label6  "3SD Upper"

#property indicator_type7   DRAW_LINE
#property indicator_color7  clrNavy
#property indicator_width7  1
#property indicator_style7  STYLE_DOT
#property indicator_label7  "3SD Lower"

// Input parameters
input int    InitialRangeSize = 25;     // Initial range size in points
input int    MaxLegsToTrack = 8;        // Number of legs to track for statistics
input double TrendFactor = 1.3;         // Range adjustment factor for strong trends
input double ChoppyFactor = 0.7;        // Range adjustment factor for choppy markets
input double VolatilityCapFactor = 2.5; // Max allowed deviation from average (multiplier)
input color  UpColor = clrLime;         // Color for up trend
input color  DownColor = clrRed;        // Color for down trend
input color  FlatColor = clrGray;       // Color for no trend
input bool   IncLstCndl = false;        // Include last candle in calculations
input bool   EnableDynamicRange = true; // Enable dynamic range calculation
input bool   ShowStats = true;          // Show statistics on chart
input int    ATRPeriod = 14;            // ATR period for range calibration
input double ATRMultiplier = 0.5;       // ATR multiplier for range calibration
input double SmoothingFactor = 0.2;     // Max allowed change in range per update (as fraction)

// Standard Deviation Band settings
input bool   ShowStdDevBands = true;    // Show standard deviation bands
input int    StdDevPeriod = 20;         // Period for standard deviation calculation
input color  StdDev1Color = clrDodgerBlue; // Color for 1 StdDev bands
input color  StdDev2Color = clrRoyalBlue;  // Color for 2 StdDev bands
input color  StdDev3Color = clrNavy;       // Color for 3 StdDev bands

// Buffers
double LineBuffer[];         // Range line
double ColorBuffer[];        // Color index for line
double CurrentRangeBuffer[];  // Current range size for data window
double LegCountBuffer[];      // Count of consecutive legs in same direction
double AvgLegSizeBuffer[];    // Average leg size
double ATRBuffer[];           // ATR values
double OptimalRangeBuffer[];  // Optimal range values
double MarketNoiseBuff[];     // Market noise measurement

// Standard deviation band buffers
double StdDev1UpperBuffer[];  // 1 Standard deviation upper band
double StdDev1LowerBuffer[];  // 1 Standard deviation lower band
double StdDev2UpperBuffer[];  // 2 Standard deviation upper band
double StdDev2LowerBuffer[];  // 2 Standard deviation lower band
double StdDev3UpperBuffer[];  // 3 Standard deviation upper band
double StdDev3LowerBuffer[];  // 3 Standard deviation lower band
double StdDevValueBuffer[];   // Current standard deviation value

// State variables
double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;
int currentRangeSize;
double minValidRange;       // Minimum valid range value for current symbol

// Leg history tracking
struct LegInfo {
   double size;              // Size of the leg in points
   bool isUpleg;             // Direction of the leg
   datetime time;            // Time when leg completed
   double atr;               // ATR at the time of leg completion
};

LegInfo legHistory[];        // Array to store leg history
int ATRHandle;               // Handle for ATR indicator

//+------------------------------------------------------------------+
//| Calculate standard deviation bands around the range line         |
//+------------------------------------------------------------------+
void CalculateStdDevBands(int i, int rates_total)
{
   // Need enough bars for calculation
   if(i < StdDevPeriod) return;
   
   // Calculate standard deviation of main line values
   double sum = 0;
   double sumSquared = 0;
   int count = 0;
   
   // Collect data for standard deviation calculation
   for(int j = i - StdDevPeriod + 1; j <= i; j++) {
      if(j >= 0 && j < rates_total && LineBuffer[j] != EMPTY_VALUE) {
         sum += LineBuffer[j];
         sumSquared += LineBuffer[j] * LineBuffer[j];
         count++;
      }
   }
   
   // Cannot calculate if not enough valid data points
   if(count < 2) return;
   
   // Calculate mean
   double mean = sum / count;
   
   // Calculate standard deviation: sqrt(E[X²] - E[X]²)
   double variance = (sumSquared / count) - (mean * mean);
   double stdDev = MathSqrt(MathMax(0, variance));
   
   // Store standard deviation value
   StdDevValueBuffer[i] = stdDev;
   
   // Calculate bands at 1, 2, and 3 standard deviations
   StdDev1UpperBuffer[i] = LineBuffer[i] + 1 * stdDev;
   StdDev1LowerBuffer[i] = LineBuffer[i] - 1 * stdDev;
   
   StdDev2UpperBuffer[i] = LineBuffer[i] + 2 * stdDev;
   StdDev2LowerBuffer[i] = LineBuffer[i] - 2 * stdDev;
   
   StdDev3UpperBuffer[i] = LineBuffer[i] + 3 * stdDev;
   StdDev3LowerBuffer[i] = LineBuffer[i] - 3 * stdDev;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   
   // Standard deviation bands
   SetIndexBuffer(2, StdDev1UpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, StdDev1LowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, StdDev2UpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, StdDev2LowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, StdDev3UpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, StdDev3LowerBuffer, INDICATOR_DATA);

   // Data buffers for statistics
   SetIndexBuffer(8, CurrentRangeBuffer, INDICATOR_DATA);
   SetIndexBuffer(9, LegCountBuffer, INDICATOR_DATA);
   SetIndexBuffer(10, AvgLegSizeBuffer, INDICATOR_DATA);
   SetIndexBuffer(11, ATRBuffer, INDICATOR_DATA);
   SetIndexBuffer(12, OptimalRangeBuffer, INDICATOR_DATA);
   SetIndexBuffer(13, MarketNoiseBuff, INDICATOR_DATA);
   SetIndexBuffer(14, StdDevValueBuffer, INDICATOR_DATA);
   
   // Initialize all buffers with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   ArrayInitialize(StdDev1UpperBuffer, EMPTY_VALUE);
   ArrayInitialize(StdDev1LowerBuffer, EMPTY_VALUE);
   ArrayInitialize(StdDev2UpperBuffer, EMPTY_VALUE);
   ArrayInitialize(StdDev2LowerBuffer, EMPTY_VALUE);
   ArrayInitialize(StdDev3UpperBuffer, EMPTY_VALUE);
   ArrayInitialize(StdDev3LowerBuffer, EMPTY_VALUE);
   ArrayInitialize(CurrentRangeBuffer, EMPTY_VALUE);
   ArrayInitialize(LegCountBuffer, EMPTY_VALUE);
   ArrayInitialize(AvgLegSizeBuffer, EMPTY_VALUE);
   ArrayInitialize(ATRBuffer, EMPTY_VALUE);
   ArrayInitialize(OptimalRangeBuffer, EMPTY_VALUE);
   ArrayInitialize(MarketNoiseBuff, EMPTY_VALUE);
   ArrayInitialize(StdDevValueBuffer, EMPTY_VALUE);
   
   // Set up colors and styles
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, FlatColor);  // Index 2  = Flatcolor
   PlotIndexSetString(0, PLOT_LABEL, "Range Line");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
  
   // Set up standard deviation band colors and styles
   if(ShowStdDevBands) {
      // 1 SD bands
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, StdDev1Color);
      PlotIndexSetInteger(3, PLOT_LINE_COLOR, StdDev1Color);
      // 2 SD bands
      PlotIndexSetInteger(4, PLOT_LINE_COLOR, StdDev2Color);
      PlotIndexSetInteger(5, PLOT_LINE_COLOR, StdDev2Color);
      // 3 SD bands
      PlotIndexSetInteger(6, PLOT_LINE_COLOR, StdDev3Color);
      PlotIndexSetInteger(7, PLOT_LINE_COLOR, StdDev3Color);
   } else {
      // Hide bands if disabled
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   
   // Hide secondary data buffers from chart
   PlotIndexSetInteger(8, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(8, PLOT_LABEL, "Current Range Size");
   PlotIndexSetInteger(9, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(9, PLOT_LABEL, "Consecutive Legs");
   PlotIndexSetInteger(10, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(10, PLOT_LABEL, "Avg Leg Size");
   PlotIndexSetInteger(11, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(11, PLOT_LABEL, "ATR");
   PlotIndexSetInteger(12, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(12, PLOT_LABEL, "Optimal Range");
   PlotIndexSetInteger(13, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(13, PLOT_LABEL, "Market Noise");
   PlotIndexSetInteger(14, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(14, PLOT_LABEL, "Standard Deviation");
   
   // Initialize state variables
   point = _Point;
   
   // Calculate minimum valid range based on symbol properties
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   minValidRange = MathMax(tickSize, pipValue * 0.5); // At least half a pip or one tick
   
   // Initialize current range size using the input, but ensure it meets minimum requirements
   currentRangeSize = MathMax(1, InitialRangeSize);
   
   // Initialize leg history array
   ArrayResize(legHistory, 0);
   
   // Get ATR indicator handle
   ATRHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(ATRHandle == INVALID_HANDLE) {
      Print("Error creating ATR indicator");
      return(INIT_FAILED);
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
   
   // Load ATR values
   if(CopyBuffer(ATRHandle, 0, 0, rates_total, ATRBuffer) <= 0) {
      Print("Error copying ATR data");
      return(0);
   }
   
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
         currentRangeSize = MathMax(1, InitialRangeSize);
      }
   }
   
   // Determine calculation boundaries
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   // Ensure we have enough data for standard deviation calculations
   if(ShowStdDevBands && start < StdDevPeriod) {
      start = StdDevPeriod;
   }
   
   int limit = rates_total;
   
   // Handle last candle differently to prevent repainting
   int actualLimit = limit;
   if(!IncLstCndl) {
      actualLimit = limit - 1; // Don't process the last candle for range calculations
      
      // But still draw the line on the last candle by copying the previous value
      if(actualLimit > 0 && actualLimit < rates_total) {
         LineBuffer[rates_total-1] = LineBuffer[actualLimit];
         ColorBuffer[rates_total-1] = ColorBuffer[actualLimit];
         
         // Copy other buffer values for data window display
         CurrentRangeBuffer[rates_total-1] = CurrentRangeBuffer[actualLimit];
         LegCountBuffer[rates_total-1] = LegCountBuffer[actualLimit];
         AvgLegSizeBuffer[rates_total-1] = AvgLegSizeBuffer[actualLimit];
         OptimalRangeBuffer[rates_total-1] = OptimalRangeBuffer[actualLimit];
         MarketNoiseBuff[rates_total-1] = MarketNoiseBuff[actualLimit];
         StdDevValueBuffer[rates_total-1] = StdDevValueBuffer[actualLimit];
         
         // Copy standard deviation bands
         StdDev1UpperBuffer[rates_total-1] = StdDev1UpperBuffer[actualLimit];
         StdDev1LowerBuffer[rates_total-1] = StdDev1LowerBuffer[actualLimit];
         StdDev2UpperBuffer[rates_total-1] = StdDev2UpperBuffer[actualLimit];
         StdDev2LowerBuffer[rates_total-1] = StdDev2LowerBuffer[actualLimit];
         StdDev3UpperBuffer[rates_total-1] = StdDev3UpperBuffer[actualLimit];
         StdDev3LowerBuffer[rates_total-1] = StdDev3LowerBuffer[actualLimit];
      }
   }

   // Calculate market noise for each bar (excluding last candle if needed)
   CalculateMarketNoise(rates_total, prev_calculated, high, low, close, !IncLstCndl);
      
   // Process bars up to the limit (excluding last candle if needed)
   for(int i = start; i < actualLimit; i++)
   {
      // Calculate optimal range size for this bar
      double optimal = CalculateOptimalRangeSize(i, high, low, close);
      OptimalRangeBuffer[i] = optimal;
      
      // Check if we should update range size dynamically
      if(EnableDynamicRange) {
         if(ArraySize(legHistory) > 0) {
            currentRangeSize = CalculateDynamicRangeSize(i);
         } else if(optimal > 0) {
            // Use optimal calculation if we don't have leg history yet
            currentRangeSize = (int)MathRound(optimal);
         }
      }
      
      // Calculate using current range size
      CalculateRange(i, high[i], low[i], rates_total, time[i]);
      
      // Update data window buffers
      CurrentRangeBuffer[i] = currentRangeSize;
      LegCountBuffer[i] = CalculateConsecutiveLegs();
      AvgLegSizeBuffer[i] = CalculateAverageLegSize();
      
      // Calculate and update standard deviation bands
      if(ShowStdDevBands) {
         CalculateStdDevBands(i, rates_total);
      }
   }
      
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate market noise (0-1 scale, higher means more noise)      |
//+------------------------------------------------------------------+
void CalculateMarketNoise(int rates_total, int prev_calculated, 
                          const double &high[], const double &low[], 
                          const double &close[], 
                          bool skipLastCandle = false)
{
   int period = 14; // Period for noise calculation
   
   int start = prev_calculated > 0 ? prev_calculated - period : 0;
   start = MathMax(period, start); // Ensure we have enough bars
   
   int limit = rates_total;
   if(skipLastCandle && limit > 0) {
      limit--; // Don't process the last candle
   }
   
   for(int i = start; i < limit; i++) {
      double dirMove = MathAbs(close[i] - close[i-period]);
      double totalMove = 0;
      
      // Sum of the absolute price moves
      for(int j = i-period+1; j <= i; j++) {
         totalMove += MathAbs(close[j] - close[j-1]);
      }
      
      // Calculate noise ratio (1 - efficiency ratio)
      // 0 = perfectly directional, 1 = perfectly noisy
      if(totalMove > 0) {
         MarketNoiseBuff[i] = 1.0 - (dirMove / totalMove);
      } else {
         MarketNoiseBuff[i] = 0.5; // Default to mid-value if no movement
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate optimal range size for current market conditions       |
//+------------------------------------------------------------------+
double CalculateOptimalRangeSize(int i, const double &high[], const double &low[], const double &close[])
{
   if(i < 14) return InitialRangeSize; // Need enough data
   
   // Use ATR as base value for volatility measurement
   double atr = ATRBuffer[i];
   
   // Scale ATR by multiplier for optimal size
   double baseRange = atr * ATRMultiplier / point;
   
   // Adjust based on market noise
   double noise = MarketNoiseBuff[i];
   double noiseAdjust = 0;
   
   // Choppy market (high noise) needs smaller ranges to catch movements
   // Trending market (low noise) benefits from larger ranges to avoid whipsaws
   if(noise > 0.7) { // Very choppy
      noiseAdjust = -0.3; // Reduce range by 30%
   } else if(noise > 0.5) { // Moderately choppy
      noiseAdjust = -0.15; // Reduce range by 15%
   } else if(noise < 0.3) { // Strong trend
      noiseAdjust = 0.25; // Increase range by 25%
   }
   
   // Apply noise adjustment
   double adjustedRange = baseRange * (1 + noiseAdjust);
   
   // Apply minimum range constraint
   return MathMax(minValidRange / point, adjustedRange);
}

//+------------------------------------------------------------------+
//| Calculate range level for each bar                               |
//+------------------------------------------------------------------+
void CalculateRange(int bar_index, double high, double low, int rates_total, datetime time)
{
   // Ensure the range is at least the minimum valid value for the symbol
   double range = MathMax(minValidRange, currentRangeSize * point);
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
      AddCompletedLeg(MathAbs(currentLevel - prevLevel) / point, wasUpTrend, time, ATRBuffer[bar_index]);
   }
}

//+------------------------------------------------------------------+
//| Add a completed leg to history                                  |
//+------------------------------------------------------------------+
void AddCompletedLeg(double size, bool isUpleg, datetime time, double atr)
{
   // Create new leg info
   LegInfo newLeg;
   newLeg.size = size;
   newLeg.isUpleg = isUpleg;
   newLeg.time = time;
   newLeg.atr = atr;
   
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
   
   // Calculate ATR-based information
   double avgATR = 0;
   for(int i = 0; i < count; i++) {
      avgATR += legHistory[i].atr;
   }
   avgATR /= count;
   
   double legSizeATRRatio = avgSize * point / avgATR;
   info += StringFormat("\nAvg ATR: %.5f | Leg/ATR Ratio: %.2f", avgATR, legSizeATRRatio);
   
   // Display how range is being determined (for debugging)
   string rangeStrategy = "Dynamic";
   if(!EnableDynamicRange) rangeStrategy = "Fixed";
   info += StringFormat("\nRange Strategy: %s | Optimal: %.1f", rangeStrategy, OptimalRangeBuffer[Bars(_Symbol, PERIOD_CURRENT)-1]);
   
   // Add standard deviation information if bands are displayed
   if(ShowStdDevBands) {
      int lastBar = Bars(_Symbol, PERIOD_CURRENT)-1;
      if(lastBar >= 0 && StdDevValueBuffer[lastBar] != EMPTY_VALUE) {
         info += StringFormat("\nStd Dev: %.5f | Period: %d", StdDevValueBuffer[lastBar], StdDevPeriod);
      }
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
//| Calculate weighted average based on recency
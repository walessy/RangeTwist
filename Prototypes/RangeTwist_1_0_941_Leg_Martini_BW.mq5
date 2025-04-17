//+------------------------------------------------------------------+
//|                  RangeTwist_1_0_94_Leg_Martini_BW.mq5           |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.0.95"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   3
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2
#property indicator_type2   DRAW_ARROW  
#property indicator_color2  clrDodgerBlue
#property indicator_width2  4        // Increased arrow width
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrMagenta
#property indicator_width3  4        // Increased arrow width

// Input parameters
input int    RangeSize = 25;              // Base range size in points
input bool   IncLstCndl = false;          // Include last candle in calculations
input int    MaxLegsToTrack = 10;         // Number of legs to track for statistics
input int    FractalLegs = 5;             // Number of legs to form a fractal (must be odd number >= 3)
input double FractalStrengthThreshold = 1.5; // Threshold for fractal strength (central leg vs. others)
input int    HistoricalBars = 500;        // Number of historical bars to process for fractals
input int    ArrowSize = 4;               // Size of the fractal arrows (1-5)
input int    ArrowOffset = 5;             // Offset in points for arrow placement
input color  UpColor = clrLime;           // Color for up trend
input color  DownColor = clrRed;          // Color for down trend
input color  BullishFractalColor = clrDodgerBlue; // Color for bullish fractals
input color  BearishFractalColor = clrMagenta;   // Color for bearish fractals
input bool   EnableDynamicRange = true;   // Enable dynamic range calculation
input bool   ShowStats = true;            // Show statistics on chart

// Buffers
double LineBuffer[];         // Primary timeframe line
double ColorBuffer[];        // Primary timeframe color
double BullishFractalBuffer[]; // Bullish fractal markers
double BearishFractalBuffer[]; // Bearish fractal markers

// Leg history structure
struct LegInfo {
   double size;              // Size of the leg in points
   bool isUpleg;             // Direction of the leg
   datetime legTime;         // Time when leg completed (renamed from 'time' to avoid conflict)
   double level;             // Price level where the leg completed
   int barIndex;             // Bar index when the leg was formed
};

// Fractal structure
struct FractalInfo {
   datetime fractalTime;     // Time the fractal formed (renamed from 'time' to avoid conflict)
   bool isBullish;           // Bullish or bearish fractal
   double strength;          // Strength of the fractal (central leg size relative to others)
   double level;             // Price level where the fractal formed
   int legsInPattern;        // Number of legs in the pattern
   int barIndex;             // Bar index when the fractal was formed
};

// State variables
double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;
int currentRangeSize;
bool initialHistoricalScan = false;  // Flag for initial historical fractal scan

// Leg history and fractals
LegInfo legHistory[];        // Array to store leg history
FractalInfo fractals[];      // Array to store identified fractals

// Temporary arrays for historical processing
double tempHighs[];
double tempLows[];
double tempOpens[];
double tempCloses[];
datetime tempTimes[];

// Arrow codes for fractal markers
#define SYMBOL_FRACTAL_UP    108   // Changed to larger up arrow (was 217)
#define SYMBOL_FRACTAL_DOWN  108   // Changed to larger down arrow (was 218)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check fractal legs value
   if(FractalLegs < 3 || FractalLegs % 2 == 0) {
      Print("FractalLegs must be an odd number and at least 3");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Set up indicator buffers
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BullishFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BearishFractalBuffer, INDICATOR_DATA);

   // Initialize buffers with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   ArrayInitialize(BullishFractalBuffer, EMPTY_VALUE);
   ArrayInitialize(BearishFractalBuffer, EMPTY_VALUE);
   
   // Set up colors and styles
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  
   PlotIndexSetString(0, PLOT_LABEL, "Range Line");
   
   // Set up fractal markers with larger arrows
   PlotIndexSetInteger(1, PLOT_ARROW, SYMBOL_FRACTAL_UP);
   PlotIndexSetString(1, PLOT_LABEL, "Bullish Fractal");
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, ArrowOffset); // Shift arrows up a bit
   
   PlotIndexSetInteger(2, PLOT_ARROW, SYMBOL_FRACTAL_DOWN);
   PlotIndexSetString(2, PLOT_LABEL, "Bearish Fractal");
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -ArrowOffset); // Shift arrows down a bit
   
   // Initialize state variables
   point = _Point;
   currentRangeSize = RangeSize;
   initialHistoricalScan = false;
   
   // Initialize leg history array
   ArrayResize(legHistory, 0);
   
   // Initialize fractals array
   ArrayResize(fractals, 0);
   
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
   if(rates_total < FractalLegs) return(0);
   
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset indicators and initialize
      ArrayInitialize(LineBuffer, EMPTY_VALUE);
      ArrayInitialize(BullishFractalBuffer, EMPTY_VALUE);
      ArrayInitialize(BearishFractalBuffer, EMPTY_VALUE);
      
      ArrayResize(legHistory, 0);
      ArrayResize(fractals, 0);
      initialHistoricalScan = false;
      
      // Initialize the first range value
      if(rates_total > 0)
      {
         currentLevel = close[0];
         prevLevel = close[0];
         lastRangeBarIndex = 0;
         upTrend = true;
         currentRangeSize = RangeSize;
         
         LineBuffer[0] = currentLevel;
         ColorBuffer[0] = 0; // Start with up color
      }
   }
   
   // Perform initial historical scan if not done yet
   if(!initialHistoricalScan) {
      ScanHistoricalFractals(rates_total, time, open, high, low, close);
      initialHistoricalScan = true;
   }
   
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   int limit = rates_total;
   
   // Main calculation loop
   for(int i = start; i < limit; i++)
   {
      if(i == rates_total - 1 && !IncLstCndl) {
         // For the last candle, when we don't want to include it in calculations
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
         
         // Check for large vertical gaps to prevent vertical line artifacts
         if(i > 0 && MathAbs(LineBuffer[i-1] - currentLevel) > currentRangeSize*_Point*10) {
            LineBuffer[i-1] = EMPTY_VALUE; // Break the line to prevent vertical artifacts
         }
         LineBuffer[i] = currentLevel;
         ColorBuffer[i] = upTrend ? 0 : 1;
      }
   }
   
   // Process fractals
   ProcessFractals(rates_total);
   
   // Display statistics if enabled
   if(ShowStats) {
      DisplayStats(rates_total - 1);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Scan historical data to find fractals                            |
//+------------------------------------------------------------------+
void ScanHistoricalFractals(int rates_total, const datetime &time[], 
                           const double &open[], const double &high[], 
                           const double &low[], const double &close[])
{
   int barsToProcess = MathMin(rates_total, HistoricalBars);
   if(barsToProcess < FractalLegs + 10) return; // Need enough bars for meaningful scan
   
   // Starting from FractalLegs bars ago to allow for pattern formation
   int startBar = barsToProcess - 1;
   
   Print("Starting historical fractal scan on ", barsToProcess, " bars...");
   
   // Copy necessary price data to temp arrays to speed up processing
   ArrayResize(tempHighs, barsToProcess);
   ArrayResize(tempLows, barsToProcess);
   ArrayResize(tempOpens, barsToProcess);
   ArrayResize(tempCloses, barsToProcess);
   ArrayResize(tempTimes, barsToProcess);
   
   for(int i = 0; i < barsToProcess; i++) {
      tempHighs[i] = high[i];
      tempLows[i] = low[i];
      tempOpens[i] = open[i];
      tempCloses[i] = close[i];
      tempTimes[i] = time[i];
   }
   
   // Initialize with the very first bar
   currentLevel = tempCloses[0];
   prevLevel = tempCloses[0];
   upTrend = true;
   
   // Process each bar to identify legs and fractals
   for(int i = 1; i < barsToProcess; i++) {
      CalculateRange(i, tempHighs[i], tempLows[i], barsToProcess, tempTimes[i]);
   }
   
   // Clean up temporary arrays
   ArrayResize(tempHighs, 0);
   ArrayResize(tempLows, 0);
   ArrayResize(tempOpens, 0);
   ArrayResize(tempCloses, 0);
   ArrayResize(tempTimes, 0);
   
   Print("Historical fractal scan complete. Found ", ArraySize(fractals), " fractals.");
}

//+------------------------------------------------------------------+
//| Calculate range level for each bar                               |
//+------------------------------------------------------------------+
void CalculateRange(int bar_index, double high, double low, int rates_total, const datetime &bar_time)
{
   double range = currentRangeSize * _Point;
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
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(low <= currentLevel - range)
      {
         // Trend has reversed to down
         prevLevel = currentLevel;
         upTrend = false;
         currentLevel = currentLevel - range;
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
   }
   else // downtrend
   {
      if(low <= currentLevel - range)
      {
         // Move the line down
         prevLevel = currentLevel;
         currentLevel = currentLevel - range;
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(high >= currentLevel + range)
      {
         // Trend has reversed to up
         prevLevel = currentLevel;
         upTrend = true;
         currentLevel = currentLevel + range;
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
   }
   
   // If a leg was completed, add it to history
   if(legCompleted) {
      AddCompletedLeg(MathAbs(currentLevel - prevLevel) / _Point, 
                     wasUpTrend, bar_time, currentLevel, bar_index);
   }
}

//+------------------------------------------------------------------+
//| Add a completed leg to history                                   |
//+------------------------------------------------------------------+
void AddCompletedLeg(double size, bool isUpleg, datetime legTime, double level, int barIndex)
{
   // Create new leg info
   LegInfo newLeg;
   newLeg.size = size;
   newLeg.isUpleg = isUpleg;
   newLeg.legTime = legTime;
   newLeg.level = level;
   newLeg.barIndex = barIndex;
   
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
   
   // Check for fractal patterns after adding the new leg
   DetectFractalPatterns();
}

//+------------------------------------------------------------------+
//| Detect Bill Williams-style fractal patterns in leg history       |
//+------------------------------------------------------------------+
void DetectFractalPatterns()
{
   // Need minimum legs to form a fractal (e.g., 5 legs for a standard fractal)
   int count = ArraySize(legHistory);
   if(count < FractalLegs) return;
   
   // Calculate middle leg position
   int middlePos = count - (FractalLegs / 2) - 1;
   
   // Check for bullish fractal (middle leg is up and largest)
   if(legHistory[middlePos].isUpleg) {
      bool isBullishFractal = true;
      double centralLegSize = legHistory[middlePos].size;
      double sumOtherLegs = 0;
      
      // Check if surrounding legs confirm the pattern
      for(int i = count - FractalLegs; i < count; i++) {
         if(i == middlePos) continue; // Skip the central leg
         
         // For a bullish fractal, surrounding legs should be smaller down legs
         if(i < middlePos && legHistory[i].isUpleg) {
            isBullishFractal = false;
            break;
         }
         
         if(i > middlePos && !legHistory[i].isUpleg) {
            isBullishFractal = false;
            break;
         }
         
         sumOtherLegs += legHistory[i].size;
      }
      
      // Calculate fractal strength (central leg relative to others)
      double avgOtherLegs = sumOtherLegs / (FractalLegs - 1);
      double fractalStrength = centralLegSize / avgOtherLegs;
      
      // If it's a valid bullish fractal with sufficient strength
      if(isBullishFractal && fractalStrength >= FractalStrengthThreshold) {
         AddFractal(legHistory[middlePos].legTime, 
                   true, 
                   fractalStrength, 
                   legHistory[middlePos].level, 
                   FractalLegs,
                   legHistory[middlePos].barIndex);
      }
   }
   
   // Check for bearish fractal (middle leg is down and largest)
   if(!legHistory[middlePos].isUpleg) {
      bool isBearishFractal = true;
      double centralLegSize = legHistory[middlePos].size;
      double sumOtherLegs = 0;
      
      // Check if surrounding legs confirm the pattern
      for(int i = count - FractalLegs; i < count; i++) {
         if(i == middlePos) continue; // Skip the central leg
         
         // For a bearish fractal, surrounding legs should be smaller up legs
         if(i < middlePos && !legHistory[i].isUpleg) {
            isBearishFractal = false;
            break;
         }
         
         if(i > middlePos && legHistory[i].isUpleg) {
            isBearishFractal = false;
            break;
         }
         
         sumOtherLegs += legHistory[i].size;
      }
      
      // Calculate fractal strength (central leg relative to others)
      double avgOtherLegs = sumOtherLegs / (FractalLegs - 1);
      double fractalStrength = centralLegSize / avgOtherLegs;
      
      // If it's a valid bearish fractal with sufficient strength
      if(isBearishFractal && fractalStrength >= FractalStrengthThreshold) {
         AddFractal(legHistory[middlePos].legTime, 
                   false, 
                   fractalStrength, 
                   legHistory[middlePos].level, 
                   FractalLegs,
                   legHistory[middlePos].barIndex);
      }
   }
}

//+------------------------------------------------------------------+
//| Add a detected fractal to the fractals array                     |
//+------------------------------------------------------------------+
void AddFractal(datetime fractalTime, bool isBullish, double strength, double level, int legsInPattern, int barIndex)
{
   // Check if this fractal already exists (avoid duplicates)
   for(int i = 0; i < ArraySize(fractals); i++) {
      if(fractals[i].barIndex == barIndex && fractals[i].isBullish == isBullish) {
         return; // Already have this fractal, skip
      }
   }
   
   // Add to array
   int count = ArraySize(fractals);
   ArrayResize(fractals, count + 1);
   
   // Fill in fractal info
   fractals[count].fractalTime = fractalTime;
   fractals[count].isBullish = isBullish;
   fractals[count].strength = strength;
   fractals[count].level = level;
   fractals[count].legsInPattern = legsInPattern;
   fractals[count].barIndex = barIndex;
   
   // Log fractal detection
   Print("New ", isBullish ? "bullish" : "bearish", " fractal detected at ", 
         TimeToString(fractalTime), " with strength ", DoubleToString(strength, 2));
}

//+------------------------------------------------------------------+
//| Process all fractals for display                                 |
//+------------------------------------------------------------------+
void ProcessFractals(int rates_total)
{
   // First, clear the fractal buffers
   ArrayInitialize(BullishFractalBuffer, EMPTY_VALUE);
   ArrayInitialize(BearishFractalBuffer, EMPTY_VALUE);
   
   // Process all detected fractals
   for(int i = 0; i < ArraySize(fractals); i++) {
      int barIndex = fractals[i].barIndex;
      
      // Make sure the bar index is within range
      if(barIndex >= 0 && barIndex < rates_total) {
         // Place arrows at fractal levels with slight offset for better visibility
         if(fractals[i].isBullish) {
            // Place bullish fractals above the level
            BullishFractalBuffer[barIndex] = fractals[i].level; 
         } else {
            // Place bearish fractals below the level
            BearishFractalBuffer[barIndex] = fractals[i].level;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Display statistics                                               |
//+------------------------------------------------------------------+
void DisplayStats(int currentBar)
{
   string info = "===== RANGE LEG ANALYSIS =====\n\n";
   
   // Current trend and level
   info += StringFormat("Current: %s trend at %.5f | Range Size: %d points\n", 
                      upTrend ? "Up" : "Down", 
                      currentLevel,
                      currentRangeSize);
   
   // Leg history
   int legCount = ArraySize(legHistory);
   if(legCount > 0) {
      info += "Recent Legs: ";
      int legsToShow = MathMin(5, legCount);
      for(int i = legCount - 1; i >= MathMax(0, legCount - legsToShow); i--) {
         info += StringFormat("%s%.1f", legHistory[i].isUpleg ? "↑" : "↓", legHistory[i].size);
         if(i > MathMax(0, legCount - legsToShow)) info += ", ";
      }
      
      // Leg statistics
      double avgSize = CalculateAverageLegSize();
      double stdDev = CalculateStandardDeviation();
      int consecutiveCount = CalculateConsecutiveLegs();
      
      info += StringFormat("\nStats: Avg Size: %.1f | StdDev: %.1f | Consecutive: %d\n", 
                         avgSize, stdDev, consecutiveCount);
      
      // Market type classification
      double volatilityRatio = stdDev / avgSize;
      string marketType = "Undefined";
      if(volatilityRatio < 0.2) marketType = "Low Volatility";
      else if(volatilityRatio < 0.5) marketType = "Normal";
      else marketType = "High Volatility";
      
      if(consecutiveCount >= 3) marketType += " Trending";
      else if(legCount > 1 && legHistory[legCount-1].isUpleg != legHistory[legCount-2].isUpleg) 
         marketType += " Choppy";
      
      info += StringFormat("Market Type: %s\n\n", marketType);
   }
   
   // Add fractal information
   info += "--- FRACTAL PATTERNS ---\n";
   
   int fractalCount = ArraySize(fractals);
   if(fractalCount > 0) {
      // Show the last 5 fractals (increased from 3)
      int fractalToShow = MathMin(5, fractalCount);
      for(int i = fractalCount - 1; i >= MathMax(0, fractalCount - fractalToShow); i--) {
         info += StringFormat("%s Fractal | Strength: %.2f | Time: %s\n",
                           fractals[i].isBullish ? "Bullish" : "Bearish",
                           fractals[i].strength,
                           TimeToString(fractals[i].fractalTime));
      }
      
      // Add total counts
      int bullishCount = 0, bearishCount = 0;
      for(int i = 0; i < fractalCount; i++) {
         if(fractals[i].isBullish) bullishCount++;
         else bearishCount++;
      }
      
      info += StringFormat("\nTotal Fractals: %d (%d bullish, %d bearish)",
                        fractalCount, bullishCount, bearishCount);
   } else {
      info += "No fractals detected yet\n";
   }
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| Calculate average leg size                                       |
//+------------------------------------------------------------------+
double CalculateAverageLegSize()
{
   int count = ArraySize(legHistory);
   if(count == 0) return RangeSize;
   
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
   if(count == 0) return RangeSize;
   
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
      adjustmentFactor = 1.2; // Increase range size
   }
   
   // Choppy market (alternating directions)
   int legCount = ArraySize(legHistory);
   if(consecutiveCount == 1 && legCount > 1 && 
      legHistory[legCount-1].isUpleg != legHistory[legCount-2].isUpleg) {
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
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear the chart comment
   Comment("");
}
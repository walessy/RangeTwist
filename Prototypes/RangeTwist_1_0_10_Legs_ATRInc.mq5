#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "2.11"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrRed, clrLime, clrGray
#property indicator_width1  2

// Input parameters
input int    PriceMovementThreshold = 25;     // Inverse sensitivity: lower values create larger line shifts (in points)
input int    MaxLegsToTrack = 5;              // Number of legs to track for statistics
input bool   ShowStats = false;                // Show statistics on chart
input bool   UseATRThreshold = true;         // Use ATR for threshold calculation
input int    ATRPeriod = 14;                  // Period for ATR calculation
input double ATRMultiplier = 1.0;             // ATR multiplier for threshold

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

// ATR indicator handle
int atrHandle;

// Leg history tracking
struct LegInfo {
   double size;              // Size of the leg in points
   bool isUpleg;             // Direction of the leg
   datetime time;            // Time when leg completed
   int duration;             // Duration of leg in bars
   double legATR;            // ATR measured during this leg
};

LegInfo legHistory[];        // Array to store leg history

// Variables for tracking current leg
int currentLegStartBar = 0;          // Bar index where current leg started
double highestHigh = 0;              // Highest high in current leg
double lowestLow = 0;                // Lowest low in current leg
double sumTrueRange = 0;             // Sum of true ranges for current leg
int barCount = 0;                    // Number of bars in current leg

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
   
   // Set up colors and styles - Swapped colors: Index 0 = Down color (Red), Index 1 = Up color (Green)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrLime);     // Index 0 = Down color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrRed);    // Index 1 = Up color 
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrGray);    // Index 2 = Flat color
   PlotIndexSetString(0, PLOT_LABEL, "Range Line");
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 0);
   
   // Set indicator name for Data Window
   IndicatorSetString(INDICATOR_SHORTNAME, "RangeTwist ATR-Based");
   
   // Initialize state variables
   point = _Point;
   
   // Initialize leg history array
   ArrayResize(legHistory, 0);
   
   // Initialize ATR indicator
   if(UseATRThreshold)
   {
      atrHandle = iATR(_Symbol, _Period, ATRPeriod);
      if(atrHandle == INVALID_HANDLE)
      {
         Print("Error creating ATR indicator: ", GetLastError());
         return(INIT_FAILED);
      }
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release ATR indicator handle
   if(UseATRThreshold && atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
      
   // Clear comment from chart
   Comment("");
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
      
      // Initialize the first range value and leg tracking
      if(rates_total > 0)
      {
         currentLevel = close[0];
         prevLevel = close[0];
         lastRangeBarIndex = 0;
         upTrend = true;
         LineBuffer[0] = currentLevel;
         ColorBuffer[0] = 2; // Start with flat color
         
         // Initialize leg tracking variables
         currentLegStartBar = 0;
         highestHigh = high[0];
         lowestLow = low[0];
         sumTrueRange = 0;
         barCount = 1;
      }
   }
   
   // Calculate start and limit indices
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   // Calculate threshold based on the method chosen
   int currentThreshold = PriceMovementThreshold;
   
   if(UseATRThreshold)
   {
      currentThreshold = CalculateLegBasedThreshold();
   }
   
   // Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      // Calculate range using the dynamically calculated threshold
      CalculateRange(i, high[i], low[i], rates_total, time[i], currentThreshold);
      
      // Update data window buffers
      CurrentRangeBuffer[i] = currentThreshold;
      LegCountBuffer[i] = CalculateConsecutiveLegs();
      AvgLegSizeBuffer[i] = CalculateAverageLegSize();
   }
   
   // Debug information
   if(ShowStats && rates_total > 0) {
      PrintLegStatistics(currentThreshold);
   }
   
   // Return value must be rates_total for indicators
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate range level for each bar                               |
//+------------------------------------------------------------------+
void CalculateRange(int bar_index, double high, double low, int rates_total, datetime time, int threshold)
{
   // Update current leg tracking
   if(high > highestHigh) highestHigh = high;
   if(low < lowestLow) lowestLow = low;
   
   // Calculate true range for this bar if not first bar in chart
   if(bar_index < rates_total - 1) {
      double prevClose = iClose(_Symbol, _Period, bar_index + 1);
      double tr = MathMax(high - low, MathMax(MathAbs(high - prevClose), MathAbs(low - prevClose)));
      sumTrueRange += tr / point;
      barCount++;
   }
   
   // Use threshold to determine line movement
   double movementThreshold = threshold * point;
   
   bool legCompleted = false;
   bool wasUpTrend = upTrend;
   
   // Save leg start bar to pass to AddCompletedLeg when the leg completes
   int legStartBar = currentLegStartBar;
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(upTrend)
   {
      if(high >= currentLevel + movementThreshold)
      {
         // Move the line up
         prevLevel = currentLevel;
         currentLevel = currentLevel + movementThreshold;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Down color (red) for peaks
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(low <= currentLevel - movementThreshold)
      {
         // Trend has reversed to down
         prevLevel = currentLevel;
         upTrend = false;
         currentLevel = currentLevel - movementThreshold;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Up color (green) for bottoms
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else
      {
         // No change in level, copy the last value
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Down color (red)
      }
   }
   else // downtrend
   {
      if(low <= currentLevel - movementThreshold)
      {
         // Move the line down
         prevLevel = currentLevel;
         currentLevel = currentLevel - movementThreshold;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Up color (green) for bottoms
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else if(high >= currentLevel + movementThreshold)
      {
         // Trend has reversed to up
         prevLevel = currentLevel;
         upTrend = true;
         currentLevel = currentLevel + movementThreshold;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Down color (red) for peaks
         lastRangeBarIndex = bar_index;
         legCompleted = true;
      }
      else
      {
         // No change in level, copy the last value
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Up color (green)
      }
   }
   
   // If a leg was completed, add it to history with ATR info
   if(legCompleted) {
      AddCompletedLeg(MathAbs(currentLevel - prevLevel) / point, wasUpTrend, time, legStartBar, bar_index);
   }
}

//+------------------------------------------------------------------+
//| Add a completed leg to history                                   |
//+------------------------------------------------------------------+
void AddCompletedLeg(double size, bool isUpleg, datetime time, int startBar, int endBar)
{
   // Calculate ATR for this leg
   double legATR = 0;
   int legDuration = endBar - startBar + 1;
   
   if(legDuration > 1) {
      // Use the true range sum we've been tracking
      legATR = sumTrueRange / barCount;
   } else {
      // For single-bar legs, use the high-low range
      legATR = (iHigh(_Symbol, _Period, startBar) - iLow(_Symbol, _Period, startBar)) / point;
   }
   
   // Create new leg info
   LegInfo newLeg;
   newLeg.size = size;
   newLeg.isUpleg = isUpleg;
   newLeg.time = time;
   newLeg.duration = legDuration;
   newLeg.legATR = legATR;
   
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
   
   // Reset current leg tracking variables
   currentLegStartBar = endBar;
   highestHigh = iHigh(_Symbol, _Period, endBar);
   lowestLow = iLow(_Symbol, _Period, endBar);
   sumTrueRange = 0;
   barCount = 1;
}

//+------------------------------------------------------------------+
//| Calculate threshold based on leg ATR history                     |
//+------------------------------------------------------------------+
int CalculateLegBasedThreshold()
{
   int count = ArraySize(legHistory);
   
   // If no history yet, check if we can use standard ATR
   if(count == 0) {
      if(UseATRThreshold && atrHandle != INVALID_HANDLE) {
         double atrBuffer[];
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0) {
            double atrPoints = atrBuffer[0] / point;
            return MathMax(5, (int)MathRound(atrPoints * ATRMultiplier));
         }
      }
      return PriceMovementThreshold;
   }
   
   // Use a weighted average of the most recent legs' ATR
   double weightedSum = 0;
   double weightSum = 0;
   
   for(int i = 0; i < count; i++) {
      // More recent legs have higher weight
      double weight = count - i;
      weightedSum += legHistory[i].legATR * weight;
      weightSum += weight;
   }
   
   // Calculate weighted average ATR
   double avgLegATR = weightedSum / weightSum;
   
   // Calculate current leg's developing ATR
   double currentLegATR = 0;
   if(barCount > 0) {
      currentLegATR = sumTrueRange / barCount;
   }
   
   // Blend completed legs' ATR with current leg's developing ATR
   double blendedATR = (avgLegATR * 2 + currentLegATR) / 3;
   
   // Apply multiplier and ensure minimum threshold
   int threshold = (int)MathMax(5, MathRound(blendedATR * ATRMultiplier));
   
   return threshold;
}

//+------------------------------------------------------------------+
//| Calculate average leg size                                       |
//+------------------------------------------------------------------+
double CalculateAverageLegSize()
{
   int count = ArraySize(legHistory);
   if(count == 0) return PriceMovementThreshold;
   
   double sum = 0;
   for(int i = 0; i < count; i++) {
      sum += legHistory[i].size;
   }
   
   return sum / count;
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
//| Print leg history statistics                                     |
//+------------------------------------------------------------------+
void PrintLegStatistics(int currentThreshold)
{
   int count = ArraySize(legHistory);
   if(count == 0) return;
   
   string info = "Leg History (newest first): ";
   for(int i = count - 1; i >= 0; i--) {
      info += StringFormat("%s%.1f (ATR:%.1f, %d bars)", 
                          legHistory[i].isUpleg ? "↑" : "↓", 
                          legHistory[i].size,
                          legHistory[i].legATR,
                          legHistory[i].duration);
      if(i > 0) info += "\n";
   }
   
   double avgSize = CalculateAverageLegSize();
   int consecutiveCount = CalculateConsecutiveLegs();
   
   // Show if using auto threshold
   string thresholdInfo = UseATRThreshold ? StringFormat("%d (Leg-Based ATR)", currentThreshold) : StringFormat("%d", currentThreshold);
   
   info += StringFormat("\n\nAvg Leg Size: %.1f | Consecutive: %d | Threshold: %s", 
                         avgSize, consecutiveCount, thresholdInfo);
   
   Comment(info);
}
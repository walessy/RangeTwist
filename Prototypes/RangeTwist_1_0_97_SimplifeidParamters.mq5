#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "2.11"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed, clrGray
#property indicator_width1  2

// Input parameters
input int    PriceMovementThreshold = 25;     // Points required to shift the line
input int    MaxLegsToTrack = 5;              // Number of legs to track for statistics
input bool   ShowStats = true;                // Show statistics on chart

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
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrLime);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrRed);     // Index 1 = Down color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrGray);    // Index 2 = Flat color
   PlotIndexSetString(0, PLOT_LABEL, "Range Line");
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 0);
   
   // Set indicator name for Data Window
   IndicatorSetString(INDICATOR_SHORTNAME, "RangeTwist Threshold");
   
   // Initialize state variables
   point = _Point;
   
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
      }
   }
   
   // Calculate start and limit indices
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   // Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      // Calculate range using PriceMovementThreshold
      CalculateRange(i, high[i], low[i], rates_total, time[i]);
      
      // Update data window buffers
      CurrentRangeBuffer[i] = PriceMovementThreshold;
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
   // Use PriceMovementThreshold directly to determine line movement
   double movementThreshold = PriceMovementThreshold * point;
   
   bool legCompleted = false;
   bool wasUpTrend = upTrend;
   
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
         ColorBuffer[bar_index] = 0; // Up color
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
      if(low <= currentLevel - movementThreshold)
      {
         // Move the line down
         prevLevel = currentLevel;
         currentLevel = currentLevel - movementThreshold;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
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
//| Add a completed leg to history                                   |
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
   int consecutiveCount = CalculateConsecutiveLegs();
   
   info += StringFormat("\nAvg Leg Size: %.1f | Consecutive: %d | Threshold: %d", 
                         avgSize, consecutiveCount, PriceMovementThreshold);
   
   Comment(info);
}
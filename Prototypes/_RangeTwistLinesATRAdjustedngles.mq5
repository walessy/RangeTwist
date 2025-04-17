#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2

input int    RangeSize = 25;            // Range size in points
input int    ATRPeriod = 14;            // ATR period
input double ATRMultiplier = 1.0;       // ATR multiplier for angle adjustment
input color  UpColor = clrLime;         // Color for up trend
input color  DownColor = clrRed;        // Color for down trend
input bool   IncLstCndl = false;        // Include last candle

double LineBuffer[];
double ColorBuffer[];

double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;

// ATR calculation variables
double atrValues[];

int OnInit()
{
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

   // Initialize with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetString(0, PLOT_LABEL, "Range Line");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   point = _Point;
   
   // Prepare ATR arrays
   ArraySetAsSeries(atrValues, true);
   
   return(INIT_SUCCEEDED);
}

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
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset indicators and initialize
      ArrayInitialize(LineBuffer, EMPTY_VALUE);
      
      // Initialize the first range value
      if(rates_total > 0)
      {
         currentLevel = close[0];
         prevLevel = close[0];
         lastRangeBarIndex = 0;
         upTrend = true;
         LineBuffer[0] = currentLevel;
         ColorBuffer[0] = 0; // Start with up color
      }
   }
   
   // Process each price bar from the last calculated one to the current
   int start = 0;
   
   if(!IncLstCndl){
      start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   }
   else{
      start = prev_calculated > 0 ? prev_calculated - 1 : 1;
   }
   
   // Create arrays for ATR values
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   // Get ATR handle
   int atrHandle = iATR(_Symbol, 0, ATRPeriod);
   
   // Copy ATR values
   CopyBuffer(atrHandle, 0, 0, rates_total, atrValues);
   
   for(int i = start; i < rates_total; i++)
   {
      double atrValue = atrValues[i];
      CalculateRange(i, high[i], low[i], rates_total, atrValue);
   }
   
   return(rates_total);
}

void CalculateRange(int bar_index, double high, double low, int rates_total, double atrValue)
{
   // Base range size
   double range = RangeSize * point;
   
   // Adjust range based on ATR
   double adjustedRange = range * (1.0 + (atrValue * ATRMultiplier * 0.1));
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   // Calculate angle adjustment based on ATR
   double angleAdjustment = 0;
   if(lastRangeBarIndex < bar_index && lastRangeBarIndex > 0) {
      int barsPassed = bar_index - lastRangeBarIndex;
      angleAdjustment = atrValue * ATRMultiplier * 0.01 * barsPassed;
   }
   
   if(upTrend)
   {
      if(high >= currentLevel + adjustedRange)
      {
         // Move the line up with angle adjustment
         prevLevel = currentLevel;
         currentLevel = currentLevel + adjustedRange;
         
         // Apply angle adjustment - steeper angle for higher volatility
         if(angleAdjustment > 0) {
            currentLevel += angleAdjustment;
         }
         
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
      }
      else if(low <= currentLevel - adjustedRange)
      {
         // Trend has reversed to down
         upTrend = false;
         prevLevel = currentLevel;
         currentLevel = currentLevel - adjustedRange;
         
         // Apply angle adjustment - steeper angle for higher volatility
         if(angleAdjustment > 0) {
            currentLevel -= angleAdjustment;
         }
         
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
      }
      else
      {
         // No change in level, but adjust angle slightly based on ATR
         if(bar_index > lastRangeBarIndex && angleAdjustment > 0) {
            currentLevel += angleAdjustment * 0.1; // Smaller continuous adjustment
         }
         
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
      }
   }
   else // downtrend
   {
      if(low <= currentLevel - adjustedRange)
      {
         // Move the line down with angle adjustment
         prevLevel = currentLevel;
         currentLevel = currentLevel - adjustedRange;
         
         // Apply angle adjustment - steeper angle for higher volatility
         if(angleAdjustment > 0) {
            currentLevel -= angleAdjustment;
         }
         
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
      }
      else if(high >= currentLevel + adjustedRange)
      {
         // Trend has reversed to up
         upTrend = true;
         prevLevel = currentLevel;
         currentLevel = currentLevel + adjustedRange;
         
         // Apply angle adjustment - steeper angle for higher volatility
         if(angleAdjustment > 0) {
            currentLevel += angleAdjustment;
         }
         
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
      }
      else
      {
         // No change in level, but adjust angle slightly based on ATR
         if(bar_index > lastRangeBarIndex && angleAdjustment > 0) {
            currentLevel -= angleAdjustment * 0.1; // Smaller continuous adjustment
         }
         
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
      }
   }
   
   // Smooth the transition between points for better angle visualization
   if(bar_index > 0 && bar_index > lastRangeBarIndex) {
      int prevIndex = bar_index - 1;
      if(prevIndex >= 0 && prevIndex < rates_total) {
         // Linear interpolation between lastRangeBarIndex and current bar
         double ratio = (double)(bar_index - lastRangeBarIndex) / 
                       (double)(bar_index - lastRangeBarIndex + 1);
         double interpolatedValue = prevLevel + (currentLevel - prevLevel) * ratio;
         
         // Apply a slight adjustment based on current bar position
         LineBuffer[bar_index] = interpolatedValue + 
                               (currentLevel - interpolatedValue) * 
                               ((double)(bar_index - lastRangeBarIndex) / 5.0);
      }
   }
}
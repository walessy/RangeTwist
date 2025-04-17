//Just made it a line therfore redcing code
//Repaints on last candle (0)
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
input int    ATR_Period = 14;           // ATR Period
input double ATR_Multiplier = 1.0;      // ATR Multiplier
input bool   UseATR = false;            // Use ATR for range calculation
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

// For ATR-based calculation
int atr_handle;

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
   
   // Initialize ATR handle if using ATR method
   if(UseATR) {
      atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
      if(atr_handle == INVALID_HANDLE) {
         Print("Error creating ATR indicator");
         return(INIT_FAILED);
      }
   }
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Release ATR indicator handle if it was created
   if(UseATR && atr_handle != INVALID_HANDLE) {
      IndicatorRelease(atr_handle);
   }
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
         }
      } else {
         // Normal calculation for all other candles
         CalculateRange(i, high[i], low[i], rates_total);
      }
   }
      
   return(rates_total);
}

// Calculate the range value based on selected method
double GetRangeValue(int bar_index)
{
   double range = RangeSize * point; // Default range calculation
   
   if(UseATR) {
      double atr_buffer[];
      if(CopyBuffer(atr_handle, 0, bar_index, 1, atr_buffer) == 1) {
         range = atr_buffer[0] * ATR_Multiplier;
      } else {
         // Fallback to fixed range if ATR fails
         Print("Failed to get ATR value at index ", bar_index, ", using fixed range");
      }
   }
   
   // Ensure minimum range
   if(range < point) range = point;
   
   return range;
}

void CalculateRange(int bar_index, double high, double low, int rates_total)
{
   // Calculate range value based on selected method
   double range = GetRangeValue(bar_index);
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(upTrend)
   {
      if(high >= currentLevel + range)
      {
         // Move the line up
         currentLevel = currentLevel + range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
      }
      else if(low <= currentLevel - range)
      {
         // Trend has reversed to down
         upTrend = false;
         currentLevel = currentLevel - range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
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
         currentLevel = currentLevel - range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
      }
      else if(high >= currentLevel + range)
      {
         // Trend has reversed to up
         upTrend = true;
         currentLevel = currentLevel + range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
      }
      else
      {
         // No change in level, copy the last value
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
      }
   }
}
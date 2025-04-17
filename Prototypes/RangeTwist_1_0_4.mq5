//Dynamic Range Line Indicator using ATR
//This version for 4hr above
#property copyright "Amos - Modified"
#property link      "amoswales@gmail.com"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed,clrGray

#property indicator_width1  2

// ATR parameters
input int    ATR_Period = 14;         // ATR Period
input double ATR_Multiplier = 1.0;    // ATR Multiplier
input bool   UseFixedRange = false;   // Option to use fixed range instead of ATR
input int    FixedRangeSize = 25;     // Fixed range size in points (if UseFixedRange=true)
input color  UpColor = clrLime;       // Color for up trend
input color  DownColor = clrRed;      // Color for down trend
input bool   IncLstCndl = false;      // Include last candle in calculations

double LineBuffer[];
double ColorBuffer[];

double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;

// Handle for ATR indicator
int atrHandle;

int OnInit()
{
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

   // Initialize with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetString(0, PLOT_LABEL, "Dynamic Range Line");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   point = _Point;
   
   // Initialize ATR indicator
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Release the ATR indicator handle
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
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
   // If insufficient bars
   if(rates_total < ATR_Period) 
      return(0);
      
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
         ColorBuffer[0] = 2; // Start with up color
      }
   }
      
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   int limit = rates_total;
   
   // Create buffer for ATR values
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   // Copy ATR values into our buffer
   if(CopyBuffer(atrHandle, 0, 0, rates_total, atrValues) <= 0)
   {
      Print("Failed to copy ATR values");
      return(0);
   }
   
   // Adjust buffer direction to match our loop direction
   ArraySetAsSeries(atrValues, false);
      
   for(int i = start; i < limit; i++)
   {
      if(i == rates_total - 1 && !IncLstCndl) 
      {
         // For the last candle, when we don't want to include it in calculations
         // Copy the previous value to maintain continuity
         if(i > 0) 
         {
            LineBuffer[i] = LineBuffer[i-1];
            ColorBuffer[i] = ColorBuffer[i-1];
         }
      } 
      else 
      {
         // Determine the range size (either fixed or ATR-based)
         double rangeSize;
         if(UseFixedRange)
         {
            rangeSize = FixedRangeSize * point;
         }
         else
         {
            // Get ATR value for the current bar and convert to points
            if(i < ATR_Period)
            {
               // Not enough data for ATR calculation
               rangeSize = FixedRangeSize * point; // Fallback to fixed range
            }
            else
            {
               // Use ATR to determine the range
               rangeSize = atrValues[i] * ATR_Multiplier;
            }
         }
         
         // Calculate using the dynamic range
         CalculateRange(i, high[i], low[i], rates_total, rangeSize);
      }
   }
      
   return(rates_total);
}

void CalculateRange(int bar_index, double high, double low, int rates_total, double range)
{
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
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrLime, clrRed
#property indicator_width1  1

input int    RangeSize = 25;            // Range size in points
input color  UpColor = clrLime;         // Color for up candles
input color  DownColor = clrRed;        // Color for down candles

double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
double ColorBuffer[];  // Add color buffer

double currentOpen = 0;
double currentHigh = 0;
double currentLow = 0;
double currentClose = 0;
double prevClose = 0;
int lastRangeBarIndex = 0;  // Track the last bar where we created a range candle
bool upTrend = true;
double point;

int OnInit()
{
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ColorBuffer, INDICATOR_COLOR_INDEX);

   // Initialize with EMPTY_VALUE
   ArrayInitialize(OpenBuffer, EMPTY_VALUE);
   ArrayInitialize(HighBuffer, EMPTY_VALUE);
   ArrayInitialize(LowBuffer, EMPTY_VALUE);
   ArrayInitialize(CloseBuffer, EMPTY_VALUE);
   
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetString(0, PLOT_LABEL, "Range Candles");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   point = _Point;
   
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
      ArrayInitialize(OpenBuffer, EMPTY_VALUE);
      ArrayInitialize(HighBuffer, EMPTY_VALUE);
      ArrayInitialize(LowBuffer, EMPTY_VALUE);
      ArrayInitialize(CloseBuffer, EMPTY_VALUE);
      
      // Initialize the first range bar
      if(rates_total > 0)
      {
         currentOpen = open[0];
         currentHigh = high[0];
         currentLow = low[0];
         currentClose = close[0];
         prevClose = close[0];
         lastRangeBarIndex = 0;
         upTrend = close[0] > open[0]; // Start with the actual trend
      }
   }
   
   // Process each price bar from the last calculated one to the current
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   // We'll track the last created range bar
   for(int i = start; i < rates_total; i++)
   {
      CalculateRange(i, open[i], high[i], low[i], close[i], rates_total);
   }
   
   return(rates_total);
}

void CalculateRange(int bar_index, double open, double high, double low, double close, int rates_total)
{
   double range = RangeSize * point;
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(upTrend)
   {
      if(high >= currentHigh + range)
      {
         // Create a new up range candle
         OpenBuffer[bar_index] = currentHigh;
         HighBuffer[bar_index] = currentHigh + range;
         LowBuffer[bar_index] = currentHigh;
         CloseBuffer[bar_index] = currentHigh + range;
         ColorBuffer[bar_index] = 0; // Up color
         
         // Update the tracking variables
         currentHigh = currentHigh + range;
         currentLow = currentHigh;
         currentClose = currentHigh;
         prevClose = currentClose;
         lastRangeBarIndex = bar_index;
      }
      else if(low <= currentHigh - range)
      {
         // Trend has reversed to down
         upTrend = false;
         
         // Create a new down range candle
         OpenBuffer[bar_index] = currentHigh;
         HighBuffer[bar_index] = currentHigh;
         LowBuffer[bar_index] = currentHigh - range;
         CloseBuffer[bar_index] = currentHigh - range;
         ColorBuffer[bar_index] = 1; // Down color
         
         // Update the tracking variables
         currentLow = currentHigh - range;
         currentClose = currentLow;
         prevClose = currentClose;
         lastRangeBarIndex = bar_index;
      }
      else
      {
         // No new range candle, copy the last one
         if(bar_index > 0 && bar_index != lastRangeBarIndex)
         {
            OpenBuffer[bar_index] = EMPTY_VALUE;
            HighBuffer[bar_index] = EMPTY_VALUE;
            LowBuffer[bar_index] = EMPTY_VALUE;
            CloseBuffer[bar_index] = EMPTY_VALUE;
         }
      }
   }
   else // downtrend
   {
      if(low <= currentLow - range)
      {
         // Create a new down range candle
         OpenBuffer[bar_index] = currentLow;
         HighBuffer[bar_index] = currentLow;
         LowBuffer[bar_index] = currentLow - range;
         CloseBuffer[bar_index] = currentLow - range;
         ColorBuffer[bar_index] = 1; // Down color
         
         // Update the tracking variables
         currentLow = currentLow - range;
         currentClose = currentLow;
         prevClose = currentClose;
         lastRangeBarIndex = bar_index;
      }
      else if(high >= currentLow + range)
      {
         // Trend has reversed to up
         upTrend = true;
         
         // Create a new up range candle
         OpenBuffer[bar_index] = currentLow;
         HighBuffer[bar_index] = currentLow + range;
         LowBuffer[bar_index] = currentLow;
         CloseBuffer[bar_index] = currentLow + range;
         ColorBuffer[bar_index] = 0; // Up color
         
         // Update the tracking variables
         currentHigh = currentLow + range;
         currentClose = currentHigh;
         prevClose = currentClose;
         lastRangeBarIndex = bar_index;
      }
      else
      {
         // No new range candle, set to EMPTY_VALUE
         if(bar_index > 0 && bar_index != lastRangeBarIndex)
         {
            OpenBuffer[bar_index] = EMPTY_VALUE;
            HighBuffer[bar_index] = EMPTY_VALUE;
            LowBuffer[bar_index] = EMPTY_VALUE;
            CloseBuffer[bar_index] = EMPTY_VALUE;
         }
      }
   }
}
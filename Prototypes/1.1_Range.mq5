//+------------------------------------------------------------------+
//|                                                  RangeChart.mq5   |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website/Email"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   1
#property indicator_type1   DRAW_CANDLES
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2

// Input parameters
input int    RangeSize = 25;            // Range size in points
input bool   ShowWicks = true;          // Show high/low wicks
input color  UpColor = clrLime;         // Color for up candles
input color  DownColor = clrRed;        // Color for down candles

// Indicator buffers
double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];

// Global variables
double currentOpen = 0;
double currentHigh = 0;
double currentLow = 0;
double currentClose = 0;
double prevClose = 0;
int lastUpdatedBar = 0;
bool upTrend = true;
double point;
int currentRangeBar = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   
   // Set plot properties
   PlotIndexSetString(0, PLOT_LABEL, "Range Candles");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_CANDLES);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   // Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   // Make sure candles display correctly
   PlotIndexSetInteger(0, PLOT_SHOW_DATA, true);
   
   // Get point value
   point = _Point;
   
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
   // Clear buffers if first calculation
   if(prev_calculated == 0)
   {
      ArrayInitialize(OpenBuffer, EMPTY_VALUE);
      ArrayInitialize(HighBuffer, EMPTY_VALUE);
      ArrayInitialize(LowBuffer, EMPTY_VALUE);
      ArrayInitialize(CloseBuffer, EMPTY_VALUE);
      
      // Initialize range chart with first bar data
      if(rates_total > 0)
      {
         currentOpen = open[0];
         currentHigh = high[0];
         currentLow = low[0];
         currentClose = close[0];
         prevClose = close[0];
         upTrend = (close[0] >= open[0]);
         currentRangeBar = 0;
         lastUpdatedBar = 0;
      }
   }
   
         // Start from the first uncalculated bar
   int startBar = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   // Reset range bar counter if this is a full recalculation
   if(prev_calculated == 0) {
      currentRangeBar = 0;
   }
   
   // Process all unprocessed price bars
   for(int i = startBar; i < rates_total; i++)
   {
      ProcessBar(open[i], high[i], low[i], close[i], time[i], i);
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Process each new price bar                                       |
//+------------------------------------------------------------------+
void ProcessBar(double open, double high, double low, double close, datetime time, int shift)
{
   double range = RangeSize * point;
   
   // Process possible range breakouts within this price bar
   if(upTrend)
   {
      // In uptrend, check if price moved up by range
      if(high >= currentHigh + range)
      {
         // How many complete ranges can we fit?
         int ranges = (int)MathFloor((high - currentHigh) / range);
         
         // Create the range bars
         for(int i = 0; i < ranges; i++)
         {
            currentRangeBar++;
            
            // Assign values to buffers - with bounds checking
            int index = shift - currentRangeBar;
            if(index >= 0 && index < ArraySize(OpenBuffer)) {
                OpenBuffer[index] = currentHigh;
                HighBuffer[index] = currentHigh + range;
                LowBuffer[index] = currentHigh;
                CloseBuffer[index] = currentHigh + range;
            }
            
            // Update current values
            currentHigh += range;
         }
         
         currentClose = currentHigh;
         currentLow = currentHigh;
         lastUpdatedBar = shift;
      }
      
      // Check for reversal to downtrend
      if(low <= currentHigh - range)
      {
         // Reversal
         upTrend = false;
         
         currentRangeBar++;
         
         // Create a new down bar - with bounds checking
         int index = shift - currentRangeBar;
         if(index >= 0 && index < ArraySize(OpenBuffer)) {
             OpenBuffer[index] = currentHigh;
             HighBuffer[index] = currentHigh;
             LowBuffer[index] = currentHigh - range;
             CloseBuffer[index] = currentHigh - range;
         }
         
         // Update current values
         currentLow = currentHigh - range;
         currentClose = currentLow;
         lastUpdatedBar = shift;
      }
   }
   else // downtrend
   {
      // In downtrend, check if price moved down by range
      if(low <= currentLow - range)
      {
         // How many complete ranges can we fit?
         int ranges = (int)MathFloor((currentLow - low) / range);
         
         // Create the range bars
         for(int i = 0; i < ranges; i++)
         {
            currentRangeBar++;
            
            // Assign values to buffers - with bounds checking
            int index = shift - currentRangeBar;
            if(index >= 0 && index < ArraySize(OpenBuffer)) {
                OpenBuffer[index] = currentLow;
                HighBuffer[index] = currentLow;
                LowBuffer[index] = currentLow - range;
                CloseBuffer[index] = currentLow - range;
            }
            
            // Update current values
            currentLow -= range;
         }
         
         currentClose = currentLow;
         currentHigh = currentLow;
         lastUpdatedBar = shift;
      }
      
      // Check for reversal to uptrend
      if(high >= currentLow + range)
      {
         // Reversal
         upTrend = true;
         
         currentRangeBar++;
         
         // Create a new up bar - with bounds checking
         int index = shift - currentRangeBar;
         if(index >= 0 && index < ArraySize(OpenBuffer)) {
             OpenBuffer[index] = currentLow;
             HighBuffer[index] = currentLow + range;
             LowBuffer[index] = currentLow;
             CloseBuffer[index] = currentLow + range;
         }
         
         // Update current values
         currentHigh = currentLow + range;
         currentClose = currentHigh;
         lastUpdatedBar = shift;
      }
   }
}
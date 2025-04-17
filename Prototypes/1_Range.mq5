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
int currentBar = 0;
bool upTrend = true;
double point;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   //SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   //SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   //SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   //SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   
   // Set plot properties
   PlotIndexSetString(0, PLOT_LABEL, "Range Candles");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_CANDLES);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   // Get point value
   point = _Point;
   
   // Initialize range chart
   InitializeRangeChart();
   
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
      
      // Reset our counter and values
      InitializeRangeChart();
   }
   
   // Process price data
   for(int i = prev_calculated > 0 ? prev_calculated - 1 : 0; i < rates_total; i++)
   {
      ProcessPrice(open[i], high[i], low[i], close[i]);
      
      Print("OnCalculate - loop");
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Initialize range chart                                           |
//+------------------------------------------------------------------+
void InitializeRangeChart()
{
   // Initialize with the first available price
   int bars = Bars(_Symbol, _Period);
   if(bars > 0)
   {
      MqlRates rates[];
      if(CopyRates(_Symbol, _Period, 0, 1, rates) > 0)
      {
         currentOpen = rates[0].open;
         currentHigh = rates[0].high;
         currentLow = rates[0].low;
         currentClose = rates[0].close;
         prevClose = rates[0].close;
         currentBar = 0;
         upTrend = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Process each new price update                                    |
//+------------------------------------------------------------------+
void ProcessPrice(double open, double high, double low, double close)
{
   // Check if we need to create a new range bar
   double range = RangeSize * point;
   
   if(upTrend)
   {
      // In uptrend, check if price moved up by range or reversed
      if(high >= currentHigh + range)
      {
         // Create a new up bar
         currentBar++;
         OpenBuffer[currentBar] = currentHigh;
         HighBuffer[currentBar] = currentHigh + range;
         LowBuffer[currentBar] = currentHigh;
         CloseBuffer[currentBar] = currentHigh + range;
         
         // Update current values
         currentHigh = currentHigh + range;
         currentLow = currentHigh;
         currentClose = currentHigh;
         prevClose = currentClose;
      }
      else if(low <= currentHigh - range)
      {
         // Reversal to downtrend
         upTrend = false;
         
         // Create a new down bar
         currentBar++;
         OpenBuffer[currentBar] = currentHigh;
         HighBuffer[currentBar] = currentHigh;
         LowBuffer[currentBar] = currentHigh - range;
         CloseBuffer[currentBar] = currentHigh - range;
         
         // Update current values
         currentHigh = currentHigh;
         currentLow = currentHigh - range;
         currentClose = currentLow;
         prevClose = currentClose;
      }
   }
   else
   {
      // In downtrend, check if price moved down by range or reversed
      if(low <= currentLow - range)
      {
         // Create a new down bar
         currentBar++;
         OpenBuffer[currentBar] = currentLow;
         HighBuffer[currentBar] = currentLow;
         LowBuffer[currentBar] = currentLow - range;
         CloseBuffer[currentBar] = currentLow - range;
         
         // Update current values
         currentHigh = currentLow;
         currentLow = currentLow - range;
         currentClose = currentLow;
         prevClose = currentClose;
      }
      else if(high >= currentLow + range)
      {
         // Reversal to uptrend
         upTrend = true;
         
         // Create a new up bar
         currentBar++;
         OpenBuffer[currentBar] = currentLow;
         HighBuffer[currentBar] = currentLow + range;
         LowBuffer[currentBar] = currentLow;
         CloseBuffer[currentBar] = currentLow + range;
         
         // Update current values
         currentHigh = currentLow + range;
         currentLow = currentLow;
         currentClose = currentHigh;
         prevClose = currentClose;
      }
   }
}
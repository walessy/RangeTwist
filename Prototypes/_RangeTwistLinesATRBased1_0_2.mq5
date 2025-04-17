#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2

// Input parameters
input int    ATR_Period = 14;           // ATR Period
input double ATR_Multiplier = 1.0;      // ATR Multiplier
input color  UpColor = clrLime;         // Color for up candles
input color  DownColor = clrRed;        // Color for down candles

// Buffers
double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
double ColorBuffer[];

// Global variables
int currentBar = 0;
bool upTrend = true;
double currentOpen, currentHigh, currentLow, currentClose;

// ATR handle
int atr_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Setting up indicator buffers
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ColorBuffer, INDICATOR_COLOR_INDEX);
   
   // Setting indicator properties
   PlotIndexSetString(0, PLOT_LABEL, "ATR Range Candles");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);
   
   // Initialize ATR indicator
   atr_handle = iATR(_Symbol, _Period, ATR_Period);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator");
      return(INIT_FAILED);
   }
   
   Print("ATR Range Bars indicator initialized");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handle
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
   
   Print("ATR Range Bars indicator removed");
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
   if(rates_total < ATR_Period)
   {
      Print("Not enough bars for ATR calculation");
      return(0);
   }
   
   // Initialize on first calculation
   if(prev_calculated == 0)
   {
      // Initialize buffers
      ArrayInitialize(OpenBuffer, EMPTY_VALUE);
      ArrayInitialize(HighBuffer, EMPTY_VALUE);
      ArrayInitialize(LowBuffer, EMPTY_VALUE);
      ArrayInitialize(CloseBuffer, EMPTY_VALUE);
      ArrayInitialize(ColorBuffer, 0);
      
      // Initialize first bar
      currentBar = 0;
      currentOpen = open[0];
      currentHigh = high[0];
      currentLow = low[0];
      currentClose = close[0];
      upTrend = (close[0] >= open[0]);
      
      OpenBuffer[0] = open[0];
      HighBuffer[0] = high[0];
      LowBuffer[0] = low[0];
      CloseBuffer[0] = close[0];
      ColorBuffer[0] = (upTrend ? 0 : 1);
      
      Print("Indicator buffers initialized");
   }
   
   // Copy ATR values
   double atr_values[];
   int copied = CopyBuffer(atr_handle, 0, 0, rates_total, atr_values);
   if(copied <= 0)
   {
      Print("Failed to copy ATR values, error code: ", GetLastError());
      return(0);
   }
   
   // Calculate starting bar for processing
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start < 1) start = 1;  // Make sure we don't start at bar 0
   
   // Debug message
   if(start < rates_total)
      Print("Processing from bar ", start, " to ", rates_total-1);
   
   // Process each bar
   for(int i = start; i < rates_total; i++)
   {
      // Skip empty ATR values
      if(atr_values[i] <= 0 || !MathIsValidNumber(atr_values[i]))
         continue;
      
      // Calculate dynamic range based on ATR
      double range = atr_values[i] * ATR_Multiplier;
      
      // Debug output
      if(i % 100 == 0)
         Print("Bar ", i, ": ATR = ", atr_values[i], ", Range = ", range);
      
      // Process this price bar
      UpdateRangeBar(i, open[i], high[i], low[i], close[i], range);
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Update range bar based on current price                          |
//+------------------------------------------------------------------+
void UpdateRangeBar(int bar, double open, double high, double low, double close, double range)
{
   if(upTrend)
   {
      // Check if price moved up by range amount
      if(high >= currentHigh + range)
      {
         currentBar++;
         if(currentBar >= bar) currentBar = bar;
         
         // Create a new up bar
         OpenBuffer[currentBar] = currentHigh;
         HighBuffer[currentBar] = currentHigh + range;
         LowBuffer[currentBar] = currentHigh;
         CloseBuffer[currentBar] = currentHigh + range;
         ColorBuffer[currentBar] = 0;  // Up color
         
         // Update current values
         currentHigh += range;
         currentLow = currentHigh;
         currentClose = currentHigh;
         currentOpen = currentHigh - range;
         
         Print("Up trend continued at bar ", bar, ", new range bar at ", currentBar);
      }
      // Check if price reversed by range amount
      else if(low <= currentHigh - range)
      {
         upTrend = false;
         currentBar++;
         if(currentBar >= bar) currentBar = bar;
         
         // Create a new down bar
         OpenBuffer[currentBar] = currentHigh;
         HighBuffer[currentBar] = currentHigh;
         LowBuffer[currentBar] = currentHigh - range;
         CloseBuffer[currentBar] = currentHigh - range;
         ColorBuffer[currentBar] = 1;  // Down color
         
         // Update current values
         currentLow = currentHigh - range;
         currentClose = currentLow;
         
         Print("Trend reversed to down at bar ", bar, ", new range bar at ", currentBar);
      }
   }
   else  // downTrend
   {
      // Check if price moved down by range amount
      if(low <= currentLow - range)
      {
         currentBar++;
         if(currentBar >= bar) currentBar = bar;
         
         // Create a new down bar
         OpenBuffer[currentBar] = currentLow;
         HighBuffer[currentBar] = currentLow;
         LowBuffer[currentBar] = currentLow - range;
         CloseBuffer[currentBar] = currentLow - range;
         ColorBuffer[currentBar] = 1;  // Down color
         
         // Update current values
         currentLow -= range;
         currentHigh = currentLow;
         currentClose = currentLow;
         
         Print("Down trend continued at bar ", bar, ", new range bar at ", currentBar);
      }
      // Check if price reversed by range amount
      else if(high >= currentLow + range)
      {
         upTrend = true;
         currentBar++;
         if(currentBar >= bar) currentBar = bar;
         
         // Create a new up bar
         OpenBuffer[currentBar] = currentLow;
         HighBuffer[currentBar] = currentLow + range;
         LowBuffer[currentBar] = currentLow;
         CloseBuffer[currentBar] = currentLow + range;
         ColorBuffer[currentBar] = 0;  // Up color
         
         // Update current values
         currentHigh = currentLow + range;
         currentClose = currentHigh;
         
         Print("Trend reversed to up at bar ", bar, ", new range bar at ", currentBar);
      }
   }
}
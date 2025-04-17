#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.01"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  1

enum RangeMethod {
   FIXED_POINTS = 0,       // Fixed points
   ATR_BASED = 1,          // ATR-based
   PERCENTAGE = 2          // Percentage of price
};

input RangeMethod Method = ATR_BASED;    // Range calculation method
input int    FixedRange = 25;            // Fixed range size in points
input int    ATR_Period = 14;            // ATR Period
input double ATR_Multiplier = 1.0;       // ATR Multiplier
input double PercentageRange = 0.1;      // Percentage range (0.1 = 0.1%)
input color  UpColor = clrLime;          // Color for up candles
input color  DownColor = clrRed;         // Color for down candles

double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];

double currentOpen = 0;
double currentHigh = 0;
double currentLow = 0;
double currentClose = 0;
double prevClose = 0;
int currentBar = 0;
bool upTrend = true;
double point;

int atr_handle;

int OnInit()
{
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   
   PlotIndexSetString(0, PLOT_LABEL, "Range Candles");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_CANDLES);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   point = _Point;
   
   if(Method == ATR_BASED)
      atr_handle = iATR(_Symbol, _Period, ATR_Period);
   
   InitializeRangeChart();
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(Method == ATR_BASED && atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
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
   if(prev_calculated == 0)
   {
      ArrayInitialize(OpenBuffer, EMPTY_VALUE);
      ArrayInitialize(HighBuffer, EMPTY_VALUE);
      ArrayInitialize(LowBuffer, EMPTY_VALUE);
      ArrayInitialize(CloseBuffer, EMPTY_VALUE);
      
      InitializeRangeChart();
   }
   
   for(int i = prev_calculated > 0 ? prev_calculated - 1 : 0; i < rates_total; i++)
   {
      double dynamicRange = CalculateDynamicRange(i, open, high, low, close);
      ProcessPrice(open[i], high[i], low[i], close[i], dynamicRange);
   }
   
   return(rates_total);
}

double CalculateDynamicRange(int index, const double &open[], const double &high[], 
                            const double &low[], const double &close[])
{
   double range = FixedRange * point; // Default to fixed range
   
   switch(Method)
   {
      case FIXED_POINTS:
         // Already set to default
         break;
         
      case ATR_BASED:
         double atr_values[];
         if(CopyBuffer(atr_handle, 0, index, 1, atr_values) > 0)
            range = atr_values[0] * ATR_Multiplier;
         break;
         
      case PERCENTAGE:
         range = close[index] * PercentageRange / 100.0;
         break;
   }
   
   // Ensure minimum range to avoid issues with very small ranges
   double min_range = 5 * point;
   if(range < min_range)
      range = min_range;
      
   return range;
}


void InitializeRangeChart()
{
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


void ProcessPrice(double open, double high, double low, double close, double range)
{
   if(upTrend)
   {
      if(high >= currentHigh + range)
      {
         currentBar++;
         OpenBuffer[currentBar] = currentHigh;
         HighBuffer[currentBar] = currentHigh + range;
         LowBuffer[currentBar] = currentHigh;
         CloseBuffer[currentBar] = currentHigh + range;
         
         currentHigh = currentHigh + range;
         currentLow = currentHigh;
         currentClose = currentHigh;
         prevClose = currentClose;
      }
      else if(low <= currentHigh - range)
      {
         upTrend = false;
         
         currentBar++;
         OpenBuffer[currentBar] = currentHigh;
         HighBuffer[currentBar] = currentHigh;
         LowBuffer[currentBar] = currentHigh - range;
         CloseBuffer[currentBar] = currentHigh - range;
         
         currentHigh = currentHigh;
         currentLow = currentHigh - range;
         currentClose = currentLow;
         prevClose = currentClose;
      }
   }
   else
   {
      if(low <= currentLow - range)
      {
         currentBar++;
         OpenBuffer[currentBar] = currentLow;
         HighBuffer[currentBar] = currentLow;
         LowBuffer[currentBar] = currentLow - range;
         CloseBuffer[currentBar] = currentLow - range;
         
         currentHigh = currentLow;
         currentLow = currentLow - range;
         currentClose = currentLow;
         prevClose = currentClose;
      }
      else if(high >= currentLow + range)
      {
         upTrend = true;
         
         currentBar++;
         OpenBuffer[currentBar] = currentLow;
         HighBuffer[currentBar] = currentLow + range;
         LowBuffer[currentBar] = currentLow;
         CloseBuffer[currentBar] = currentLow + range;
         
         currentHigh = currentLow + range;
         currentLow = currentLow;
         currentClose = currentHigh;
         prevClose = currentClose;
      }
   }
}
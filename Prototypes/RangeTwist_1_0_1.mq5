
//This is the am mt5 version of the very original Mt4 version for my personnal manual trading
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE ///DRAW_CANDLES
#property indicator_color1  clrLime, clrRed
#property indicator_width1  1

input int    RangeSize = 25;            // Range size in points
input color  UpColor = clrLime;         // Color for up candles
input color  DownColor = clrRed;        // Color for down candles

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
   
   InitializeRangeChart();
   
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
      ProcessPrice(open[i], high[i], low[i], close[i]);
   }
   
   return(rates_total);
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


void ProcessPrice(double open, double high, double low, double close)
{
   double range = RangeSize * point;
   ///Print("Bar"+IntegerToString(currentBar)+"_Range.mq5");
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
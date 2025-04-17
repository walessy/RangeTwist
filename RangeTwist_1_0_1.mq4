//+------------------------------------------------------------------+
//|                                                  RangeTwist.mq4   |
//|                                                       Amos        |
//|                              amoswales@gmail.com                  |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4

//--- input parameters
input int    RangeSize = 25;            // Range size in points
input color  UpColor = clrLime;         // Color for up candles
input color  DownColor = clrRed;        // Color for down candles

//--- indicator buffers
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

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int init()
{
   // Set up indicator buffers
   SetIndexBuffer(0, OpenBuffer);
   SetIndexBuffer(1, HighBuffer);
   SetIndexBuffer(2, LowBuffer);
   SetIndexBuffer(3, CloseBuffer);
   
   // Set drawing style to none for individual buffers
   SetIndexStyle(0, DRAW_NONE);
   SetIndexStyle(1, DRAW_NONE);
   SetIndexStyle(2, DRAW_NONE);
   SetIndexStyle(3, DRAW_NONE);
   
   // Set labels
   IndicatorShortName("Range Candles");
   SetIndexLabel(0, "Open");
   SetIndexLabel(1, "High");
   SetIndexLabel(2, "Low");
   SetIndexLabel(3, "Close");
   
   point = Point;
   
   InitializeRangeChart();
   
   return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
int deinit()
{
   return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int start()
{
   int counted_bars = IndicatorCounted();
   int limit;
   
   if(counted_bars < 0) return(-1);
   if(counted_bars == 0)
   {
      ArrayInitialize(OpenBuffer, EMPTY_VALUE);
      ArrayInitialize(HighBuffer, EMPTY_VALUE);
      ArrayInitialize(LowBuffer, EMPTY_VALUE);
      ArrayInitialize(CloseBuffer, EMPTY_VALUE);
      
      InitializeRangeChart();
      limit = Bars - 1;
   }
   else
   {
      limit = Bars - counted_bars - 1;
   }
   
   for(int i = limit; i >= 0; i--)
   {
      ProcessPrice(Open[i], High[i], Low[i], Close[i]);
   }
   
   return(0);
}

//+------------------------------------------------------------------+
//| Initialize range chart                                           |
//+------------------------------------------------------------------+
void InitializeRangeChart()
{
   if(Bars > 0)
   {
      currentOpen = Open[0];
      currentHigh = High[0];
      currentLow = Low[0];
      currentClose = Close[0];
      prevClose = Close[0];
      currentBar = 0;
      upTrend = true;
   }
}

//+------------------------------------------------------------------+
//| Process price data                                               |
//+------------------------------------------------------------------+
void ProcessPrice(double open, double high, double low, double close)
{
   double range = RangeSize * point;
   
   if(upTrend)
   {
      if(high >= currentHigh + range)
      {
         currentBar++;
         if(currentBar >= Bars) return; // Prevent buffer overflow
         
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
         if(currentBar >= Bars) return; // Prevent buffer overflow
         
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
         if(currentBar >= Bars) return; // Prevent buffer overflow
         
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
         if(currentBar >= Bars) return; // Prevent buffer overflow
         
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
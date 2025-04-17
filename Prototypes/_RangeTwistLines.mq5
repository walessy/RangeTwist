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
input color  UpColor = clrLime;         // Color for up trend
input color  DownColor = clrRed;        // Color for down trend
input bool   IncLstCndl = false;

double LineBuffer[];
double ColorBuffer[];

double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;

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
   //int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   //int start = prev_calculated > 0 ? prev_calculated - 1 : 1;
   
   int start = 0;
   
   if(!IncLstCndl){
      start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   }
   else{
      start = prev_calculated > 0 ? prev_calculated - 1 : 1;
   }
   
   for(int i = start; i < rates_total; i++)
   {
      CalculateRange(i, high[i], low[i], rates_total);
   }
   
   return(rates_total);
}

void CalculateRange(int bar_index, double high, double low, int rates_total)
{
   double range = RangeSize * point;
   
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
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2

// Input parameters
input int      RangeSize = 25;            // Range size in points
input color    UpColor = clrLime;         // Color for up trend
input color    DownColor = clrRed;        // Color for down trend
input bool     IncLstCndl = false;        // Include last candle in calculation
input ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT; // Timeframe to use

// Buffers
double LineBuffer[];
double ColorBuffer[];

// Global variables
double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;
datetime lastProcessedTime = 0;
int rates_total_prev = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

   // Initialize with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetString(0, PLOT_LABEL, "MTF Range Line");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   point = _Point;
   
   // Set indicator description with timeframe info
   string tf_description = TimeframeToString(TimeFrame);
   IndicatorSetString(INDICATOR_SHORTNAME, "MTF Range Line (" + tf_description + ")");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
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
   // If no data, return
   if(rates_total <= 0) return(0);
   
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0 || rates_total_prev == 0) 
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
   
   // Store current rates_total for next call
   rates_total_prev = rates_total;

   // Determine start point for calculations
   int start = 0;
   
   if(!IncLstCndl){
      start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   }
   else{
      start = prev_calculated > 0 ? prev_calculated - 1 : 1;
   }
   
   // If we're using a timeframe other than the current one
   if(TimeFrame != PERIOD_CURRENT)
   {
      // Arrays to store higher timeframe data
      MqlRates rates_tf[];
      datetime time_tf[];
      
      // Copy higher timeframe data
      int copied = CopyRates(Symbol(), TimeFrame, 0, rates_total, rates_tf);
      if(copied <= 0) 
      {
         Print("Error copying higher timeframe rates: ", GetLastError());
         return(prev_calculated);
      }
      
      // Copy higher timeframe times for mapping
      int copied_time = CopyTime(Symbol(), TimeFrame, 0, copied, time_tf);
      if(copied_time <= 0)
      {
         Print("Error copying higher timeframe times: ", GetLastError());
         return(prev_calculated);
      }
      
      // Process each current timeframe bar
      for(int i = start; i < rates_total; i++)
      {
         // Find the corresponding higher timeframe bar
         int tf_index = GetHigherTimeframeIndex(time[i], time_tf, copied_time);
         if(tf_index >= 0 && tf_index < copied)
         {
            CalculateRange(i, rates_tf[tf_index].high, rates_tf[tf_index].low, rates_total);
         }
         else
         {
            // If we couldn't find a matching bar, copy the last value
            if(i > 0)
            {
               LineBuffer[i] = LineBuffer[i-1];
               ColorBuffer[i] = ColorBuffer[i-1];
            }
         }
      }
   }
   else
   {
      // Process using the current timeframe data
      for(int i = start; i < rates_total; i++)
      {
         CalculateRange(i, high[i], low[i], rates_total);
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate the range for a specific bar                           |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Find index of higher timeframe bar containing the time           |
//+------------------------------------------------------------------+
int GetHigherTimeframeIndex(datetime current_time, datetime &time_tf[], int size)
{
   // If no data, return invalid index
   if(size <= 0) return -1;
   
   // Find the most recent higher timeframe bar that contains the current time
   for(int i = 0; i < size-1; i++)
   {
      if(current_time >= time_tf[i] && current_time < time_tf[i+1])
         return i;
   }
   
   // Check the last bar
   if(current_time >= time_tf[size-1])
      return size-1;
      
   return -1; // Not found
}

//+------------------------------------------------------------------+
//| Convert timeframe enum to string                                 |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "Current";
   }
}
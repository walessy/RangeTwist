//+------------------------------------------------------------------+
//|                                           FibEntrySystem.mq5 |
//|                                                               |
//|                                                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

// Plot styles for the Fibonacci levels
#property indicator_label1  "Daily 50%"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Daily 61.8%"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "Sub Fib 0%"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMagenta
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

#property indicator_label4  "Sub Fib 50%"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDeepPink
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#property indicator_label5  "Sub Fib 61.8%"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDeepPink
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "Sub Fib 100%"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_style6  STYLE_DASH
#property indicator_width6  1

// Input parameters
input int                 SignalBarCount = 3;     // Number of bars oscillating for signal
input ENUM_TIMEFRAMES     SubTimeframe = PERIOD_M5; // Timeframe for sub-fibs
input bool                ShowSignalArrows = true; // Show entry signal arrows
input double              MinPriceDeviation = 0.0001; // Min price deviation for oscillation
input color               BuySignalColor = clrLime; // Buy signal color
input color               SellSignalColor = clrRed; // Sell signal color

// Indicator buffers
double DailyFib50Buffer[];
double DailyFib618Buffer[];
double SubFib0Buffer[];
double SubFib50Buffer[];
double SubFib618Buffer[];
double SubFib100Buffer[];

// Global variables
datetime prevDay = 0;
double prevDayHigh = 0;
double prevDayLow = 0;
double dailyFib50 = 0;
double dailyFib618 = 0;
int signalArrowID = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize buffers
   SetIndexBuffer(0, DailyFib50Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, DailyFib618Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, SubFib0Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, SubFib50Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, SubFib618Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, SubFib100Buffer, INDICATOR_DATA);
   
   // Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   // Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, 0.0);
   
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
   // Check if we have enough bars
   if(rates_total < 2) return(0);
   
   // Calculate only once per day on the daily timeframe
   if(Period() == PERIOD_D1)
   {
      CalculateDailyFibs(rates_total, time, high, low, close);
   }
   else
   {
      // For non-daily timeframes, get the daily fibs and then calculate sub-fibs
      GetDailyFibsFromHigherTimeframe();
      CalculateSubFibs(rates_total, time, high, low, close);
      
      // Check for oscillation around sub fib levels on the M5 timeframe
      if(Period() == SubTimeframe)
      {
         CheckOscillationSignals(rates_total, time, high, low, close);
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Fibonacci levels from previous day's high and low      |
//+------------------------------------------------------------------+
void CalculateDailyFibs(const int rates_total,
                       const datetime &time[],
                       const double &high[],
                       const double &low[],
                       const double &close[])
{
   // Get the current day
   MqlDateTime curr_time;
   TimeToStruct(time[rates_total-1], curr_time);
   
   // Convert to day start
   datetime curr_day = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                                   curr_time.year, curr_time.mon, curr_time.day));
                                   
   // If this is a new day, calculate new Fibonacci levels
   if(curr_day != prevDay)
   {
      // Find the previous day's high and low
      double prev_high = 0;
      double prev_low = DBL_MAX;
      
      for(int i = rates_total-2; i >= 0; i--)
      {
         MqlDateTime bar_time;
         TimeToStruct(time[i], bar_time);
         datetime bar_day = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                                   bar_time.year, bar_time.mon, bar_time.day));
                                   
         if(bar_day == curr_day - PeriodSeconds(PERIOD_D1))
         {
            prev_high = MathMax(prev_high, high[i]);
            prev_low = MathMin(prev_low, low[i]);
         }
         else if(bar_day < curr_day - PeriodSeconds(PERIOD_D1))
         {
            break;
         }
      }
      
      // Store for later use
      prevDay = curr_day;
      prevDayHigh = prev_high;
      prevDayLow = prev_low;
      
      // Calculate Fibonacci levels
      double range = prev_high - prev_low;
      dailyFib50 = prev_low + 0.5 * range;
      dailyFib618 = prev_low + 0.618 * range;
      
      // Print for debugging
      Print("New day: Previous day high = ", prev_high, ", low = ", prev_low);
      Print("Daily Fib 50% = ", dailyFib50, ", 61.8% = ", dailyFib618);
   }
   
   // Fill the buffers with calculated values
   for(int i = 0; i < rates_total; i++)
   {
      DailyFib50Buffer[i] = dailyFib50;
      DailyFib618Buffer[i] = dailyFib618;
   }
}

//+------------------------------------------------------------------+
//| Get daily Fibonacci levels from higher timeframe                 |
//+------------------------------------------------------------------+
void GetDailyFibsFromHigherTimeframe()
{
   // Get daily fibs from global variables or initialize if not set
   if(dailyFib50 == 0 || dailyFib618 == 0)
   {
      // Get data from the daily chart
      double high[], low[];
      datetime time[];
      
      int copied_high = CopyHigh(Symbol(), PERIOD_D1, 0, 2, high);
      int copied_low = CopyLow(Symbol(), PERIOD_D1, 0, 2, low);
      int copied_time = CopyTime(Symbol(), PERIOD_D1, 0, 2, time);
      
      if(copied_high > 0 && copied_low > 0 && copied_time > 0)
      {
         // Calculate the previous day's Fibonacci levels
         double range = high[0] - low[0];
         dailyFib50 = low[0] + 0.5 * range;
         dailyFib618 = low[0] + 0.618 * range;
         
         Print("Initialized from daily: Daily Fib 50% = ", dailyFib50, ", 61.8% = ", dailyFib618);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate sub-Fibonacci levels between daily 50% and 61.8%       |
//+------------------------------------------------------------------+
void CalculateSubFibs(const int rates_total,
                     const datetime &time[],
                     const double &high[],
                     const double &low[],
                     const double &close[])
{
   // Make sure daily fibs are available
   if(dailyFib50 == 0 || dailyFib618 == 0) return;
   
   // Define sub-fib range (0% is lower of the two, 100% is higher)
   double subFib0 = MathMin(dailyFib50, dailyFib618);
   double subFib100 = MathMax(dailyFib50, dailyFib618);
   double subRange = subFib100 - subFib0;
   
   // Calculate sub-fibs
   double subFib50 = subFib0 + 0.5 * subRange;
   double subFib618 = subFib0 + 0.618 * subRange;
   
   // Fill the buffers
   for(int i = 0; i < rates_total; i++)
   {
      DailyFib50Buffer[i] = dailyFib50;
      DailyFib618Buffer[i] = dailyFib618;
      SubFib0Buffer[i] = subFib0;
      SubFib50Buffer[i] = subFib50;
      SubFib618Buffer[i] = subFib618;
      SubFib100Buffer[i] = subFib100;
   }
}

//+------------------------------------------------------------------+
//| Check for price oscillation around sub-fib levels                |
//+------------------------------------------------------------------+
void CheckOscillationSignals(const int rates_total,
                           const datetime &time[],
                           const double &high[],
                           const double &low[],
                           const double &close[])
{
   // Skip if not enough bars
   if(rates_total < SignalBarCount + 1) return;
   
   // Make sure sub-fibs are available
   if(SubFib50Buffer[rates_total-1] == 0 || SubFib618Buffer[rates_total-1] == 0) return;
   
   double subFib50 = SubFib50Buffer[rates_total-1];
   double subFib618 = SubFib618Buffer[rates_total-1];
   
   // Identify if price is oscillating between sub-fib 50% and 61.8%
   bool hasOscillatedAbove50 = false;
   bool hasOscillatedAbove618 = false;
   bool hasOscillatedBelow50 = false;
   bool hasOscillatedBelow618 = false;
   
   for(int i = rates_total - SignalBarCount; i < rates_total; i++)
   {
      // Check if price is oscillating around 50% level
      if(high[i] > subFib50 + MinPriceDeviation) hasOscillatedAbove50 = true;
      if(low[i] < subFib50 - MinPriceDeviation) hasOscillatedBelow50 = true;
      
      // Check if price is oscillating around 61.8% level
      if(high[i] > subFib618 + MinPriceDeviation) hasOscillatedAbove618 = true;
      if(low[i] < subFib618 - MinPriceDeviation) hasOscillatedBelow618 = true;
   }
   
   // Determine signal type
   bool buySignal = hasOscillatedAbove50 && hasOscillatedBelow50 && close[rates_total-1] > subFib50;
   bool sellSignal = hasOscillatedAbove618 && hasOscillatedBelow618 && close[rates_total-1] < subFib618;
   
   // Show signal if enabled
   if(ShowSignalArrows && (buySignal || sellSignal))
   {
      // Create a trend line for the signal
      string signalName = "FibSignal_" + IntegerToString(signalArrowID++);
      
      if(buySignal)
      {
         ObjectCreate(0, signalName, OBJ_ARROW_BUY, 0, time[rates_total-1], low[rates_total-1] - 10 * _Point);
         ObjectSetInteger(0, signalName, OBJPROP_COLOR, BuySignalColor);
         Print("Buy signal at ", TimeToString(time[rates_total-1]), " price: ", close[rates_total-1]);
      }
      else if(sellSignal)
      {
         ObjectCreate(0, signalName, OBJ_ARROW_SELL, 0, time[rates_total-1], high[rates_total-1] + 10 * _Point);
         ObjectSetInteger(0, signalName, OBJPROP_COLOR, SellSignalColor);
         Print("Sell signal at ", TimeToString(time[rates_total-1]), " price: ", close[rates_total-1]);
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up any objects created by the indicator
   ObjectsDeleteAll(0, "FibSignal_");
}
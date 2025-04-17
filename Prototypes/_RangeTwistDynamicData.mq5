#property copyright "Amos (Modified)"
#property link      "amoswales@gmail.com"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 3  // Added one more buffer for dynamic range values
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2

enum RANGE_METHOD {
   FIXED = 0,           // Fixed Range (points)
   ATR_BASED = 1,       // ATR-Based Range
   VOLATILITY_BASED = 2 // Volatility-Based Range
};

input RANGE_METHOD RangeMethod = ATR_BASED;  // Method to calculate range
input int    FixedRangeSize = 25;            // Fixed range size in points
input int    ATRPeriod = 14;                 // ATR period
input double ATRMultiplier = 2.0;            // ATR multiplier
input int    VolatilityPeriod = 20;          // Volatility calculation period
input double VolatilityMultiplier = 1.5;     // Volatility multiplier
input color  UpColor = clrLime;              // Color for up trend
input color  DownColor = clrRed;             // Color for down trend
input bool   ExportToCSV = false;            // Export data to CSV
input int    ExportBars = 500;               // Number of bars to export

double LineBuffer[];
double ColorBuffer[];
double DynamicRangeBuffer[];  // Renamed from ATRBuffer to be clearer

double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
double point;
int atrHandle = INVALID_HANDLE;  // Initialize with INVALID_HANDLE

int OnInit()
{
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, DynamicRangeBuffer, INDICATOR_CALCULATIONS);

   // Initialize with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   ArrayInitialize(DynamicRangeBuffer, EMPTY_VALUE);
   
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetString(0, PLOT_LABEL, "Dynamic Range Line");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   point = _Point;
   
   // Create ATR indicator handle - always initialize it if using ATR-based method
   if(RangeMethod == ATR_BASED)
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Export data when indicator is removed if enabled
   if(ExportToCSV)
      ExportIndicatorData();
   
   // Clean up indicator handle
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
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
   // Update range values based on the selected method
   if(RangeMethod == ATR_BASED)
   {
      // Check if handle is valid
      if(atrHandle != INVALID_HANDLE)
      {
         // Copy ATR values to our buffer
         if(CopyBuffer(atrHandle, 0, 0, rates_total, DynamicRangeBuffer) <= 0)
         {
            Print("Error copying ATR data: ", GetLastError());
            return 0;
         }
      }
      else
      {
         Print("Error: Invalid ATR handle");
         return 0;
      }
   }
   else if(RangeMethod == VOLATILITY_BASED)
   {
      // Calculate volatility for each bar
      CalculateVolatility(rates_total, close);
   }
   else if(RangeMethod == FIXED)
   {
      // Set a fixed range for all bars
      for(int i = 0; i < rates_total; i++)
      {
         DynamicRangeBuffer[i] = FixedRangeSize * point;
      }
   }
   
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset indicators and initialize
      ArrayInitialize(LineBuffer, EMPTY_VALUE);
      
      // Initialize the first range value, but don't draw it
      if(rates_total > 0)
      {
         currentLevel = close[0];
         prevLevel = close[0];
         lastRangeBarIndex = 0;
         upTrend = true;
         // Don't set LineBuffer[0] to avoid redrawing the first bar
         LineBuffer[0] = EMPTY_VALUE;
      }
   }
   
   // Process each price bar from the last calculated one to the current
   // Start from bar 1 to skip the first bar
   int start = prev_calculated > 0 ? prev_calculated - 1 : 1;
   
   for(int i = start; i < rates_total; i++)
   {
      CalculateRange(i, high[i], low[i], close[i], rates_total);
   }
   
   return(rates_total);
}

void CalculateRange(int bar_index, double high, double low, double close, int rates_total)
{
   double range;
   
   // Make sure we don't exceed buffer size or use uninitialized values
   if(bar_index >= rates_total || bar_index < 0) 
      return;
      
   // Get the range value based on the selected method
   if(RangeMethod == FIXED)
   {
      range = FixedRangeSize * point;
   }
   else if(RangeMethod == ATR_BASED || RangeMethod == VOLATILITY_BASED)
   {
      // Both methods use the DynamicRangeBuffer but with different multipliers
      double buffer_value = DynamicRangeBuffer[bar_index];
      
      // Check for empty or invalid values
      if(buffer_value <= 0 || buffer_value == EMPTY_VALUE)
      {
         // Fallback to fixed range if the buffer has invalid data
         range = FixedRangeSize * point;
      }
      else
      {
         // Apply the appropriate multiplier
         if(RangeMethod == ATR_BASED)
            range = buffer_value * ATRMultiplier;
         else // VOLATILITY_BASED
            range = buffer_value * VolatilityMultiplier;
      }
   }
   else
   {
      // Default to fixed range
      range = FixedRangeSize * point;
   }
   
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

void CalculateVolatility(int rates_total, const double &close[])
{
   int period = MathMin(VolatilityPeriod, rates_total);
   
   // Calculate close price standard deviation for volatility
   for(int i = period; i < rates_total; i++)
   {
      double sum = 0;
      double sum_sq = 0;
      
      for(int j = 0; j < period; j++)
      {
         sum += close[i-j];
         sum_sq += close[i-j] * close[i-j];
      }
      
      double mean = sum / period;
      double variance = sum_sq / period - mean * mean;
      DynamicRangeBuffer[i] = MathSqrt(variance);
   }
   
   // Fill the initial bars with the first calculated value
   double first_value = DynamicRangeBuffer[period];
   for(int i = 0; i < period; i++)
   {
      DynamicRangeBuffer[i] = first_value;
   }
}

void ExportIndicatorData()
{
   int export_count = MathMin(ExportBars, Bars);
   
   // Create filename with mode indication
   string mode_name;
   switch(RangeMethod) {
      case FIXED: mode_name = "Fixed"; break;
      case ATR_BASED: mode_name = "ATR"; break;
      case VOLATILITY_BASED: mode_name = "Volatility"; break;
      default: mode_name = "Unknown";
   }
   
   string filename = "DynamicRangeData_" + mode_name + "_" + _Symbol + "_" + IntegerToString(Period()) + ".csv";
   
   int handle = FileOpen(filename, FILE_WRITE|FILE_CSV, ",");
   
   if(handle != INVALID_HANDLE)
   {
      // Write header
      FileWrite(handle, "DateTime", "Price", "RangeLevel", "TrendDirection", "Range");
      
      // Write data (most recent bars first)
      for(int i = 0; i < export_count; i++)
      {
         datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, i);
         double price = iClose(_Symbol, PERIOD_CURRENT, i);
         string direction = ColorBuffer[i] == 0 ? "Up" : "Down";
         double range_value = 0;
         
         // Get the appropriate range value for this bar
         if(i < ArraySize(DynamicRangeBuffer))
         {
            if(RangeMethod == FIXED)
            {
               range_value = FixedRangeSize * point;
            }
            else
            {
               // For ATR and Volatility methods, get from buffer with appropriate multiplier
               double buffer_value = DynamicRangeBuffer[i];
               if(buffer_value > 0 && buffer_value != EMPTY_VALUE)
               {
                  if(RangeMethod == ATR_BASED)
                     range_value = buffer_value * ATRMultiplier;
                  else // VOLATILITY_BASED
                     range_value = buffer_value * VolatilityMultiplier;
               }
               else
               {
                  range_value = FixedRangeSize * point;
               }
            }
         }
         else
         {
            range_value = FixedRangeSize * point;
         }
         
         FileWrite(handle, 
                  TimeToString(bar_time, TIME_DATE|TIME_MINUTES),
                  DoubleToString(price, _Digits),
                  DoubleToString(LineBuffer[i], _Digits),
                  direction,
                  DoubleToString(range_value, _Digits));
      }
      
      FileClose(handle);
      Print("Data exported to ", filename);
   }
   else
   {
      Print("Failed to open file for writing: ", GetLastError());
   }
}
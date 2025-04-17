//Dynamic Range Line Indicator using Normalized ATR
#property copyright "Amos - Modified"
#property link      "amoswales@gmail.com"
#property version   "2.10"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed, clrGray
#property indicator_width1  3  // Increased line width for better visibility

// ATR and Range parameters
input int    ATR_Period = 14;           // ATR Period
input double ATR_Multiplier = 1.0;      // ATR Multiplier (lower for high-volatility instruments)
input ENUM_TIMEFRAMES NormTimeframe = PERIOD_D1; // Normalization Timeframe
input bool   UseFixedRange = false;     // Option to use fixed range instead of ATR
input int    FixedRangeSize = 25;       // Fixed range size in points (if UseFixedRange=true)
input double MinRangeSize = 10;         // Minimum range size in points
input double MaxRangeSize = 2000;       // Maximum range size in points
input bool   AutoAdjustRange = true;    // Automatically adjust range based on instrument price
input color  UpColor = clrLime;         // Color for up trend
input color  DownColor = clrRed;        // Color for down trend
input color  FlatColor = clrGray;       // Color for flat/no change
input bool   IncLstCndl = false;        // Include last candle in calculations
input bool   ShowInfo = true;           // Show current range info on chart
input int    DebugMode = 0;            // Debug level (0=off, 1=basic, 2=detailed)

double LineBuffer[];
double ColorBuffer[];

double currentLevel = 0;
double prevLevel = 0;
int lastRangeBarIndex = 0;
bool upTrend = true;
int lastDirection = 0;  // 0=flat start, 1=up, -1=down
double point;
double currentRange = 0;
string indicatorName;
bool isHighPriceInstrument = false; // Flag for high-priced instruments like BTC

// Handle for ATR indicators
int atrHandle;
int atrNormHandle;

int OnInit()
{
   indicatorName = "DynamicRange_" + StringSubstr(_Symbol, 0, 6);
   
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

   // Initialize with EMPTY_VALUE
   ArrayInitialize(LineBuffer, EMPTY_VALUE);
   
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);    // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);  // Index 1 = Down color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, FlatColor);  // Index 2 = Flat color
   PlotIndexSetString(0, PLOT_LABEL, "Dynamic Range Line");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 3);  // Increased line width
   
   // Handle point size
   point = _Point;
   
   // For debugging
   if(DebugMode > 0)
   {
      double current_close = iClose(_Symbol, PERIOD_CURRENT, 0);
      Print("Symbol: ", _Symbol, ", Point: ", _Point, ", Digits: ", _Digits, ", Current Price: ", current_close);
   }
   
   // Initialize ATR indicators
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }
   
   // Initialize ATR indicators
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }
   
   // Create ATR handle for normalization timeframe
   if(NormTimeframe != PERIOD_CURRENT)
   {
      atrNormHandle = iATR(_Symbol, NormTimeframe, ATR_Period);
      if(atrNormHandle == INVALID_HANDLE)
      {
         Print("Failed to create normalization ATR indicator handle");
         return(INIT_FAILED);
      }
   }
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Release the ATR indicator handles
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
      
   if(atrNormHandle != INVALID_HANDLE)
      IndicatorRelease(atrNormHandle);
      
   // Delete info objects
   if(ShowInfo)
   {
      ObjectDelete(0, indicatorName + "_Info");
   }
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
   // If insufficient bars
   if(rates_total < ATR_Period) 
      return(0);
      
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset indicators and initialize
      ArrayInitialize(LineBuffer, EMPTY_VALUE);
      
      // Initialize the first range value
      if(rates_total > 0)
      {
         // Start at the most recent close price
         currentLevel = close[rates_total-1];
         prevLevel = close[rates_total-1];
         lastRangeBarIndex = rates_total-1;
         upTrend = true;
         lastDirection = 0; // Start as flat
         
         // Fill buffer with initial value
         for(int i=0; i<rates_total; i++)
         {
            LineBuffer[i] = currentLevel;
            ColorBuffer[i] = 2; // Start with flat color
         }
         
         if(DebugMode > 0)
         {
            Print("Initialized at price: ", currentLevel);
            Print("Symbol: ", _Symbol, ", Point: ", _Point, ", Digits: ", _Digits);
         }
      }
   }
      
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   int limit = rates_total;
   
   // Create buffer for ATR values
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   // Copy ATR values into our buffer
   if(CopyBuffer(atrHandle, 0, 0, rates_total, atrValues) <= 0)
   {
      Print("Failed to copy ATR values");
      return(0);
   }
   
   // Get ATR from normalization timeframe if needed
   double normFactor = 1.0;
   if(NormTimeframe != PERIOD_CURRENT && atrNormHandle != INVALID_HANDLE)
   {
      double atrNormValues[];
      ArraySetAsSeries(atrNormValues, true);
      
      if(CopyBuffer(atrNormHandle, 0, 0, 1, atrNormValues) > 0)
      {
         // Calculate normalization factor
         // This creates a ratio of current timeframe volatility to reference timeframe volatility
         double currentFrameATR = atrValues[0];
         double normFrameATR = atrNormValues[0];
         
         if(normFrameATR > 0)
         {
            // This factor will be larger for lower timeframes and closer to 1.0 for higher timeframes
            double timeframeRatio = GetTimeframeRatio(PERIOD_CURRENT, NormTimeframe);
            
            // Normalize ATR based on both volatility and timeframe ratio
            normFactor = (normFrameATR / currentFrameATR) * timeframeRatio;
            
            // Prevent extreme values
            normFactor = MathMax(0.1, MathMin(normFactor, 10.0));
         }
      }
   }
   
   // Adjust buffer direction to match our loop direction
   ArraySetAsSeries(atrValues, false);
      
   for(int i = start; i < limit; i++)
   {
      if(i == rates_total - 1 && !IncLstCndl) 
      {
         // For the last candle, when we don't want to include it in calculations
         // Copy the previous value to maintain continuity
         if(i > 0) 
         {
            LineBuffer[i] = LineBuffer[i-1];
            ColorBuffer[i] = ColorBuffer[i-1];
         }
      } 
      else 
      {
         // Check if this is a high-price instrument (like BTC)
         if(close[i] > 1000)
         {
            isHighPriceInstrument = true;
         }
      
         // Determine the range size (either fixed or ATR-based)
         double rangeSize;
         if(UseFixedRange)
         {
            rangeSize = FixedRangeSize * point;
         }
         else
         {
            // Get ATR value for the current bar and convert to points
            if(i < ATR_Period)
            {
               // Not enough data for ATR calculation
               rangeSize = FixedRangeSize * point; // Fallback to fixed range
            }
            else
            {
               // Use ATR to determine the range with normalization
               rangeSize = atrValues[i] * ATR_Multiplier * normFactor;
               
               // Auto-adjust range based on price level if enabled
               if(AutoAdjustRange)
               {
                  double current_price = close[i];
                  
                  // Get a percentage-based minimum range (0.1% of price)
                  double percentRange = current_price * 0.001; // 0.1% of price
                  
                  // Set minimum range as the larger of our fixed minimum or the percentage
                  double dynamicMinRange = MathMax(MinRangeSize * point, percentRange);
                  
                  // For very high priced instruments (like BTC), ensure minimum meaningful movement
                  if(current_price > 1000)
                  {
                     // For high-value assets, ensure a minimum range of 0.25% of price
                     dynamicMinRange = MathMax(dynamicMinRange, current_price * 0.0025);
                  }
                  
                  // Set maximum as either our fixed maximum or a percentage of price (1.5%)
                  double dynamicMaxRange = MathMin(MaxRangeSize * point, current_price * 0.015);
                  
                  // Make sure our range is within these dynamic bounds
                  rangeSize = MathMax(dynamicMinRange, MathMin(rangeSize, dynamicMaxRange));
                  
                  if(DebugMode > 1 && i == rates_total-1)
                  {
                     Print("Auto-adjusted range: ", rangeSize, " for price ", current_price,
                           " (Min: ", dynamicMinRange, ", Max: ", dynamicMaxRange, ")");
                  }
               }
               else
               {
                  // Traditional fixed min/max constraints (in points)
                  double rangeInPoints = rangeSize / point;
                  rangeInPoints = MathMax(MinRangeSize, MathMin(rangeInPoints, MaxRangeSize));
                  rangeSize = rangeInPoints * point;
               }
            }
         }
         
         // Store current range for info display
         //if(IsCrypto)
         //{
         //   // For crypto, display the actual price amount
         //   currentRange = rangeSize;
         //}
         //else
         //{
            // For standard instruments, display in points
            currentRange = rangeSize / point;
         //}
         
         // Calculate using the dynamic range
         CalculateRange(i, high[i], low[i], rates_total, rangeSize);
      }
   }
   
   // Update information on chart
   if(ShowInfo && rates_total > 0)
   {
      string trendStatus = "FLAT";
      if(lastDirection > 0) trendStatus = "UP";
      else if(lastDirection < 0) trendStatus = "DOWN";
      
      UpdateInfoDisplay(time[rates_total-1], close[rates_total-1], currentRange, trendStatus, lastDirection);
      
      // Add current price to info if in debug mode
      if(DebugMode > 0)
      {
         UpdateDebugInfo(rates_total-1, close[rates_total-1], currentRange);
      }
   }
      
   return(rates_total);
}

// Helper function to get ratio between timeframes
double GetTimeframeRatio(ENUM_TIMEFRAMES current, ENUM_TIMEFRAMES reference)
{
   // Convert timeframes to minutes
   int currentMinutes = PeriodSeconds(current) / 60;
   int referenceMinutes = PeriodSeconds(reference) / 60;
   
   // Prevent division by zero
   if(currentMinutes == 0) currentMinutes = 1;
   if(referenceMinutes == 0) referenceMinutes = 1;
   
   // Calculate square root of ratio to dampen the effect
   return MathSqrt((double)referenceMinutes / currentMinutes);
}

// Check if we should update debug info
void UpdateDebugInfo(int bar_index, double close_price, double range_value)
{
   if(DebugMode > 0 && bar_index > 0)
   {
      string debugName = indicatorName + "_Debug";
      string priceType = isHighPriceInstrument ? "High-Priced" : "Standard";
      
      string debugText = "Price: " + DoubleToString(close_price, _Digits) + 
                        " | Level: " + DoubleToString(currentLevel, _Digits) + 
                        " | Type: " + priceType;
      
      // Check if object exists
      if(ObjectFind(0, debugName) < 0)
      {
         // Create text label
         ObjectCreate(0, debugName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, debugName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, debugName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
         ObjectSetInteger(0, debugName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, debugName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, debugName, OBJPROP_BACK, false);
         ObjectSetInteger(0, debugName, OBJPROP_SELECTABLE, false);
      }
      
      // Update position and text
      ObjectSetInteger(0, debugName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, debugName, OBJPROP_YDISTANCE, 40);
      ObjectSetString(0, debugName, OBJPROP_TEXT, debugText);
   }
}

void CalculateRange(int bar_index, double high, double low, int rates_total, double range)
{
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   // Keep track of the previous direction
   int previousDirection = lastDirection;
   
   if(upTrend)
   {
      if(high >= currentLevel + range)
      {
         // Move the line up
         currentLevel = currentLevel + range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
         lastDirection = 1; // Up direction
      }
      else if(low <= currentLevel - range)
      {
         // Trend has reversed to down
         upTrend = false;
         currentLevel = currentLevel - range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 1; // Down color
         lastRangeBarIndex = bar_index;
         lastDirection = -1; // Down direction
      }
      else
      {
         // No change in level, copy the last value
         LineBuffer[bar_index] = currentLevel;
         
         // If we've been flat for a while, show the flat color
         if(bar_index - lastRangeBarIndex > 3 && previousDirection != 0)
         {
            // Line hasn't moved for several bars, show flat
            ColorBuffer[bar_index] = 2; // Flat color
            lastDirection = 0; // Flat direction
         }
         else
         {
            // Keep the up color for a few bars after a movement
            ColorBuffer[bar_index] = 0; // Up color
         }
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
         lastDirection = -1; // Down direction
      }
      else if(high >= currentLevel + range)
      {
         // Trend has reversed to up
         upTrend = true;
         currentLevel = currentLevel + range;
         LineBuffer[bar_index] = currentLevel;
         ColorBuffer[bar_index] = 0; // Up color
         lastRangeBarIndex = bar_index;
         lastDirection = 1; // Up direction
      }
      else
      {
         // No change in level, copy the last value
         LineBuffer[bar_index] = currentLevel;
         
         // If we've been flat for a while, show the flat color
         if(bar_index - lastRangeBarIndex > 3 && previousDirection != 0)
         {
            // Line hasn't moved for several bars, show flat
            ColorBuffer[bar_index] = 2; // Flat color
            lastDirection = 0; // Flat direction
         }
         else
         {
            // Keep the down color for a few bars after a movement
            ColorBuffer[bar_index] = 1; // Down color
         }
      }
   }
}

// Display current range information on chart
void UpdateInfoDisplay(datetime time, double price, double range, string trendText, int direction)
{
   string name = indicatorName + "_Info";
   string rangeText;
   
   if(AutoAdjustRange)
   {
      // Show as percentage of price
      rangeText = DoubleToString(range, 2) + "% of price";
   }
   else
   {
      // Show as points
      rangeText = DoubleToString(range, 1) + " points";
   }
   
   string text = "Range: " + rangeText + " | Status: " + trendText;
                 
   // Calculate position (upper right corner of chart)
   int x = 20;
   int y = 20;
   
   // Determine color based on direction
   color infoColor;
   if(direction > 0) infoColor = UpColor;
   else if(direction < 0) infoColor = DownColor;
   else infoColor = FlatColor;
   
   // Check if object exists
   if(ObjectFind(0, name) < 0)
   {
      // Create text label
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_COLOR, infoColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   
   // Update position and text
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, infoColor);
   
   // Force chart update
   ChartRedraw(0);
}
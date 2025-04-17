#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  1

enum RANGE_CALC_MODE {
   FIXED_RANGE = 0,   // Fixed Range
   CURRENT_DAY = 1,   // Current Day Average
   PREVIOUS_DAY = 2   // Previous Day Average
};

input int              RangeSize = 25;             // Fixed Range size in points
input RANGE_CALC_MODE  RangeMode = FIXED_RANGE;    // Range Calculation Mode
input int              MinimumLegs = 5;            // Minimum legs for calculation
input int              DefaultRange = 25;          // Default range if not enough data
input color            UpColor = clrLime;          // Color for up candles
input color            DownColor = clrRed;         // Color for down candles

double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
double ColorBuffer[];

double currentOpen = 0;
double currentHigh = 0;
double currentLow = 0;
double currentClose = 0;
double prevClose = 0;
int currentBar = 0;
bool upTrend = true;
double point;
double dynamicRange;

// Leg tracking variables
struct LegInfo {
   datetime time;
   double size;
};

LegInfo legs[];

int OnInit()
{
   // Initialize buffers
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ColorBuffer, INDICATOR_COLOR_INDEX);
   
   PlotIndexSetString(0, PLOT_LABEL, "Range Candles");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_CANDLES);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   point = _Point;
   dynamicRange = RangeSize * point; // Default to fixed range initially
   
   // Ensure arrays are empty
   ArrayResize(legs, 0);
   
   // Initialize chart data
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
   // Validate input data
   if(rates_total <= 0) return 0;
   
   // Full recalculation
   if(prev_calculated == 0)
   {
      // Clear all buffers
      ArrayInitialize(OpenBuffer, EMPTY_VALUE);
      ArrayInitialize(HighBuffer, EMPTY_VALUE);
      ArrayInitialize(LowBuffer, EMPTY_VALUE);
      ArrayInitialize(CloseBuffer, EMPTY_VALUE);
      ArrayInitialize(ColorBuffer, 0);
      
      // Reset chart state
      InitializeRangeChart();
   }
   
   // Update dynamic range based on selected mode
   if(RangeMode != FIXED_RANGE) {
      // Only update if we have data
      if(ArraySize(time) > 0) {
         UpdateDynamicRange(time[0]);
      }
   }
   
   // Process prices
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
   {
      ProcessPrice(time[i], open[i], high[i], low[i], close[i]);
   }
   
   return(rates_total);
}

void InitializeRangeChart()
{
   // Reset variables
   currentBar = 0;  // Critical: Start at 0
   upTrend = true;
   
   // Get initial price data
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
      }
   }
   
   // Clear legs array
   ArrayFree(legs);
   
   // Set initial dynamic range
   if(RangeMode != FIXED_RANGE) {
      // Load historical legs to initialize the dynamic range
      LoadHistoricalLegs();
      UpdateDynamicRange(TimeCurrent());
   } else {
      dynamicRange = RangeSize * point;
   }
}

void ProcessPrice(datetime time, double open, double high, double low, double close)
{
   // Use the dynamic range instead of fixed range
   double range = dynamicRange;
   
   // Safety check - ensure we have a valid range
   if(range <= 0) range = DefaultRange * point;
   
   // Process based on trend direction
   if(upTrend)
   {
      if(high >= currentHigh + range)
      {
         // Record this leg
         RecordLeg(time, range);
         
         // Update buffers - ensure valid index
         currentBar++;
         if(currentBar >= 0) {
            OpenBuffer[currentBar] = currentHigh;
            HighBuffer[currentBar] = currentHigh + range;
            LowBuffer[currentBar] = currentHigh;
            CloseBuffer[currentBar] = currentHigh + range;
            ColorBuffer[currentBar] = 0; // Up color
         }
         
         // Update current values
         currentHigh = currentHigh + range;
         currentLow = currentHigh;
         currentClose = currentHigh;
         prevClose = currentClose;
      }
      else if(low <= currentHigh - range)
      {
         // Record this leg
         RecordLeg(time, range);
         
         // Change trend direction
         upTrend = false;
         
         // Update buffers - ensure valid index
         currentBar++;
         if(currentBar >= 0) {
            OpenBuffer[currentBar] = currentHigh;
            HighBuffer[currentBar] = currentHigh;
            LowBuffer[currentBar] = currentHigh - range;
            CloseBuffer[currentBar] = currentHigh - range;
            ColorBuffer[currentBar] = 1; // Down color
         }
         
         // Update current values
         currentLow = currentHigh - range;
         currentClose = currentLow;
         prevClose = currentClose;
      }
   }
   else // Downtrend
   {
      if(low <= currentLow - range)
      {
         // Record this leg
         RecordLeg(time, range);
         
         // Update buffers - ensure valid index
         currentBar++;
         if(currentBar >= 0) {
            OpenBuffer[currentBar] = currentLow;
            HighBuffer[currentBar] = currentLow;
            LowBuffer[currentBar] = currentLow - range;
            CloseBuffer[currentBar] = currentLow - range;
            ColorBuffer[currentBar] = 1; // Down color
         }
         
         // Update current values
         currentHigh = currentLow;
         currentLow = currentLow - range;
         currentClose = currentLow;
         prevClose = currentClose;
      }
      else if(high >= currentLow + range)
      {
         // Record this leg
         RecordLeg(time, range);
         
         // Change trend direction
         upTrend = true;
         
         // Update buffers - ensure valid index
         currentBar++;
         if(currentBar >= 0) {
            OpenBuffer[currentBar] = currentLow;
            HighBuffer[currentBar] = currentLow + range;
            LowBuffer[currentBar] = currentLow;
            CloseBuffer[currentBar] = currentLow + range;
            ColorBuffer[currentBar] = 0; // Up color
         }
         
         // Update current values
         currentHigh = currentLow + range;
         currentClose = currentHigh;
         prevClose = currentClose;
      }
   }
}

// Record a completed leg for calculating average
void RecordLeg(datetime time, double size)
{
   // Safe array resize
   int oldSize = ArraySize(legs);
   int newSize = oldSize + 1;
   
   if(ArrayResize(legs, newSize) != newSize) {
      Print("Failed to resize legs array to ", newSize);
      return;
   }
   
   // Store leg data
   legs[oldSize].time = time;
   legs[oldSize].size = size / point; // Store in points for easier calculation
   
   // Update dynamic range after recording a new leg
   if(RangeMode != FIXED_RANGE) {
      UpdateDynamicRange(time);
   }
}

// Load historical legs from past data
void LoadHistoricalLegs()
{
   // Clear existing legs
   ArrayFree(legs);
   
   // Get historical data
   MqlRates rates[];
   int copied = CopyRates(_Symbol, _Period, 0, 500, rates); // Limit to 500 bars for performance
   
   if(copied <= 0) {
      Print("Failed to get historical rates for leg calculation");
      return;
   }
   
   // Initialize values from first bar
   double prevHigh = rates[0].high;
   double prevLow = rates[0].low;
   bool isUptrend = true;
   
   // Calculate historical legs
   for(int i = 1; i < copied; i++)
   {
      if(isUptrend)
      {
         if(rates[i].high > prevHigh + RangeSize * point)
         {
            // Completed an up leg
            double legSize = RangeSize;
            prevHigh = rates[i].high;
            prevLow = prevHigh;
            
            // Safe array resize and add leg
            int count = ArraySize(legs);
            if(ArrayResize(legs, count + 1) == count + 1) {
               legs[count].time = rates[i].time;
               legs[count].size = legSize;
            }
         }
         else if(rates[i].low < prevHigh - RangeSize * point)
         {
            // Changed direction
            double legSize = RangeSize;
            isUptrend = false;
            prevLow = prevHigh - RangeSize * point;
            
            // Safe array resize and add leg
            int count = ArraySize(legs);
            if(ArrayResize(legs, count + 1) == count + 1) {
               legs[count].time = rates[i].time;
               legs[count].size = legSize;
            }
         }
      }
      else // Downtrend
      {
         if(rates[i].low < prevLow - RangeSize * point)
         {
            // Completed a down leg
            double legSize = RangeSize;
            prevLow = rates[i].low;
            prevHigh = prevLow;
            
            // Safe array resize and add leg
            int count = ArraySize(legs);
            if(ArrayResize(legs, count + 1) == count + 1) {
               legs[count].time = rates[i].time;
               legs[count].size = legSize;
            }
         }
         else if(rates[i].high > prevLow + RangeSize * point)
         {
            // Changed direction
            double legSize = RangeSize;
            isUptrend = true;
            prevHigh = prevLow + RangeSize * point;
            
            // Safe array resize and add leg
            int count = ArraySize(legs);
            if(ArrayResize(legs, count + 1) == count + 1) {
               legs[count].time = rates[i].time;
               legs[count].size = legSize;
            }
         }
      }
   }
   
   // Debug output
   Print("Loaded ", ArraySize(legs), " historical legs");
}

// Update the dynamic range based on average leg size
void UpdateDynamicRange(datetime currentTime)
{
   int legsCount = ArraySize(legs);
   
   // Check if we have enough legs
   if(legsCount < MinimumLegs)
   {
      // Not enough data, use default
      dynamicRange = DefaultRange * point;
      return;
   }
   
   double totalSize = 0;
   int validLegsCount = 0;
   
   // Get current time components
   MqlDateTime currentMqlTime;
   TimeToStruct(currentTime, currentMqlTime);
   
   // Calculate previous day
   datetime prevDay = currentTime - 86400; // 24 hours in seconds
   MqlDateTime prevDayStruct;
   TimeToStruct(prevDay, prevDayStruct);
   
   // Calculate average based on selected mode
   for(int i = 0; i < legsCount; i++)
   {
      // Get leg time components
      MqlDateTime legMqlTime;
      TimeToStruct(legs[i].time, legMqlTime);
      
      bool includeThisLeg = false;
      
      if(RangeMode == CURRENT_DAY)
      {
         // Include if from current day
         includeThisLeg = (legMqlTime.day == currentMqlTime.day && 
                           legMqlTime.mon == currentMqlTime.mon &&
                           legMqlTime.year == currentMqlTime.year);
      }
      else if(RangeMode == PREVIOUS_DAY)
      {
         // Include if from previous day
         includeThisLeg = (legMqlTime.day == prevDayStruct.day && 
                           legMqlTime.mon == prevDayStruct.mon &&
                           legMqlTime.year == prevDayStruct.year);
      }
      
      if(includeThisLeg)
      {
         totalSize += legs[i].size;
         validLegsCount++;
      }
   }
   
   // Calculate and set dynamic range
   if(validLegsCount >= MinimumLegs)
   {
      double averageSize = totalSize / validLegsCount;
      dynamicRange = averageSize * point;
      
      // Debug output
      Print("Dynamic Range updated: ", averageSize, " points based on ", validLegsCount, " legs");
   }
   else
   {
      // Not enough data for the specified mode, use default
      dynamicRange = DefaultRange * point;
      Print("Using default range: not enough valid legs (", validLegsCount, "/", MinimumLegs, " required)");
   }
}
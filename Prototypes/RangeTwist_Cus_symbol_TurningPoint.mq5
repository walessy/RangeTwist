//+------------------------------------------------------------------+
//|                      RangeTwistWithVisibleArrows.mq5 |
//+------------------------------------------------------------------+
#property copyright "Based on RangeTwist by Amos"
#property version   "1.00"
#property indicator_separate_window  // Use separate window for better visualization
#property indicator_buffers 5
#property indicator_plots   3
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label1  "RangeTwist"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  5        // Increased width for visibility
#property indicator_label2  "Upward Turn"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  5        // Increased width for visibility
#property indicator_label3  "Downward Turn"

// Input parameters
input int    RangeSize = 25;               // Range size in points
input bool   NormalizeValues = true;       // Normalize values to 0-100 range
input double ArrowOffset = 5.0;            // Vertical offset for arrows
input bool   ShowAllLevels = false;        // Show arrows at all level changes, not just trend changes

// Indicator buffers
double RangeTwistBuffer[];
double UpArrowBuffer[];
double DownArrowBuffer[];
double DirectionBuffer[];
double LevelChangeBuffer[];

// RangeTwist variables
double currentLevel = 0;
double prevLevel = 0;
bool upTrend = true;
bool prevUpTrend = true;
double pointValue;
double minValue, maxValue;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   SetIndexBuffer(0, RangeTwistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, UpArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, DownArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, DirectionBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, LevelChangeBuffer, INDICATOR_CALCULATIONS);
   
   // Set up arrow codes (standard arrows)
   PlotIndexSetInteger(1, PLOT_ARROW, 241);  // Large up arrow
   PlotIndexSetInteger(2, PLOT_ARROW, 242);  // Large down arrow
   
   // Initialize variables
   pointValue = _Point;
   
   // Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "RangeTwist with Arrows");
   
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
   if(rates_total < 3) return(0);
   
   int start;
   
   // Initialize arrays on first run
   if(prev_calculated <= 0)
   {
      ArrayInitialize(RangeTwistBuffer, EMPTY_VALUE);
      ArrayInitialize(UpArrowBuffer, EMPTY_VALUE);
      ArrayInitialize(DownArrowBuffer, EMPTY_VALUE);
      ArrayInitialize(DirectionBuffer, 0);
      ArrayInitialize(LevelChangeBuffer, 0);
      
      // Initialize variables
      currentLevel = close[0];
      prevLevel = currentLevel;
      upTrend = true;
      prevUpTrend = true;
      minValue = currentLevel;
      maxValue = currentLevel;
      
      start = 0;
   }
   else
   {
      // Continue from last calculated bar
      start = prev_calculated - 2; // Go back a few bars to handle any boundary cases
      if(start < 0) start = 0;
   }
   
   // First pass - calculate range values
   for(int i = start; i < rates_total; i++)
   {
      if(i == 0)
      {
         // Initialize first bar
         RangeTwistBuffer[i] = close[i];
         DirectionBuffer[i] = 1; // Start with uptrend
         LevelChangeBuffer[i] = 0;
         continue;
      }
      
      // Save previous values
      prevLevel = currentLevel;
      prevUpTrend = upTrend;
      
      // Calculate new level using RangeTwist logic
      CalculateRangeLevel(high[i], low[i], RangeSize * pointValue);
      
      // Store values
      RangeTwistBuffer[i] = currentLevel;
      DirectionBuffer[i] = upTrend ? 1 : -1;
      LevelChangeBuffer[i] = (prevLevel != currentLevel) ? 1 : 0;
      
      // Update min/max for normalization
      if(currentLevel < minValue) minValue = currentLevel;
      if(currentLevel > maxValue) maxValue = currentLevel;
   }
   
   // Apply normalization if requested
   if(NormalizeValues && maxValue > minValue)
   {
      double range = maxValue - minValue;
      for(int i = start; i < rates_total; i++)
      {
         if(RangeTwistBuffer[i] != EMPTY_VALUE)
         {
            RangeTwistBuffer[i] = 100 * (RangeTwistBuffer[i] - minValue) / range;
         }
      }
   }
   
   // Second pass - place arrows
   for(int i = start; i < rates_total; i++)
   {
      // Clear arrow buffers by default
      UpArrowBuffer[i] = EMPTY_VALUE;
      DownArrowBuffer[i] = EMPTY_VALUE;
      
      // Skip first bar
      if(i < 2) continue;
      
      // Check if there was a level change
      bool levelChanged = (LevelChangeBuffer[i] > 0);
      
      // Check if there was a trend change
      bool trendChanged = (DirectionBuffer[i] != DirectionBuffer[i-1]);
      
      // Place arrows based on user preferences
      if(levelChanged && (ShowAllLevels || trendChanged))
      {
         // Place arrow based on current trend
         if(DirectionBuffer[i] > 0) // Uptrend
         {
            // Place an up arrow below the line
            UpArrowBuffer[i] = RangeTwistBuffer[i] - ArrowOffset;
            DownArrowBuffer[i] = EMPTY_VALUE;
            
            // Debug output
            Print("Up Arrow placed at bar ", i, ", value: ", UpArrowBuffer[i]);
         }
         else // Downtrend
         {
            // Place a down arrow above the line
            UpArrowBuffer[i] = EMPTY_VALUE;
            DownArrowBuffer[i] = RangeTwistBuffer[i] + ArrowOffset;
            
            // Debug output
            Print("Down Arrow placed at bar ", i, ", value: ", DownArrowBuffer[i]);
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate range level for bar (based on RangeTwist logic)        |
//+------------------------------------------------------------------+
void CalculateRangeLevel(double high, double low, double range)
{
   if(upTrend)
   {
      if(high >= currentLevel + range)
      {
         // Move the line up
         prevLevel = currentLevel;
         currentLevel = currentLevel + range;
      }
      else if(low <= currentLevel - range)
      {
         // Trend has reversed to down
         prevLevel = currentLevel;
         upTrend = false;
         currentLevel = currentLevel - range;
      }
   }
   else // downtrend
   {
      if(low <= currentLevel - range)
      {
         // Move the line down
         prevLevel = currentLevel;
         currentLevel = currentLevel - range;
      }
      else if(high >= currentLevel + range)
      {
         // Trend has reversed to up
         prevLevel = currentLevel;
         upTrend = true;
         currentLevel = currentLevel + range;
      }
   }
}
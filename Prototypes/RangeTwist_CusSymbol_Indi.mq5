//+------------------------------------------------------------------+
//|                                RangeTwistFlattened.mq5 |
//+------------------------------------------------------------------+
#property copyright "Based on RangeTwist by Amos"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label1  "RangeTwist"

// Input parameters
input int    RangeSize = 25;              // Range size in points
input bool   NormalizeValues = true;       // Normalize values to 0-100 range
input double YScale = 1.0;                 // Y-scale factor
input double YOffset = 0.0;                // Y-offset 
input int    FirstBar = 0;                 // First bar to start calculations from

// Indicator buffers
double RangeTwistBuffer[];
double ColorBuffer[];

// RangeTwist variables
double currentLevel = 0;
double prevLevel = 0;
bool upTrend = true;
double pointValue;
double minValue, maxValue;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   SetIndexBuffer(0, RangeTwistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_DATA);
   
   // Set indicator properties
   PlotIndexSetString(0, PLOT_LABEL, "RangeTwist Flattened");
   
   // Set the scale and offset
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, YOffset);
   
   // Initialize values
   pointValue = _Point;
   
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
   
   // Calculate start position
   int start;
   
   // In the first calculation, initialize our value at FirstBar
   if(prev_calculated <= 0) 
   {
      // Initialize RangeTwist variables
      currentLevel = close[FirstBar];
      prevLevel = close[FirstBar];
      upTrend = true;
      
      // Initialize min and max values
      minValue = currentLevel;
      maxValue = currentLevel;
      
      // Set starting point
      start = FirstBar;
      
      // Clear the buffers
      ArrayInitialize(RangeTwistBuffer, EMPTY_VALUE);
   }
   else
   {
      // Continue from the previous bar
      start = prev_calculated - 1;
   }
   
   // Main calculation loop
   for(int i = start; i < rates_total; i++)
   {      
      // Calculate range using RangeTwist logic
      CalculateRangeLevel(high[i], low[i], RangeSize * pointValue);
      
      // Store range level in buffer
      RangeTwistBuffer[i] = currentLevel;
      
      // Update min and max values for normalization
      if(currentLevel < minValue) minValue = currentLevel;
      if(currentLevel > maxValue) maxValue = currentLevel;
   }
   
   // Normalize values if requested
   if(NormalizeValues && maxValue > minValue)
   {
      double range = maxValue - minValue;
      
      for(int i = start; i < rates_total; i++)
      {
         if(RangeTwistBuffer[i] != EMPTY_VALUE)
         {
            // Normalize to 0-100 range
            double normalizedValue = 100 * (RangeTwistBuffer[i] - minValue) / range;
            
            // Apply scale and offset
            RangeTwistBuffer[i] = normalizedValue * YScale + YOffset;
         }
      }
   }
   else
   {
      // Apply scale and offset without normalization
      for(int i = start; i < rates_total; i++)
      {
         if(RangeTwistBuffer[i] != EMPTY_VALUE)
         {
            RangeTwistBuffer[i] = RangeTwistBuffer[i] * YScale + YOffset;
         }
      }
   }
   
   // Return value of prev_calculated for next call
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
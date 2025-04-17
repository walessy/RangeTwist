//+------------------------------------------------------------------+
//|             DynamicTurningPoints.mq5                             |
//|             Dynamically calculates turning points thresholds      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  3
#property indicator_label1  "Top"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreen
#property indicator_width2  3
#property indicator_label2  "Bottom"

// Input parameters
input int     TicksToAnalyze = 40;       // Number of ticks to analyze
input int     LookbackPeriods = 10;      // Periods for volatility calculation
input double  VolatilityMultiplier = 1.5; // Multiplier for volatility threshold

// Indicator buffers
double TopBuffer[];
double BottomBuffer[];

// Global variables
MqlTick lastTicks[];
double priceHistory[];
int tickCount = 0;
datetime lastSignalTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up buffers
   SetIndexBuffer(0, TopBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BottomBuffer, INDICATOR_DATA);
   
   // Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 218);
   PlotIndexSetInteger(1, PLOT_ARROW, 217);
   
   // Initialize arrays
   ArrayInitialize(TopBuffer, EMPTY_VALUE);
   ArrayInitialize(BottomBuffer, EMPTY_VALUE);
   
   // Allocate memory for tick storage
   ArrayResize(lastTicks, TicksToAnalyze * 2);
   ArrayResize(priceHistory, LookbackPeriods * 10); // Store more price history for volatility calc
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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
   // Get current tick
   MqlTick currentTick;
   if(!SymbolInfoTick(Symbol(), currentTick))
      return(rates_total);
      
   // Store tick data
   for(int i = ArraySize(lastTicks) - 1; i > 0; i--)
      lastTicks[i] = lastTicks[i-1];
      
   lastTicks[0] = currentTick;
   
   // Store price history for volatility calculation
   for(int i = ArraySize(priceHistory) - 1; i > 0; i--)
      priceHistory[i] = priceHistory[i-1];
      
   priceHistory[0] = (currentTick.bid + currentTick.ask) / 2;
   
   if(tickCount < MathMax(ArraySize(lastTicks), ArraySize(priceHistory)))
      tickCount++;
      
   // Need enough ticks to analyze
   if(tickCount < MathMax(TicksToAnalyze, LookbackPeriods * 10))
      return(rates_total);
      
   // Only check once per second to save resources
   if(currentTick.time <= lastSignalTime)
      return(rates_total);
      
   lastSignalTime = currentTick.time;
   
   // Get middle price for current tick
   double currentPrice = (currentTick.bid + currentTick.ask) / 2;
   
   // Calculate dynamic threshold based on recent volatility
   double dynamicThreshold = CalculateVolatilityThreshold();
   
   // Check for turning points
   bool potentialTop = true;
   bool potentialBottom = true;
   
   for(int i = 1; i < TicksToAnalyze; i++)
   {
      double prevPrice = (lastTicks[i].bid + lastTicks[i].ask) / 2;
      
      // For a top, all previous prices should be lower
      if(prevPrice >= currentPrice)
         potentialTop = false;
         
      // For a bottom, all previous prices should be higher
      if(prevPrice <= currentPrice)
         potentialBottom = false;
   }
   
   // Find bar index for current time
   int barIndex = 0;
   while(barIndex < rates_total && time[barIndex] > currentTick.time)
      barIndex++;
      
   // If no matching bar found, use most recent
   if(barIndex >= rates_total)
      barIndex = 0;
      
   // Check if price change exceeds our dynamic threshold
   double priceChange = MathAbs(currentPrice - (lastTicks[TicksToAnalyze-1].bid + lastTicks[TicksToAnalyze-1].ask)/2);
   
   // Mark turning points if they exceed the dynamic threshold
   if(potentialTop && priceChange > dynamicThreshold)
   {
      TopBuffer[barIndex] = high[barIndex];
      PrintFormat("Top detected at %s price %.5f (threshold: %.5f)", 
                  TimeToString(currentTick.time), currentPrice, dynamicThreshold);
   }
   
   if(potentialBottom && priceChange > dynamicThreshold)
   {
      BottomBuffer[barIndex] = low[barIndex];
      PrintFormat("Bottom detected at %s price %.5f (threshold: %.5f)", 
                  TimeToString(currentTick.time), currentPrice, dynamicThreshold);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate dynamic threshold based on recent price volatility      |
//+------------------------------------------------------------------+
double CalculateVolatilityThreshold()
{
   double highestHigh = priceHistory[0];
   double lowestLow = priceHistory[0];
   double sumChanges = 0;
   
   // Find highest high and lowest low
   for(int i = 0; i < LookbackPeriods * 10; i++)
   {
      if(priceHistory[i] > highestHigh)
         highestHigh = priceHistory[i];
         
      if(priceHistory[i] < lowestLow)
         lowestLow = priceHistory[i];
         
      // Calculate tick-to-tick changes for additional volatility measure
      if(i < LookbackPeriods * 10 - 1)
         sumChanges += MathAbs(priceHistory[i] - priceHistory[i+1]);
   }
   
   // Calculate range-based volatility
   double rangeVolatility = (highestHigh - lowestLow) / LookbackPeriods;
   
   // Calculate average tick-to-tick volatility
   double avgTickChange = sumChanges / (LookbackPeriods * 10 - 1);
   
   // Use a weighted combination of both measures
   double combinedVolatility = (rangeVolatility * 0.7) + (avgTickChange * 10 * 0.3);
   
   // Apply multiplier and return
   return combinedVolatility * VolatilityMultiplier;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Nothing special to clean up
}
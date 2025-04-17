//+------------------------------------------------------------------+
//|             TickDataTurningPoints.mq5                            |
//|             Copyright 2025                                        |
//|             Analyzes tick data to find turning points             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  2
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreen
#property indicator_width2  2

// Input parameters
input int     TickBuffer = 1000;        // Number of ticks to store in memory
input int     PeakValleyPeriod = 10;    // Period for peak/valley detection
input double  MinPriceChange = 0.0005;  // Minimum price change for turning point
input bool    ShowTurningPoints = true; // Display turning points on chart

// Indicator buffers
double TopsBuffer[];
double BottomsBuffer[];

// Global variables
MqlTick tickArray[];
int tickCount = 0;
datetime lastDetectionTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, TopsBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BottomsBuffer, INDICATOR_DATA);
   
   // Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 159); // Down arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 158); // Up arrow
   
   // Initialize buffer for tick data
   ArrayResize(tickArray, TickBuffer);
   
   // Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Tick Data Turning Points");
   
   // Initialize empty values
   ArrayInitialize(TopsBuffer, EMPTY_VALUE);
   ArrayInitialize(BottomsBuffer, EMPTY_VALUE);
   
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
   // Process incoming ticks
   MqlTick currentTick;
   if(SymbolInfoTick(Symbol(), currentTick))
   {
      // Store tick data
      StoreTickData(currentTick);
      
      // Detect turning points in tick data
      if(tickCount > PeakValleyPeriod * 2)
      {
         // Only run detection once per second to save resources
         if(currentTick.time > lastDetectionTime)
         {
            DetectTurningPoints(time, high, low, rates_total);
            lastDetectionTime = currentTick.time;
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Store tick data in circular buffer                                |
//+------------------------------------------------------------------+
void StoreTickData(MqlTick &tick)
{
   // Shift data in circular buffer
   for(int i = TickBuffer - 1; i > 0; i--)
   {
      tickArray[i] = tickArray[i-1];
   }
   
   // Add new tick to buffer
   tickArray[0] = tick;
   
   if(tickCount < TickBuffer)
      tickCount++;
}

//+------------------------------------------------------------------+
//| Detect turning points in tick data                                |
//+------------------------------------------------------------------+
void DetectTurningPoints(const datetime &time[], const double &high[], const double &low[], int rates_total)
{
   if(!ShowTurningPoints || tickCount < PeakValleyPeriod * 2)
      return;
   
   // We'll check the middle of our available data
   int checkIndex = PeakValleyPeriod;
   
   bool isTop = true;
   bool isBottom = true;
   
   // Reference price
   double checkPrice = (tickArray[checkIndex].ask + tickArray[checkIndex].bid) / 2;
   
   // Check if it's a top
   for(int i = 0; i < PeakValleyPeriod; i++)
   {
      double beforePrice = (tickArray[checkIndex + i + 1].ask + tickArray[checkIndex + i + 1].bid) / 2;
      double afterPrice = (tickArray[checkIndex - i - 1].ask + tickArray[checkIndex - i - 1].bid) / 2;
      
      if(beforePrice >= checkPrice || afterPrice >= checkPrice)
      {
         isTop = false;
         break;
      }
   }
   
   // Check if it's a bottom
   for(int i = 0; i < PeakValleyPeriod; i++)
   {
      double beforePrice = (tickArray[checkIndex + i + 1].ask + tickArray[checkIndex + i + 1].bid) / 2;
      double afterPrice = (tickArray[checkIndex - i - 1].ask + tickArray[checkIndex + i + 1].bid) / 2;
      
      if(beforePrice <= checkPrice || afterPrice <= checkPrice)
      {
         isBottom = false;
         break;
      }
   }
   
   // Check for minimum price change
   if(isTop || isBottom)
   {
      double maxDiff = 0;
      
      for(int i = 0; i < PeakValleyPeriod * 2; i++)
      {
         double tickPrice = (tickArray[i].ask + tickArray[i].bid) / 2;
         double diff = MathAbs(tickPrice - checkPrice);
         
         if(diff > maxDiff)
            maxDiff = diff;
      }
      
      if(maxDiff < MinPriceChange)
      {
         isTop = false;
         isBottom = false;
      }
   }
   
   // If we found a valid turning point, mark it on the chart
   if(isTop || isBottom)
   {
      // Find the closest bar index to our tick time
      int barIndex = -1;
      for(int i = 0; i < rates_total; i++)
      {
         if(time[i] <= tickArray[checkIndex].time)
         {
            barIndex = i;
            break;
         }
      }
      
      if(barIndex >= 0)
      {
         if(isTop)
         {
            TopsBuffer[barIndex] = high[barIndex];
            
            // Create a text label
            string objName = "Top_" + TimeToString(time[barIndex]);
            if(ObjectFind(0, objName) < 0) // Only create if doesn't exist
            {
               ObjectCreate(0, objName, OBJ_TEXT, 0, time[barIndex], high[barIndex] + 10 * Point());
               ObjectSetString(0, objName, OBJPROP_TEXT, "Tick Top");
               ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
            }
         }
         else // Bottom
         {
            BottomsBuffer[barIndex] = low[barIndex];
            
            // Create a text label
            string objName = "Bottom_" + TimeToString(time[barIndex]);
            if(ObjectFind(0, objName) < 0) // Only create if doesn't exist
            {
               ObjectCreate(0, objName, OBJ_TEXT, 0, time[barIndex], low[barIndex] - 10 * Point());
               ObjectSetString(0, objName, OBJPROP_TEXT, "Tick Bottom");
               ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
               ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
            }
         }
         
         // Refresh the chart
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up text objects when indicator is removed
   ObjectsDeleteAll(0, "Top_");
   ObjectsDeleteAll(0, "Bottom_");
}
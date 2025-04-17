//+------------------------------------------------------------------+
//|                                       RangeBarsScript.mq5        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website/Email"
#property version   "1.00"
#property script_show_inputs
#property strict

// Input parameters
input int    RangeSize = 100;           // Range size in points
input color  UpColor = clrLimeGreen;    // Color for up bars
input color  DownColor = clrCrimson;    // Color for down bars
input int    BarWidth = 2;              // Width of bars in pixels
input int    HistoryBars = 500;         // Number of historical bars to process

// Global variables
string objPrefix = "RangeBar_";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Clean up any existing objects
   ObjectsDeleteAll(0, objPrefix);
   
   // Fetch historical data
   MqlRates rates[];
   ArraySetAsSeries(rates, true); // Most recent first
   int copied = CopyRates(_Symbol, _Period, 0, HistoryBars, rates);
   
   if(copied <= 0)
   {
      Alert("Failed to copy price data. Error: ", GetLastError());
      return;
   }
   
   Print("Successfully copied ", copied, " bars for analysis");
   
   // Initialize with the oldest bar's close
   double lastPrice = rates[copied-1].close;
   datetime lastTime = rates[copied-1].time;
   int barCount = 0;
   
   Print("Starting price: ", lastPrice, " at time: ", TimeToString(lastTime));
   Print("Symbol Point value: ", _Point, ", Range in price: ", RangeSize * _Point);
   
   // Process all bars to create range bars
   for(int i = copied-2; i >= 0; i--) // Start from second oldest and work forward
   {
      double currentPrice = rates[i].close;
      datetime currentTime = rates[i].time;
      
      // If price has moved enough, create a new range bar
      double priceDiff = MathAbs(currentPrice - lastPrice);
      double rangeAmount = RangeSize * _Point;
      
      if(priceDiff >= rangeAmount)
      {
         // Create new range bar
         bool isUp = currentPrice > lastPrice;
         color barColor = isUp ? UpColor : DownColor;
         
         // Create a rectangle object for the range bar
         string objName = objPrefix + IntegerToString(barCount);
         
         // Draw from the last time to current time
         if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, lastTime, lastPrice, currentTime, currentPrice))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
            ObjectSetInteger(0, objName, OBJPROP_FILL, true);
            ObjectSetInteger(0, objName, OBJPROP_BACK, false); // Draw over the chart
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, BarWidth);
            
            Print("Created range bar #", barCount, 
                 " from ", lastPrice, " to ", currentPrice,
                 " (diff: ", priceDiff, ")");
            
            // Update for next bar
            lastPrice = currentPrice;
            lastTime = currentTime;
            barCount++;
         }
         else
         {
            Print("Failed to create object: ", GetLastError());
         }
      }
   }
   
   // Final summary
   if(barCount > 0)
   {
      Print("Created ", barCount, " range bars");
      ChartRedraw(0);
   }
   else
   {
      Print("No range bars created. Try reducing the range size.");
      Alert("No range bars created. Try reducing the range size.");
   }
}
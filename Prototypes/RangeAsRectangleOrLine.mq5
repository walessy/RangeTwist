//+------------------------------------------------------------------+
//|                          RangeBarWithLinesScript.mq5             |
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
input color  DownColor = clrRed;        // Color for down bars
input int    BarWidth = 2;              // Width of bars in pixels
input bool   ShowValues = false;        // Show price values on bars
input bool   DrawLines = false;         // Draw lines instead of rectangles
input int    LineWidth = 3;             // Width of lines (if using lines)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Prefix for object names
   string objPrefix = "RangeBar_Line_";
   
   // Clear any existing objects with our prefix
   ObjectsDeleteAll(0, objPrefix);
   
   // Get MAXIMUM available history
   datetime start_time = D'1970.01.01 00:00';  // Very old date to get all history
   datetime end_time = TimeCurrent();
   
   // First try to force load the full history
   Print("Forcing history load from oldest available data...");
   int available_bars = Bars(_Symbol, _Period, start_time, end_time);
   
   Print("Available bars: ", available_bars);
   
   if(available_bars <= 0)
   {
      Print("No historical data available");
      return;
   }
   
   // Process in chunks if necessary for very large datasets
   const int CHUNK_SIZE = 500000; // Process data in chunks to avoid memory errors
   int chunks_needed = (int)MathCeil((double)available_bars / CHUNK_SIZE);
   
   Print("Processing data in ", chunks_needed, " chunks");
   Print("Range size: ", RangeSize, " points = ", RangeSize * _Point, " in price");
   Print("Drawing mode: ", (DrawLines ? "Lines" : "Rectangles"));
   
   int total_processed = 0;
   int barCount = 0;
   double lastPrice = 0;
   datetime lastTime = 0;
   bool first_bar = true;
   
   // Process all chunks
   for(int chunk = 0; chunk < chunks_needed; chunk++)
   {
      // Calculate range for this chunk
      int start_pos = chunk * CHUNK_SIZE;
      int bars_to_copy = MathMin(CHUNK_SIZE, available_bars - total_processed);
      
      Print("Processing chunk ", chunk+1, "/", chunks_needed, " - bars ", start_pos, " to ", start_pos + bars_to_copy - 1);
      
      // Get data for this chunk
      MqlRates rates[];
      if(CopyRates(_Symbol, _Period, start_pos, bars_to_copy, rates) <= 0)
      {
         Print("Failed to copy data for chunk ", chunk+1);
         
         // Try a smaller chunk as fallback
         bars_to_copy = MathMax(1000, bars_to_copy / 10);
         if(CopyRates(_Symbol, _Period, start_pos, bars_to_copy, rates) <= 0)
         {
            Print("Fallback copy also failed. Skipping to next chunk.");
            total_processed += bars_to_copy;
            continue;
         }
      }
      
      int rates_count = ArraySize(rates);
      Print("Copied ", rates_count, " bars for processing");
      
      // Process this chunk of data
      for(int i = 0; i < rates_count; i++)
      {
         // For the very first bar, just record the price
         if(first_bar)
         {
            lastPrice = rates[i].close;
            lastTime = rates[i].time;
            first_bar = false;
            continue;
         }
         
         double currentPrice = rates[i].close;
         datetime currentTime = rates[i].time;
         
         // If price moved enough, create a range bar
         double priceDiff = MathAbs(currentPrice - lastPrice);
         double rangeAmount = RangeSize * _Point;
         
         if(priceDiff >= rangeAmount)
         {
            // Create range bar
            string objName = objPrefix + IntegerToString(barCount);
            bool isUp = currentPrice > lastPrice;
            color barColor = isUp ? UpColor : DownColor;
            
            if(DrawLines)
            {
               // Draw a trend line
               if(ObjectCreate(0, objName, OBJ_TREND, 0, lastTime, lastPrice, currentTime, currentPrice))
               {
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
                  ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
                  ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                  ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                  ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  
                  // Only log progress periodically
                  if(barCount % 100 == 0)
                  {
                     Print("Created range line #", barCount, 
                          " at ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES),
                          " price: ", DoubleToString(currentPrice, _Digits));
                  }
                  
                  // Update for next bar
                  lastPrice = currentPrice;
                  lastTime = currentTime;
                  barCount++;
               }
            }
            else
            {
               // Create a rectangle for this range bar
               if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, lastTime, lastPrice, currentTime, currentPrice))
               {
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                  ObjectSetInteger(0, objName, OBJPROP_FILL, true);
                  ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, BarWidth);
                  ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  
                  // Only log progress periodically
                  if(barCount % 100 == 0)
                  {
                     Print("Created range bar #", barCount, 
                          " at ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES),
                          " price: ", DoubleToString(currentPrice, _Digits));
                  }
                  
                  // Update for next bar
                  lastPrice = currentPrice;
                  lastTime = currentTime;
                  barCount++;
               }
            }
            
            // Add text label if requested
            if(ShowValues)
            {
               string labelName = objPrefix + "Label_" + IntegerToString(barCount-1);
               string labelText = DoubleToString(lastPrice, _Digits) + " → " + DoubleToString(currentPrice, _Digits);
               
               ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, (lastPrice + currentPrice) / 2);
               ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
               ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
               ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
               ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            }
         }
      }
      
      // Update count of processed bars
      total_processed += rates_count;
      
      // Give MT5 a chance to process events
      Sleep(10);
      ChartRedraw(0);
   }
   
   // Report final results
   Print("Processed ", total_processed, " price bars");
   Print("Created ", barCount, " range bars");
   ChartRedraw(0);
}
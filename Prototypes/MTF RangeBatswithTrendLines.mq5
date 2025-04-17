//+------------------------------------------------------------------+
//|                      MTF_RangeBarWithTrendLines.mq5              |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website/Email"
#property version   "1.00"
#property script_show_inputs
#property strict

// Input parameters for range bars
input int    RangeSize = 100;           // Range size in points
input color  UpColor = clrLimeGreen;    // Color for up bars
input color  DownColor = clrRed;        // Color for down bars
input int    BarWidth = 2;              // Width of bars in pixels
input bool   ShowValues = false;        // Show price values on bars
input bool   DrawLines = true;          // Draw lines instead of rectangles
input int    LineWidth = 3;             // Width of lines (if using lines)
input int    LineOffset = 5;            // Offset in points for line placement

// MTF Parameters
input string MTFSymbol = "";            // Symbol to use (empty = current)

// Define enum for timeframe selection
enum ENUM_MTF_TIMEFRAMES
{
   CURRENT_TF = 0,   // Current Timeframe
   USE_M1     = 1,   // M1
   USE_M5     = 2,   // M5
   USE_M15    = 3,   // M15
   USE_M30    = 4,   // M30
   USE_H1     = 5,   // H1
   USE_H4     = 6,   // H4
   USE_D1     = 7,   // D1
   USE_W1     = 8,   // W1
   USE_MN1    = 9,   // MN1
   USE_ALL    = 10,  // All Timeframes
};

input ENUM_MTF_TIMEFRAMES TimeFrameSelection = CURRENT_TF; // Timeframe to use

//+------------------------------------------------------------------+
//| Process one timeframe                                            |
//+------------------------------------------------------------------+
void ProcessTimeframe(string symbol, ENUM_TIMEFRAMES timeframe)
{
   // Prefix for object names
   string objPrefix = "MTF_RangeBar_" + symbol + "_" + EnumToString(timeframe) + "_";
   
   // Clear any existing objects with our prefix
   ObjectsDeleteAll(0, objPrefix);
   
   // Get MAXIMUM available history
   datetime start_time = D'1970.01.01 00:00';  // Very old date to get all history
   datetime end_time = TimeCurrent();
   
   // First try to force load the full history
   Print("Forcing history load from oldest available data...");
   Print("Symbol: ", symbol, ", Timeframe: ", EnumToString(timeframe));
   int available_bars = Bars(symbol, timeframe, start_time, end_time);
   
   Print("Available bars: ", available_bars);
   
   if(available_bars <= 0)
   {
      Print("No historical data available for ", symbol, " on ", EnumToString(timeframe), " timeframe");
      return;
   }
   
   // Process in chunks if necessary for very large datasets
   const int CHUNK_SIZE = 500000; // Process data in chunks to avoid memory errors
   int chunks_needed = (int)MathCeil((double)available_bars / CHUNK_SIZE);
   
   Print("Processing data in ", chunks_needed, " chunks");
   Print("Range size: ", RangeSize, " points = ", RangeSize * SymbolInfoDouble(symbol, SYMBOL_POINT), " in price");
   Print("Drawing mode: ", (DrawLines ? "Lines" : "Rectangles"));
   
   int total_processed = 0;
   int barCount = 0;
   double lastPrice = 0;
   datetime lastTime = 0;
   bool first_bar = true;
   
   // Get symbol point value
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculate the price offset amount
   double offsetAmount = LineOffset * point;
   
   // Process all chunks
   for(int chunk = 0; chunk < chunks_needed; chunk++)
   {
      // Calculate range for this chunk
      int start_pos = chunk * CHUNK_SIZE;
      int bars_to_copy = MathMin(CHUNK_SIZE, available_bars - total_processed);
      
      Print("Processing chunk ", chunk+1, "/", chunks_needed, " - bars ", start_pos, " to ", start_pos + bars_to_copy - 1);
      
      // Get data for this chunk
      MqlRates rates[];
      if(CopyRates(symbol, timeframe, start_pos, bars_to_copy, rates) <= 0)
      {
         Print("Failed to copy data for chunk ", chunk+1);
         
         // Try a smaller chunk as fallback
         bars_to_copy = MathMax(1000, bars_to_copy / 10);
         if(CopyRates(symbol, timeframe, start_pos, bars_to_copy, rates) <= 0)
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
         double rangeAmount = RangeSize * point;
         
         if(priceDiff >= rangeAmount)
         {
            // Create range bar
            string objName = objPrefix + IntegerToString(barCount);
            bool isUp = currentPrice > lastPrice;
            color barColor = isUp ? UpColor : DownColor;
            
            if(DrawLines)
            {
               if(isUp)
               {
                  // Bullish trend - draw line below the price move
                  // Use the lowest price points
                  double lowPoint1 = MathMin(lastPrice, currentPrice) - offsetAmount;
                  double lowPoint2 = lowPoint1;
                  
                  if(ObjectCreate(0, objName, OBJ_TREND, 0, lastTime, lowPoint1, currentTime, lowPoint2))
                  {
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
                     ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  }
               }
               else
               {
                  // Bearish trend - draw line above the price move
                  // Use the highest price points
                  double highPoint1 = MathMax(lastPrice, currentPrice) + offsetAmount;
                  double highPoint2 = highPoint1;
                  
                  if(ObjectCreate(0, objName, OBJ_TREND, 0, lastTime, highPoint1, currentTime, highPoint2))
                  {
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
                     ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  }
               }
               
               // Only log progress periodically
               if(barCount % 100 == 0)
               {
                  Print("Created trend line #", barCount, 
                       " at ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES),
                       " price: ", DoubleToString(currentPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
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
                          " price: ", DoubleToString(currentPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
                  }
               }
            }
            
            // Add text label if requested
            if(ShowValues)
            {
               string labelName = objPrefix + "Label_" + IntegerToString(barCount);
               string labelText = DoubleToString(lastPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + 
                                " → " + 
                                DoubleToString(currentPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
               
               ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, (lastPrice + currentPrice) / 2);
               ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
               ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
               ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
               ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            }
            
            // Update for next bar
            lastPrice = currentPrice;
            lastTime = currentTime;
            barCount++;
         }
      }
      
      // Update count of processed bars
      total_processed += rates_count;
      
      // Give MT5 a chance to process events
      Sleep(10);
      ChartRedraw(0);
   }
   
   // Report final results
   Print("Processed ", total_processed, " price bars from ", symbol, " ", EnumToString(timeframe));
   Print("Created ", barCount, " range bars");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Determine which symbol to use
   string symbol = _Symbol;
   if(MTFSymbol != "")
      symbol = MTFSymbol;
   
   Print("Starting MTF Range Bar processing for symbol: ", symbol);
   Print("=========================================");
   
   // Process based on timeframe selection
   switch(TimeFrameSelection)
   {
      case CURRENT_TF:
         Print("Processing current timeframe: ", EnumToString(_Period));
         ProcessTimeframe(symbol, _Period);
         break;
         
      case USE_M1:
         Print("Processing M1 timeframe...");
         ProcessTimeframe(symbol, PERIOD_M1);
         break;
         
      case USE_M5:
         Print("Processing M5 timeframe...");
         ProcessTimeframe(symbol, PERIOD_M5);
         break;
         
      case USE_M15:
         Print("Processing M15 timeframe...");
         ProcessTimeframe(symbol, PERIOD_M15);
         break;
         
      case USE_M30:
         Print("Processing M30 timeframe...");
         ProcessTimeframe(symbol, PERIOD_M30);
         break;
         
      case USE_H1:
         Print("Processing H1 timeframe...");
         ProcessTimeframe(symbol, PERIOD_H1);
         break;
         
      case USE_H4:
         Print("Processing H4 timeframe...");
         ProcessTimeframe(symbol, PERIOD_H4);
         break;
         
      case USE_D1:
         Print("Processing D1 timeframe...");
         ProcessTimeframe(symbol, PERIOD_D1);
         break;
         
      case USE_W1:
         Print("Processing W1 timeframe...");
         ProcessTimeframe(symbol, PERIOD_W1);
         break;
         
      case USE_MN1:
         Print("Processing MN1 timeframe...");
         ProcessTimeframe(symbol, PERIOD_MN1);
         break;
         
      case USE_ALL:
         Print("Processing ALL timeframes...");
         ProcessTimeframe(symbol, PERIOD_M1);
         ProcessTimeframe(symbol, PERIOD_M5);
         ProcessTimeframe(symbol, PERIOD_M15);
         ProcessTimeframe(symbol, PERIOD_M30);
         ProcessTimeframe(symbol, PERIOD_H1);
         ProcessTimeframe(symbol, PERIOD_H4);
         ProcessTimeframe(symbol, PERIOD_D1);
         ProcessTimeframe(symbol, PERIOD_W1);
         ProcessTimeframe(symbol, PERIOD_MN1);
         break;
   }
   
   Print("=========================================");
   Print("MTF Range Bar processing completed!");
}
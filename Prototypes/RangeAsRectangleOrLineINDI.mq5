//+------------------------------------------------------------------+
//|                        RangeBarWithLinesIndicator.mq5            |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website/Email"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// Input parameters
input int    RangeSize = 100;           // Range size in points
input color  UpColor = clrLimeGreen;    // Color for up bars
input color  DownColor = clrRed;        // Color for down bars
input int    BarWidth = 2;              // Width of bars in pixels
input bool   ShowValues = false;        // Show price values on bars
input bool   DrawLines = false;         // Draw lines instead of rectangles
input int    LineWidth = 3;             // Width of lines (if using lines)
input bool   AutoRefresh = false;       // Automatically refresh on new bar

// Global variables
string objPrefix = "RangeBar_Ind_";     // Prefix for object names
int barCount = 0;                       // Count of range bars created
double lastPrice = 0;                   // Last price point
datetime lastTime = 0;                  // Last time point
bool isInitialized = false;             // Flag to track if we've done initial processing
datetime lastBarTime = 0;               // To track new bars for auto refresh

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "Range Bars (" + IntegerToString(RangeSize) + ")");
   
   // Clear any existing objects with our prefix
   ObjectsDeleteAll(0, objPrefix);
   
   // Reset variables
   barCount = 0;
   lastPrice = 0;
   lastTime = 0;
   isInitialized = false;
   
   // Initial processing will be done in OnCalculate
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clear all objects created by this indicator
   ObjectsDeleteAll(0, objPrefix);
   Print("Range Bar indicator removed, all objects cleared");
}

//+------------------------------------------------------------------+
//| Process historical data and create range bars                    |
//+------------------------------------------------------------------+
void ProcessHistory()
{
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
            CreateRangeBar(lastTime, lastPrice, currentTime, currentPrice);
         }
      }
      
      // Update count of processed bars
      total_processed += rates_count;
      
      // Update the last bar time for auto refresh feature
      if(rates_count > 0)
         lastBarTime = rates[rates_count-1].time;
      
      // Give MT5 a chance to process events
      Sleep(10);
      ChartRedraw(0);
   }
   
   // Report final results
   Print("Processed ", total_processed, " price bars");
   Print("Created ", barCount, " range bars");
   ChartRedraw(0);
   
   // Mark initialization as complete
   isInitialized = true;
}

//+------------------------------------------------------------------+
//| Create a range bar object                                        |
//+------------------------------------------------------------------+
void CreateRangeBar(datetime startTime, double startPrice, datetime endTime, double endPrice)
{
   string objName = objPrefix + IntegerToString(barCount);
   bool isUp = endPrice > startPrice;
   color barColor = isUp ? UpColor : DownColor;
   
   if(DrawLines)
   {
      // Draw a trend line
      if(ObjectCreate(0, objName, OBJ_TREND, 0, startTime, startPrice, endTime, endPrice))
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
                  " at ", TimeToString(endTime, TIME_DATE|TIME_MINUTES),
                  " price: ", DoubleToString(endPrice, _Digits));
         }
      }
   }
   else
   {
      // Create a rectangle for this range bar
      if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, startPrice, endTime, endPrice))
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
                  " at ", TimeToString(endTime, TIME_DATE|TIME_MINUTES),
                  " price: ", DoubleToString(endPrice, _Digits));
         }
      }
   }
   
   // Add text label if requested
   if(ShowValues)
   {
      string labelName = objPrefix + "Label_" + IntegerToString(barCount);
      string labelText = DoubleToString(startPrice, _Digits) + " → " + DoubleToString(endPrice, _Digits);
      
      ObjectCreate(0, labelName, OBJ_TEXT, 0, endTime, (startPrice + endPrice) / 2);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
   
   // Update for next bar
   lastPrice = endPrice;
   lastTime = endTime;
   barCount++;
}

//+------------------------------------------------------------------+
//| Process new price data                                           |
//+------------------------------------------------------------------+
void ProcessNewData()
{
   // Get the latest bar
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 2, rates) <= 0)
      return;
   
   // Check if we have a new bar
   if(rates[0].time <= lastBarTime)
      return;
   
   // Update lastBarTime
   lastBarTime = rates[0].time;
   
   // Get current price
   double currentPrice = rates[0].close;
   datetime currentTime = rates[0].time;
   
   // If price moved enough, create a range bar
   double priceDiff = MathAbs(currentPrice - lastPrice);
   double rangeAmount = RangeSize * _Point;
   
   if(priceDiff >= rangeAmount)
   {
      CreateRangeBar(lastTime, lastPrice, currentTime, currentPrice);
      ChartRedraw(0);
   }
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
   // Do the full processing only once
   if(!isInitialized)
   {
      ProcessHistory();
   }
   else if(AutoRefresh)
   {
      // Process only new data if auto refresh is enabled
      ProcessNewData();
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
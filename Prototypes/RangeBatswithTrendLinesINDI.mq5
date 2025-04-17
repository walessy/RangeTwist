//+------------------------------------------------------------------+
//|                      RangeBarWithTrendLines_Indicator.mq5        |
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
input bool   DrawLines = true;          // Draw lines instead of rectangles
input int    LineWidth = 3;             // Width of lines (if using lines)
input int    LineOffset = 5;            // Offset in points for line placement
input bool   LimitHistory = false;      // Limit the historical calculation
input int    MaxBarsToProcess = 10000;  // Maximum number of bars to process if limited

// Global variables
string g_objPrefix;
int g_barCount;
double g_lastPrice;
datetime g_lastTime;
bool g_first_bar;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize prefix for object names
   g_objPrefix = "RangeBar_Ind_" + IntegerToString(ChartID()) + "_";
   
   // Initialize counters and flags
   g_barCount = 0;
   g_lastPrice = 0;
   g_lastTime = 0;
   g_first_bar = true;
   
   // Set indicator short name
   string shortName = "Range Bar (" + IntegerToString(RangeSize) + " pts)";
   IndicatorSetString(INDICATOR_SHORTNAME, shortName);
   
   // Initial removal of previous objects
   ObjectsDeleteAll(0, g_objPrefix);
   
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
   // First-time initialization or full recalculation required
   if(prev_calculated == 0)
   {
      // Clear any existing objects with our prefix
      ObjectsDeleteAll(0, g_objPrefix);
      
      g_barCount = 0;
      g_first_bar = true;
      
      // Define the starting point
      int start_idx;
      
      if(LimitHistory)
         start_idx = MathMax(0, rates_total - MaxBarsToProcess);
      else
         start_idx = 0;
         
      Print("Range Bar Indicator: Processing from bar ", start_idx, " to ", rates_total-1);
      Print("Range size: ", RangeSize, " points = ", RangeSize * _Point, " in price");
      
      // Calculate the price offset amount for trend lines
      double offsetAmount = LineOffset * _Point;
      
      // Process all historical data
      for(int i = start_idx; i < rates_total; i++)
      {
         // For the very first bar we process, just record the price
         if(g_first_bar)
         {
            g_lastPrice = close[i];
            g_lastTime = time[i];
            g_first_bar = false;
            continue;
         }
         
         double currentPrice = close[i];
         datetime currentTime = time[i];
         
         // If price moved enough, create a range bar
         double priceDiff = MathAbs(currentPrice - g_lastPrice);
         double rangeAmount = RangeSize * _Point;
         
         if(priceDiff >= rangeAmount)
         {
            // Create range bar
            string objName = g_objPrefix + IntegerToString(g_barCount);
            bool isUp = currentPrice > g_lastPrice;
            color barColor = isUp ? UpColor : DownColor;
            
            if(DrawLines)
            {
               if(isUp)
               {
                  // Bullish trend - draw line below the price move
                  double lowPoint1 = MathMin(g_lastPrice, currentPrice) - offsetAmount;
                  double lowPoint2 = lowPoint1;
                  
                  if(ObjectCreate(0, objName, OBJ_TREND, 0, g_lastTime, lowPoint1, currentTime, lowPoint2))
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
                  double highPoint1 = MathMax(g_lastPrice, currentPrice) + offsetAmount;
                  double highPoint2 = highPoint1;
                  
                  if(ObjectCreate(0, objName, OBJ_TREND, 0, g_lastTime, highPoint1, currentTime, highPoint2))
                  {
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
                     ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  }
               }
            }
            else
            {
               // Create a rectangle for this range bar
               if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, g_lastTime, g_lastPrice, currentTime, currentPrice))
               {
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                  ObjectSetInteger(0, objName, OBJPROP_FILL, true);
                  ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, BarWidth);
                  ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
               }
            }
            
            // Add text label if requested
            if(ShowValues)
            {
               string labelName = g_objPrefix + "Label_" + IntegerToString(g_barCount);
               string labelText = DoubleToString(g_lastPrice, _Digits) + " → " + DoubleToString(currentPrice, _Digits);
               
               ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, (g_lastPrice + currentPrice) / 2);
               ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
               ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
               ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
               ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            }
            
            // Update for next range bar
            g_lastPrice = currentPrice;
            g_lastTime = currentTime;
            g_barCount++;
         }
      }
      
      Print("Range Bar Indicator: Created ", g_barCount, " range bars");
   }
   else
   {
      // Only process new bars
      int start_pos = prev_calculated - 1;
      if(start_pos < 0) start_pos = 0;
      
      // Calculate the price offset amount for trend lines
      double offsetAmount = LineOffset * _Point;
      
      // Process only the new bars since last calculation
      for(int i = start_pos; i < rates_total; i++)
      {
         // If this is the first calculation after indicator restart
         if(g_first_bar)
         {
            g_lastPrice = close[i];
            g_lastTime = time[i];
            g_first_bar = false;
            continue;
         }
         
         double currentPrice = close[i];
         datetime currentTime = time[i];
         
         // If price moved enough, create a range bar
         double priceDiff = MathAbs(currentPrice - g_lastPrice);
         double rangeAmount = RangeSize * _Point;
         
         if(priceDiff >= rangeAmount)
         {
            // Create range bar
            string objName = g_objPrefix + IntegerToString(g_barCount);
            bool isUp = currentPrice > g_lastPrice;
            color barColor = isUp ? UpColor : DownColor;
            
            if(DrawLines)
            {
               if(isUp)
               {
                  // Bullish trend - draw line below the price move
                  double lowPoint1 = MathMin(g_lastPrice, currentPrice) - offsetAmount;
                  double lowPoint2 = lowPoint1;
                  
                  if(ObjectCreate(0, objName, OBJ_TREND, 0, g_lastTime, lowPoint1, currentTime, lowPoint2))
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
                  double highPoint1 = MathMax(g_lastPrice, currentPrice) + offsetAmount;
                  double highPoint2 = highPoint1;
                  
                  if(ObjectCreate(0, objName, OBJ_TREND, 0, g_lastTime, highPoint1, currentTime, highPoint2))
                  {
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
                     ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  }
               }
            }
            else
            {
               // Create a rectangle for this range bar
               if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, g_lastTime, g_lastPrice, currentTime, currentPrice))
               {
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
                  ObjectSetInteger(0, objName, OBJPROP_FILL, true);
                  ObjectSetInteger(0, objName, OBJPROP_BACK, false);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, BarWidth);
                  ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
               }
            }
            
            // Add text label if requested
            if(ShowValues)
            {
               string labelName = g_objPrefix + "Label_" + IntegerToString(g_barCount);
               string labelText = DoubleToString(g_lastPrice, _Digits) + " → " + DoubleToString(currentPrice, _Digits);
               
               ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, (g_lastPrice + currentPrice) / 2);
               ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
               ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
               ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
               ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            }
            
            // Update for next range bar
            g_lastPrice = currentPrice;
            g_lastTime = currentTime;
            g_barCount++;
         }
      }
   }
   
   // Force chart redraw
   ChartRedraw(0);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove all objects created by the indicator
   ObjectsDeleteAll(0, g_objPrefix);
   Print("Range Bar Indicator: Removed all objects");
}
//+------------------------------------------------------------------+
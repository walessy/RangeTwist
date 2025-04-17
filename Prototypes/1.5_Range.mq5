//+------------------------------------------------------------------+
//|                                              RangeBarsIndicator.mq5 |
//|                                             Copyright 2025          |
//|                                                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// Input parameters
input color    RangeLineColor = clrDarkGray;   // Range line color
input int      RangeLineStyle = STYLE_DOT;     // Range line style
input int      RangeLineWidth = 1;             // Range line width
input bool     ShowRangeLabels = true;         // Show range line labels
input int      LabelFontSize = 8;              // Label font size

// Slider properties for interactive control
input int      InitialRangeValue = 10;         // Initial range size
input int      MinRangeValue = 5;              // Minimum range size
input int      MaxRangeValue = 50;             // Maximum range size

// Global variables
int currentRangeSize;       // Current range size selected by slider
datetime lastBarTime;      // Time of the last processed bar
bool chartInitialized = false;
string indicatorName;
int buttonID, sliderID, labelID;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set the initial range size
   currentRangeSize = InitialRangeValue;
   
   // Initialize the indicator name
   indicatorName = "RangeBarsIndicator_" + StringSubstr(Symbol(), 0, 6);
   
   // Create UI controls
   CreateControls();
   
   // Set a short timer to ensure the chart is ready
   EventSetTimer(1);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up by removing all created objects
   ObjectsDeleteAll(0, indicatorName);
   
   // Remove the event timer
   EventKillTimer();
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
   // Check if we need to recalculate
   if (rates_total <= 0) return(0);
   
   // If it's a new bar or range size changed, redraw the range lines
   if (lastBarTime != time[rates_total-1] || !chartInitialized)
   {
      lastBarTime = time[rates_total-1];
      DrawRangeLines(rates_total, high, low);
      chartInitialized = true;
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   // This ensures the chart is ready for drawing
   if (!chartInitialized)
   {
      int bars = Bars(Symbol(), Period());
      if (bars > 0)
      {
         double high[], low[];
         ArraySetAsSeries(high, true);
         ArraySetAsSeries(low, true);
         CopyHigh(Symbol(), Period(), 0, bars, high);
         CopyLow(Symbol(), Period(), 0, bars, low);
         
         DrawRangeLines(bars, high, low);
         chartInitialized = true;
      }
   }
   
   // We can kill the timer once initialization is complete
   if (chartInitialized)
      EventKillTimer();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle slider events
   if (id == CHARTEVENT_OBJECT_DRAG && sparam == indicatorName + "_Slider")
   {
      // Get the new slider value
      int newValue = (int)ObjectGetDouble(0, indicatorName + "_Slider", OBJPROP_PRICE);
      
      // Apply limits
      if (newValue < MinRangeValue) newValue = MinRangeValue;
      if (newValue > MaxRangeValue) newValue = MaxRangeValue;
      
      // Update the slider position
      ObjectSetDouble(0, indicatorName + "_Slider", OBJPROP_PRICE, newValue);
      
      // Update the display label
      ObjectSetString(0, indicatorName + "_Label", OBJPROP_TEXT, "Range Size: " + IntegerToString(newValue));
      
      // Only redraw if the value changed
      if (newValue != currentRangeSize)
      {
         currentRangeSize = newValue;
         
         // Trigger recalculation
         int bars = Bars(Symbol(), Period());
         if (bars > 0)
         {
            double high[], low[];
            ArraySetAsSeries(high, true);
            ArraySetAsSeries(low, true);
            CopyHigh(Symbol(), Period(), 0, bars, high);
            CopyLow(Symbol(), Period(), 0, bars, low);
            
            // Redraw the range lines
            DrawRangeLines(bars, high, low);
         }
      }
   }
   
   // Handle button click to reset the range size
   if (id == CHARTEVENT_OBJECT_CLICK && sparam == indicatorName + "_Button")
   {
      // Reset to initial value
      currentRangeSize = InitialRangeValue;
      
      // Update the slider position
      ObjectSetDouble(0, indicatorName + "_Slider", OBJPROP_PRICE, currentRangeSize);
      
      // Update the display label
      ObjectSetString(0, indicatorName + "_Label", OBJPROP_TEXT, "Range Size: " + IntegerToString(currentRangeSize));
      
      // Trigger recalculation
      int bars = Bars(Symbol(), Period());
      if (bars > 0)
      {
         double high[], low[];
         ArraySetAsSeries(high, true);
         ArraySetAsSeries(low, true);
         CopyHigh(Symbol(), Period(), 0, bars, high);
         CopyLow(Symbol(), Period(), 0, bars, low);
         
         // Redraw the range lines
         DrawRangeLines(bars, high, low);
      }
   }
}

//+------------------------------------------------------------------+
//| Create UI controls (slider, button, label)                       |
//+------------------------------------------------------------------+
void CreateControls()
{
   // Delete any existing controls with the same name
   ObjectDelete(0, indicatorName + "_Slider");
   ObjectDelete(0, indicatorName + "_Button");
   ObjectDelete(0, indicatorName + "_Label");
   
   // Create slider
   sliderID = ObjectCreate(0, indicatorName + "_Slider", OBJ_HLINE, 0, 0, currentRangeSize);
   if (sliderID)
   {
      ObjectSetInteger(0, indicatorName + "_Slider", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, indicatorName + "_Slider", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, indicatorName + "_Slider", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, indicatorName + "_Slider", OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, indicatorName + "_Slider", OBJPROP_SELECTED, true);
      ObjectSetInteger(0, indicatorName + "_Slider", OBJPROP_BACK, false);
      ObjectSetString(0, indicatorName + "_Slider", OBJPROP_TOOLTIP, "Drag to adjust range size");
   }
   
   // Create label
   labelID = ObjectCreate(0, indicatorName + "_Label", OBJ_LABEL, 0, 0, 0);
   if (labelID)
   {
      ObjectSetInteger(0, indicatorName + "_Label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, indicatorName + "_Label", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, indicatorName + "_Label", OBJPROP_YDISTANCE, 20);
      ObjectSetString(0, indicatorName + "_Label", OBJPROP_TEXT, "Range Size: " + IntegerToString(currentRangeSize));
      ObjectSetInteger(0, indicatorName + "_Label", OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, indicatorName + "_Label", OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, indicatorName + "_Label", OBJPROP_BACK, false);
   }
   
   // Create reset button
   buttonID = ObjectCreate(0, indicatorName + "_Button", OBJ_BUTTON, 0, 0, 0);
   if (buttonID)
   {
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_YDISTANCE, 50);
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_XSIZE, 100);
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_YSIZE, 20);
      ObjectSetString(0, indicatorName + "_Button", OBJPROP_TEXT, "Reset");
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_BGCOLOR, clrLightGray);
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, indicatorName + "_Button", OBJPROP_FONTSIZE, 10);
   }
}

//+------------------------------------------------------------------+
//| Draw range lines based on price action                           |
//+------------------------------------------------------------------+
void DrawRangeLines(const int bars_count, const double &high[], const double &low[])
{
   // Delete existing range lines
   for (int i = 0; i < 100; i++)  // Assuming max 100 range lines
   {
      ObjectDelete(0, indicatorName + "_RangeLine_" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "_RangeLabel_" + IntegerToString(i));
   }
   
   // Find min and max values
   double minValue = low[ArrayMinimum(low, 0, bars_count)];
   double maxValue = high[ArrayMaximum(high, 0, bars_count)];
   
   // Round min value down and max value up to nearest range size multiple
   minValue = MathFloor(minValue / currentRangeSize) * currentRangeSize;
   maxValue = MathCeil(maxValue / currentRangeSize) * currentRangeSize;
   
   // Calculate number of range bars
   int numRangeBars = (int)((maxValue - minValue) / currentRangeSize);
   
   // Draw range lines
   for (int i = 0; i <= numRangeBars; i++)
   {
      double lineValue = minValue + (i * currentRangeSize);
      
      // Create horizontal line for each range level
      string lineName = indicatorName + "_RangeLine_" + IntegerToString(i);
      if (ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, lineValue))
      {
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, RangeLineColor);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, RangeLineStyle);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, RangeLineWidth);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      }
      
      // Add labels if enabled
      if (ShowRangeLabels)
      {
         string labelName = indicatorName + "_RangeLabel_" + IntegerToString(i);
         if (ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), lineValue))
         {
            ObjectSetString(0, labelName, OBJPROP_TEXT, DoubleToString(lineValue, _Digits));
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, RangeLineColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LabelFontSize);
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
         }
      }
   }
   
   // Force chart redraw
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
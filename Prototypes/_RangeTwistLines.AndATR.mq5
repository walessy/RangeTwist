//+------------------------------------------------------------------+
//|                                          RangeTwistLines.mq5 |
//|                                       Copyright 2025, Amos   |
//|                                     http://amoswales@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.20"
#property description "Range Twist Lines with Fixed Points and ATR options"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2

// Fixed Points line
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed
#property indicator_width1  2
#property indicator_label1  "Range Line (Fixed)"

// ATR-based line
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrLawnGreen, clrOrangeRed, clrNONE
#property indicator_width2  2
#property indicator_label2  "Range Line (ATR)"
#property indicator_style2  STYLE_DOT

//--- input parameters
input int    RangeSize = 25;            // Range size in points
input double ATRMultiple = 1.0;         // ATR multiplier
input int    ATRPeriod = 14;            // ATR period
input bool   ShowATRLine = true;        // Show ATR line
input color  UpColor = clrLime;         // Color for up trend (Fixed)
input color  DownColor = clrRed;        // Color for down trend (Fixed)
input color  UpColorATR = clrLawnGreen; // Color for up trend (ATR)
input color  DownColorATR = clrOrangeRed; // Color for down trend (ATR)
input bool   IncludeCurrentCandle = true; // Include current (forming) candle in calculation

//--- indicator buffers
double FixedLineBuffer[];
double FixedColorBuffer[];
double ATRLineBuffer[];
double ATRColorBuffer[];
double ATRBuffer[];
double RangeBuffer[];

//--- global variables
double currentFixedLevel = 0;
int lastFixedRangeBarIndex = 0;
bool upTrendFixed = true;

double currentATRLevel = 0;
int lastATRRangeBarIndex = 0;
bool upTrendATR = true;

double point;
int atrHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Setup Fixed Points line buffers
   SetIndexBuffer(0, FixedLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, FixedColorBuffer, INDICATOR_COLOR_INDEX);
   
   // Setup ATR line buffers
   SetIndexBuffer(2, ATRLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ATRColorBuffer, INDICATOR_COLOR_INDEX);
   
   // Setup calculation buffers
   SetIndexBuffer(4, ATRBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, RangeBuffer, INDICATOR_CALCULATIONS);

   // Initialize with EMPTY_VALUE
   ArrayInitialize(FixedLineBuffer, EMPTY_VALUE);
   ArrayInitialize(ATRLineBuffer, EMPTY_VALUE);
   ArrayInitialize(ATRBuffer, 0);
   ArrayInitialize(RangeBuffer, RangeSize * point); // Default to fixed range
   
   // Set up Fixed Points line
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, UpColor);      // Index 0 = Up color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, DownColor);    // Index 1 = Down color
   PlotIndexSetString(0, PLOT_LABEL, "Range Line (Fixed)");
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   // Set up ATR line
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, UpColorATR);   // Index 0 = Up color
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, DownColorATR); // Index 1 = Down color
   PlotIndexSetString(1, PLOT_LABEL, "Range Line (ATR)");
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2);
   
   // Hide ATR line if not needed
   if(!ShowATRLine) {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   
   // Create ATR indicator handle
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(atrHandle == INVALID_HANDLE) {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }
   
   point = _Point;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
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
   // Check for insufficient data
   if(rates_total < 2) 
      return(0);
      
   // If we're using ATR, copy values to our buffer
   if(ShowATRLine) {
      int atr_copied = CopyBuffer(atrHandle, 0, 0, rates_total, ATRBuffer);
      if(atr_copied <= 0) {
         Print("Error copying ATR buffer: ", GetLastError(), " - Will use fixed range as fallback");
         // Continue execution, but use fixed points as fallback
         for(int i = 0; i < rates_total; i++) {
            RangeBuffer[i] = RangeSize * point;
         }
      } else {
         // Pre-calculate ranges for each bar
         for(int i = 0; i < rates_total; i++) {
            if(i < ATRPeriod || ATRBuffer[i] <= 0) {
               RangeBuffer[i] = RangeSize * point; // Fallback to fixed range
            } else {
               RangeBuffer[i] = ATRBuffer[i] * ATRMultiple;
            }
         }
      }
   }
   
   // If this is the first calculation or indicator has been reset
   if(prev_calculated <= 0) 
   {
      // Reset indicators and initialize
      ArrayInitialize(FixedLineBuffer, EMPTY_VALUE);
      ArrayInitialize(ATRLineBuffer, EMPTY_VALUE);
      
      // Initialize the first range values
      if(rates_total > 0)
      {
         // Fixed Points initialization
         currentFixedLevel = close[0];
         lastFixedRangeBarIndex = 0;
         upTrendFixed = true;
         FixedLineBuffer[0] = currentFixedLevel;
         FixedColorBuffer[0] = 0; // Start with up color
         
         // ATR initialization
         currentATRLevel = close[0];
         lastATRRangeBarIndex = 0;
         upTrendATR = true;
         ATRLineBuffer[0] = currentATRLevel;
         ATRColorBuffer[0] = 0; // Start with up color
      }
   }
   
   // Process each price bar from the last calculated one to the current
   int start = 0;
   
   if(!IncludeCurrentCandle){
      start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   }
   else{
      start = prev_calculated > 0 ? prev_calculated - 1 : 1;
   }
   
   for(int i = start; i < rates_total; i++)
   {
      // Calculate Fixed Points line
      CalculateFixedRange(i, high[i], low[i], rates_total);
      
      // Calculate ATR-based line
      // ATR color buffer values: 0=up, 1=down, 2=hidden
      CalculateATRRange(i, high[i], low[i], rates_total, RangeBuffer[i]);
      
      // Hide ATR line data if ShowATRLine is false
      if(!ShowATRLine) {
         ATRLineBuffer[i] = FixedLineBuffer[i]; // Match fixed line to avoid scale issues
         ATRColorBuffer[i] = 2; // Use a color index that doesn't exist (hidden)
      }
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Fixed Points based range line                          |
//+------------------------------------------------------------------+
void CalculateFixedRange(int bar_index, double high, double low, int rates_total)
{
   double range = RangeSize * point;
   
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(upTrendFixed)
   {
      if(high >= currentFixedLevel + range)
      {
         // Move the line up
         currentFixedLevel = currentFixedLevel + range;
         FixedLineBuffer[bar_index] = currentFixedLevel;
         FixedColorBuffer[bar_index] = 0; // Up color
         lastFixedRangeBarIndex = bar_index;
      }
      else if(low <= currentFixedLevel - range)
      {
         // Trend has reversed to down
         upTrendFixed = false;
         currentFixedLevel = currentFixedLevel - range;
         FixedLineBuffer[bar_index] = currentFixedLevel;
         FixedColorBuffer[bar_index] = 1; // Down color
         lastFixedRangeBarIndex = bar_index;
      }
      else
      {
         // No change in level, copy the last value
         FixedLineBuffer[bar_index] = currentFixedLevel;
         FixedColorBuffer[bar_index] = 0; // Up color
      }
   }
   else // downtrend
   {
      if(low <= currentFixedLevel - range)
      {
         // Move the line down
         currentFixedLevel = currentFixedLevel - range;
         FixedLineBuffer[bar_index] = currentFixedLevel;
         FixedColorBuffer[bar_index] = 1; // Down color
         lastFixedRangeBarIndex = bar_index;
      }
      else if(high >= currentFixedLevel + range)
      {
         // Trend has reversed to up
         upTrendFixed = true;
         currentFixedLevel = currentFixedLevel + range;
         FixedLineBuffer[bar_index] = currentFixedLevel;
         FixedColorBuffer[bar_index] = 0; // Up color
         lastFixedRangeBarIndex = bar_index;
      }
      else
      {
         // No change in level, copy the last value
         FixedLineBuffer[bar_index] = currentFixedLevel;
         FixedColorBuffer[bar_index] = 1; // Down color
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate ATR based range line                                   |
//+------------------------------------------------------------------+
void CalculateATRRange(int bar_index, double high, double low, int rates_total, double range)
{
   // Make sure we don't exceed buffer size
   if(bar_index >= rates_total) return;
   
   if(upTrendATR)
   {
      if(high >= currentATRLevel + range)
      {
         // Move the line up
         currentATRLevel = currentATRLevel + range;
         ATRLineBuffer[bar_index] = currentATRLevel;
         ATRColorBuffer[bar_index] = 0; // Up color
         lastATRRangeBarIndex = bar_index;
      }
      else if(low <= currentATRLevel - range)
      {
         // Trend has reversed to down
         upTrendATR = false;
         currentATRLevel = currentATRLevel - range;
         ATRLineBuffer[bar_index] = currentATRLevel;
         ATRColorBuffer[bar_index] = 1; // Down color
         lastATRRangeBarIndex = bar_index;
      }
      else
      {
         // No change in level, copy the last value
         ATRLineBuffer[bar_index] = currentATRLevel;
         ATRColorBuffer[bar_index] = 0; // Up color
      }
   }
   else // downtrend
   {
      if(low <= currentATRLevel - range)
      {
         // Move the line down
         currentATRLevel = currentATRLevel - range;
         ATRLineBuffer[bar_index] = currentATRLevel;
         ATRColorBuffer[bar_index] = 1; // Down color
         lastATRRangeBarIndex = bar_index;
      }
      else if(high >= currentATRLevel + range)
      {
         // Trend has reversed to up
         upTrendATR = true;
         currentATRLevel = currentATRLevel + range;
         ATRLineBuffer[bar_index] = currentATRLevel;
         ATRColorBuffer[bar_index] = 0; // Up color
         lastATRRangeBarIndex = bar_index;
      }
      else
      {
         // No change in level, copy the last value
         ATRLineBuffer[bar_index] = currentATRLevel;
         ATRColorBuffer[bar_index] = 1; // Down color
      }
   }
}
//+------------------------------------------------------------------+
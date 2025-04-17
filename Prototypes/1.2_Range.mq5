//+------------------------------------------------------------------+
//|                                             RangeDifference.mq5 |
//|                        Copyright 2025, Your Name                 |
//|                                             https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://www.example.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- plot RangeLine
#property indicator_label1  "RangeLine"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- input parameters
input int      RangePoints = 25;  // Range in points
input int      LineShift   = 5;   // Line position shift (bars back)
input color    LineColor   = clrMediumSeaGreen;  // Line color

//--- indicator buffers
double         RangeLineBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, RangeLineBuffer, INDICATOR_DATA);
   
   //--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   //--- set line properties
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, LineColor);
   
   //--- set indicator name
   string short_name = "Range Difference (" + IntegerToString(RangePoints) + " points)";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   
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
   //--- check for available bars
   if(rates_total < LineShift + 1)
      return(0);
      
   //--- Calculate starting position
   int start;
   if(prev_calculated == 0)
      start = LineShift;
   else
      start = prev_calculated - 1;
      
   //--- Main loop
   for(int i = start; i < rates_total; i++)
   {
      //--- Get point value for the current symbol
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      //--- Calculate the range in price
      double rangeValue = RangePoints * point;
      
      //--- Draw the range line based on the high price
      RangeLineBuffer[i] = high[i - LineShift] + rangeValue;
   }
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
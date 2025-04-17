//+------------------------------------------------------------------+
//|                            MarketStructureEntry.mq5               |
//|                         Copyright 2025, MetaQuotes Ltd.           |
//|                     Market Structure Entry Level Indicator        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   5

// Zigzag lines
#property indicator_label1  "ZigZag"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  Gray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

// Trend change arrows
#property indicator_label2  "Up Trend"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  Blue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "Down Trend"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  Red
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

// Entry level horizontal lines
#property indicator_label4  "Long Entry Level"
#property indicator_type4   DRAW_LINE
#property indicator_color4  Lime
#property indicator_style4  STYLE_DASH
#property indicator_width4  2

#property indicator_label5  "Short Entry Level"
#property indicator_type5   DRAW_LINE
#property indicator_color5  Magenta
#property indicator_style5  STYLE_DASH
#property indicator_width5  2

// Input parameters
input int      InpDepth       = 12;     // Depth (minimum 2)
input int      InpDeviation   = 5;      // Deviation (minimum 1)
input int      InpBackstep    = 3;      // Backstep (minimum 1)
input bool     InpShowZigzag  = true;   // Show ZigZag lines
input bool     InpUseHigherTF = true;   // Use higher timeframe for trend confirmation
input ENUM_TIMEFRAMES InpHigherTimeframe = PERIOD_H1; // Higher timeframe
input int      InpLineLength  = 50;     // Entry level line length (bars)

// Buffers
double ZigzagBuffer[];        // Main zigzag buffer for line drawing
double HighsBuffer[];         // Highs points buffer
double LowsBuffer[];          // Lows points buffer
double UpArrowBuffer[];       // Trend up arrows
double DownArrowBuffer[];     // Trend down arrows
double LongEntryBuffer[];     // Long entry level lines
double ShortEntryBuffer[];    // Short entry level lines

// For ZigZag calculation
int ExtZigzagHandle;

// Variables for market structure tracking
datetime prev_time[];
int      last_high_pos = -1; 
int      last_low_pos = -1;
double   last_high_price = 0;
double   last_low_price = 0;
double   prev_high_price = 0;
double   prev_low_price = 0;
bool     uptrend = false;     // Current trend direction
bool     downtrend = false;

// Variables for higher timeframe trend analysis
bool higher_tf_uptrend = false;
bool higher_tf_downtrend = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Creating ZigZag indicator handle
   ExtZigzagHandle = iCustom(Symbol(), Period(), "Examples\\ZigZag", 
                              InpDepth, InpDeviation, InpBackstep);
   if(ExtZigzagHandle == INVALID_HANDLE)
   {
      Print("Failed to create handle of the ZigZag indicator");
      return(INIT_FAILED);
   }
   
   // Configuring buffers
   SetIndexBuffer(0, ZigzagBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighsBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, LowsBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, UpArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, DownArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, LongEntryBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, ShortEntryBuffer, INDICATOR_DATA);
   
   // Setting buffer series
   ArraySetAsSeries(ZigzagBuffer, true);
   ArraySetAsSeries(HighsBuffer, true);
   ArraySetAsSeries(LowsBuffer, true);
   ArraySetAsSeries(UpArrowBuffer, true);
   ArraySetAsSeries(DownArrowBuffer, true);
   ArraySetAsSeries(LongEntryBuffer, true);
   ArraySetAsSeries(ShortEntryBuffer, true);
   
   // Setting plot properties
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, InpShowZigzag ? DRAW_SECTION : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   PlotIndexSetInteger(2, PLOT_ARROW, 234);
   
   // Set empty value for indicator buffers
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ExtZigzagHandle != INVALID_HANDLE)
      IndicatorRelease(ExtZigzagHandle);
}

//+------------------------------------------------------------------+
//| Check Higher Timeframe Trend                                     |
//+------------------------------------------------------------------+
void CheckHigherTimeframeTrend()
{
   if(!InpUseHigherTF)
   {
      higher_tf_uptrend = true;   // Default to no restriction if not using higher TF
      higher_tf_downtrend = true;
      return;
   }
   
   MqlRates htf_rates[];
   ArraySetAsSeries(htf_rates, true);
   
   int copied = CopyRates(Symbol(), InpHigherTimeframe, 0, 10, htf_rates);
   if(copied < 10)
      return;
      
   // Simple moving average crossover for trend detection
   double ma_fast = 0, ma_slow = 0;
   
   // Calculate 5-period MA
   for(int i = 0; i < 5; i++)
      ma_fast += htf_rates[i].close;
   ma_fast /= 5;
   
   // Calculate 10-period MA
   for(int i = 0; i < 10; i++)
      ma_slow += htf_rates[i].close;
   ma_slow /= 10;
   
   higher_tf_uptrend = ma_fast > ma_slow;
   higher_tf_downtrend = ma_fast < ma_slow;
}

//+------------------------------------------------------------------+
//| CreateEntryLevel - Creates horizontal entry level line           |
//+------------------------------------------------------------------+
void CreateEntryLevel(int position, double price, bool is_long, const double &price_array[])
{
   // Start the entry level line at the current bar
   if(is_long)
   {
      // Draw long entry level
      for(int i = position; i >= MathMax(0, position - InpLineLength); i--)
      {
         LongEntryBuffer[i] = price;
      }
   }
   else
   {
      // Draw short entry level
      for(int i = position; i >= MathMax(0, position - InpLineLength); i--)
      {
         ShortEntryBuffer[i] = price;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Market Structure and Entry Opportunities                  |
//+------------------------------------------------------------------+
void DetectMarketStructure(int rates_total, const double &high_array[], const double &low_array[])
{
   // Find ZigZag extreme points
   int prev_high_pos = -1, prev_low_pos = -1;
   
   // Scan recent bars for pivot points
   for(int i = 0; i < rates_total-InpDepth; i++)
   {
      if(HighsBuffer[i] != 0)
      {
         // Found a high point
         if(last_high_pos >= 0)
         {
            prev_high_pos = last_high_pos;
            prev_high_price = last_high_price;
         }
         
         last_high_pos = i;
         last_high_price = HighsBuffer[i];
      }
      
      if(LowsBuffer[i] != 0)
      {
         // Found a low point
         if(last_low_pos >= 0)
         {
            prev_low_pos = last_low_pos;
            prev_low_price = last_low_price;
         }
         
         last_low_pos = i;
         last_low_price = LowsBuffer[i];
      }
      
      // Detect trend change (Higher High, Higher Low pattern)
      if(last_high_pos >= 0 && prev_high_pos >= 0 && 
         last_low_pos >= 0 && prev_low_pos >= 0)
      {
         // Check if we have a higher high and higher low (uptrend)
         if(last_high_price > prev_high_price && last_low_price > prev_low_price)
         {
            if(!uptrend) // New uptrend identified
            {
               uptrend = true;
               downtrend = false;
               UpArrowBuffer[last_high_pos] = low_array[last_high_pos];
               
               // Calculate entry level - this is the key part for your horizontal level
               double entry_level = last_low_price + (last_high_price - last_low_price) * 0.5; // Mid-point of the leg
               
               // Check higher timeframe trend confluence
               if(!InpUseHigherTF || higher_tf_uptrend)
               {
                  // Create horizontal entry level line
                  CreateEntryLevel(last_high_pos, entry_level, true, high_array);
               }
            }
         }
         
         // Check if we have a lower low and lower high (downtrend)
         if(last_high_price < prev_high_price && last_low_price < prev_low_price)
         {
            if(!downtrend) // New downtrend identified
            {
               uptrend = false;
               downtrend = true;
               DownArrowBuffer[last_low_pos] = high_array[last_low_pos];
               
               // Calculate entry level - this is the key part for your horizontal level
               double entry_level = last_high_price - (last_high_price - last_low_price) * 0.5; // Mid-point of the leg
               
               // Check higher timeframe trend confluence
               if(!InpUseHigherTF || higher_tf_downtrend)
               {
                  // Create horizontal entry level line
                  CreateEntryLevel(last_low_pos, entry_level, false, high_array);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
   if(rates_total < InpDepth)
      return(0);
      
   // Set arrays as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   // Check higher timeframe trend periodically
   static datetime last_htf_check = 0;
   if(time[0] > last_htf_check + PeriodSeconds(Period()) * 10)
   {
      CheckHigherTimeframeTrend();
      last_htf_check = time[0];
   }
   
   // Copy ZigZag indicator values
   int copied = CopyBuffer(ExtZigzagHandle, 0, 0, rates_total, ZigzagBuffer);
   if(copied <= 0) return(0);
   
   // Identify peaks and troughs in ZigZag
   for(int i = 0; i < rates_total; i++)
   {
      HighsBuffer[i] = 0.0;
      LowsBuffer[i] = 0.0;
      
      // If this is a ZigZag point, determine if it's a peak or trough
      if(ZigzagBuffer[i] != 0.0)
      {
         if(ZigzagBuffer[i] == high[i])
            HighsBuffer[i] = high[i];
         else if(ZigzagBuffer[i] == low[i])
            LowsBuffer[i] = low[i];
      }
   }
   
   // Detect market structure and create entry levels
   DetectMarketStructure(rates_total, high, low);
   
   return(rates_total);
}
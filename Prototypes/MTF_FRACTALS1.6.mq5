//+------------------------------------------------------------------+
//|                                              MTF_Fractals.mq5 |
//|                                       Copyright 2025, Your Name |
//|                                            https://www.your-website.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025, Your Name"
#property link      "https://www.your-website.com"
#property version   "1.00"
#property description "Multi-Timeframe Fractals Indicator with Confluence Bars, Triangles and Bands for MT5"
#property indicator_chart_window
#property indicator_buffers 18  // 4 for fractals, 8 for candles, 2 for triangles, 4 for bands
#property indicator_plots   12   // 4 for fractals, 2 for candles, 2 for triangles, 4 for bands

// Plot properties for up fractal
#property indicator_label1  "Up Fractal Current TF"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

// Plot properties for down fractal
#property indicator_label2  "Down Fractal Current TF"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Plot properties for MTF up fractal
#property indicator_label3  "Up Fractal Higher TF"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrAqua
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

// Plot properties for MTF down fractal
#property indicator_label4  "Down Fractal Higher TF"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrMagenta
#property indicator_style4  STYLE_SOLID
#property indicator_width4  3

// Plot properties for bullish confluence
#property indicator_label5  "Bullish Confluence"
#property indicator_type5   DRAW_CANDLES
#property indicator_color5  clrYellow
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

// Plot properties for bearish confluence
#property indicator_label6  "Bearish Confluence"
#property indicator_type6   DRAW_CANDLES
#property indicator_color6  clrPurple
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2

// Plot properties for bullish confluence triangle
#property indicator_label7  "Bullish Confluence Triangle"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrLimeGreen
#property indicator_style7  STYLE_SOLID
#property indicator_width7  20

// Plot properties for bearish confluence triangle
#property indicator_label8  "Bearish Confluence Triangle"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrCrimson
#property indicator_style8  STYLE_SOLID
#property indicator_width8  20

// Plot properties for bullish band upper line
#property indicator_label9  "Bullish Band Upper"
#property indicator_type9   DRAW_LINE
#property indicator_color9  C'255,255,180' // Lighter yellow
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

// Plot properties for bullish band lower line
#property indicator_label10  "Bullish Band Lower"
#property indicator_type10   DRAW_LINE
#property indicator_color10  C'255,255,180' // Lighter yellow
#property indicator_style10  STYLE_SOLID
#property indicator_width10  1

// Plot properties for bearish band upper line
#property indicator_label11  "Bearish Band Upper"
#property indicator_type11   DRAW_LINE
#property indicator_color11  C'220,180,220' // Lighter purple
#property indicator_style11  STYLE_SOLID
#property indicator_width11  1

// Plot properties for bearish band lower line
#property indicator_label12  "Bearish Band Lower"
#property indicator_type12   DRAW_LINE
#property indicator_color12  C'220,180,220' // Lighter purple
#property indicator_style12  STYLE_SOLID
#property indicator_width12  1

// Input parameters
input ENUM_TIMEFRAMES Higher_Timeframe = PERIOD_H1; // Higher timeframe
input int Fractal_Lookback = 2;                     // Fractal lookback period
input bool Show_Current_TF = false;                 // Show current timeframe fractals
input bool Show_MTF_Arrows = false;                 // Show higher timeframe fractal arrows
input bool Highlight_Confluence_Bars = true;        // Highlight bars with fractal confluence
input bool Show_Confluence_Triangles = true;        // Show triangles at confluence points
input bool Show_Confluence_Bands = true;            // Show bands extending from confluence points
input int Triangle_Size = 20;                       // Size of confluence triangles
input int Triangle_Distance = 60;                   // Distance of triangles from price (in Points)
input color Bullish_Candle_Color = clrYellow;       // Bullish confluence candle color
input color Bearish_Candle_Color = clrPurple;       // Bearish confluence candle color
input color Bullish_Triangle_Color = clrLimeGreen;  // Bullish confluence triangle color
input color Bearish_Triangle_Color = clrCrimson;    // Bearish confluence triangle color
input color Bullish_Band_Color = C'255,255,180';    // Bullish band color (lighter yellow)
input color Bearish_Band_Color = C'220,180,220';    // Bearish band color (lighter purple)
input int Band_Opacity = 30;                        // Band opacity (0-100)

// Indicator buffers
double UpFractalBuffer[];         // Current TF up fractals
double DownFractalBuffer[];       // Current TF down fractals
double MTFUpFractalBuffer[];      // Higher TF up fractals
double MTFDownFractalBuffer[];    // Higher TF down fractals
// Buffers for confluence candles
double BullishOpen[];             // Bullish confluence open
double BullishHigh[];             // Bullish confluence high
double BullishLow[];              // Bullish confluence low
double BullishClose[];            // Bullish confluence close
double BearishOpen[];             // Bearish confluence open
double BearishHigh[];             // Bearish confluence high
double BearishLow[];              // Bearish confluence low
double BearishClose[];            // Bearish confluence close
// Buffers for confluence triangles
double BullishTriangleBuffer[];   // Bullish confluence triangle
double BearishTriangleBuffer[];   // Bearish confluence triangle
// Buffers for confluence bands
double BullishBandUpper[];        // Bullish band upper line
double BullishBandLower[];        // Bullish band lower line
double BearishBandUpper[];        // Bearish band upper line
double BearishBandLower[];        // Bearish band lower line

// Global variables
int handle_fractal_up;            // Handle for Up Fractal
int handle_fractal_down;          // Handle for Down Fractal
int handle_mtf_fractal_up;        // Handle for MTF Up Fractal
int handle_mtf_fractal_down;      // Handle for MTF Down Fractal

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Initializing MTF Fractals with Confluence Indicator and Bands");
   
   // Set up indicator buffers
   SetIndexBuffer(0, UpFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DownFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, MTFUpFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, MTFDownFractalBuffer, INDICATOR_DATA);
   
   // Set up bullish confluence candle buffers
   SetIndexBuffer(4, BullishOpen, INDICATOR_DATA);
   SetIndexBuffer(5, BullishHigh, INDICATOR_DATA);
   SetIndexBuffer(6, BullishLow, INDICATOR_DATA);
   SetIndexBuffer(7, BullishClose, INDICATOR_DATA);
   
   // Set up bearish confluence candle buffers
   SetIndexBuffer(8, BearishOpen, INDICATOR_DATA);
   SetIndexBuffer(9, BearishHigh, INDICATOR_DATA);
   SetIndexBuffer(10, BearishLow, INDICATOR_DATA);
   SetIndexBuffer(11, BearishClose, INDICATOR_DATA);
   
   // Set up confluence triangle buffers
   SetIndexBuffer(12, BullishTriangleBuffer, INDICATOR_DATA);
   SetIndexBuffer(13, BearishTriangleBuffer, INDICATOR_DATA);
   
   // Set up confluence band buffers
   SetIndexBuffer(14, BullishBandUpper, INDICATOR_DATA);
   SetIndexBuffer(15, BullishBandLower, INDICATOR_DATA);
   SetIndexBuffer(16, BearishBandUpper, INDICATOR_DATA);
   SetIndexBuffer(17, BearishBandLower, INDICATOR_DATA);
   
   // Debug info about buffer setup
   Print("Indicator buffers set up:");
   Print("  Buffers 0-3: Fractal arrows");
   Print("  Buffers 4-7: Bullish confluence candles");
   Print("  Buffers 8-11: Bearish confluence candles");
   Print("  Buffers 12-13: Confluence triangles");
   Print("  Buffers 14-17: Confluence bands");
   
   // Handle visibility based on user input - separate controls for each element
   // Current timeframe fractals
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, Show_Current_TF ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, Show_Current_TF ? DRAW_ARROW : DRAW_NONE);
   
   // Higher timeframe fractals
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, Show_MTF_Arrows ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, Show_MTF_Arrows ? DRAW_ARROW : DRAW_NONE);
   
   // Confluence candles/rectangles - controlled separately by Highlight_Confluence_Bars
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, Highlight_Confluence_Bars ? DRAW_CANDLES : DRAW_NONE);
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, Highlight_Confluence_Bars ? DRAW_CANDLES : DRAW_NONE);
   
   // Confluence triangles
   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, Show_Confluence_Triangles ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, Show_Confluence_Triangles ? DRAW_ARROW : DRAW_NONE);
   
   // Confluence bands 
   PlotIndexSetInteger(8, PLOT_DRAW_TYPE, Show_Confluence_Bands ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(9, PLOT_DRAW_TYPE, Show_Confluence_Bands ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(10, PLOT_DRAW_TYPE, Show_Confluence_Bands ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(11, PLOT_DRAW_TYPE, Show_Confluence_Bands ? DRAW_LINE : DRAW_NONE);
   
   // Set up visualization parameters for current TF fractals
   PlotIndexSetInteger(0, PLOT_ARROW, 241); // Up arrow (triangle)
   PlotIndexSetInteger(1, PLOT_ARROW, 242); // Down arrow (triangle)
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 10); // Position above the high
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 10); // Position below the low
   
   // Set up visualization parameters for MTF fractals
   PlotIndexSetInteger(2, PLOT_ARROW, 225); // Up MTF arrow (larger arrow)
   PlotIndexSetInteger(3, PLOT_ARROW, 226); // Down MTF arrow (larger arrow)
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, 20); // Position higher
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, 20); // Position lower

   // Set up visualization parameters for confluence triangles
   PlotIndexSetInteger(6, PLOT_ARROW, 242); // Down-pointing triangle for bullish confluence (opposite)
   PlotIndexSetInteger(7, PLOT_ARROW, 241); // Up-pointing triangle for bearish confluence (opposite)
   PlotIndexSetInteger(6, PLOT_ARROW_SHIFT, 0);  // Positioning handled in calculation
   PlotIndexSetInteger(7, PLOT_ARROW_SHIFT, 0);  // Positioning handled in calculation
   
   // Make current TF fractals hollow/transparent
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 3);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 3);
   
   // Set empty value for buffers
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // Set empty values for band lines
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(10, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(11, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // Apply user-defined colors
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, 0, Bullish_Candle_Color);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 0, Bearish_Candle_Color);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, 0, Bullish_Triangle_Color);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, 0, Bearish_Triangle_Color);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, 0, Bullish_Band_Color);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, 0, Bullish_Band_Color);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 0, Bearish_Band_Color);
   PlotIndexSetInteger(11, PLOT_LINE_COLOR, 0, Bearish_Band_Color);
   
   // Set width for the confluence triangles
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, Triangle_Size);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, Triangle_Size);
   
   // Create fractal indicator handles
   handle_fractal_up = iFractals(Symbol(), Period());
   handle_fractal_down = handle_fractal_up; // Same handle for both directions
   
   handle_mtf_fractal_up = iFractals(Symbol(), Higher_Timeframe);
   handle_mtf_fractal_down = handle_mtf_fractal_up; // Same handle for both directions
   
   // Check for errors in creating handles
   if(handle_fractal_up == INVALID_HANDLE || handle_mtf_fractal_up == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return(INIT_FAILED);
   }
   
   // Set indicator name with timeframe
   string short_name = "MTF Fractals (" + TimeframeToString(Period()) + " & " + TimeframeToString(Higher_Timeframe) + ")";
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
   if(rates_total < 5) return(0); // Not enough bars for fractals
   
   static datetime last_debug_time = 0;
   datetime current_time = TimeCurrent();
   bool print_debug = (current_time - last_debug_time > 60); // Debug once per minute
   
   if(print_debug)
   {
      Print("------- DEBUG START -------");
      Print("OnCalculate called - rates_total: ", rates_total, ", prev_calculated: ", prev_calculated);
      last_debug_time = current_time;
   }
   
   int limit;
   
   // Calculate the starting point
   if(prev_calculated == 0)
   {
      limit = rates_total - Fractal_Lookback - 1;
      
      // Initialize buffers with empty values
      ArrayInitialize(UpFractalBuffer, EMPTY_VALUE);
      ArrayInitialize(DownFractalBuffer, EMPTY_VALUE);
      ArrayInitialize(MTFUpFractalBuffer, EMPTY_VALUE);
      ArrayInitialize(MTFDownFractalBuffer, EMPTY_VALUE);
      ArrayInitialize(BullishOpen, 0);
      ArrayInitialize(BullishHigh, 0);
      ArrayInitialize(BullishLow, 0);
      ArrayInitialize(BullishClose, 0);
      ArrayInitialize(BearishOpen, 0);
      ArrayInitialize(BearishHigh, 0);
      ArrayInitialize(BearishLow, 0);
      ArrayInitialize(BearishClose, 0);
      ArrayInitialize(BullishTriangleBuffer, EMPTY_VALUE);
      ArrayInitialize(BearishTriangleBuffer, EMPTY_VALUE);
      ArrayInitialize(BullishBandUpper, EMPTY_VALUE);
      ArrayInitialize(BullishBandLower, EMPTY_VALUE);
      ArrayInitialize(BearishBandUpper, EMPTY_VALUE);
      ArrayInitialize(BearishBandLower, EMPTY_VALUE);
      
      if(print_debug) Print("First calculation - initializing all buffers");
   }
   else
   {
      limit = rates_total - prev_calculated;
      if(limit > 1) limit += Fractal_Lookback;
   }
   
   // Limit to a reasonable number
   if(limit > rates_total - 5) limit = rates_total - 5;
   if(limit < 0) limit = 0;
   
   if(print_debug) Print("Processing bars from index ", limit, " to ", rates_total - 3);
   
   // Arrays to store fractal status (will be used for confluence detection)
   bool has_up_fractal[]; 
   bool has_down_fractal[];
   bool has_mtf_up_fractal[];
   bool has_mtf_down_fractal[];
   
   ArrayResize(has_up_fractal, rates_total);
   ArrayResize(has_down_fractal, rates_total);
   ArrayResize(has_mtf_up_fractal, rates_total);
   ArrayResize(has_mtf_down_fractal, rates_total);
   
   ArrayInitialize(has_up_fractal, false);
   ArrayInitialize(has_down_fractal, false);
   ArrayInitialize(has_mtf_up_fractal, false);
   ArrayInitialize(has_mtf_down_fractal, false);
   
   // Copy fractal data for current timeframe - always process this data
   // even if Show_Current_TF is false, so we can detect confluences correctly
   {
      double up_buffer[];
      double down_buffer[];
      
      // Allocate arrays with suitable size
      ArraySetAsSeries(up_buffer, true);
      ArraySetAsSeries(down_buffer, true);
      ArrayResize(up_buffer, rates_total);
      ArrayResize(down_buffer, rates_total);
      
      // Copy data from indicators
      if(CopyBuffer(handle_fractal_up, 0, 0, rates_total, up_buffer) <= 0)
      {
         Print("Failed to copy up fractal data. Error code:", GetLastError());
         return(0);
      }
      
      if(CopyBuffer(handle_fractal_down, 1, 0, rates_total, down_buffer) <= 0)
      {
         Print("Failed to copy down fractal data. Error code:", GetLastError());
         return(0);
      }
      
      // Process the up and down fractals
      for(int i = limit; i < rates_total - 2; i++)
      {
         UpFractalBuffer[i] = EMPTY_VALUE;
         DownFractalBuffer[i] = EMPTY_VALUE;
         
         if(up_buffer[rates_total - 1 - i] != EMPTY_VALUE && up_buffer[rates_total - 1 - i] != 0)
         {
            UpFractalBuffer[i] = high[i] + 5 * Point(); // Place slightly above the high
            has_up_fractal[i] = true;
            
            if(print_debug && i > rates_total - 20) // Debug only recent bars
               Print("Bar ", i, " (", TimeToString(time[i]), ") - Current TF Up Fractal at price ", DoubleToString(high[i], _Digits));
         }
            
         if(down_buffer[rates_total - 1 - i] != EMPTY_VALUE && down_buffer[rates_total - 1 - i] != 0)
         {
            DownFractalBuffer[i] = low[i] - 5 * Point(); // Place slightly below the low
            has_down_fractal[i] = true;
            
            if(print_debug && i > rates_total - 20) // Debug only recent bars
               Print("Bar ", i, " (", TimeToString(time[i]), ") - Current TF Down Fractal at price ", DoubleToString(low[i], _Digits));
         }
      }
   }
   
   // Process MTF fractals
   double mtf_up_buffer[];
   double mtf_down_buffer[];
   
   // Allocate arrays with suitable size
   ArraySetAsSeries(mtf_up_buffer, true);
   ArraySetAsSeries(mtf_down_buffer, true);
   ArrayResize(mtf_up_buffer, rates_total);
   ArrayResize(mtf_down_buffer, rates_total);
   
   // Copy data from higher timeframe indicators
   if(CopyBuffer(handle_mtf_fractal_up, 0, 0, rates_total, mtf_up_buffer) <= 0)
   {
      Print("Failed to copy MTF up fractal data. Error code:", GetLastError());
      return(0);
   }
   
   if(CopyBuffer(handle_mtf_fractal_down, 1, 0, rates_total, mtf_down_buffer) <= 0)
   {
      Print("Failed to copy MTF down fractal data. Error code:", GetLastError());
      return(0);
   }
   
   // Map higher timeframe fractals to current timeframe
   datetime time_array[];
   datetime higher_time_array[];
   
   ArraySetAsSeries(time_array, true);
   ArraySetAsSeries(higher_time_array, true);
   
   if(CopyTime(Symbol(), Period(), 0, rates_total, time_array) <= 0)
   {
      Print("Failed to copy current timeframe time. Error code:", GetLastError());
      return(0);
   }
   
   if(CopyTime(Symbol(), Higher_Timeframe, 0, rates_total, higher_time_array) <= 0)
   {
      Print("Failed to copy higher timeframe time. Error code:", GetLastError());
      return(0);
   }
   
   // Map the higher timeframe fractals to current timeframe
   for(int i = limit; i < rates_total - 2; i++)
   {
      MTFUpFractalBuffer[i] = EMPTY_VALUE;
      MTFDownFractalBuffer[i] = EMPTY_VALUE;
      
      // Find corresponding higher timeframe bar
      datetime curr_bar_time = time_array[rates_total - 1 - i];
      int higher_bar_index = -1;
      
      for(int j = 0; j < ArraySize(higher_time_array); j++)
      {
         if(curr_bar_time >= higher_time_array[j] && 
            (j == 0 || curr_bar_time < higher_time_array[j-1]))
         {
            higher_bar_index = j;
            break;
         }
      }
      
      if(higher_bar_index >= 0 && higher_bar_index < ArraySize(mtf_up_buffer))
      {
         // Check if we have a fractal on the higher timeframe
         if(mtf_up_buffer[higher_bar_index] != EMPTY_VALUE && mtf_up_buffer[higher_bar_index] != 0)
         {
            MTFUpFractalBuffer[i] = high[i] + 25 * Point(); // Position a bit above the high
            has_mtf_up_fractal[i] = true;
            
            if(print_debug && i > rates_total - 20) // Debug only recent bars
               Print("Bar ", i, " (", TimeToString(time[i]), ") - Higher TF Up Fractal at price ", DoubleToString(high[i], _Digits));
         }
            
         if(mtf_down_buffer[higher_bar_index] != EMPTY_VALUE && mtf_down_buffer[higher_bar_index] != 0)
         {
            MTFDownFractalBuffer[i] = low[i] - 25 * Point(); // Position a bit below the low
            has_mtf_down_fractal[i] = true;
            
            if(print_debug && i > rates_total - 20) // Debug only recent bars
               Print("Bar ", i, " (", TimeToString(time[i]), ") - Higher TF Down Fractal at price ", DoubleToString(low[i], _Digits));
         }
      }
   }
   
   // Now check for confluence and highlight the bars
   if(Highlight_Confluence_Bars || Show_Confluence_Triangles || Show_Confluence_Bands)
   {
      int confluenceCount = 0;
      
      // Arrays to store the indices of the latest bullish and bearish confluence
      int lastBullishConfluence = -1;
      int lastBearishConfluence = -1;
      
      // First pass to identify confluences
      for(int i = limit; i < rates_total - 2; i++)
      {
         // Reset confluence values to ensure clean data
         BullishOpen[i] = 0;
         BullishHigh[i] = 0;
         BullishLow[i] = 0;
         BullishClose[i] = 0;
         BearishOpen[i] = 0;
         BearishHigh[i] = 0;
         BearishLow[i] = 0;
         BearishClose[i] = 0;
         BullishTriangleBuffer[i] = EMPTY_VALUE;
         BearishTriangleBuffer[i] = EMPTY_VALUE;
         BullishBandUpper[i] = EMPTY_VALUE;
         BullishBandLower[i] = EMPTY_VALUE;
         BearishBandUpper[i] = EMPTY_VALUE;
         BearishBandLower[i] = EMPTY_VALUE;
         
         // Bullish confluence: both up fractals present
         if(has_up_fractal[i] && has_mtf_up_fractal[i])
         {
            // Draw candle if enabled
            if(Highlight_Confluence_Bars)
            {
               BullishOpen[i] = open[i];
               BullishHigh[i] = high[i];
               BullishLow[i] = low[i];
               BullishClose[i] = close[i];
            }
            
            // Draw triangle if enabled
            if(Show_Confluence_Triangles)
            {
               // For bullish confluence, draw a down-pointing triangle (opposite direction)
               // at a specified distance from the high
               double trianglePosition = high[i];
               
               // Apply the user-defined distance
               trianglePosition += Triangle_Distance * Point();
               
               BullishTriangleBuffer[i] = trianglePosition;
            }
            
            // Store this as the latest bullish confluence
            lastBullishConfluence = i;
            
            confluenceCount++;
            
            if(print_debug && i > rates_total - 20) // Debug only recent bars
               Print("Bar ", i, " (", TimeToString(time[i]), ") - BULLISH CONFLUENCE DETECTED");
         }
         
         // Bearish confluence: both down fractals present
         if(has_down_fractal[i] && has_mtf_down_fractal[i])
         {
            // Draw candle if enabled
            if(Highlight_Confluence_Bars)
            {
               BearishOpen[i] = open[i];
               BearishHigh[i] = high[i];
               BearishLow[i] = low[i];
               BearishClose[i] = close[i];
            }
            
            // Draw triangle if enabled
            if(Show_Confluence_Triangles)
            {
               // For bearish confluence, draw an up-pointing triangle (opposite direction)
               // at a specified distance from the low
               double trianglePosition = low[i];
               
               // Apply the user-defined distance
               trianglePosition -= Triangle_Distance * Point();
               
               BearishTriangleBuffer[i] = trianglePosition;
            }
            
            // Store this as the latest bearish confluence
            lastBearishConfluence = i;
            
            confluenceCount++;
            
            if(print_debug && i > rates_total - 20) // Debug only recent bars
               Print("Bar ", i, " (", TimeToString(time[i]), ") - BEARISH CONFLUENCE DETECTED");
         }
      }
      
      // Now create the bands that extend from the confluences to the right edge
      if(Show_Confluence_Bands)
      {
         if(lastBullishConfluence >= 0)
         {
            double upperLevel = BullishHigh[lastBullishConfluence];
            double lowerLevel = BullishLow[lastBullishConfluence];
            
            // Extend these levels from the last bullish confluence to the right edge
            for(int i = lastBullishConfluence; i < rates_total; i++)
            {
               BullishBandUpper[i] = upperLevel;
               BullishBandLower[i] = lowerLevel;
            }
            
            if(print_debug)
               Print("Created bullish band from bar ", lastBullishConfluence, " to end with high: ", 
                     DoubleToString(upperLevel, _Digits), ", low: ", DoubleToString(lowerLevel, _Digits));
         }
         
         if(lastBearishConfluence >= 0)
         {
            double upperLevel = BearishHigh[lastBearishConfluence];
            double lowerLevel = BearishLow[lastBearishConfluence];
            
            // Extend these levels from the last bearish confluence to the right edge
            for(int i = lastBearishConfluence; i < rates_total; i++)
            {
               BearishBandUpper[i] = upperLevel;
               BearishBandLower[i] = lowerLevel;
            }
            
            if(print_debug)
               Print("Created bearish band from bar ", lastBearishConfluence, " to end with high: ", 
                     DoubleToString(upperLevel, _Digits), ", low: ", DoubleToString(lowerLevel, _Digits));
         }
      }
      
      if(print_debug) Print("Total confluence bars found: ", confluenceCount);
   }
   
   if(print_debug) Print("------- DEBUG END -------");
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(handle_fractal_up != INVALID_HANDLE)
      IndicatorRelease(handle_fractal_up);
      
   if(handle_mtf_fractal_up != INVALID_HANDLE && handle_mtf_fractal_up != handle_fractal_up)
      IndicatorRelease(handle_mtf_fractal_up);
}

//+------------------------------------------------------------------+
//| Convert timeframe to string                                      |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:  return("M1");
      case PERIOD_M2:  return("M2");
      case PERIOD_M3:  return("M3");
      case PERIOD_M4:  return("M4");
      case PERIOD_M5:  return("M5");
      case PERIOD_M6:  return("M6");
      case PERIOD_M10: return("M10");
      case PERIOD_M12: return("M12");
      case PERIOD_M15: return("M15");
      case PERIOD_M20: return("M20");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H2:  return("H2");
      case PERIOD_H3:  return("H3");
      case PERIOD_H4:  return("H4");
      case PERIOD_H6:  return("H6");
      case PERIOD_H8:  return("H8");
      case PERIOD_H12: return("H12");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
      default:         return(IntegerToString(timeframe));
   }
}
//+------------------------------------------------------------------+
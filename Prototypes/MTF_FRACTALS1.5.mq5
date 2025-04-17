//+------------------------------------------------------------------+
//|                                              MTF_Fractals.mq5 |
//|                                       Copyright 2025, Your Name |
//|                                            https://www.your-website.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025, Your Name"
#property link      "https://www.your-website.com"
#property version   "1.00"
#property description "Multi-Timeframe Fractals Indicator with Confluence Bars and Triangles for MT5"
#property indicator_chart_window
#property indicator_buffers 14  // 4 for fractals, 8 for candles, 2 for triangles
#property indicator_plots   8   // 4 for fractals, 2 for candles, 2 for triangles

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

// Input parameters
input ENUM_TIMEFRAMES Higher_Timeframe = PERIOD_H1; // Higher timeframe
input int Fractal_Lookback = 2;                     // Fractal lookback period
input bool Show_Current_TF = true;                  // Show current timeframe fractals (CHANGED TO TRUE)
input bool Show_MTF_Arrows = true;                  // Show higher timeframe fractal arrows (CHANGED TO TRUE)
input bool Highlight_Confluence_Bars = true;        // Highlight bars with fractal confluence
input bool Show_Confluence_Triangles = true;        // Show triangles at confluence points
input int Triangle_Size = 20;                       // Size of confluence triangles
input int Triangle_Distance = 60;                   // Distance of triangles from price (in Points)
input color Bullish_Candle_Color = clrYellow;       // Bullish confluence candle color
input color Bearish_Candle_Color = clrPurple;       // Bearish confluence candle color
input color Bullish_Triangle_Color = clrLimeGreen;  // Bullish confluence triangle color
input color Bearish_Triangle_Color = clrCrimson;    // Bearish confluence triangle color

// Indicator buffers
double UpFractalBuffer[];     // Current TF up fractals
double DownFractalBuffer[];   // Current TF down fractals
double MTFUpFractalBuffer[];  // Higher TF up fractals
double MTFDownFractalBuffer[];// Higher TF down fractals
// Buffers for confluence candles
double BullishOpen[];         // Bullish confluence open
double BullishHigh[];         // Bullish confluence high
double BullishLow[];          // Bullish confluence low
double BullishClose[];        // Bullish confluence close
double BearishOpen[];         // Bearish confluence open
double BearishHigh[];         // Bearish confluence high
double BearishLow[];          // Bearish confluence low
double BearishClose[];        // Bearish confluence close
// Buffers for confluence triangles
double BullishTriangleBuffer[];    // Bullish confluence triangle
double BearishTriangleBuffer[];    // Bearish confluence triangle

// Global variables
int handle_fractal_up;       // Handle for Up Fractal
int handle_fractal_down;     // Handle for Down Fractal
int handle_mtf_fractal_up;   // Handle for MTF Up Fractal
int handle_mtf_fractal_down; // Handle for MTF Down Fractal

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=========== MTF FRACTALS INITIALIZING ===========");
   
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
   
   // Debug info about buffer setup
   Print("Indicator buffers set up:");
   Print("  Buffers 0-3: Fractal arrows");
   Print("  Buffers 4-7: Bullish confluence candles");
   Print("  Buffers 8-11: Bearish confluence candles");
   Print("  Buffers 12-13: Confluence triangles");
   
   // Handle visibility based on user input - separate controls for each element
   // IMPORTANT: Always use DRAW_ARROW for fractals, never DRAW_NONE as we want them visible
   // Current timeframe fractals - CHANGED TO ALWAYS VISIBLE
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
   
   // Higher timeframe fractals - CHANGED TO ALWAYS VISIBLE
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
   
   // Confluence candles/rectangles - controlled separately by Highlight_Confluence_Bars
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, Highlight_Confluence_Bars ? DRAW_CANDLES : DRAW_NONE);
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, Highlight_Confluence_Bars ? DRAW_CANDLES : DRAW_NONE);
   
   // Confluence triangles
   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, Show_Confluence_Triangles ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, Show_Confluence_Triangles ? DRAW_ARROW : DRAW_NONE);
   
   // Set up visualization parameters for current TF fractals
   PlotIndexSetInteger(0, PLOT_ARROW, 217); // CHANGED: Up arrow (more visible)
   PlotIndexSetInteger(1, PLOT_ARROW, 218); // CHANGED: Down arrow (more visible)
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 0); // CHANGED: No shift
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 0); // CHANGED: No shift
   
   // Set up visualization parameters for MTF fractals
   PlotIndexSetInteger(2, PLOT_ARROW, 225); // Up MTF arrow (larger arrow)
   PlotIndexSetInteger(3, PLOT_ARROW, 226); // Down MTF arrow (larger arrow)
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, 0); // CHANGED: No shift
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, 0); // CHANGED: No shift

   // Set up visualization parameters for confluence triangles
   PlotIndexSetInteger(6, PLOT_ARROW, 242); // Down-pointing triangle for bullish confluence (opposite)
   PlotIndexSetInteger(7, PLOT_ARROW, 241); // Up-pointing triangle for bearish confluence (opposite)
   PlotIndexSetInteger(6, PLOT_ARROW_SHIFT, 0);  // Positioning handled in calculation
   PlotIndexSetInteger(7, PLOT_ARROW_SHIFT, 0);  // Positioning handled in calculation
   
   // Increase size of fractal arrows for visibility
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2); // ADDED: Wider up fractal
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2); // ADDED: Wider down fractal
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 3); // ADDED: Wider MTF up fractal
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 3); // ADDED: Wider MTF down fractal
   
   // Make colors more visible
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrLime);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, clrRed);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, clrAqua);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, 0, clrMagenta);
   
   // Set empty value for buffers
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // Apply user-defined colors
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, 0, Bullish_Candle_Color);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 0, Bearish_Candle_Color);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, 0, Bullish_Triangle_Color);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, 0, Bearish_Triangle_Color);
   
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
   Print("OnCalculate called with rates_total: ", rates_total, ", prev_calculated: ", prev_calculated);
   
   if(rates_total < 5) return(0); // Not enough bars for fractals
   
   // Initialize buffers
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
   
   // Calculate the starting point
   int limit;
   
   if(prev_calculated == 0)
   {
      limit = rates_total - Fractal_Lookback - 1;
      Print("First calculation - starting from bar ", limit);
   }
   else
   {
      limit = prev_calculated - 1;
      Print("Recalculation - starting from bar ", limit);
   }
   
   // Limit to a reasonable number
   if(limit < 3) limit = 3;
   if(limit > rates_total - 3) limit = rates_total - 3;
   
   Print("Processing bars from index ", limit, " to ", rates_total - 3);
   
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
   
   // Copy fractal data for current timeframe
   double up_buffer[];
   double down_buffer[];
   
   // Allocate arrays with suitable size
   ArrayResize(up_buffer, rates_total);
   ArrayResize(down_buffer, rates_total);
   
   // Copy data from indicators - CHANGED: Using direct indices
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
      // Current TF Fractals - CHANGED: Direct access to buffer
      if(up_buffer[i] != EMPTY_VALUE && up_buffer[i] != 0)
      {
         UpFractalBuffer[i] = high[i]; // CHANGED: Place directly at high
         has_up_fractal[i] = true;
         Print("Bar ", i, " (", TimeToString(time[i]), ") - Current TF Up Fractal at price ", DoubleToString(high[i], _Digits));
      }
         
      if(down_buffer[i] != EMPTY_VALUE && down_buffer[i] != 0)
      {
         DownFractalBuffer[i] = low[i]; // CHANGED: Place directly at low
         has_down_fractal[i] = true;
         Print("Bar ", i, " (", TimeToString(time[i]), ") - Current TF Down Fractal at price ", DoubleToString(low[i], _Digits));
      }
   }
   
   // Process MTF fractals - CHANGED: Simplified approach using iBarShift
   double mtf_up_buffer[];
   double mtf_down_buffer[];
   
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
   
   // For higher TF fractals - CHANGED: Using iBarShift for mapping
   for(int i = limit; i < rates_total - 2; i++)
   {
      // Find the corresponding bar in the higher timeframe
      datetime curr_time = time[i];
      int higher_tf_bar = iBarShift(Symbol(), Higher_Timeframe, curr_time);
      
      // Check if valid bar found
      if(higher_tf_bar >= 0)
      {
         // Check if we have an up fractal on the higher timeframe
         if(mtf_up_buffer[higher_tf_bar] != EMPTY_VALUE && mtf_up_buffer[higher_tf_bar] != 0)
         {
            MTFUpFractalBuffer[i] = high[i]; // CHANGED: Place directly at high
            has_mtf_up_fractal[i] = true;
            Print("Bar ", i, " (", TimeToString(time[i]), ") - Higher TF Up Fractal at price ", DoubleToString(high[i], _Digits));
         }
            
         // Check if we have a down fractal on the higher timeframe
         if(mtf_down_buffer[higher_tf_bar] != EMPTY_VALUE && mtf_down_buffer[higher_tf_bar] != 0)
         {
            MTFDownFractalBuffer[i] = low[i]; // CHANGED: Place directly at low
            has_mtf_down_fractal[i] = true;
            Print("Bar ", i, " (", TimeToString(time[i]), ") - Higher TF Down Fractal at price ", DoubleToString(low[i], _Digits));
         }
      }
   }
   
   // Now check for confluence and highlight the bars
   if(Highlight_Confluence_Bars || Show_Confluence_Triangles)
   {
      int confluenceCount = 0;
      
      for(int i = limit; i < rates_total - 2; i++)
      {
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
               BullishTriangleBuffer[i] = high[i] + Triangle_Distance * Point();
            }
            
            confluenceCount++;
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
               BearishTriangleBuffer[i] = low[i] - Triangle_Distance * Point();
            }
            
            confluenceCount++;
            Print("Bar ", i, " (", TimeToString(time[i]), ") - BEARISH CONFLUENCE DETECTED");
         }
      }
      
      Print("Total confluence bars found: ", confluenceCount);
   }
   
   Print("OnCalculate completed successfully");
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Deinitializing MTF Fractals indicator, reason code: ", reason);
   
   // Release indicator handles
   if(handle_fractal_up != INVALID_HANDLE)
      IndicatorRelease(handle_fractal_up);
      
   if(handle_mtf_fractal_up != INVALID_HANDLE && handle_mtf_fractal_up != handle_fractal_up)
      IndicatorRelease(handle_mtf_fractal_up);
      
   Print("Indicator handles released");
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
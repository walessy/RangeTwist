//+------------------------------------------------------------------+
//|                                              MTF_Fractals.mq5 |
//|                                       Copyright 2025, Your Name |
//|                                            https://www.your-website.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://www.your-website.com"
#property version   "1.00"
#property description "Multi-Timeframe Fractals Indicator for MT5"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

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

// Input parameters
input ENUM_TIMEFRAMES Higher_Timeframe = PERIOD_H1; // Higher timeframe
input int Fractal_Lookback = 2;                     // Fractal lookback period
input bool Show_Current_TF = true;                  // Show current timeframe fractals

// Indicator buffers
double UpFractalBuffer[];     // Current TF up fractals
double DownFractalBuffer[];   // Current TF down fractals
double MTFUpFractalBuffer[];  // Higher TF up fractals
double MTFDownFractalBuffer[];// Higher TF down fractals

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
   // Set up indicator buffers
   SetIndexBuffer(0, UpFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DownFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, MTFUpFractalBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, MTFDownFractalBuffer, INDICATOR_DATA);
   
   // Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 217); // Up arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 218); // Down arrow
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // Up MTF arrow
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // Down MTF arrow
   
   // Set empty value for buffers
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
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
   }
   else
   {
      limit = rates_total - prev_calculated;
      if(limit > 1) limit += Fractal_Lookback;
   }
   
   // Limit to a reasonable number
   if(limit > rates_total - 5) limit = rates_total - 5;
   if(limit < 0) limit = 0;
   
   // Copy fractal data for current timeframe
   if(Show_Current_TF)
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
            UpFractalBuffer[i] = high[i] + 10 * Point();
            
         if(down_buffer[rates_total - 1 - i] != EMPTY_VALUE && down_buffer[rates_total - 1 - i] != 0)
            DownFractalBuffer[i] = low[i] - 10 * Point();
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
   datetime current_time[];
   datetime higher_time[];
   
   ArraySetAsSeries(current_time, true);
   ArraySetAsSeries(higher_time, true);
   
   if(CopyTime(Symbol(), Period(), 0, rates_total, current_time) <= 0)
   {
      Print("Failed to copy current timeframe time. Error code:", GetLastError());
      return(0);
   }
   
   if(CopyTime(Symbol(), Higher_Timeframe, 0, rates_total, higher_time) <= 0)
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
      datetime curr_bar_time = current_time[rates_total - 1 - i];
      int higher_bar_index = -1;
      
      for(int j = 0; j < ArraySize(higher_time); j++)
      {
         if(curr_bar_time >= higher_time[j] && 
            (j == 0 || curr_bar_time < higher_time[j-1]))
         {
            higher_bar_index = j;
            break;
         }
      }
      
      if(higher_bar_index >= 0 && higher_bar_index < ArraySize(mtf_up_buffer))
      {
         // Check if we have a fractal on the higher timeframe
         if(mtf_up_buffer[higher_bar_index] != EMPTY_VALUE && mtf_up_buffer[higher_bar_index] != 0)
            MTFUpFractalBuffer[i] = high[i] + 20 * Point();
            
         if(mtf_down_buffer[higher_bar_index] != EMPTY_VALUE && mtf_down_buffer[higher_bar_index] != 0)
            MTFDownFractalBuffer[i] = low[i] - 20 * Point();
      }
   }
   
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
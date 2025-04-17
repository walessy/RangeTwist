//+------------------------------------------------------------------+
//|                                      Simple_MTF_Fractals.mq5      |
//|                                      Copyright 2025, Your Name    |
//|                                            https://www.domain.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://www.domain.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

// Plot properties for timeframe 1
#property indicator_label1  "TF1 Up Fractal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "TF1 Down Fractal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// Plot properties for timeframe 2
#property indicator_label3  "TF2 Up Fractal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrMagenta
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "TF2 Down Fractal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLimeGreen
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

// Indicator buffers
double UpFractalTF1Buffer[];
double DownFractalTF1Buffer[];
double UpFractalTF2Buffer[];
double DownFractalTF2Buffer[];

// Input parameters
input int     FractalPeriod = 5;           // Fractal Period (must be odd)
input ENUM_TIMEFRAMES Timeframe1 = PERIOD_H1;  // First Timeframe
input ENUM_TIMEFRAMES Timeframe2 = PERIOD_D1;  // Second Timeframe
input int     ArrowOffset   = 5;           // Arrow Offset (in points)
input int     MaxBars       = 500;         // Maximum Bars to Calculate

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Ensure fractal period is odd
   if(FractalPeriod % 2 == 0)
   {
      Print("Fractal Period must be an odd number!");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Set buffer indexes
   SetIndexBuffer(0, UpFractalTF1Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, DownFractalTF1Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, UpFractalTF2Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, DownFractalTF2Buffer, INDICATOR_DATA);
   
   // Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 217); // Up arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 218); // Down arrow
   PlotIndexSetInteger(2, PLOT_ARROW, 217); // Up arrow
   PlotIndexSetInteger(3, PLOT_ARROW, 218); // Down arrow
   
   // Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   
   // Set indicator name with selected timeframes
   string tf1name = GetTimeframeName(Timeframe1);
   string tf2name = GetTimeframeName(Timeframe2);
   string short_name = "MTF Fractals (" + tf1name + " & " + tf2name + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator calculation function                             |
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
   // Limit calculation to avoid performance issues
   int limit = rates_total - prev_calculated;
   
   if(limit > MaxBars) limit = MaxBars;
   if(limit > rates_total - FractalPeriod) limit = rates_total - FractalPeriod;
   
   // Calculate fractals for the two selected timeframes
   CalculateFractals(limit, high, low, time);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate fractals for the two timeframes                         |
//+------------------------------------------------------------------+
void CalculateFractals(int limit, const double &high[], const double &low[], const datetime &time[])
{
   // Process each bar
   for(int i = 0; i < limit; i++)
   {
      int idx = i;
      
      // Reset all buffer values
      UpFractalTF1Buffer[idx] = 0.0;
      DownFractalTF1Buffer[idx] = 0.0;
      UpFractalTF2Buffer[idx] = 0.0;
      DownFractalTF2Buffer[idx] = 0.0;
      
      // Process Timeframe 1
      if(IsNewBar(time[idx], Timeframe1))
      {
         ProcessFractal(idx, Timeframe1, high, low, time, 
                        UpFractalTF1Buffer, DownFractalTF1Buffer);
      }
      
      // Process Timeframe 2
      if(IsNewBar(time[idx], Timeframe2))
      {
         ProcessFractal(idx, Timeframe2, high, low, time,
                        UpFractalTF2Buffer, DownFractalTF2Buffer);
      }
   }
}

//+------------------------------------------------------------------+
//| Process fractal detection for a specific timeframe                |
//+------------------------------------------------------------------+
void ProcessFractal(int idx, ENUM_TIMEFRAMES timeframe, 
                   const double &high[], const double &low[], const datetime &time[],
                   double &upBuffer[], double &downBuffer[])
{
   // Get the data for the higher timeframe
   MqlRates rates[];
   if(CopyRates(_Symbol, timeframe, time[idx], FractalPeriod, rates) == FractalPeriod)
   {
      int middle = FractalPeriod / 2;
      
      // Check for up fractal
      bool isUpFractal = true;
      for(int j = 0; j < FractalPeriod; j++)
      {
         if(j == middle) continue; // Skip middle bar
         if(rates[j].high >= rates[middle].high)
         {
            isUpFractal = false;
            break;
         }
      }
      
      // Check for down fractal
      bool isDownFractal = true;
      for(int j = 0; j < FractalPeriod; j++)
      {
         if(j == middle) continue; // Skip middle bar
         if(rates[j].low <= rates[middle].low)
         {
            isDownFractal = false;
            break;
         }
      }
      
      // Calculate offset based on timeframe
      double offset = ArrowOffset * _Point;
      if(timeframe >= PERIOD_H1) offset *= 2;
      if(timeframe >= PERIOD_H4) offset *= 2;
      if(timeframe == PERIOD_D1) offset *= 2;
      
      // Set values in buffers
      if(isUpFractal)
      {
         upBuffer[idx] = high[idx] + offset;
      }
      
      if(isDownFractal)
      {
         downBuffer[idx] = low[idx] - offset;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if the current bar is the start of a new bar on the        |
//| specified timeframe                                              |
//+------------------------------------------------------------------+
bool IsNewBar(datetime current_time, ENUM_TIMEFRAMES timeframe)
{
   datetime tf_time[1];
   if(CopyTime(_Symbol, timeframe, 0, 1, tf_time) != 1) return false;
   
   MqlDateTime current_mql_time, tf_mql_time;
   TimeToStruct(current_time, current_mql_time);
   TimeToStruct(tf_time[0], tf_mql_time);
   
   // For higher timeframes, compare relevant time components
   switch(timeframe)
   {
      case PERIOD_M1:
         return current_mql_time.min == tf_mql_time.min &&
                current_mql_time.hour == tf_mql_time.hour &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_M2:
         return current_mql_time.min / 2 == tf_mql_time.min / 2 &&
                current_mql_time.hour == tf_mql_time.hour &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_M3:
         return current_mql_time.min / 3 == tf_mql_time.min / 3 &&
                current_mql_time.hour == tf_mql_time.hour &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_M5:
         return current_mql_time.min / 5 == tf_mql_time.min / 5 &&
                current_mql_time.hour == tf_mql_time.hour &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_M10:
         return current_mql_time.min / 10 == tf_mql_time.min / 10 &&
                current_mql_time.hour == tf_mql_time.hour &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_M15:
         return current_mql_time.min / 15 == tf_mql_time.min / 15 &&
                current_mql_time.hour == tf_mql_time.hour &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_M30:
         return current_mql_time.min / 30 == tf_mql_time.min / 30 &&
                current_mql_time.hour == tf_mql_time.hour &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_H1:
         return current_mql_time.hour == tf_mql_time.hour &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_H2:
         return current_mql_time.hour / 2 == tf_mql_time.hour / 2 &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_H3:
         return current_mql_time.hour / 3 == tf_mql_time.hour / 3 &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_H4:
         return current_mql_time.hour / 4 == tf_mql_time.hour / 4 &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_H6:
         return current_mql_time.hour / 6 == tf_mql_time.hour / 6 &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_H8:
         return current_mql_time.hour / 8 == tf_mql_time.hour / 8 &&
                current_mql_time.day == tf_mql_time.day;
                
      case PERIOD_D1:
         return current_mql_time.day == tf_mql_time.day;
                
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Get timeframe name as string                                      |
//+------------------------------------------------------------------+
string GetTimeframeName(ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "Unknown";
   }
}
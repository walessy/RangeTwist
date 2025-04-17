//+------------------------------------------------------------------+
//|                                    AlexSTAL_ZigZagTrendArrows.mq5 |
//|                                         Copyright 2011, AlexSTAL |
//|                  Modified to show trend change arrows only        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2011, AlexSTAL"
#property link      "http://www.alexstal.ru"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   2
//---- plot Up Arrows
#property indicator_label1  "Up Trend"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  Red         // Changed from LimeGreen to Red
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
//---- plot Down Arrows
#property indicator_label2  "Down Trend"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  LimeGreen   // Changed from Red to LimeGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

#include "AlexSTAL_OutsideBar.mqh"

// Number of bars to calculate the extremums
// the value should be not less than 2
input uchar iExtPeriod = 12;
// Minimal distance between the neighbour peak and bottom (overwise it will skip)
input uchar iMinAmplitude = 10;
// Minimal price movement in points at the zeroth bar for recalculation of the indicator
input uchar iMinMotion = 0;
// Use more precise algorithm to calculate the ordering of the High/Low formation
input bool iUseSmallerTFforEB = true;
// Arrow size
input int iArrowSize = 3;

uchar ExtPeriod, MinAmplitude, MinMotion;

// Buffers of the indicator - we'll hide the zigzag lines
double UP[], DN[];
// Buffers for trend arrows
double UpArrow[], DownArrow[];
// Buffers for cache of the outside bar
double OB[];

// Opening time of the last calculated bar
datetime LastBarTime;
// Protection of history update (download)
// Used for optimization of calculations
double LastBarLastHigh, LastBarLastLow;
// Time of the last extermum (needed for the outside bar recalculation)
datetime TimeFirstExtBar;

// Used in the calculations
double MP, MM;

// Auxiliary variable
bool DownloadHistory;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   if (iExtPeriod >= 2)
      ExtPeriod = iExtPeriod;
   else
      ExtPeriod = 2;
   
   MinAmplitude = iMinAmplitude;
   MP = NormalizeDouble(MinAmplitude * _Point, _Digits);
   
   if (iMinMotion >= 1)
      MinMotion = iMinMotion;
   else
      MinMotion = 1;
   MM = NormalizeDouble(MinMotion * _Point, _Digits);
   
   //--- indicator buffers mapping
   // Original buffers (hidden)
   SetIndexBuffer(0, UP, INDICATOR_CALCULATIONS);
   SetIndexBuffer(1, DN, INDICATOR_CALCULATIONS);
   // Arrow buffers
   SetIndexBuffer(2, UpArrow, INDICATOR_DATA);
   SetIndexBuffer(3, DownArrow, INDICATOR_DATA);
   // Outside bar cache buffer
   SetIndexBuffer(4, OB, INDICATOR_CALCULATIONS);
   
   ArraySetAsSeries(UP, true);
   ArraySetAsSeries(DN, true);
   ArraySetAsSeries(UpArrow, true);
   ArraySetAsSeries(DownArrow, true);
   ArraySetAsSeries(OB, true);

   // Set up arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow code
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow code
   
   // Set width (size) of the arrows
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, iArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, iArrowSize);

   //--- set short name and digits   
   PlotIndexSetString(0, PLOT_LABEL, "ZigZag Up Trend(" + (string)ExtPeriod + "," + (string)MinAmplitude + ")");
   PlotIndexSetString(1, PLOT_LABEL, "ZigZag Down Trend(" + (string)ExtPeriod + "," + (string)MinAmplitude + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   DownloadHistory = true;
   
   //---
   return(0);
}
//+------------------------------------------------------------------+
//|  searching index of the highest bar                              |
//+------------------------------------------------------------------+
int iHighest(const double &array[], int depth, int startPos)
{
   int index = startPos;
   int MaxBar = ArraySize(array) - 1;
   //--- start index validation
   if ( (startPos < 0) || (startPos > MaxBar) )
     {
      Print("Invalid parameter in the function iHighest, startPos =", startPos);
      return -1;
     }
   double max = array[startPos];
   
   //--- start searching
   for (int i = MathMin(startPos+depth-1, MaxBar); i >= startPos; i--)
     {
      if (array[i] > max)
        {
         index = i;
         max = array[i];
        }
     }
   //--- return index of the highest bar
   return(index);
}
//+------------------------------------------------------------------+
//|  searching index of the lowest bar                               |
//+------------------------------------------------------------------+
int iLowest(const double &array[], int depth, int startPos)
{
   int index = startPos;
   int MaxBar = ArraySize(array) - 1;
   //--- start index validation
   if ( (startPos < 0) || (startPos > MaxBar) )
     {
      Print("Invalid parameter in the function iLowest, startPos =",startPos);
      return -1;
     }
   double min = array[startPos];
   
   //--- start searching
   for (int i = MathMin(startPos+depth-1, MaxBar); i >= startPos; i--)
     {
      if (array[i] < min)
        {
         index = i;
         min = array[i];
        }
     }
   //--- return index of the lowest bar
   return(index);
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
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   int i;
   for (i = (rates_total-prev_calculated-1); i >= 0; i--)
     {
      UP[i] = EMPTY_VALUE;
      DN[i] = EMPTY_VALUE;
      OB[i] = EMPTY_VALUE;
      UpArrow[i] = EMPTY_VALUE;
      DownArrow[i] = EMPTY_VALUE;
     }
   
   //---
   // Initialization when downloading of the history
   // ----------------------------------------------
   int counted_bars = prev_calculated;
   
   // IndicatorCounted() may be zero when reconnected
   if ( counted_bars == 0 )
      DownloadHistory = true;
   
   // Reinitialization
   if (DownloadHistory)
     {
      ArrayInitialize(UP, EMPTY_VALUE);
      ArrayInitialize(DN, EMPTY_VALUE);
      ArrayInitialize(OB, EMPTY_VALUE);
      ArrayInitialize(UpArrow, EMPTY_VALUE);
      ArrayInitialize(DownArrow, EMPTY_VALUE);
      TimeFirstExtBar = 0;
      counted_bars = 0;
      LastBarTime = 0;
      DownloadHistory = false;
     }
   
   // check for the new bar
   bool NewBar = false;
   if (LastBarTime != time[0])
     {
      NewBar = true;
      LastBarTime = time[0];
      // zero variables
      LastBarLastHigh = high[0];
      LastBarLastLow = low[0];
     }

   // Check the bars, needed for the recalculation
   int BarsForRecalculation;
   if ( counted_bars != 0 )
     {
      BarsForRecalculation = rates_total - counted_bars;
      // Optimization of the calculations
      if (!NewBar)
        {
         if ( (NormalizeDouble(high[0]-LastBarLastHigh, _Digits) >= MM) || (NormalizeDouble(LastBarLastLow-low[0], _Digits) >= MM) )
           {
            LastBarLastHigh = high[0];
            LastBarLastLow = low[0];
           } else {
            // the price has changed inside the current (0) bar, or price changes less than threshold,
            // defined in MinMotion variable
            return(rates_total);
           }
        }
     } else {
      BarsForRecalculation = rates_total - ExtPeriod;
     }
   
   //======================================================
   //============ main loop ===============================
   //======================================================
   int LET;
   double H, L, Fup, Fdn;
   int lastUPbar, lastDNbar;
   double lastUP, lastDN;
   int m, n; // used in search for the last extremum
   for (i = BarsForRecalculation; i >= 0; i--)
     {
      // Search for the last extremum
      // ---------------------------
      lastUP = 0;
      lastDN = 0;
      lastUPbar = i;
      lastDNbar = i;
      LET = 0; 
      m = 0; n = 0;
      while ( UP[lastUPbar] == EMPTY_VALUE )
        {
         if ( lastUPbar > (rates_total-ExtPeriod) )
            break;
         lastUPbar++;
        }
      lastUP = UP[lastUPbar]; // it's possible we have found the last peak
      while ( DN[lastDNbar] == EMPTY_VALUE)
        {
         if ( lastDNbar > (rates_total-ExtPeriod) )
            break;
         lastDNbar++;
        } 
      lastDN = DN[lastDNbar]; //it's possible we have found the last bottom
   
      if ( lastUPbar < lastDNbar)
         LET = 1;
      if ( lastUPbar > lastDNbar)
         LET = -1;
      if ( lastUPbar == lastDNbar)
        {
         //lastUPbar==lastDNbar, so we need to check if the single extermum is the last extremum:
         m = lastUPbar;
         n = m;
         while ( m == n )
           {
            m++; n++;
            while ( UP[m] == EMPTY_VALUE )
              {
               if ( m > (rates_total-ExtPeriod) )
                  break;
               m++;
              } // it's possible we have found the last peak
            while ( DN[n] == EMPTY_VALUE )
              {
               if ( n > (rates_total-ExtPeriod) )
                  break;
               n++;
              } //it's possible we have found the last bottom
            if ( MathMax(m, n) > (rates_total-ExtPeriod) )
               break;
           }
         if (m < n)
            LET = 1;     // peak
         else
            if (m > n)
               LET = -1; // bottom
        }
      // ----------------------------------
      // if LET==0 - it means that it may be outside bar with 2 extremums (in the begining)
      // End of the last extremum search
      // ----------------------------------

      //---- let's consider the extermal price valus of the period:
      H = high[iHighest(high, ExtPeriod, i)];
      L = low[iLowest(low, ExtPeriod, i)];
      Fup = high[i];
      Fdn = low[i];
      
      //---- check for the new extremums: 
      switch(Comb(i,H,L,Fup,Fdn))
        {
         //---- potential Peak
         case 1 :
            switch(LET)
              {
               case 1 :
                  // the last extemum is the peak, choose the highest:
                  if ( lastUP < Fup )
                    {
                     UP[lastUPbar] = EMPTY_VALUE;
                     UP[i] = Fup;
                    }
                  break;
               case -1 :
                  if ( (Fup-lastDN) > MP ) // previous extremum is the bottom
                    {
                     UP[i] = Fup;
                     // This is where trend changes from down to up - place an up arrow
                     UpArrow[i] = low[i]; // Place arrow at the bottom of the bar
                    }
                  break; 
               default :
                  UP[i] = Fup;
                  TimeFirstExtBar = time[i]; //0 - means the beginning of the calculation
                  break; 
              }
            break;

         //---- Potential bottom  (Comb)          
         case -1 :
            switch(LET)
              {
               case 1 :
                  if ( (lastUP-Fdn) > MP ) // previous extemum was peak
                    {
                     DN[i]=Fdn;
                     // This is where trend changes from up to down - place a down arrow
                     DownArrow[i] = high[i]; // Place arrow at the top of the bar
                    }
                  break; 
               case -1 :
                  // previous extremum is the bottom, choose the lowest:
                  if ( lastDN > Fdn )
                    {
                     DN[lastDNbar] = EMPTY_VALUE;
                     DN[i] = Fdn;
                    }
                  break;
               default :
                  DN[i] = Fdn;
                  TimeFirstExtBar = time[i]; //0 - means the beginning of the calculation
                  break;
              }
            break;

         //---- potential peak or potential bottom (Comb)
         case 2 : // Bull bar: Low first, High last
            switch(LET)
              {
               case 1 : // previous extremum is the peak
                  if ( (Fup-Fdn) > MP )
                    {
                     if ( (lastUP-Fdn) > MP )
                       {
                        UP[i] = Fup;
                        DN[i] = Fdn;
                        // Potential trend change from up to down to up again in same bar
                        // Add arrows for clarity - uncomment if needed for such edge cases
                        //DownArrow[i] = high[i];
                        //UpArrow[i] = low[i];
                       } else {
                        if ( lastUP < Fup )
                          {
                           UP[lastUPbar] = EMPTY_VALUE;
                           UP[i] = Fup;
                          }
                       }
                    } else {
                     if ( (lastUP-Fdn) > MP )
                       { 
                        DN[i] = Fdn;
                        // Trend change from up to down
                        DownArrow[i] = high[i];
                       }
                     else {
                        if ( lastUP < Fup )
                          {
                           UP[lastUPbar] = EMPTY_VALUE;
                           UP[i] = Fup;
                          }
                       }
                    }
                  break;
               case -1 : //previous extremum is the bottom
                  if ( (Fup-Fdn) > MP )
                    {
                     UP[i] = Fup;
                     // Trend change from down to up
                     UpArrow[i] = low[i];
                     
                     if ( (Fdn < lastDN) && (time[lastDNbar] > TimeFirstExtBar) )
                       {
                        DN[lastDNbar] = EMPTY_VALUE;
                        DN[i] = Fdn;
                       }
                    } else {
                     if ( (Fup-lastDN) > MP )
                       {
                        UP[i] = Fup;
                        // Trend change from down to up
                        UpArrow[i] = low[i];
                       }
                     else {
                        if ( lastDN > Fdn )
                          {
                           DN[lastDNbar] = EMPTY_VALUE;
                           DN[i] = Fdn;
                          }
                       }
                    }
                  break;
               default: break;
              } //switch LET
            break;

         //---- potential peak or potential bottom (Comb)
         case -2 : // BEAR bar: High first, Low last
            switch(LET)
              {
               case 1 : //previous extremum is the peak
                  if ( (Fup-Fdn) > MP )
                    {
                     DN[i] = Fdn;
                     // Trend change from up to down
                     DownArrow[i] = high[i];
                     
                     if ( (lastUP < Fup) && (time[lastUPbar] > TimeFirstExtBar) )
                       {
                        UP[lastUPbar] = EMPTY_VALUE;
                        UP[i] = Fup;
                       }
                    } else {
                     if ( (lastUP-Fdn) > MP)
                       {
                        DN[i] = Fdn;
                        // Trend change from up to down
                        DownArrow[i] = high[i];
                       }
                     else {
                        if ( lastUP < Fup )
                          {
                           UP[lastUPbar] = EMPTY_VALUE;
                           UP[i] = Fup;
                          }
                       }
                    }
                  break;
               case -1 : //previous extremum is the bottom
                  if ( (Fup-Fdn) > MP )
                    {
                     if ( (Fup-lastDN) > MP )
                       {
                        UP[i] = Fup;
                        DN[i] = Fdn;
                        // Potential trend change from down to up to down again in same bar
                        // Add arrows for clarity - uncomment if needed for such edge cases
                        //UpArrow[i] = low[i];
                        //DownArrow[i] = high[i];
                       } else {
                        if (lastDN > Fdn)
                          {
                           DN[lastDNbar] = EMPTY_VALUE;
                           DN[i] = Fdn;
                          }
                       }
                    } else {
                     if ( (Fup-lastDN) > MP )
                       {
                        UP[i] = Fup;
                        // Trend change from down to up
                        UpArrow[i] = low[i];
                       }
                     else {
                        if ( lastDN > Fdn)
                          {
                           DN[lastDNbar] = EMPTY_VALUE;
                           DN[i]=Fdn;
                          }
                       }
                    }
                  break;
               default: break;
              } //switch LET
            break;
         
         default: break;
        } // end of switch (main)
     } // end of for (main)
   //--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
//| Function for the analysis                                        |
//+------------------------------------------------------------------+ 
int Comb(int i, double H, double L, double Fup, double Fdn)
{
   //----
   if (Fup==H && (Fdn==0 || (Fdn>0 && Fdn>L))) return(1);  //potential peak
   if (Fdn==L && (Fup==0 || (Fup>0 && Fup<H))) return(-1); //potential bottom
   if (Fdn==L && Fup==H)                                   //potential peak or bottom
     {
      OrderFormationBarHighLow OrderFormationHL = OFBError;
      // Find cached data in the OB[] buffer
      if (OB[i] == EMPTY_VALUE)
         OrderFormationHL = GetOrderFormationBarHighLow(Symbol(), Period(), i, iUseSmallerTFforEB);
         if (OrderFormationHL != OFBError)
            OB[i] = OrderFormationHL;
      else
         OrderFormationHL = (OrderFormationBarHighLow)OB[i];
      
      switch(OrderFormationHL)
        {
         case OFBLowHigh:       //Bull bar: Low first, High last
            return(2);
            break;
         case OFBHighLow:       //Bear bar: High first, Low last
            return(-2); 
            break;
        }
     }
   //----  
   return(0);           //
}
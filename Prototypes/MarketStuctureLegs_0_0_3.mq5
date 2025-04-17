//+------------------------------------------------------------------+
//|                                 AlexSTAL_ZigZagTrendArrows_Entry.mq5 |
//|                                         Copyright 2011, AlexSTAL |
//|            Modified to identify entry opportunities based on market structure |
//+------------------------------------------------------------------+
#property copyright "Copyright 2011, AlexSTAL"
#property link      "http://www.alexstal.ru"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   6
//---- plot Up Arrows for trend changes
#property indicator_label1  "Up Trend"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  Red         
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
//---- plot Down Arrows for trend changes
#property indicator_label2  "Down Trend"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  LimeGreen   
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3
//---- plot Entry Up Arrows 
#property indicator_label3  "Entry Long"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  Blue        
#property indicator_style3  STYLE_SOLID
#property indicator_width3  4
//---- plot Entry Down Arrows
#property indicator_label4  "Entry Short"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  Magenta      
#property indicator_style4  STYLE_SOLID
#property indicator_width4  4
//---- plot Price Lines for Entry Zones
#property indicator_label5  "Entry Zone High"
#property indicator_type5   DRAW_LINE
#property indicator_color5  Aqua
#property indicator_style5  STYLE_DOT
#property indicator_width5  1
#property indicator_label6  "Entry Zone Low"
#property indicator_type6   DRAW_LINE
#property indicator_color6  Pink
#property indicator_style6  STYLE_DOT
#property indicator_width6  1

#include "AlexSTAL_OutsideBar.mqh"

// Number of bars to calculate the extremums
// the value should be not less than 2
input uchar iExtPeriod = 24;           // Increased default period for 5-min chart
// Minimal distance between the neighbour peak and bottom (overwise it will skip)
input uchar iMinAmplitude = 15;        // Increased minimum amplitude
// Minimal price movement in points at the zeroth bar for recalculation of the indicator
input uchar iMinMotion = 0;
// Use more precise algorithm to calculate the ordering of the High/Low formation
input bool iUseSmallerTFforEB = true;
// Arrow size
input int iArrowSize = 3;
// Entry Arrow size
input int iEntryArrowSize = 3;
// Enable multi-timeframe analysis
input bool iUseMultiTimeframe = true;
// Higher timeframe for trend determination
input ENUM_TIMEFRAMES iHigherTimeframe = PERIOD_H1;  // Default to 1-hour
// Entry zone percentage (how much of candle range to use for entry zone)
input double iEntryZonePercent = 30;    // Default 30% of candle range
// Number of bars to maintain entry zones 
input int iEntryZoneBars = 5;           // Show entry zones for 5 bars

uchar ExtPeriod, MinAmplitude, MinMotion;

// Buffers of the indicator - we'll hide the zigzag lines
double UP[], DN[];
// Buffers for trend arrows
double UpArrow[], DownArrow[];
// Buffers for entry arrows
double EntryLongArrow[], EntryShortArrow[];
// Buffers for entry zone lines
double EntryZoneHigh[], EntryZoneLow[];
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

// Market structure variables
double lastHH = 0;
double lastLL = 0;
double prevHH = 0;
double prevLL = 0;
int lastHHbar = 0;
int lastLLbar = 0;
bool upTrend = false;
bool downTrend = false;

// Entry zone variables
datetime lastEntrySignalTime = 0;
double entryZoneHighPrice = 0;
double entryZoneLowPrice = 0;
int entryZoneType = 0;  // 0=none, 1=long, 2=short
int entryZoneBarsRemaining = 0;

// Multi-timeframe analysis variables
bool higherTFUpTrend = false;
bool higherTFDownTrend = false;

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
   // Entry arrow buffers
   SetIndexBuffer(4, EntryLongArrow, INDICATOR_DATA);
   SetIndexBuffer(5, EntryShortArrow, INDICATOR_DATA);
   // Entry zone line buffers
   SetIndexBuffer(6, EntryZoneHigh, INDICATOR_DATA);
   SetIndexBuffer(7, EntryZoneLow, INDICATOR_DATA);
   // Outside bar cache buffer
   SetIndexBuffer(8, OB, INDICATOR_CALCULATIONS);
   
   ArraySetAsSeries(UP, true);
   ArraySetAsSeries(DN, true);
   ArraySetAsSeries(UpArrow, true);
   ArraySetAsSeries(DownArrow, true);
   ArraySetAsSeries(EntryLongArrow, true);
   ArraySetAsSeries(EntryShortArrow, true);
   ArraySetAsSeries(EntryZoneHigh, true);
   ArraySetAsSeries(EntryZoneLow, true);
   ArraySetAsSeries(OB, true);

   // Set up arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow code
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow code
   PlotIndexSetInteger(2, PLOT_ARROW, 217); // Entry long code (diagonal arrow pointing to entry)
   PlotIndexSetInteger(3, PLOT_ARROW, 218); // Entry short code (diagonal arrow pointing to entry)
   
   // Set width (size) of the arrows
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, iArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, iArrowSize);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, iEntryArrowSize);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, iEntryArrowSize);

   //--- set short name and digits   
   PlotIndexSetString(0, PLOT_LABEL, "ZigZag Up Trend(" + (string)ExtPeriod + "," + (string)MinAmplitude + ")");
   PlotIndexSetString(1, PLOT_LABEL, "ZigZag Down Trend(" + (string)ExtPeriod + "," + (string)MinAmplitude + ")");
   PlotIndexSetString(2, PLOT_LABEL, "Entry Long");
   PlotIndexSetString(3, PLOT_LABEL, "Entry Short");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
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
//| Check for entry opportunities based on market structure          |
//+------------------------------------------------------------------+
void CheckForEntryOpportunity(int i, const double &high[], const double &low[], const double &open[], const double &close[])
{
   // Update entry zones - decrease remaining bars counter
   if(entryZoneBarsRemaining > 0)
   {
      entryZoneBarsRemaining--;
      
      // Draw the entry zone lines
      if(entryZoneBarsRemaining > 0)
      {
         EntryZoneHigh[i] = entryZoneHighPrice;
         EntryZoneLow[i] = entryZoneLowPrice;
      }
   }
   else
   {
      // Clear entry zones
      entryZoneHighPrice = 0;
      entryZoneLowPrice = 0;
      entryZoneType = 0;
   }

   // Check for Higher High/Higher Low in uptrend
   if(upTrend && UP[i] != EMPTY_VALUE)
   {
      // We found a new high point
      if(lastHH > 0)
      {
         prevHH = lastHH;
         lastHH = UP[i];
         
         // Check if it's a higher high
         if(lastHH > prevHH)
         {
            // This is the start of a HHHL sequence
            // Now we need to wait for a higher low to complete the pattern
         }
      }
      else
      {
         // First high point in the uptrend
         lastHH = UP[i];
         lastHHbar = i;
      }
   }
   
   // Check for Lower Low/Lower High in downtrend
   if(downTrend && DN[i] != EMPTY_VALUE)
   {
      // We found a new low point
      if(lastLL > 0)
      {
         prevLL = lastLL;
         lastLL = DN[i];
         
         // Check if it's a lower low
         if(lastLL < prevLL)
         {
            // This is the start of a LHLL sequence
            // Now we need to wait for a lower high to complete the pattern
         }
      }
      else
      {
         // First low point in the downtrend
         lastLL = DN[i];
         lastLLbar = i;
      }
   }
   
   // Entry long opportunity
   if(UpArrow[i] != EMPTY_VALUE)
   {
      upTrend = true;
      downTrend = false;
      
      // Check if this is a valid entry point
      // If the current low is still within the range of the previous swing high
      if(lastHH > 0 && low[i] > prevLL && high[i] < lastHH)
      {
         // Check higher timeframe alignment if enabled
         bool canEnterLong = true;
         if(iUseMultiTimeframe)
            canEnterLong = !higherTFDownTrend; // Only enter if higher TF isn't in a downtrend
         
         if(canEnterLong)
         {
            // Entry opportunity for long - place diagonal arrow pointing at the potential entry point
            // Placed at the bottom of the bar + a small offset to make arrow visible
            EntryLongArrow[i] = low[i];
            
            // Calculate the entry zone - this is where traders using lower timeframes should look for entries
            double candleRange = high[i] - low[i];
            double zoneSize = candleRange * (iEntryZonePercent / 100.0);
            
            // For long entries, zone is at the bottom portion of the candle
            entryZoneLowPrice = low[i];
            entryZoneHighPrice = low[i] + zoneSize;
            entryZoneType = 1; // Long entry
            entryZoneBarsRemaining = iEntryZoneBars;
            
            // Draw the entry zone lines
            EntryZoneHigh[i] = entryZoneHighPrice;
            EntryZoneLow[i] = entryZoneLowPrice;
         }
      }
   }
   
   // Entry short opportunity
   if(DownArrow[i] != EMPTY_VALUE)
   {
      downTrend = true;
      upTrend = false;
      
      // Check if this is a valid entry point
      // If the current high is still within the range of the previous swing low
      if(lastLL > 0 && high[i] < prevHH && low[i] > lastLL)
      {
         // Check higher timeframe alignment if enabled
         bool canEnterShort = true;
         if(iUseMultiTimeframe)
            canEnterShort = !higherTFUpTrend; // Only enter if higher TF isn't in an uptrend
         
         if(canEnterShort)
         {
            // Entry opportunity for short - place diagonal arrow pointing at the potential entry point
            // Placed at the top of the bar + a small offset to make arrow visible
            EntryShortArrow[i] = high[i];
            
            // Calculate the entry zone - this is where traders using lower timeframes should look for entries
            double candleRange = high[i] - low[i];
            double zoneSize = candleRange * (iEntryZonePercent / 100.0);
            
            // For short entries, zone is at the top portion of the candle
            entryZoneHighPrice = high[i];
            entryZoneLowPrice = high[i] - zoneSize;
            entryZoneType = 2; // Short entry
            entryZoneBarsRemaining = iEntryZoneBars;
            
            // Draw the entry zone lines
            EntryZoneHigh[i] = entryZoneHighPrice;
            EntryZoneLow[i] = entryZoneLowPrice;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check higher timeframe trend                                     |
//+------------------------------------------------------------------+
void CheckHigherTimeframeTrend()
{
   if(!iUseMultiTimeframe)
      return;
      
   // Get higher timeframe data
   MqlRates htf_rates[];
   ArraySetAsSeries(htf_rates, true);
   
   // Get most recent bars from higher timeframe
   int copied = CopyRates(Symbol(), iHigherTimeframe, 0, 30, htf_rates);
   
   if(copied > 0)
   {
      // Simple trend determination using moving average
      double ma_fast = 0, ma_slow = 0;
      
      // Calculate a simple 8-period MA
      for(int i = 0; i < 8 && i < copied; i++)
      {
         ma_fast += htf_rates[i].close;
      }
      ma_fast /= 8;
      
      // Calculate a simple 21-period MA
      for(int i = 0; i < 21 && i < copied; i++)
      {
         ma_slow += htf_rates[i].close;
      }
      ma_slow /= 21;
      
      // Determine trend based on MA relationship
      higherTFUpTrend = ma_fast > ma_slow;
      higherTFDownTrend = ma_fast < ma_slow;
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
      EntryLongArrow[i] = EMPTY_VALUE;
      EntryShortArrow[i] = EMPTY_VALUE;
      EntryZoneHigh[i] = EMPTY_VALUE;
      EntryZoneLow[i] = EMPTY_VALUE;
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
      ArrayInitialize(EntryLongArrow, EMPTY_VALUE);
      ArrayInitialize(EntryShortArrow, EMPTY_VALUE);
      ArrayInitialize(EntryZoneHigh, EMPTY_VALUE);
      ArrayInitialize(EntryZoneLow, EMPTY_VALUE);
      TimeFirstExtBar = 0;
      counted_bars = 0;
      LastBarTime = 0;
      DownloadHistory = false;
      
      // Reset market structure variables
      lastHH = 0;
      lastLL = 0;
      prevHH = 0;
      prevLL = 0;
      lastHHbar = 0;
      lastLLbar = 0;
      upTrend = false;
      downTrend = false;
      higherTFUpTrend = false;
      higherTFDownTrend = false;
     }
   
   // Check higher timeframe trend
   // Only check on first calculation or when a new bar forms
   bool isNewBar = (LastBarTime != time[0]);
   if(isNewBar || prev_calculated == 0)
      CheckHigherTimeframeTrend();
   
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
        
      // Check for entry opportunity after establishing trend arrows
      CheckForEntryOpportunity(i, high, low, open, close);
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
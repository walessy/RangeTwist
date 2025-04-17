//+------------------------------------------------------------------+
//|                                 ZigZag_Fibonacci_Entry.mq5       |
//|                                         Copyright 2011, AlexSTAL |
//|            Modified to use Fibonacci retracement entries         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2011, AlexSTAL"
#property link      "http://www.alexstal.ru"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 10
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
//---- plot Fibonacci 50% Level
#property indicator_label3  "Fib 50%"
#property indicator_type3   DRAW_LINE
#property indicator_color3  DodgerBlue        
#property indicator_style3  STYLE_DASH
#property indicator_width3  1
//---- plot Fibonacci 61.8% Level
#property indicator_label4  "Fib 61.8%"
#property indicator_type4   DRAW_LINE
#property indicator_color4  DeepPink     
#property indicator_style4  STYLE_DASH
#property indicator_width4  1
//---- plot Entry Signal
#property indicator_label5  "Entry Signal"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  Yellow     
#property indicator_style5  STYLE_SOLID
#property indicator_width5  3
//---- plot SubFib Entry Level
#property indicator_label6  "SubFib Entry Level"
#property indicator_type6   DRAW_LINE
#property indicator_color6  Gold
#property indicator_style6  STYLE_DASH
#property indicator_width6  2

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
// Enable multi-timeframe analysis
input bool iUseMultiTimeframe = true;
// Higher timeframe for trend determination
input ENUM_TIMEFRAMES iHigherTimeframe = PERIOD_H1;  // Default to 1-hour
// Smaller timeframe for sub-Fibonacci analysis (2 timeframes lower)
input ENUM_TIMEFRAMES iLowerTimeframe = PERIOD_M5;   // Default to 5-minute

uchar ExtPeriod, MinAmplitude, MinMotion;

// Buffers of the indicator - we'll hide the zigzag lines
double UP[], DN[];
// Buffers for trend arrows
double UpArrow[], DownArrow[];
// Buffers for Fibonacci levels
double Fib50Level[], Fib618Level[];
// Buffer for entry signal
double EntrySignal[];
// Buffer for sub-Fibonacci entry level
double SubFibEntryLevel[];
// Buffers for cache of the outside bar
double OB[];
// Buffer for price oscillation tracking
double OscillationFlag[];

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

// Fibonacci variables
double fibLevelHigh = 0;
double fibLevelLow = 0;
double fib50Level = 0;
double fib618Level = 0;
bool fibLevelsDrawn = false;
bool priceOscillated = false;
int legStartBar = 0;
int legEndBar = 0;

// Sub-Fibonacci variables
double subFibEntryLevel = 0;
bool subFibSignalGenerated = false;

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
   // Fibonacci level buffers
   SetIndexBuffer(4, Fib50Level, INDICATOR_DATA);
   SetIndexBuffer(5, Fib618Level, INDICATOR_DATA);
   // Entry signal buffer
   SetIndexBuffer(6, EntrySignal, INDICATOR_DATA);
   // Sub-Fibonacci entry level buffer
   SetIndexBuffer(7, SubFibEntryLevel, INDICATOR_DATA);
   // Outside bar cache buffer
   SetIndexBuffer(8, OB, INDICATOR_CALCULATIONS);
   // Oscillation flag buffer
   SetIndexBuffer(9, OscillationFlag, INDICATOR_CALCULATIONS);
   
   ArraySetAsSeries(UP, true);
   ArraySetAsSeries(DN, true);
   ArraySetAsSeries(UpArrow, true);
   ArraySetAsSeries(DownArrow, true);
   ArraySetAsSeries(Fib50Level, true);
   ArraySetAsSeries(Fib618Level, true);
   ArraySetAsSeries(EntrySignal, true);
   ArraySetAsSeries(SubFibEntryLevel, true);
   ArraySetAsSeries(OB, true);
   ArraySetAsSeries(OscillationFlag, true);

   // Set up arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow code
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow code
   PlotIndexSetInteger(4, PLOT_ARROW, 159); // Entry signal arrow code
   
   // Set width of the arrows and lines
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, iArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, iArrowSize);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, iArrowSize);

   //--- set short name and digits   
   PlotIndexSetString(0, PLOT_LABEL, "ZigZag Up Trend(" + (string)ExtPeriod + "," + (string)MinAmplitude + ")");
   PlotIndexSetString(1, PLOT_LABEL, "ZigZag Down Trend(" + (string)ExtPeriod + "," + (string)MinAmplitude + ")");
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
//| Draw Fibonacci Levels                                            |
//+------------------------------------------------------------------+
void DrawFibonacciLevels(int startBar, int endBar, bool isUptrend, 
                         const double &high[], const double &low[], int rates_total)
{
   if(startBar < 0 || endBar < 0 || startBar >= rates_total || endBar >= rates_total)
      return;
      
   // For uptrend, we measure from Low to High
   if(isUptrend)
   {
      fibLevelHigh = high[endBar];
      fibLevelLow = low[startBar];
   }
   // For downtrend, we measure from High to Low
   else
   {
      fibLevelHigh = high[startBar];
      fibLevelLow = low[endBar];
   }
   
   double fibRange = fibLevelHigh - fibLevelLow;
   
   // Calculate Fibonacci levels
   fib50Level = fibLevelLow + (fibRange * 0.5);
   fib618Level = fibLevelLow + (fibRange * 0.618);
   
   // Draw Fibonacci levels
   for(int i = endBar; i >= 0 && i > endBar - 100; i--)
   {
      Fib50Level[i] = fib50Level;
      Fib618Level[i] = fib618Level;
   }
   
   fibLevelsDrawn = true;
   priceOscillated = false;
   legStartBar = startBar;
   legEndBar = endBar;
}



//+------------------------------------------------------------------+
//| Check if price oscillates between 50% and 61.8% levels           |
//+------------------------------------------------------------------+
bool CheckPriceOscillation(int i, const double &high[], const double &low[])
{
   if(!fibLevelsDrawn)
      return false;
      
   // Check if price has touched both the 50% and 61.8% levels
   bool touchedFib50 = (high[i] >= fib50Level && low[i] <= fib50Level);
   bool touchedFib618 = (high[i] >= fib618Level && low[i] <= fib618Level);
   
   // If price is between the two levels, update the oscillation flag
   if(high[i] >= fib50Level && low[i] <= fib618Level)
   {
      OscillationFlag[i] = 1;
      
      // Check previous bars for oscillation between the two levels
      if(!priceOscillated)
      {
         int touchedFib50Count = 0;
         int touchedFib618Count = 0;
         
         for(int j = i+1; j <= i+20 && j < ArraySize(OscillationFlag); j++)
         {
            if(OscillationFlag[j] > 0)
            {
               // Check if price touched either level
               if(high[j] >= fib50Level && low[j] <= fib50Level)
                  touchedFib50Count++;
                  
               if(high[j] >= fib618Level && low[j] <= fib618Level)
                  touchedFib618Count++;
            }
         }
         
         // Determine if price has sufficiently oscillated between the levels
         if(touchedFib50Count > 0 && touchedFib618Count > 0)
         {
            priceOscillated = true;
            // Set the sub-Fibonacci entry level
            subFibEntryLevel = fib618Level;
            
            // Draw the sub-Fibonacci entry level
            for(int k = i; k >= 0 && k > i-50; k--)
            {
               SubFibEntryLevel[k] = subFibEntryLevel;
            }
            
            return true;
         }
      }
   }
   
   return priceOscillated;
}

//+------------------------------------------------------------------+
//| Check lower timeframe for entry confirmation                     |
//+------------------------------------------------------------------+
bool CheckLowerTimeframeConfirmation()
{
   if(!priceOscillated || subFibEntryLevel == 0)
      return false;
      
   // Get lower timeframe data
   MqlRates ltf_rates[];
   ArraySetAsSeries(ltf_rates, true);
   
   // Get most recent bars from lower timeframe
   int copied = CopyRates(Symbol(), iLowerTimeframe, 0, 30, ltf_rates);
   
   if(copied > 0)
   {
      // Track if price has touched both levels on lower timeframe
      bool ltfTouchedFib50 = false;
      bool ltfTouchedFib618 = false;
      
      // Check recent bars for oscillation between the sub-Fibonacci levels
      for(int i = 0; i < copied; i++)
      {
         if(ltf_rates[i].high >= fib50Level && ltf_rates[i].low <= fib50Level)
            ltfTouchedFib50 = true;
            
         if(ltf_rates[i].high >= fib618Level && ltf_rates[i].low <= fib618Level)
            ltfTouchedFib618 = true;
      }
      
      // If price has touched both levels on lower timeframe, confirm entry
      if(ltfTouchedFib50 && ltfTouchedFib618)
      {
         return true;
      }
   }
   
   return false;
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
//| Check for entry opportunities based on Fibonacci retracements    |
//+------------------------------------------------------------------+
void CheckForFibonacciEntry(int i, const double &high[], const double &low[], 
                            const double &open[], const double &close[])
{
   // If Fibonacci levels are drawn, check if price oscillates between 50% and 61.8%
   if(fibLevelsDrawn)
   {
      bool oscillated = CheckPriceOscillation(i, high, low);
      
      // If price has oscillated and we have confluence with higher timeframe trend
      if(oscillated && !subFibSignalGenerated)
      {
         bool higherTFConfluence = false;
         
         // Check for confluence with higher timeframe trend
         if(upTrend && !higherTFDownTrend)
            higherTFConfluence = true;
         else if(downTrend && !higherTFUpTrend)
            higherTFConfluence = true;
         
         // Check lower timeframe for confirmation
         bool lowerTFConfirmation = CheckLowerTimeframeConfirmation();
         
         // If all conditions are met, generate entry signal
         if(higherTFConfluence && lowerTFConfirmation)
         {
            EntrySignal[i] = close[i];
            subFibSignalGenerated = true;
         }
      }
   }
   
   // Update Fibonacci levels when trend changes
   if(UpArrow[i] != EMPTY_VALUE && lastHHbar > 0 && lastLLbar > 0)
   {
      // Trend change from down to up
      upTrend = true;
      downTrend = false;
      
      // Draw Fibonacci levels from the last Low to the new High
      DrawFibonacciLevels(lastLLbar, i, true, high, low, ArraySize(high));
      subFibSignalGenerated = false;
   }
   else if(DownArrow[i] != EMPTY_VALUE && lastHHbar > 0 && lastLLbar > 0)
   {
      // Trend change from up to down
      downTrend = true;
      upTrend = false;
      
      // Draw Fibonacci levels from the last High to the new Low
      DrawFibonacciLevels(lastHHbar, i, false, high, low, ArraySize(high));
      subFibSignalGenerated = false;
   }
   
   // Check for Higher High/Higher Low in uptrend
   if(upTrend && UP[i] != EMPTY_VALUE)
   {
      // We found a new high point
      if(lastHH > 0)
      {
         prevHH = lastHH;
         lastHH = UP[i];
         lastHHbar = i;
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
         lastLLbar = i;
      }
      else
      {
         // First low point in the downtrend
         lastLL = DN[i];
         lastLLbar = i;
      }
   }
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
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   
   int i;
   for (i = (rates_total-prev_calculated-1); i >= 0; i--)
     {
      UP[i] = EMPTY_VALUE;
      DN[i] = EMPTY_VALUE;
      OB[i] = EMPTY_VALUE;
      UpArrow[i] = EMPTY_VALUE;
      DownArrow[i] = EMPTY_VALUE;
      Fib50Level[i] = EMPTY_VALUE;
      Fib618Level[i] = EMPTY_VALUE;
      EntrySignal[i] = EMPTY_VALUE;
      SubFibEntryLevel[i] = EMPTY_VALUE;
      OscillationFlag[i] = 0;
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
      ArrayInitialize(Fib50Level, EMPTY_VALUE);
      ArrayInitialize(Fib618Level, EMPTY_VALUE);
      ArrayInitialize(EntrySignal, EMPTY_VALUE);
      ArrayInitialize(SubFibEntryLevel, EMPTY_VALUE);
      ArrayInitialize(OscillationFlag, 0);
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
      fibLevelsDrawn = false;
      priceOscillated = false;
      subFibSignalGenerated = false;
      higherTFUpTrend = false;
      higherTFDownTrend = false;
     }
   
   // check for the new bar
   bool isNewBar = (LastBarTime != time[0]);
   if (isNewBar)
     {
      LastBarTime = time[0];
      // zero variables
      LastBarLastHigh = high[0];
      LastBarLastLow = low[0];
     }
     
   // Check higher timeframe trend
   if(isNewBar || prev_calculated == 0)
      CheckHigherTimeframeTrend();

   // Check the bars, needed for the recalculation
   int BarsForRecalculation;
   if ( counted_bars != 0 )
     {
      BarsForRecalculation = rates_total - counted_bars;
      // Optimization of the calculations
      if (!isNewBar)
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
        
      // Check for Fibonacci entry opportunities
      CheckForFibonacciEntry(i, high, low, open, close);
     } // end of for (main)
   //--- return value of prev_calculated for next call
   return(rates_total);
}
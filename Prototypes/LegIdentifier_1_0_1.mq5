#property copyright "Amos"
#property link      "amoswales@gmail.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   5

// Plot settings for leg lines and labels
#property indicator_label1  "UpLeg"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "DownLeg"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "Peak"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrYellow
#property indicator_width3  2

#property indicator_label4  "Trough"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrCyan
#property indicator_width4  2

#property indicator_label5  "SignalPower"
#property indicator_type5   DRAW_HISTOGRAM
#property indicator_color5  clrOrange
#property indicator_width5  2

// Input parameters
enum LEG_DETECTION_MODE {
   MODE_MULTI_STOCH = 0,    // Multiple Stochastics
   MODE_RSI = 1,            // RSI Levels
   MODE_BBANDS = 2,         // Bollinger Bands
   MODE_CCI = 3,            // CCI Extremes
   MODE_FISHER = 4,         // Fisher Transform
   MODE_COMBINED = 5        // Combined Approach
};

input LEG_DETECTION_MODE  DetectionMode = MODE_COMBINED;  // Leg Detection Method
input int                 LookbackBars = 200;            // Analysis lookback period
input bool                ShowLegLabels = true;           // Show leg size labels
input bool                AutoCalculateRange = true;      // Auto calculate optimal range
input double              RangeSizeFactor = 0.4;          // Range size factor (0.2-0.6)

// Stochastic settings (used in multiple modes)
input int                 FastK = 5;                      // Fast Stochastic K period
input int                 MediumK = 14;                   // Medium Stochastic K period
input int                 SlowK = 21;                     // Slow Stochastic K period
input int                 StochSlowing = 3;               // Stochastic slowing
input int                 StochDPeriod = 3;               // Stochastic D period
input int                 OverBought = 80;                // Overbought level
input int                 OverSold = 20;                  // Oversold level

// RSI settings
input int                 FastRSI = 8;                    // Fast RSI period
input int                 MediumRSI = 14;                 // Medium RSI period
input int                 SlowRSI = 21;                   // Slow RSI period
input int                 RSI_UpperLevel = 70;            // RSI upper threshold
input int                 RSI_LowerLevel = 30;            // RSI lower threshold

// Bollinger Bands settings
input int                 BB_Period = 20;                 // Bollinger Bands period
input double              BB_Deviations = 2.0;            // Bollinger Bands deviations

// CCI settings
input int                 FastCCI = 14;                   // Fast CCI period
input int                 SlowCCI = 50;                   // Slow CCI period
input int                 CCI_Threshold = 100;            // CCI threshold level

// Fisher Transform settings
input int                 Fisher_Period = 10;             // Fisher Transform period
input double              Fisher_Threshold = 1.5;         // Fisher threshold level

// Indicator buffers
double UpLegBuffer[];
double DownLegBuffer[];
double PeakBuffer[];
double TroughBuffer[];
double SignalPowerBuffer[];
double AuxBuffer1[];
double AuxBuffer2[];
double AuxBuffer3[];
double AuxBuffer4[];
double AuxBuffer5[];

// Global variables
datetime legStartTime[];
datetime legEndTime[];
double legStartPrice[];
double legEndPrice[];
string legDirection[];
double legSize[];
int legCount = 0;

// For optimal range calculation
double totalLegSize = 0;
double averageLegSize = 0;
double optimalRangeSize = 0;

// Structure for signal strength
struct SignalStrength {
   bool isSignal;
   double strength;
   bool isPeak;
};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   SetIndexBuffer(0, UpLegBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DownLegBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, PeakBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, TroughBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SignalPowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, AuxBuffer1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, AuxBuffer2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, AuxBuffer3, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, AuxBuffer4, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, AuxBuffer5, INDICATOR_CALCULATIONS);
   
   // Set arrow codes
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // Peak arrow
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // Trough arrow
   
   // Set indicator name
   string modeName = "";
   switch(DetectionMode) {
      case MODE_MULTI_STOCH: modeName = "Multi-Stochastic"; break;
      case MODE_RSI: modeName = "RSI"; break;
      case MODE_BBANDS: modeName = "Bollinger Bands"; break;
      case MODE_CCI: modeName = "CCI"; break;
      case MODE_FISHER: modeName = "Fisher Transform"; break;
      case MODE_COMBINED: modeName = "Combined"; break;
   }
   IndicatorSetString(INDICATOR_SHORTNAME, "Leg Detector (" + modeName + ")");
   
   // Initialize arrays
   ArrayResize(legStartTime, 0);
   ArrayResize(legEndTime, 0);
   ArrayResize(legStartPrice, 0);
   ArrayResize(legEndPrice, 0);
   ArrayResize(legDirection, 0);
   ArrayResize(legSize, 0);
   legCount = 0;
   
   // Initialize calculation variables
   totalLegSize = 0;
   averageLegSize = 0;
   optimalRangeSize = 0;
   
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
   // Check if we have enough bars
   if(rates_total < LookbackBars) return(0);
   
   // Clear previous calculations if this is first call
   if(prev_calculated == 0) {
      ArrayInitialize(UpLegBuffer, EMPTY_VALUE);
      ArrayInitialize(DownLegBuffer, EMPTY_VALUE);
      ArrayInitialize(PeakBuffer, EMPTY_VALUE);
      ArrayInitialize(TroughBuffer, EMPTY_VALUE);
      ArrayInitialize(SignalPowerBuffer, EMPTY_VALUE);
      
      // Reset leg tracking
      ArrayResize(legStartTime, 0);
      ArrayResize(legEndTime, 0);
      ArrayResize(legStartPrice, 0);
      ArrayResize(legEndPrice, 0);
      ArrayResize(legDirection, 0);
      ArrayResize(legSize, 0);
      legCount = 0;
      
      // Clear chart objects
      ObjectsDeleteAll(0, "LegLabel_");
      ObjectsDeleteAll(0, "OptRange_");
   }
   
   // Determine start index for calculation
   int start = prev_calculated > 0 ? prev_calculated - 1 : LookbackBars;
   
   // Reset buffers for recalculation
   for(int i = start; i < rates_total; i++) {
      UpLegBuffer[i] = EMPTY_VALUE;
      DownLegBuffer[i] = EMPTY_VALUE;
      PeakBuffer[i] = EMPTY_VALUE;
      TroughBuffer[i] = EMPTY_VALUE;
      SignalPowerBuffer[i] = EMPTY_VALUE;
   }
   
   // Detect reversal points based on selected mode
   switch(DetectionMode) {
      case MODE_MULTI_STOCH:
         DetectLegsWithMultiStochastic(rates_total, start, time, high, low, close);
         break;
      case MODE_RSI:
         DetectLegsWithRSI(rates_total, start, time, high, low, close);
         break;
      case MODE_BBANDS:
         DetectLegsWithBollingerBands(rates_total, start, time, high, low, close);
         break;
      case MODE_CCI:
         DetectLegsWithCCI(rates_total, start, time, high, low, close);
         break;
      case MODE_FISHER:
         DetectLegsWithFisher(rates_total, start, time, high, low, close);
         break;
      case MODE_COMBINED:
         DetectLegsWithCombinedApproach(rates_total, start, time, high, low, close);
         break;
   }
   
   // Draw leg lines and calculate sizes
   DrawLegs();
   
   // Display statistics and recommended range
   if(legCount > 1) {
      DisplayLegStatistics();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Detect legs using multiple stochastic oscillators                |
//+------------------------------------------------------------------+
void DetectLegsWithMultiStochastic(const int rates_total, 
                                   const int start,
                                   const datetime &time[],
                                   const double &high[],
                                   const double &low[],
                                   const double &close[])
{
   // Calculate stochastic values
   for(int i = LookbackBars; i < rates_total; i++) {
      // Calculate fast stochastic
      double fastK = iStochastic(_Symbol, PERIOD_CURRENT, FastK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, i);
      double fastD = iStochastic(_Symbol, PERIOD_CURRENT, FastK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_SIGNAL, i);
      
      // Calculate medium stochastic
      double mediumK = iStochastic(_Symbol, PERIOD_CURRENT, MediumK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, i);
      double mediumD = iStochastic(_Symbol, PERIOD_CURRENT, MediumK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_SIGNAL, i);
      
      // Calculate slow stochastic
      double slowK = iStochastic(_Symbol, PERIOD_CURRENT, SlowK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, i);
      double slowD = iStochastic(_Symbol, PERIOD_CURRENT, SlowK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_SIGNAL, i);
      
      // Detect overbought/oversold conditions with confirmation
      SignalStrength signal = {false, 0, false};
      
      // Fast stochastic crossing down from overbought = potential peak
      if(fastK > OverBought && fastD > OverBought && fastK < fastD) {
         signal.strength += 0.3;
         signal.isPeak = true;
      }
      
      // Fast stochastic crossing up from oversold = potential trough
      if(fastK < OverSold && fastD < OverSold && fastK > fastD) {
         signal.strength += 0.3;
         signal.isPeak = false;
      }
      
      // Add medium stochastic confirmation
      if(mediumK > OverBought && mediumK < mediumD && signal.isPeak) {
         signal.strength += 0.3;
      }
      else if(mediumK < OverSold && mediumK > mediumD && !signal.isPeak) {
         signal.strength += 0.3;
      }
      
      // Add slow stochastic for major trend confirmation
      if(slowK > 50 && !signal.isPeak) {
         signal.strength += 0.2;
      }
      else if(slowK < 50 && signal.isPeak) {
         signal.strength += 0.2;
      }
      
      // Check if we have a strong enough signal
      if(signal.strength > 0.5) {
         signal.isSignal = true;
         
         // Save the signal
         if(signal.isPeak) {
            PeakBuffer[i] = high[i];
            RecordReversalPoint(time[i], high[i], true);
         }
         else {
            TroughBuffer[i] = low[i];
            RecordReversalPoint(time[i], low[i], false);
         }
         
         // Record signal strength
         SignalPowerBuffer[i] = signal.strength;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect legs using RSI                                            |
//+------------------------------------------------------------------+
void DetectLegsWithRSI(const int rates_total,
                       const int start,
                       const datetime &time[],
                       const double &high[],
                       const double &low[],
                       const double &close[])
{
   // Calculate RSI values
   for(int i = LookbackBars; i < rates_total; i++) {
      // Calculate three RSIs with different periods
      double fastRSIValue = iRSI(_Symbol, PERIOD_CURRENT, FastRSI, PRICE_CLOSE, i);
      double mediumRSIValue = iRSI(_Symbol, PERIOD_CURRENT, MediumRSI, PRICE_CLOSE, i);
      double slowRSIValue = iRSI(_Symbol, PERIOD_CURRENT, SlowRSI, PRICE_CLOSE, i);
      
      // Previous values
      double prevFastRSI = iRSI(_Symbol, PERIOD_CURRENT, FastRSI, PRICE_CLOSE, i+1);
      double prevMediumRSI = iRSI(_Symbol, PERIOD_CURRENT, MediumRSI, PRICE_CLOSE, i+1);
      
      // Detect overbought/oversold conditions with confirmation
      SignalStrength signal = {false, 0, false};
      
      // Fast RSI crossing down from overbought = potential peak
      if(prevFastRSI >= RSI_UpperLevel && fastRSIValue < RSI_UpperLevel) {
         signal.strength += 0.3;
         signal.isPeak = true;
      }
      
      // Fast RSI crossing up from oversold = potential trough
      if(prevFastRSI <= RSI_LowerLevel && fastRSIValue > RSI_LowerLevel) {
         signal.strength += 0.3;
         signal.isPeak = false;
      }
      
      // Add medium RSI confirmation
      if(prevMediumRSI >= 60 && mediumRSIValue < prevMediumRSI && signal.isPeak) {
         signal.strength += 0.3;
      }
      else if(prevMediumRSI <= 40 && mediumRSIValue > prevMediumRSI && !signal.isPeak) {
         signal.strength += 0.3;
      }
      
      // Add slow RSI for trend confirmation
      if(slowRSIValue > 50 && !signal.isPeak) {
         signal.strength += 0.2;
      }
      else if(slowRSIValue < 50 && signal.isPeak) {
         signal.strength += 0.2;
      }
      
      // Check if we have a strong enough signal
      if(signal.strength > 0.5) {
         signal.isSignal = true;
         
         // Save the signal
         if(signal.isPeak) {
            PeakBuffer[i] = high[i];
            RecordReversalPoint(time[i], high[i], true);
         }
         else {
            TroughBuffer[i] = low[i];
            RecordReversalPoint(time[i], low[i], false);
         }
         
         // Record signal strength
         SignalPowerBuffer[i] = signal.strength;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect legs using Bollinger Bands                                |
//+------------------------------------------------------------------+
void DetectLegsWithBollingerBands(const int rates_total,
                                 const int start,
                                 const datetime &time[],
                                 const double &high[],
                                 const double &low[],
                                 const double &close[])
{
   // Calculate BB values
   for(int i = LookbackBars; i < rates_total; i++) {
      // Get Bollinger Bands values
      double bbUpper = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviations, 0, PRICE_CLOSE, MODE_UPPER, i);
      double bbMiddle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviations, 0, PRICE_CLOSE, MODE_MAIN, i);
      double bbLower = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviations, 0, PRICE_CLOSE, MODE_LOWER, i);
      
      // Previous close
      double prevClose = close[i+1];
      double currClose = close[i];
      
      // Calculate %B
      double bbRange = bbUpper - bbLower;
      double percentB = bbRange > 0 ? (currClose - bbLower) / bbRange : 0.5;
      double prevPercentB = bbRange > 0 ? (prevClose - bbLower) / bbRange : 0.5;
      
      // Get RSI for confirmation
      double rsiValue = iRSI(_Symbol, PERIOD_CURRENT, MediumRSI, PRICE_CLOSE, i);
      
      // Detect conditions
      SignalStrength signal = {false, 0, false};
      
      // Price touching or exceeding upper band and starting to reverse
      if(high[i] >= bbUpper && currClose < prevClose && percentB < prevPercentB) {
         signal.strength += 0.4;
         signal.isPeak = true;
      }
      
      // Price touching or exceeding lower band and starting to reverse
      if(low[i] <= bbLower && currClose > prevClose && percentB > prevPercentB) {
         signal.strength += 0.4;
         signal.isPeak = false;
      }
      
      // Add RSI confirmation
      if(rsiValue > 70 && signal.isPeak) {
         signal.strength += 0.3;
      }
      else if(rsiValue < 30 && !signal.isPeak) {
         signal.strength += 0.3;
      }
      
      // Add trend direction
      if(currClose > bbMiddle && !signal.isPeak) {
         signal.strength += 0.2;
      }
      else if(currClose < bbMiddle && signal.isPeak) {
         signal.strength += 0.2;
      }
      
      // Check if we have a strong enough signal
      if(signal.strength > 0.5) {
         signal.isSignal = true;
         
         // Save the signal
         if(signal.isPeak) {
            PeakBuffer[i] = high[i];
            RecordReversalPoint(time[i], high[i], true);
         }
         else {
            TroughBuffer[i] = low[i];
            RecordReversalPoint(time[i], low[i], false);
         }
         
         // Record signal strength
         SignalPowerBuffer[i] = signal.strength;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect legs using CCI                                            |
//+------------------------------------------------------------------+
void DetectLegsWithCCI(const int rates_total,
                       const int start,
                       const datetime &time[],
                       const double &high[],
                       const double &low[],
                       const double &close[])
{
   // Calculate CCI values
   for(int i = LookbackBars; i < rates_total; i++) {
      // Get CCI values
      double fastCCIValue = iCCI(_Symbol, PERIOD_CURRENT, FastCCI, PRICE_TYPICAL, i);
      double slowCCIValue = iCCI(_Symbol, PERIOD_CURRENT, SlowCCI, PRICE_TYPICAL, i);
      
      // Previous values
      double prevFastCCI = iCCI(_Symbol, PERIOD_CURRENT, FastCCI, PRICE_TYPICAL, i+1);
      
      // Detect conditions
      SignalStrength signal = {false, 0, false};
      
      // Fast CCI crossing down from extreme high
      if(prevFastCCI > CCI_Threshold && fastCCIValue < prevFastCCI) {
         signal.strength += 0.4;
         signal.isPeak = true;
      }
      
      // Fast CCI crossing up from extreme low
      if(prevFastCCI < -CCI_Threshold && fastCCIValue > prevFastCCI) {
         signal.strength += 0.4;
         signal.isPeak = false;
      }
      
      // Add slow CCI confirmation
      if(slowCCIValue > 0 && !signal.isPeak) {
         signal.strength += 0.3;
      }
      else if(slowCCIValue < 0 && signal.isPeak) {
         signal.strength += 0.3;
      }
      
      // Add price action confirmation
      bool possibleReversal = false;
      
      if(signal.isPeak && close[i] < open[i] && close[i+1] > open[i+1]) {
         signal.strength += 0.2;
         possibleReversal = true;
      }
      else if(!signal.isPeak && close[i] > open[i] && close[i+1] < open[i+1]) {
         signal.strength += 0.2;
         possibleReversal = true;
      }
      
      // Check if we have a strong enough signal
      if(signal.strength > 0.5 && possibleReversal) {
         signal.isSignal = true;
         
         // Save the signal
         if(signal.isPeak) {
            PeakBuffer[i] = high[i];
            RecordReversalPoint(time[i], high[i], true);
         }
         else {
            TroughBuffer[i] = low[i];
            RecordReversalPoint(time[i], low[i], false);
         }
         
         // Record signal strength
         SignalPowerBuffer[i] = signal.strength;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect legs using Fisher Transform                               |
//+------------------------------------------------------------------+
void DetectLegsWithFisher(const int rates_total,
                         const int start,
                         const datetime &time[],
                         const double &high[],
                         const double &low[],
                         const double &close[])
{
   // Calculate Fisher values (simulated - actual Fisher requires custom calculation)
   double fisherValues[];
   ArrayResize(fisherValues, rates_total);
   
   // First pass - calculate normalized price
   double maxHigh = 0, minLow = DBL_MAX;
   for(int i = rates_total-1; i >= rates_total-Fisher_Period-10 && i >= 0; i--) {
      for(int j = 0; j < Fisher_Period && i+j < rates_total; j++) {
         maxHigh = MathMax(maxHigh, high[i+j]);
         minLow = MathMin(minLow, low[i+j]);
      }
      
      // Normalize price between -1 and 1
      double range = maxHigh - minLow;
      double value = range > 0 ? 2 * ((close[i] - minLow) / range - 0.5) : 0;
      
      // Apply Fisher Transform (simplified)
      fisherValues[i] = 0.5 * MathLog((1 + value) / (1 - value));
   }
   
   // Detect Fisher Transform reversals
   for(int i = LookbackBars; i < rates_total; i++) {
      double fisherValue = fisherValues[i];
      double prevFisher = fisherValues[i+1];
      double prevPrevFisher = fisherValues[i+2];
      
      // Get RSI for confirmation
      double rsiValue = iRSI(_Symbol, PERIOD_CURRENT, MediumRSI, PRICE_CLOSE, i);
      
      SignalStrength signal = {false, 0, false};
      
      // Fisher turning down from extreme high
      if(fisherValue < prevFisher && prevFisher > prevPrevFisher && prevFisher > Fisher_Threshold) {
         signal.strength += 0.5;
         signal.isPeak = true;
      }
      
      // Fisher turning up from extreme low
      if(fisherValue > prevFisher && prevFisher < prevPrevFisher && prevFisher < -Fisher_Threshold) {
         signal.strength += 0.5;
         signal.isPeak = false;
      }
      
      // Add RSI confirmation
      if(rsiValue > 70 && signal.isPeak) {
         signal.strength += 0.3;
      }
      else if(rsiValue < 30 && !signal.isPeak) {
         signal.strength += 0.3;
      }
      
      // Check if we have a strong enough signal
      if(signal.strength > 0.6) {
         signal.isSignal = true;
         
         // Save the signal
         if(signal.isPeak) {
            PeakBuffer[i] = high[i];
            RecordReversalPoint(time[i], high[i], true);
         }
         else {
            TroughBuffer[i] = low[i];
            RecordReversalPoint(time[i], low[i], false);
         }
         
         // Record signal strength
         SignalPowerBuffer[i] = signal.strength;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect legs using combined approach                              |
//+------------------------------------------------------------------+
void DetectLegsWithCombinedApproach(const int rates_total,
                                    const int start,
                                    const datetime &time[],
                                    const double &high[],
                                    const double &low[],
                                    const double &close[])
{
   // Keep track of signals from different indicators
   double signalStrengthPeak[];
   double signalStrengthTrough[];
   ArrayResize(signalStrengthPeak, rates_total);
   ArrayResize(signalStrengthTrough, rates_total);
   ArrayInitialize(signalStrengthPeak, 0);
   ArrayInitialize(signalStrengthTrough, 0);
   
   // 1. Stochastic Analysis
   for(int i = LookbackBars; i < rates_total; i++) {
      // Calculate fast stochastic
      double fastK = iStochastic(_Symbol, PERIOD_CURRENT, FastK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, i);
      double fastD = iStochastic(_Symbol, PERIOD_CURRENT, FastK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_SIGNAL, i);
      
      // Calculate medium stochastic
      double mediumK = iStochastic(_Symbol, PERIOD_CURRENT, MediumK, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, i);
      
      // Check overbought/oversold
      if(fastK > OverBought && fastK < fastD) {
         signalStrengthPeak[i] += 0.2;
      }
      if(fastK < OverSold && fastK > fastD) {
         signalStrengthTrough[i] += 0.2;
      }
      
      // Add medium stochastic confirmation
      if(mediumK > 60 && signalStrengthPeak[i] > 0) {
         signalStrengthPeak[i] += 0.1;
      }
      if(mediumK < 40 && signalStrengthTrough[i] > 0) {
         signalStrengthTrough[i] += 0.1;
      }
   }
   
   // 2. RSI Analysis
   for(int i = LookbackBars; i < rates_total; i++) {
      double rsiValue = iRSI(_Symbol, PERIOD_CURRENT, MediumRSI, PRICE_CLOSE, i);
      double prevRSI = iRSI(_Symbol, PERIOD_CURRENT, MediumRSI, PRICE_CLOSE, i+1);
      
      // RSI turning down from overbought
      if(prevRSI > RSI_UpperLevel && rsiValue < prevRSI) {
         signalStrengthPeak[i] += 0.2;
      }
      
      // RSI turning up from oversold
      if(prevRSI < RSI_LowerLevel && rsiValue > prevRSI) {
         signalStrengthTrough[i] += 0.2;
      }
   }
   
   // 3. Bollinger Bands Analysis
   for(int i = LookbackBars; i < rates_total; i++) {
      double bbUpper = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviations, 0, PRICE_CLOSE, MODE_UPPER, i);
      double bbLower = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Deviations, 0, PRICE_CLOSE, MODE_LOWER, i);
      
      // Price touching or exceeding upper band
      if(high[i] >= bbUpper) {
         signalStrengthPeak[i] += 0.2;
      }
      
      // Price touching or exceeding lower band
      if(low[i] <= bbLower) {
         signalStrengthTrough[i] += 0.2;
      }
   }
   
   // 4. CCI Analysis
   for(int i = LookbackBars; i < rates_total; i++) {
      double cciValue = iCCI(_Symbol, PERIOD_CURRENT, FastCCI, PRICE_TYPICAL, i);
      double prevCCI = iCCI(_Symbol, PERIOD_CURRENT, FastCCI, PRICE_TYPICAL, i+1);
      
      // CCI turning down from extreme level
      if(prevCCI > CCI_Threshold && cciValue < prevCCI) {
         signalStrengthPeak[i] += 0.15;
      }
      
      // CCI turning up from extreme level
      if(prevCCI < -CCI_Threshold && cciValue > prevCCI) {
         signalStrengthTrough[i] += 0.15;
      }
   }
   
   // 5. Price Action Confirmation
   for(int i = LookbackBars; i < rates_total; i++) {
      // Look for potential reversal candles when we have signals
      
      // Bearish engulfing or shooting star for peaks
      if(signalStrengthPeak[i] > 0) {
         if(close[i] < open[i] && close[i+1] > open[i+1] && open[i] > close[i+1]) {
            signalStrengthPeak[i] += 0.15;
         }
         // Shooting star pattern
         else if(close[i] < open[i] && (high[i] - MathMax(open[i], close[i])) > 2 * MathAbs(open[i] - close[i])) {
            signalStrengthPeak[i] += 0.15;
         }
      }
      
      // Bullish engulfing or hammer for troughs
      if(signalStrengthTrough[i] > 0) {
         if(close[i] > open[i] && close[i+1] < open[i+1] && open[i] < close[i+1]) {
            signalStrengthTrough[i] += 0.15;
         }
         // Hammer pattern
         else if(close[i] > open[i] && (MathMin(open[i], close[i]) - low[i]) > 2 * MathAbs(open[i] - close[i])) {
            signalStrengthTrough[i] += 0.15;
         }
      }
   }
   
   // Process combined signals
   for(int i = LookbackBars; i < rates_total; i++) {
      // Check for valid peak signals
      if(signalStrengthPeak[i] > 0.4) {
         PeakBuffer[i] = high[i];
         RecordReversalPoint(time[i], high[i], true);
         SignalPowerBuffer[i] = signalStrengthPeak[i];
      }
      
      // Check for valid trough signals
      if(signalStrengthTrough[i] > 0.4) {
         TroughBuffer[i] = low[i];
         RecordReversalPoint(time[i], low[i], false);
         SignalPowerBuffer[i] = signalStrengthTrough[i];
      }
   }
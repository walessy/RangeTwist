//+------------------------------------------------------------------+
//|                          FibStrategyFunctions.mqh                |
//|                                                                   |
//|  Shared functions for Fibonacci strategy detection                |
//|  Used by both the indicator and tester                            |
//+------------------------------------------------------------------+
//#property copyright "Copyright 2025"
//#property version   "1.0"

// Common global variables
double fibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.764, 1.0, 1.618, 2.618};
double subFibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.764, 1.0};

// Strategy state variables - shared between indicator and tester
bool condition1Met = false;
bool condition2Met = false;
bool condition3Met = false;
bool condition4Met = false;
bool entrySignal = false;

// Data for strategy detection
double highPoint = 0.0;      // High point for secondary Fibonacci
double lowPoint = 0.0;       // Low point for secondary Fibonacci
datetime highPointTime = 0;  // Time of high point
datetime lowPointTime = 0;   // Time of low point
double secondFibLevels[7];   // Store second Fibonacci level prices

// Settings for zone limits (can be overridden by indicator inputs)
double LowerZoneLimit = 0.5;    // Lower zone boundary (default 50%)
double UpperZoneLimit = 0.618;  // Upper zone boundary (default 61.8%)

//+------------------------------------------------------------------+
//| Initialize/reset the strategy detection state                     |
//+------------------------------------------------------------------+
void ResetStrategyState()
{
   condition1Met = false;
   condition2Met = false;
   condition3Met = false;
   condition4Met = false;
   entrySignal = false;
   highPoint = 0.0;
   lowPoint = 0.0;
   highPointTime = 0;
   lowPointTime = 0;
   ArrayInitialize(secondFibLevels, 0.0);
}

//+------------------------------------------------------------------+
//| Calculate a Fibonacci level based on previous day range           |
//+------------------------------------------------------------------+
double CalculateFibLevel(double fibRatio, double pdh, double pdl, bool pdBullish)
{
   double startPoint, endPoint;
   
   if(pdBullish) {
      // In bullish days, 0% is at the low, 100% at the high
      startPoint = pdl;   // 0% level
      endPoint = pdh;    // 100% level
   } else {
      // In bearish days, 0% is at the high, 100% at the low
      startPoint = pdh;  // 0% level
      endPoint = pdl;     // 100% level
   }
   
   return startPoint + (endPoint - startPoint) * fibRatio;
}

//+------------------------------------------------------------------+
//| Calculate the secondary Fibonacci levels                          |
//+------------------------------------------------------------------+
void CalculateSecondaryFibLevels(double highPt, double lowPt, bool pdBullish, bool verbose=false)
{
   // Determine the range direction based on previous day trend
   double secStartPoint, secEndPoint;
   
   if(pdBullish) {
      // In bullish trend, the secondary Fibonacci is from low to high
      secStartPoint = lowPt;
      secEndPoint = highPt;
   } else {
      // In bearish trend, the secondary Fibonacci is from high to low
      secStartPoint = highPt;
      secEndPoint = lowPt;
   }
   
   // Calculate all the level prices for the secondary Fibonacci
   for(int i = 0; i < ArraySize(subFibLevels); i++) {
      secondFibLevels[i] = secStartPoint + (secEndPoint - secStartPoint) * subFibLevels[i];
      
      if(verbose) Print("SecFib ", subFibLevels[i]*100, "% = ", secondFibLevels[i]);
   }
}

//+------------------------------------------------------------------+
//| Check if the strategy criteria are met                            |
//+------------------------------------------------------------------+
void CheckStrategyCriteria(const datetime &time[], 
                          const double &open[], 
                          const double &high[], 
                          const double &low[], 
                          const double &close[], 
                          const int rates_total,
                          double pdh, double pdl, bool pdBullish,
                          bool verbose=false)
{
   // Reset strategy state before checking conditions
   ResetStrategyState();
   
   // Calculate zone boundaries
   double lowerZone = CalculateFibLevel(LowerZoneLimit, pdh, pdl, pdBullish);
   double upperZone = CalculateFibLevel(UpperZoneLimit, pdh, pdl, pdBullish);
   
   // Track the state for Condition 2
   bool belowLowerZone = false;
   bool aboveUpperZone = false;
   bool backBelowLowerZone = false;
   
   // Arrays to store price zone location
   bool inZone[50];       // Is price in the target zone?
   bool aboveZone[50];    // Is price above the zone?
   bool belowZone[50];    // Is price below the zone?
   
   // Ensure our arrays are large enough
   int maxBars = MathMin(50, rates_total);
   
   // Analyze recent candles
   for(int i = maxBars-1; i >= 0; i--) {
      // Calculate the midpoint of each candle body
      double midpoint = (open[i] + close[i]) / 2.0;
      
      // Check if midpoint is in the target zone (50-60%)
      inZone[i] = (midpoint >= lowerZone && midpoint <= upperZone);
      aboveZone[i] = (midpoint > upperZone);
      belowZone[i] = (midpoint < lowerZone);
      
      // Check Condition 1: Price returns to 50-60% zone
      if(inZone[i] && !condition1Met) {
         condition1Met = true;
         if(verbose) Print("Condition 1 Met: Price returned to ", DoubleToString(LowerZoneLimit*100,1), 
                  "-", DoubleToString(UpperZoneLimit*100,1), "% zone at bar ", i);
      }
      
      // Track zone transitions for Condition 2
      if(belowZone[i] && !belowLowerZone && !backBelowLowerZone) {
         belowLowerZone = true;
         if(verbose) Print("First below zone detected at bar ", i);
      }
      else if(aboveZone[i] && belowLowerZone && !aboveUpperZone && !backBelowLowerZone) {
         aboveUpperZone = true;
         if(verbose) Print("Above upper zone detected at bar ", i);
         
         // Store the high point for Condition 3
         if(midpoint > highPoint || highPoint == 0) {
            highPoint = midpoint;
            highPointTime = time[i];
         }
      }
      else if(belowZone[i] && belowLowerZone && aboveUpperZone && !backBelowLowerZone) {
         backBelowLowerZone = true;
         if(verbose) Print("Second below zone detected at bar ", i);
         
         // Store the low point for Condition 3
         if(midpoint < lowPoint || lowPoint == 0) {
            lowPoint = midpoint;
            lowPointTime = time[i];
         }
      }
   }
   
   // Check if Condition 2 is met (all three transitions occurred)
   if(belowLowerZone && aboveUpperZone && backBelowLowerZone && !condition2Met) {
      condition2Met = true;
      if(verbose) Print("Condition 2 Met: Price made the required zone transitions");
      
      // Now Condition 3 can be met - we have high and low points
      if(highPoint > 0 && lowPoint > 0 && highPointTime > 0 && lowPointTime > 0) {
         condition3Met = true;
         if(verbose) Print("Condition 3 Met: Secondary Fibonacci points identified");
         
         // Calculate secondary Fibonacci levels for Condition 4
         CalculateSecondaryFibLevels(highPoint, lowPoint, pdBullish, verbose);
      }
   }
   
   // Check Condition 4: Price returns to 50-60% of the second Fibonacci
   if(condition3Met && !condition4Met) {
      // Get 50% and 61.8% levels from secondary Fibonacci
      double secLowerZone = secondFibLevels[3]; // 50%
      double secUpperZone = secondFibLevels[4]; // 61.8%
      
      // Ensure we have the levels in the correct order
      if(secLowerZone > secUpperZone) {
         double temp = secLowerZone;
         secLowerZone = secUpperZone;
         secUpperZone = temp;
      }
      
      // Check if current candle's midpoint is in the secondary zone
      double currentMidpoint = (open[0] + close[0]) / 2.0;
      
      if(currentMidpoint >= secLowerZone && currentMidpoint <= secUpperZone) {
         condition4Met = true;
         entrySignal = true;
         if(verbose) Print("Condition 4 Met: Price returned to secondary 50-61.8% zone");
      }
   }
}

//+------------------------------------------------------------------+
//| Helper function to convert color to ARGB with alpha               |
//+------------------------------------------------------------------+
uint ConvertColorToARGB(color clr, uchar alpha = 255)
{
   // Extract RGB components
   uchar r = (uchar)clr;
   uchar g = (uchar)(clr >> 8);
   uchar b = (uchar)(clr >> 16);
   
   // Combine with alpha
   return ((uint)alpha << 24) + ((uint)b << 16) + ((uint)g << 8) + r;
}
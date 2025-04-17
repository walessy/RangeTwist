//+------------------------------------------------------------------+
//| Liquidity Zone Indicator with Dynamic Thresholds                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// Stochastic Parameters
input int StochasticPeriod1 = 9;
input int StochasticPeriod2 = 14;
input int StochasticPeriod3 = 40;
input int StochasticPeriod4 = 60;

// Consolidation Parameters
input int ConsolidationBars = 10;    // Number of bars for consolidation detection
input double ImpulseFactor = 1.5;    // Factor to determine breakout strength

// ATR Parameters for Dynamic Thresholds
input int ATR_Period = 14;           // Period for ATR calculation
input double VolatilityFactor = 2.0; // Factor to adjust thresholds based on volatility
input int BaseThresholdLow = 20;     // Base lower threshold (default 20)
input int BaseThresholdHigh = 80;    // Base upper threshold (default 80)
input int MaxThresholdAdjustment = 10; // Maximum adjustment to thresholds

// Gradient parameters
input int GradientSteps = 5;             // Number of rectangles to create for gradient effect
input int GradientOpacityStart = 40;     // Starting opacity (0-255, where 0 is fully transparent)
input int GradientOpacityEnd = 10;       // Ending opacity (0-255)
input color BullishBaseColor = clrRoyalBlue;  // Base color for bullish zones
input color BearishBaseColor = clrCrimson;    // Base color for bearish zones

// Global variables
int stoch_handle1, stoch_handle2, stoch_handle3, stoch_handle4;
int atr_handle;
datetime prev_time;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize Stochastic indicator handles
    stoch_handle1 = iStochastic(Symbol(), Period(), StochasticPeriod1, 3, 1, MODE_SMA, STO_LOWHIGH);
    stoch_handle2 = iStochastic(Symbol(), Period(), StochasticPeriod2, 3, 1, MODE_SMA, STO_LOWHIGH);
    stoch_handle3 = iStochastic(Symbol(), Period(), StochasticPeriod3, 3, 1, MODE_SMA, STO_LOWHIGH);
    stoch_handle4 = iStochastic(Symbol(), Period(), StochasticPeriod4, 3, 1, MODE_SMA, STO_LOWHIGH);
    
    // Initialize ATR indicator handle
    atr_handle = iATR(Symbol(), Period(), ATR_Period);
    
    // Check if indicator handles were created successfully
    if(stoch_handle1 == INVALID_HANDLE || 
       stoch_handle2 == INVALID_HANDLE || 
       stoch_handle3 == INVALID_HANDLE || 
       stoch_handle4 == INVALID_HANDLE ||
       atr_handle == INVALID_HANDLE)
    {
        Print("Failed to create indicator handles");
        return(INIT_FAILED);
    }
    
    prev_time = 0;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(stoch_handle1);
    IndicatorRelease(stoch_handle2);
    IndicatorRelease(stoch_handle3);
    IndicatorRelease(stoch_handle4);
    IndicatorRelease(atr_handle);
    
    // Delete objects
    for(int i = 0; i < 200; i++)
    {
        // Delete both single rectangles (original implementation)
        ObjectDelete(0, "BullishZone_" + IntegerToString(i));
        ObjectDelete(0, "BearishZone_" + IntegerToString(i));
        
        // Delete gradient rectangles
        for(int j = 0; j < GradientSteps; j++)
        {
            ObjectDelete(0, "BullishZone_" + IntegerToString(i) + "_" + IntegerToString(j));
            ObjectDelete(0, "BearishZone_" + IntegerToString(i) + "_" + IntegerToString(j));
        }
    }
}

// Function to create a color with specific transparency
color ColorWithAlpha(color baseColor, int alpha)
{
    // Extract RGB components
    int r = baseColor & 0xFF;
    int g = (baseColor >> 8) & 0xFF;
    int b = (baseColor >> 16) & 0xFF;
    
    // Create new color with alpha (ARGB format)
    return (color)((alpha & 0xFF) << 24) | (r | (g << 8) | (b << 16));
}

// Function to draw gradient rectangles
void DrawGradientRectangle(string baseName, double high, double low, datetime time, color baseColor) 
{
    // Calculate time span for each rectangle
    int totalBars = ConsolidationBars;
    int barsPerStep = (int)MathMax(1, MathFloor(totalBars / GradientSteps));
    
    // Delete existing objects with this base name
    for(int i = 0; i < GradientSteps; i++)
    {
        string name = baseName + "_" + IntegerToString(i);
        ObjectDelete(0, name);
    }
    
    // Create gradient effect with multiple rectangles
    for(int i = 0; i < GradientSteps; i++)
    {
        string name = baseName + "_" + IntegerToString(i);
        
        // Calculate transparency for this step
        double alphaRatio = (double)i / (GradientSteps - 1);
        int alpha = (int)(GradientOpacityStart + (GradientOpacityEnd - GradientOpacityStart) * alphaRatio);
        color rectColor = ColorWithAlpha(baseColor, alpha);
        
        // Calculate start and end times for this rectangle
        datetime rectStartTime = time + (i * barsPerStep * PeriodSeconds());
        datetime rectEndTime = rectStartTime + (barsPerStep * PeriodSeconds());
        
        // Create the rectangle
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, rectStartTime, high, rectEndTime, low);
        ObjectSetInteger(0, name, OBJPROP_COLOR, rectColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    }
}

// Function to get Stochastic %K value
double Stoch(int handle, int shift) 
{
    double stoch_buffer[];
    if(CopyBuffer(handle, 0, shift, 1, stoch_buffer) <= 0) 
        return -1;
    
    return stoch_buffer[0];
}

// Function to get ATR value
double GetATR(int shift)
{
    double atr_buffer[];
    if(CopyBuffer(atr_handle, 0, shift, 1, atr_buffer) <= 0)
        return -1;
        
    return atr_buffer[0];
}

// Function to calculate average ATR for normalization
double GetAverageATR(int period, int shift)
{
    double atr_buffer[];
    if(CopyBuffer(atr_handle, 0, shift, period, atr_buffer) <= 0)
        return -1;
    
    double sum = 0;
    for(int i = 0; i < period; i++)
    {
        sum += atr_buffer[i];
    }
    
    return sum / period;
}

// Function to calculate dynamic thresholds based on volatility
void GetDynamicThresholds(int shift, double &lowThreshold, double &highThreshold)
{
    // Get current ATR
    double currentATR = GetATR(shift);
    if(currentATR == -1)
    {
        // Fallback to default thresholds if ATR calculation fails
        lowThreshold = BaseThresholdLow;
        highThreshold = BaseThresholdHigh;
        return;
    }
    
    // Get average ATR for the last 50 periods for normalization
    double avgATR = GetAverageATR(50, shift);
    if(avgATR == -1 || avgATR == 0)
    {
        lowThreshold = BaseThresholdLow;
        highThreshold = BaseThresholdHigh;
        return;
    }
    
    // Calculate volatility ratio
    double volatilityRatio = currentATR / avgATR;
    
    // Adjust thresholds based on volatility
    // Higher volatility = wider thresholds
    double adjustment = MathMin(MaxThresholdAdjustment, 
                              (volatilityRatio - 1.0) * VolatilityFactor * 10);
    
    // Apply adjustments
    lowThreshold = MathMax(5, BaseThresholdLow - adjustment);
    highThreshold = MathMin(95, BaseThresholdHigh + adjustment);
    
    Print("Current ATR: ", currentATR, " Avg ATR: ", avgATR, 
          " Volatility Ratio: ", volatilityRatio,
          " Thresholds: ", lowThreshold, "/", highThreshold);
}

// Function to confirm breakout with Stochastic indicators using dynamic thresholds
bool StochasticConfirm(bool isBullish, int shift) 
{
    int count = 0;

    double s1 = Stoch(stoch_handle1, shift);
    double s2 = Stoch(stoch_handle2, shift);
    double s3 = Stoch(stoch_handle3, shift);
    double s4 = Stoch(stoch_handle4, shift);
    
    if(s1 == -1 || s2 == -1 || s3 == -1 || s4 == -1)
        return false;

    // Get dynamic thresholds based on current market volatility
    double lowThreshold, highThreshold;
    GetDynamicThresholds(shift, lowThreshold, highThreshold);

    if(isBullish) 
    {
        if(s1 < lowThreshold) count++;  // Fastest stochastic must confirm
        if(s2 < lowThreshold) count++;
        if(s3 < lowThreshold) count++;
        if(s4 < lowThreshold) count++;
    } 
    else 
    {
        if(s1 > highThreshold) count++;  // Fastest stochastic must confirm
        if(s2 > highThreshold) count++;
        if(s3 > highThreshold) count++;
        if(s4 > highThreshold) count++;
    }

    return count >= 2;  // Require at least 2 confirmations
}

// Function to check for order blocks
void CheckOrderBlocks() 
{
    int bars = Bars(Symbol(), Period());
    if(bars < ConsolidationBars) return;
    
    MqlRates rates[];
    if(CopyRates(Symbol(), Period(), 0, bars, rates) <= 0)
        return;
    
    for(int i = bars - ConsolidationBars - 1; i >= 0; i--) 
    {
        // Find highest high and lowest low in the consolidation range
        int highest_idx = i;
        int lowest_idx = i;
        double high = rates[i].high;
        double low = rates[i].low;
        
        for(int j = 0; j < ConsolidationBars; j++)
        {
            if(i+j >= bars) break;
            
            if(rates[i+j].high > high)
            {
                high = rates[i+j].high;
                highest_idx = i+j;
            }
            
            if(rates[i+j].low < low)
            {
                low = rates[i+j].low;
                lowest_idx = i+j;
            }
        }

        // Check if we have enough bars for the condition
        if(i - ConsolidationBars < 0) continue;
        
        if(rates[i - ConsolidationBars].close > high && StochasticConfirm(true, i)) 
        {
            //Print("Bullish Liquidity Zone at Bar:", i);
            DrawGradientRectangle("BullishZone_" + IntegerToString(i), high, low, rates[i].time, BullishBaseColor);
        } 
        else if(rates[i - ConsolidationBars].close < low && StochasticConfirm(false, i)) 
        {
            //Print("Bearish Liquidity Zone at Bar:", i);
            DrawGradientRectangle("BearishZone_" + IntegerToString(i), high, low, rates[i].time, BearishBaseColor);
        }
    }
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
    if(rates_total < ConsolidationBars) return 0;  // Ensure enough bars exist
    
    // Only run on new bars to improve performance
    if(prev_time == time[0])
        return rates_total;
        
    prev_time = time[0];

    CheckOrderBlocks();
    
    return rates_total;
}
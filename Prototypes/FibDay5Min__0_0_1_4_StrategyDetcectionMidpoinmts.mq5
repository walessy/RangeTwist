//+------------------------------------------------------------------+
//|                          FibDay5Min_StrategyDetection.mq5        |
//|                                                                   |
//|  Draws horizontal lines based on previous day's OHLC              |
//|  - Previous day high/low lines (solid/dashed based on direction)  |
//|  - Fibonacci levels between previous day's high and low           |
//|  - Sub-Fibonacci trend lines with configurable points             |
//|  - Lines are truncated to only show on current day                |
//|  - Detects and highlights strategy conditions using candle bodies |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.20"
#property indicator_chart_window
#property indicator_plots   0

// Input parameters for original functionality
input bool  UseDirectionalColors = true;   // Use direction-based colors (Bull/Bear)
input color BullishColor = clrSkyBlue;     // Color for Bullish Days
input color BearishColor = clrMaroon;      // Color for Bearish Days
input color LineColor = clrDodgerBlue;     // Default Line Color (if not using directional)
input bool  ShowFibLevels = true;          // Show Fibonacci Levels
input bool  Show0Level = true;             // Show 0% Level
input bool  Show23_6Level = true;          // Show 23.6% Level
input bool  Show38_2Level = true;          // Show 38.2% Level
input bool  Show50Level = true;            // Show 50% Level
input bool  Show61_8Level = true;          // Show 61.8% Level
input bool  Show76_4Level = true;          // Show 76.4% Level
input bool  Show100Level = true;           // Show 100% Level
input bool  Show161_8Level = false;        // Show 161.8% Level
input bool  Show261_8Level = false;        // Show 261.8% Level
input bool  ShowLabels = true;             // Show Price Labels on Lines
input color LabelColor = clrBrown;         // Label Text Color
input int   LabelFontSize = 8;             // Label Font Size

// Input parameters for sub-Fibonacci trend lines
input bool   AlwaysShowSubFib = false; 
input string SubFibSection = "--- Sub-Fibonacci Settings ---"; // Sub-Fibonacci Settings
input bool   ShowSubFib = true;            // Show Sub-Fibonacci Trend Lines
input double StartPoint = 0.5;             // Starting Point for Sub-Fibonacci (0-1)
input double EndPoint = 0.618;             // Ending Point for Sub-Fibonacci (0-1)
input bool   UseCustomSubFibColor = false; // Use custom Sub-Fibonacci color (or inherit from main)
input color  SubFibColor = clrMagenta;     // Custom Sub-Fibonacci Lines Color (if enabled)
input double SubFibLineLength = 0.5;       // Length of Sub-Fib lines (0-1 ratio of day)
input double SubFibStartOffset = 0.25;     // Start offset for Sub-Fib lines (0-1 ratio of day)
input bool   ShowSubFib0Level = true;      // Show Sub-Fib 0% Level
input bool   ShowSubFib23_6Level = true;   // Show Sub-Fib 23.6% Level
input bool   ShowSubFib38_2Level = true;   // Show Sub-Fib 38.2% Level
input bool   ShowSubFib50Level = true;     // Show Sub-Fib 50% Level
input bool   ShowSubFib61_8Level = true;   // Show Sub-Fib 61.8% Level
input bool   ShowSubFib76_4Level = true;   // Show Sub-Fib 76.4% Level
input bool   ShowSubFib100Level = true;    // Show Sub-Fib 100% Level
input bool   ShowSubFibLabels = true;      // Show Sub-Fib Labels

// New input parameters for strategy detection
input string StrategySection = "--- Strategy Detection Settings ---"; // Strategy Detection Settings
input bool   EnableStrategyDetection = true;  // Enable strategy condition detection
input bool   DrawCandleMidpoints = true;      // Draw midpoints for candle bodies
input color  MidpointColor = clrPurple;       // Color for candle midpoint lines
input int    LookbackCandles = 20;            // Number of candles to look back for conditions
input bool   HighlightEntryZone = true;       // Highlight the entry zone when detected
input color  EntryZoneColor = clrLime;        // Color for the entry zone highlight
input double UpperZoneLimit = 0.6;            // Upper limit for zone (default 60%)
input double LowerZoneLimit = 0.5;            // Lower limit for zone (default 50%)
input bool   ShowEntryArrow = true;           // Show arrow at entry point
input color  EntryArrowColor = clrRed;        // Color for entry arrow

// Global variables
datetime prevDayTime = 0;
datetime todayStartTime = 0;
datetime nextDayStartTime = 0;
double prevDayHigh = 0;
double prevDayLow = 0;
bool prevDayBullish = true;
string currentSymbol = "";  // Track current symbol
bool showLevels[9] = {true, true, true, true, true, true, true, false, false};
bool showSubFibLevels[7] = {false, false, false, false, false, false, false};

// Fibonacci levels array
double fibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.764, 1.0, 1.618, 2.618};
double subFibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.764, 1.0};

// Strategy detection variables
bool condition1Met = false;  // Price returned to 50-60% zone
bool condition2Met = false;  // 3 transitions occurred (below 50%, above 60%, below 50%)
bool condition3Met = false;  // Second Fibonacci drawn
bool condition4Met = false;  // Price returned to 50-60% of second Fibonacci
double highPoint = 0.0;      // High point for secondary Fibonacci
double lowPoint = 0.0;       // Low point for secondary Fibonacci
datetime highPointTime = 0;  // Time of high point
datetime lowPointTime = 0;   // Time of low point
double secondFibLevels[7];   // Store second Fibonacci level prices
bool entrySignal = false;    // Entry signal detected

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set which levels to show based on input parameters
    showLevels[0] = Show0Level;
    showLevels[1] = Show23_6Level;
    showLevels[2] = Show38_2Level;
    showLevels[3] = Show50Level;
    showLevels[4] = Show61_8Level;
    showLevels[5] = Show76_4Level;
    showLevels[6] = Show100Level;
    showLevels[7] = Show161_8Level;
    showLevels[8] = Show261_8Level;
    
    // Set which sub-fib levels to show
    showSubFibLevels[0] = ShowSubFib0Level;
    showSubFibLevels[1] = ShowSubFib23_6Level;
    showSubFibLevels[2] = ShowSubFib38_2Level;
    showSubFibLevels[3] = ShowSubFib50Level;
    showSubFibLevels[4] = ShowSubFib61_8Level;
    showSubFibLevels[5] = ShowSubFib76_4Level;
    showSubFibLevels[6] = ShowSubFib100Level;
    
    // Validate start and end points
    if(StartPoint < 0 || StartPoint > 1 || EndPoint < 0 || EndPoint > 1)
    {
        Print("Warning: Start and End points must be between 0 and 1. Using default values.");
        // Keep the defaults as they are already set in the input parameters
    }
    
    // Validate zone limits
    if(LowerZoneLimit < 0 || LowerZoneLimit > 1 || UpperZoneLimit < 0 || UpperZoneLimit > 1 || LowerZoneLimit >= UpperZoneLimit)
    {
        Print("Warning: Zone limits must be between 0 and 1, and lower limit must be less than upper limit. Using default values.");
        // Keep the defaults as they are already set in the input parameters
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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
    // Check if we need to update previous day's data
    datetime currentDay = iTime(Symbol(), PERIOD_D1, 0);
    string symbol = Symbol();
    
    // Force redraw if symbol has changed or day has changed
    if(prevDayTime != currentDay || currentSymbol != symbol)
    {
        // Reset strategy detection variables
        condition1Met = false;
        condition2Met = false;
        condition3Met = false;
        condition4Met = false;
        entrySignal = false;
        highPoint = 0.0;
        lowPoint = 0.0;
        highPointTime = 0;
        lowPointTime = 0;
        
        // Update current symbol
        currentSymbol = symbol;
        
        // Get yesterday's OHLC data
        datetime yesterdayTime = iTime(Symbol(), PERIOD_D1, 1);
        double yesterdayOpen = iOpen(Symbol(), PERIOD_D1, 1);
        double yesterdayHigh = iHigh(Symbol(), PERIOD_D1, 1);
        double yesterdayLow = iLow(Symbol(), PERIOD_D1, 1);
        double yesterdayClose = iClose(Symbol(), PERIOD_D1, 1);
        
        // Determine if previous day was bullish or bearish
        prevDayBullish = (yesterdayClose > yesterdayOpen);
        
        // Update high, low and time
        prevDayHigh = yesterdayHigh;
        prevDayLow = yesterdayLow;
        prevDayTime = currentDay;
        
        // Get today's start time and next day's start time for truncation
        todayStartTime = iTime(Symbol(), PERIOD_D1, 0);
        
        // Calculate next day's start time (approximate)
        MqlDateTime today_struct;
        TimeToStruct(todayStartTime, today_struct);
        today_struct.day += 1;  // Add one day
        nextDayStartTime = StructToTime(today_struct);
        
        // Clear previous lines
        ObjectsDeleteAll(0, "PrevDay_");
        ObjectsDeleteAll(0, "SubFib_");
        ObjectsDeleteAll(0, "Label_");
        ObjectsDeleteAll(0, "MidPoint_");
        ObjectsDeleteAll(0, "Strategy_");
        ObjectsDeleteAll(0, "Entry_");
        
        // Create the original high and low lines
        if(Show100Level)
        {
            // Skip creating separate high/low lines since we'll draw them as part of the Fibonacci levels
        }
        else
        {
            CreateHorizontalLine("PrevDay_High", prevDayHigh, prevDayBullish ? STYLE_SOLID : STYLE_DASH, 
                                "Previous Day High: " + DoubleToString(prevDayHigh, Digits()));
            
            CreateHorizontalLine("PrevDay_Low", prevDayLow, prevDayBullish ? STYLE_DASH : STYLE_SOLID, 
                                "Previous Day Low: " + DoubleToString(prevDayLow, Digits()));
        }
        
        // Create Fibonacci levels if enabled
        if(ShowFibLevels)
        {
            // Calculate the range
            double range = MathAbs(prevDayHigh - prevDayLow);
            
            // Define start and end points for the retracement
            double startPoint, endPoint;
            
            if(prevDayBullish)
            {
                // In bullish days, 0% is at the low, 100% at the high
                startPoint = prevDayLow;   // 0% level
                endPoint = prevDayHigh;    // 100% level
            }
            else
            {
                // In bearish days, 0% is at the high, 100% at the low
                startPoint = prevDayHigh;  // 0% level
                endPoint = prevDayLow;     // 100% level
            }
            
            // Loop through each Fibonacci level
            for(int i = 0; i < ArraySize(fibLevels); i++)
            {
                // Skip if this level is not enabled
                if(!showLevels[i]) continue;
                
                // Calculate the price for this level
                double levelPrice = startPoint + (endPoint - startPoint) * fibLevels[i];
                
                // Create the horizontal line
                string levelName = "PrevDay_Fib_" + DoubleToString(fibLevels[i] * 100, 1);

                // Use solid line style for all main Fibonacci levels
                ENUM_LINE_STYLE lineStyle = STYLE_SOLID;
                    
                CreateHorizontalLine(levelName, levelPrice, lineStyle, 
                                    "Fib " + DoubleToString(fibLevels[i] * 100, 1) + "%: " + 
                                    DoubleToString(levelPrice, Digits()));
            }
        }
    }
    
    // Draw candle midpoints if enabled and we have enough data
    if(DrawCandleMidpoints && rates_total > 3)
    {
        // Delete previous midpoint lines
        ObjectsDeleteAll(0, "MidPoint_");
        
        // Limit the number of midpoint lines to draw to avoid clutter
        int maxLines = MathMin(LookbackCandles, rates_total-1);
        
        for(int i = 0; i < maxLines; i++)
        {
            // Calculate midpoint of the candle body
            double midpoint = (open[i] + close[i]) / 2.0;
            
            // Create a midpoint line
            string midpointName = "MidPoint_" + IntegerToString(i);
            
            // Draw a short horizontal line at the midpoint
            datetime lineStartTime = time[i] - PeriodSeconds() / 4;
            datetime lineEndTime = time[i] + PeriodSeconds() / 4;
            
            ObjectCreate(0, midpointName, OBJ_TREND, 0, lineStartTime, midpoint, lineEndTime, midpoint);
            ObjectSetInteger(0, midpointName, OBJPROP_COLOR, MidpointColor);
            ObjectSetInteger(0, midpointName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, midpointName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, midpointName, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, midpointName, OBJPROP_RAY_RIGHT, false);
            ObjectSetString(0, midpointName, OBJPROP_TOOLTIP, "Midpoint: " + DoubleToString(midpoint, Digits()));
        }
    }
    
    // Apply strategy detection logic if enabled
    if(EnableStrategyDetection && rates_total > LookbackCandles)
    {
        // Check for all conditions
        CheckStrategyCriteria(time, open, high, low, close, rates_total);
        
        // Draw the strategy detection visuals if conditions are met
        if(condition3Met)
        {
            // Create the second Fibonacci retracement (Condition 3)
            CreateSecondaryFibonacci(highPoint, lowPoint, highPointTime, lowPointTime);
        }
        
        // Check for entry signal
        if(condition4Met && !entrySignal)
        {
            // Signal detected
            entrySignal = true;
            
            // Draw entry arrow if enabled
            if(ShowEntryArrow)
            {
                // Create an arrow at the entry point
                string entryName = "Entry_Arrow";
                ObjectCreate(0, entryName, OBJ_ARROW, 0, time[0], close[0]);
                ObjectSetInteger(0, entryName, OBJPROP_ARROWCODE, prevDayBullish ? 217 : 218); // Up/Down arrow
                ObjectSetInteger(0, entryName, OBJPROP_COLOR, EntryArrowColor);
                ObjectSetInteger(0, entryName, OBJPROP_WIDTH, 2);
                ObjectSetInteger(0, entryName, OBJPROP_SELECTABLE, false);
            }
            
            // Create text label for entry signal
            string entryLabelName = "Entry_Label";
            ObjectCreate(0, entryLabelName, OBJ_TEXT, 0, time[0], close[0]);
            ObjectSetString(0, entryLabelName, OBJPROP_TEXT, "ENTRY SIGNAL (" + 
                           (prevDayBullish ? "Buy" : "Sell") + ")");
            ObjectSetInteger(0, entryLabelName, OBJPROP_COLOR, EntryArrowColor);
            ObjectSetInteger(0, entryLabelName, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, entryLabelName, OBJPROP_SELECTABLE, false);
            
            // Print alert
            Print("Strategy Entry Signal: ", (prevDayBullish ? "Buy" : "Sell"), " at ", DoubleToString(close[0], Digits()));
        }
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Check if the strategy criteria are met                            |
//+------------------------------------------------------------------+
void CheckStrategyCriteria(const datetime &time[], 
                          const double &open[], 
                          const double &high[], 
                          const double &low[], 
                          const double &close[], 
                          const int rates_total)
{
    // Calculate Fibonacci levels
    double range = MathAbs(prevDayHigh - prevDayLow);
    double startPoint, endPoint;
    
    if(prevDayBullish)
    {
        startPoint = prevDayLow;   // 0% level
        endPoint = prevDayHigh;    // 100% level
    }
    else
    {
        startPoint = prevDayHigh;  // 0% level
        endPoint = prevDayLow;     // 100% level
    }
    
    // Calculate zone boundaries
    double lowerZone = startPoint + (endPoint - startPoint) * LowerZoneLimit;
    double upperZone = startPoint + (endPoint - startPoint) * UpperZoneLimit;
    
    // Track the state for Condition 2
    bool belowLowerZone = false;
    bool aboveUpperZone = false;
    bool backBelowLowerZone = false;
    
    // Arrays to store price zone location
    bool inZone[20];       // Is price in the target zone?
    bool aboveZone[20];    // Is price above the zone?
    bool belowZone[20];    // Is price below the zone?
    
    // Analyze recent candles
    for(int i = MathMin(LookbackCandles-1, rates_total-1); i >= 0; i--)
    {
        // Calculate the midpoint of each candle body
        double midpoint = (open[i] + close[i]) / 2.0;
        
        // Check if midpoint is in the target zone (50-60%)
        inZone[i] = (midpoint >= lowerZone && midpoint <= upperZone);
        aboveZone[i] = (midpoint > upperZone);
        belowZone[i] = (midpoint < lowerZone);
        
        // Check Condition 1: Price returns to 50-60% zone
        if(inZone[i] && !condition1Met)
        {
            condition1Met = true;
            Print("Condition 1 Met: Price returned to ", DoubleToString(LowerZoneLimit*100,1), 
                  "-", DoubleToString(UpperZoneLimit*100,1), "% zone at bar ", i);
        }
        
        // Track zone transitions for Condition 2
        if(belowZone[i] && !belowLowerZone && !backBelowLowerZone)
        {
            belowLowerZone = true;
        }
        else if(aboveZone[i] && belowLowerZone && !aboveUpperZone && !backBelowLowerZone)
        {
            aboveUpperZone = true;
            // Store the high point for Condition 3
            if(midpoint > highPoint || highPoint == 0)
            {
                highPoint = midpoint;
                highPointTime = time[i];
            }
        }
        else if(belowZone[i] && belowLowerZone && aboveUpperZone && !backBelowLowerZone)
        {
            backBelowLowerZone = true;
            // Store the low point for Condition 3
            if(midpoint < lowPoint || lowPoint == 0)
            {
                lowPoint = midpoint;
                lowPointTime = time[i];
            }
        }
    }
    
    // Check if Condition 2 is met (all three transitions occurred)
    if(belowLowerZone && aboveUpperZone && backBelowLowerZone && !condition2Met)
    {
        condition2Met = true;
        Print("Condition 2 Met: Price made the required zone transitions");
        
        // Now Condition 3 can be met - we have high and low points
        if(highPoint > 0 && lowPoint > 0 && highPointTime > 0 && lowPointTime > 0)
        {
            condition3Met = true;
            Print("Condition 3 Met: Secondary Fibonacci points identified");
            
            // Calculate secondary Fibonacci levels for Condition 4
            CalculateSecondaryFibLevels(highPoint, lowPoint);
        }
    }
    
    // Check Condition 4: Price returns to 50-60% of the second Fibonacci
    if(condition3Met && !condition4Met)
    {
        // Get 50% and 61.8% levels from secondary Fibonacci
        double secLowerZone = secondFibLevels[3]; // 50%
        double secUpperZone = secondFibLevels[4]; // 61.8%
        
        // Ensure we have the levels in the correct order
        if(secLowerZone > secUpperZone)
        {
            double temp = secLowerZone;
            secLowerZone = secUpperZone;
            secUpperZone = temp;
        }
        
        // Check if current candle's midpoint is in the secondary zone
        double currentMidpoint = (open[0] + close[0]) / 2.0;
        
        if(currentMidpoint >= secLowerZone && currentMidpoint <= secUpperZone)
        {
            condition4Met = true;
            Print("Condition 4 Met: Price returned to secondary 50-61.8% zone");
        }
    }
}

//+------------------------------------------------------------------+
//| Helper function to create a shorter horizontal line for sub-fibs   |
//+------------------------------------------------------------------+
void CreateShorterHorizontalLine(string name, double price, ENUM_LINE_STYLE style, string tooltip, 
                                color customColor = CLR_NONE, bool useCustomLabel = false, 
                                double lengthRatio = 0.5, double startOffsetRatio = 0.25)
{
    // Determine line color based on bullish/bearish setting
    color currentLineColor;
    
    if(customColor != CLR_NONE)
    {
        // Use custom color if provided
        currentLineColor = customColor;
    }
    else if(UseDirectionalColors)
    {
        // Use direction-based colors
        currentLineColor = prevDayBullish ? BullishColor : BearishColor;
    }
    else
    {
        // Use the default line color
        currentLineColor = LineColor;
    }
    
    // Validate length ratio to be between 0 and 1
    lengthRatio = MathMax(0.1, MathMin(1.0, lengthRatio));
    
    // Validate start offset ratio to be between 0 and 0.9
    startOffsetRatio = MathMax(0.0, MathMin(0.9, startOffsetRatio));
    
    // Ensure that offset + length doesn't exceed the day
    if(startOffsetRatio + lengthRatio > 1.0)
        lengthRatio = 1.0 - startOffsetRatio;
    
    // Calculate the day's time range
    double timeRange = nextDayStartTime - todayStartTime;
    
    // Calculate start and end times for the shorter line with offset
    datetime lineStartTime = todayStartTime + (datetime)(timeRange * startOffsetRatio);
    datetime lineEndTime = lineStartTime + (datetime)(timeRange * lengthRatio);
    
    // Create the horizontal line with shorter length and offset start
    ObjectCreate(0, name, OBJ_TREND, 0, lineStartTime, price, lineEndTime, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, currentLineColor);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);  // No ray to the left
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false); // No ray to the right
    ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
    
    // Add price label on the line if enabled
    if(useCustomLabel)
    {
        // Extract label text from tooltip (before the colon)
        string labelText = tooltip;
        int colonPos = StringFind(tooltip, ":");
        if(colonPos > 0)
            labelText = StringSubstr(tooltip, 0, colonPos);
            
        // Create a text label at the start of the shorter line
        string labelName = "Label_" + name;
        
        // Use standard OBJ_TEXT that is tied to chart coordinates
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, lineStartTime, price))
        {
            // Set the text
            ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
            
            // Position tied to price and time
            ObjectSetDouble(0, labelName, OBJPROP_PRICE, price);
            ObjectSetInteger(0, labelName, OBJPROP_TIME, lineStartTime);
            
            // Style
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, currentLineColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LabelFontSize);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
            
            // Make sure it stays on top
            ObjectSetInteger(0, labelName, OBJPROP_ZORDER, 100);
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
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

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Delete all created objects when indicator is removed
    ObjectsDeleteAll(0, "PrevDay_");
    ObjectsDeleteAll(0, "SubFib_");
    ObjectsDeleteAll(0, "Label_");
    ObjectsDeleteAll(0, "MidPoint_");
    ObjectsDeleteAll(0, "Strategy_");
    ObjectsDeleteAll(0, "Entry_");
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate the secondary Fibonacci levels                          |
//+------------------------------------------------------------------+
void CalculateSecondaryFibLevels(double highPoint, double lowPoint)
{
    // Determine the range direction based on previous day trend
    double secStartPoint, secEndPoint;
    
    if(prevDayBullish)
    {
        // In bullish trend, the secondary Fibonacci is from low to high
        secStartPoint = lowPoint;
        secEndPoint = highPoint;
    }
    else
    {
        // In bearish trend, the secondary Fibonacci is from high to low
        secStartPoint = highPoint;
        secEndPoint = lowPoint;
    }
    
    // Calculate all the level prices for the secondary Fibonacci
    for(int i = 0; i < ArraySize(subFibLevels); i++)
    {
        secondFibLevels[i] = secStartPoint + (secEndPoint - secStartPoint) * subFibLevels[i];
    }
}

//+------------------------------------------------------------------+
//| Create the secondary Fibonacci retracement lines                  |
//+------------------------------------------------------------------+
void CreateSecondaryFibonacci(double highPoint, double lowPoint, datetime highTime, datetime lowTime)
{
    // Clear any existing secondary Fibonacci objects
    ObjectsDeleteAll(0, "Strategy_");
    
    // Determine the color to use for the secondary Fibonacci
    color strategyColor = EntryZoneColor;
    
    // Create a line connecting the high and low points
    string connectionName = "Strategy_Connection";
    ObjectCreate(0, connectionName, OBJ_TREND, 0, highTime, highPoint, lowTime, lowPoint);
    ObjectSetInteger(0, connectionName, OBJPROP_COLOR, strategyColor);
    ObjectSetInteger(0, connectionName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, connectionName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, connectionName, OBJPROP_RAY_LEFT, false);
    ObjectSetInteger(0, connectionName, OBJPROP_RAY_RIGHT, false);
    ObjectSetString(0, connectionName, OBJPROP_TOOLTIP, "Strategy High-Low Connection");
    
    // Create circles at the high and low points
    string highPointName = "Strategy_HighPoint";
    ObjectCreate(0, highPointName, OBJ_ELLIPSE, 0, highTime, highPoint);
    ObjectSetInteger(0, highPointName, OBJPROP_COLOR, strategyColor);
    ObjectSetInteger(0, highPointName, OBJPROP_FILL, true);
    ObjectSetInteger(0, highPointName, OBJPROP_BACK, false);
    ObjectSetInteger(0, highPointName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, highPointName, OBJPROP_ELLIPSE, true);
    ObjectSetInteger(0, highPointName, OBJPROP_SELECTABLE, false);
    ObjectSetDouble(0, highPointName, OBJPROP_DEVIATION, 0.0001);
    
    string lowPointName = "Strategy_LowPoint";
    ObjectCreate(0, lowPointName, OBJ_ELLIPSE, 0, lowTime, lowPoint);
    ObjectSetInteger(0, lowPointName, OBJPROP_COLOR, strategyColor);
    ObjectSetInteger(0, lowPointName, OBJPROP_FILL, true);
    ObjectSetInteger(0, lowPointName, OBJPROP_BACK, false);
    ObjectSetInteger(0, lowPointName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, lowPointName, OBJPROP_ELLIPSE, true);
    ObjectSetInteger(0, lowPointName, OBJPROP_SELECTABLE, false);
    ObjectSetDouble(0, lowPointName, OBJPROP_DEVIATION, 0.0001);
    
    // Now create the secondary Fibonacci levels
    for(int i = 0; i < ArraySize(secondFibLevels); i++)
    {
        // Skip if this level is not needed for sub-fibs
        if(i > 0 && i < 6 && !showSubFibLevels[i]) continue;
        
        // Always show 0%, 50%, 61.8% and 100% for the strategy
        if(i != 0 && i != 3 && i != 4 && i != 6) continue;
        
        // Create the horizontal line for this level
        string levelName = "Strategy_Level_" + DoubleToString(subFibLevels[i] * 100, 1);
        
        // Special highlighting for the 50-60% zone
        bool isEntryZone = (i == 3 || i == 4); // 50% or 61.8%
        
        // Use different line style for the entry zone
        ENUM_LINE_STYLE lineStyle = isEntryZone ? STYLE_SOLID : STYLE_DOT;
        int lineWidth = isEntryZone ? 2 : 1;
        
        // Create the level line
        CreateShorterHorizontalLine(levelName, secondFibLevels[i], lineStyle, 
                                "Strategy " + DoubleToString(subFibLevels[i] * 100, 1) + "%: " + 
                                DoubleToString(secondFibLevels[i], Digits()),
                                strategyColor, true, 0.7, 0.3);
                                
        ObjectSetInteger(0, levelName, OBJPROP_WIDTH, lineWidth);
    }
    
    // Create a rectangle for the entry zone if highlighting is enabled
    if(HighlightEntryZone)
    {
        string zoneName = "Strategy_EntryZone";
        double zoneStart = secondFibLevels[3]; // 50%
        double zoneEnd = secondFibLevels[4]; // 61.8%
        
        // Make sure zone start is less than zone end
        if(zoneStart > zoneEnd)
        {
            double temp = zoneStart;
            zoneStart = zoneEnd;
            zoneEnd = temp;
        }
        
        // Calculate rectangle coordinates
        datetime rectStart = todayStartTime + (datetime)((nextDayStartTime - todayStartTime) * 0.3);
        datetime rectEnd = todayStartTime + (datetime)((nextDayStartTime - todayStartTime) * 1.0);
        
        ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, rectStart, zoneStart, rectEnd, zoneEnd);
        ObjectSetInteger(0, zoneName, OBJPROP_COLOR, strategyColor);
        ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
        ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
        ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);
        //ObjectSetDouble(0, zoneName, OBJPROP_ZORDER, -1);
       
        ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
        
        // Use a blended, semi-transparent color for fill
        ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, ConvertColorToARGB(strategyColor, 30)); // 30% opacity
    }
}

//+------------------------------------------------------------------+
//| Helper function to create a horizontal line                       |
//+------------------------------------------------------------------+
void CreateHorizontalLine(string name, double price, ENUM_LINE_STYLE style, string tooltip, 
                          color customColor = CLR_NONE, bool useCustomLabel = false)
{
    // Determine line color based on bullish/bearish setting
    color currentLineColor;
    
    if(customColor != CLR_NONE)
    {
        // Use custom color if provided
        currentLineColor = customColor;
    }
    else if(UseDirectionalColors)
    {
        // Use direction-based colors
        currentLineColor = prevDayBullish ? BullishColor : BearishColor;
    }
    else
    {
        // Use the default line color
        currentLineColor = LineColor;
    }
    
    // Create the horizontal line
    ObjectCreate(0, name, OBJ_TREND, 0, todayStartTime, price, nextDayStartTime, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, currentLineColor);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);  // No ray to the left
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false); // No ray to the right
    ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
    
    // Add price label on the line if enabled
    bool shouldShowLabel = (useCustomLabel && ShowSubFibLabels) || (!useCustomLabel && ShowLabels);
    
    if(shouldShowLabel)
    {
        // Extract label text from tooltip (before the colon)
        string labelText = tooltip;
        int colonPos = StringFind(tooltip, ":");
        if(colonPos > 0)
            labelText = StringSubstr(tooltip, 0, colonPos);
            
        // Add "Day" prefix to the label text for main fibs, "Sub" prefix for sub-fibs
        if(StringFind(labelText, "Previous Day") >= 0)
        {
            // Don't modify if it already has "Previous Day" in the text
        }
        else if(StringFind(labelText, "SubFib") >= 0)
        {
            // It's already a SubFib label, keep as is
        }
        else if(StringFind(labelText, "Fib") >= 0)
        {
            // For Fibonacci levels
            labelText = "Day " + labelText;
        }
        else
        {
            // For any other label type
            labelText = "Day " + labelText;
        }
            
        // Create a text label at the start of the line
        string labelName = "Label_" + name;
        
        // Use standard OBJ_TEXT that is tied to chart coordinates
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, todayStartTime, price))
        {
            // Set the text
            ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
            
            // Position tied to price
            ObjectSetDouble(0, labelName, OBJPROP_PRICE, price);
            ObjectSetInteger(0, labelName, OBJPROP_TIME, todayStartTime);
            
            // Style
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, currentLineColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LabelFontSize);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
            
            // Make sure it stays on top
            ObjectSetInteger(0, labelName, OBJPROP_ZORDER, 100);
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        }
    }
}
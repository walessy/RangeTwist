//+------------------------------------------------------------------+
//|                        FibDay5Min_StrategyDetection.mq5          |
//|                                                                   |
//|  Draws horizontal lines based on previous day's OHLC              |
//|  - Previous day high/low lines (solid/dashed based on direction)  |
//|  - Fibonacci levels between previous day's high and low           |
//|  - Sub-Fibonacci trend lines with configurable points             |
//|  - Lines are truncated to only show on current day                |
//|  - Detects and highlights strategy conditions using candle bodies |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.30"
#property indicator_chart_window
#property indicator_plots   0

// Include shared functions
#include "FibStrategyFunctions.mqh"

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
input string SubFibSection = "--- Sub-Fibonacci Settings ---"; // Sub-Fibonacci Settings
input bool   ShowSubFib = true;            // Show Sub-Fibonacci Trend Lines
input bool   AlwaysShowSubFib = false;     // Always show Sub-Fibonacci levels (ignore strategy conditions)
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

// Input parameters for strategy detection
input string StrategySection = "--- Strategy Detection Settings ---"; // Strategy Detection Settings
input bool   EnableStrategyDetection = true;  // Enable strategy condition detection
input bool   DrawCandleMidpoints = true;      // Draw midpoints for candle bodies
input color  MidpointColor = clrPurple;       // Color for candle midpoint lines
input int    LookbackCandles = 100;           // Number of candles to look back for conditions
input bool   HighlightEntryZone = true;       // Highlight the entry zone when detected
input color  EntryZoneColor = clrLime;        // Color for the entry zone highlight
input double InputUpperZoneLimit = 0.6;       // Upper limit for zone (default 60%)
input double InputLowerZoneLimit = 0.5;       // Lower limit for zone (default 50%)
input bool   ShowEntryArrow = true;           // Show arrow at entry point
input color  EntryArrowColor = clrRed;        // Color for entry arrow
// Input parameters for condition highlighting
input string HighlightSection = "--- Condition Highlighting Settings ---"; // Condition Highlighting
input bool   ShowConditionPanel = true;       // Show condition status panel
input bool   MarkConditionCandles = true;     // Mark candles where conditions were met
input bool   RestrictToCurrentDay = true;     // Only show conditions from current day
input color  Condition1Color = clrGreen;      // Color for Condition 1 markers
input color  Condition2Color = clrBlue;       // Color for Condition 2 markers
input color  Condition3Color = clrOrange;     // Color for Condition 3 markers
input color  Condition4Color = clrRed;        // Color for Condition 4 markers

// Input parameters for condition panel customization
input string PanelSection = "--- Condition Panel Settings ---"; // Condition Panel Settings
input ENUM_BASE_CORNER PanelCorner = CORNER_RIGHT_UPPER;    // Panel Position Corner
input int PanelXDistance = 200;                             // Panel X Distance
input int PanelYDistance = 20;                              // Panel Y Distance
input int PanelWidth = 180;                                 // Panel Width
input int PanelHeight = 120;                                // Panel Height
input color PanelBackgroundColor = clrWhite;                // Panel Background Color
input color PanelBorderColor = clrBlack;                    // Panel Border Color
input color PanelTitleColor = clrBlack;                     // Panel Title Color
input int PanelTitleFontSize = 10;                          // Panel Title Font Size
input bool PanelShowBulletPoints = true;                    // Show Bullet Points
input int PanelConditionFontSize = 8;                       // Condition Text Font Size
input int PanelSignalFontSize = 9;                          // Signal Text Font Size
input bool EnablePanelTransparency = false;                 // Enable Panel Transparency
input int PanelTransparencyLevel = 80;                      // Panel Transparency Level (0-100)
input bool EnableAutoPosition = false;                      // Auto-position Panel
// Global variables
datetime prevDayTime = 0;
datetime todayStartTime = 0;
datetime nextDayStartTime = 0;
string currentSymbol = "";  // Track current symbol
ENUM_TIMEFRAMES currentTimeframe = PERIOD_CURRENT; // Track timeframe for resets
bool showLevels[9] = {true, true, true, true, true, true, true, false, false};
bool showSubFibLevels[7] = {false, false, false, false, false, false, false};

// Global variables for drawing
double prevDayHigh = 0;
double prevDayLow = 0;
bool prevDayBullish = false;

//+------------------------------------------------------------------+
//| Function declarations                                             |
//+------------------------------------------------------------------+
void CreateHorizontalLine(string name, double price, ENUM_LINE_STYLE style, string tooltip, color customColor = CLR_NONE, bool useCustomLabel = false);
void CreateShorterHorizontalLine(string name, double price, ENUM_LINE_STYLE style, string tooltip, color customColor = CLR_NONE, bool useCustomLabel = false, double lengthRatio = 0.5, double startOffsetRatio = 0.25);
void CreateSecondaryFibonacci();
void UpdateConditionPanel();
void MarkConditionPoints(const datetime &time[], const double &close[]);
void DrawMainFibonacciLevels();
void DrawSubFibonacciLevels();
bool IsToday(datetime time);
uint ConvertColorToARGB(color clr, uchar alpha);
void SetOptimalPanelPosition();
//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
    // Update zone limits from inputs
    LowerZoneLimit = InputLowerZoneLimit;
    UpperZoneLimit = InputUpperZoneLimit;
    
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
    if(InputLowerZoneLimit < 0 || InputLowerZoneLimit > 1 || InputUpperZoneLimit < 0 || InputUpperZoneLimit > 1 || InputLowerZoneLimit >= InputUpperZoneLimit)
    {
        Print("Warning: Zone limits must be between 0 and 1, and lower limit must be less than upper limit. Using default values.");
        // Keep the defaults as they are already set in the input parameters
    }
    
    // Store current timeframe
    currentTimeframe = Period();
    
    // Create the initial condition panel if enabled
    if(ShowConditionPanel) {
        // Clear any existing panel objects to ensure a clean start
        ObjectsDeleteAll(0, "Condition_Panel");
        ObjectsDeleteAll(0, "Condition_Title");
        ObjectsDeleteAll(0, "Condition_Status_");
        ObjectsDeleteAll(0, "Entry_Signal_Status");
        
        // Find the optimal position first if enabled
        if(EnableAutoPosition) {
            SetOptimalPanelPosition();
        }
        
        // Create the condition panel with initial states
        UpdateConditionPanel();
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
    // Check if timeframe has changed - force a redraw if it has
    if(currentTimeframe != Period()) {
        currentTimeframe = Period();
        prevDayTime = 0; // This will force a redraw
        ResetStrategyState();
        Print("Timeframe changed to ", EnumToString(currentTimeframe), " - resetting indicator");
    }
    
    // Always update condition panel if it's enabled
    if(ShowConditionPanel) {
        // If the panel doesn't exist (was deleted or not created yet), recreate it
        if(ObjectFind(0, "Condition_Panel") < 0) {
            // Find the optimal position first if enabled
            if(EnableAutoPosition) {
                SetOptimalPanelPosition();
            }
            
            // Create/update the panel
            UpdateConditionPanel();
        } else {
            // Panel exists, just update it
            UpdateConditionPanel();
        }
    } else {
        // If panel is disabled, ensure it's removed
        ObjectsDeleteAll(0, "Condition_Panel");
        ObjectsDeleteAll(0, "Condition_Title");
        ObjectsDeleteAll(0, "Condition_Status_");
        ObjectsDeleteAll(0, "Entry_Signal_Status");
    }
    
    // Check if we need to update previous day's data
    datetime currentDay = iTime(Symbol(), PERIOD_D1, 0);
    string symbol = Symbol();
    
    // Force redraw if symbol has changed or day has changed
    if(prevDayTime != currentDay || currentSymbol != symbol)
    {
        // Reset strategy detection variables
        ResetStrategyState();
        
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
        ObjectsDeleteAll(0, "Condition_");
        ObjectsDeleteAll(0, "CondMarker_");
        
        // Always draw main Fibonacci levels
        DrawMainFibonacciLevels();
        
        // Always show sub-fibs if enabled, regardless of strategy conditions
        if(ShowSubFib && AlwaysShowSubFib) {
            DrawSubFibonacciLevels();
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
        CheckStrategyCriteria(time, open, high, low, close, rates_total, 
                             prevDayHigh, prevDayLow, prevDayBullish, false);
        
        // Draw the strategy detection visuals if conditions are met
        if(condition3Met)
        {
            // Create the second Fibonacci retracement (Condition 3)
            CreateSecondaryFibonacci();
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
        
        // Update condition panel and markers
        if(ShowConditionPanel) UpdateConditionPanel();
        if(MarkConditionCandles) MarkConditionPoints(time, close);
    }
    
    return(rates_total);
}
//+------------------------------------------------------------------+
//| Draw main Fibonacci levels                                        |
//+------------------------------------------------------------------+
void DrawMainFibonacciLevels()
{
    // Always create the high/low lines separate from Fibonacci levels
    CreateHorizontalLine("PrevDay_High", prevDayHigh, prevDayBullish ? STYLE_SOLID : STYLE_DASH, 
                        "Previous Day High: " + DoubleToString(prevDayHigh, Digits()));
    
    CreateHorizontalLine("PrevDay_Low", prevDayLow, prevDayBullish ? STYLE_DASH : STYLE_SOLID, 
                        "Previous Day Low: " + DoubleToString(prevDayLow, Digits()));
    
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

//+------------------------------------------------------------------+
//| Draw sub-Fibonacci levels                                         |
//+------------------------------------------------------------------+
void DrawSubFibonacciLevels()
{
    // Calculate the sub-fib range prices
    double range = MathAbs(prevDayHigh - prevDayLow);
    double startFibPoint, endFibPoint;
    
    if(prevDayBullish)
    {
        // In bullish days, 0% is at the low, 100% at the high
        startFibPoint = prevDayLow;   // 0% level
        endFibPoint = prevDayHigh;    // 100% level
    }
    else
    {
        // In bearish days, 0% is at the high, 100% at the low
        startFibPoint = prevDayHigh;  // 0% level
        endFibPoint = prevDayLow;     // 100% level
    }
    
    double subFibStartPrice = startFibPoint + (endFibPoint - startFibPoint) * StartPoint;
    double subFibEndPrice = startFibPoint + (endFibPoint - startFibPoint) * EndPoint;
    
    // Loop through each Sub-Fibonacci level
    for(int i = 0; i < ArraySize(subFibLevels); i++)
    {
        // Skip if this level is not enabled
        if(!showSubFibLevels[i]) continue;
        
        // Calculate the price for this sub-fib level
        double subLevelPrice = subFibStartPrice + (subFibEndPrice - subFibStartPrice) * subFibLevels[i];
        
        // Create the horizontal line for sub-fib
        string subLevelName = "SubFib_" + DoubleToString(subFibLevels[i] * 100, 1);
        ENUM_LINE_STYLE subLineStyle = STYLE_DOT;  // Use dotted style for sub-fibs
        
        // Create the line with the specified sub-fib color and shorter length and offset
        CreateShorterHorizontalLine(subLevelName, subLevelPrice, subLineStyle, 
                            "SubFib " + DoubleToString(subFibLevels[i] * 100, 1) + "%: " + 
                            DoubleToString(subLevelPrice, Digits()), 
                            UseCustomSubFibColor ? SubFibColor : CLR_NONE, 
                            ShowSubFibLabels, SubFibLineLength, SubFibStartOffset);
    }
}
//+------------------------------------------------------------------+
//| Check if a datetime is within today's trading day                 |
//+------------------------------------------------------------------+
bool IsToday(datetime time)
{
    return (time >= todayStartTime && time < nextDayStartTime);
}

//+------------------------------------------------------------------+
//| Create the secondary Fibonacci retracement lines                  |
//+------------------------------------------------------------------+
void CreateSecondaryFibonacci()
{
    // Don't create secondary Fibonacci objects if time points are outside current day and restriction is enabled
    if(RestrictToCurrentDay && (!IsToday(highPointTime) || !IsToday(lowPointTime))) {
        return;
    }
    
    // Clear any existing secondary Fibonacci objects
    ObjectsDeleteAll(0, "Strategy_");
    
    // Determine the color to use for the secondary Fibonacci
    color strategyColor = EntryZoneColor;
    
    // Create a line connecting the high and low points
    string connectionName = "Strategy_Connection";
    ObjectCreate(0, connectionName, OBJ_TREND, 0, highPointTime, highPoint, lowPointTime, lowPoint);
    ObjectSetInteger(0, connectionName, OBJPROP_COLOR, strategyColor);
    ObjectSetInteger(0, connectionName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, connectionName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, connectionName, OBJPROP_RAY_LEFT, false);
    ObjectSetInteger(0, connectionName, OBJPROP_RAY_RIGHT, false);
    ObjectSetString(0, connectionName, OBJPROP_TOOLTIP, "Strategy High-Low Connection");
    
    // Create circles at the high and low points
    string highPointName = "Strategy_HighPoint";
    ObjectCreate(0, highPointName, OBJ_ELLIPSE, 0, highPointTime, highPoint);
    ObjectSetInteger(0, highPointName, OBJPROP_COLOR, strategyColor);
    ObjectSetInteger(0, highPointName, OBJPROP_FILL, true);
    ObjectSetInteger(0, highPointName, OBJPROP_BACK, false);
    ObjectSetInteger(0, highPointName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, highPointName, OBJPROP_ELLIPSE, true);
    ObjectSetInteger(0, highPointName, OBJPROP_SELECTABLE, false);
    
    string lowPointName = "Strategy_LowPoint";
    ObjectCreate(0, lowPointName, OBJ_ELLIPSE, 0, lowPointTime, lowPoint);
    ObjectSetInteger(0, lowPointName, OBJPROP_COLOR, strategyColor);
    ObjectSetInteger(0, lowPointName, OBJPROP_FILL, true);
    ObjectSetInteger(0, lowPointName, OBJPROP_BACK, false);
    ObjectSetInteger(0, lowPointName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, lowPointName, OBJPROP_ELLIPSE, true);
    ObjectSetInteger(0, lowPointName, OBJPROP_SELECTABLE, false);
    
    // Now create the secondary Fibonacci levels
    for(int i = 0; i < ArraySize(secondFibLevels); i++) {
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
    if(HighlightEntryZone) {
        string zoneName = "Strategy_EntryZone";
        double zoneStart = secondFibLevels[3]; // 50%
        double zoneEnd = secondFibLevels[4]; // 61.8%
        
        // Make sure zone start is less than zone end
        if(zoneStart > zoneEnd) {
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
        ObjectSetInteger(0, zoneName, OBJPROP_ZORDER, -1);
        ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
        
        // Use a blended, semi-transparent color for fill
        ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, ConvertColorToARGB(strategyColor, 30)); // 30% opacity
    }
}
//+------------------------------------------------------------------+
//| Find optimal position for condition panel                         |
//+------------------------------------------------------------------+
void SetOptimalPanelPosition()
{
    if(!EnableAutoPosition) return;
    
    // Get chart dimensions
    int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    
    // Calculate potential positions in each corner
    // Format: {corner, xDistance, yDistance}
    int positions[4][3] = {
        {CORNER_LEFT_UPPER, 10, 10},
        {CORNER_RIGHT_UPPER, 10, 10},
        {CORNER_LEFT_LOWER, 10, 10},
        {CORNER_RIGHT_LOWER, 10, 10}
    };
    
    // Calculate scores for each position (higher is better)
    int scores[4] = {0, 0, 0, 0};
    
    // Check for object overlap in each corner
    for(int i = 0; i < 4; i++) {
        // Create a temporary object for collision detection
        string tempName = "Temp_Panel_Pos_" + IntegerToString(i);
        ObjectCreate(0, tempName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, tempName, OBJPROP_CORNER, positions[i][0]);
        ObjectSetInteger(0, tempName, OBJPROP_XDISTANCE, positions[i][1]);
        ObjectSetInteger(0, tempName, OBJPROP_YDISTANCE, positions[i][2]);
        ObjectSetInteger(0, tempName, OBJPROP_XSIZE, PanelWidth);
        ObjectSetInteger(0, tempName, OBJPROP_YSIZE, PanelHeight);
        
        // Check for overlap with other objects
        int totalObjects = ObjectsTotal(0);
        
        for(int j = 0; j < totalObjects; j++) {
            string objName = ObjectName(0, j);
            
            // Skip temporary and panel-related objects
            if(StringFind(objName, "Temp_Panel_Pos_") >= 0 ||
               StringFind(objName, "Condition_Panel") >= 0 ||
               StringFind(objName, "Condition_Title") >= 0 ||
               StringFind(objName, "Condition_Status_") >= 0 ||
               StringFind(objName, "Entry_Signal_Status") >= 0) {
                continue;
            }
            
            // Check object type - we're mainly concerned with visible objects
            ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, objName, OBJPROP_TYPE);
            
            // Skip certain object types that won't cause visual conflicts
            if(objType == OBJ_VLINE || objType == OBJ_HLINE || objType == OBJ_TREND) {
                continue;
            }
            
            // Check if object is at same corner
            ENUM_BASE_CORNER objCorner = (ENUM_BASE_CORNER)ObjectGetInteger(0, objName, OBJPROP_CORNER);
            
            if(objCorner == positions[i][0]) {
                // For objects using same corner system, check for overlap
                int objX = (int)ObjectGetInteger(0, objName, OBJPROP_XDISTANCE);
                int objY = (int)ObjectGetInteger(0, objName, OBJPROP_YDISTANCE);
                int objWidth = (int)ObjectGetInteger(0, objName, OBJPROP_XSIZE);
                int objHeight = (int)ObjectGetInteger(0, objName, OBJPROP_YSIZE);
                
                // Simple overlap detection - if coordinates overlap, reduce score
                if(objX < positions[i][1] + PanelWidth && objX + objWidth > positions[i][1] &&
                   objY < positions[i][2] + PanelHeight && objY + objHeight > positions[i][2]) {
                    scores[i] -= 10;
                }
            }
        }
        
        // Remove temporary object
        ObjectDelete(0, tempName);
        
        // Add score for distance from chart edges
        if(positions[i][0] == CORNER_LEFT_UPPER || positions[i][0] == CORNER_LEFT_LOWER) {
            // More space on the left side of chart
            if(positions[i][1] + PanelWidth < chartWidth / 2) {
                scores[i] += 5;
            }
        } else {
            // More space on the right side of chart
            if(positions[i][1] + PanelWidth < chartWidth / 2) {
                scores[i] += 5;
            }
        }
        
        // Prefer upper positions slightly (less likely to overlap with other indicators)
        if(positions[i][0] == CORNER_LEFT_UPPER || positions[i][0] == CORNER_RIGHT_UPPER) {
            scores[i] += 3;
        }
    }
    
    // Find position with highest score
    int bestPos = 0;
    for(int i = 1; i < 4; i++) {
        if(scores[i] > scores[bestPos]) {
            bestPos = i;
        }
    }
    
    // Using variables to store optimal position values
    int optimalCorner = positions[bestPos][0];
    int optimalXDistance = positions[bestPos][1];
    int optimalYDistance = positions[bestPos][2];
    
    // Apply these values in the UpdateConditionPanel function next time it's called
    string variableName = "Condition_Panel";
    if(ObjectFind(0, variableName) >= 0) {
        ObjectSetInteger(0, variableName, OBJPROP_CORNER, optimalCorner);
        ObjectSetInteger(0, variableName, OBJPROP_XDISTANCE, optimalXDistance);
        ObjectSetInteger(0, variableName, OBJPROP_YDISTANCE, optimalYDistance);
    }
    
    // Also update title and condition labels
    string titleName = "Condition_Title";
    if(ObjectFind(0, titleName) >= 0) {
        ObjectSetInteger(0, titleName, OBJPROP_CORNER, optimalCorner);
        
        // Calculate adjusted X position based on corner
        int titleX = optimalXDistance;
        if(optimalCorner == CORNER_RIGHT_UPPER || optimalCorner == CORNER_RIGHT_LOWER) {
            titleX = optimalXDistance + 15; // Add padding for right corners
        } else {
            titleX = optimalXDistance + PanelWidth - 15; // Left align with padding for left corners
        }
        
        ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, titleX);
        ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, optimalYDistance + 5);
    }
    
    // Update all condition status labels
    for(int i=1; i<=4; i++) {
        string labelName = "Condition_Status_" + IntegerToString(i);
        if(ObjectFind(0, labelName) >= 0) {
            int conditionY = optimalYDistance + 5 + i*20;
            
            ObjectSetInteger(0, labelName, OBJPROP_CORNER, optimalCorner);
            // Use same X position calculation as for title
            int labelX = optimalXDistance;
            if(optimalCorner == CORNER_RIGHT_UPPER || optimalCorner == CORNER_RIGHT_LOWER) {
                labelX = optimalXDistance + 15;
            } else {
                labelX = optimalXDistance + PanelWidth - 15;
            }
            ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, labelX);
            ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, conditionY);
        }
    }
    
    // Update entry signal status
    string signalName = "Entry_Signal_Status";
    if(ObjectFind(0, signalName) >= 0) {
        int signalY = optimalYDistance + 5 + 5*20;
        
        ObjectSetInteger(0, signalName, OBJPROP_CORNER, optimalCorner);
        // Use same X position calculation as for other labels
        int signalX = optimalXDistance;
        if(optimalCorner == CORNER_RIGHT_UPPER || optimalCorner == CORNER_RIGHT_LOWER) {
            signalX = optimalXDistance + 15;
        } else {
            signalX = optimalXDistance + PanelWidth - 15;
        }
        ObjectSetInteger(0, signalName, OBJPROP_XDISTANCE, signalX);
        ObjectSetInteger(0, signalName, OBJPROP_YDISTANCE, signalY);
    }
}
//+------------------------------------------------------------------+
//| Create condition status panel - Always visible but only show triggered conditions |
//+------------------------------------------------------------------+
void UpdateConditionPanel()
{
    // Check if any conditions are met
    bool anyConditionMet = condition1Met || condition2Met || condition3Met || condition4Met || entrySignal;
    
    // Calculate background color with transparency if enabled
    color bgColor = PanelBackgroundColor;
    if(EnablePanelTransparency) {
        // Convert transparency level (0-100) to alpha value (0-255)
        int alpha = (int)((100 - PanelTransparencyLevel) * 2.55);
        // Apply transparency to background color
        bgColor = ConvertColorToARGB(PanelBackgroundColor, alpha);
    }
    
    // Always create/update the panel background, even when no conditions are met
    if(ObjectFind(0, "Condition_Panel") < 0) {
        ObjectCreate(0, "Condition_Panel", OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_CORNER, PanelCorner);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_XDISTANCE, PanelXDistance);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_YDISTANCE, PanelYDistance);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_XSIZE, PanelWidth);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_YSIZE, PanelHeight);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_BGCOLOR, bgColor);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_COLOR, PanelBorderColor);
    } else {
        // Update existing panel properties
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_XSIZE, PanelWidth);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_YSIZE, PanelHeight);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_BGCOLOR, bgColor);
        ObjectSetInteger(0, "Condition_Panel", OBJPROP_COLOR, PanelBorderColor);
    }
    
    // Get the actual corner being used (it might have been set by auto-positioning)
    ENUM_BASE_CORNER actualCorner = (ENUM_BASE_CORNER)ObjectGetInteger(0, "Condition_Panel", OBJPROP_CORNER);
    int actualX = (int)ObjectGetInteger(0, "Condition_Panel", OBJPROP_XDISTANCE);
    int actualY = (int)ObjectGetInteger(0, "Condition_Panel", OBJPROP_YDISTANCE);
    
    // Calculate title position based on the actual panel corner
    int titleX = actualX;
    int titleY = actualY;
    
    // Adjust X position for right corners
    if(actualCorner == CORNER_RIGHT_UPPER || actualCorner == CORNER_RIGHT_LOWER) {
        titleX = actualX + 15; // Add some padding
    } else {
        titleX = actualX + PanelWidth - 15; // Left align with padding
    }
    
    // Adjust Y position for lower corners
    if(actualCorner == CORNER_LEFT_LOWER || actualCorner == CORNER_RIGHT_LOWER) {
        titleY += 5; // Add some padding from top
    } else {
        titleY += 5; // Add some padding from top
    }
    
    // Always create/update the title
    if(ObjectFind(0, "Condition_Title") < 0) {
        ObjectCreate(0, "Condition_Title", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "Condition_Title", OBJPROP_CORNER, actualCorner);
        ObjectSetInteger(0, "Condition_Title", OBJPROP_XDISTANCE, titleX);
        ObjectSetInteger(0, "Condition_Title", OBJPROP_YDISTANCE, titleY);
        ObjectSetString(0, "Condition_Title", OBJPROP_TEXT, "Strategy Conditions");
        ObjectSetInteger(0, "Condition_Title", OBJPROP_COLOR, PanelTitleColor);
        ObjectSetInteger(0, "Condition_Title", OBJPROP_FONTSIZE, PanelTitleFontSize);
    } else {
        // Update existing title properties
        ObjectSetInteger(0, "Condition_Title", OBJPROP_CORNER, actualCorner);
        ObjectSetInteger(0, "Condition_Title", OBJPROP_XDISTANCE, titleX);
        ObjectSetInteger(0, "Condition_Title", OBJPROP_YDISTANCE, titleY);
        ObjectSetInteger(0, "Condition_Title", OBJPROP_COLOR, PanelTitleColor);
        ObjectSetInteger(0, "Condition_Title", OBJPROP_FONTSIZE, PanelTitleFontSize);
    }
    
    // Remove all existing condition labels and entry signal
    ObjectsDeleteAll(0, "Condition_Status_");
    ObjectDelete(0, "Entry_Signal_Status");
    
    // If no conditions are met, just leave the panel empty with only the title
    if(!anyConditionMet) {
        return;
    }
    
    // Define condition descriptions
    string conditionTexts[4] = {
        "Price in 50-60% Zone",
        "Zone Transitions",
        "Secondary Fib Points",
        "Entry Zone Reached"
    };
    
    // Create status indicators only for met conditions
    int rowCount = 0; // Track how many rows we've added
    
    // Only create labels for conditions that are met
    for(int i=1; i<=4; i++) {
        bool conditionMet = false;
        color conditionColor = clrRed;
        
        switch(i) {
            case 1: conditionMet = condition1Met; conditionColor = Condition1Color; break;
            case 2: conditionMet = condition2Met; conditionColor = Condition2Color; break;
            case 3: conditionMet = condition3Met; conditionColor = Condition3Color; break;
            case 4: conditionMet = condition4Met; conditionColor = Condition4Color; break;
        }
        
        // Only create label if condition is met
        if(conditionMet) {
            rowCount++;
            string labelName = "Condition_Status_" + IntegerToString(i);
            int conditionY = titleY + rowCount*20;
            
            // Create label object
            ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, labelName, OBJPROP_CORNER, actualCorner);
            ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, titleX);
            ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, conditionY);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, PanelConditionFontSize);
            
            // Format the condition text with optional bullet points
            string bulletPoint = PanelShowBulletPoints ? "• " : "";
            string statusSymbol = "✓";
            
            ObjectSetString(0, labelName, OBJPROP_TEXT, bulletPoint + "C" + IntegerToString(i) + ": " + 
                            conditionTexts[i-1] + " " + statusSymbol);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, conditionColor);
        }
    }
    
    // Add entry signal if active
    if(entrySignal) {
        rowCount++;
        string signalName = "Entry_Signal_Status";
        int signalY = titleY + rowCount*20;
        
        // Create entry signal label
        ObjectCreate(0, signalName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, signalName, OBJPROP_CORNER, actualCorner);
        ObjectSetInteger(0, signalName, OBJPROP_XDISTANCE, titleX);
        ObjectSetInteger(0, signalName, OBJPROP_YDISTANCE, signalY);
        ObjectSetInteger(0, signalName, OBJPROP_FONTSIZE, PanelSignalFontSize);
        
        // Format the entry signal status
        string entryPrefix = PanelShowBulletPoints ? "• " : "";
        string entryText = entryPrefix + "ENTRY SIGNAL: ACTIVE (" + (prevDayBullish ? "BUY" : "SELL") + ")";
        
        ObjectSetString(0, signalName, OBJPROP_TEXT, entryText);
        ObjectSetInteger(0, signalName, OBJPROP_COLOR, prevDayBullish ? clrBlue : clrRed);
    }
}
//+------------------------------------------------------------------+
//| Mark condition points on chart with clear identifiers            |
//+------------------------------------------------------------------+
void MarkConditionPoints(const datetime &time[], const double &close[])
{
    // Only create markers if we have transitions completed
    if(condition1Met || condition2Met || condition3Met || condition4Met) {
        // Clear previous markers
        ObjectsDeleteAll(0, "CondMarker_");
        
        // Mark condition 1 (first entry to the 50-60% zone)
        if(condition1Met && highPointTime > 0) {
            // Only draw if within current day when restriction is enabled
            if(!RestrictToCurrentDay || (RestrictToCurrentDay && IsToday(highPointTime))) {
                string markerName = "CondMarker_1";
                int barIndex = iBarShift(Symbol(), PERIOD_CURRENT, highPointTime);
                if(barIndex >= 0) {
                    // Create distinctive marker for Condition 1
                    ObjectCreate(0, markerName, OBJ_ARROW, 0, time[barIndex], highPoint + 10*Point());
                    ObjectSetInteger(0, markerName, OBJPROP_ARROWCODE, 241); // Diamond
                    ObjectSetInteger(0, markerName, OBJPROP_COLOR, Condition1Color);
                    ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 2);
                    ObjectSetString(0, markerName, OBJPROP_TOOLTIP, "Condition 1 Met: Price in 50-60% Zone");
                    
                    // Add text label with condition number
                    string labelName = "CondMarker_1_Label";
                    ObjectCreate(0, labelName, OBJ_TEXT, 0, time[barIndex], highPoint + 20*Point());
                    ObjectSetString(0, labelName, OBJPROP_TEXT, "C1");
                    ObjectSetInteger(0, labelName, OBJPROP_COLOR, Condition1Color);
                    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
                    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                    
                    // Add dotted vertical line
                    string vlineName = "CondMarker_1_VLine";
                    ObjectCreate(0, vlineName, OBJ_VLINE, 0, time[barIndex], 0);
                    ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DOT);
                    ObjectSetInteger(0, vlineName, OBJPROP_COLOR, Condition1Color);
                    ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 1);
                    ObjectSetInteger(0, vlineName, OBJPROP_BACK, true); // Put line in the background
                    ObjectSetString(0, vlineName, OBJPROP_TOOLTIP, "Condition 1 Met Here");
                }
            }
        }
        
        // Mark condition 2 & 3 (transitions and secondary fib points)
        if(condition3Met && highPointTime > 0 && lowPointTime > 0) {
            // Mark high point (Condition 2)
            if(!RestrictToCurrentDay || (RestrictToCurrentDay && IsToday(highPointTime))) {
                string highMarkerName = "CondMarker_2";
                int highBarIndex = iBarShift(Symbol(), PERIOD_CURRENT, highPointTime);
                if(highBarIndex >= 0) {
                    // Create distinctive marker for Condition 2
                    ObjectCreate(0, highMarkerName, OBJ_ARROW, 0, time[highBarIndex], highPoint + 15*Point());
                    ObjectSetInteger(0, highMarkerName, OBJPROP_ARROWCODE, 159); // Check mark
                    ObjectSetInteger(0, highMarkerName, OBJPROP_COLOR, Condition2Color);
                    ObjectSetInteger(0, highMarkerName, OBJPROP_WIDTH, 2);
                    ObjectSetString(0, highMarkerName, OBJPROP_TOOLTIP, "Condition 2 Met: Zone Transitions - High Point");
                    
                    // Add text label with condition number
                    string labelName = "CondMarker_2_Label";
                    ObjectCreate(0, labelName, OBJ_TEXT, 0, time[highBarIndex], highPoint + 25*Point());
                    ObjectSetString(0, labelName, OBJPROP_TEXT, "C2");
                    ObjectSetInteger(0, labelName, OBJPROP_COLOR, Condition2Color);
                    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
                    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                    
                    // Add dotted vertical line
                    string vlineName = "CondMarker_2_VLine";
                    ObjectCreate(0, vlineName, OBJ_VLINE, 0, time[highBarIndex], 0);
                    ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DOT);
                    ObjectSetInteger(0, vlineName, OBJPROP_COLOR, Condition2Color);
                    ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 1);
                    ObjectSetInteger(0, vlineName, OBJPROP_BACK, true); // Put line in the background
                    ObjectSetString(0, vlineName, OBJPROP_TOOLTIP, "Condition 2 Met Here");
                }
            }
            
            // Mark low point (Condition 3)
            if(!RestrictToCurrentDay || (RestrictToCurrentDay && IsToday(lowPointTime))) {
                string lowMarkerName = "CondMarker_3";
                int lowBarIndex = iBarShift(Symbol(), PERIOD_CURRENT, lowPointTime);
                if(lowBarIndex >= 0) {
                    // Create distinctive marker for Condition 3
                    ObjectCreate(0, lowMarkerName, OBJ_ARROW, 0, time[lowBarIndex], lowPoint - 15*Point());
                    ObjectSetInteger(0, lowMarkerName, OBJPROP_ARROWCODE, 115); // Down arrow
                    ObjectSetInteger(0, lowMarkerName, OBJPROP_COLOR, Condition3Color);
                    ObjectSetInteger(0, lowMarkerName, OBJPROP_WIDTH, 2);
                    ObjectSetString(0, lowMarkerName, OBJPROP_TOOLTIP, "Condition 3 Met: Secondary Fibonacci Points - Low Point");
                    
                    // Add text label with condition number
                    string labelName = "CondMarker_3_Label";
                    ObjectCreate(0, labelName, OBJ_TEXT, 0, time[lowBarIndex], lowPoint - 25*Point());
                    ObjectSetString(0, labelName, OBJPROP_TEXT, "C3");
                    ObjectSetInteger(0, labelName, OBJPROP_COLOR, Condition3Color);
                    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
                    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                    
                    // Add dotted vertical line
                    string vlineName = "CondMarker_3_VLine";
                    ObjectCreate(0, vlineName, OBJ_VLINE, 0, time[lowBarIndex], 0);
                    ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DOT);
                    ObjectSetInteger(0, vlineName, OBJPROP_COLOR, Condition3Color);
                    ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 1);
                    ObjectSetInteger(0, vlineName, OBJPROP_BACK, true); // Put line in the background
                    ObjectSetString(0, vlineName, OBJPROP_TOOLTIP, "Condition 3 Met Here");
                }
            }
        }
        // Mark condition 4 (entry point)
        if(condition4Met) {
            // Check if the entry point is today
            if(!RestrictToCurrentDay || (RestrictToCurrentDay && IsToday(time[0]))) {
                string entryMarkerName = "CondMarker_4";
                
                // Create distinctive marker for Condition 4 (entry signal)
                ObjectCreate(0, entryMarkerName, OBJ_ARROW, 0, time[0], close[0]);
                ObjectSetInteger(0, entryMarkerName, OBJPROP_ARROWCODE, prevDayBullish ? 225 : 226); // Up/down triangles
                ObjectSetInteger(0, entryMarkerName, OBJPROP_COLOR, Condition4Color);
                ObjectSetInteger(0, entryMarkerName, OBJPROP_WIDTH, 3);
                ObjectSetString(0, entryMarkerName, OBJPROP_TOOLTIP, "Condition 4 Met: Entry Signal " + 
                               (prevDayBullish ? "BUY" : "SELL"));
                
                // Add text label with condition number and signal direction
                string labelName = "CondMarker_4_Label";
                double labelPos = close[0] + (prevDayBullish ? 20 : -20) * Point();
                ObjectCreate(0, labelName, OBJ_TEXT, 0, time[0], labelPos);
                ObjectSetString(0, labelName, OBJPROP_TEXT, "C4 " + (prevDayBullish ? "BUY" : "SELL"));
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, Condition4Color);
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
                ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                
                // Add dotted vertical line
                string vlineName = "CondMarker_4_VLine";
                ObjectCreate(0, vlineName, OBJ_VLINE, 0, time[0], 0);
                ObjectSetInteger(0, vlineName, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, vlineName, OBJPROP_COLOR, Condition4Color);
                ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, vlineName, OBJPROP_BACK, true); // Put line in the background
                ObjectSetString(0, vlineName, OBJPROP_TOOLTIP, "Entry Signal Here");
            }
        }
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
    long timeRange = (long)(nextDayStartTime - todayStartTime);
    
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
    ObjectsDeleteAll(0, "Condition_");
    ObjectsDeleteAll(0, "CondMarker_");
    ObjectsDeleteAll(0, "Temp_Panel_");
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ChartEvent function to handle chart events                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Store the current symbol at the start of the event
    static string lastSymbol = Symbol();
    
    // For any chart event, check if the symbol has changed
    string currentSymbolName = Symbol();
    if(currentSymbolName != lastSymbol) {
        Print("Symbol changed from ", lastSymbol, " to ", currentSymbolName, " - forcing Fibonacci redraw");
        lastSymbol = currentSymbolName;
        
        // Reset the previous day time to force a redraw
        prevDayTime = 0;
        
        // Reset strategy state
        ResetStrategyState();
        
        // Update current symbol
        currentSymbol = currentSymbolName;
        
        // Get yesterday's OHLC data
        datetime yesterdayTime = iTime(currentSymbolName, PERIOD_D1, 1);
        double yesterdayOpen = iOpen(currentSymbolName, PERIOD_D1, 1);
        double yesterdayHigh = iHigh(currentSymbolName, PERIOD_D1, 1);
        double yesterdayLow = iLow(currentSymbolName, PERIOD_D1, 1);
        double yesterdayClose = iClose(currentSymbolName, PERIOD_D1, 1);
        
        // Determine if previous day was bullish or bearish
        prevDayBullish = (yesterdayClose > yesterdayOpen);
        
        // Update high, low and time
        prevDayHigh = yesterdayHigh;
        prevDayLow = yesterdayLow;
        prevDayTime = iTime(currentSymbolName, PERIOD_D1, 0);
        
        // Get today's start time and next day's start time for truncation
        todayStartTime = iTime(currentSymbolName, PERIOD_D1, 0);
        
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
        ObjectsDeleteAll(0, "Condition_");
        ObjectsDeleteAll(0, "CondMarker_");
        
        // Always draw main Fibonacci levels
        DrawMainFibonacciLevels();
        
        // Always show sub-fibs if enabled, regardless of strategy conditions
        if(ShowSubFib && AlwaysShowSubFib) {
            DrawSubFibonacciLevels();
        }
        
        // Force a chart redraw to ensure everything is displayed
        ChartRedraw(0);
    }
}
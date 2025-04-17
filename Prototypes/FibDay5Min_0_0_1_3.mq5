//+------------------------------------------------------------------+
//|                             FibDay5Min_Enhanced.mq5               |
//|                                                                   |
//|  Draws horizontal lines based on previous day's OHLC              |
//|  - Previous day high/low lines (solid/dashed based on direction)  |
//|  - Fibonacci levels between previous day's high and low           |
//|  - Sub-Fibonacci trend lines with configurable points             |
//|  - Lines are truncated to only show on current day                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.10"
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

// New input parameters for sub-Fibonacci trend lines
input string SubFibSection = "--- Sub-Fibonacci Settings ---"; // Sub-Fibonacci Settings
input bool   ShowSubFib = true;            // Show Sub-Fibonacci Trend Lines
input double StartPoint = 0.5;           // Starting Point for Sub-Fibonacci (0-1)
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
                // In bullish days, 0% is at the high, 100% at the low
                startPoint = prevDayHigh;  // 0% level
                endPoint = prevDayLow;     // 100% level
            }
            else
            {
                // In bearish days, 0% is at the low, 100% at the high
                startPoint = prevDayLow;   // 0% level
                endPoint = prevDayHigh;    // 100% level
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
            
            // Create Sub-Fibonacci levels if enabled
            if(ShowSubFib)
            {
                // Calculate the sub-fib range prices
                double subFibStartPrice = startPoint + (endPoint - startPoint) * StartPoint;
                double subFibEndPrice = startPoint + (endPoint - startPoint) * EndPoint;
                
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
        }
    }
    
    return(rates_total);
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
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Delete all created objects when indicator is removed
    ObjectsDeleteAll(0, "PrevDay_");
    ObjectsDeleteAll(0, "SubFib_");
    ObjectsDeleteAll(0, "Label_");
}
//+------------------------------------------------------------------+
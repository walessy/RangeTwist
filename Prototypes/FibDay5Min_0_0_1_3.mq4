//+------------------------------------------------------------------+
//| Helper function to create a shorter horizontal line for sub-fibs   |
//+------------------------------------------------------------------+
void CreateShorterHorizontalLine(string name, double price, int style, string tooltip, 
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
    int timeRange = (int)(nextDayStartTime - todayStartTime);
    
    // Calculate start and end times for the shorter line with offset
    datetime lineStartTime = todayStartTime + (int)(timeRange * startOffsetRatio);
    datetime lineEndTime = lineStartTime + (int)(timeRange * lengthRatio);
    
    // Create the horizontal line with shorter length and offset start
    ObjectCreate(name, OBJ_TREND, 0, lineStartTime, price, lineEndTime, price);
    ObjectSet(name, OBJPROP_COLOR, currentLineColor);
    ObjectSet(name, OBJPROP_STYLE, style);
    ObjectSet(name, OBJPROP_WIDTH, 1);
    ObjectSet(name, OBJPROP_RAY, false);  // No ray in MT4
    ObjectSetText(name, tooltip, 8, "Arial", Black);  // Set tooltip in MT4
    
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
        
        // Create text object for the label
        ObjectCreate(labelName, OBJ_TEXT, 0, lineStartTime, price);
        
        // Set the text
        ObjectSetText(labelName, labelText, LabelFontSize, "Arial", currentLineColor);
        
        // Position tied to price and time
        ObjectSet(labelName, OBJPROP_PRICE1, price);
        ObjectSet(labelName, OBJPROP_TIME1, lineStartTime);
        
        // Set anchor point (0 = ANCHOR_LEFT)
        ObjectSet(labelName, OBJPROP_ANCHOR, 0);
    }
}
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//|                             FibDay5Min_Enhanced.mq4               |
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
#property indicator_buffers 0

// Input parameters for original functionality
extern bool  UseDirectionalColors = true;   // Use direction-based colors (Bull/Bear)
extern color BullishColor = SkyBlue;        // Color for Bullish Days
extern color BearishColor = Maroon;         // Color for Bearish Days
extern color LineColor = DodgerBlue;        // Default Line Color (if not using directional)
extern bool  ShowFibLevels = true;          // Show Fibonacci Levels
extern bool  Show0Level = true;             // Show 0% Level
extern bool  Show23_6Level = true;          // Show 23.6% Level
extern bool  Show38_2Level = true;          // Show 38.2% Level
extern bool  Show50Level = true;            // Show 50% Level
extern bool  Show61_8Level = true;          // Show 61.8% Level
extern bool  Show76_4Level = true;          // Show 76.4% Level
extern bool  Show100Level = true;           // Show 100% Level
extern bool  Show161_8Level = false;        // Show 161.8% Level
extern bool  Show261_8Level = false;        // Show 261.8% Level
extern bool  ShowLabels = true;             // Show Price Labels on Lines
extern color LabelColor = Brown;            // Label Text Color
extern int   LabelFontSize = 8;             // Label Font Size

// New input parameters for sub-Fibonacci trend lines
extern string SubFibSection = "--- Sub-Fibonacci Settings ---"; // Sub-Fibonacci Settings
extern bool   ShowSubFib = true;            // Show Sub-Fibonacci Trend Lines
extern double StartPoint = 0.5;             // Starting Point for Sub-Fibonacci (0-1)
extern double EndPoint = 0.618;             // Ending Point for Sub-Fibonacci (0-1)
extern bool   UseCustomSubFibColor = false; // Use custom Sub-Fibonacci color (or inherit from main)
extern color  SubFibColor = Magenta;        // Custom Sub-Fibonacci Lines Color (if enabled)
extern double SubFibLineLength = 0.5;       // Length of Sub-Fib lines (0-1 ratio of day)
extern double SubFibStartOffset = 0.25;     // Start offset for Sub-Fib lines (0-1 ratio of day)
extern bool   ShowSubFib0Level = true;      // Show Sub-Fib 0% Level
extern bool   ShowSubFib23_6Level = true;   // Show Sub-Fib 23.6% Level
extern bool   ShowSubFib38_2Level = true;   // Show Sub-Fib 38.2% Level
extern bool   ShowSubFib50Level = true;     // Show Sub-Fib 50% Level
extern bool   ShowSubFib61_8Level = true;   // Show Sub-Fib 61.8% Level
extern bool   ShowSubFib76_4Level = true;   // Show Sub-Fib 76.4% Level
extern bool   ShowSubFib100Level = true;    // Show Sub-Fib 100% Level
extern bool   ShowSubFibLabels = true;      // Show Sub-Fib Labels

// Global variables
datetime prevDayTime = 0;
datetime todayStartTime = 0;
datetime nextDayStartTime = 0;
double prevDayHigh = 0;
double prevDayLow = 0;
bool prevDayBullish = true;
string currentSymbol = "";  // Track current symbol
bool showLevels[9];
bool showSubFibLevels[7];

// Fibonacci levels array
double fibLevels[9] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.764, 1.0, 1.618, 2.618};
double subFibLevels[7] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.764, 1.0};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int init()
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
    
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
int deinit()
{
    // Delete all created objects when indicator is removed
    ObjectsDeleteAll(0, "PrevDay_");
    ObjectsDeleteAll(0, "SubFib_");
    ObjectsDeleteAll(0, "Label_");
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int start()
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
        nextDayStartTime = todayStartTime + 86400;  // Add 86400 seconds (24 hours)
        
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
                                "Previous Day High: " + DoubleToStr(prevDayHigh, Digits));
            
            CreateHorizontalLine("PrevDay_Low", prevDayLow, prevDayBullish ? STYLE_DASH : STYLE_SOLID, 
                                "Previous Day Low: " + DoubleToStr(prevDayLow, Digits));
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
            for(int i = 0; i < 9; i++)
            {
                // Skip if this level is not enabled
                if(!showLevels[i]) continue;
                
                // Calculate the price for this level
                double levelPrice = startPoint + (endPoint - startPoint) * fibLevels[i];
                
                // Create the horizontal line
                string levelName = "PrevDay_Fib_" + DoubleToStr(fibLevels[i] * 100, 1);

                // Use solid line style for all main Fibonacci levels
                int lineStyle = STYLE_SOLID;
                    
                CreateHorizontalLine(levelName, levelPrice, lineStyle, 
                                    "Fib " + DoubleToStr(fibLevels[i] * 100, 1) + "%: " + 
                                    DoubleToStr(levelPrice, Digits));
            }
            
            // Create Sub-Fibonacci levels if enabled
            if(ShowSubFib)
            {
                // Calculate the sub-fib range prices
                double subFibStartPrice = startPoint + (endPoint - startPoint) * StartPoint;
                double subFibEndPrice = startPoint + (endPoint - startPoint) * EndPoint;
                
                // Loop through each Sub-Fibonacci level
                for(int i = 0; i < 7; i++)
                {
                    // Skip if this level is not enabled
                    if(!showSubFibLevels[i]) continue;
                    
                    // Calculate the price for this sub-fib level
                    double subLevelPrice = subFibStartPrice + (subFibEndPrice - subFibStartPrice) * subFibLevels[i];
                    
                    // Create the horizontal line for sub-fib
                    string subLevelName = "SubFib_" + DoubleToStr(subFibLevels[i] * 100, 1);
                    int subLineStyle = STYLE_DOT;  // Use dotted style for sub-fibs
                    
                    // Create the line with the specified sub-fib color and shorter length and offset
                    CreateShorterHorizontalLine(subLevelName, subLevelPrice, subLineStyle, 
                                        "SubFib " + DoubleToStr(subFibLevels[i] * 100, 1) + "%: " + 
                                        DoubleToStr(subLevelPrice, Digits), 
                                        UseCustomSubFibColor ? SubFibColor : CLR_NONE, 
                                        ShowSubFibLabels, SubFibLineLength, SubFibStartOffset);
                }
            }
        }
    }
    
    return(0);
}

//+------------------------------------------------------------------+
//| Helper function to create a horizontal line                       |
//+------------------------------------------------------------------+
void CreateHorizontalLine(string name, double price, int style, string tooltip, 
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
    ObjectCreate(name, OBJ_TREND, 0, todayStartTime, price, nextDayStartTime, price);
    ObjectSet(name, OBJPROP_COLOR, currentLineColor);
    ObjectSet(name, OBJPROP_STYLE, style);
    ObjectSet(name, OBJPROP_WIDTH, 1);
    ObjectSet(name, OBJPROP_RAY, false);  // No ray to the right
    ObjectSetText(name, tooltip, 8, "Arial", Black);  // Set tooltip in MT4
    
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
        
        // Create text object for the label
        ObjectCreate(labelName, OBJ_TEXT, 0, todayStartTime, price);
        
        // Set the text
        ObjectSetText(labelName, labelText, LabelFontSize, "Arial", currentLineColor);
        
        // Position tied to price and time
        ObjectSet(labelName, OBJPROP_PRICE1, price);
        ObjectSet(labelName, OBJPROP_TIME1, todayStartTime);
        
        // Set anchor point (0 = ANCHOR_LEFT)
        ObjectSet(labelName, OBJPROP_ANCHOR, 0);
    }
}
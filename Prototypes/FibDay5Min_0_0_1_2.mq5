//+------------------------------------------------------------------+
//|                                  FibDay5Min_0_0_1_1.mq5           |
//|                                                                   |
//|  Draws horizontal lines based on previous day's OHLC              |
//|  - Previous day high/low lines (solid/dashed based on direction)  |
//|  - Fibonacci levels between previous day's high and low           |
//|  - Lines are truncated to only show on current day                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots   0

// Input parameters
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

// Global variables
datetime prevDayTime = 0;
datetime todayStartTime = 0;
datetime nextDayStartTime = 0;
double prevDayHigh = 0;
double prevDayLow = 0;
bool prevDayBullish = true;
string currentSymbol = "";  // Track current symbol
bool showLevels[9] = {false, false, false, false, false, false, false, false, false};

// Fibonacci levels array
double fibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.764, 1.0, 1.618, 2.618};

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
                ENUM_LINE_STYLE lineStyle;
                
                // Use dashed line for 100% level, dotted for others
                if(MathAbs(fibLevels[i] - 1.0) < 0.0001)  // 100% level
                    lineStyle = STYLE_DASH;
                else
                    lineStyle = STYLE_DOT;
                    
                CreateHorizontalLine(levelName, levelPrice, lineStyle, 
                                    "Fib " + DoubleToString(fibLevels[i] * 100, 1) + "%: " + 
                                    DoubleToString(levelPrice, Digits()));
            }
        }
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Helper function to create a horizontal line                       |
//+------------------------------------------------------------------+
void CreateHorizontalLine(string name, double price, ENUM_LINE_STYLE style, string tooltip)
{
    // Determine line color based on bullish/bearish setting
    color currentLineColor;
    
    if(UseDirectionalColors)
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
    if(ShowLabels)
    {
        // Extract label text from tooltip (before the colon)
        string labelText = tooltip;
        int colonPos = StringFind(tooltip, ":");
        if(colonPos > 0)
            labelText = StringSubstr(tooltip, 0, colonPos);
            
        // Add "Day" prefix to the label text
        if(StringFind(labelText, "Previous Day") >= 0)
        {
            // Don't add "Day" if it already has "Previous Day" in the text
            // Just keep it as is
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
            
        // Create a simple text label at the start of the line
        string labelName = "Label_" + name;
        
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, todayStartTime, price))
        {
            // Set label properties - positioned at the start of the line
            ObjectSetDouble(0, labelName, OBJPROP_PRICE, price);
            ObjectSetInteger(0, labelName, OBJPROP_TIME, todayStartTime); // Align with start of the line
            ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
            
            // Determine label color - match line color
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, currentLineColor);
            
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LabelFontSize);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);  // Left aligned
            
            // Print debug info
            Print("Created label: ", labelName, " at price: ", price, " text: ", labelText);
        }
        else
        {
            Print("Failed to create label: ", labelName, " Error: ", GetLastError());
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
    ObjectsDeleteAll(0, "Label_");
}
//+------------------------------------------------------------------+
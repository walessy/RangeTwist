//+------------------------------------------------------------------+
//|                                  PreviousDayLines.mq5             |
//|                                                                   |
//|  Draws two horizontal lines based on previous day's OHLC          |
//|  - One solid line, one dashed line                                |
//|  - If previous day was bullish, high = solid and low = dashed     |
//|  - If previous day was bearish, low = solid and high = dashed     |
//|  - Lines are truncated to only show on current day                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots   0

// Input parameters
input color LineColor = clrDodgerBlue; // Line Color

// Global variables
datetime prevDayTime = 0;
datetime todayStartTime = 0;
datetime nextDayStartTime = 0;
double prevDayHigh = 0;
double prevDayLow = 0;
bool prevDayBullish = true;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
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
    if(prevDayTime != currentDay)
    {
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
        
        // Create the two horizontal lines as trend lines (not hlines) for truncation
        // High line
        string highLineName = "PrevDay_High";
        ObjectCreate(0, highLineName, OBJ_TREND, 0, todayStartTime, prevDayHigh, nextDayStartTime, prevDayHigh);
        ObjectSetInteger(0, highLineName, OBJPROP_COLOR, LineColor);
        ObjectSetInteger(0, highLineName, OBJPROP_STYLE, prevDayBullish ? STYLE_SOLID : STYLE_DASH);
        ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, highLineName, OBJPROP_RAY_LEFT, false);  // No ray to the left
        ObjectSetInteger(0, highLineName, OBJPROP_RAY_RIGHT, false); // No ray to the right
        ObjectSetString(0, highLineName, OBJPROP_TOOLTIP, "Previous Day High: " + DoubleToString(prevDayHigh, Digits()));
        
        // Low line
        string lowLineName = "PrevDay_Low";
        ObjectCreate(0, lowLineName, OBJ_TREND, 0, todayStartTime, prevDayLow, nextDayStartTime, prevDayLow);
        ObjectSetInteger(0, lowLineName, OBJPROP_COLOR, LineColor);
        ObjectSetInteger(0, lowLineName, OBJPROP_STYLE, prevDayBullish ? STYLE_DASH : STYLE_SOLID);
        ObjectSetInteger(0, lowLineName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, lowLineName, OBJPROP_RAY_LEFT, false);  // No ray to the left
        ObjectSetInteger(0, lowLineName, OBJPROP_RAY_RIGHT, false); // No ray to the right
        ObjectSetString(0, lowLineName, OBJPROP_TOOLTIP, "Previous Day Low: " + DoubleToString(prevDayLow, Digits()));
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Delete all created objects when indicator is removed
    ObjectsDeleteAll(0, "PrevDay_");
}
//+------------------------------------------------------------------+
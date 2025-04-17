//+------------------------------------------------------------------+
//|                                       First5MinBarFixed.mq5      |
//+------------------------------------------------------------------+
#property copyright "YourName"
#property link      "YourWebsite"
#property version   "1.05"
#property indicator_chart_window
#property description "Draws vertical lines at specified minute markers"

// Input parameters
input color BullishColor = clrLightBlue;    // Color for bullish bar
input color BearishColor = clrLightPink; // Color for bearish bar
input int MinuteMarker1 = 5;           // First minute marker (e.g. 5 for 5 minutes past the hour)
input int MinuteMarker1Width = 2;      // Line width for first minute marker
input int MinuteMarker2 = 0;           // Second minute marker (e.g. 0 for the hour marker)
input int MinuteMarker2Width = 4;      // Line width for second minute marker
input bool ShowMinuteMarker1 = true;   // Show first minute marker
input bool ShowMinuteMarker2 = true;   // Show second minute marker

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Clean up any previous indicator objects when reloading
   ObjectsDeleteAll(0, "Line_", -1, -1);
   Print("Previous indicator lines cleaned up during initialization");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all objects created by this indicator
   ObjectsDeleteAll(0, "Line_", -1, -1);
   Print("All indicator lines deleted during deinitialization");
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
    Print("rates_total = ", rates_total, ", prev_calculated = ", prev_calculated);
    
    int start = 0; // Default to processing all bars
    if (prev_calculated > 0) // On subsequent updates
    {
        start = prev_calculated - 1; // Start from the last unprocessed bar
    }
    
    for (int i = start; i < rates_total; i++)
    {
        datetime barTime = time[i];
        
        MqlDateTime dt;
        TimeToStruct(barTime, dt);
        int minute = dt.min;
        int hour = dt.hour;
        
        string lineName;
        bool created;
        
        // Check for first minute marker (default: 5 min)
        if (ShowMinuteMarker1 && minute == MinuteMarker1)
        {
            lineName = "Line_" + IntegerToString(i) + "_" + TimeToString(barTime, TIME_MINUTES);
            if (ObjectFind(0, lineName) < 0) // MT5 returns -1 if object isn't found
            {
                created = ObjectCreate(0, lineName, OBJ_VLINE, 0, barTime, 0);
                if (created)
                {
                    ObjectSetInteger(0, lineName, OBJPROP_COLOR, (close[i] > open[i]) ? BullishColor : BearishColor);
                    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, MinuteMarker1Width);
                    ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
     
                    ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
                    Print("Line created: ", lineName, " at ", TimeToString(barTime), " (Marker 1)");
                }
                else
                {
                    Print("Failed to create line: ", lineName);
                }
            }
        }
        
        // Check for second minute marker (default: 0 min / hour marker)
        if (ShowMinuteMarker2 && minute == MinuteMarker2)
        {
            lineName = "Line_" + IntegerToString(i) + "_" + TimeToString(barTime, TIME_MINUTES);
            if (ObjectFind(0, lineName) < 0) // MT5 returns -1 if object isn't found
            {
                created = ObjectCreate(0, lineName, OBJ_VLINE, 0, barTime, 0);
                if (created)
                {
                    ObjectSetInteger(0, lineName, OBJPROP_COLOR, (close[i] > open[i]) ? BullishColor : BearishColor);
                    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, MinuteMarker2Width);
                    ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
                    ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
                    Print("Line created: ", lineName, " at ", TimeToString(barTime), " (Marker 2)");
                }
                else
                {
                    Print("Failed to create line: ", lineName);
                }
            }
        }
    }
    
    // Return the total number of bars processed
    return(rates_total);
}
//+------------------------------------------------------------------+
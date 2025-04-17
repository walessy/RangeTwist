// First, add these variables near the beginning of your code where you have the alert variables:
datetime lastAlertTime = 0;
int alertCooldownSeconds;
// Add these new variables to track alert states
enum ALERT_STATE
{
   ALERT_NONE,
   ALERT_ENTERING_OVERBOUGHT,
   ALERT_LEAVING_OVERBOUGHT,
   ALERT_ENTERING_OVERSOLD,
   ALERT_LEAVING_OVERSOLD
};

// Make this static so it persists between function calls
static ALERT_STATE lastAlertState = ALERT_NONE;

//+------------------------------------------------------------------+
//| Check for alerts                                                 |
//+------------------------------------------------------------------+
void CheckAlerts(int prev_bar, int curr_bar)
{
    // All your existing code for determining stoch1_entering_overbought, etc...
    
    // Then replace the final part with this:
    
    // Determine current alert state
    ALERT_STATE currentAlertState = ALERT_NONE;
    
    if(allEnteringOverbought)
        currentAlertState = ALERT_ENTERING_OVERBOUGHT;
    else if(allLeavingOverbought)
        currentAlertState = ALERT_LEAVING_OVERBOUGHT;
    else if(allEnteringOversold)
        currentAlertState = ALERT_ENTERING_OVERSOLD;
    else if(allLeavingOversold)
        currentAlertState = ALERT_LEAVING_OVERSOLD;
    
    // Only trigger alert if state has changed and cooldown period has passed
    if(currentAlertState != ALERT_NONE && 
       currentAlertState != lastAlertState && 
       TimeCurrent() > lastAlertTime + alertCooldownSeconds)
    {
        // Trigger the appropriate alert based on the current state
        switch(currentAlertState)
        {
            case ALERT_ENTERING_OVERBOUGHT:
                Alert("All selected stochastic lines entering overbought zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
                break;
                
            case ALERT_LEAVING_OVERBOUGHT:
                Alert("All selected stochastic lines leaving overbought zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
                break;
                
            case ALERT_ENTERING_OVERSOLD:
                Alert("All selected stochastic lines entering oversold zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
                break;
                
            case ALERT_LEAVING_OVERSOLD:
                Alert("All selected stochastic lines leaving oversold zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
                break;
        }
        
        // Update the last alert time and state
        lastAlertTime = TimeCurrent();
        lastAlertState = currentAlertState;
    }
}

// Also modify the OnCalculate function to only check for alerts on new bars
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
    // Your existing code...
    
    // Make sure time array is properly set as series
    ArraySetAsSeries(time, true);
    
    // Only check for alerts if a new bar has formed or it's the first calculation
    bool isNewBar = (prev_calculated == 0) || (prev_calculated > 0 && time[0] != time[1]);
    
    // Check for alerts only if a new bar has formed, data was copied successfully, and alerts are enabled
    if(isNewBar && copySuccess && EnableAlerts && rates_total > 1)
    {
        CheckAlerts(1, 0);
    }
    
    return(rates_total);
}
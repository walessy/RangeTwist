//+------------------------------------------------------------------+
//|                                     MultiStochasticBasic.mq5     |
//|                                     Copyright 2025, Your Name    |
//|                                          https://yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://yourwebsite.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_buffers 8
#property indicator_plots   8

// Plot settings for 4 Stochastics (K and D lines for each)
#property indicator_label1  "Stoch1_K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Stoch1_D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_label3  "Stoch2_K"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "Stoch2_D"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrBlue
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

#property indicator_label5  "Stoch3_K"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGreen
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

#property indicator_label6  "Stoch3_D"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrGreen
#property indicator_style6  STYLE_DOT
#property indicator_width6  1

#property indicator_label7  "Stoch4_K"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrMagenta
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2

#property indicator_label8  "Stoch4_D"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrMagenta
#property indicator_style8  STYLE_DOT
#property indicator_width8  1

// Input parameters
input int    Stoch1_KPeriod = 9;    // Stochastic 1 - K Period
input int    Stoch1_DPeriod = 3;    // Stochastic 1 - D Period
input int    Stoch1_Slowing = 1;    // Stochastic 1 - Slowing

input int    Stoch2_KPeriod = 14;   // Stochastic 2 - K Period
input int    Stoch2_DPeriod = 3;    // Stochastic 2 - D Period
input int    Stoch2_Slowing = 1;    // Stochastic 2 - Slowing

input int    Stoch3_KPeriod = 40;   // Stochastic 3 - K Period
input int    Stoch3_DPeriod = 4;    // Stochastic 3 - D Period
input int    Stoch3_Slowing = 1;    // Stochastic 3 - Slowing

input int    Stoch4_KPeriod = 60;   // Stochastic 4 - K Period
input int    Stoch4_DPeriod = 10;   // Stochastic 4 - D Period
input int    Stoch4_Slowing = 1;    // Stochastic 4 - Slowing

input ENUM_MA_METHOD  MA_Method = MODE_SMA;    // Moving Average Method
input ENUM_STO_PRICE  Price_Field = STO_LOWHIGH; // Price Field

input int    OverboughtLevel = 80;  // Overbought Level
input int    OversoldLevel = 20;    // Oversold Level
input bool   EnableAlerts = true;   // Enable Alerts

// Buffer arrays for 4 Stochastics
double Stoch1_K_Buffer[];
double Stoch1_D_Buffer[];
double Stoch2_K_Buffer[];
double Stoch2_D_Buffer[];
double Stoch3_K_Buffer[];
double Stoch3_D_Buffer[];
double Stoch4_K_Buffer[];
double Stoch4_D_Buffer[];

// Debug buffer to detect flatlines
int bars_without_update = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("---- Initializing Multi-Stochastic Basic ----");
    
    // Set buffer arrays for stochastics
    SetIndexBuffer(0, Stoch1_K_Buffer, INDICATOR_DATA);
    SetIndexBuffer(1, Stoch1_D_Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, Stoch2_K_Buffer, INDICATOR_DATA);
    SetIndexBuffer(3, Stoch2_D_Buffer, INDICATOR_DATA);
    SetIndexBuffer(4, Stoch3_K_Buffer, INDICATOR_DATA);
    SetIndexBuffer(5, Stoch3_D_Buffer, INDICATOR_DATA);
    SetIndexBuffer(6, Stoch4_K_Buffer, INDICATOR_DATA);
    SetIndexBuffer(7, Stoch4_D_Buffer, INDICATOR_DATA);
    
    // Set empty value (this ensures proper handling of empty areas)
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    // Set indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "Multi-Stochastic");
    
    // Set horizontal levels for overbought/oversold
    IndicatorSetInteger(INDICATOR_LEVELS, 2);
    IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, OverboughtLevel);
    IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, OversoldLevel);
    IndicatorSetString(INDICATOR_LEVELTEXT, 0, "Overbought");
    IndicatorSetString(INDICATOR_LEVELTEXT, 1, "Oversold");
    
    // Initialize buffer arrays with EMPTY_VALUE
    ArrayInitialize(Stoch1_K_Buffer, EMPTY_VALUE);
    ArrayInitialize(Stoch1_D_Buffer, EMPTY_VALUE);
    ArrayInitialize(Stoch2_K_Buffer, EMPTY_VALUE);
    ArrayInitialize(Stoch2_D_Buffer, EMPTY_VALUE);
    ArrayInitialize(Stoch3_K_Buffer, EMPTY_VALUE);
    ArrayInitialize(Stoch3_D_Buffer, EMPTY_VALUE);
    ArrayInitialize(Stoch4_K_Buffer, EMPTY_VALUE);
    ArrayInitialize(Stoch4_D_Buffer, EMPTY_VALUE);
    
    bars_without_update = 0;
    
    return(INIT_SUCCEEDED);
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
    // Debug info
    if(prev_calculated == 0)
        Print("Full calculation needed: prev_calculated = 0");
    
    // Skip if not enough data
    int max_period = MathMax(
        MathMax(Stoch1_KPeriod + Stoch1_DPeriod, Stoch2_KPeriod + Stoch2_DPeriod),
        MathMax(Stoch3_KPeriod + Stoch3_DPeriod, Stoch4_KPeriod + Stoch4_DPeriod)
    );
    
    if(rates_total < max_period) {
        Print("Not enough data: ", rates_total, " bars available, need at least ", max_period);
        return(0);
    }
    
    // Calculate starting position
    int start;
    if(prev_calculated == 0) {
        start = max_period;
        Print("Starting calculation from bar ", start);
    }
    else {
        start = MathMax(prev_calculated - 1, max_period);
    }
    
    // Calculate stochastics directly (no indicator handles)
    for(int i = start; i < rates_total; i++) {
        // Calculate Stochastic 1
        CalculateStochastic(i, Stoch1_KPeriod, Stoch1_DPeriod, Stoch1_Slowing, 
                            high, low, close, rates_total, Stoch1_K_Buffer, Stoch1_D_Buffer);
        
        // Calculate Stochastic 2
        CalculateStochastic(i, Stoch2_KPeriod, Stoch2_DPeriod, Stoch2_Slowing, 
                            high, low, close, rates_total, Stoch2_K_Buffer, Stoch2_D_Buffer);
        
        // Calculate Stochastic 3
        CalculateStochastic(i, Stoch3_KPeriod, Stoch3_DPeriod, Stoch3_Slowing, 
                            high, low, close, rates_total, Stoch3_K_Buffer, Stoch3_D_Buffer);
        
        // Calculate Stochastic 4
        CalculateStochastic(i, Stoch4_KPeriod, Stoch4_DPeriod, Stoch4_Slowing, 
                            high, low, close, rates_total, Stoch4_K_Buffer, Stoch4_D_Buffer);
    }
    
    // Reset flatline detection counter
    bars_without_update = 0;
    
    // Check for alerts on the current bar
    if(EnableAlerts && rates_total > 1) {
        CheckAlerts(rates_total-2, rates_total-1);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Stochastic for specific parameters                     |
//+------------------------------------------------------------------+
void CalculateStochastic(int index, int k_period, int d_period, int slowing,
                         const double &high[], const double &low[], const double &close[],
                         int rates_total, double &k_buffer[], double &d_buffer[])
{
    // Skip calculation if not enough data
    if(index < k_period + d_period - 1)
        return;
    
    // Find highest high and lowest low for k_period
    double highest_high = high[index];
    double lowest_low = low[index];
    
    for(int j = 1; j < k_period; j++) {
        int prev_index = index - j;
        if(prev_index >= 0) {
            highest_high = MathMax(highest_high, high[prev_index]);
            lowest_low = MathMin(lowest_low, low[prev_index]);
        }
    }
    
    // Calculate %K
    double range = highest_high - lowest_low;
    if(range > 0)
        k_buffer[index] = 100.0 * ((close[index] - lowest_low) / range);
    else
        k_buffer[index] = 50.0;  // Default to middle if no range
    
    // Apply slowing if needed
    if(slowing > 1) {
        double sum = k_buffer[index];
        int count = 1;
        
        for(int j = 1; j < slowing; j++) {
            int prev_index = index - j;
            if(prev_index >= 0 && k_buffer[prev_index] != EMPTY_VALUE) {
                sum += k_buffer[prev_index];
                count++;
            }
        }
        
        if(count > 0)
            k_buffer[index] = sum / count;
    }
    
    // Calculate %D (simple moving average of %K)
    if(index >= k_period + d_period - 1) {
        double sum = 0;
        int count = 0;
        
        for(int j = 0; j < d_period; j++) {
            int prev_index = index - j;
            if(prev_index >= 0 && k_buffer[prev_index] != EMPTY_VALUE) {
                sum += k_buffer[prev_index];
                count++;
            }
        }
        
        if(count > 0)
            d_buffer[index] = sum / count;
        else
            d_buffer[index] = k_buffer[index];  // Default to %K if not enough data
    }
}

//+------------------------------------------------------------------+
//| Function to check for alerts                                     |
//+------------------------------------------------------------------+
void CheckAlerts(int prev_bar, int curr_bar)
{
    // Stochastic 1 crossings
    bool stoch1_entering_overbought = Stoch1_K_Buffer[prev_bar] < OverboughtLevel && Stoch1_K_Buffer[curr_bar] >= OverboughtLevel;
    bool stoch1_leaving_overbought = Stoch1_K_Buffer[prev_bar] >= OverboughtLevel && Stoch1_K_Buffer[curr_bar] < OverboughtLevel;
    bool stoch1_entering_oversold = Stoch1_K_Buffer[prev_bar] > OversoldLevel && Stoch1_K_Buffer[curr_bar] <= OversoldLevel;
    bool stoch1_leaving_oversold = Stoch1_K_Buffer[prev_bar] <= OversoldLevel && Stoch1_K_Buffer[curr_bar] > OversoldLevel;
    
    // Stochastic 2 crossings
    bool stoch2_entering_overbought = Stoch2_K_Buffer[prev_bar] < OverboughtLevel && Stoch2_K_Buffer[curr_bar] >= OverboughtLevel;
    bool stoch2_leaving_overbought = Stoch2_K_Buffer[prev_bar] >= OverboughtLevel && Stoch2_K_Buffer[curr_bar] < OverboughtLevel;
    bool stoch2_entering_oversold = Stoch2_K_Buffer[prev_bar] > OversoldLevel && Stoch2_K_Buffer[curr_bar] <= OversoldLevel;
    bool stoch2_leaving_oversold = Stoch2_K_Buffer[prev_bar] <= OversoldLevel && Stoch2_K_Buffer[curr_bar] > OversoldLevel;
    
    // Stochastic 3 crossings
    bool stoch3_entering_overbought = Stoch3_K_Buffer[prev_bar] < OverboughtLevel && Stoch3_K_Buffer[curr_bar] >= OverboughtLevel;
    bool stoch3_leaving_overbought = Stoch3_K_Buffer[prev_bar] >= OverboughtLevel && Stoch3_K_Buffer[curr_bar] < OverboughtLevel;
    bool stoch3_entering_oversold = Stoch3_K_Buffer[prev_bar] > OversoldLevel && Stoch3_K_Buffer[curr_bar] <= OversoldLevel;
    bool stoch3_leaving_oversold = Stoch3_K_Buffer[prev_bar] <= OversoldLevel && Stoch3_K_Buffer[curr_bar] > OversoldLevel;
    
    // Stochastic 4 crossings
    bool stoch4_entering_overbought = Stoch4_K_Buffer[prev_bar] < OverboughtLevel && Stoch4_K_Buffer[curr_bar] >= OverboughtLevel;
    bool stoch4_leaving_overbought = Stoch4_K_Buffer[prev_bar] >= OverboughtLevel && Stoch4_K_Buffer[curr_bar] < OverboughtLevel;
    bool stoch4_entering_oversold = Stoch4_K_Buffer[prev_bar] > OversoldLevel && Stoch4_K_Buffer[curr_bar] <= OversoldLevel;
    bool stoch4_leaving_oversold = Stoch4_K_Buffer[prev_bar] <= OversoldLevel && Stoch4_K_Buffer[curr_bar] > OversoldLevel;
    
    // Check if all stochastics meet the conditions
    bool allEnteringOverbought = stoch1_entering_overbought && stoch2_entering_overbought && 
                              stoch3_entering_overbought && stoch4_entering_overbought;
                              
    bool allLeavingOverbought = stoch1_leaving_overbought && stoch2_leaving_overbought && 
                             stoch3_leaving_overbought && stoch4_leaving_overbought;
                             
    bool allEnteringOversold = stoch1_entering_oversold && stoch2_entering_oversold && 
                            stoch3_entering_oversold && stoch4_entering_oversold;
                            
    bool allLeavingOversold = stoch1_leaving_oversold && stoch2_leaving_oversold && 
                           stoch3_leaving_oversold && stoch4_leaving_oversold;
    
    // Trigger appropriate alerts
    if(allEnteringOverbought)
    {
        Alert("All selected stochastic lines entering overbought zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
    }
    else if(allLeavingOverbought)
    {
        Alert("All selected stochastic lines leaving overbought zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
    }
    else if(allEnteringOversold)
    {
        Alert("All selected stochastic lines entering oversold zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
    }
    else if(allLeavingOversold)
    {
        Alert("All selected stochastic lines leaving oversold zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
    }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Print deinitialization reason - helpful for debugging
    if(reason == REASON_CHARTCHANGE)
        Print("Deinitializing due to chart period change");
    else if(reason == REASON_PARAMETERS)
        Print("Deinitializing due to input parameters change");
    else if(reason == REASON_RECOMPILE)
        Print("Deinitializing due to program recompilation");
    else if(reason == REASON_REMOVE)
        Print("Deinitializing due to indicator removal from chart");
}
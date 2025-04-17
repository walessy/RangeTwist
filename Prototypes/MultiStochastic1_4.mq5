// Alert variables
datetime lastAlertTime = 0;
int alertCooldownSeconds;//+------------------------------------------------------------------+
//|                                          MultiStochastic.mq5     |
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
input ENUM_LINE_STYLE Stoch1_LineStyle = STYLE_SOLID; // Stochastic 1 - K Line Style

input int    Stoch2_KPeriod = 14;   // Stochastic 2 - K Period
input int    Stoch2_DPeriod = 3;    // Stochastic 2 - D Period
input int    Stoch2_Slowing = 1;    // Stochastic 2 - Slowing
input ENUM_LINE_STYLE Stoch2_LineStyle = STYLE_SOLID; // Stochastic 2 - K Line Style

input int    Stoch3_KPeriod = 40;   // Stochastic 3 - K Period
input int    Stoch3_DPeriod = 4;    // Stochastic 3 - D Period
input int    Stoch3_Slowing = 1;    // Stochastic 3 - Slowing
input ENUM_LINE_STYLE Stoch3_LineStyle = STYLE_SOLID; // Stochastic 3 - K Line Style

input int    Stoch4_KPeriod = 60;   // Stochastic 4 - K Period
input int    Stoch4_DPeriod = 10;   // Stochastic 4 - D Period
input int    Stoch4_Slowing = 1;    // Stochastic 4 - Slowing
input ENUM_LINE_STYLE Stoch4_LineStyle = STYLE_SOLID; // Stochastic 4 - K Line Style

input ENUM_MA_METHOD  MA_Method = MODE_SMA;    // Moving Average Method
input ENUM_STO_PRICE  Price_Field = STO_LOWHIGH; // Price Field

// Display options for each stochastic
enum ENUM_DISPLAY_LINES
{
   SHOW_K_ONLY,    // K Line Only
   SHOW_D_ONLY,    // D Line Only (Default)
   SHOW_BOTH       // Both K and D Lines
};

input ENUM_DISPLAY_LINES Stoch1_Display = SHOW_D_ONLY; // Stochastic 1 - Lines to Display
input ENUM_DISPLAY_LINES Stoch2_Display = SHOW_D_ONLY; // Stochastic 2 - Lines to Display
input ENUM_DISPLAY_LINES Stoch3_Display = SHOW_D_ONLY; // Stochastic 3 - Lines to Display
input ENUM_DISPLAY_LINES Stoch4_Display = SHOW_D_ONLY; // Stochastic 4 - Lines to Display

input int    OverboughtLevel = 80;  // Overbought Level
input int    OversoldLevel = 20;    // Oversold Level
input bool   EnableAlerts = true;   // Enable Alerts
input int    AlertCooldown = 5;     // Alert Cooldown (minutes)

// Buffer arrays for 4 Stochastics
double Stoch1_K_Buffer[];
double Stoch1_D_Buffer[];
double Stoch2_K_Buffer[];
double Stoch2_D_Buffer[];
double Stoch3_K_Buffer[];
double Stoch3_D_Buffer[];
double Stoch4_K_Buffer[];
double Stoch4_D_Buffer[];

// Stochastic indicator handles
int Stoch1_Handle;
int Stoch2_Handle;
int Stoch3_Handle;
int Stoch4_Handle;

// Global variables to track timeframe changes
ENUM_TIMEFRAMES currentTimeframe = PERIOD_CURRENT;
datetime lastCalculationTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Record current timeframe
    currentTimeframe = Period();
    Print("Initializing Multi-Stochastic on timeframe: ", EnumToString(currentTimeframe));
    
    // Set buffer arrays for stochastics
    SetIndexBuffer(0, Stoch1_K_Buffer, INDICATOR_DATA);
    SetIndexBuffer(1, Stoch1_D_Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, Stoch2_K_Buffer, INDICATOR_DATA);
    SetIndexBuffer(3, Stoch2_D_Buffer, INDICATOR_DATA);
    SetIndexBuffer(4, Stoch3_K_Buffer, INDICATOR_DATA);
    SetIndexBuffer(5, Stoch3_D_Buffer, INDICATOR_DATA);
    SetIndexBuffer(6, Stoch4_K_Buffer, INDICATOR_DATA);
    SetIndexBuffer(7, Stoch4_D_Buffer, INDICATOR_DATA);
    
    // Set plotting properties for all buffers
    for (int i = 0; i < 8; i++)
    {
        PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_LINE);
        PlotIndexSetInteger(i, PLOT_SHOW_DATA, true);
        PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    }
    
    // Set specific line styles for K and D lines
    PlotIndexSetInteger(0, PLOT_LINE_STYLE, Stoch1_LineStyle);
    PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_DOT);
    PlotIndexSetInteger(2, PLOT_LINE_STYLE, Stoch2_LineStyle);
    PlotIndexSetInteger(3, PLOT_LINE_STYLE, STYLE_DOT);
    PlotIndexSetInteger(4, PLOT_LINE_STYLE, Stoch3_LineStyle);
    PlotIndexSetInteger(5, PLOT_LINE_STYLE, STYLE_DOT);
    PlotIndexSetInteger(6, PLOT_LINE_STYLE, Stoch4_LineStyle);
    PlotIndexSetInteger(7, PLOT_LINE_STYLE, STYLE_DOT);
    
    // Initialize stochastic handles with proper error handling and explicit timeframe
    Stoch1_Handle = iStochastic(Symbol(), Period(), Stoch1_KPeriod, Stoch1_DPeriod, Stoch1_Slowing, MA_Method, Price_Field);
    if(Stoch1_Handle == INVALID_HANDLE)
    {
        Print("Failed to create Stochastic 1 handle: ", GetLastError());
        return(INIT_FAILED);
    }
    
    Stoch2_Handle = iStochastic(Symbol(), Period(), Stoch2_KPeriod, Stoch2_DPeriod, Stoch2_Slowing, MA_Method, Price_Field);
    if(Stoch2_Handle == INVALID_HANDLE)
    {
        Print("Failed to create Stochastic 2 handle: ", GetLastError());
        IndicatorRelease(Stoch1_Handle); // Clean up previous handle
        return(INIT_FAILED);
    }
    
    Stoch3_Handle = iStochastic(Symbol(), Period(), Stoch3_KPeriod, Stoch3_DPeriod, Stoch3_Slowing, MA_Method, Price_Field);
    if(Stoch3_Handle == INVALID_HANDLE)
    {
        Print("Failed to create Stochastic 3 handle: ", GetLastError());
        IndicatorRelease(Stoch1_Handle); // Clean up previous handles
        IndicatorRelease(Stoch2_Handle);
        return(INIT_FAILED);
    }
    
    Stoch4_Handle = iStochastic(Symbol(), Period(), Stoch4_KPeriod, Stoch4_DPeriod, Stoch4_Slowing, MA_Method, Price_Field);
    if(Stoch4_Handle == INVALID_HANDLE)
    {
        Print("Failed to create Stochastic 4 handle: ", GetLastError());
        IndicatorRelease(Stoch1_Handle); // Clean up previous handles
        IndicatorRelease(Stoch2_Handle);
        IndicatorRelease(Stoch3_Handle);
        return(INIT_FAILED);
    }
    
    // Set indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "Multi-Stochastic");
    
    // Set horizontal levels for overbought/oversold
    IndicatorSetInteger(INDICATOR_LEVELS, 2);
    IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, OverboughtLevel);
    IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, OversoldLevel);
    IndicatorSetString(INDICATOR_LEVELTEXT, 0, "Overbought");
    IndicatorSetString(INDICATOR_LEVELTEXT, 1, "Oversold");
    
    // Convert cooldown from minutes to seconds
    alertCooldownSeconds = AlertCooldown * 60;
    
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
    // Check if timeframe has changed since last calculation
    if(Period() != currentTimeframe) {
        Print("Timeframe changed from ", EnumToString(currentTimeframe), " to ", EnumToString(Period()));
        currentTimeframe = Period();
        
        // Clear buffers and force full recalculation
        ArrayInitialize(Stoch1_K_Buffer, EMPTY_VALUE);
        ArrayInitialize(Stoch1_D_Buffer, EMPTY_VALUE);
        ArrayInitialize(Stoch2_K_Buffer, EMPTY_VALUE);
        ArrayInitialize(Stoch2_D_Buffer, EMPTY_VALUE);
        ArrayInitialize(Stoch3_K_Buffer, EMPTY_VALUE);
        ArrayInitialize(Stoch3_D_Buffer, EMPTY_VALUE);
        ArrayInitialize(Stoch4_K_Buffer, EMPTY_VALUE);
        ArrayInitialize(Stoch4_D_Buffer, EMPTY_VALUE);
        
        // Release and recreate indicator handles for the new timeframe
        IndicatorRelease(Stoch1_Handle);
        IndicatorRelease(Stoch2_Handle);
        IndicatorRelease(Stoch3_Handle);
        IndicatorRelease(Stoch4_Handle);
        
        Stoch1_Handle = iStochastic(Symbol(), Period(), Stoch1_KPeriod, Stoch1_DPeriod, Stoch1_Slowing, MA_Method, Price_Field);
        Stoch2_Handle = iStochastic(Symbol(), Period(), Stoch2_KPeriod, Stoch2_DPeriod, Stoch2_Slowing, MA_Method, Price_Field);
        Stoch3_Handle = iStochastic(Symbol(), Period(), Stoch3_KPeriod, Stoch3_DPeriod, Stoch3_Slowing, MA_Method, Price_Field);
        Stoch4_Handle = iStochastic(Symbol(), Period(), Stoch4_KPeriod, Stoch4_DPeriod, Stoch4_Slowing, MA_Method, Price_Field);
        
        if(Stoch1_Handle == INVALID_HANDLE || Stoch2_Handle == INVALID_HANDLE || 
           Stoch3_Handle == INVALID_HANDLE || Stoch4_Handle == INVALID_HANDLE) {
            Print("Failed to create stochastic handles after timeframe change");
            return(0);
        }
    }
    
    // For real-time chart updates, check if enough time has passed since the last calculation
    if(TimeCurrent() - lastCalculationTime < 1 && prev_calculated > 0) {
        // Too frequent updates, use previous calculations
        return(prev_calculated);
    }
    
    lastCalculationTime = TimeCurrent();
    
    // Skip if not enough data
    if(rates_total <= MathMax(MathMax(Stoch1_KPeriod, Stoch2_KPeriod), MathMax(Stoch3_KPeriod, Stoch4_KPeriod)))
      return(0);
    
    // Calculate starting position
    int start;
    if(prev_calculated == 0)
      start = 0;
    else
      start = prev_calculated - 1;
    
    // Arrays for stochastic values
    double K1[], D1[], K2[], D2[], K3[], D3[], K4[], D4[];
    
    // Ensure the arrays are big enough
    ArrayResize(K1, rates_total);
    ArrayResize(D1, rates_total);
    ArrayResize(K2, rates_total);
    ArrayResize(D2, rates_total);
    ArrayResize(K3, rates_total);
    ArrayResize(D3, rates_total);
    ArrayResize(K4, rates_total);
    ArrayResize(D4, rates_total);
    
    // Sort stochastic values in reverse order (newest first)
    ArraySetAsSeries(K1, true);
    ArraySetAsSeries(D1, true);
    ArraySetAsSeries(K2, true);
    ArraySetAsSeries(D2, true);
    ArraySetAsSeries(K3, true);
    ArraySetAsSeries(D3, true);
    ArraySetAsSeries(K4, true);
    ArraySetAsSeries(D4, true);
    
    // Sort buffer arrays in reverse order
    ArraySetAsSeries(Stoch1_K_Buffer, true);
    ArraySetAsSeries(Stoch1_D_Buffer, true);
    ArraySetAsSeries(Stoch2_K_Buffer, true);
    ArraySetAsSeries(Stoch2_D_Buffer, true);
    ArraySetAsSeries(Stoch3_K_Buffer, true);
    ArraySetAsSeries(Stoch3_D_Buffer, true);
    ArraySetAsSeries(Stoch4_K_Buffer, true);
    ArraySetAsSeries(Stoch4_D_Buffer, true);
    ArraySetAsSeries(time, true);
    
    // Copy stochastic values from indicators with error handling
    bool copySuccess = true;
    
    // Copy stochastic 1 values
    if(CopyBuffer(Stoch1_Handle, 0, 0, rates_total, K1) <= 0) {
        Print("Failed to copy Stochastic 1 K values: ", GetLastError());
        ArrayFill(K1, 0, rates_total, 50); // Fill with middle value
        copySuccess = false;
    }
    if(CopyBuffer(Stoch1_Handle, 1, 0, rates_total, D1) <= 0) {
        Print("Failed to copy Stochastic 1 D values: ", GetLastError());
        ArrayFill(D1, 0, rates_total, 50);
        copySuccess = false;
    }
    
    // Copy stochastic 2 values
    if(CopyBuffer(Stoch2_Handle, 0, 0, rates_total, K2) <= 0) {
        Print("Failed to copy Stochastic 2 K values: ", GetLastError());
        ArrayFill(K2, 0, rates_total, 50);
        copySuccess = false;
    }
    if(CopyBuffer(Stoch2_Handle, 1, 0, rates_total, D2) <= 0) {
        Print("Failed to copy Stochastic 2 D values: ", GetLastError());
        ArrayFill(D2, 0, rates_total, 50);
        copySuccess = false;
    }
    
    // Copy stochastic 3 values
    if(CopyBuffer(Stoch3_Handle, 0, 0, rates_total, K3) <= 0) {
        Print("Failed to copy Stochastic 3 K values: ", GetLastError());
        ArrayFill(K3, 0, rates_total, 50);
        copySuccess = false;
    }
    if(CopyBuffer(Stoch3_Handle, 1, 0, rates_total, D3) <= 0) {
        Print("Failed to copy Stochastic 3 D values: ", GetLastError());
        ArrayFill(D3, 0, rates_total, 50);
        copySuccess = false;
    }
    
    // Copy stochastic 4 values
    if(CopyBuffer(Stoch4_Handle, 0, 0, rates_total, K4) <= 0) {
        Print("Failed to copy Stochastic 4 K values: ", GetLastError());
        ArrayFill(K4, 0, rates_total, 50);
        copySuccess = false;
    }
    if(CopyBuffer(Stoch4_Handle, 1, 0, rates_total, D4) <= 0) {
        Print("Failed to copy Stochastic 4 D values: ", GetLastError());
        ArrayFill(D4, 0, rates_total, 50);
        copySuccess = false;
    }
    
    // Copy values to output buffers
    for(int i = start; i < rates_total; i++)
    {
        // Stochastic 1 display options
        if(Stoch1_Display == SHOW_K_ONLY || Stoch1_Display == SHOW_BOTH)
            Stoch1_K_Buffer[i] = K1[i];
        else
            Stoch1_K_Buffer[i] = EMPTY_VALUE;  // Hide K line
            
        if(Stoch1_Display == SHOW_D_ONLY || Stoch1_Display == SHOW_BOTH)
            Stoch1_D_Buffer[i] = D1[i];
        else
            Stoch1_D_Buffer[i] = EMPTY_VALUE;  // Hide D line
        
        // Stochastic 2 display options    
        if(Stoch2_Display == SHOW_K_ONLY || Stoch2_Display == SHOW_BOTH)
            Stoch2_K_Buffer[i] = K2[i];
        else
            Stoch2_K_Buffer[i] = EMPTY_VALUE;  // Hide K line
            
        if(Stoch2_Display == SHOW_D_ONLY || Stoch2_Display == SHOW_BOTH)
            Stoch2_D_Buffer[i] = D2[i];
        else
            Stoch2_D_Buffer[i] = EMPTY_VALUE;  // Hide D line
        
        // Stochastic 3 display options
        if(Stoch3_Display == SHOW_K_ONLY || Stoch3_Display == SHOW_BOTH)
            Stoch3_K_Buffer[i] = K3[i];
        else
            Stoch3_K_Buffer[i] = EMPTY_VALUE;  // Hide K line
            
        if(Stoch3_Display == SHOW_D_ONLY || Stoch3_Display == SHOW_BOTH)
            Stoch3_D_Buffer[i] = D3[i];
        else
            Stoch3_D_Buffer[i] = EMPTY_VALUE;  // Hide D line
        
        // Stochastic 4 display options
        if(Stoch4_Display == SHOW_K_ONLY || Stoch4_Display == SHOW_BOTH)
            Stoch4_K_Buffer[i] = K4[i];
        else
            Stoch4_K_Buffer[i] = EMPTY_VALUE;  // Hide K line
            
        if(Stoch4_Display == SHOW_D_ONLY || Stoch4_Display == SHOW_BOTH)
            Stoch4_D_Buffer[i] = D4[i];
        else
            Stoch4_D_Buffer[i] = EMPTY_VALUE;  // Hide D line
    }
    
    // Check for alerts only if data was copied successfully
    if(copySuccess && EnableAlerts && rates_total > 1 && time[0] > lastAlertTime + alertCooldownSeconds)
    {
        CheckAlerts(1, 0);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Print the reason for deinitialization (useful for debugging)
    if(reason == REASON_CHARTCHANGE)
        Print("Deinitializing due to chart period change");
    else if(reason == REASON_PARAMETERS)
        Print("Deinitializing due to input parameters change");
    else if(reason == REASON_RECOMPILE)
        Print("Deinitializing due to program recompilation");
    else if(reason == REASON_REMOVE)
        Print("Deinitializing due to indicator removal from chart");
    
    // Release indicator handles
    IndicatorRelease(Stoch1_Handle);
    IndicatorRelease(Stoch2_Handle);
    IndicatorRelease(Stoch3_Handle);
    IndicatorRelease(Stoch4_Handle);
    
    // Reset global variables
    currentTimeframe = PERIOD_CURRENT;
    lastCalculationTime = 0;
}

//+------------------------------------------------------------------+
//| Function to check for alerts                                     |
//+------------------------------------------------------------------+
void CheckAlerts(int prev_bar, int curr_bar)
{
    bool stoch1_entering_overbought = false;
    bool stoch2_entering_overbought = false;
    bool stoch3_entering_overbought = false;
    bool stoch4_entering_overbought = false;
    
    bool stoch1_leaving_overbought = false;
    bool stoch2_leaving_overbought = false;
    bool stoch3_leaving_overbought = false;
    bool stoch4_leaving_overbought = false;
    
    bool stoch1_entering_oversold = false;
    bool stoch2_entering_oversold = false;
    bool stoch3_entering_oversold = false;
    bool stoch4_entering_oversold = false;
    
    bool stoch1_leaving_oversold = false;
    bool stoch2_leaving_oversold = false;
    bool stoch3_leaving_oversold = false;
    bool stoch4_leaving_oversold = false;
    
    // Check stochastic 1 based on display selection
    if(Stoch1_Display == SHOW_K_ONLY) {
        stoch1_entering_overbought = Stoch1_K_Buffer[prev_bar] < OverboughtLevel && Stoch1_K_Buffer[curr_bar] >= OverboughtLevel;
        stoch1_leaving_overbought = Stoch1_K_Buffer[prev_bar] >= OverboughtLevel && Stoch1_K_Buffer[curr_bar] < OverboughtLevel;
        stoch1_entering_oversold = Stoch1_K_Buffer[prev_bar] > OversoldLevel && Stoch1_K_Buffer[curr_bar] <= OversoldLevel;
        stoch1_leaving_oversold = Stoch1_K_Buffer[prev_bar] <= OversoldLevel && Stoch1_K_Buffer[curr_bar] > OversoldLevel;
    } 
    else if(Stoch1_Display == SHOW_D_ONLY) {
        stoch1_entering_overbought = Stoch1_D_Buffer[prev_bar] < OverboughtLevel && Stoch1_D_Buffer[curr_bar] >= OverboughtLevel;
        stoch1_leaving_overbought = Stoch1_D_Buffer[prev_bar] >= OverboughtLevel && Stoch1_D_Buffer[curr_bar] < OverboughtLevel;
        stoch1_entering_oversold = Stoch1_D_Buffer[prev_bar] > OversoldLevel && Stoch1_D_Buffer[curr_bar] <= OversoldLevel;
        stoch1_leaving_oversold = Stoch1_D_Buffer[prev_bar] <= OversoldLevel && Stoch1_D_Buffer[curr_bar] > OversoldLevel;
    }
    else { // SHOW_BOTH - alert if either K or D crosses
        bool k_entering_overbought = Stoch1_K_Buffer[prev_bar] < OverboughtLevel && Stoch1_K_Buffer[curr_bar] >= OverboughtLevel;
        bool d_entering_overbought = Stoch1_D_Buffer[prev_bar] < OverboughtLevel && Stoch1_D_Buffer[curr_bar] >= OverboughtLevel;
        stoch1_entering_overbought = k_entering_overbought || d_entering_overbought;
        
        bool k_leaving_overbought = Stoch1_K_Buffer[prev_bar] >= OverboughtLevel && Stoch1_K_Buffer[curr_bar] < OverboughtLevel;
        bool d_leaving_overbought = Stoch1_D_Buffer[prev_bar] >= OverboughtLevel && Stoch1_D_Buffer[curr_bar] < OverboughtLevel;
        stoch1_leaving_overbought = k_leaving_overbought || d_leaving_overbought;
        
        bool k_entering_oversold = Stoch1_K_Buffer[prev_bar] > OversoldLevel && Stoch1_K_Buffer[curr_bar] <= OversoldLevel;
        bool d_entering_oversold = Stoch1_D_Buffer[prev_bar] > OversoldLevel && Stoch1_D_Buffer[curr_bar] <= OversoldLevel;
        stoch1_entering_oversold = k_entering_oversold || d_entering_oversold;
        
        bool k_leaving_oversold = Stoch1_K_Buffer[prev_bar] <= OversoldLevel && Stoch1_K_Buffer[curr_bar] > OversoldLevel;
        bool d_leaving_oversold = Stoch1_D_Buffer[prev_bar] <= OversoldLevel && Stoch1_D_Buffer[curr_bar] > OversoldLevel;
        stoch1_leaving_oversold = k_leaving_oversold || d_leaving_oversold;
    }
    
    // Check stochastic 2 based on display selection
    if(Stoch2_Display == SHOW_K_ONLY) {
        stoch2_entering_overbought = Stoch2_K_Buffer[prev_bar] < OverboughtLevel && Stoch2_K_Buffer[curr_bar] >= OverboughtLevel;
        stoch2_leaving_overbought = Stoch2_K_Buffer[prev_bar] >= OverboughtLevel && Stoch2_K_Buffer[curr_bar] < OverboughtLevel;
        stoch2_entering_oversold = Stoch2_K_Buffer[prev_bar] > OversoldLevel && Stoch2_K_Buffer[curr_bar] <= OversoldLevel;
        stoch2_leaving_oversold = Stoch2_K_Buffer[prev_bar] <= OversoldLevel && Stoch2_K_Buffer[curr_bar] > OversoldLevel;
    } 
    else if(Stoch2_Display == SHOW_D_ONLY) {
        stoch2_entering_overbought = Stoch2_D_Buffer[prev_bar] < OverboughtLevel && Stoch2_D_Buffer[curr_bar] >= OverboughtLevel;
        stoch2_leaving_overbought = Stoch2_D_Buffer[prev_bar] >= OverboughtLevel && Stoch2_D_Buffer[curr_bar] < OverboughtLevel;
        stoch2_entering_oversold = Stoch2_D_Buffer[prev_bar] > OversoldLevel && Stoch2_D_Buffer[curr_bar] <= OversoldLevel;
        stoch2_leaving_oversold = Stoch2_D_Buffer[prev_bar] <= OversoldLevel && Stoch2_D_Buffer[curr_bar] > OversoldLevel;
    }
    else { // SHOW_BOTH - alert if either K or D crosses
        bool k_entering_overbought = Stoch2_K_Buffer[prev_bar] < OverboughtLevel && Stoch2_K_Buffer[curr_bar] >= OverboughtLevel;
        bool d_entering_overbought = Stoch2_D_Buffer[prev_bar] < OverboughtLevel && Stoch2_D_Buffer[curr_bar] >= OverboughtLevel;
        stoch2_entering_overbought = k_entering_overbought || d_entering_overbought;
        
        bool k_leaving_overbought = Stoch2_K_Buffer[prev_bar] >= OverboughtLevel && Stoch2_K_Buffer[curr_bar] < OverboughtLevel;
        bool d_leaving_overbought = Stoch2_D_Buffer[prev_bar] >= OverboughtLevel && Stoch2_D_Buffer[curr_bar] < OverboughtLevel;
        stoch2_leaving_overbought = k_leaving_overbought || d_leaving_overbought;
        
        bool k_entering_oversold = Stoch2_K_Buffer[prev_bar] > OversoldLevel && Stoch2_K_Buffer[curr_bar] <= OversoldLevel;
        bool d_entering_oversold = Stoch2_D_Buffer[prev_bar] > OversoldLevel && Stoch2_D_Buffer[curr_bar] <= OversoldLevel;
        stoch2_entering_oversold = k_entering_oversold || d_entering_oversold;
        
        bool k_leaving_oversold = Stoch2_K_Buffer[prev_bar] <= OversoldLevel && Stoch2_K_Buffer[curr_bar] > OversoldLevel;
        bool d_leaving_oversold = Stoch2_D_Buffer[prev_bar] <= OversoldLevel && Stoch2_D_Buffer[curr_bar] > OversoldLevel;
        stoch2_leaving_oversold = k_leaving_oversold || d_leaving_oversold;
    }
    
    // Check stochastic 3 based on display selection
    if(Stoch3_Display == SHOW_K_ONLY) {
        stoch3_entering_overbought = Stoch3_K_Buffer[prev_bar] < OverboughtLevel && Stoch3_K_Buffer[curr_bar] >= OverboughtLevel;
        stoch3_leaving_overbought = Stoch3_K_Buffer[prev_bar] >= OverboughtLevel && Stoch3_K_Buffer[curr_bar] < OverboughtLevel;
        stoch3_entering_oversold = Stoch3_K_Buffer[prev_bar] > OversoldLevel && Stoch3_K_Buffer[curr_bar] <= OversoldLevel;
        stoch3_leaving_oversold = Stoch3_K_Buffer[prev_bar] <= OversoldLevel && Stoch3_K_Buffer[curr_bar] > OversoldLevel;
    } 
    else if(Stoch3_Display == SHOW_D_ONLY) {
        stoch3_entering_overbought = Stoch3_D_Buffer[prev_bar] < OverboughtLevel && Stoch3_D_Buffer[curr_bar] >= OverboughtLevel;
        stoch3_leaving_overbought = Stoch3_D_Buffer[prev_bar] >= OverboughtLevel && Stoch3_D_Buffer[curr_bar] < OverboughtLevel;
        stoch3_entering_oversold = Stoch3_D_Buffer[prev_bar] > OversoldLevel && Stoch3_D_Buffer[curr_bar] <= OversoldLevel;
        stoch3_leaving_oversold = Stoch3_D_Buffer[prev_bar] <= OversoldLevel && Stoch3_D_Buffer[curr_bar] > OversoldLevel;
    }
    else { // SHOW_BOTH - alert if either K or D crosses
        bool k_entering_overbought = Stoch3_K_Buffer[prev_bar] < OverboughtLevel && Stoch3_K_Buffer[curr_bar] >= OverboughtLevel;
        bool d_entering_overbought = Stoch3_D_Buffer[prev_bar] < OverboughtLevel && Stoch3_D_Buffer[curr_bar] >= OverboughtLevel;
        stoch3_entering_overbought = k_entering_overbought || d_entering_overbought;
        
        bool k_leaving_overbought = Stoch3_K_Buffer[prev_bar] >= OverboughtLevel && Stoch3_K_Buffer[curr_bar] < OverboughtLevel;
        bool d_leaving_overbought = Stoch3_D_Buffer[prev_bar] >= OverboughtLevel && Stoch3_D_Buffer[curr_bar] < OverboughtLevel;
        stoch3_leaving_overbought = k_leaving_overbought || d_leaving_overbought;
        
        bool k_entering_oversold = Stoch3_K_Buffer[prev_bar] > OversoldLevel && Stoch3_K_Buffer[curr_bar] <= OversoldLevel;
        bool d_entering_oversold = Stoch3_D_Buffer[prev_bar] > OversoldLevel && Stoch3_D_Buffer[curr_bar] <= OversoldLevel;
        stoch3_entering_oversold = k_entering_oversold || d_entering_oversold;
        
        bool k_leaving_oversold = Stoch3_K_Buffer[prev_bar] <= OversoldLevel && Stoch3_K_Buffer[curr_bar] > OversoldLevel;
        bool d_leaving_oversold = Stoch3_D_Buffer[prev_bar] <= OversoldLevel && Stoch3_D_Buffer[curr_bar] > OversoldLevel;
        stoch3_leaving_oversold = k_leaving_oversold || d_leaving_oversold;
    }
    
    // Check stochastic 4 based on display selection
    if(Stoch4_Display == SHOW_K_ONLY) {
        stoch4_entering_overbought = Stoch4_K_Buffer[prev_bar] < OverboughtLevel && Stoch4_K_Buffer[curr_bar] >= OverboughtLevel;
        stoch4_leaving_overbought = Stoch4_K_Buffer[prev_bar] >= OverboughtLevel && Stoch4_K_Buffer[curr_bar] < OverboughtLevel;
        stoch4_entering_oversold = Stoch4_K_Buffer[prev_bar] > OversoldLevel && Stoch4_K_Buffer[curr_bar] <= OversoldLevel;
        stoch4_leaving_oversold = Stoch4_K_Buffer[prev_bar] <= OversoldLevel && Stoch4_K_Buffer[curr_bar] > OversoldLevel;
    } 
    else if(Stoch4_Display == SHOW_D_ONLY) {
        stoch4_entering_overbought = Stoch4_D_Buffer[prev_bar] < OverboughtLevel && Stoch4_D_Buffer[curr_bar] >= OverboughtLevel;
        stoch4_leaving_overbought = Stoch4_D_Buffer[prev_bar] >= OverboughtLevel && Stoch4_D_Buffer[curr_bar] < OverboughtLevel;
        stoch4_entering_oversold = Stoch4_D_Buffer[prev_bar] > OversoldLevel && Stoch4_D_Buffer[curr_bar] <= OversoldLevel;
        stoch4_leaving_oversold = Stoch4_D_Buffer[prev_bar] <= OversoldLevel && Stoch4_D_Buffer[curr_bar] > OversoldLevel;
    }
    else { // SHOW_BOTH - alert if either K or D crosses
        bool k_entering_overbought = Stoch4_K_Buffer[prev_bar] < OverboughtLevel && Stoch4_K_Buffer[curr_bar] >= OverboughtLevel;
        bool d_entering_overbought = Stoch4_D_Buffer[prev_bar] < OverboughtLevel && Stoch4_D_Buffer[curr_bar] >= OverboughtLevel;
        stoch4_entering_overbought = k_entering_overbought || d_entering_overbought;
        
        bool k_leaving_overbought = Stoch4_K_Buffer[prev_bar] >= OverboughtLevel && Stoch4_K_Buffer[curr_bar] < OverboughtLevel;
        bool d_leaving_overbought = Stoch4_D_Buffer[prev_bar] >= OverboughtLevel && Stoch4_D_Buffer[curr_bar] < OverboughtLevel;
        stoch4_leaving_overbought = k_leaving_overbought || d_leaving_overbought;
        
        bool k_entering_oversold = Stoch4_K_Buffer[prev_bar] > OversoldLevel && Stoch4_K_Buffer[curr_bar] <= OversoldLevel;
        bool d_entering_oversold = Stoch4_D_Buffer[prev_bar] > OversoldLevel && Stoch4_D_Buffer[curr_bar] <= OversoldLevel;
        stoch4_entering_oversold = k_entering_oversold || d_entering_oversold;
        
        bool k_leaving_oversold = Stoch4_K_Buffer[prev_bar] <= OversoldLevel && Stoch4_K_Buffer[curr_bar] > OversoldLevel;
        bool d_leaving_oversold = Stoch4_D_Buffer[prev_bar] <= OversoldLevel && Stoch4_D_Buffer[curr_bar] > OversoldLevel;
        stoch4_leaving_oversold = k_leaving_oversold || d_leaving_oversold;
    }
    
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
        lastAlertTime = TimeCurrent();
    }
    else if(allLeavingOverbought)
    {
        Alert("All selected stochastic lines leaving overbought zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
        lastAlertTime = TimeCurrent();
    }
    else if(allEnteringOversold)
    {
        Alert("All selected stochastic lines entering oversold zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
        lastAlertTime = TimeCurrent();
    }
    else if(allLeavingOversold)
    {
        Alert("All selected stochastic lines leaving oversold zone - ", Symbol(), " - ", EnumToString((ENUM_TIMEFRAMES)Period()));
        lastAlertTime = TimeCurrent();
    }
}
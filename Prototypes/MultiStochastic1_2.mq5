//+------------------------------------------------------------------+
//| Chart event handler function                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                 const long &lparam,
                 const double &dparam,
                 const string &sparam)
{
   // Process button clicks
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == kButtonName) {
         // Toggle K-Lines
         showKLines = !showKLines;
         Print("K-Lines toggled via chart event: ", showKLines ? "ON" : "OFF");
         
         // Update button text
         string kText = showKLines ? "Toggle K-Lines: ON" : "Toggle K-Lines: OFF";
         ObjectSetString(0, kButtonName, OBJPROP_TEXT, kText);
         
         // Reset button state
         ObjectSetInteger(0, kButtonName, OBJPROP_STATE, false);
         
         // Force recalculation
         ChartRedraw();
      }
      else if(sparam == dButtonName) {
         // Toggle D-Lines
         showDLines = !showDLines;
         Print("D-Lines toggled via chart event: ", showDLines ? "ON" : "OFF");
         
         // Update button text
         string dText = showDLines ? "Toggle D-Lines: ON" : "Toggle D-Lines: OFF";
         ObjectSetString(0, dButtonName, OBJPROP_TEXT, dText);
         
         // Reset button state
         ObjectSetInteger(0, dButtonName, OBJPROP_STATE, false);
         
         // Force recalculation
         ChartRedraw();
      }
   }
}//+------------------------------------------------------------------+
//| Custom event handler function                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Create buttons on timer (allows chart to fully initialize first)
   static bool buttonsCreated = false;
   
   if(!buttonsCreated) {
      if(CreateButtons()) {
         buttonsCreated = true;
         Print("Buttons created successfully via timer");
         EventKillTimer(); // Timer no longer needed
      }
   }
}//+------------------------------------------------------------------+
//| Function prototypes                                              |
//+------------------------------------------------------------------+
bool CreateButtons();
void HandleButtonClicks();
void CalculateVolumeData(const int rates_total);
void CheckAlerts(int prev_bar, int curr_bar);// Include required library for chart operations
//+------------------------------------------------------------------+
//| Create indicator buttons                                         |
//+------------------------------------------------------------------+
bool CreateButtons()
{
   long chartID = 0; // Current chart ID
   int subwin = ChartWindowFind(chartID, "Multi-Stochastic");
   if(subwin < 0) {
      subwin = ChartWindowFind(); // Try without name
      if(subwin < 0) {
         Print("Failed to find indicator window");
         return false;
      }
   }
   
   // Remove existing buttons if they exist
   ObjectDelete(chartID, kButtonName);
   ObjectDelete(chartID, dButtonName);
   
   // Create K-line toggle button
   if(!ObjectCreate(chartID, kButtonName, OBJ_BUTTON, subwin, 0, 0)) {
      Print("Failed to create K-Line button: ", GetLastError());
      return false;
   }
   
   ObjectSetString(chartID, kButtonName, OBJPROP_TEXT, showKLines ? "Toggle K-Lines: ON" : "Toggle K-Lines: OFF");
   ObjectSetInteger(chartID, kButtonName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_YDISTANCE, 5);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_XSIZE, 150);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_YSIZE, 20);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_BGCOLOR, clrDarkGray);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(chartID, kButtonName, OBJPROP_SELECTABLE, false);
   
   // Create D-line toggle button
   if(!ObjectCreate(chartID, dButtonName, OBJ_BUTTON, subwin, 0, 0)) {
      Print("Failed to create D-Line button: ", GetLastError());
      ObjectDelete(chartID, kButtonName); // Clean up first button
      return false;
   }
   
   ObjectSetString(chartID, dButtonName, OBJPROP_TEXT, showDLines ? "Toggle D-Lines: ON" : "Toggle D-Lines: OFF");
   ObjectSetInteger(chartID, dButtonName, OBJPROP_XDISTANCE, 170);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_YDISTANCE, 5);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_XSIZE, 150);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_YSIZE, 20);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_BGCOLOR, clrDarkGray);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(chartID, dButtonName, OBJPROP_SELECTABLE, false);
   
   Print("Toggle buttons created successfully in subwindow ", subwin);
   
   // Force chart redraw
   ChartRedraw(chartID);
   return true;
}

//+------------------------------------------------------------------+
//| Check for button clicks and handle them                          |
//+------------------------------------------------------------------+
void HandleButtonClicks()
{
   // Skip if we're in indicator tester or optimization
   if(MQLInfoInteger(MQL_TESTER)) return;
   
   long chartID = 0; // Current chart ID
   int subwin = ChartWindowFind(chartID, "Multi-Stochastic");
   if(subwin < 0) subwin = ChartWindowFind(); // Try without name
   
   // Recreate buttons if they don't exist or were removed
   if(!ObjectFind(chartID, kButtonName) || !ObjectFind(chartID, dButtonName)) {
      // Attempt to recreate buttons
      Print("Toggle buttons not found - recreating...");
      CreateButtons();
      return;
   }
   
   // Get click state for K-Line button
   if(ObjectGetInteger(chartID, kButtonName, OBJPROP_STATE)) {
      // Button was clicked, toggle K-Lines state
      showKLines = !showKLines;
      Print("K-Lines toggled: ", showKLines ? "ON" : "OFF");
      
      // Update button text
      string kText = showKLines ? "Toggle K-Lines: ON" : "Toggle K-Lines: OFF";
      ObjectSetString(chartID, kButtonName, OBJPROP_TEXT, kText);
      
      // Reset button state
      ObjectSetInteger(chartID, kButtonName, OBJPROP_STATE, false);
      
      // Force recalculation to update display
      ChartRedraw(chartID);
   }
   
   // Get click state for D-Line button
   if(ObjectGetInteger(chartID, dButtonName, OBJPROP_STATE)) {
      // Button was clicked, toggle D-Lines state
      showDLines = !showDLines;
      Print("D-Lines toggled: ", showDLines ? "ON" : "OFF");
      
      // Update button text
      string dText = showDLines ? "Toggle D-Lines: ON" : "Toggle D-Lines: OFF";
      ObjectSetString(chartID, dButtonName, OBJPROP_TEXT, dText);
      
      // Reset button state
      ObjectSetInteger(chartID, dButtonName, OBJPROP_STATE, false);
      
      // Force recalculation to update display
      ChartRedraw(chartID);
   }
}//+------------------------------------------------------------------+
//| Calculate normalized volume data                                 |
//+------------------------------------------------------------------+
void CalculateVolumeData(const int rates_total)
{
    if(!ShowVolume) {
        // Volume display is off, fill with EMPTY_VALUE
        ArrayFill(Volume_Buffer, 0, rates_total, EMPTY_VALUE);
        return;
    }
    
    // Arrays for volume data
    long raw_volume[];
    double volume_data[];
    double ma_volume[];
    
    // Prepare arrays
    ArrayResize(raw_volume, rates_total);
    ArrayResize(volume_data, rates_total);
    ArrayResize(ma_volume, rates_total);
    ArraySetAsSeries(raw_volume, true);
    ArraySetAsSeries(volume_data, true);
    ArraySetAsSeries(ma_volume, true);
    
    // Get volume data based on selected mode
    if(VolumeMode == VOL_TICK) {
        // Use tick volume
        if(CopyTickVolume(Symbol(), Period(), 0, rates_total, raw_volume) <= 0) {
            Print("Failed to copy tick volume data: ", GetLastError());
            ArrayFill(Volume_Buffer, 0, rates_total, EMPTY_VALUE);
            return;
        }
    } else if(VolumeMode == VOL_REAL) {
        // Use real volume if available
        if(CopyRealVolume(Symbol(), Period(), 0, rates_total, raw_volume) <= 0) {
            Print("Failed to copy real volume data: ", GetLastError());
            // Fall back to tick volume
            if(CopyTickVolume(Symbol(), Period(), 0, rates_total, raw_volume) <= 0) {
                Print("Failed to copy tick volume data: ", GetLastError());
                ArrayFill(Volume_Buffer, 0, rates_total, EMPTY_VALUE);
                return;
            }
        }
    } else {
        // Default to tick volume for normalized
        if(CopyTickVolume(Symbol(), Period(), 0, rates_total, raw_volume) <= 0) {
            Print("Failed to copy tick volume data: ", GetLastError());
            ArrayFill(Volume_Buffer, 0, rates_total, EMPTY_VALUE);
            return;
        }
    }
    
    // Convert long volume values to double for calculations
    for(int i = 0; i < rates_total; i++) {
        volume_data[i] = (double)raw_volume[i];
    }
    
    // Calculate moving average of volume
    if(VolumePeriod > 1) {
        for(int i = 0; i < rates_total; i++) {
            if(i < VolumePeriod) {
                // Not enough data for MA calculation
                ma_volume[i] = 0;
                continue;
            }
            
            double sum = 0;
            for(int j = 0; j < VolumePeriod; j++) {
                sum += volume_data[i-j];
            }
            ma_volume[i] = sum / VolumePeriod;
        }
    } else {
        // No smoothing, use raw volume
        ArrayCopy(ma_volume, volume_data);
    }
    
    // Normalize volume to 0-100 scale
    double max_volume = 0;
    double min_volume = DBL_MAX;
    
    // Find min and max in visible range (first 100 bars or all if less)
    int range = MathMin(100, rates_total);
    for(int i = 0; i < range; i++) {
        if(ma_volume[i] > max_volume) max_volume = ma_volume[i];
        if(ma_volume[i] < min_volume && ma_volume[i] > 0) min_volume = ma_volume[i];
    }
    
    // Avoid division by zero
    if(max_volume == min_volume) max_volume = min_volume + 1;
    
    // Normalize and apply to volume buffer
    for(int i = 0; i < rates_total; i++) {
        // Check for valid value
        if(ma_volume[i] == 0 || min_volume == DBL_MAX) {
            Volume_Buffer[i] = EMPTY_VALUE;
            continue;
        }
        
        // Normalize to 0-100 scale and apply shift
        int shifted_index = i + VolumeShift;
        if(shifted_index >= 0 && shifted_index < rates_total) {
            Volume_Buffer[shifted_index] = ((ma_volume[i] - min_volume) / (max_volume - min_volume)) * 100;
        }
    }
}// Alert variables
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
#property indicator_buffers 9
#property indicator_plots   9

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

#property indicator_label9  "Volume/Tick"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrPurple
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

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

// Volume/Tick settings
enum ENUM_VOLUME_TYPE
{
   VOL_TICK,        // Tick Volume
   VOL_REAL,        // Real Volume (if available)
   VOL_NORMALIZED   // Normalized Volume
};

input ENUM_DISPLAY_LINES Stoch1_Display = SHOW_D_ONLY; // Stochastic 1 - Lines to Display
input ENUM_DISPLAY_LINES Stoch2_Display = SHOW_D_ONLY; // Stochastic 2 - Lines to Display
input ENUM_DISPLAY_LINES Stoch3_Display = SHOW_D_ONLY; // Stochastic 3 - Lines to Display
input ENUM_DISPLAY_LINES Stoch4_Display = SHOW_D_ONLY; // Stochastic 4 - Lines to Display

// Volume/Tick overlay settings
input bool   ShowVolume = false;       // Show Volume/Tick Overlay
input ENUM_VOLUME_TYPE VolumeMode = VOL_TICK; // Volume Mode
input int    VolumePeriod = 14;        // Volume Smoothing Period
input int    VolumeShift = 0;          // Volume Shift
input color  VolumeColor = clrPurple;  // Volume Line Color

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
double Volume_Buffer[];  // Buffer for volume data

// Stochastic indicator handles
int Stoch1_Handle;
int Stoch2_Handle;
int Stoch3_Handle;
int Stoch4_Handle;

// Global variables to track timeframe changes
ENUM_TIMEFRAMES currentTimeframe = PERIOD_CURRENT;
datetime lastCalculationTime = 0;

// Button object names
string kButtonName = "KLineToggleButton";
string dButtonName = "DLineToggleButton";

// Button states (global to persist between function calls)
// Initialize based on default being D-line only
bool showKLines = false;  // Start with K-lines off by default
bool showDLines = true;   // Start with D-lines on by default

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
    SetIndexBuffer(8, Volume_Buffer, INDICATOR_DATA);
    
    // Set plotting properties for all buffers
    for (int i = 0; i < 9; i++)
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
    
    // Set volume line properties
    PlotIndexSetInteger(8, PLOT_LINE_COLOR, VolumeColor);
    
    // Control visibility of volume line
    PlotIndexSetInteger(8, PLOT_DRAW_TYPE, ShowVolume ? DRAW_LINE : DRAW_NONE);
    
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
    
    // Let the chart fully initialize before creating buttons
    EventSetTimer(1); // Set 1-second timer for delayed button creation
    
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
      
    // Check for button clicks
    HandleButtonClicks();
    
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
    ArraySetAsSeries(Volume_Buffer, true);
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
    
    // Calculate volume data
    CalculateVolumeData(rates_total);
    
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
    
    // Remove buttons when indicator is removed
    long chartID = 0;
    ObjectDelete(chartID, kButtonName);
    ObjectDelete(chartID, dButtonName);
    
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

//+------------------------------------------------------------------+
//|                                             TierPriceIndicator.mq5 |
//|                                     Copyright 2025, Your Name Here |
//|                                             https://www.domain.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name Here"
#property link      "https://www.domain.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1
//--- plot TierPrice
#property indicator_label1  "TierPrice"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- input parameters
input int      TierRange=25;          // Tier range value
input bool     ShowLabels=true;        // Show price labels
input color    LabelColor=clrBlue;     // Label color
input int      LabelSize=10;           // Label font size

//--- indicator buffers
double         TierPriceBuffer[];
double         PriceBuffer[];

//--- Global variables
int            labelCounter = 0;
string         indicatorName = "TierPrice";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, TierPriceBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, PriceBuffer, INDICATOR_CALCULATIONS);
   
   //--- setting indicator parameters
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   //--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Tier Price (Range: " + IntegerToString(TierRange) + ")");
   
   //--- initialization done
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
   //--- Check for data
   if(rates_total <= 0) return 0;
   
   //--- Calculate initial position for calculations
   int start;
   if(prev_calculated == 0)
   {
      start = 0;
      
      // Delete old labels when indicator is reset
      DeleteAllLabels();
   }
   else
      start = prev_calculated - 1;
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      // Store original price
      PriceBuffer[i] = close[i];
      
      // Calculate tier price (floor function implementation)
      TierPriceBuffer[i] = MathFloor(close[i] / TierRange) * TierRange;
   }
   
   //--- Create labels if enabled
   if(ShowLabels && prev_calculated == 0)
      CreateLabels(rates_total, time, close);
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Create price level labels                                        |
//+------------------------------------------------------------------+
void CreateLabels(const int rates_total, const datetime &time[], const double &close[])
{
   double currentTier = 0;
   double lastTier = -1;
   
   // Find most recent tiers
   for(int i = rates_total - 1; i >= MathMax(0, rates_total - 500); i--)
   {
      currentTier = MathFloor(close[i] / TierRange) * TierRange;
      
      if(currentTier != lastTier && lastTier != -1)
      {
         // Create a label for this tier level
         CreatePriceLabel(time[i], currentTier);
         
         // Also create a label for the previous tier
         if(labelCounter < 10)  // Limit number of labels
            CreatePriceLabel(time[i], lastTier);
      }
      
      lastTier = currentTier;
      
      // Limit the number of labels
      if(labelCounter >= 15)
         break;
   }
}

//+------------------------------------------------------------------+
//| Create an individual price label                                 |
//+------------------------------------------------------------------+
void CreatePriceLabel(datetime time, double price)
{
   labelCounter++;
   string labelName = indicatorName + "_Label_" + IntegerToString(labelCounter);
   
   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT, DoubleToString(price, _Digits));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, LabelColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LabelSize);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   }
}

//+------------------------------------------------------------------+
//| Delete all labels created by this indicator                      |
//+------------------------------------------------------------------+
void DeleteAllLabels()
{
   for(int i = ObjectsTotal(0, 0, OBJ_TEXT) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TEXT);
      if(StringFind(name, indicatorName) == 0)
         ObjectDelete(0, name);
   }
   
   labelCounter = 0;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up by removing all labels
   DeleteAllLabels();
}
//+------------------------------------------------------------------+
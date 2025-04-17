//+------------------------------------------------------------------+
//|                                    AdaptiveTierPriceIndicator.mq5 |
//|                                     Copyright 2025, Your Name Here |
//|                                             https://www.domain.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name Here"
#property link      "https://www.domain.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- plot Bullish Tier (below price)
#property indicator_label1  "BullishTier"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot Bearish Tier (above price)
#property indicator_label2  "BearishTier"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- input parameters
input int      TierRange=25;          // Tier range value
input int      TrendPeriod=14;         // Period for trend determination
input bool     ShowLabels=true;        // Show price labels
input color    BullLabelColor=clrGreen; // Bullish label color
input color    BearLabelColor=clrRed;  // Bearish label color
input int      LabelSize=10;           // Label font size

//--- indicator buffers
double         BullishTierBuffer[];    // Tier price for bullish trend (below candles)
double         BearishTierBuffer[];    // Tier price for bearish trend (above candles)
double         PriceBuffer[];          // Original price
double         TrendBuffer[];          // Trend direction buffer

//--- Global variables
int            labelCounter = 0;
string         indicatorName = "AdaptiveTierPrice";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, BullishTierBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BearishTierBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, PriceBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, TrendBuffer, INDICATOR_CALCULATIONS);
   
   //--- setting indicator parameters
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   
   //--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Adaptive Tier Price (Range: " + IntegerToString(TierRange) + ")");
   
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
      start = TrendPeriod; // Need enough bars for MA calculation
      
      // Clear buffers
      ArrayInitialize(BullishTierBuffer, 0.0);
      ArrayInitialize(BearishTierBuffer, 0.0);
      ArrayInitialize(TrendBuffer, 0.0);
      
      // Delete old labels when indicator is reset
      DeleteAllLabels();
   }
   else
      start = prev_calculated - 1;
      
   //--- Calculate trend direction first
   for(int i = start; i < rates_total; i++)
   {
      // Store original price
      PriceBuffer[i] = close[i];
      
      // Simple trend detection using moving average
      // If close price > MA, bullish trend (1), else bearish trend (-1)
      double ma = CalculateMA(i, TrendPeriod, close);
      TrendBuffer[i] = (close[i] > ma) ? 1 : -1;
   }
      
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      // Calculate tier price (floor function implementation)
      double tierPrice = MathFloor(close[i] / TierRange) * TierRange;
      
      // Determine which buffer to fill based on trend
      if(TrendBuffer[i] > 0) // Bullish trend
      {
         BullishTierBuffer[i] = tierPrice;
         BearishTierBuffer[i] = 0; // Empty value
      }
      else // Bearish trend
      {
         BearishTierBuffer[i] = tierPrice;
         BullishTierBuffer[i] = 0; // Empty value
      }
   }
   
   //--- Create labels if enabled
   if(ShowLabels && prev_calculated == 0)
      CreateLabels(rates_total, time, close);
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Simple Moving Average                                  |
//+------------------------------------------------------------------+
double CalculateMA(int position, int period, const double &price[])
{
   double sum = 0.0;
   int startPos = position - period + 1;
   
   if(startPos < 0)
      startPos = 0;
      
   for(int i = startPos; i <= position; i++)
      sum += price[i];
      
   return sum / (position - startPos + 1);
}

//+------------------------------------------------------------------+
//| Create price level labels                                        |
//+------------------------------------------------------------------+
void CreateLabels(const int rates_total, const datetime &time[], const double &close[])
{
   double currentTier = 0;
   double lastTier = -1;
   
   // Find most recent tiers
   for(int i = rates_total - 1; i >= MathMax(0, rates_total - 300); i--)
   {
      currentTier = MathFloor(close[i] / TierRange) * TierRange;
      
      if(currentTier != lastTier && lastTier != -1)
      {
         // Create a label for this tier level with appropriate color based on trend
         color labelColor = (TrendBuffer[i] > 0) ? BullLabelColor : BearLabelColor;
         CreatePriceLabel(time[i], currentTier, labelColor);
         
         // Also create a label for the previous tier
         if(labelCounter < 10)  // Limit number of labels
         {
            color prevLabelColor = (TrendBuffer[i] > 0) ? BullLabelColor : BearLabelColor;
            CreatePriceLabel(time[i], lastTier, prevLabelColor);
         }
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
void CreatePriceLabel(datetime time, double price, color labelColor)
{
   labelCounter++;
   string labelName = indicatorName + "_Label_" + IntegerToString(labelCounter);
   
   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT, DoubleToString(price, _Digits));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
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
//+------------------------------------------------------------------+
//| Candle Closing Time Remaining-(CCTR).mq5                         |
//| Copyright 2013, Foad Tahmasebi                                   |
//| Version 2.0 (MT5)                                                |
//| http://www.daskhat.ir                                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013, Foad Tahmasebi"
#property link      "http://www.daskhat.ir"
#property version   "2.0"

#property indicator_chart_window
//--- input parameters
input int       location=2;            // Corner location (0-3)
input int       displayServerTime=0;   // Display server time (0-no, 1-yes)
input int       fontSize=16;           // Font size
input color     colour=clrRed;         // Text color
input int       xOffset=10;            // X offset
input int       yOffset=10;            // Y offset

//--- variables
double leftTime;
string sTime;
int days;
string sCurrentTime;
datetime lastBarTime;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(1); // Set the timer to trigger every second
   
   //---- indicators
   if(location != 0){
      if(!ObjectCreate(0, "CandleClosingTimeRemaining-CCTR", OBJ_LABEL, 0, 0, 0))
      {
         Print("Error creating object: ", GetLastError());
         return(INIT_FAILED);
      }
      ObjectSetInteger(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_CORNER, location);
      ObjectSetInteger(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_XDISTANCE, xOffset); 
      ObjectSetInteger(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_YDISTANCE, yOffset); 
      ObjectSetInteger(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_COLOR, colour);
      ObjectSetInteger(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_FONT, "Verdana");
   }
   
   // Get the most recent bar time
   lastBarTime = GetLastBarTime();
   
   //----
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer(); // Kill the timer
   ObjectDelete(0, "CandleClosingTimeRemaining-CCTR");
   Comment("");
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateCandleClosingTime();
}

//+------------------------------------------------------------------+
//| Get the time of the last bar                                     |
//+------------------------------------------------------------------+
datetime GetLastBarTime()
{
   datetime time[];
   
   if(CopyTime(_Symbol, _Period, 0, 1, time) <= 0)
      return 0;
      
   return time[0];
}

//+------------------------------------------------------------------+
//| Update candle closing time function                              |
//+------------------------------------------------------------------+
void UpdateCandleClosingTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   sCurrentTime = TimeToString(TimeCurrent(), TIME_SECONDS);
   
   // In MT5, we need to get the bar time explicitly
   datetime currentBarTime = GetLastBarTime();
   if(currentBarTime == 0)
      return;
      
   // Update the last bar time if a new bar has formed
   if(currentBarTime != lastBarTime)
      lastBarTime = currentBarTime;
   
   leftTime = (PeriodSeconds(_Period)) - (TimeCurrent() - lastBarTime);
   sTime = TimeToString(leftTime, TIME_SECONDS);
   
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
   {
      // Weekend logic - you can uncomment if needed
      //if(location == 0)
      //{
      //   Comment("Candle Closing Time Remaining: " + "Market Is Closed");
      //}
      //else
      //{
      //   ObjectSetString(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_TEXT, "Market Is Closed");
      //}
   }
   else
   {
      if(_Period == PERIOD_MN1 || _Period == PERIOD_W1)
      {
         days = ((leftTime / 60) / 60) / 24;
         if(location == 0)
         {
            if(displayServerTime == 0)
            {
               Comment("Candle Closing Time Remaining: " + IntegerToString(days) + "D - " + sTime);
            }
            else
            {
               Comment("Candle Closing Time Remaining: " + IntegerToString(days) + "D - " + sTime + " [" + sCurrentTime + "]");
            }
         }
         else
         {
            if(displayServerTime == 0)
            {
               ObjectSetString(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_TEXT, IntegerToString(days) + "D - " + sTime);
            }
            else
            {
               ObjectSetString(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_TEXT, IntegerToString(days) + "D - " + sTime + " [" + sCurrentTime + "]");
            }
         }
      }
      else
      {
         if(location == 0)
         {
            if(displayServerTime == 0)
            {
               Comment("Candle Closing Time Remaining: " + sTime);
            }
            else
            {
               Comment("Candle Closing Time Remaining: " + sTime + " [" + sCurrentTime + "]");
            }
         }
         else
         {
            if(displayServerTime == 0)
            {
               ObjectSetString(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_TEXT, sTime);
            }
            else
            {
               ObjectSetString(0, "CandleClosingTimeRemaining-CCTR", OBJPROP_TEXT, sTime + " [" + sCurrentTime + "]");
            }
         }
      }
   }
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
   // The main logic is now handled by the timer, so OnCalculate can remain simple
   // However, we need to update the last bar time if a new bar has formed
   if(rates_total > 0 && time[0] != lastBarTime)
      lastBarTime = time[0];
      
   return(rates_total);
}
//+------------------------------------------------------------------+
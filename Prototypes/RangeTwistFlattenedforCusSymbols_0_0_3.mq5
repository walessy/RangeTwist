//+------------------------------------------------------------------+
//|                         RangeTwistFlattenedforCusSymbols.mq5 |
//+------------------------------------------------------------------+
#property copyright "Custom Symbol Generator"
#property version   "1.00"
#property script_show_inputs

// Input parameters for the symbol creation
input string   SourceSymbol = "EURUSD";          // Source symbol to transform
input string   NewSymbolName = "FLATRANGE";      // Name for the new custom symbol
input int      InitialRangeSize = 25;            // Matching your RangeTwist parameter
input double   FlatteningFactor = 0.5;           // Factor to flatten angles (0.1-1.0)
input int      BarsToProcess = 1000;             // Number of historical bars to process
input bool     AutoUpdate = true;                // Auto-update custom symbol with new ticks

// Global variables
string fullCustomSymbolName;
int indicatorHandle;
double lineBuffer[];
int timer = 0;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Create the full custom symbol name
   fullCustomSymbolName = NewSymbolName;
   
   // Check if custom symbol already exists, otherwise create it
   if(!CustomSymbolExists(fullCustomSymbolName))
   {
      if(!CreateCustomSymbol(fullCustomSymbolName, SourceSymbol))
      {
         Print("Failed to create custom symbol: ", fullCustomSymbolName);
         return;
      }
   }
   
   // Get the RangeTwist indicator handle
   indicatorHandle = iCustom(SourceSymbol, PERIOD_CURRENT, "RangeTwist_1_0_92_Legs", 
                              InitialRangeSize, 5, 1.2, 0.8, 2.0, clrLime, clrRed, clrGray, 
                              false, true, true);
   
   if(indicatorHandle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handle for RangeTwist_1_0_92_Legs");
      return;
   }
   
   // Process historical data
   ProcessHistoricalData();
   
   if(AutoUpdate)
   {
      // Setup the timer for auto-updates
      timer = EventSetTimer(1); // 1 second timer
      Print("Auto-update enabled for ", fullCustomSymbolName);
      
      // Keep script running until user stops it
      while(!IsStopped())
      {
         // Update the custom symbol with the latest data
         UpdateLatestData();
         Sleep(1000);
      }
      
      // Clean up when script stops
      EventKillTimer();
      IndicatorRelease(indicatorHandle);
      Print("Custom symbol updater stopped");
   }
   else
   {
      Print("Custom symbol ", fullCustomSymbolName, " created and populated with flattened RangeTwist data");
   }
}

//+------------------------------------------------------------------+
//| Checks if a custom symbol already exists                         |
//+------------------------------------------------------------------+
bool CustomSymbolExists(string symbolName)
{
   return SymbolSelect(symbolName, true);
}

//+------------------------------------------------------------------+
//| Creates a new custom symbol based on template symbol             |
//+------------------------------------------------------------------+
bool CreateCustomSymbol(string customSymbolName, string templateSymbol)
{
   // Select template symbol
   if(!SymbolSelect(templateSymbol, true))
   {
      Print("Template symbol not found: ", templateSymbol);
      return false;
   }
   
   // Create custom symbol
   if(!CustomSymbolCreate(customSymbolName))
   {
      Print("Failed to create custom symbol: ", customSymbolName);
      return false;
   }
   
   // Copy properties from template symbol
   ENUM_SYMBOL_INFO_DOUBLE doubleProps[] = 
   {
      SYMBOL_VOLUME_MIN, SYMBOL_VOLUME_MAX, SYMBOL_VOLUME_STEP,
      SYMBOL_POINT, SYMBOL_TRADE_TICK_SIZE, SYMBOL_TRADE_TICK_VALUE
   };
   
   ENUM_SYMBOL_INFO_INTEGER intProps[] = 
   {
      SYMBOL_DIGITS, SYMBOL_SPREAD_FLOAT, SYMBOL_TRADE_CALC_MODE,
      SYMBOL_TRADE_MODE, SYMBOL_BACKGROUND_COLOR
   };
   
   // Copy double properties
   for(int i = 0; i < ArraySize(doubleProps); i++)
   {
      double value = SymbolInfoDouble(templateSymbol, doubleProps[i]);
      CustomSymbolSetDouble(customSymbolName, doubleProps[i], value);
   }
   
   // Copy integer properties
   for(int i = 0; i < ArraySize(intProps); i++)
   {
      long value = SymbolInfoInteger(templateSymbol, intProps[i]);
      CustomSymbolSetInteger(customSymbolName, intProps[i], value);
   }
   
   // Set chart mode to line (using the correct constant)
   CustomSymbolSetInteger(customSymbolName, SYMBOL_CHART_MODE, 0); // 0 = line mode
   CustomSymbolSetString(customSymbolName, SYMBOL_DESCRIPTION, "Flattened RangeTwist");
   
   return true;
}

//+------------------------------------------------------------------+
//| Process historical data and populate the custom symbol           |
//+------------------------------------------------------------------+
void ProcessHistoricalData()
{
   // Prepare buffers for indicator values
   ArrayResize(lineBuffer, BarsToProcess);
   
   // Copy indicator values
   int copied = CopyBuffer(indicatorHandle, 0, 0, BarsToProcess, lineBuffer);
   if(copied <= 0)
   {
      Print("Failed to copy indicator values, error code: ", GetLastError());
      return;
   }
   
   // Get historical OHLC data for the source symbol
   MqlRates rates[];
   ArrayResize(rates, BarsToProcess);
   
   if(CopyRates(SourceSymbol, PERIOD_CURRENT, 0, BarsToProcess, rates) <= 0)
   {
      Print("Failed to copy rates data, error code: ", GetLastError());
      return;
   }
   
   // Apply flattening algorithm to RangeTwist line
   double flattenedValues[];
   ArrayResize(flattenedValues, copied);
   
   for(int i = 0; i < copied; i++)
   {
      if(i == 0 || lineBuffer[i] == EMPTY_VALUE)
      {
         flattenedValues[i] = lineBuffer[i];
         continue;
      }
      
      // Find the angle and flatten it - using integer time difference instead of datetime
      // to avoid type conversion issues
      int timeDiff = (int)(rates[i].time - rates[i-1].time);
      if(timeDiff == 0) timeDiff = 1; // Avoid division by zero
      
      double angle = MathArctan((lineBuffer[i] - lineBuffer[i-1]) / timeDiff);
      double newAngle = angle * FlatteningFactor;
      
      // Calculate new value with flattened angle
      flattenedValues[i] = lineBuffer[i-1] + MathTan(newAngle) * timeDiff;
   }
   
   // Delete any existing rates for the custom symbol
   CustomRatesDelete(fullCustomSymbolName, 0, 0);
   
   // Create new MqlRates array for the custom symbol and add rates one by one
   for(int i = 0; i < copied; i++)
   {
      // Skip empty values
      if(flattenedValues[i] == EMPTY_VALUE)
         continue;
         
      // Create a new rate using the flattened value
      MqlRates customRate;
      customRate.time = rates[i].time;
      customRate.open = flattenedValues[i];
      customRate.high = flattenedValues[i];
      customRate.low = flattenedValues[i];
      customRate.close = flattenedValues[i];
      customRate.tick_volume = rates[i].tick_volume;
      customRate.real_volume = rates[i].real_volume;
      customRate.spread = rates[i].spread;
      
      // Add the rate to the custom symbol (with correct reference syntax)
      CustomRatesUpdate(fullCustomSymbolName, customRate, 1);
   }
   
   // Refresh the symbol in the Market Watch
   SymbolSelect(fullCustomSymbolName, true);
}

//+------------------------------------------------------------------+
//| Update custom symbol with the latest data                        |
//+------------------------------------------------------------------+
void UpdateLatestData()
{
   // Get the latest indicator value
   double latestValue[1];
   if(CopyBuffer(indicatorHandle, 0, 0, 1, latestValue) <= 0)
   {
      Print("Failed to copy latest indicator value, error: ", GetLastError());
      return;
   }
   
   // Get the latest OHLC data for the source symbol
   MqlRates latestRates[1];
   if(CopyRates(SourceSymbol, PERIOD_CURRENT, 0, 1, latestRates) <= 0)
   {
      Print("Failed to copy latest rates data, error: ", GetLastError());
      return;
   }
   
   // Get the previous indicator value for angle calculation
   double prevValue[2];
   if(CopyBuffer(indicatorHandle, 0, 0, 2, prevValue) <= 0)
   {
      Print("Failed to copy previous indicator values, error: ", GetLastError());
      return;
   }
   
   // Get previous rates for time difference
   MqlRates prevRates[2];
   if(CopyRates(SourceSymbol, PERIOD_CURRENT, 0, 2, prevRates) <= 0)
   {
      Print("Failed to copy previous rates, error: ", GetLastError());
      return;
   }
   
   double flattenedValue = latestValue[0];
   
   // Apply flattening only if we have previous values
   if(prevValue[1] != EMPTY_VALUE && latestValue[0] != EMPTY_VALUE)
   {
      // Calculate angle and flatten it - using integer time difference to avoid type conversion
      int timeDiff = (int)(latestRates[0].time - prevRates[1].time);
      if(timeDiff == 0) timeDiff = 1; // Avoid division by zero
      
      double angle = MathArctan((latestValue[0] - prevValue[1]) / timeDiff);
      double newAngle = angle * FlatteningFactor;
      
      // Calculate new value with flattened angle
      flattenedValue = prevValue[1] + MathTan(newAngle) * timeDiff;
   }
   
   // Create a new rate using the flattened value
   MqlRates newRate;
   newRate.time = latestRates[0].time;
   newRate.open = flattenedValue;
   newRate.high = flattenedValue;
   newRate.low = flattenedValue;
   newRate.close = flattenedValue;
   newRate.tick_volume = latestRates[0].tick_volume;
   newRate.real_volume = latestRates[0].real_volume;
   newRate.spread = latestRates[0].spread;
   
   // Update the custom symbol with the new rate (with correct function call)
   CustomRatesUpdate(fullCustomSymbolName, newRate, 1);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                       FibStrategyAutomatedTester.mq5             |
//|                                                                   |
//|  Automated test framework for FibDay5Min strategy indicator       |
//|  Tests multiple scenarios and reports results                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.0"
#property script_show_inputs

// Include the shared functions from our common file
#include "FibStrategyFunctions.mqh"

// Mock data structure
struct MockCandle {
   datetime time;
   double open;
   double high;
   double low;
   double close;
};

struct MockDay {
   double open;
   double high;
   double low;
   double close;
   bool isBullish;
};

struct TestScenario {
   string name;
   string description;
   MockDay prevDay;
   MockCandle candles[50];  // Up to 50 candles per scenario
   int candleCount;
   bool expectedCondition1;
   bool expectedCondition2;
   bool expectedCondition3;
   bool expectedCondition4;
   bool expectedEntrySignal;
};

// Input parameters
input bool RunAllTests = true;       // Run all test scenarios
input int  SingleTestNumber = 1;     // Run only specific test if RunAllTests=false
input bool VerboseOutput = false;    // Show detailed output for each candle

// Global variables for test results
int totalTests = 0;
int passedTests = 0;
string testResults = "";

// Buffer to store predefined test scenarios
TestScenario scenarios[];

// Variables for previous day data needed by the strategy functions
double prevDayHigh = 0;
double prevDayLow = 0;
bool prevDayBullish = false;
datetime prevDayTime = 0;
datetime todayStartTime = 0;
datetime nextDayStartTime = 0;

//+------------------------------------------------------------------+
//| Script program start function                                     |
//+------------------------------------------------------------------+
void OnStart()
{
   // Initialize test scenarios
   InitializeTestScenarios();
   
   Print("Starting Automated Fibonacci Strategy Testing...");
   Print("Total scenarios: ", ArraySize(scenarios));
   
   if(RunAllTests) {
      for(int i = 0; i < ArraySize(scenarios); i++) {
         RunTestScenario(i);
      }
   } else {
      if(SingleTestNumber > 0 && SingleTestNumber <= ArraySize(scenarios)) {
         RunTestScenario(SingleTestNumber - 1);
      } else {
         Print("Invalid test number. Please select between 1 and ", ArraySize(scenarios));
      }
   }
   
   // Print summary
   Print("Test Summary: ", passedTests, "/", totalTests, " tests passed");
   if(testResults != "") {
      Print("Detailed Results:");
      Print(testResults);
   }
}

//+------------------------------------------------------------------+
//| Initialize all test scenarios                                     |
//+------------------------------------------------------------------+
void InitializeTestScenarios()
{
   // Calculate how many test scenarios we'll have
   int totalScenarios = 5;  // We're defining 5 main scenarios
   
   // Allocate memory for the array
   ArrayResize(scenarios, totalScenarios);
   
   // Scenario 1: Basic Downtrend - All conditions should be met
   scenarios[0].name = "Basic Downtrend";
   scenarios[0].description = "Previous day bearish. Price below 50%, then above 60%, then below 50%, then return to 50-60% zone of second Fib.";
   
   // Set up previous day (bearish)
   scenarios[0].prevDay.open = 1.2000;
   scenarios[0].prevDay.high = 1.2100;
   scenarios[0].prevDay.low = 1.1800;
   scenarios[0].prevDay.close = 1.1850;
   scenarios[0].prevDay.isBullish = false;
   
   // Set up candle sequence - 15 candles showing the pattern
   scenarios[0].candleCount = 15;
   
   // Phase 1: Price below 50% (first 3 candles)
   for(int i = 0; i < 3; i++) {
      scenarios[0].candles[i].time = D'2025.01.02 00:00' + i*300; // 5 min candles
      scenarios[0].candles[i].open = 1.1900 - i*0.005;
      scenarios[0].candles[i].high = 1.1920 - i*0.005;
      scenarios[0].candles[i].low = 1.1880 - i*0.005;
      scenarios[0].candles[i].close = 1.1890 - i*0.005;
   }
   
   // Phase 2: Price moving back up above 60% (next 4 candles)
   for(int i = 3; i < 7; i++) {
      scenarios[0].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[0].candles[i].open = 1.1885 + (i-3)*0.008;
      scenarios[0].candles[i].high = 1.1905 + (i-3)*0.008;
      scenarios[0].candles[i].low = 1.1865 + (i-3)*0.008;
      scenarios[0].candles[i].close = 1.1895 + (i-3)*0.008;
   }
   
   // Phase 3: Price moving back down below 50% (next 4 candles)
   for(int i = 7; i < 11; i++) {
      scenarios[0].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[0].candles[i].open = 1.1970 - (i-7)*0.010;
      scenarios[0].candles[i].high = 1.1990 - (i-7)*0.010;
      scenarios[0].candles[i].low = 1.1950 - (i-7)*0.010;
      scenarios[0].candles[i].close = 1.1960 - (i-7)*0.010;
   }
   
   // Phase 4: Price returns to 50-60% zone of second Fib (next 4 candles)
   for(int i = 11; i < 15; i++) {
      scenarios[0].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[0].candles[i].open = 1.1930 + (i-11)*0.003;
      scenarios[0].candles[i].high = 1.1950 + (i-11)*0.003;
      scenarios[0].candles[i].low = 1.1910 + (i-11)*0.003;
      scenarios[0].candles[i].close = 1.1940 + (i-11)*0.003;
   }
   
   // Expected results
   scenarios[0].expectedCondition1 = true;
   scenarios[0].expectedCondition2 = true;
   scenarios[0].expectedCondition3 = true;
   scenarios[0].expectedCondition4 = true;
   scenarios[0].expectedEntrySignal = true;
   
   // Scenario 2: Basic Uptrend - All conditions should be met
   scenarios[1].name = "Basic Uptrend";
   scenarios[1].description = "Previous day bullish. Price above 50%, then below 40%, then above 50%, then return to 40-50% zone of second Fib.";
   
   // Set up previous day (bullish)
   scenarios[1].prevDay.open = 1.1800;
   scenarios[1].prevDay.high = 1.2100;
   scenarios[1].prevDay.low = 1.1800;
   scenarios[1].prevDay.close = 1.2050;
   scenarios[1].prevDay.isBullish = true;
   
   // Set up candle sequence - 15 candles showing the pattern
   scenarios[1].candleCount = 15;
   
   // Uptrend pattern with mirror logic to the downtrend
   // Phase 1: Price above 50% (first 3 candles)
   for(int i = 0; i < 3; i++) {
      scenarios[1].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[1].candles[i].open = 1.1980 + i*0.005;
      scenarios[1].candles[i].high = 1.2000 + i*0.005;
      scenarios[1].candles[i].low = 1.1960 + i*0.005;
      scenarios[1].candles[i].close = 1.1990 + i*0.005;
   }
   
   // Phase 2: Price moving down below 40% (next 4 candles)
   for(int i = 3; i < 7; i++) {
      scenarios[1].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[1].candles[i].open = 1.1995 - (i-3)*0.008;
      scenarios[1].candles[i].high = 1.2015 - (i-3)*0.008;
      scenarios[1].candles[i].low = 1.1975 - (i-3)*0.008;
      scenarios[1].candles[i].close = 1.1985 - (i-3)*0.008;
   }
   
   // Phase 3: Price moving back up above 50% (next 4 candles)
   for(int i = 7; i < 11; i++) {
      scenarios[1].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[1].candles[i].open = 1.1930 + (i-7)*0.010;
      scenarios[1].candles[i].high = 1.1950 + (i-7)*0.010;
      scenarios[1].candles[i].low = 1.1910 + (i-7)*0.010;
      scenarios[1].candles[i].close = 1.1940 + (i-7)*0.010;
   }
   
   // Phase 4: Price returns to 40-50% zone of second Fib (next 4 candles)
   for(int i = 11; i < 15; i++) {
      scenarios[1].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[1].candles[i].open = 1.1970 - (i-11)*0.003;
      scenarios[1].candles[i].high = 1.1990 - (i-11)*0.003;
      scenarios[1].candles[i].low = 1.1950 - (i-11)*0.003;
      scenarios[1].candles[i].close = 1.1980 - (i-11)*0.003;
   }
   
   // Expected results
   scenarios[1].expectedCondition1 = true;
   scenarios[1].expectedCondition2 = true;
   scenarios[1].expectedCondition3 = true;
   scenarios[1].expectedCondition4 = true;
   scenarios[1].expectedEntrySignal = true;
   
   // Scenario 3: Incomplete Pattern - Missing last condition
   scenarios[2].name = "Incomplete Pattern";
   scenarios[2].description = "Meets first 3 conditions but price never returns to the second Fib 50-60% zone.";
   
   // Set up previous day (bearish)
   scenarios[2].prevDay.open = 1.2000;
   scenarios[2].prevDay.high = 1.2100;
   scenarios[2].prevDay.low = 1.1800;
   scenarios[2].prevDay.close = 1.1850;
   scenarios[2].prevDay.isBullish = false;
   
   // Set up candle sequence - 15 candles showing the pattern
   scenarios[2].candleCount = 15;
   
   // Copy first 11 candles from scenario 1 (conditions 1-3 met)
   for(int i = 0; i < 11; i++) {
      scenarios[2].candles[i] = scenarios[0].candles[i];
   }
   
   // Phase 4: Price stays below 50% (never returns to 50-60% zone)
   for(int i = 11; i < 15; i++) {
      scenarios[2].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[2].candles[i].open = 1.1900 - (i-11)*0.003;
      scenarios[2].candles[i].high = 1.1920 - (i-11)*0.003;
      scenarios[2].candles[i].low = 1.1880 - (i-11)*0.003;
      scenarios[2].candles[i].close = 1.1890 - (i-11)*0.003;
   }
   
   // Expected results
   scenarios[2].expectedCondition1 = true;
   scenarios[2].expectedCondition2 = true;
   scenarios[2].expectedCondition3 = true;
   scenarios[2].expectedCondition4 = false;
   scenarios[2].expectedEntrySignal = false;
   
   // Scenario 4: No Pattern - Price stays in a small range
   scenarios[3].name = "No Pattern - Range Bound";
   scenarios[3].description = "Price stays in a small range around the 50% level, never making required transitions.";
   
   // Set up previous day (bearish)
   scenarios[3].prevDay.open = 1.2000;
   scenarios[3].prevDay.high = 1.2100;
   scenarios[3].prevDay.low = 1.1800;
   scenarios[3].prevDay.close = 1.1850;
   scenarios[3].prevDay.isBullish = false;
   
   // Set up candle sequence - 15 candles in a tight range
   scenarios[3].candleCount = 15;
   
   for(int i = 0; i < 15; i++) {
      scenarios[3].candles[i].time = D'2025.01.02 00:00' + i*300;
      
      // Fluctuate slightly around the 50% level
      double offset = 0.002 * sin(i * 0.5);
      scenarios[3].candles[i].open = 1.1950 + offset;
      scenarios[3].candles[i].high = 1.1970 + offset;
      scenarios[3].candles[i].low = 1.1930 + offset;
      scenarios[3].candles[i].close = 1.1960 + offset;
   }
   
   // Expected results - no conditions met except possibly condition 1
   scenarios[3].expectedCondition1 = true;  // Might be true if price enters 50-60% zone
   scenarios[3].expectedCondition2 = false;
   scenarios[3].expectedCondition3 = false;
   scenarios[3].expectedCondition4 = false;
   scenarios[3].expectedEntrySignal = false;
   
   // Scenario 5: Edge Case - Transitions happen but at extremes
   scenarios[4].name = "Edge Case - Extreme Transitions";
   scenarios[4].description = "Pattern transitions happen at extreme values, testing calculation boundaries.";
   
   // Set up previous day (bearish)
   scenarios[4].prevDay.open = 1.2000;
   scenarios[4].prevDay.high = 1.2100;
   scenarios[4].prevDay.low = 1.1800;
   scenarios[4].prevDay.close = 1.1850;
   scenarios[4].prevDay.isBullish = false;
   
   // Set up candle sequence with extreme transitions
   scenarios[4].candleCount = 15;
   
   // Phase 1: Price just below 50% (first 3 candles)
   for(int i = 0; i < 3; i++) {
      scenarios[4].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[4].candles[i].open = 1.1952 - i*0.0001;
      scenarios[4].candles[i].high = 1.1955 - i*0.0001;
      scenarios[4].candles[i].low = 1.1948 - i*0.0001;
      scenarios[4].candles[i].close = 1.1951 - i*0.0001;
   }
   
   // Phase 2: Price barely above 60% (next 4 candles)
   for(int i = 3; i < 7; i++) {
      scenarios[4].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[4].candles[i].open = 1.1920 - (i-3)*0.0001;
      scenarios[4].candles[i].high = 1.1923 - (i-3)*0.0001;
      scenarios[4].candles[i].low = 1.1917 - (i-3)*0.0001;
      scenarios[4].candles[i].close = 1.1919 - (i-3)*0.0001;
   }
   
   // Phase 3: Price just below 50% again (next 4 candles)
   for(int i = 7; i < 11; i++) {
      scenarios[4].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[4].candles[i].open = 1.1951 - (i-7)*0.0001;
      scenarios[4].candles[i].high = 1.1954 - (i-7)*0.0001;
      scenarios[4].candles[i].low = 1.1947 - (i-7)*0.0001;
      scenarios[4].candles[i].close = 1.1950 - (i-7)*0.0001;
   }
   
   // Phase 4: Price barely in the 50-60% zone (next 4 candles)
   for(int i = 11; i < 15; i++) {
      scenarios[4].candles[i].time = D'2025.01.02 00:00' + i*300;
      scenarios[4].candles[i].open = 1.1935 - (i-11)*0.0001;
      scenarios[4].candles[i].high = 1.1938 - (i-11)*0.0001;
      scenarios[4].candles[i].low = 1.1932 - (i-11)*0.0001;
      scenarios[4].candles[i].close = 1.1936 - (i-11)*0.0001;
   }
   
   // Expected results - conditions should be met but it's an edge case
   scenarios[4].expectedCondition1 = true;
   scenarios[4].expectedCondition2 = true;
   scenarios[4].expectedCondition3 = true;
   scenarios[4].expectedCondition4 = true;
   scenarios[4].expectedEntrySignal = true;
}

//+------------------------------------------------------------------+
//| Run an individual test scenario                                   |
//+------------------------------------------------------------------+
void RunTestScenario(int scenarioIndex)
{
   // Get the scenario
   TestScenario scenario = scenarios[scenarioIndex];
   
   // Display test info
   Print("Running Test #", scenarioIndex + 1, ": ", scenario.name);
   if(VerboseOutput) Print("Description: ", scenario.description);
   
   // Reset state
   ResetStrategyState();
   
   // Set up previous day data
   prevDayHigh = scenario.prevDay.high;
   prevDayLow = scenario.prevDay.low;
   prevDayBullish = scenario.prevDay.isBullish;
   prevDayTime = D'2025.01.01 00:00';
   todayStartTime = D'2025.01.02 00:00';
   nextDayStartTime = D'2025.01.03 00:00';
   
   // Create arrays to pass to the strategy function
   datetime time[];
   double open[];
   double high[];
   double low[];
   double close[];
   
   ArrayResize(time, scenario.candleCount);
   ArrayResize(open, scenario.candleCount);
   ArrayResize(high, scenario.candleCount);
   ArrayResize(low, scenario.candleCount);
   ArrayResize(close, scenario.candleCount);
   
   // Fill arrays with mock data
   for(int i = 0; i < scenario.candleCount; i++) {
      time[i] = scenario.candles[i].time;
      open[i] = scenario.candles[i].open;
      high[i] = scenario.candles[i].high;
      low[i] = scenario.candles[i].low;
      close[i] = scenario.candles[i].close;
   }
   
   // Print candle data if verbose mode is enabled
   if(VerboseOutput) {
      Print("Previous Day - Open: ", scenario.prevDay.open, ", High: ", scenario.prevDay.high, 
            ", Low: ", scenario.prevDay.low, ", Close: ", scenario.prevDay.close, 
            ", isBullish: ", scenario.prevDay.isBullish);
      
      Print("Candle data:");
      for(int i = 0; i < scenario.candleCount; i++) {
         Print("Candle[", i, "] - Time: ", time[i], ", Open: ", open[i], 
               ", High: ", high[i], ", Low: ", low[i], ", Close: ", close[i]);
         
         // Calculate and print midpoint
         double midpoint = (open[i] + close[i]) / 2.0;
         Print("  Midpoint: ", midpoint);
         
         // Calculate Fibonacci levels for reference
         double lowerZone = CalculateFibLevel(LowerZoneLimit, prevDayHigh, prevDayLow, prevDayBullish);
         double upperZone = CalculateFibLevel(UpperZoneLimit, prevDayHigh, prevDayLow, prevDayBullish);
         
         // Check if midpoint is in the target zone
         string zoneStatus = "outside zone";
         if(midpoint >= lowerZone && midpoint <= upperZone) zoneStatus = "IN ZONE";
         else if(midpoint < lowerZone) zoneStatus = "below zone";
         else if(midpoint > upperZone) zoneStatus = "above zone";
         
         Print("  Zone status: ", zoneStatus, " (Zone: ", lowerZone, " - ", upperZone, ")");
      }
   }
   
   // Run the strategy detection logic
   CheckStrategyCriteria(time, open, high, low, close, scenario.candleCount, 
                        prevDayHigh, prevDayLow, prevDayBullish, VerboseOutput);
   
   // Check results
   bool allMatch = true;
   string resultDetails = "";
   
   // Condition 1
   if(condition1Met != scenario.expectedCondition1) {
      allMatch = false;
      resultDetails += "Condition 1: Expected " + (scenario.expectedCondition1 ? "true" : "false") + 
                       ", got " + (condition1Met ? "true" : "false") + "\n";
   }
   
   // Condition 2
   if(condition2Met != scenario.expectedCondition2) {
      allMatch = false;
      resultDetails += "Condition 2: Expected " + (scenario.expectedCondition2 ? "true" : "false") + 
                       ", got " + (condition2Met ? "true" : "false") + "\n";
   }
   
   // Condition 3
   if(condition3Met != scenario.expectedCondition3) {
      allMatch = false;
      resultDetails += "Condition 3: Expected " + (scenario.expectedCondition3 ? "true" : "false") + 
                       ", got " + (condition3Met ? "true" : "false") + "\n";
   }
   
   // Condition 4
   if(condition4Met != scenario.expectedCondition4) {
      allMatch = false;
      resultDetails += "Condition 4: Expected " + (scenario.expectedCondition4 ? "true" : "false") + 
                       ", got " + (condition4Met ? "true" : "false") + "\n";
   }
   
   // Entry Signal
   if(entrySignal != scenario.expectedEntrySignal) {
      allMatch = false;
      resultDetails += "Entry Signal: Expected " + (scenario.expectedEntrySignal ? "true" : "false") + 
                       ", got " + (entrySignal ? "true" : "false") + "\n";
   }
   
   // Increment test count
   totalTests++;
   
   // Print result
   if(allMatch) {
      Print("  Test PASSED");
      passedTests++;
   } else {
      Print("  Test FAILED");
      if(resultDetails != "") {
         Print("  Details:");
         Print(resultDetails);
      }
   }
   
   // Add to results log
   testResults += "Test #" + IntegerToString(scenarioIndex + 1) + " (" + scenario.name + "): " + 
                  (allMatch ? "PASSED" : "FAILED") + "\n";
   if(!allMatch) {
      testResults += resultDetails + "\n";
   }
}
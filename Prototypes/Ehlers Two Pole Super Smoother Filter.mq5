//+------------------------------------------------------------------+
//|                                   TwoPoleSuperSmootherFilter.mq5 |
//|                                                                  |
//| Two-Pole Super Smoother Filter                                   |
//|                                                                  |
//| Algorithm taken from book                                        |
//|     "Cybernetics Analysis for Stock and Futures"                 |
//| by John F. Ehlers                                                |
//|                                                                  |
//|                                              contact@mqlsoft.com |
//|                                          http://www.mqlsoft.com/ |
//+------------------------------------------------------------------+
#property copyright "Coded by Witold Wozniak"
#property link      "www.mqlsoft.com"

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_color1 clrRed
#property indicator_type1 DRAW_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1
#property indicator_label1 "Two-Pole Super Smoother Filter"

input int CutoffPeriod = 15; // Cutoff Period

double Filter[];

int drawBegin = 0;

double tempReal, rad2Deg, deg2Rad;
double coef1, coef2, coef3;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    drawBegin = 4;
    
    // Indicator buffers mapping
    SetIndexBuffer(0, Filter, INDICATOR_DATA);
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, drawBegin);
    PlotIndexSetInteger(0, PLOT_SHIFT, 0);
    
    // Set indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "Two-Pole Super Smoother Filter [" + string(CutoffPeriod) + "]");
    
    // Calculate constants
    tempReal = MathArctan(1.0);
    rad2Deg = 45.0 / tempReal;
    deg2Rad = 1.0 / rad2Deg;
    double a1 = MathExp(-1.414 * M_PI / CutoffPeriod);
    double b1 = 2 * a1 * MathCos(deg2Rad * 1.414 * 180 / CutoffPeriod);
    coef2 = b1;
    coef3 = -a1 * a1;
    coef1 = 1.0 - coef2 - coef3;
    
    return (INIT_SUCCEEDED);
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
                const int &spread[]) {
    
    if (rates_total <= drawBegin) return (0);
    
    int limit;
    if (prev_calculated == 0) {
        limit = rates_total - drawBegin - 1;
    } else {
        limit = rates_total - prev_calculated;
    }
    
    for (int i = limit; i >= 0; i--) {
        Filter[i] = coef1 * P(open, i) +
                    coef2 * Filter[i + 1] +
                    coef3 * Filter[i + 2];
        if (i > rates_total - 4) {
            Filter[i] = P(open, i);
        }
    }
    
    return (rates_total);
}

//+------------------------------------------------------------------+
//| Calculate the price value                                        |
//+------------------------------------------------------------------+
double P(const double &price[], int index) {
    return (price[index]);
    //return ((high[index] + low[index]) / 2.0);
}
//+------------------------------------------------------------------+
//|                                    Laguerre_PPO_Tops_Bottoms.mq5 |
//|                                                                  |
//|                                         Hamoon Soleimani         |
//+------------------------------------------------------------------+
#property copyright "Hamoon Soleimani Copyright 2024"
#property link      "Hamoon.net"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 9
#property indicator_plots   9

//--- plot buffers
double PctRankTBuffer[];
double PctRankBBuffer[];
double ExtremeMoveTopBuffer[];
double ExtremeMoveBottomBuffer[];
double WarningTopBuffer[];
double WarningBottomBuffer[];
double ZeroLineCircleBuffer[];
double ZeroLineBuffer[];
double TempBuffer[];

//--- plot parameters
input double   PctileThreshold = 90;      // Percentile Threshold Extreme Value
input double   WrnPctile = 70;            // Warning Percentile Threshold
input double   ShortSetting = 0.4;        // PPO Short Setting
input double   LongSetting = 0.8;         // PPO Long Setting
input int      LookBackTop = 200;         // Look Back Period For Tops
input int      LookBackBottom = 200;      // Look Back Period For Bottoms
input bool     ShowThresholdLine = true;   // Show Threshold Line
input bool     ShowWarningLine = true;     // Show Warning Line

//--- Laguerre variables
double L0_Short[], L1_Short[], L2_Short[], L3_Short[];
double L0_Long[], L1_Long[], L2_Long[], L3_Long[];
double PPO_Top[], PPO_Bottom[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get the number of bars in the current chart
   int rates_total = Bars(_Symbol, PERIOD_CURRENT);
   
   SetIndexBuffer(0, PctRankTBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, PctRankBBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ExtremeMoveTopBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ExtremeMoveBottomBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, WarningTopBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, WarningBottomBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, ZeroLineCircleBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, ZeroLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(8, TempBuffer, INDICATOR_CALCULATIONS);
   
   // Initialize Laguerre arrays
   ArrayResize(L0_Short, rates_total);
   ArrayResize(L1_Short, rates_total);
   ArrayResize(L2_Short, rates_total);
   ArrayResize(L3_Short, rates_total);
   ArrayResize(L0_Long, rates_total);
   ArrayResize(L1_Long, rates_total);
   ArrayResize(L2_Long, rates_total);
   ArrayResize(L3_Long, rates_total);
   ArrayResize(PPO_Top, rates_total);
   ArrayResize(PPO_Bottom, rates_total);
   
   // Set indicator properties
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_LINE);
   
   // Set indicator labels
   PlotIndexSetString(0, PLOT_LABEL, "Top Percentile Rank");
   PlotIndexSetString(1, PLOT_LABEL, "Bottom Percentile Rank");
   PlotIndexSetString(2, PLOT_LABEL, "Extreme Move Top");
   PlotIndexSetString(3, PLOT_LABEL, "Extreme Move Bottom");
   PlotIndexSetString(4, PLOT_LABEL, "Warning Top");
   PlotIndexSetString(5, PLOT_LABEL, "Warning Bottom");
   PlotIndexSetString(6, PLOT_LABEL, "Zero Line Circle");
   PlotIndexSetString(7, PLOT_LABEL, "Zero Line");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Laguerre calculation function                                      |
//+------------------------------------------------------------------+
double LaguerreFilter(double g, double price, int i, double &L0[], double &L1[], double &L2[], double &L3[])
{
   L0[i] = (1 - g) * price + g * (i > 0 ? L0[i-1] : price);
   L1[i] = -g * L0[i] + (i > 0 ? L0[i-1] : L0[i]) + g * (i > 0 ? L1[i-1] : 0);
   L2[i] = -g * L1[i] + (i > 0 ? L1[i-1] : L1[i]) + g * (i > 0 ? L2[i-1] : 0);
   L3[i] = -g * L2[i] + (i > 0 ? L2[i-1] : L2[i]) + g * (i > 0 ? L3[i-1] : 0);
   
   return (L0[i] + 2*L1[i] + 2*L2[i] + L3[i])/6;
}

//+------------------------------------------------------------------+
//| Calculate percentile rank                                          |
//+------------------------------------------------------------------+
double PercentileRank(double value, double& array[], int length, int current)
{
   int count = 0;
   for(int i = 0; i < length && (current - i) >= 0; i++)
   {
      if(array[current - i] <= value) count++;
   }
   return (double)count/length * 100;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
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
   int limit = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   
   // Set colors for the plots
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrRed);     // Top histogram
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrLime);    // Bottom histogram
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrRed);     // Extreme top line
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrLime);    // Extreme bottom line
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, clrOrange);  // Warning top line
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, clrGreen);   // Warning bottom line
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, clrSilver);  // Zero line circle
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, clrGray);    // Zero line
   
   for(int i = limit; i < rates_total; i++)
   {
      double price = (high[i] + low[i])/2;
      
      // Calculate Laguerre values
      double lmas = LaguerreFilter(ShortSetting, price, i, L0_Short, L1_Short, L2_Short, L3_Short);
      double lmal = LaguerreFilter(LongSetting, price, i, L0_Long, L1_Long, L2_Long, L3_Long);
      
      // Calculate PPO
      PPO_Top[i] = (lmas - lmal)/lmal * 100;
      PPO_Bottom[i] = (lmal - lmas)/lmal * 100;
      
      // Calculate percentile ranks
      double pctRankT = PercentileRank(PPO_Top[i], PPO_Top, LookBackTop, i);
      double pctRankB = -PercentileRank(PPO_Bottom[i], PPO_Bottom, LookBackBottom, i);
      
      // Set buffer values
      PctRankTBuffer[i] = pctRankT;
      PctRankBBuffer[i] = pctRankB;
      
      // Set threshold lines
      if(ShowThresholdLine)
      {
         ExtremeMoveTopBuffer[i] = PctileThreshold;
         ExtremeMoveBottomBuffer[i] = -PctileThreshold;
      }
      else
      {
         ExtremeMoveTopBuffer[i] = EMPTY_VALUE;
         ExtremeMoveBottomBuffer[i] = EMPTY_VALUE;
      }
      
      // Set warning lines
      if(ShowWarningLine)
      {
         WarningTopBuffer[i] = WrnPctile;
         WarningBottomBuffer[i] = -WrnPctile;
      }
      else
      {
         WarningTopBuffer[i] = EMPTY_VALUE;
         WarningBottomBuffer[i] = EMPTY_VALUE;
      }
      
      // Set zero lines
      ZeroLineCircleBuffer[i] = 0;
      ZeroLineBuffer[i] = 0;
   }
   
   return(rates_total);
}
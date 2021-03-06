//+------------------------------------------------------------------+
//|                                                          CSI.mq5 |
//|                                                              Lex |
//|                                                                  |
//+------------------------------------------------------------------+
#include <Trade\AccountInfo.mqh>
#include <Indicators\Indicators.mqh>
#include "CiADXR.mqh"
#include "SymbolInfo.mqh"

input ENUM_TIMEFRAMES   CSI_TF = PERIOD_H4;     // Time Frame for calculating CSI.
input ENUM_TIMEFRAMES   TREND_TF = PERIOD_M15;  // Time Frame for Directional Movement Index.
input ENUM_TIMEFRAMES   TRADE_TF = PERIOD_M5;   // Time Frame for Trading Direction.

input int               ADX_Period = 12;        // Period of ADX & ATR.
input double            MARGIN = 1000;
input double            MARGIN_PERCENT = 0.5;   // Percent of Margin could used in trade.

string symbolNames[] =
  {
   "XAUUSD",
   "XAGUSD",
   "COPPER",
   "WHEAT",
   "SUGAR",
   "CORN",
   "SOYBEANS",
   "AUDUSD",
   "EURUSD",
   "GBPUSD",
   "NZDUSD",
  };

CSymbolInfo *symbols[];
CiADXR      *CSI_ADXs[];
CiADXR      *TrendADXs[];
CiADXR      *TradeADXs[];

CIndicators indicators;

CAccountInfo *account;

double MarginCanUsed = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   int count = ArraySize(symbolNames);
   ArrayResize(symbols, count);
   ArrayResize(CSI_ADXs, count);
   ArrayResize(TrendADXs, count);
   ArrayResize(TradeADXs, count);

//--- Create all indicators.
   for(int i = 0; i < count; i ++)
     {
      string name = symbolNames[i];
      symbols[i] = new CSymbolInfo();
      symbols[i].Name(name);
      symbols[i].RefreshRates();

      CSI_ADXs[i] = new CiADXR();
      CSI_ADXs[i].Create(name, CSI_TF, ADX_Period);
      //PrintSymbolProperties(symbols[i]);
      indicators.Add(CSI_ADXs[i]);
      
      TrendADXs[i] = new CiADXR();
      TrendADXs[i].Create(name, TREND_TF, ADX_Period);
      indicators.Add(TrendADXs[i]);
      
      TradeADXs[i] = new CiADXR();
      TradeADXs[i].Create(name, TRADE_TF, ADX_Period);
      indicators.Add(TradeADXs[i]);
     }

   indicators.Refresh();

//--- Calculate Margin management variables.
   account = new CAccountInfo();

   if(MARGIN > 0)
      MarginCanUsed = MARGIN * MARGIN_PERCENT;
   else
      MarginCanUsed = account.FreeMargin() * MARGIN_PERCENT;

//--- create timer
   EventSetTimer(60);

//---
   PrintAllCSI();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

//--- release objects.
   int count = ArraySize(symbolNames);
   for(int i = 0; i < count; i ++)
     {
      delete symbols[i];
      delete CSI_ADXs[i];
      delete TrendADXs[i];
      delete TradeADXs[i];
     }

   delete account;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
// Nothing to Do !!!
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
int   timerTick = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   timerTick ++;
   if(timerTick % CSI_TF == 0)
     {
      indicators.Refresh();
      PrintAllCSI();
     }
  }
//+------------------------------------------------------------------+
void PrintSymbolProperties(CSymbolInfo* symbol)
  {
   Print("\n===== " + symbol.Name() + " =====");
   Print("Trade contract size: " + symbol.ContractSize());
   Print("Spread value in points: " + symbol.Spread());
   Print("Is Spread floating: " + symbol.SpreadFloat());
   Print("Maximum permitted amount of a lot: " + symbol.LotsMax());
   Print("Minimum permitted amount of a lot: " + symbol.LotsMin());
   Print("Step for changing lots: " + symbol.LotsStep());
   Print("Initial margin requirements for 1 lot: " + symbol.MarginInitial());
  }
//+------------------------------------------------------------------+
double CalculateCSI(CSymbolInfo *symbol, CiADXR*adx)
  {
   double adxr = adx.ADXR(1);
   double atr = adx.ATR(1);
   double commission_rate = 1 / (150 + symbol.Spread() * symbol.Point());

   double marginRate, maintenanceMarginRate;
   string name = symbol.Name();
   SymbolInfoMarginRate(name, ORDER_TYPE_BUY, marginRate, maintenanceMarginRate);
//--- Calculate how many lot can trade with free margin.
   double V = symbol.ContractSize() * symbol.LotsMin();
   double askPrice = symbol.Ask();
   double marginMin = askPrice * V * marginRate / 100;
   double miniLots = MathRound(MarginCanUsed / marginMin);

   double M = 1 / MathSqrt(marginMin * miniLots);

   double csi = adxr * atr * commission_rate * V * M * 100;
   return csi;
  }
//+------------------------------------------------------------------+
void PrintAllCSI()
  {
   int count = ArraySize(symbolNames);

   Print("----------");
   for(int i = 0; i < count; i ++)
     {
      Print(symbolNames[i] + ": " + CalculateCSI(symbols[i], CSI_ADXs[i]));
     }
  }
//+------------------------------------------------------------------+

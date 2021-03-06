//+------------------------------------------------------------------+
//|                                               JinmonWilder03.mq5 |
//|                                                              Lex |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "..\CSI\CiADXR.mqh"
#include <Indicators\Indicators.mqh>

#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>

#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

#include <ChartObjects\ChartObjectsTxtControls.mqh>

CSymbolInfo *symbol;
CChartObjectHLine SellLine;
CChartObjectHLine BuyLine;
CChartObjectHLine HBOPLine;
CChartObjectHLine LBOPLine;
CChartObjectLabel CurrentTradeDay;

CPositionInfo  position;
CTrade         trade;

CiADXR         *adxr;
CIndicators    *indicators;

CChartObjectLabel signalLabel;
CChartObjectLabel dmpLabel;
CChartObjectLabel dmnLabel;

//--- Input variables
input ENUM_TIMEFRAMES   ADX_TF = PERIOD_M15;
input int               ADX_Period = 12;        // Period of ADX & ATR.

input    ENUM_TIMEFRAMES   ReactTimeFrame = PERIOD_M5;
input    int               SpreadMultiplier = 4;

int      timerInterval = 0;
double   spreadMargin = 0;
string   TradeDays[] = {"B", "O", "S"};
int      tradeDay = -1;

enum ENUM_TRADE_DAY
  {
   BUY_DAY = 0,
   OPEN_DAY = 1,
   SELL_DAY = 2,
  };

enum ENUM_TRADE_MODE
  {
   NONE_MODE = 0,
   REACTION_MODE = 1,
   TREND_MODE = 2,
  };

ENUM_TRADE_MODE   tradeMode = NONE_MODE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   switch(ReactTimeFrame)
     {
      case PERIOD_M1:
         timerInterval = 60;
         break;
      case PERIOD_M5:
         timerInterval = 300;
         break;
      case PERIOD_M15:
         timerInterval = 900;
         break;
     }

//---
   symbol = new CSymbolInfo();
   symbol.Name(_Symbol);

   adxr = new CiADXR();
   adxr.Create(_Symbol, ADX_TF, ADX_Period);

   indicators = new CIndicators();
   indicators.Add(adxr);

   indicators.Refresh();

//--- Calibrate Trade Day.
   int bDay = iLowest(_Symbol, ReactTimeFrame, MODE_LOW, 12);
   int sDay = iHighest(_Symbol, ReactTimeFrame, MODE_HIGH, 12);
   int hbopDay = 0;
   int lbopDay = 0;

   double hbop, lbop, b, s;
   double h0, l0, h, l;
   h0 = iHigh(_Symbol, ReactTimeFrame, 0);
   l0 = iLow(_Symbol, ReactTimeFrame, 0);


   for(int i = 0; i < 12; i ++)
     {
      h = iHigh(_Symbol, ReactTimeFrame, i);
      l = iLow(_Symbol, ReactTimeFrame, i);
      CalculateReactionPrices(b, s, hbop, lbop, i + 1);

      if(h > h0 && h >= hbop)
        {
         Print("Cross HBOP at " + i);
         hbopDay = i;
         break;
        }
      if(l < l0 && l <= lbop)
        {
         Print("Cross LBOP at " + i);
         lbopDay = i;
         break;
        }
     }

   Print("Lowest Bar is " + bDay);
   Print("Highest Bar is " + sDay);

   if(hbopDay > 0)
     {
      tradeDay = (hbopDay - 1) % 3;
      Print("Use HBOP day as First day: " + hbopDay);
     }
   else
      if(lbopDay > 0)
        {
         tradeDay = lbopDay % 3;
         Print("Use LBOP day as First day: " + lbopDay);
        }
      else
         if(bDay > sDay)
           {
            tradeDay = (sDay + 2) % 3;
            Print("Use Highest S day as First day: " + sDay);
           }
         else
            if(sDay > bDay)
              {
               tradeDay = bDay % 3;
               Print("Use Lowest B day as First day: " + bDay);
              }

   tradeMode = REACTION_MODE;

   InitReactionLines();
   UpdateReactionLines();
   
   //--- Label for Trade Information.
   signalLabel.Create(0, "Trade Signal", 0, 260, 3);
   dmpLabel.Create(0, "DM +", 0, 320, 3);
   dmnLabel.Create(0, "DM -", 0, 400, 3);
   UpdateSignalLabel();

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   delete symbol;
   delete adxr;
   delete indicators;
   
   DeleteReactionLines();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
bool tradeDayChanged = false;
bool tradeDayRecalibrated = false;
bool MinuteFlag = false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   ulong seconds = TimeCurrent();

   symbol.RefreshRates();

   if(!tradeDayRecalibrated)
      tradeDayRecalibrated = RecalibrateTradeDayWithBOP();

   if(!MinuteFlag && seconds % 60 == 0)
     {
      indicators.Refresh();
      MinuteFlag = true;
     }
   else
      MinuteFlag = false;

//---
//if(Positions)
//--- Update Reaction Lines.
   if(seconds % timerInterval == 0)
     {
      if(!tradeDayChanged)
        {
         if(!tradeDayRecalibrated)
            RecalibrateTradeDayWithSIP();

         tradeDayRecalibrated = false;
         tradeDayChanged = true;

         tradeDay = (tradeDay + 1) % 3;
         Print("Current Trade Day is " + TradeDays[tradeDay]);
         UpdateReactionLines();
         
         //--- Update Signal Label.
         UpdateSignalLabel();
        }
     }
   else
     {
      tradeDayChanged = false;
     }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---

  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double HBOP = 0;
double LBOP = 0;
double PriceB = 0;
double PriceS = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitReactionLines()
  {
   spreadMargin = symbol.Spread() * symbol.Point() * SpreadMultiplier;

   SellLine.Create(0, "Reaction Sell Line", 0, 0);
   SellLine.Color(clrWhiteSmoke);
   SellLine.Style(STYLE_DOT);

   BuyLine.Create(0, "Reaction Buy Line", 0, 0);
   BuyLine.Color(clrWhiteSmoke);
   BuyLine.Style(STYLE_DOT);

   HBOPLine.Create(0, "Reaction HBOP Line", 0, 0);
   HBOPLine.Color(clrYellowGreen);
   HBOPLine.Style(STYLE_DASH);

   LBOPLine.Create(0, "Reaction LBOP Line", 0, 0);
   LBOPLine.Color(clrYellowGreen);
   LBOPLine.Style(STYLE_DASH);

   CurrentTradeDay.Create(0, "Current Trade Day", 0, 200, 3);
   CurrentTradeDay.Color(clrGold);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateReactionPrices(double& B, double& S, double& HBOP, double& LBOP, int index)
  {
   double H = iHigh(_Symbol, ReactTimeFrame, index);
   double L = iLow(_Symbol, ReactTimeFrame, index);
   double C = iClose(_Symbol, ReactTimeFrame, index);

   double X = (H + L + C) / 3;

   B = 2 * X - H;
   S = 2 * X - L;
   HBOP = 2 * (X - L) + H;
   LBOP = 2 * (X - H) + L;
  }
//+------------------------------------------------------------------+
bool RecalibrateTradeDayWithBOP()
  {
   bool bModified = false;

   if(symbol.Bid() >= HBOP)
     {
      tradeDay = SELL_DAY;
      bModified = true;
     }

   if(symbol.Ask() <= LBOP)
     {
      tradeDay = BUY_DAY;
      bModified = true;
     }

   if(bModified)
     {
      CurrentTradeDay.Description(TradeDays[tradeDay]);
      Print("Recalibrate Trad Day to " + (tradeDay == SELL_DAY ? "SELL" : "BUY"));
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
bool RecalibrateTradeDayWithSIP()
  {
   int bDay = iLowest(_Symbol, ReactTimeFrame, MODE_LOW, 12);
   int sDay = iHighest(_Symbol, ReactTimeFrame, MODE_HIGH, 12);
   bool calibrated = false;

   Print("Lowest Bar is " + bDay);
   Print("Highest Bar is " + sDay);

   if(bDay > sDay)
     {
      tradeDay = (sDay + 2) % 3;
      Print("Use Highest S day as First day: " + sDay);
      calibrated = true;
     }
   else
      if(sDay > bDay)
        {
         tradeDay = bDay % 3;
         Print("Use Lowest B day as First day: " + bDay);
         calibrated = true;
        }

   return calibrated;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateReactionLines()
  {
   color LineColor = clrWhiteSmoke;

   CalculateReactionPrices(PriceB, PriceS, HBOP, LBOP, 1);

   if(spreadMargin > PriceS - PriceB)
      LineColor = clrDimGray;

   SellLine.Price(0, PriceS);
   SellLine.Color(LineColor);

   BuyLine.Price(0, PriceB);
   BuyLine.Color(LineColor);

   HBOPLine.Price(0, HBOP);
   LBOPLine.Price(0, LBOP);

   CurrentTradeDay.Description(TradeDays[tradeDay]);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteReactionLines()
  {
   SellLine.Delete();
   BuyLine.Delete();
   HBOPLine.Delete();
   LBOPLine.Delete();
   CurrentTradeDay.Delete();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateSignalLabel()
  {
   double adx = NormalizeDouble(adxr.Main(0), 3);
   double dmp = NormalizeDouble(adxr.Plus(0), 3);
   double dmn = NormalizeDouble(adxr.Minus(0), 3);

   signalLabel.Color(adx > 20 ? clrYellowGreen : clrRed);
   signalLabel.Description(adx);

   dmpLabel.Color(dmp > 20 ? clrWhite : clrDarkGray);
   dmpLabel.Description(dmp + " ▲");

   dmnLabel.Color(dmn > 20 ? clrWhite : clrDarkGray);
   dmnLabel.Description(dmn + " ▼");
  }
//+------------------------------------------------------------------+

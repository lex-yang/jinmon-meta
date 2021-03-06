//+------------------------------------------------------------------+
//|                                               JinmonWilder04.mq5 |
//|                                                              Lex |
//|                                                                  |
//+------------------------------------------------------------------+
#include "CiASI.mqh"
#include "CiBBP.mqh"
#include "..\CSI\CiADXR.mqh"

#include <Generic\ArrayList.mqh>

#include <Indicators\Indicators.mqh>

#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>

enum ENUM_EA_MODE
  {
   AUTO_MODE = 0,
   MANUAL_MODE = 1,
   AGENT_MODE = 2,
   SUPPLY_DEMAND_MODE = 3,
  };

input ENUM_TIMEFRAMES   ADX_TF = PERIOD_H1;
input ENUM_TIMEFRAMES   TRADE_TF = PERIOD_M5;
input int               ADX_Period = 12;           // Period of ADX & ATR.
input double            InpT=300.0;                // T (maximum price changing)
input int               SP_RANGE = 36;
input bool              InpShowSP = true;          // Display Significant Swing Points.
input bool              InpSwingAlert = false;     // Alert user when ASI cross significant SP.
input bool              InpNotifyDevice = false;   // Send Notification to Device.
input bool              InpCompactMode = true;     // Only calculate & display Swing Points.

input bool              InpAttachBBP = false;      // Attach Bollinger Band Indicator to chart.

CSymbolInfo    *symbol;
CiADXR         *TrendADX;
CiADXR         *TradeADX;
CiBBP          *bbp;
CiBBP          *bbp50;
CiASI          *asi;
CIndicators    *indicators;

CChartObjectLabel shspLabel;
CChartObjectLabel slspLabel;

CChartObjectLabel hspLabel;
CChartObjectLabel lspLabel;

CChartObjectLabel hsarLabel;
CChartObjectLabel lsarLabel;

CChartObjectLabel trendLabel;
CChartObjectLabel trendDIPLabel;
CChartObjectLabel trendDINLabel;

CChartObjectLabel tradeLabel;
CChartObjectLabel tradeDIPLabel;
CChartObjectLabel tradeDINLabel;

CChartObjectLabel modeLabel;
CChartObjectLabel bbpLabel;
CChartObjectLabel bbwLabel;
CChartObjectLabel bbsLabel;

CChartObjectLabel bbp50Label;
CChartObjectLabel bbs50Label;

//--- HSP
int                  SHSPIndex = -1;
double               SHSPValue = 0;
double               SHSPPrice = 0;
datetime             SHSPDatetime;

datetime             HSPdatetime;
double               HSPvalue = 0;
double               HSPprice = 0;

datetime             HSARdatetime;
double               HSARvalue = 0;
double               HSARprice = 0;

CArrayList<int>      hspIndex;
CArrayList<double>   hspValue;

//--- LSP
int                  SLSPIndex = -1;
double               SLSPValue = 0;
double               SLSPPrice = 0;
datetime             SLSPDatetime;

datetime             LSPdatetime;
double               LSPvalue = 0;
double               LSPprice = 0;

datetime             LSARdatetime;
double               LSARvalue = 0;
double               LSARprice = 0;

CArrayList<int>      lspIndex;
CArrayList<double>   lspValue;

//--- Position
CPositionInfo  *position;
CTrade         *trade;

double         ADX = 0;
ulong          positionTicket = ULONG_MAX;

//--- EA Mode
ENUM_EA_MODE   eaMode = AUTO_MODE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   switch(TRADE_TF)
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

//--- Indicator Container.
   indicators = new CIndicators();

//--- Label for Trade Information.
   if(!InpCompactMode)
     {
      //--- Create ADX indicators.
      TrendADX = new CiADXR();
      TrendADX.Create(_Symbol, ADX_TF, ADX_Period);
      indicators.Add(TrendADX);

      TradeADX = new CiADXR();
      TradeADX.Create(_Symbol, TRADE_TF, ADX_Period);
      indicators.Add(TradeADX);

      //--- Create Labels.
      trendLabel.Create(0, "Trend Signal", 0, 260, 3);
      trendDIPLabel.Create(0, "Trend DI+", 0, 320, 3);
      trendDINLabel.Create(0, "Trend DI-", 0, 400, 3);

      tradeLabel.Create(0, "Trade Signal", 0, 260, 23);
      tradeDIPLabel.Create(0, "Trade DI+", 0, 320, 23);
      tradeDINLabel.Create(0, "Trade DI-", 0, 400, 23);
      
      //--- Bollinger Band Labels
      bbpLabel.Create(0, "Bollinger Band %", 0, 600, 3);
      bbpLabel.Color(clrWhite);
      bbpLabel.Description();

      bbwLabel.Create(0, "Bollinger Band Width", 0, 550, 3);
      bbwLabel.Color(clrWhite);
      bbwLabel.Description();
   
      bbsLabel.Create(0, "Bollinger Band Squeeze", 0, 550, 23);
      bbsLabel.Color(clrWhite);
      bbsLabel.Description("BBS");
     }

//---
   symbol = new CSymbolInfo();
   symbol.Name(_Symbol);

   asi = new CiASI();
   asi.Create(_Symbol, TRADE_TF, InpT);
   indicators.Add(asi);

   bbp = new CiBBP();
   bbp.Create(_Symbol, PERIOD_CURRENT);
   if(InpAttachBBP)
      bbp.AddToChart(0, ChartGetInteger(0, CHART_WINDOWS_TOTAL, 0));

   indicators.Add(bbp);

   position = new CPositionInfo();
   trade = new CTrade();

//---
   indicators.Refresh();

   UpdateSignalLabel();

   if(InpShowSP)
     {
      FindSignificantSwingPoint(true);

      //--- Labels for Significant Swing Point.
      shspLabel.Create(0, "Significant HSP", 0, SHSPDatetime, SHSPPrice + 2);
      shspLabel.Color(clrGold);
      shspLabel.Description("SH");

      slspLabel.Create(0, "Significant LSP", 0, SLSPDatetime, SLSPPrice - 2);
      slspLabel.Color(clrGold);
      slspLabel.Description("SL");

      hspLabel.Create(0, "Nearest HSP", 0, HSPdatetime, HSPprice + 1);
      hspLabel.Color(clrWhiteSmoke);
      hspLabel.Description("H");

      lspLabel.Create(0, "Nearest LSP", 0, LSPdatetime, LSPprice - 1);
      lspLabel.Color(clrWhiteSmoke);
      lspLabel.Description("L");

      hsarLabel.Create(0, "High SAR", 0, HSARdatetime, HSARprice + 1);
      hsarLabel.Color(clrWhiteSmoke);
      hsarLabel.Description("Hsar");

      lsarLabel.Create(0, "Low SAR", 0, LSARdatetime, LSARprice - 1);
      lsarLabel.Color(clrWhiteSmoke);
      lsarLabel.Description("Lsar");
     }

//--- Misc. Labels
   modeLabel.Create(0, "Mode", 0, 500, 3);
   modeLabel.Color(clrDodgerBlue);
   modeLabel.Description("A");

   EventSetTimer(60);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();

   delete symbol;

   delete asi;
   delete indicators;

   delete position;
   delete trade;

   shspLabel.Delete();
   slspLabel.Delete();
   hspLabel.Delete();
   lspLabel.Delete();
   hsarLabel.Delete();
   lsarLabel.Delete();

   modeLabel.Delete();

   if(!InpCompactMode)
     {
      delete TrendADX;
      delete TradeADX;

      trendLabel.Delete();
      trendDIPLabel.Delete();
      trendDINLabel.Delete();

      tradeLabel.Delete();
      tradeDIPLabel.Delete();
      tradeDINLabel.Delete();
     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
int timerInterval = 0;

bool NotifiedUser = false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   ulong seconds = TimeCurrent();
   string message;

   if(eaMode == AUTO_MODE && !NotifiedUser && ADX > 20 && positionTicket == ULONG_MAX)
     {
      double asi = asi.Main(0);
      if(SHSPPrice != 0 && asi > SHSPValue && SHSPValue > HSPvalue)
        {
         if(!InpSwingAlert)
            return ;

         message = _Symbol + " 突破 HSP";
         if(InpNotifyDevice)
            SendNotification(message);
         if(!InpNotifyDevice)
            Alert(message);

         NotifiedUser = true;
        }
      else
         if(SLSPPrice != 0 && asi < SLSPValue && SLSPValue < LSPvalue)
           {
            if(!InpSwingAlert)
               return ;

            message = _Symbol + " 跌破 LSP";
            if(InpNotifyDevice)
               SendNotification(message);
            if(!InpNotifyDevice)
               Alert(message);

            NotifiedUser = true;
           }
     }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
int timerTick = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Update HSP, LSP, S-HSP, S-LSP, HSAR, LSAR, before a new candle bar.
//if(seconds % timerInterval == (timerInterval - 1))
//--- No position, detect if ASI cross Significant HSP / LSP.
   symbol.RefreshRates();
   indicators.Refresh();

//--- Update Signal Label.
   if(eaMode == AUTO_MODE)
      UpdateSignalLabel();

   if(InpShowSP)
     {
      FindSignificantSwingPoint();

      shspLabel.SetPoint(0, SHSPDatetime, SHSPPrice);
      slspLabel.SetPoint(0, SLSPDatetime, SLSPPrice);

      hspLabel.SetPoint(0, HSPdatetime, HSPprice);
      lspLabel.SetPoint(0, LSPdatetime, LSPprice);

      hsarLabel.SetPoint(0, HSARdatetime, HSARprice);
      lsarLabel.SetPoint(0, LSARdatetime, LSARprice);
     }

//--- Reset all flags.
   NotifiedUser = false;

//--- Update SAR.
   /*
      if(PositionsTotal())
        {
         //--- Find position which belonged to current symbol.
         positionTicket = ULONG_MAX;
         for(int i = PositionsTotal() - 1; i >= 0; i --)
           {
            position.SelectByIndex(i);
            if(position.Symbol() == _Symbol)
              {
               positionTicket = position.Ticket();
               UpdateStopLoss(positionTicket);
               break;
              }
           }
        }
   */
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//--- Find position belong to current symbol.
   positionTicket = ULONG_MAX;

   for(int i = PositionsTotal() - 1; i > 0; i --)
     {
      position.SelectByIndex(i);
      if(position.Symbol() == _Symbol)
        {
         positionTicket = position.Ticket();
         break;
        }
     }
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
   switch(id)
     {
      case CHARTEVENT_CLICK:
         MouseHandler(lparam, dparam);
         break;
      case CHARTEVENT_KEYDOWN:
         KeyDownHandler(lparam);
         break;
     }
  }
//+------------------------------------------------------------------+
//| Key Event handler                                                |
//+------------------------------------------------------------------+
void KeyDownHandler(const long& key)
  {
//Print("Key Code: " + key);
   switch(key)
     {
      case 'A':
         eaMode = AUTO_MODE;
         Print("Auto Mode");
         modeLabel.Description("A");
         break;
      case 'M':
         eaMode = MANUAL_MODE;
         Print("Manual Mode");
         modeLabel.Description("M");
         break;
      case 'C':
         eaMode = AGENT_MODE;
         Print("Agent Mode");
         modeLabel.Description("C");
         break;
      case 'R':
         eaMode = SUPPLY_DEMAND_MODE;
         Print("Supply & Demand Mode");
         modeLabel.Description("R");
         break;
     }
  }
//+------------------------------------------------------------------+
//| Mouse Event handler                                              |
//+------------------------------------------------------------------+
void MouseHandler(int x, int y)
  {
   if(eaMode == AUTO_MODE)
      return ;

   int subWindow;
   datetime time;
   double price;

   if(ChartXYToTimePrice(0, x, y, subWindow, time, price) == false)
     {
      Alert("Failed to Convert X/Y to Time Price !");
      return ;
     }

   switch(eaMode)
     {
      case SUPPLY_DEMAND_MODE:
      case AGENT_MODE:
        {
         int index = iBarShift(_Symbol, PERIOD_CURRENT, time);
         if(index == 0)
            return ;

         int h = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 4, index);
         int l = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 4, index);
         Print("H = " + h);
         Print("L = " + l);
         
         double highest = iHigh(_Symbol, PERIOD_CURRENT, h);
         double lowest  = iLow(_Symbol, PERIOD_CURRENT, l);
         double range = NormalizeDouble(highest - lowest, _Digits);

         //--- Agent Mode specific process.
         if(eaMode == AGENT_MODE)
            MessageBox("Price Range = " + NormalizeDouble(range, 2));

         //--- S&D Mode specific process.
         if(eaMode == SUPPLY_DEMAND_MODE)
           {
            CChartObjectRectangle *sdZone;
            sdZone = new CChartObjectRectangle();
            sdZone.Create(0, "SD Zone" + time, 0, iTime(_Symbol, PERIOD_CURRENT, index + 2), highest, TimeCurrent(), lowest);
            sdZone.Fill(true);
            sdZone.Background(true);
            sdZone.Color(clrGainsboro);
            sdZone.Selectable(true);
            sdZone.Tooltip("H: " + highest + " / L: " + lowest + " / R: " + range);
           }
           
         // back to Auto Mode.
         eaMode = AUTO_MODE;
         modeLabel.Description("A");
        }
      break;        
      case MANUAL_MODE:
        {
         int trendShift = iBarShift(_Symbol, ADX_TF, time);
         int tradeShift = iBarShift(_Symbol, TRADE_TF, time);
         Print("M15: " + trendShift + ", M5: " + tradeShift);

         UpdateSignalLabel(trendShift, tradeShift);
        }
      break;
     }
  }

//+------------------------------------------------------------------+
void UpdateSignalLabel(int trendShift = 0, int tradeShift = 0)
  {
   if(InpCompactMode)
      return ;

   ADX = NormalizeDouble(TrendADX.Main(trendShift), 3);
   double dmp = NormalizeDouble(TrendADX.Plus(trendShift), 3);
   double dmn = NormalizeDouble(TrendADX.Minus(trendShift), 3);

   trendLabel.Color(ADX > 20 ? clrYellowGreen : clrRed);
   trendLabel.Description(ADX);

   trendDIPLabel.Color(dmp > 20 ? clrWhite : clrDarkGray);
   trendDIPLabel.Description(dmp + " ▲");

   trendDINLabel.Color(dmn > 20 ? clrWhite : clrDarkGray);
   trendDINLabel.Description(dmn + " ▼");

   double adx = NormalizeDouble(TradeADX.Main(tradeShift), 3);
   dmp = NormalizeDouble(TradeADX.Plus(tradeShift), 3);
   dmn = NormalizeDouble(TradeADX.Minus(tradeShift), 3);

   tradeLabel.Color(adx > 20 ? clrYellowGreen : clrRed);
   tradeLabel.Description(adx);

   tradeDIPLabel.Color(dmp > 20 ? clrWhite : clrDarkGray);
   tradeDIPLabel.Description(dmp + " ▲");

   tradeDINLabel.Color(dmn > 20 ? clrWhite : clrDarkGray);
   tradeDINLabel.Description(dmn + " ▼");
   
   //--- Update Bollinger Band Width & Squeeze Rate.
   bbpLabel.Description(NormalizeDouble(bbp.BBP(tradeShift) * 100, 2) + "%");
   bbwLabel.Description(NormalizeDouble(bbp.Width(tradeShift), _Digits));
   bbsLabel.Description(NormalizeDouble(bbp.SR(tradeShift), _Digits) + "%");
  }
//+------------------------------------------------------------------+
//| Finding HSP and LSP                                              |
//+------------------------------------------------------------------+
void FindSignificantSwingPoint(const bool initialize = false)
  {
   if(!InpShowSP)
      return ;

   int index, count;
   double sp0, sp1, sp2;

//if(initialize)
   hspIndex.Clear();
   hspValue.Clear();
   lspIndex.Clear();
   lspValue.Clear();

     {
      int i;
      //--- Find all HSP and LSP in range.
      for(i = 0; i < SP_RANGE; i ++)
        {
         double sp = asi.SwingPoint(i);
         if(sp == 1)
           {
            hspIndex.Add(i);
            hspValue.Add(asi.Main(i));
           }
         else
            if(sp == -1)
              {
               lspIndex.Add(i);
               lspValue.Add(asi.Main(i));
              }
        }
     }

//-- High Index SAR
   hspIndex.TryGetValue(0, index);
   hspValue.TryGetValue(0, sp0);
   HSARdatetime = iTime(_Symbol, TRADE_TF, index);
   HSARprice = iHigh(_Symbol, TRADE_TF, index);
   HSARvalue = sp0;

//-- Low Index SAR
   lspIndex.TryGetValue(0, index);
   lspValue.TryGetValue(0, sp0);
   LSARdatetime = iTime(_Symbol, TRADE_TF, index);
   LSARprice = iLow(_Symbol, TRADE_TF, index);
   LSARvalue = sp0;

//--- Find Significant HSP.
   count = hspIndex.Count();

   hspValue.TryGetValue(0, sp0);
   SHSPPrice = 0;
   HSPprice = 0;
   for(int i = 1; i < count - 1; i ++, sp0 = sp1)
     {
      hspValue.TryGetValue(i, sp1);
      hspValue.TryGetValue(i + 1, sp2);

      if(sp2 < sp1 && sp1 > sp0)
        {
         hspIndex.TryGetValue(i, SHSPIndex);
         SHSPDatetime = iTime(_Symbol, TRADE_TF, SHSPIndex);
         SHSPPrice = iHigh(_Symbol, TRADE_TF, SHSPIndex);
         SHSPValue = sp1;

         Print("Significant HSP time  : " + SHSPDatetime);
         Print("Significant HSP value : " + SHSPValue);
         Print("Significant HSP Price : " + SHSPPrice);

         hspIndex.TryGetValue(i - 1, index);
         HSPdatetime = iTime(_Symbol, TRADE_TF, index);
         HSPprice = iHigh(_Symbol, TRADE_TF, index);
         HSPvalue = sp0;
         break;
        }
     }

   if(SHSPPrice == 0)
      Print("No Significant HSP in range("+SP_RANGE+")");

//--- Find Significant LSP.
   count = lspIndex.Count();

   lspValue.TryGetValue(0, sp0);
   SLSPPrice = 0;
   LSPprice = 0;
   for(int i = 1; i < count - 1; i ++, sp0 = sp1)
     {
      lspValue.TryGetValue(i, sp1);
      lspValue.TryGetValue(i + 1, sp2);

      if(sp2 > sp1 && sp1 < sp0)
        {
         lspIndex.TryGetValue(i, SLSPIndex);
         SLSPDatetime = iTime(_Symbol, TRADE_TF, SLSPIndex);
         SLSPPrice = iLow(_Symbol, TRADE_TF, SLSPIndex);
         SLSPValue = sp1;

         Print("Significant LSP time  : " + SLSPDatetime);
         Print("Significant LSP value : " + SLSPValue);
         Print("Significant LSP Price : " + SLSPPrice);

         lspIndex.TryGetValue(i - 1, index);
         LSPdatetime = iTime(_Symbol, TRADE_TF, index);
         LSPprice = iLow(_Symbol, TRADE_TF, index);
         LSPvalue = sp0;
         break;
        }
     }

   if(SLSPPrice == 0)
      Print("No Significant LSP in range("+SP_RANGE+")");

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void UpdateStopLoss(ulong ticket)
  {
   double   stopLoss = position.StopLoss();
   double   spread = symbol.Spread() * symbol.Point();
   double   sar = 0;

   switch(position.PositionType())
     {
      case POSITION_TYPE_SELL:
         // Do NOT use High SAR until ASI was less.
         if(HSARvalue <= asi.Main(0))
            break;

         sar = HSARprice + spread;
         Print("Latest HSP : " + HSARprice + " / Spread : " + spread);
         if(stopLoss == 0 || sar < stopLoss)
           {
            trade.PositionModify(ticket, sar, 0);
            Print("Trail SAR to : " + sar);
           }
         break;
      case POSITION_TYPE_BUY:
         // Do NOT use Low SAR until ASI was greater.
         if(LSARvalue >= asi.Main(0))
            break;

         sar = LSARprice - spread;
         Print("Latest LSP : " + LSARprice + " / Spread : " + spread);
         if(stopLoss == 0 || sar > stopLoss)
           {
            trade.PositionModify(ticket, sar, 0);
            Print("Trail SAR to : " + sar);
           }
         break;
     }
  }
//+------------------------------------------------------------------+

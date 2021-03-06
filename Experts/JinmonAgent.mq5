//+------------------------------------------------------------------+
//|                                                  JinmonAgent.mq5 |
//|                                         Lex Yang @ Jinmon Island |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex Yang @ Jinmon Island"
#property link      ""
#property version   "1.00"

#include <JAson.mqh>

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

//--- input parameters
input long     order_magic = 55555;

input double   additionLot=0;
input double   slDelta=0;
input double   orderLot=0;
input double   pollingInterval=1;
input bool     verbose=false;
input bool     dryRun=false;
input string   agentCallback = "http://127.0.0.1/";

//--- Trade variables.
const string   SELL_ORDER = "sell";
const string   BUY_ORDER = "buy";
const string   CLOSE_ORDER = "close";

CPositionInfo position;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(pollingInterval);

   trade.SetExpertMagicNumber(order_magic);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetAsyncMode(false);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   string cookie = NULL, headers;
   char post[], result[];

   int res = WebRequest("POST", agentCallback + "mt/poll/", cookie, NULL, 500, post, 0, result, headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      //--- Perhaps the URL is not listed, display a message about the necessity to add the address
      //MessageBox("Add the address to the list of allowed URLs on tab 'Expert Advisors'","Error",MB_ICONINFORMATION);
      Print("Add the address [", agentCallback, "] to the list of allowed URLs on tab 'Expert Advisors'");
     }
   else
     {
      if(res==200)
        {
         if(ArraySize(result) == 2)
           {
            if(verbose)
               Print("NA");
           }
         else
           {
            CJAVal jv;
            jv.Deserialize(result);

            double stoploss = jv["sl"].ToDbl();
            const double lot = orderLot ? orderLot : jv["l"].ToDbl();
            const string action = jv["a"].ToStr();
            const bool addition = jv["add"].ToBool();

            MqlTick latest_price;
            SymbolInfoTick(_Symbol, latest_price);

            if(stoploss == 0)
              {
               stoploss = (action == SELL_ORDER) ? (latest_price.ask + slDelta) : (latest_price.bid - slDelta);
              }

            Print("Lot: ", lot);
            Print("StopLoss: ", stoploss);
            Print("Action: ", action);

            // Dry-Run only for debugging.
            if(dryRun)
               return ;

            if(action == CLOSE_ORDER)
               CloseOrder();

            if(action == SELL_ORDER)
              {
               if(PositionsTotal() == 0)
                 {
                  trade.Sell(lot, NULL, 0, stoploss);
                  Print("--------------------");
                  Print(">> Sell " + lot + " at " + latest_price.bid + ", sl: " + stoploss);
                  Print("--------------------");
                 }
               else
                  if(addition)
                    {
                     trade.Sell(additionLot, NULL, 0, stoploss);
                     Print("--------------------");
                     Print(">> Additional Sell " + additionLot + " at " + latest_price.bid + ", sl: " + stoploss);
                     Print("--------------------");
                    }
                  else
                    {
                     position.SelectByIndex(0);
                     if(position.PositionType() == POSITION_TYPE_BUY)
                       {
                        CloseOrder();
                        Print("--------------------");
                        Print(">> Close order");
                        Print("--------------------");
                       }

                    }
              }

            if(action == BUY_ORDER)
              {
               if(PositionsTotal() == 0)
                 {
                  trade.Buy(lot, NULL, 0, stoploss);
                  Print("--------------------");
                  Print(">> Buy " + lot + " at " + latest_price.ask + ", sl: " + stoploss);
                  Print("--------------------");
                 }
               else
                  if(addition)
                    {
                     trade.Buy(additionLot, NULL, 0, stoploss);
                     Print("--------------------");
                     Print(">> Additional Buy " + additionLot + " at " + latest_price.ask + ", sl: " + stoploss);
                     Print("--------------------");
                    }
                  else
                    {
                     position.SelectByIndex(0);
                     if(position.PositionType() == POSITION_TYPE_SELL)
                       {
                        CloseOrder();
                        Print("--------------------");
                        Print(">> Close order");
                        Print("--------------------");
                       }
                    }
              }
           }
        }
      else
         PrintFormat("Downloading failed, error code %d",res);
     }
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
bool CloseOrder()
  {
   int count = PositionsTotal();

   for(int count = PositionsTotal(); count > 0; count --)
     {
      if(position.SelectByIndex(count - 1))
         !trade.PositionClose(position.Ticket());
     }
   return true;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

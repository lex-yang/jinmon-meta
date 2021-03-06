//+------------------------------------------------------------------+
//|                                                  JinmonAgent.mq5 |
//|                                         Lex Yang @ Jinmon Island |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex Yang @ Jinmon Island"
#property link      ""
#property version   "1.00"

#include <JAson.mqh>
#include <Indicators\Indicators.mqh>
#include "JinmonWilder04\CiADP.mqh"

//--- Indicator Objects
CiRSI*         rsi;
CiMA*          ma21;
CiMA*          ma50;
CiADP*         adp;
CIndicators    indicators;

//--- input parameters
input string            InpListName="OHLC";        // List to save features.
input ENUM_TIMEFRAMES   InpTimeFrame = PERIOD_M1;
input bool              InpVerbose = false;

//--- misc. variables
int      fileHandle = INVALID_HANDLE;
int      extractPeriod = 0;
  
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   string now = TimeToString(TimeCurrent(), TIME_DATE);
   string ts_suffix = "none";
   
   switch(InpTimeFrame)
   {
   case PERIOD_M1:
      extractPeriod = 1 * 60;
      ts_suffix = "M1";
      break;
   case PERIOD_M5:
      extractPeriod = 5 * 60;
      ts_suffix = "M5";
      break;
   case PERIOD_M15:
      extractPeriod = 15 * 60;
      ts_suffix = "M15";
      break;
   case PERIOD_H1:
      extractPeriod = 60 * 60;
      ts_suffix = "H1";
      break;
   }
 
   string fileName = "Features\\" + InpListName + "-" + now + "-" + ts_suffix + ".json";
   Print("Root Folder : " + TerminalInfoString(TERMINAL_DATA_PATH));
   Print("Open file : " + fileName);

   fileHandle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI, 0);
   if(fileHandle == INVALID_HANDLE)
      Print("Failed to Open File !!!");
   else
      FileWriteString(fileHandle, "[");

//--- Initialize RSI indicator.
   MqlParam params[];
   
   rsi = new CiRSI();
   rsi.Create(_Symbol, InpTimeFrame, 21, PRICE_CLOSE);
   
   ma21 = new CiMA();
   ma21.Create(_Symbol, InpTimeFrame, 21, 0, MODE_SMA, PRICE_CLOSE);
   
   ma50 = new CiMA();
   ma50.Create(_Symbol, InpTimeFrame, 50, 0, MODE_SMA, PRICE_CLOSE);
   
   adp = new CiADP();
   adp.Create(_Symbol, InpTimeFrame);
   
   indicators.Add(rsi);
   indicators.Add(ma21);
   indicators.Add(ma50);
   indicators.Add(adp);   

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(fileHandle != INVALID_HANDLE)
     {
      FileSeek(fileHandle, -3, SEEK_CUR);
      FileWriteString(fileHandle, "]");
      Print("Flush ...");
      FileFlush(fileHandle);
      Print("Close file !");
      FileClose(fileHandle);
     }
     
   if(rsi) delete rsi;
   if(ma21) delete ma21;
   if(ma50) delete ma50;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Latest Price.
   MqlTick latest_price;
   SymbolInfoTick(_Symbol, latest_price);

   if(latest_price.time % extractPeriod)
      return ;

   indicators.Refresh();
   string jsonTickData = ConvertToJSON(InpTimeFrame, latest_price, rsi.Main(1), ma21.Main(1), ma50.Main(1), adp.Main(1));

   uint bytes = FileWriteString(fileHandle, jsonTickData + ",\n");
   if(fileHandle != INVALID_HANDLE && InpVerbose)
     {
      Print("Write Bytes: " + bytes);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ConvertToJSON(ENUM_TIMEFRAMES timeframes, MqlTick& price, double rsi, double ma21, double ma50, double adp)
  {
//--- Calculate OHLC features.
   double open = iOpen(_Symbol, timeframes, 1);
   double high = iHigh(_Symbol, timeframes, 1);
   double low  = iLow(_Symbol, timeframes, 1);
   double close= iClose(_Symbol, timeframes, 1);

//--- Convert to JSON format.
   string jsonString =  "{" +
//--- OHCL
                        "\"o\":" + open   + "," +
                        "\"h\":" + high   + "," +
                        "\"c\":" + close  + "," +
                        "\"l\":" + low    + "," +
//--- latest price
                        "\"la\":" + price.ask         + "," +
                        "\"lb\":" + price.bid         + "," +
                        "\"ts\":" + (uint)price.time  + "," +
//--- indicators
                        "\"rsi\":"  + NormalizeDouble(rsi, _Digits)  + "," +
                        "\"ma21\":" + NormalizeDouble(ma21, _Digits) + "," +
                        "\"ma50\":" + NormalizeDouble(ma50, _Digits) + "," +
                        "\"adp\":" + NormalizeDouble(adp, _Digits) + "," +
                        "}";
   return jsonString;
  }

//+------------------------------------------------------------------+

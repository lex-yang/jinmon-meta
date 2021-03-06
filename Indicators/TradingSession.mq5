//+------------------------------------------------------------------+
//|                                  Trading Sessions Open Close.mq5 |
//|                                                Copyright VDVSoft |
//|                                                 vdv_2001@mail.ru |
//+------------------------------------------------------------------+
#property copyright "VDVSoft"
#property version   "1.00"
#property description "Trading Sessions"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   3
//---- plot The Asian session
#property indicator_label1  "Asian session High; Asian session Low"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'255,243,242'
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//---- plot The European session
#property indicator_label2  "European session High; European session Low"
#property indicator_type2   DRAW_FILLING
#property indicator_color2  C'235,235,252'
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//---- plot The American session
#property indicator_label3  "American session"
#property indicator_type3   DRAW_FILLING
#property indicator_color3  C'206,253,206'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Delta Analyzer.
#include <Generic\ArrayList.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>

input datetime    InpStartTime = "2021.02.02 09:00:00";
input bool        InpEnableLeap = true;            // Extra 50 mins per session.
input bool        InpShowDeltaSession = false;     // Show Delta Sessions.

CArrayList<CChartObjectVLine*> TimeLines;

const ulong DELTA_TIME_SPAN = (24 * 60) * 60;
const ulong DELTA_LEAP_TIME = 50 * 60;

color DeltaColors[] = {clrGold, clrDodgerBlue, clrYellowGreen, clrRed};
const ENUM_LINE_STYLE   TIME_LINE_STYLE = STYLE_DOT;

//--- Trading Sessions.
double      AsiaHigh[];
double      AsiaLow[];
double      EuropaHigh[];
double      EuropaLow[];
double      AmericaHigh[];
double      AmericaLow[];
//    Time constants are specified across Greenwich
const int   AsiaOpen=0;
const int   AsiaClose=9;
const int   AsiaOpenSummertime=1;   // The Asian session shifts
const int   AsiaCloseSummertime=10; // after the time changes
const int   EuropaOpen=6;
const int   EuropaClose=15;
const int   AmericaOpen=13;
const int   AmericaClose=22;
//    Global variable
int         ShiftTime;  //Displacement of the buffer for construction of the future sessions
double      HighForFutureSession;   // High for the future session
double      LowForFutureSession;    // Low for the future session

input bool  InpShowAsia = true;     // Show Asia Session
input bool  InpShowEuropa = true;   // Show Europa Session
input bool  InpShowAmerica = true;  // Show America Session

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
//--- Verify Time Period
   if( PeriodSeconds(_Period)>=PeriodSeconds(PERIOD_H2) )
   {
      return(-1);
   }
//--- Displacement of the buffer for construction of the future sessions
   ShiftTime=PeriodSeconds(PERIOD_D1)/PeriodSeconds(_Period);
   
//--- indicators
   SetIndexBuffer(0,AsiaHigh,INDICATOR_DATA);
   SetIndexBuffer(1,AsiaLow,INDICATOR_DATA);
   SetIndexBuffer(2,EuropaHigh,INDICATOR_DATA);
   SetIndexBuffer(3,EuropaLow,INDICATOR_DATA);
   SetIndexBuffer(4,AmericaHigh,INDICATOR_DATA);
   SetIndexBuffer(5,AmericaLow,INDICATOR_DATA);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   PlotIndexSetInteger(0,PLOT_SHIFT,ShiftTime);
   PlotIndexSetInteger(1,PLOT_SHIFT,ShiftTime);
   PlotIndexSetInteger(2,PLOT_SHIFT,ShiftTime);
   PlotIndexSetInteger(3,PLOT_SHIFT,ShiftTime);
   PlotIndexSetInteger(4,PLOT_SHIFT,ShiftTime);
   PlotIndexSetInteger(5,PLOT_SHIFT,ShiftTime);
//---

   if(InpShowDeltaSession)
      DrawDeltaSession();

   return(0);
}

void OnDeinit(const int reason)
  {
   if(InpShowDeltaSession)
      DeinitDeltaSession();
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
//--- auxiliary variables
   int  i=1;
   HighForFutureSession=MathMax(high[rates_total-1],high[rates_total-2]);
   LowForFutureSession=MathMin(low[rates_total-1],low[rates_total-2]);
   MqlDateTime time1, time2;
//--- set position for beginning
   if(prev_calculated==0)
   {
      i=ShiftTime+1;
      ArrayInitialize(AsiaHigh, 0.0);
      ArrayInitialize(AsiaLow, 0.0);
      ArrayInitialize(EuropaHigh, 0.0);
      ArrayInitialize(EuropaLow, 0.0);
      ArrayInitialize(AmericaHigh, 0.0);
      ArrayInitialize(AmericaLow, 0.0);
   }
   else
      i=prev_calculated-ShiftTime;
//--- start calculations
   while(i<rates_total)
   {
      TimeToStruct(time[i-1], time1);
      TimeToStruct(time[i], time2);
      if(time1.day!=time2.day)
      {
         DrawTimeZone(time[i],i);
      }
      i++;
   }
//--- return value of prev_calculated for next call
   return(rates_total);
}
//+--------------------------------------------------------------------+
// Summertime determination is reserved for the future calculations
//+--------------------------------------------------------------------+
bool Summertime(datetime time)
{
   if(TimeDaylightSavings()!=0)
      return(true);
   else
      return(false);
}
//+--------------------------------------------------------------------+
// Calculation and filling of buffers of time zones
//+--------------------------------------------------------------------+

void DrawTimeZone(datetime Start, int Index)
{
   int rates_total,shift,shift_end,_startIndex=Index-ShiftTime;
   double iHigh[], iLow[], HighSession, LowSession;
   datetime AsiaStart, AsiaEnd, EuropaStart, EuropaEnd, AmericaStart, AmericaEnd;
   datetime _start=Start+(TimeTradeServer()-TimeGMT());

// Processing of the Asian session
   if(InpShowAsia)
     {
      AsiaStart=_start+(Summertime(Start)?AsiaOpenSummertime:AsiaOpen)*PeriodSeconds(PERIOD_H1);
      AsiaEnd=_start+(Summertime(Start)?AsiaCloseSummertime:AsiaClose)*PeriodSeconds(PERIOD_H1)-1;
      rates_total=CopyHigh(NULL,_Period,AsiaStart,AsiaEnd,iHigh);
      if(rates_total<=0)
         HighSession=HighForFutureSession;
      else
         HighSession=iHigh[ArrayMaximum(iHigh,0,rates_total)];
      rates_total=CopyLow(NULL,_Period,AsiaStart,AsiaEnd,iLow);
      if(rates_total<=0)
         LowSession=LowForFutureSession;
      else
         LowSession=iLow[ArrayMinimum(iLow,0,rates_total)];
      shift=int((AsiaStart-Start)/PeriodSeconds(_Period));
      shift_end=int((AsiaEnd-Start)/PeriodSeconds(_Period)+1);
      for(int i=shift; i<shift_end; i++)
      {
         AsiaHigh[_startIndex+i]=HighSession;
         AsiaLow[_startIndex+i]=LowSession;
      }
     }

// Processing of the European session
   if(InpShowEuropa)
     {
      EuropaStart=_start+EuropaOpen*PeriodSeconds(PERIOD_H1);
      EuropaEnd=_start+EuropaClose*PeriodSeconds(PERIOD_H1)-1;
      rates_total=CopyHigh(NULL,_Period,EuropaStart,EuropaEnd,iHigh);
      if(rates_total<=0)
         HighSession=HighForFutureSession;
      else
         HighSession=iHigh[ArrayMaximum(iHigh,0,rates_total)];
      rates_total=CopyLow(NULL,_Period,EuropaStart,EuropaEnd,iLow);
      if(rates_total<=0)
         LowSession=LowForFutureSession;
      else
         LowSession=iLow[ArrayMinimum(iLow,0,rates_total)];
      shift=int((EuropaStart-Start)/PeriodSeconds(_Period));
      shift_end=int((EuropaEnd-Start)/PeriodSeconds(_Period)+1);
      for(int i=shift; i<shift_end; i++)
      {
         EuropaHigh[_startIndex+i]=HighSession;
         EuropaLow[_startIndex+i]=LowSession;
      }
     }

// Processing of the American session
   if(InpShowAmerica)
     {
      AmericaStart=_start+AmericaOpen*PeriodSeconds(PERIOD_H1);
      AmericaEnd=_start+AmericaClose*PeriodSeconds(PERIOD_H1)-1;
      rates_total=CopyHigh(NULL,_Period,AmericaStart,AmericaEnd,iHigh);
      if(rates_total<=0)
         HighSession=HighForFutureSession;
      else
         HighSession=iHigh[ArrayMaximum(iHigh,0,rates_total)];
      rates_total=CopyLow(NULL,_Period,AmericaStart,AmericaEnd,iLow);
      if(rates_total<=0)
         LowSession=LowForFutureSession;
      else
         LowSession=iLow[ArrayMinimum(iLow,0,rates_total)];
      shift=int((AmericaStart-Start)/PeriodSeconds(_Period));
      shift_end=int((AmericaEnd-Start)/PeriodSeconds(_Period)+1);
      for(int i=shift; i<shift_end; i++)
      {
         AmericaHigh[_startIndex+i]=HighSession;
         AmericaLow[_startIndex+i]=LowSession;
      }
     }

// Memory clearing
   ArrayResize(iHigh,0);
   ArrayResize(iLow,0);
}

void DrawDeltaSession()
  {
   int   colorIndex = 0;
   MqlDateTime sTime;
   ulong delta = DELTA_TIME_SPAN + (InpEnableLeap ? DELTA_LEAP_TIME : 0);
   datetime end = TimeCurrent() + delta;
   datetime vdate;

   CChartObjectVLine *vLine;
   datetime start = InpStartTime;

   do
     {
      vLine = new CChartObjectVLine();
      TimeToStruct(start, sTime);
      switch(sTime.day_of_week)
        {
         case 1:  // Monday
            vdate = start + 3600;
            break;
         case 6:  // Saturday
            vdate = start - 3600;
            break;
         default:
            vdate = start;
            break;
        }

      // Skip Sunday.
      //if(sTime.day_of_week > 0)
        {
         vLine.Create(0, "Delta Line " + start, 0, vdate);
         vLine.Color(DeltaColors[colorIndex]);
         vLine.Style(TIME_LINE_STYLE);

         TimeLines.Add(vLine);

         // Create Middle Line (White)
         vLine.Create(0, "Delta Line M - " + start , 0, vdate + delta / 2);
         vLine.Color(clrWhiteSmoke);
         vLine.Style(TIME_LINE_STYLE);

         TimeLines.Add(vLine);
        }

      start += delta;
      colorIndex = (colorIndex + 1) % 4;
     }
   while(start < end);
  }
  
void  DeinitDeltaSession()
  {
   CChartObjectVLine *line;

   do
     {
      TimeLines.TryGetValue(0, line);
      line.Delete();
      TimeLines.RemoveAt(0);
     }
   while(TimeLines.Count());
  }
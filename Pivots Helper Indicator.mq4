//+------------------------------------------------------------------+
//|    PivotsHelperIndicator.mq4                                     |
//|    MT4trendindicator.com                                         |
//+------------------------------------------------------------------+
#property copyright "MT4trendindicator.com"
#property link      "https://mt4trendindicator.com"
#property version   "1.0"
#property strict
#property description "Calculates daily, weekly or monthly pivot levels for custom switch time."

//types
#define PIVOTS_NUMBER 7
#define SECONDS_IN_DAY 86400

enum PIVOTS_NAMES {PP=0,S1=1,S2=2,S3=3,R1=4,R2=5,R3=6};
enum PIVOT_KIND{Daily=0,Weekly,Monthly};

//---- indicator settings
#property indicator_chart_window
#property  indicator_buffers PIVOTS_NUMBER
#property  indicator_color1  clrBlack
#property  indicator_color2  clrRed
#property  indicator_color3  clrRed
#property  indicator_color4  clrRed
#property  indicator_color5  clrGreen
#property  indicator_color6  clrGreen
#property  indicator_color7  clrGreen

#property  indicator_width1  2
#property  indicator_width2  1
#property  indicator_width3  1
#property  indicator_width4  1
#property  indicator_width5  1
#property  indicator_width6  1
#property  indicator_width7  1

#property  indicator_style1  STYLE_SOLID
#property  indicator_style2  STYLE_SOLID
#property  indicator_style3  STYLE_SOLID
#property  indicator_style4  STYLE_SOLID
#property  indicator_style5  STYLE_SOLID
#property  indicator_style6  STYLE_SOLID
#property  indicator_style7  STYLE_SOLID


//---- indicator parameters
input PIVOT_KIND Kind=Daily;
input string SwitchTime="00:00";

//---- indicator buffers
double bPP[];
double bS1[];
double bS2[];
double bS3[];
double bR1[];
double bR2[];
double bR3[];
// classes



class Pivots
{
   public:
      Pivots();
      virtual void ~Pivots(){};
      bool GetFromOHLC(double h,double l,double c,double& p[]);
      static bool PivotIndicesAscending(PIVOTS_NAMES& p[]);
      static bool PivotIndexNext(PIVOTS_NAMES ind,PIVOTS_NAMES& n);
      static bool PivotIndexPrevious(PIVOTS_NAMES ind,PIVOTS_NAMES& p);
};

Pivots::Pivots(void)
{
}

bool Pivots::GetFromOHLC(double h,double l,double c,double &p[])
{
   if(ArrayResize(p,PIVOTS_NUMBER)==PIVOTS_NUMBER)
   {
      p[PP]=NormalizeDouble((h+l+c)/3.0,Digits);
      p[R1]=2.0*p[PP]-l;
      p[S1]=2.0*p[PP]-h;
      p[R2]=p[PP]-p[S1]+p[R1];
      p[S2]=p[PP]-p[R1]+p[S1];
      p[R3]=h+2.*(p[PP]-l);
      p[S3]=l-2.*(h-p[PP]);
      return true;
   }
   return false;
}

static bool Pivots::PivotIndicesAscending(PIVOTS_NAMES &p[])
{
   if(ArrayResize(p,PIVOTS_NUMBER)==PIVOTS_NUMBER)
   {
      p[0]=S3;
      p[1]=S2;
      p[2]=S1;
      p[3]=PP;
      p[4]=R1;
      p[5]=R2;
      p[6]=R3;
      return true;
   }
   return false;
}

static bool Pivots::PivotIndexNext(PIVOTS_NAMES ind,PIVOTS_NAMES& n)
{
   PIVOTS_NAMES pa[];
   if(Pivots::PivotIndicesAscending(pa))
   {
      for(int i=0;i<PIVOTS_NUMBER;i++)
      {
         if(pa[i]==ind)
         {
            if((i+1)<PIVOTS_NUMBER)
            {
               n=pa[i+1];
               return true;
            }
            else return false; 
         }
      }
   }
   return false;
}

static bool Pivots::PivotIndexPrevious(PIVOTS_NAMES ind,PIVOTS_NAMES& p)
{
   PIVOTS_NAMES pa[];
   if(Pivots::PivotIndicesAscending(pa))
   {
      for(int i=0;i<PIVOTS_NUMBER;i++)
      {
         if(pa[i]==ind)
         {
            if((i-1)>=0)
            {
               p=pa[i-1];
               return true;
            }
            else return false; 
         }
      }
   }
   return false;
}

//!!! Class TimeCompact
class TimeCompact
{
   public:
   int hours;
   int minutes;
   TimeCompact();
   bool Init(string s);//string format "00:00"
   int TotalSeconds();
};

TimeCompact::TimeCompact(void)
{
   hours=0;
   minutes=0;
}

bool TimeCompact::Init(string s)
{
   string ft[];
   int res=StringSplit(s,StringGetCharacter(":",0),ft);
   if(res!=2) return false;
   if(StringLen(ft[0])==0 || StringLen(ft[1])==0) return false;
   hours=(int)StringToInteger(ft[0]);
   minutes=(int)StringToInteger(ft[1]);
   if(hours<0 || hours>24) return false;
   if(minutes<0 || minutes>59) return false;
   return true;
}

int TimeCompact::TotalSeconds(void)
{
   return hours*3600+minutes*60;
}

//Time functions
datetime TimeBase(datetime dt)
{
   return dt-TimeHour(dt)*3600-TimeMinute(dt)*60-TimeSeconds(dt);
}

bool IsWeekend(datetime dt)
{
   return TimeDayOfWeek(dt)==SUNDAY || TimeDayOfWeek(dt)== SATURDAY;
}


datetime WeekendShiftBackward(datetime dt)
{
   datetime res=dt;
   while(IsWeekend(res)) res-=SECONDS_IN_DAY;
   return res;
}

datetime WeekendShiftForward(datetime dt)
{
   datetime res=dt;
   while(IsWeekend(res)) res+=SECONDS_IN_DAY;
   return res;
}

datetime SwitchForDay(datetime dt)
{
   return TimeBase(dt)+g_st.TotalSeconds();
}

bool GetDailyFromTo(datetime dt,datetime& from,datetime& to)
{
   datetime st=SwitchForDay(dt);
   if(TimeDayOfWeek(st)==MONDAY) st-=SECONDS_IN_DAY;//Use the same as sunday 
   to= dt>=st ? st : st-SECONDS_IN_DAY;
   from=WeekendShiftBackward(to-SECONDS_IN_DAY);
   if(TimeDayOfWeek(from)==MONDAY) from-=SECONDS_IN_DAY;//Use monday and weekends for Tuesday 
   return true;
}


bool GetOHLC(datetime from,datetime to,double& o,double& h,double& l,double& c)
{
   o=0;
   c=0;
   h=0;
   l=DBL_MAX;
   for(int i=Bars-1;i>=0;i--)
   {
      if(Time[i]<from) continue;
      if(Time[i]>=to) break;
      if(IsEqual(o,0)) o=Open[i];
      c=Close[i];
      if(High[i]>h) h=High[i];
      if(Low[i]<l) l=Low[i];
   }
   return (!IsEqual(o,0)) && (!IsEqual(c,0)) && (!IsEqual(h,0)) && (!IsEqual(l,DBL_MAX));
}

TimeCompact g_st;

int OnInit()
{
   IndicatorBuffers(PIVOTS_NUMBER);
   IndicatorDigits(Digits+1);

//---- drawing settings
   SetIndexStyle(0,DRAW_LINE);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexStyle(2,DRAW_LINE);
   SetIndexStyle(3,DRAW_LINE);
   SetIndexStyle(4,DRAW_LINE);
   SetIndexStyle(5,DRAW_LINE);
   SetIndexStyle(6,DRAW_LINE);
   
//---- indicator buffers mapping
   SetIndexBuffer(0,bPP);
   SetIndexBuffer(1,bS1);
   SetIndexBuffer(2,bS2);
   SetIndexBuffer(3,bS3);
   SetIndexBuffer(4,bR1);
   SetIndexBuffer(5,bR2);
   SetIndexBuffer(6,bR3);
   
   SetIndexEmptyValue(0,0.0);
   SetIndexEmptyValue(1,0.0);
   SetIndexEmptyValue(2,0.0);
   SetIndexEmptyValue(3,0.0);
   SetIndexEmptyValue(4,0.0);
   SetIndexEmptyValue(5,0.0);
   SetIndexEmptyValue(6,0.0);

//---- name for DataWindow and indicator subwindow label
   IndicatorShortName("Pivots Custom");
   SetIndexLabel(0,EnumToString(Kind)+" "+EnumToString(PP));
   SetIndexLabel(1,EnumToString(Kind)+" "+EnumToString(S1));
   SetIndexLabel(2,EnumToString(Kind)+" "+EnumToString(S2));
   SetIndexLabel(3,EnumToString(Kind)+" "+EnumToString(S3));
   SetIndexLabel(4,EnumToString(Kind)+" "+EnumToString(R1));
   SetIndexLabel(5,EnumToString(Kind)+" "+EnumToString(R2));
   SetIndexLabel(6,EnumToString(Kind)+" "+EnumToString(R3));

   if(!g_st.Init(SwitchTime))
   {
      Alert("SwitchTime "+SwitchTime+" : incorrect format");
      return INIT_PARAMETERS_INCORRECT;
   }
//---- initialization done
   return(INIT_SUCCEEDED);
}

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
   int limit;
   int counted_bars=IndicatorCounted();
//---- last counted bar will be recounted
   if(counted_bars>0) counted_bars--;
   limit=Bars-counted_bars;
   for(int i=limit-1; i>=0; i--)
   {
      bool res=false;
      double o,h,l,c;
      if(Kind==Daily)
      {
         datetime from,to,from1,to1;
         if(GetDailyFromTo(Time[i],from,to))
         {
            if((i+1)<Bars) 
            {
               if(GetDailyFromTo(Time[i+1],from1,to1))
               {
                  if(from1==from && to1==to)
                  {
                     if(CopyPreviousValues(i)) res=true;
                  }
               }
            }
            
            if(!res)
            {
               if(GetOHLC(from,to,o,h,l,c))
               {
                  if(SetByOHLC(i,h,l,c)) res=true;
               }
            }   
         }
      }
      else if(Kind==Weekly)
      {
         ENUM_TIMEFRAMES tf=PERIOD_W1;
         int sourceBar = GetSourceBar(tf,i);
         if(sourceBar>=0)
         {
            int sb1=GetSourceBar(tf,i+1);
            if(sourceBar==sb1)
            {
               if(CopyPreviousValues(i)) res=true;
            }
            if(!res)
            {
               if(SetByOHLC(i,iHigh(Symbol(),tf,sourceBar),iLow(Symbol(),tf,sourceBar),iClose(Symbol(),tf,sourceBar))) res=true;
            }   
         }
      }
      else if(Kind==Monthly)
      {
         ENUM_TIMEFRAMES tf=PERIOD_MN1;
         int sourceBar = GetSourceBar(tf,i);
         if(sourceBar>=0)
         {
            int sb1=GetSourceBar(tf,i+1);
            if(sourceBar==sb1)
            {
               if(CopyPreviousValues(i)) res=true;
            }
            if(!res)
            {
               if(SetByOHLC(i,iHigh(Symbol(),tf,sourceBar),iLow(Symbol(),tf,sourceBar),iClose(Symbol(),tf,sourceBar))) res=true;
            }   
         }
      }
      if(!res) SetEmpty(i); 
   }
//---- done
   return(rates_total);
}

bool IsEqual(double val1, double val2,int acc=1)
{
   return (MathAbs(val1-val2)<=(acc*Point));
}

bool CopyPreviousValues(int i)
{
   if(i>=Bars) return false;
   if(IsEqual(bPP[i+1],0)) return false;
   bPP[i]=bPP[i+1];
   bS1[i]=bS1[i+1];
   bS2[i]=bS2[i+1];
   bS3[i]=bS3[i+1];
   bR1[i]=bR1[i+1];
   bR2[i]=bR2[i+1];
   bR3[i]=bR3[i+1];
   return true;  
}

void SetEmpty(int i)
{
   if(i<Bars)
   {
      bPP[i]=0;
      bS1[i]=0;
      bS2[i]=0;
      bS3[i]=0;
      bR1[i]=0;
      bR2[i]=0;
      bR3[i]=0;
   }
}

bool SetByOHLC(int i,double h,double l,double c)
{
   if(i<Bars)
   {
      Pivots pc;
      double p[];
      if(pc.GetFromOHLC(h,l,c,p))
      {
         bPP[i]=p[PP];
         bS1[i]=p[S1];
         bS2[i]=p[S2];
         bS3[i]=p[S3];
         bR1[i]=p[R1];
         bR2[i]=p[R2];
         bR3[i]=p[R3];
         return true;
      }
   }
   return false;
}

//returns -1 if not found
int GetSourceBar(ENUM_TIMEFRAMES tf,int i)
{
   if(i<Bars)
   {
      int sourceBar = iBarShift(Symbol(),tf,Time[i]);
      if(sourceBar>=0)
      {
         sourceBar++;
         if(TimeDayOfWeek(Time[i])==SUNDAY && Time[i]<SwitchForDay(Time[i]) && tf==PERIOD_W1) sourceBar++;
         if(TimeDay(Time[i])==1 && Time[i]<SwitchForDay(Time[i]) && tf==PERIOD_MN1) sourceBar++;
         return sourceBar;
      }
   }
   return -1;
}
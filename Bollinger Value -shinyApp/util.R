
# ---Source for all useful Utilities ------

# startDate=(as.Date("01/01/2008",format="%m/%d/%Y"))
# endDate = as.Date("12/31/2009",format="%m/%d/%Y")
# getStockHist("AAPL",startDate,endDate)

getStockHist <- function(stk,sdate,edate,pricetype="Adj.Close") {
 
  
  smonth = as.numeric(format(sdate,"%m"))
  sday = as.numeric(format(sdate,"%d"))
  syear = as.numeric(format(sdate,"%Y"))
  
  
  emonth = as.numeric(format(edate,"%m"))
  eday = as.numeric(format(edate,"%d"))
  eyear = as.numeric(format(edate,"%Y"))
  
  
  url<-paste("http://real-chart.finance.yahoo.com/table.csv?s=",stk,"&a=",smonth-1,"&b=",sday,"&c=",syear,"&d=",emonth-1,"&e=",eday,"&f=",eyear,"&g=d&ignore=.csv",sep="")
  
  
  urls <- lapply(stk,function(x)paste0("http://real-chart.finance.yahoo.com/table.csv?s=",x,"&a=",smonth-1,"&b=",sday,"&c=",syear,"&d=",emonth-1,"&e=",eday,"&f=",eyear,"&g=d&ignore=.csv"))
  # print(urls) 
  
  ss<-lapply(urls,function(x)tryCatch(read.csv(x),error=function(e)return(NA)))
  
  ss= (as.data.frame(ss)) #[,c("Date")]
 
  ss= subset(ss,select= c("Date",pricetype))
   
  colnames(ss)<-c("date","price")
  
  ss$date<-as.Date(ss$date)
  
  ss <- ss[order(ss$date),] 
  
  #  print("printing SS")

  # THIS SHOJLD ALSO SCRUB OUT ALL NA  
  return(ss)
} #getStkHist

# 
# { #-----  Driver for Stock Hist-----------
# startDate=(as.Date("01/01/2008",format="%m/%d/%Y"))
# endDate = as.Date("12/31/2009",format="%m/%d/%Y")
# 
# asset.vec = read.csv("sp5002012.csv")
# 
# event = 10
# 
# st = mapply(SIMPLIFY=FALSE ,as.character(asset.vec$stock)  ,FUN=function(x)tryCatch(getStockHist(stk=x,sdate=startDate,edate=endDate,pricetype="Close") ,error=function(e)return(NA)))
# }



eventgenerate<-function(stkhist,event,pricedrop){
  
  
  stkhist = stkhist[order(as.Date(stkhist$date)),] #order by dates
  
  if(pricedrop == TRUE){
  idx = which(stkhist[which(stkhist$close<event)-1,]$close>=event) # records of a day earlier > event 
    newdf = (stkhist[which(stkhist$close<event)-1,])
  
  }else{
    # Price Surge
    idx = which(stkhist[which(stkhist$close<event)-1,]$close<event) # records of a day earlier < event 
    newdf = (stkhist[which(stkhist$close<event)-1,])
    
    
  }
  return(newdf[idx,])
  
}


generateTX<-function(stkvalues,orders){
  
  symlist = unique(orders$symbol)
  
  holdings = matrix(nrow= nrow(stkvalues),ncol=length(symlist))
  
  colnames(holdings)<-c(as.character(symlist))
  
  #replace(orders$action, grep("Buy",orders$action),c("1"))
  
  orders$action = gsub(c("Buy"),c(1),orders$action)
  
  orders$action = gsub(c("Sell"),c(-1),orders$action)
  
  orders$action = as.numeric(orders$action)
  
  # Assign orders to holdings -------
  
  for(or in 1:nrow(orders)){
    
    holdings[which(stkvalues$date==orders$date[or]),as.character(orders$symbol[or])] = orders$number[or]*orders$action[or]
    
    
  } # for loop
  
  #--- assignment done --- Same day buy and sell needs to be checked----
  
  txmatrix = holdings[is.na(holdings)]<-0
  
  txmatrix = holdings  # transaction matrix
  
  
  return (txmatrix)
   }  # function 


getPortfolioStats<-function(dailyreturns, pfweights){
  
  pf.ret  = pfweights%*%t(dailyreturns) # daily returns
  pf.sd = sd(pf.ret,na.rm=TRUE)  # Volatility - seems ok 
  
  pf.mean = mean(pf.ret,na.rm=TRUE)-1  # Avg daily Return or divide by 251?
  
  pf.ret.cumm = rowSums(pf.ret,na.rm=TRUE)/(ncol(pf.ret)) # Average Daily Return +1
  
  pf.sharpe =sqrt(252)*(pf.mean/pf.sd)
  pf.sharpe
  
  df=data.frame(pf.sd, pf.mean,pf.sharpe)
  
  return(df)
  
  #  return(as.data.frame(c(pfsd=pf.sd, pfmean=pf.mean, pfsharpe=pf.sharpe)))
}


getBollingerValue<-function(asset,startDate,endDate,lookback){
  
#   endDate is the daet at which BValue is done
#   startDate is begin of stock history
#   Min 2 assests are required   
  
  endDate = as.Date(endDate,format="%m/%d/%Y")
  startDate = as.Date(startDate,format="%m/%d/%Y")- 2*(lookback)
  
  st = mapply(SIMPLIFY=FALSE ,as.character(asset)  ,FUN=function(x)tryCatch(getStockHist(stk=x,sdate=startDate,edate=endDate,pricetype="Adj.Close") ,error=function(e)return(NA)))
  
  stkval= do.call("cbind",st)
  
  stkval= stkval[order(stkval[1],decreasing=T),]

  
  roll.mean = colMeans(stkval[1:lookback,paste0(asset,".price")])
  
  roll.sd = apply(stkval[1:lookback,paste0(asset,".price")], 2, sd)
  
  
  prices = stkval[1,grep("*.price",colnames(stkval))]
  
  return ((prices-roll.mean)/roll.sd)
  
  
}

getMultipleBollingerValues<-function(asset,endDate,lookback,idxrange){
  
  #   endDate is the daet at which BValue is done
  #   startDate is begin of stock history
  #   Min 2 assests are required   
  
  endDate = as.Date(endDate,format="%m/%d/%Y")
  startDate = endDate -2*idxrange- 2*(lookback)
  
  st = mapply(SIMPLIFY=FALSE ,as.character(asset)  ,FUN=function(x)tryCatch(getStockHist(stk=x,sdate=startDate,edate=endDate,pricetype="Adj.Close") ,error=function(e)return(NA)))
  
  stkval= do.call("cbind",st)
  asset.vec.rv = names(st)
  stkval= stkval[order(stkval[1],decreasing=T),]
  
  
  rollsd = sapply(c(1:idxrange),function(x){apply(stkval[x:(x+lookback-1),paste0(asset.vec.rv,".price")], 2, sd)})
  
  
  rollmean = as.matrix(sapply(c(1:idxrange),function(x){apply(stkval[x:(x+lookback-1),paste0(asset.vec.rv,".price")], 2, mean)}))
  
  stkprices = as.matrix(sapply(c(1:idxrange),function(x){stkval[x,paste0(asset.vec.rv,".price")]}))
#   df = t(as.data.frame((as.numeric(stkprices)-rollmean)/rollsd) )
#   cbind(df,stkval[1])
  return((as.numeric(stkprices)-rollmean)/rollsd) 
  
  
}

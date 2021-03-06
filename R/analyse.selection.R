# 0. help -----------------------------------------------------------------
#' Study of the intra-population selection within the mixture project
#' 
#' @param donnees Results from \code{\link{PPBstats::MC} (list) or from \code{\link{shinemas2R::get.data} (data frame)
#' 
#' @param data_version Result from \code{\link{shinemas2R::get.data}} with query.type = "data-S" with add columns type ("Composante" or "Mélange") and modalite which is the discriminating factor when empile = TRUE
#' 
#' @param variable The variable on which the analysis is done. Must be one of the elements of donnees
#' 
#' @param person Element of the plot title
#' 
#' @param empile If TRUE, separate the graphic in x plots depending on the x levels of the data_version's "modalite" column 
#' 
#' @param nom A name to put on graphic title
#' 
#' @return A list containing the plot and the data frame containing the data
#' 
#' @author Gaelle Van Frank
#' 
#' @seealso \code{\link{}}
#' 
analyse.selection = function(donnees, data_version, variable, person, empile=FALSE, nom="", language="english")
{
  
  data=unique(data_version[,c("year","location","germplasm","group","type","modalite")])
  data$vrac = paste("mu[",sapply(strsplit(as.character(data$group)," | "),function(x){return(x[[1]])}),",",data$location,":",data$year,"]",sep="")
  data$bouquet = paste("mu[",sapply(strsplit(as.character(data$group)," | "),function(x){return(x[[3]])}),",",data$location,":",data$year,"]",sep="")

  
#0. functions ---------
 compare_model = function(x){
   # x : nom du vrac et nom du bouquet. La fonction retourne la moyenne de chacune des chaines ainsi que la comparaison des 2
   MCMC = donnees[[variable]]$model.outputs$MCMC
   vrac=MCMC[,colnames(MCMC) %in% x["vrac"]] 
   bouquet=MCMC[,colnames(MCMC) %in% x["bouquet"]]
   
   Result = as.data.frame(cbind(vrac,bouquet))
   if(length(Result) == 2){ 
     colnames(Result) = c("mu[vrac]","mu[bouquet]")
     Mpvalue = comp.parameters(Result, parameter = "mu", type = 1)
     return(c(mean(vrac),mean(bouquet),Mpvalue[1,2]))
   }
 }
 
 WMW = function(x){
   # x: nom du vrac et du bouquet
   if (class(x) == "data.frame"){Mat = donnees[as.character(donnees$expe_name) %in% x[,"group"],]}else{Mat = donnees[as.character(donnees$expe_name) %in% x["group"],]}
   # add one since color, awns and curve can be 0 and then problems when calculating overyielding
   vrac=as.numeric(na.omit(Mat[grep("vrac",Mat$sl_statut),variable]))
   bouquet = as.numeric(na.omit(Mat[grep("bouquet",Mat$sl_statut),variable]))
   
   if (var(na.omit(bouquet)) == 0 & var(na.omit(vrac)) == 0){
     if(mean(bouquet) == mean(vrac)){pval = 1}else{pval=0}
   }else{
     # Test non paramétrique U de Wilcoxon-Mann-Whitney pour données semi_quantitatives
     pval = wilcox.test(as.numeric(c(vrac,bouquet)) ~ c(rep("vrac",length(vrac)),rep("bouquet",length(bouquet))))$p.value
     
   }
   return(c(mean(na.omit(as.numeric(vrac))),mean(na.omit(as.numeric(bouquet))),pval))
 }
 
 get_stars = function(signif) {
   stars = findInterval(signif, c(0, 0.001, 0.01, 0.05, 0.1))
   codes = c("***" , "**","*", ".", " ")
   return(codes[stars])
 }
 

#1. If the data was analyzed using bayesian model -----------
if (class(donnees) == "list"){
  if (!(variable %in% names(donnees))){stop("Variable must be one of donnees's names")}
  result = apply(data,1,FUN=compare_model)
  if(class(result) == "list"){Res=NULL; comp = NULL; for (i in 1:length(result)){if(!is.null(result[[i]])){Res=cbind(Res,result[[i]])}else{comp = c(comp,i)}}; result=Res; data=data[-comp,]}
}
   
#2. If the data was not analyzed using the bayesian model: semi-quantitative data such as awns, color, curve --> use chi2 test to compare selection vs bulk-----------
if(class(donnees) == "data.frame"){
  if (!(variable %in% names(donnees))){stop("Variable must be one of donnees's names")}
  result = apply(data,1,FUN=WMW)
}
 
#3. Calculations ----------------
 result = t(result)
 colnames(result) = c("MoyenneVrac","MoyenneBouquet","pvalue")
 Data=cbind(data,result)
 if(class(donnees) == "list"){Data$overyielding = Data$MoyenneBouquet/Data$MoyenneVrac-1}
 if(class(donnees) == "data.frame"){Data$overyielding = Data$MoyenneBouquet-Data$MoyenneVrac}

 Data=Data[Data$modalite != "",]
 pval= NULL
 Data[is.na(Data$pvalue),"pvalue"] = 1
 for (i in 1:nrow(Data)){
   if (Data[i,"type"] == "Composante" & as.numeric(as.character(Data[i,"pvalue"])) <= 0.01){
     if(language == "english"){pval = c(pval,"Component, significant at 0.01")}else{pval = c(pval,"Composante, significatif à 0.01")}}
   if (Data[i,"type"] == "Composante" & as.numeric(as.character(Data[i,"pvalue"])) <= 0.05 & as.numeric(as.character(Data[i,"pvalue"])) > 0.01 ){
     if(language == "english"){pval = c(pval,"Component, significant at 0.05")}else{pval = c(pval,"Composante, significatif à 0.05")}}
   if (Data[i,"type"] == "Composante" & as.numeric(as.character(Data[i,"pvalue"])) > 0.05){
     if(language == "english"){pval = c(pval,"Component, not significant (pvalue > 0.05)")}else{pval = c(pval,"Composante, non significatif (pvalue > 0.05)")}}
   if (Data[i,"type"] == "Mélange" & as.numeric(as.character(Data[i,"pvalue"])) <= 0.01){
     if(language == "english"){pval = c(pval,"Mixture, significant at 0.01")}else{pval = c(pval,"Mélange, significatif à 0.01")}}
   if (Data[i,"type"] == "Mélange" & as.numeric(as.character(Data[i,"pvalue"])) <= 0.05 & as.numeric(as.character(Data[i,"pvalue"])) > 0.01 ){
     if(language == "english"){pval = c(pval,"Mixture, significant at 0.05")}else{pval = c(pval,"Mélange, significatif à 0.05")}}
   if (Data[i,"type"] == "Mélange" & as.numeric(as.character(Data[i,"pvalue"])) > 0.05){
     if(language == "english"){pval = c(pval,"Mixture, not significant (pvalue > 0.05)")}else{pval = c(pval,"Mélange, non significatif (pvalue > 0.05)")}}
 }

  Mean=unlist(lapply(levels(as.factor(Data$modalite)),function(x){mean(Data[Data$modalite %in% x,"overyielding"])}))
  names(Mean) = levels(as.factor(Data$modalite))
  MeanGlob = mean(Data$overyielding)

 Data$pval = pval
 
 mel = Data[Data$type %in% "Mélange", "overyielding"]
 names(mel) = Data[Data$type %in% "Mélange", "germplasm"]

#3. Test to check if overyielding is different from zero ---------
 if (empile == FALSE){
   if(shapiro.test(Data$overyielding)$p.value <= 0.05){Signif = t.test(Data$overyielding, mu=0)$p.value }else{ Signif = wilcox.test(Data$overyielding, mu=0)$p.value}
 }
 if (empile ==TRUE){
   Signif = unlist(lapply(unique(Data$modalite),function(x){
     if(length(Data[Data$modalite %in% x,"modalite"]) < 3){
       Signif=1
     }else{
       if (length(unique(Data[Data$modalite %in% x,"overyielding"])) == 1){
         if(mean(Data[Data$modalite %in% x,"overyielding"]) == 0){Signif = 1}else{Signif = 0}
       }else{
         if(shapiro.test(Data[Data$modalite %in% x,"overyielding"])$p.value <= 0.05){ 
           Signif = t.test(Data[Data$modalite %in% x,"overyielding"], mu=0)$p.value
         }else{  Signif = wilcox.test(Data[Data$modalite %in% x,"overyielding"], mu=0)$p.value}
       }

     }

     return(Signif)
   }))
   names(Signif)=unique(Data$modalite)
 }
 
 Data$modalite = unlist(lapply(Data$modalite, function(x){paste(x,ifelse(language=="english","- Mean gain: "," - Gain moyen : "),round((Mean[x])*100,2)," % ",get_stars(Signif[x])," (n = ",nrow(Data[Data$modalite %in% x,])," )", sep="")}))
 

#4. Histogram ---------
  From= min(Data$overyielding)-0.2*abs(min(Data$overyielding))
  To = max(Data$overyielding) + 0.2*max(Data$overyielding)
  By = (max(Data$overyielding)-min(Data$overyielding))/12
  if (language == "english"){factoL = c("Component, not significant (pvalue > 0.05)","Component, significant at 0.05","Component, significant at 0.01",
                                        "Mixture, not significant (pvalue > 0.05)","Mixture, significant at 0.05","Mixture, significant at 0.01")
  }else{factoL = c("Composante, non significatif (pvalue > 0.05)","Composante, significatif à 0.05","Composante, significatif à 0.01",
                                                       "Mélange, non significatif (pvalue > 0.05)","Mélange, significatif à 0.05","Mélange, significatif à 0.01")}
  if(nrow(Data) ==1){p = ggplot(ylim = c(0,1))
  
  }else{ 
    p =  ggplot(data=Data,aes(as.numeric(as.character(overyielding)),fill=factor(pval, levels = factoL))) +
    geom_histogram(breaks = seq(From,To,By), color = "black")
  }
  
  if (empile==TRUE){ p = p + facet_wrap( ~ modalite, ncol =1, scales="free_y") + theme(strip.text.x = element_text(size=9))} 
  p = p + ggtitle(paste(person, variable, nom, sep=" : "))
  if (empile == FALSE) {
    p = p + geom_vline(xintercept = MeanGlob, size = 1.2, color="red")
  }
  if(class(donnees) == "list"){
    xlabel = ifelse(language == "english",paste("Normalised difference between selected and non-selected bulk, ",variable,sep=""),paste("Différence normalisée entre bouquet de sélection et vrac, ",variable,sep=""))
  }
  if(class(donnees) == "data.frame"){
    xlabel = ifelse(language == "english",paste("Difference between selected and non-selected bulk, ",variable,sep=""),paste("Différence entre bouquet de sélection et vrac, ",variable,sep=""))
  }
  p = p + labs(x=xlabel,
               y=ifelse(language == "english","Number of comparisons selected vs non-selected bulk","Nombre de couples Bouquet - Vrac")) 
  p = p + geom_vline(xintercept = 0,  linetype = "dotted")
  p = p + scale_fill_discrete(name = "")
  p = p + theme(legend.text = element_text(size = 7), axis.title = element_text(size = 10))
  
  if (empile==F){p = p + annotate("text",label = c(paste("n :",nrow(Data),sep=" "),
                                                   paste(ifelse(language == "english","Mean gain = ","Gain moyen = "),round(MeanGlob*100,2),"% (",get_stars(Signif),")",sep="")),x=(max(Data$overyielding)-0.2*max(Data$overyielding)),y=c(nrow(Data)/5,(nrow(Data)/5-nrow(Data)/50)),
                                                  size=3.5)
  }

  
  return(list("histo" = p, "tab" = Data))
}

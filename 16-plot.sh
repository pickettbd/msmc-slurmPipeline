#! /bin/bash

echo "plot"

#Plot in R
#First, you must determine the mutation rate (mu) and generation time
#I used a value from Liu, Hansen, & Jacobsen, 2016 'Region-wide and ecotype-specific differences in demographic histories of threespine stickleback populations, estimated from whole genome sequences', Molecular Ecology, vol. 25, pp. 5187–5202. https://doi.org/10.1111/mec.13827 This was also used in an msmc paper on Hamlets (Serranidae)
mu <- 3.7e-8 
gen <- 4 # 2 years old * 2

BT_msmcDat<-read.table("/Users/JessicaRGlass/Documents/SAIAB_PostDoc/Projects/Comparative_Genomics/Bluefin/msmc/msmc_output/msmc.final.txt", header=TRUE)

options(scipen = 7)
plot(BT_msmcDat$left_time_boundary/mu*gen, (1/BT_msmcDat$lambda)/mu, log="x",ylim=c(0,1.5e+06),
     type="n", xlab="Years ago", ylab="effective population size")
	 lines(BT_msmcDat$left_time_boundary/mu*gen, (1/BT_msmcDat$lambda)/mu, type="s", col="blue")
	

# what she actually did later instead of the original listed above
#Read in bootstrap runs for 780 Mbp replicates
setwd("/Users/JessicaRGlass/Documents/SAIAB_PostDoc/Projects/Comparative_Genomics/Bluefin/msmc/msmc_bootstrap_780Mbp")

BT_msmc_boot <- read.table("/Users/JessicaRGlass/Documents/SAIAB_PostDoc/Projects/Comparative_Genomics/Bluefin/msmc/msmc_bootstrap_780Mbp/msmc-bootstrap_concat.tsv", header = T)
head(BT_msmc_boot)

#Plot 
dev.off()
options(scipen = 7)
plot(BT_msmcDat2$left_time_boundary/mu*gen, (1/BT_msmcDat2$lambda)/mu, ylim=c(0,2.5e+05), xlim = c(0,5e+05), 
     type="n", xlab="Years ago", ylab="effective population size")


#read in bootstrap values and plot them as lines on the graph
  for (i in 1:max(BT_msmc_boot$Bootstrap_Round)) {
    BT_i <- BT_msmc_boot[BT_msmc_boot$Bootstrap_Round ==i,]
   
    lines(BT_i$left_time_boundary/mu*gen, (1/BT_i$lambda)/mu, type="s", col="light blue", lwd = 0.5 )
  }


# more stuff

#Calculate the median values
d = data.frame(x=rep(0,19), y=rep(0,19)) #set up a blank dataframe
for (i in unique(BT_msmc_boot$time_index)) {
BT_ti <- BT_msmc_boot[BT_msmc_boot$time_index == i,]

lt <- (median(BT_ti$left_time_boundary))
l <-  (median(BT_ti$lambda_00))

#put these in a data frame
d[i, ] = c(lt, l)
    
print(d)  

}

#Amend Time 0 data to dataframe
BT_ti.0 <- BT_msmc_boot[BT_msmc_boot$time_index == 0,]

lt.0 <- (median(BT_ti.0$left_time_boundary))
l.0 <-  (median(BT_ti.0$lambda_00))

d2 <- rbind(c(lt.0,l.0), d)
d2
#Now plot median values
lines(d2$x/mu*gen, (1/d2$y)/mu, type="s", col="blue", lwd = 2)

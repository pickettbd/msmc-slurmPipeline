#! /usr/bin/env Rscript

# import stuff
library(tibble)
library(ggplot2)

# handle the arguments
args <- commandArgs(trailingOnly=TRUE)

if (length(args) != 6 ) {
	stop("ERROR: You did not provide the correct number of arguments.")
}

mu <- as.numeric(args[1]) # 3.7e-8
age_at_maturity <- as.numeric(args[2]) # 2
age_multiplier <- as.numeric(args[3]) # 2
msmc_main_fn <- args[4] # data/msmc/msmc.final.txt
msmc_bootstrap_fn <- args[5] # data/msmc/bootstrap/msmc-bootstrap_concat.tsv
plot_fn <- args[6] # data/msmc/plot.pdf

# compute generation time
gen <- age_at_maturity * age_multiplier

# Read in the Bootstrap file
#   1                  2           3                    4                   5 
# Bootstrap_Round	time_index	left_time_boundary	right_time_boundary	lambda_00
data <- as_tibble(read.table(msmc_bootstrap_fn, header=TRUE, row.names=NULL))

# Read in the main msmc file
#    1           2                    3                   4 
# time_index	left_time_boundary	right_time_boundary	lambda_00
d <- as_tibble(read.table(msmc_main_fn, header=TRUE, row.names=NULL))

# prepend a "bootstrap round" column so it has the same shape
d <- as_tibble(cbind(rep(c(0), times=nrow(d)), d))
colnames(d) <- colnames(data)

# add the main msmc section to the bootstrap one in a single data.frame
data <- as_tibble(rbind(data, d))

# factorize the bootstrap round value
data$Bootstrap_Round <- as.factor(data$Bootstrap_Round)

## drop the last two time indices
#data <- data[data$time_index < 18,]

# add years_ago and N_e
data$years_ago <- data$left_time_boundary / mu * gen / 1000
data$N_e <- (1 / data$lambda_00) / mu

# calculate median values
d_med <- aggregate(cbind(years_ago,N_e)~time_index, data=subset(data, Bootstrap_Round != 0), FUN=median)
d_med <- as_tibble(cbind(rep(c(0), times=nrow(d_med)), d_med))
colnames(d_med) <- c("Bootstrap_Round", "time_index", "years_ago", "N_e")

# set scientific notation options
options(scipen=7)

# ggplot
p <- ggplot(data, aes(x=years_ago, y=N_e, group=Bootstrap_Round, lineend="butt", linejoin="square")) +
	geom_step(data=subset(data, Bootstrap_Round != 0), size=0.40, color="light blue", direction="vh") + 
	#geom_step(data=subset(data, Bootstrap_Round == 0), size=0.60, color="cornflowerblue", direction="vh") + 
	geom_step(data=d_med, size=0.5, color="blue", direction="vh") + 
	xlab("Time (kya)") + 
	ylab(expression("Effective Population Size (N"['e']*')')) + 
	scale_x_continuous(limits=c(0, as.integer(max(data$years_ago)) + 1), expand=c(0,0)) + 
	scale_y_continuous(limits=c(0, as.integer(max(data$N_e)) + 1), expand=c(0,0)) + 
	theme_classic() + 
	theme(axis.text=element_text(size=12, color="black"), axis.text.y=element_text(angle=90, vjust=1, hjust=0.5), 
			axis.title=element_text(size=14, color="black"), axis.ticks=element_line(color="black") 
		)

# save the plot
ggsave(plot_fn, plot=p, device="pdf", units="cm", width=20, height=15)

# quit
q()
	

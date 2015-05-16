#Deps, options
library(ggplot2)
library(urltools)
library(data.table)
options(scipen=500)

#Run query, read data
system("export HADOOP_HEAPSIZE=1024 && hive -f query.sql > api_data.tsv", wait = TRUE)
data <- read.delim("api_data.tsv", header = TRUE, as.is = TRUE, quote = "")

#Sanitise
data$year <- as.integer(data$year)
data$requests <- as.integer(data$requests)
data <- data[complete.cases(data),]
data$uri_query <- url_decode(data$uri_query)
options <- url_parameters(data$uri_query, parameter_names = c("namespace","limit","format"))

#?action=opensearch
#Deps, options
library(ggplot2)
library(urltools)
library(data.table)
library(scales) #For percentage scales.
library(maptools) #Mapping dependency
library(rgeos) #Mapping dependency
library(rworldmap) #SpatialPolygonDataFrame creation.
library(RColorBrewer) #Colour scale definitions.
library(gridExtra) #Multi-mapping
library(mapproj) #mollweide projection
library(stats)
library(olivr)
options(scipen=500)

#Run query, read data
system("export HADOOP_HEAPSIZE=1024 && hive -f query.sql > api_data.tsv", wait = TRUE)
data <- as.data.table(read.delim("api_data.tsv", header = TRUE, as.is = TRUE, quote = ""))

#Sanitise
data$year <- as.integer(data$year)
data$requests <- as.integer(data$requests)
data <- data[complete.cases(data),]
data$uri_query <- url_decode(data$uri_query)
data$referer <- url_parse(url_decode(data$referer))$domain

#Extract URI options
options <- as.data.table(url_parameters(data$uri_query, parameter_names = c("namespace","limit","format")))

#Map
country_data <- data[!data$country == "--", j=list(requests = sum(requests)), by = "country"]
names(country_data)[1:2] <- c("country","count")
cdm <- joinCountryData2Map(country_data, joinCode = "ISO2", nameJoinColumn = "country", suggestForFailedCodes = TRUE)
missing_countries <- unique(cdm$ISO_A2[!(cdm$ISO_A2 %in% country_data$country)])
if(length(missing_countries) >= 1){
  country_data <- rbind(country_data, data.frame(country = missing_countries, count=0))
}
cdm <- joinCountryData2Map(country_data, joinCode = "ISO2", nameJoinColumn = "country", suggestForFailedCodes=TRUE)
values <- as.data.frame(cdm[,c("count", "country")])
names(values) <- c("count", "id")
values <- unique(values)
fortified_polygons <- fortify(cdm, region = "country")
ggsave(file = "geo_plot.svg",
       plot = ggplot(values) + 
         geom_map(aes(fill = count, map_id = id),
                  map = fortified_polygons) +
         expand_limits(x = fortified_polygons$long,
                       y = fortified_polygons$lat) +
         coord_equal() + 
         coord_map(projection="mollweide") +
         labs(title = "Geographic distribution of API search requests",
              x = "Longitude",
              y = "Latitude") +
         scale_fill_gradientn(colours=brewer.pal(9, "Blues")[3:8]))

plot_theme <- function(){
  palette <- brewer.pal("Greys", n=9)
  color.background = palette[2]
  color.grid.major = palette[3]
  color.axis.text = palette[6]
  color.axis.title = palette[7]
  color.title = palette[9]
  
  # Begin construction of chart
  theme_bw(base_size=9) +
    
    # Set the entire chart region to a light gray color
    theme(panel.background=element_rect(fill=color.background, color=color.background)) +
    theme(plot.background=element_rect(fill=color.background, color=color.background)) +
    theme(panel.border=element_rect(color=color.background)) +
    
    # Format the grid
    theme(panel.grid.major=element_line(color=color.grid.major,size=.25)) +
    theme(panel.grid.minor=element_blank()) +
    theme(axis.ticks=element_blank()) +
    
    # Format the legend, but hide by default
    theme(legend.position="none") +
    theme(legend.background = element_rect(fill=color.background)) +
    theme(legend.text = element_text(size=7,color=color.axis.title)) +
    
    # Set title and axis labels, and format these and tick marks
    theme(plot.title=element_text(color=color.title, size=14)) +
    theme(axis.text.x=element_text(size=14,color=color.axis.text)) +
    theme(axis.text.y=element_text(size=14,color=color.axis.text)) +
    theme(axis.title.x=element_text(size=16,color=color.axis.title, vjust=0)) +
    theme(axis.title.y=element_text(size=16,color=color.axis.title, vjust=1.25))
}

#Format choices
options$requests <- data$requests
formats <- options[,j=list(requests = sum(requests)), by = "format"]
formats$format[formats$format==""] <- "default"
ggsave(file = "format_choice.svg",
       plot = ggplot(formats, aes(factor(formats$format, levels=formats$format[order(formats$requests, decreasing = T)]),
                                  requests)) + 
         geom_bar(stat="identity", fill = "#009E73") +
         labs(title = "Output format for API search requests",
              x = "Output format",
              y = "Requests") +
         plot_theme())

#Namespace choices
namespaces <- options[,j=list(requests = sum(requests)), by = "namespace"]
namespaces$namespace[namespaces$namespace==""] <- "default"
amended_namespaces <- data.table(namespace = "other",
                                 requests = sum(namespaces$requests[!namespaces$namespace %in% c("0","default")]))
namespaces <- rbind(namespaces[namespaces$namespace %in% c("0","default")], amended_namespaces)
ggsave(file = "namespace_choice.svg",
       plot = ggplot(namespaces, aes(factor(namespaces$namespace,
                                            levels=namespaces$namespace[order(namespaces$requests, decreasing = T)]),
                                  requests)) + 
         geom_bar(stat="identity", fill = "#009E73") +
         labs(title = "Namespace filtering in API search requests",
              x = "Namespace choice",
              y = "Requests") +
         plot_theme())

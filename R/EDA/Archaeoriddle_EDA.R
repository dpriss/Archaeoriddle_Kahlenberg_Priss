library(stringr)
library(ggplot2)
library(sf)
library(oxcAAR)
quickSetupOxcal()

## import site data ----
sites <- read.csv("DATA/allsites.CSV")

## extract site start/end  ----
sites$start_date <- str_sub(sites$dates, start = 1, end = 13)
sites$end_date <- str_trim(str_sub(sites$dates, start = -13), side = "left")

## extract numeric values from strings

for (i in 1:nrow(sites)) {
  sites$start_date_bp[i] <- as.numeric(str_sub(sites$start_date[i], 1,4))
  sites$start_date_std[i] <- as.numeric(str_sub(sites$start_date[i], 8,10))
  sites$end_date_bp[i] <- as.numeric(str_sub(sites$end_date[i], 1,4))
  sites$end_date_std[i] <- as.numeric(str_sub(sites$end_date[i], 8,10)) 
}

## calibrate 14C dates ----

my_cal_start_dates <- oxcalCalibrate(sites$start_date_bp, sites$start_date_std, sites$id)
my_cal_end_dates <- oxcalCalibrate(sites$end_date_bp, sites$end_date_std, sites$id)

# 1 sigma
for (i in 1:nrow(sites)) {
  sites$start_date_BC[i] <- as.numeric(str_sub(my_cal_start_dates[[sites$id[i]]][["sigma_ranges"]][["one_sigma"]][["start"]][[1]],2,5))
  sites$end_date_BC[i] <- as.numeric(str_sub(my_cal_end_dates[[sites$id[i]]][["sigma_ranges"]][["one_sigma"]][["end"]][[length(my_cal_end_dates[[sites$id[i]]][["sigma_ranges"]][["one_sigma"]][["end"]])]],2,5))
  }

## add time spans ----

sites$time_span <- 0

for (i in 1:nrow(sites)) {
  sites$time_span[i] <- as.numeric(sites$start_date_BC[i]) - as.numeric(sites$end_date_BC[i]) 
}

max_age <- max(sites$start_date_BC)
min_age <- min(sites$end_date_BC)

sites <- as.data.frame(sites)

## Create a scatterplot of site persistence by economy ----
ggplot(data = sites, aes(x = time_span, y = fitness, color = economy)) +
  geom_point() +
  scale_color_manual(values = c("F" = "green", "HG" = "red")) +
  labs(x = "Site persistence", y = "Fitness", color = "Economy") +
  ggtitle("Scatterplot of Fitness vs. Site persistence by Economy") 


## create table: sites per year ----
years <- seq(min_age,max_age)

number_of_sites <- data.frame(column1 = years, column2 = 0, column3 = 0)

colnames(number_of_sites) <- c("year", "HG_counts", "F_counts")


for (i in 1:nrow(sites)) {
  sites$id[i] <- paste0("site_",sites$id[i])
  column_name <- paste0(sites$id[i])
  number_of_sites[column_name] = ""
}


for (i in 1:nrow(number_of_sites)) {
  for (j in 1:nrow(sites)) {
    if (sites$start_date_BC[j]>=number_of_sites$year[i] && sites$end_date_BC[j]<=number_of_sites$year[i] && sites$economy[j]=="HG"){
      number_of_sites$HG_counts[i] <- number_of_sites$HG_counts[i] +1
    }
    if (sites$start_date_BC[j]>=number_of_sites$year[i] && sites$end_date_BC[j]<=number_of_sites$year[i] && sites$economy[j]=="F"){
      number_of_sites$F_counts[i] <- number_of_sites$F_counts[i] +1
    }
    
    ## add presence/absense of sites ----
    
    if (sites$start_date_BC[j]>=number_of_sites$year[i] && sites$end_date_BC[j]<=number_of_sites$year[i]){
      number_of_sites[i,paste0(sites$id[j])] <- TRUE
    } else {number_of_sites[i,paste0(sites$id[j])] <- FALSE}
    
  }
}

## export updated site data ----

# write.csv(number_of_sites, file = "DATA/presence-absence-table_calib.csv")
# write.csv(sites, file = "DATA/allsites_output_calib.csv")

## plot sites per year ----

pop_plot <- ggplot(number_of_sites, aes(x=year)) +
  geom_line(aes(y = HG_counts, colour = "Hunter-Gatherers")) +
  geom_line(aes(y = F_counts, colour="Farmers")) +
  geom_area(aes(y = HG_counts), fill = "red", alpha = 0.3) +
  geom_area(aes(y = F_counts), fill = "darkgreen", alpha = 0.3) +
  scale_colour_manual("", 
                      breaks = c("Hunter-Gatherers", "Farmers"),
                      values = c("red", "darkgreen")) +
  labs(x="Years BP", y="Number of Sites", title = "Number of Sites in Rabbithole")+
  scale_x_reverse() +
  theme_minimal()
  
pop_plot

## sites per year stats ----
min(sites$fitness)
max(sites$fitness)
median(sites$fitness)
mean(sites$fitness)

## lists of sites in year ----

for (i in 1:nrow(number_of_sites)) {
  sites_this_year <- data.frame(column1 = numeric(),
                                column2 = numeric(),
                                column3 = numeric(),
                                column4 = character(),
                                column5 = numeric(),
                                column6 = numeric(),
                                column7 = character(),
                                column8 = character(),
                                column9 = numeric(),
                                column10 = numeric(),
                                column11 = numeric(),
                                column12 = numeric(),
                                column13 = numeric()
  )
  #colnames(sites_this_year) <- c("Field1","sitename","lon","lat","dates","economy")

  for (j in 1:nrow(sites)) {
    if (sites$start_date_BC[j]>=number_of_sites$year[i] && sites$end_date_BC[j]<=number_of_sites$year[i])
      {
      nextsite <- sites[j,]
      sites_this_year <- rbind(sites_this_year, nextsite)
    }
  }
  
  ## add persistence data to annual sites dataset ----
  
  median_span_this_year <- median(sites_this_year$time_span)
  number_of_sites$median_span[i] <- median_span_this_year
  
  median_span_HG <- median(subset(sites_this_year,economy=="HG")$time_span)
  number_of_sites$median_span_HG[i] <- median_span_HG 
  
  median_span_F <- median(subset(sites_this_year,economy=="F")$time_span)
  number_of_sites$median_span_F[i] <- median_span_F 
    
  
  ## add fitness data to annual sites dataset ----
  
  median_fitness_this_year <- median(sites_this_year$fitness)
  number_of_sites$median_fitness[i] <- median_fitness_this_year
  
  median_fitness_HG <- median(subset(sites_this_year,economy=="HG")$fitness)
  number_of_sites$median_fitness_HG[i] <- median_fitness_HG 
  
  median_fitness_F <- median(subset(sites_this_year,economy=="F")$fitness)
  number_of_sites$median_fitness_F[i] <- median_fitness_F 
  
  ## geospatial operations ----
  data_sf <- st_as_sf(sites_this_year, coords = c("lon", "lat"))
  
  ## distances in grid units
  
  # dist_hg <- st_distance(data_sf[data_sf$economy == "HG",])
  # min_dist_hg <- min(dist_hg[dist_hg != 0])
  # number_of_sites$min_dist_HG_HG[i] <- min_dist_hg
  # 
  # dist_f <- st_distance(data_sf[data_sf$economy == "F",])
  # min_dist_f <- min(dist_f[dist_f != 0])
  # number_of_sites$min_dist_F_F[i] <- min_dist_f
  # 
  # dist_hg_f <- st_distance(data_sf[data_sf$economy == "F",], data_sf[data_sf$economy == "HG",])
  # min_dist_hg_f <- min(dist_hg_f[dist_hg_f != 0])
  # number_of_sites$min_dist_HG_F[i] <- min_dist_hg_f
  
  ## distances in km
  
  dist_hg <- (st_distance(data_sf[data_sf$economy == "HG",]))*111.5
  min_dist_hg <- min(dist_hg[dist_hg != 0])
  number_of_sites$min_dist_HG_HG[i] <- min_dist_hg
  
  dist_f <- (st_distance(data_sf[data_sf$economy == "F",]))*111.5
  min_dist_f <- min(dist_f[dist_f != 0])
  number_of_sites$min_dist_F_F[i] <- min_dist_f
  
  dist_hg_f <- (st_distance(data_sf[data_sf$economy == "F",], data_sf[data_sf$economy == "HG",]))*111.5
  min_dist_hg_f <- min(dist_hg_f[dist_hg_f != 0])
  number_of_sites$min_dist_HG_F[i] <- min_dist_hg_f
  
  
}

number_of_sites$min_dist_HG_HG <- replace(number_of_sites$min_dist_HG_HG, is.infinite(number_of_sites$min_dist_HG_HG), NA)
number_of_sites$min_dist_F_F <- replace(number_of_sites$min_dist_F_F, is.infinite(number_of_sites$min_dist_F_F), NA)
number_of_sites$min_dist_HG_F <- replace(number_of_sites$min_dist_HG_F, is.infinite(number_of_sites$min_dist_HG_F), NA)


## plot persistence per year ----

pers_plot <- ggplot(number_of_sites, aes(x=year)) +
  geom_line(aes(y = median_span_HG, colour = "Hunter-Gatherers")) +
  geom_line(aes(y = median_span_F, colour="Farmers")) +
  geom_area(aes(y = median_span_HG), fill = "red", alpha = 0.3) +
  geom_area(aes(y = median_span_F), fill = "darkgreen", alpha = 0.3) +
  scale_colour_manual("",
                      breaks = c("Hunter-Gatherers", "Farmers"),
                      values = c("red", "darkgreen")) +
  labs(x="Years BP", y="Median Site Persistence (y)", title = "Median Site Persistence over Time")+
  scale_x_reverse() +
  theme_minimal()


pers_plot 

## plot fitness per year ----

fit_plot <- ggplot(number_of_sites, aes(x=year)) +
  geom_line(aes(y = median_fitness_HG, colour = "Hunter-Gatherers")) +
  geom_line(aes(y = median_fitness_F, colour="Farmers")) +
  geom_area(aes(y = median_fitness_HG), fill = "red", alpha = 0.3) +
  geom_area(aes(y = median_fitness_F), fill = "darkgreen", alpha = 0.3) +
  scale_colour_manual("",
                      breaks = c("Hunter-Gatherers", "Farmers"),
                      values = c("red", "darkgreen")) +
  labs(x="Years BP", y="Fitness", title = "Median Site Environmental Fitness of site locations over Time")+
  scale_x_reverse() +
  theme_minimal()


fit_plot 

## plot min site distance per year ----


dist_plot <- ggplot(number_of_sites[number_of_sites$min_dist_F_F <= 55.525 || is.na(number_of_sites$min_dist_F_F),], aes(x=year)) +
  geom_line(aes(y = min_dist_HG_HG, colour = "Hunter-Gatherers")) +
  geom_line(aes(y = min_dist_F_F, colour="Farmers")) +
  geom_area(aes(y = min_dist_HG_HG), fill = "red", alpha = 0.3) +
  geom_area(aes(y = min_dist_F_F), fill = "darkgreen", alpha = 0.3) +
  scale_colour_manual("",
                      breaks = c("Hunter-Gatherers", "Farmers"),
                      values = c("red", "darkgreen")) +
  labs(x="Years BP", y="Site Distance", title = "Minimum Site Distance")+
  scale_x_reverse() +
  theme_minimal()


dist_plot 

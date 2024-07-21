library(tidyverse)
library(dplyr)

### import and transform netlogo output ###

all_sites <- list.files(pattern = "sites0902e\\w+.csv$", full.names = TRUE)
all_farmers <- list.files(pattern = "farmers0902e\\w+.csv$", full.names = TRUE)

##create list of shapefiles 
list_all_sites <- lapply(all_sites, read.csv, header = FALSE)
list_all_farmers <- lapply(all_farmers, read.csv, header = FALSE)

##add names to the shapefiles in the list to include only the period
names(list_all_sites) <- gsub(".csv", "", list.files(pattern = "sites0902e\\w+.csv$", full.names = F))
names(list_all_farmers) <- gsub(".csv", "", list.files(pattern = "farmers0902e\\w+.csv$", full.names = F))

list2env(list_all_sites, envir = .GlobalEnv)
list2env(list_all_farmers, envir = .GlobalEnv)

all0902e1 <- rbind(farmers0902e1, sites0902e1)
all0902e2 <- rbind(farmers0902e2, sites0902e2)
all0902e3 <- rbind(farmers0902e3, sites0902e3)

colnames(all0902e1) <- c("group","lon","lat","population","start","end")
colnames(all0902e2) <- c("group","lon","lat","population","start","end")
colnames(all0902e3) <- c("group","lon","lat","population","start","end")

all0902e1 <- all0902e1[all0902e1$group == "farmer", ]
all0902e2 <- all0902e2[all0902e2$group == "farmer", ]
all0902e3 <- all0902e3[all0902e3$group == "farmer", ]

all0902e1$square_string <- "A"
all0902e2$square_string <- "A"
all0902e3$square_string <- "A"

all0902e1$square_number <- "1"
all0902e2$square_number <- "1"
all0902e3$square_number <- "1"

all0902e1$square<- "0"
all0902e2$square <- "0"
all0902e3$square <- "0"

list_all <- list(all0902e1, all0902e2, all0902e3)

names(list_all) <- c("all0902e1", "all0902e2", "all0902e3")


# netlogo_all_sites <- read.csv("sites.csv", header = FALSE)
# netlogo_farmer_sites <- read.csv("DATA/farmers.csv", header = FALSE)
# netlogo_all_abandoned_farmer_sites <- netlogo_all_sites[netlogo_all_sites$hunter == "0" | netlogo_all_sites$hunter == "farmer" ,]

# netlogo_farmer_sites <- rbind(netlogo_all_abandoned_farmer_sites,netlogo_farmer_sites)


# colnames(netlogo_farmer_sites) <- c("group","lon","lat","population","start","end")
# plot(all0902e1[,2:3])

x = 1
for (item in list_all) {
  nm <- names(list_all[x])
  item[,2] <- (5/((5/item[,2])*51.12))-4
  item[,3] <- (5/((5/item[,3])*51.12))-1
  item[,5] <- 7600-(item[,5]/12)
  item[,6] <- 7600-(item[,6]/12)
  
  for (i in 1:nrow(item)) {
    if (item[,3][i] > 3 && item[,3][i] < 3.5) {
      item[,7][i] <- "B"
    }
    if (item[,3][i] > 2.5 && item[,3][i] < 3) {
      item[,7][i] <- "C"
    }
    if (item[,3][i] > 2 && item[,3][i] < 2.5) {
      item[,7][i] <- "D"
    }
    if (item[,3][i] > 1.5 && item[,3][i] < 2) {
      item[,7][i] <- "E"
    }
    if (item[,3][i] > 1 && item[,3][i] < 1.5) {
      item[,7][i] <- "F"
    }
    if (item[,3][i] > 0.5 && item[,3][i] < 1) {
      item[,7][i] <- "G"
    }
    if (item[,3][i] > 0 && item[,3][i] < 0.5) {
      item[,7][i] <- "H"
    }
    if (item[,3][i] > -0.5 && item[,3][i] < 0) {
      item[,7][i] <- "I"
    }
    if (item[,3][i] > -1 && item[,3][i] < -0.5) {
      item[,7][i] <- "J"
    }

    if (item[,2][i] > -3.5 && item[,2][i] < -3) {
      item[,8][i] <- "2"
    }
    
    if (item[,2][i] > -3 && item[,2][i] < -2.5) {
      item[,8][i] <- "3"
    }
    
    if (item[,2][i] > -2.5 && item[,2][i] < -2) {
      item[,8][i] <- "4"
    }
    
    if (item[,2][i] > -2 && item[,2][i] < -1.5) {
      item[,8][i] <- "5"
    }
    if (item[,2][i] > -1.5 && item[,2][i] < -1) {
      item[,8][i] <- "6"
    }
    
    if (item[,2][i] > -1 && item[,2][i] < -0.5) {
      item[,8][i] <- "7"
    }
    if (item[,2][i] > -0.5 && item[,2][i] < 0) {
      item[,8][i] <- "8"
    }
    
    if (item[,2][i] > 0 && item[,2][i] < 0.5) {
      item[,8][i] <- "9"
    }
    
    if (item[,2][i] > 0.5 && item[,2][i] < 1) {
      item[,8][i] <- "10"
    }
    
    item[,9][i] <- paste0(item[,7][i], item[,8][i])
    
  }
  
  mn <- item %>% 
    group_by(item[,9]) %>% 
    mutate(mean_start = mean(start),
              .groups = 'drop')
  
  write.csv(mn, paste0("mean_squares", nm, ".csv"), row.names =  F)
  write.csv(item, paste0("farmers_", nm, ".csv"), row.names =  F)

  x = x + 1
}






# netlogo_farmer_sites$lon <- (5/((5/netlogo_farmer_sites$lon)*51.12))-4
# netlogo_farmer_sites$lat <- (5/((5/netlogo_farmer_sites$lat)*51.12))-1
# netlogo_farmer_sites$start <- 7600-(netlogo_farmer_sites$start/12) 
# netlogo_farmer_sites$end <- 7600-(netlogo_farmer_sites$end/12)

# write.csv(netlogo_farmer_sites, "DATA/netlogo_farmer_sites.csv")


### assign squares ----

# netlogo_farmer_sites$square_string <- "A"
# netlogo_farmer_sites$square_number <- "1"
# 
# for (i in 1:nrow(netlogo_farmer_sites)) {
#   
#   if (netlogo_farmer_sites$lat[i] > 3 && netlogo_farmer_sites$lat[i] < 3.5) {
#     netlogo_farmer_sites$square_string[i] <- "B"
#   }
#   
#   if (netlogo_farmer_sites$lat[i] > 2.5 && netlogo_farmer_sites$lat[i] < 3) {
#     netlogo_farmer_sites$square_string[i] <- "C"
#   }
#   
#   if (netlogo_farmer_sites$lat[i] > 2 && netlogo_farmer_sites$lat[i] < 2.5) {
#     netlogo_farmer_sites$square_string[i] <- "D"
#   }
#   
#   if (netlogo_farmer_sites$lat[i] > 1.5 && netlogo_farmer_sites$lat[i] < 2) {
#     netlogo_farmer_sites$square_string[i] <- "E"
#   }
#   
#   if (netlogo_farmer_sites$lat[i] > 1 && netlogo_farmer_sites$lat[i] < 1.5) {
#     netlogo_farmer_sites$square_string[i] <- "F"
#   }
#   
#   if (netlogo_farmer_sites$lat[i] > 0.5 && netlogo_farmer_sites$lat[i] < 1) {
#     netlogo_farmer_sites$square_string[i] <- "G"
#   }
#   
#   if (netlogo_farmer_sites$lat[i] > 0 && netlogo_farmer_sites$lat[i] < 0.5) {
#     netlogo_farmer_sites$square_string[i] <- "H"
#   }
#   
#   if (netlogo_farmer_sites$lat[i] > -0.5 && netlogo_farmer_sites$lat[i] < 0) {
#     netlogo_farmer_sites$square_string[i] <- "I"
#   }
#   
#   if (netlogo_farmer_sites$lat[i] > -1 && netlogo_farmer_sites$lat[i] < -0.5) {
#     netlogo_farmer_sites$square_string[i] <- "J"
#   }
#   
#   
#   
#   
#   if (netlogo_farmer_sites$lon[i] > -3.5 && netlogo_farmer_sites$lon[i] < -3) {
#     netlogo_farmer_sites$square_number[i] <- "2"
#   }
#   
#   if (netlogo_farmer_sites$lon[i] > -3 && netlogo_farmer_sites$lon[i] < -2.5) {
#     netlogo_farmer_sites$square_number[i] <- "3"
#   }
#   
#   if (netlogo_farmer_sites$lon[i] > -2.5 && netlogo_farmer_sites$lon[i] < -2) {
#     netlogo_farmer_sites$square_number[i] <- "4"
#   }
#   
#   if (netlogo_farmer_sites$lon[i] > -2 && netlogo_farmer_sites$lon[i] < -1.5) {
#     netlogo_farmer_sites$square_number[i] <- "5"
#   }
#   if (netlogo_farmer_sites$lon[i] > -1.5 && netlogo_farmer_sites$lon[i] < -1) {
#     netlogo_farmer_sites$square_number[i] <- "6"
#   }
#   
#   if (netlogo_farmer_sites$lon[i] > -1 && netlogo_farmer_sites$lon[i] < -0.5) {
#     netlogo_farmer_sites$square_number[i] <- "7"
#   }
#   if (netlogo_farmer_sites$lon[i] > -0.5 && netlogo_farmer_sites$lon[i] < 0) {
#     netlogo_farmer_sites$square_number[i] <- "8"
#   }
#   
#   if (netlogo_farmer_sites$lon[i] > 0 && netlogo_farmer_sites$lon[i] < 0.5) {
#     netlogo_farmer_sites$square_number[i] <- "9"
#   }
#   
#   if (netlogo_farmer_sites$lon[i] > 0.5 && netlogo_farmer_sites$lon[i] < 1) {
#     netlogo_farmer_sites$square_number[i] <- "10"
#   }
#   
#   netlogo_farmer_sites$square[i] <- paste0(netlogo_farmer_sites$square_string[i], netlogo_farmer_sites$square_number[i])
#   
# }
# 
# 
# squarelist <- unique(netlogo_farmer_sites$square)
# 
# ### calculate loewest start date for each square
# 
# squares_starts <- aggregate(netlogo_farmer_sites[2:6], by=list(netlogo_farmer_sites$square), FUN=max)
# 
# # Rename the columns in the result dataframe
# colnames(squares_starts) <- c("square", "lon","lat","population","start","end")
# 
# 
# write.csv(squares_starts, "DATA/netlogo_oldest_farmer_sites.csv")
















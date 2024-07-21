library(raster)
library(terra)
library(leastcostpath)
library(sf)
library(dplyr)                                    
library(plyr)                                     
library(readr) 

# merge initial tiles and new tiles
notlogical <- cols(economy = col_character())
data_all <- list.files(pattern = "*.csv$", full.names = TRUE) %>% 
  lapply(read_csv, col_types = notlogical) %>%                             
  bind_rows %>% 
  rename_with(.cols = 1, ~ "id") %>% 
  mutate(id = seq(1, nrow(data_all), by = 1)) #%>% 
  write.csv("Biblio_all_tiles.csv")


# calculate distances between sites ----
data_all <- st_as_sf(read.csv("Biblio_all_tiles.csv"), coords = c("lon", "lat"))

dist_all <- st_distance(data_sf)
min_dist_all <- min(dist_all[dist_all != 0])

dist_hg <- st_distance(data_sf[data_sf$economy == "HG",])
min_dist_hg <- min(dist_hg[dist_hg != 0])

dist_f <- st_distance(data_sf[data_sf$economy == "F",])
min_dist_f <- min(dist_f[dist_f != 0])

dist_hg_f <- st_distance(data_sf[data_sf$economy == "F",], data_sf[data_sf$economy == "HG",])
min_dist_hg_f <- min(dist_hg_f[dist_hg_f != 0])

# convert csv to shp for Netlogo input
data_all <- st_as_sf(st_read("allsites_output_calib.csv"), coords = c("lon", "lat")) %>% 
  select(-c(1, 2, 3)) %>% 
  st_write("Biblio_all_tiles.shp", append = F)

# load raster
resources <- raster("./ABM_neolithic_spread/code/resources.asc")

#plot raster
plot(resources)

# reclassify raster values ----
## get the values of all cells
values <- getValues(resources)

## histogram of values
hist(values)
min(values, na.rm = T)

## round values
rounded <- round(resources, digits = 3)
values_round <- getValues(rounded)
hist(values[values < 0.05])

## reclassify values
m <- c(0.000, 0.001, 1,   0.001, 0.002,2,  0.002, 0.004, 3,  0.004, 0.006, 4,  0.006, 0.008, 5,  0.008, 0.01, 6,  0.01, 0.02, 7, 
       0.02, 0.05, 8,  0.05, 0.1, 9,  0.1, 0.2, 10,  0.2, 0.55, 11)
rclmat <- matrix(m, ncol = 3, byrow = TRUE)
rc <- reclassify(resources, rclmat)
values_rc <- getValues(rc)
hist(values_rc)

## write raster to ASCII file
writeRaster(rc, "resources_reclass.asc")

# changing values of sea patches ----
resources <- raster("./ABM_neolithic_spread/code/resources_reclass.asc")
sea <- st_read("sea.shp")

r <- rasterize(sea, resources, field = 9999, update = F)

plot(r)

# LCP ----
narnia <- raster("east_narnia4x.tif")
narnia[narnia$lyr.1 < 0] <- NA

slope_cs <- create_slope_cs(narnia, cost_function = "tobler", neighbours = 4)

locs <- as_Spatial(st_read("./ABM_neolithic_spread//code/Biblio_data_XYTableToPoint.shp"))

lcps <- create_FETE_lcps(slope_cs, locations = locs, cost_distance = T)

lcps_rast <- create_lcp_density(resources, lcps = lcps, rescale = F)

plot(lcps_rast)
points(locs)



  

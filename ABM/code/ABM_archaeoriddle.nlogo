extensions [
  gis
  csv
]

breed [site-agents site-agent]
breed [start-points-hg start-point-hg]
breed [start-points-f start-point-f]
breed [farmer-sites farmer-site]
breed [hunter-sites hunter-site]
breed [farmer-settlers farmer-settler]

site-agents-own [
  site-information ;; GIS data attributes
  start-date       ;; start of occupation (years BC)
  end-date         ;; end of occupation (years BC)
  economy          ;; economy of site, either hunter or farmer
]

farmer-sites-own [
  population       ;; population of the site
  known-patches    ;; patches visited by the farmer settler, i.e. known to the community
  funded           ;; founding date of the site (ticks)
  abandoned        ;; data of abandonment (ticks)
  group            ;; economy of site (farmer or hunter, only necessary to write the respective field to csv)
]

hunter-sites-own [
  population       ;; population of the site
  funded           ;; founding date of the site (ticks)
  abandoned        ;; data of abandonment (ticks)
  farmer-arrival   ;; time when a farmer site first showed up in the vicinity of the site (ticks)
  group            ;; economy of site (farmer or hunter, only necessary to write the respective field to csv)
  last-move        ;; time when the site last moved (ticks)
]

farmer-settlers-own [
  home-site        ;; farmer-site the farmer belongs to
  visited-patches  ;; patches visited, reported to home-site and stored there as known-patches
  sailor           ;; if farmer-settler is at the coast, he beomes a sailor and his behaviour changes
  landing-place    ;; first coast patch the farmer-settler arrives at
  my-region        ;; region of the home-site in which the farmer-settler can move
  time-here        ;; time since the farmer arrived in the current coastal area
]

patches-own [
  fertility        ;; probability of hunters and farmers settling here
  patchtype        ;; can be suitable or unsuitable
  elevation        ;; elevation of patch
  occupied-hg      ;; occupied by hunter
  occupied-f       ;; occupied by farmer
  landform         ;; can be either sea, land or coast
  near-patches     ;; patches in the vicinity of the site
  region           ;; number of region = site id
  allowed          ;; region in which farmer-settlers are allowed to move
  region-patches   ;; patches that the farmer-settler can explore
  blocked          ;; for hunter-sites: when moving, previous visited patches are blocked for a certain time
  continent        ;; the area in which hunters can move (i.e. north and east of the sea)
  coast            ;; land patches adjacent to sea patches
]

globals [
  suitable         ;; patches with fertility not NaN
  landmap          ;; name of raster file of land for spreading (in ESRI ASCII format)
  sitesfile        ;; name of vector points file of sites (in ESRI shapefile format)
  basemap          ;; GIS base map for setting up world
  patch-size-km    ;; size of patches in real-earth units
  sites            ;; GIS sites map
  sitefields       ;; Names of data fields in sites attribute database
  filebase         ;; spread type for base output file name
  startlist-f      ;; list of xy pairs for starting farmer patches
  startlist-hg     ;; list of xy pairs for starting  patches
  use-sites        ;; records information for sites loaded from GIS vector points file
  resourcemap      ;; GIS base map for setting up resources
  remap            ;; name of raster file of resources (in ESRI ASCII format)
  sea              ;; water patches
  maxelevation     ;; maximum elevation value
  minelevation     ;; minimum elevation value
  maxindex         ;; maximum value of fertility
  minindex         ;; minimum value of fertility
  next-update      ;; tick of next growth phase
  list-sites       ;; list of sites that have been founded and abandoned
  contmap          ;; GIS base map for defining the extent of the area where hunters can move
  continentmap     ;; name of raster file of continent (ESRI ASCII format)
  next-move        ;; for hunter-sites: tick of next move
  real-time        ;; tick number converted in years BC
  next-hunter      ;; tick when next hunter-site is initiated (only in the beginning of the simulation)
]

to setup[filename]
  clear-all
  reset-ticks
  ;; convert ticks into years BC, i.e. the simulation starts 7600 BC
  set real-time 7600
  ;; create empty list for farmer-sites startpoints
  set startlist-f [ ]
  ;; create empty list for hunter-sites startpoints
  set startlist-hg [ ]
  ;; set site information to 0 because no information has been loaded yet
  set use-sites 0
  ;; create an empty list of sites that will be exported to csv in the end
  set list-sites []
  ;; if next-update is set to 0, the condition will be met at the first tick, so we use "none" here to initiate the procedure later
  set next-update "none"
  ;; set next-hunter to 0 as start value
  set next-hunter 0
  setup-world
  ;; unblock all patches from the beginning so they can be used for hunters as new site patch
  ask patches [set blocked "none"]
  ;; initate the moving procedure for hunters
  ask hunter-sites [set last-move 0]
end

to setup-world
  ;; define the ASCII files that serve as the environment for the simulation
  set landmap "east_narnia.asc"
  set remap "resources.asc"
  set contmap "continent.asc"

  ;; set the NetLogo world dimension to 0
  let world-wd 0
  let world-ht 0

  ;; load the raster maps
  set resourcemap gis:load-dataset remap
  set basemap gis:load-dataset landmap
  set continentmap gis:load-dataset contmap

  ;; define the dimension of the NetLogo world according to the GIS raster base map
  let gis-wd gis:width-of basemap
  let gis-ht gis:height-of basemap
  ifelse gis-wd >= gis-ht
    [set world-wd world-max-dim
      set world-ht int (gis-ht * world-wd / gis-wd)]
  [set world-ht world-max-dim
    set world-wd int (gis-wd * world-ht / gis-ht)]
  resize-world 0 world-wd 0 world-ht
  gis:set-world-envelope (gis:envelope-of basemap)

  ;; import the values of the raster files (i.e. elevation, fertility and continent)
  gis:apply-raster resourcemap fertility
  gis:apply-raster basemap elevation
  gis:apply-raster continentmap continent

  ;; identify the ranges for elevation and fertility
  set maxelevation max [elevation] of patches
  set minelevation min [elevation] of patches
  set maxindex max [fertility] of patches
  set minindex min [fertility] of patches

  ;; set the variables of the patches
  ask patches [
    ;; none of the patches is occupied yet
    set occupied-hg "no"
    set occupied-f "no"
    ;; no region defined for patches yet
    set region []
    set allowed []
    ;; if the elevation is smaller than 0, it is a water patch, otherwise it is a land patch
    ifelse elevation < 0 [set landform "sea"] [set landform "land"]
    ;; if fertility is not NaN, the patch is suitable, otherwise it is unsuitable (for a more detailed explanation of NaN and how to handle it see the NetLogo manual)
    ifelse (fertility <= 0) or (fertility >= 0) [set patchtype "suitable"][set patchtype "unsuitable"]
    ;; set the landform of unsuitable patches
    if patchtype = "unsuitable" and [landform] of neighbors = "land" [
      set landform "land"
    ]
    if patchtype = "unsuitable" and [landform] of one-of neighbors = "sea" [
      set landform "sea"
    ]
  ]

  ;; define coast patches: patches that are land and have neighbours that are sea patches; set their colour to turquoise
  ask patches [
    ifelse any? neighbors with [landform = "sea"] and [landform] of self = "land" [set coast "yes" set pcolor 83] [set coast "no"]
  ]

  ;; determine size of patches in real-world units
  if GIS-grid-cell-km = "" or GIS-grid-cell-km <= 0.02 [set GIS-grid-cell-km 0.02] ;; if not specified, default to 1km raster grid cells
  set patch-size-km (gis-wd * GIS-grid-cell-km) / world-wd
  output-print "patch size = " output-type patch-size-km output-print " km in geographic units"

  ;; set the colour of sea patches to blue
  ask patches with [landform = "sea"] [set pcolor 102]

  ;; create an agentset of suitable patches
  set suitable patches with [patchtype = "suitable"]
  ;; colour the world if the switch is set to "on"
  if color-world [ ask suitable [set-shading] ]
end

to set-shading
  ;; this bombs regularly due to a bug in NetLogo AFAICT. If it happens, try again until it works
  carefully [
    ;; colour the patches according to elevation
    ; set pcolor scale-color 31 elevation maxelevation minelevation] [ ;; scale color of suitable from dark (highest elevation) to light
    ;; OR colour the patches according to fertility
    set pcolor scale-color 31 fertility maxindex minindex] [ ;; scale color of suitable from dark (most suitable) to light
    ;; if the shading doesn't work, this message shows
    user-message "You need to run setup again"
    stop
  ]
end

to load-sites[filename]
  ;; load GIS vector file of sites and create turtles (site-agents) for each site
  ;; remove previously loaded site data
  ask site-agents [die]

  ifelse empty? filename [
    ;; loads GIS sites file interactively
    user-message "Please select shapefile of sites (*.shp)"
    set sitesfile user-file ] [
    ;; lets sites file be loaded from behavior space or command line
    set sitesfile filename
  ]

  ;; import sites file
  set sites gis:load-dataset sitesfile
  ;; add the attributes of the sites to sitefields
  set sitefields gis:property-names sites
  ;; add the sites to a list
  let feature-list gis:feature-list-of sites

  foreach feature-list [ ?1 ->
    ;; create a site-agent turtle for each GIS vector site
    let sitepoint gis:centroid-of ?1
    ;; create an empty list
    let prop-list []
    ;; define the current site
    let this-feature ?1
    ;; iterate through all of the data that corresponsds to each site and make a list that will be handed off to agents
    foreach sitefields [ ??1 ->
      let prop-field gis:property-value this-feature ??1
      set prop-list lput prop-field prop-list
    ]

    ;; define the location of the sites
    let location gis:location-of sitepoint
    ;; if the location is empty, do nothing (can be adjusted if needed), otherwise create site-agents
    ifelse empty? location [
    ][
      ;; initialize an agent to represent a site in the simulation
      create-site-agents 1 [
        ;; define how the hunter-sites should look
        ifelse gis:property-value this-feature "economy" = "HG" [
          ;; place it at the location of the current site
          setxy item 0 location item 1 location
          ;; add start date as variable
          set start-date gis:property-value this-feature "start_date"
          set start-date runresult start-date
          ;; add end date as variable
          set end-date gis:property-value this-feature "end_date"
          set end-date runresult end-date
          ;; add economy as variable
          set economy gis:property-value this-feature "economy"
          ;; check to make sure the site is not located in the ocean, useful for sites on the coastline
          if [pcolor] of patch-here = blue
          [ print "ERROR Site Located in Water"
            print prop-list
            set color red]
          ;; define shape
          set shape "triangle"
          ;; defien colour
          set color 15
          ;; define size
          set size 8
          ;; set the start date as label and define lable colour
          set label start-date
          set label-color black
          ;; hide the site, i.e. make it invisible
          set hidden? not hidden?
        ][
          ;; define how the farmer sites should look
          ;; place it at the location of the current site
          setxy item 0 location item 1 location
          ;; add start date as variable
          set start-date gis:property-value this-feature "start_date"
          set start-date runresult start-date
          ;; add end date as variable
          set end-date gis:property-value this-feature "end_date"
          set end-date runresult end-date
          ;; add economy as variable
          set economy gis:property-value this-feature "economy"
          ;; check to make sure the site is not located in the ocean, useful for sites on the coastline
          if [pcolor] of patch-here = blue
          [ print "ERROR Site Located in Water"
            print prop-list
            set color red]
          ;; define shape
          set shape "triangle"
          ;; defien colour
          set color 65
          ;; define size
          set size 8
          ;; set the start date as label and define lable colour
          set label start-date
          set label-color black
          ;; hide the site, i.e. make it invisible
          set hidden? not hidden?
        ]
      ]
    ]
  ]
  ;; sites are loaded so output can be saved
  set use-sites 1
end

to setup-startpoints-f
  ;; set start points for farmers from list of xy coordinate pairs
  let startx 0
  let starty 0

  ;; iterate through each xy coordinate pair in the list of starting points
  foreach startlist-f [ ?1 ->
    ;; if the coordinates are within the scope of the NetLogo world
    if (abs item 0 ?1 < max-pxcor and abs item 1 ?1 < max-pycor )  [
      ;; create a farmer-site
      ask patch (item 0 ?1) (item 1 ?1) [
        set startx pxcor
        set starty pycor
        new-farmer
      ]
    ]

    ;; create a turtle to mark start point of the farming community - optional
    create-start-points-f 1 [
      set color black
      set size 1
      set shape "x"
      setxy startx starty
    ]
  ]
end

to mouse-set-start-f
  ;; create a list of xy pairs for starting point for agriculture spread by clicking with a mouse
  ;; user needs to click inside the world for anything to happen
  if (mouse-down? and abs mouse-xcor < max-pxcor and abs mouse-ycor < max-pycor ) [
    let start-pointsf (list mouse-xcor mouse-ycor)
    set startlist-f lput start-pointsf startlist-f
    setup-startpoints-f
    stop
  ]
end

to setup-startpoints-hg
  ;; set start points for hunters from list of xy coordinate pairs
  ;; same procedure as for farmers except that hunters don't have settlers
  let startx 0
  let starty 0

  foreach startlist-hg [ ?1 -> ;; iterate through each xy coordinate pair in the list of starting points
    if (abs item 0 ?1 < max-pxcor and abs item 1 ?1 < max-pycor )  [
      ask patch (item 0 ?1) (item 1 ?1) [ ;; set start point for diffusion
        set startx pxcor
        set starty pycor
        new-hunter
      ]
    ]

    create-start-points-f 1 [  ;; create a turtle to mark start point for diffusion
      set color black
      set size 1
      set shape "x"
      setxy startx starty
    ]
  ]
end

to mouse-set-start-hg
  ;; create a list of xy pairs for starting point for agriculture spread by clicking with a mouse
  ;; user needs to click inside the world for anything to happen

  if (mouse-down? and abs mouse-xcor < max-pxcor and abs mouse-ycor < max-pycor ) [
    let startpoints (list mouse-xcor mouse-ycor)
    set startlist-hg lput startpoints startlist-hg
    setup-startpoints-hg
    stop
  ]
end

to go
  show-sites
  initiate-hunter

  ;; if a certain time has passed (equivalent to the assumed first appearance of farmers), create the first farmer site
  ;; can be replaced by using the mouse to manually create sites
  if ticks = 1200 [
    ask patch 122 1 [
      new-farmer
    ]
  ]

  ;; update the abandon variable for all sites. If the sites dissappear in this time step, this information will be stored here
  ask hunter-sites [
    set abandoned ticks
  ]

  ask farmer-sites [
    set abandoned ticks
  ]


  ;; hunter sites can only use patches to settle that they haven't settled on recently.
  ;; The blocked variable of a patch is activated as soon as a site arrives and stays active for a certain amount of time (time-blocked)
  ask patches [
    if blocked != "none" [
      set blocked blocked + 1
      if ticks - blocked = time-blocked [
        set occupied-hg "no"
        set near-patches 0
        set blocked "none"
      ]
    ]
  ]

  grow
  move-farmer
  move-hunter-sites
  split-hunter

  ;; cultural diffusion means that hunters become farmers if there are farmers in their vicinity dor a specified time
  if interaction-type = "cultural diffusion" [
    settle-farmer
    cultural
  ]

  ;; demic diffusion means that hunters and farmers have a hostile relationship
  if interaction-type = "demic diffusion" [demic]

  ;;create a new agentset that includes all sites
  let sites-all (turtle-set farmer-sites hunter-sites)

  ask sites-all [
    ;; if the site existed for 600 ticks (i.e. 50 years), it will be abandoned wtih a certain probality
    ;; the probabilty is influenced by the fertility of the patch
    ;; i.e. the lower the fertility, the higher the probability of abandonment
    if (ticks - funded) >= 600 [
      (ifelse
        ;; if the fertility is less than 0.05, the site is abandoned with a probability of 0.04%
        [fertility] of patch-here < 0.05 and random-float 1 < 0.0004 [
          ;; store the site information in a list
          set list-sites lput (list group xcor ycor population funded abandoned) list-sites
          die-farmer
          die-hunter
        ]
        ;; if the fertility is higher than 0.05, the site is abandoned with a probability of 0.02%
        [fertility] of patch-here > 0.05 and [fertility] of patch-here < 0.1 and random-float 1 < 0.0002 [
          set list-sites lput (list group xcor ycor population funded abandoned) list-sites
          die-farmer
          die-hunter
        ]
        ;; if the fertility is higher than 0.05, the site is abandoned with a probability of 0.0013%
        [fertility] of patch-here > 0.10 and random-float 1 < 0.000013 [
          set list-sites lput (list group xcor ycor population funded abandoned) list-sites
          die-farmer
          die-hunter
      ])
    ]
  ]

  ;; stop the simulation after 12000 ticks, i.e. when the last farmer sites have appeared
  ;; and save the site-information to files
  if ticks = 12000 [
    save-files
    stop
  ]

  tick
end

to die-farmer
  ;; if a farmer-site dies, the patches around it are reset and the settler of the site dies as well
  ask near-patches [
    set occupied-f "no"
  ]
  ask patch-here [
    set near-patches 0
    set occupied-f "no"
  ]
  ask farmer-settlers with [home-site = [who] of myself][die]
  die
end

to settle-farmer
  ;; procedure for founding new farmer sites
  ask farmer-sites [
    ;; if the population of a farmer site reaches its limits, a new site is founded
    if population > number-farmer-split [
      ;; check the patches that have been explored by the settler
      let available-patches patch-set known-patches
      ;; find the patches with the best fertility that is not occupied, is on land and is within a certain distance to other sites
      let settler-patches available-patches with [
        occupied-f = "no"
        and landform = "land"
        and pcolor != black
        and not any? farmer-sites in-radius 10
        and not any? hunter-sites in-radius 10
      ]

      ;; choose the patch with the highest fertility and create a new site
      if max-one-of settler-patches [fertility] != nobody [
        ask max-one-of settler-patches [fertility] [
          new-farmer
        ]
      ]

      ;; adjust the population of the parent site by removing those that have left for the new site
      set population population - number-farmer
    ]
  ]
end

to new-farmer
  ;; define variables of the patch
  set occupied-f "yes"
  ;; create a site and define its variables
  sprout-farmer-sites 1 [
    set size 5
    set shape "house"
    set color 65
    set population number-farmer
    set funded ticks
    set group "farmer"
  ]
  ;; define the region of the patch as the id of the site. This is used to determine which area the farmers can use to explore
  set region [who] of farmer-sites-here
  ;; define the patches around the site that are used by it for e.g. agriculture
  set near-patches patches in-radius 15
  ask near-patches [
    set occupied-f "yes"
  ]

  ;; define the region of the site, i.e. the area that can be explored
  set region-patches patches in-radius 25
  set-region

  ;; create one settler that belongs to the site
  sprout-farmer-settlers 1 [
    set shape "person"
    set color 65
    set size 4
    ;; define the home-site, i.e. the site to which the settler belongs
    set home-site first [who] of farmer-sites-here
    ;; create a list in which the patches are stored that the settler has explored
    set visited-patches []
    ;; settler can travel over sea once they reach the coast
    set sailor "no"
    set landing-place []
    ;; align the region of the settler with the one of the site
    set my-region first [region] of myself
    ;; time-here is used for seafaring and needs to be set to a values that is not a positive number
    set time-here -1
    ;; make the settler invisible - optional
    set hidden? not hidden?
  ]
end

to report-patches
  ;; the settler reports the patches he explores back to his home site where they are stored in a variable
  ;; add current patch to list
  set visited-patches fput patch-here visited-patches
  ;; find the home site
  let site-to-contact home-site
  ;; add the patch to the list of hte home site
  ask farmer-sites with [who = site-to-contact]
  [set known-patches [visited-patches] of myself]
end

to set-region
  ;; procedure to define the region for farmer sites and settlers
  ask region-patches [
    set region fput [region] of myself region
    set allowed lput first region allowed
  ]
end

to move-farmer
  ;; procedure to let farmer settlers explore
  ask farmer-settlers [
    ;; check the eleavation of the current patch
    let elev [elevation] of patch-here
    ;; if the settler can't move over sea
    ifelse sailor = "no" [
      ;; in case the settler is not able to move over sea:
      ;; find a neighbouring patch with a not too high elevation
      ;; note that a leap-frog of 3 is included here which can be adjusted
      let good-spots patches in-radius 3 with [(elevation - elev) < maxslope]
      ;; move to one of those patches
      move-to one-of good-spots with [member? [my-region] of myself allowed]
      report-patches
      ;; if the settler reaches the coast, he can start moving over sea
      if [landform] of patch-here = "coast" [
        ;; change to sailor
        set sailor "yes"
        ;; define the current patch as the base for seafaring
        set landing-place fput patch-here landing-place
      ]
    ][
      ;; if the settler can move over sea:
      (ifelse
        ;; if he is on hios landing place choose one of the coast patches in a 25km radius and go there
        patch-here = first landing-place [
          let good-spots patches in-radius 50 with [coast = "yes"]
          move-to one-of good-spots
          ;; the time-here variables tracks the time the settler explores the area to avoid him going too far inland
          ;; and give him the opportunity to explore other coastal areas
          set time-here 0
          report-patches
          ;; explored patches are added to the region of the home site
          ask patch-here [
            set region [region] of myself
            set region-patches patches in-radius 10
            set-region
          ]
        ]

        ;; if the settler is in a new coastal area, he explroes it for a while and reports the patches to his home site
        patch-here != first landing-place and [coast] of patch-here = "yes" [
          ;; find the neighbouring land patches with a suitable elevation that belong to the region of the settler and hence can be explored and move to one of them
          let good-spots patches in-radius 3 with [(elevation - elev) < maxslope  and coast = "no" and landform = "land" and member? [my-region] of myself allowed]
          let good-spot one-of good-spots
          ;; if there are auitbale patches, explore and report them
          ifelse good-spot != nobody [
            move-to good-spot
            report-patches
            ;; update time counter
            set time-here time-here + 1
          ][
            ;; if there is no suitable patch available, return to the landing patch
            move-to first landing-place
            set time-here time-here + 1
          ]
        ]

        [coast] of patch-here = "no" [
          ;; if the settler is here for less than a year, he keeps exploring, otherwise he returns to his landing place
          ifelse time-here != 12 [
            let good-spots patches in-radius 3 with [(elevation - elev) < maxslope and landform = "land"]
            move-to one-of good-spots with [member? [my-region] of myself allowed]
            report-patches
            set time-here time-here + 1
          ][
            move-to first landing-place
            set time-here -1
          ]
      ])
    ]
  ]
end

to grow
  ;; procedure for population growth
  ;; every year, the population experiences a new growth push
  if ticks = 11 or ticks = next-update [
    ;; converting ticks into real time, i.e. real time runs backwards (BC) while ticks run forward
    set real-time real-time - 1
    ;; growth push for hunter sites
    ask hunter-sites [
      ;; if the population of a site has not yet reached its limmits (25% more than the threshold for splitting),
      ;; it grows according to the growth rate
      if population <= (number-hunter-split + number-hunter-split * 0.25) [
        let pop-grow (growth-rate-hunter / 100) * population
        set population population + (precision pop-grow 5)
        set population precision population 5
      ]
    ]
    ask farmer-sites [
      ;; if the population of a site has not yet reached its limmits (25% more than the threshold for splitting),
      ;; it grows according to the growth rate
      if population <= (number-farmer-split + number-farmer-split * 0.25) [
        let pop-grow (growth-rate-farmer / 100) * population
        set population population + (precision pop-grow 3)
        set population precision population 3
      ]
    ]
    ;; update the point for the next growth push, i.e. in a year
    set next-update ticks + 12
  ]
end

to move-hunter-sites
  ;; procedure to let hunters move as they are a mobile community
  ask hunter-sites [
    ;; hunter sites move in certain intervals, here every 10 years
    if ticks - last-move = 120 [
      ;; find suitable patches to move to
      let settler-patches patches in-radius 15 with [
        occupied-hg = "no"
        and landform = "land"
        and continent = 1
        and not any? farmer-sites in-radius 5
        and not any? other hunter-sites in-radius 5
      ]

      ;; if there is a suitable patch available, move to the one with the highest fertility
      ifelse max-one-of settler-patches [fertility] != nobody [
        move-to max-one-of settler-patches [fertility]
        set near-patches patches in-radius 5
        ask near-patches [
          set occupied-hg "yes"
        ]
      ][
        ;; if there is no suitable patch available, blocked patches can be used as well
        ;; this avoids hunter sites to be trapped in the corners of the world in coastal areas
        ;; iniitally, they try to not use the same patches again for a while but can go there if there is no other option
        let settler-alt-patches patches in-radius 15 with [
          landform = "land"
          and continent = 1
          and not any? farmer-sites in-radius 5
          and not any? other hunter-sites in-radius 5
        ]
        move-to one-of settler-alt-patches
        set near-patches patches in-radius 5
        ask near-patches [
          set occupied-hg "yes"
        ]
      ]
      ;; update the time for the next move
      set last-move ticks
    ]
  ]
end

to die-hunter
  ;; if a hunter-site dies, the patches around it are reset
  ask near-patches [
    set occupied-hg "no"
  ]
  ask patch-here [
    set near-patches 0
    set occupied-hg "no"
  ]
  die
end

to initiate-hunter
  ;; procedure to set up initial hunter sites
  ;; 30 sites are founded in regular intervals, always 2 at the same time
  if ticks = next-hunter and next-hunter <= 675 [
    ask n-of 2 (patches with [
      continent = 1
      and pycor <= 200
    ]) [
      new-hunter
    ]
    set next-hunter ticks + 45
  ]
end

to new-hunter
  ;; procedure to create new hunter sites
  set occupied-hg "yes"
  ;; create new site and define characteristics
  sprout-hunter-sites 1 [
    set size 5
    set shape "house"
    set color 15
    set population number-hunter
    set funded ticks
    set group "hunter"
    set blocked ticks
  ]
  set near-patches patches in-radius 5
  ask near-patches [
    set occupied-hg "yes"
    set blocked ticks
  ]
end

to split-hunter
  ;; procedure to split hunter sites and fund new site
  ask hunter-sites [
    ;; if the population exceeds the threshold
    if population > number-hunter-split [
      ;; find new patch to fund a new site
      let settler-patches patches in-radius 15 with [
        occupied-hg = "no"
        and landform = "land"
        and continent = 1
        and not any? farmer-sites in-radius 10
        and not any? other hunter-sites in-radius 10
      ]

      ;; if there is a suitable patch available, create a new site
      if max-one-of settler-patches [fertility] != nobody [
        ask one-of settler-patches [
          new-hunter
        ]
        ;; adjust the population of the home site to account for inhabitants that moved to the new site
        set population population - number-hunter
      ]
    ]
  ]
end

to demic
  ;; procedure for demic diffusion
  ask farmer-sites [
    ;; there are any hunter sites in the vicinity of a farmer site, the farmer site will be abandoned with a certain probability
    if any? hunter-sites in-radius 15 and random-float 1 < farmer-die-prob [
      die-farmer
    ]
    ;; if the farmer site wants to split and fund a new site but can't find a suitable patch,
    ;; it destroys hunter-sites in the vicinity to free up space to settle
    if population > number-farmer-split [
      let available-patches patch-set known-patches
      let settler-patches available-patches with [
        occupied-f = "no"
        and landform = "land"
        and pcolor != black
        and not any? farmer-sites in-radius 10
        and not any? hunter-sites in-radius 10
      ]

      ifelse max-one-of settler-patches [fertility] != nobody [
        set population population - number-farmer
        ask max-one-of settler-patches [fertility] [
          new-farmer
        ]
      ][
        if any? hunter-sites in-radius 15 [
          ask hunter-sites in-radius 15 [
            die
          ]
        ]
      ]
    ]
  ]
end

to cultural
  ;; procedure for cultural diffusion
  ask hunter-sites [
    ;; if there are any farmer site in the vicinity of a hunter site,
    ;; the farmer-arrival counter starts to run and is updates with every tick
    if any? farmer-sites in-radius 15 [
      ifelse farmer-arrival = 0 [
        set farmer-arrival ticks
      ][
        let arrival-time (ticks - farmer-arrival)
        ;; if a certain time has past (here: 20 years), the hunter site turns into a farmer site and changes the respective variables
        if arrival-time = 240 [
          set breed farmer-sites
          set shape "house"
          set color 65

          ask patch-here [
            set region [who] of farmer-sites-here
            set near-patches patches in-radius 15
            ask near-patches [
              set occupied-f "yes"
            ]

            set region-patches patches in-radius 25
            set-region
            sprout-farmer-settlers 1 [
              set shape "person"
              set color 65
              set size 4
              set home-site first [who] of farmer-sites-here
              set visited-patches []
              set sailor "no"
              set landing-place []
              set my-region first [region] of myself
              set hidden? not hidden?
            ]
          ]
        ]
      ]
    ]
  ]

  ask farmer-sites [
    if any? hunter-sites in-radius 15 and random-float 1 < farmer-die-prob [
      die-farmer
    ]
  ]
end

to show-sites
  ;; procedure to make documented sites visible for the time of their ocupation
  ;; this helps to trace if the hunters and farmers spread accordingly
  ask site-agents [
    ;; make site visible once their start date is reached
    if real-time = start-date [
      show-turtle
    ]

    ;; make site invisible again once their end date is reached
    if real-time = end-date [
      hide-turtle
    ]
  ]
end

to save-files
  ;; procedure to save files after the run finished
  ;; all the sites that have been founded and abandoned and are NOT present at the end of the run are saved to sites.csv
  csv:to-file "sites.csv" list-sites
  ;; all the farmer sites present at the end of the run are saved to farmers.csv
  csv:to-file "farmers.csv" [(list group xcor ycor population funded abandoned)] of farmer-sites
  ;; all the hunter sites present at the end of the run are saved to hunter.csv
  csv:to-file "hunters.csv" [(list group xcor ycor population funded abandoned)] of hunter-sites
  ;; the current view of the interface is saved to ABM-archaeoriddle.png.
  ;; Ideally, only the plot would be saved but this can only be done in the form of a csv that then needs to be edited elsewhere.
  export-view "ABM_archaeoriddle.png"
end
@#$#@#$#@
GRAPHICS-WINDOW
316
21
820
526
-1
-1
1.93
1
10
1
1
1
0
0
0
1
0
256
0
256
0
0
1
ticks
30.0

BUTTON
7
17
144
50
setup world
setup \"\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
154
18
304
51
setup sites
load-sites \"\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
153
55
305
88
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
6
55
144
88
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
6
97
306
130
set hunter-gatherer start with mouse 
mouse-set-start-hg
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
7
138
305
171
set start farmer with mouse
mouse-set-start-f
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
8
181
307
214
maxslope
maxslope
0
500
100.0
1
1
NIL
HORIZONTAL

INPUTBOX
9
372
151
432
world-max-dim
256.0
1
0
Number

INPUTBOX
156
372
308
432
GIS-grid-cell-km
2.0
1
0
Number

SWITCH
8
439
150
472
color-world
color-world
0
1
-1000

SLIDER
8
218
150
251
number-farmer
number-farmer
0
200
100.0
10
1
NIL
HORIZONTAL

SLIDER
156
218
307
251
number-hunter
number-hunter
0
30
10.0
5
1
NIL
HORIZONTAL

CHOOSER
157
439
309
484
interaction-type
interaction-type
"cultural diffusion" "demic diffusion"
1

SLIDER
8
297
150
330
growth-rate-farmer
growth-rate-farmer
1
2.5
1.8
0.1
1
NIL
HORIZONTAL

SLIDER
156
296
307
329
growth-rate-hunter
growth-rate-hunter
0.2
0.6
0.6
0.1
1
NIL
HORIZONTAL

PLOT
829
21
1149
280
Number of sites
ticks
count
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"farmers " 1.0 0 -15040220 true "" "plot count farmer-sites"
"hunters " 1.0 0 -8053223 true "" "plot count hunter-sites "

SLIDER
8
258
151
291
number-farmer-split
number-farmer-split
0
500
200.0
50
1
NIL
HORIZONTAL

SLIDER
156
258
306
291
number-hunter-split
number-hunter-split
0
50
20.0
10
1
NIL
HORIZONTAL

SLIDER
7
333
150
366
time-blocked
time-blocked
0
500
360.0
10
1
NIL
HORIZONTAL

SLIDER
9
486
309
519
farmer-die-prob
farmer-die-prob
0.001
0.1
0.02
0.001
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model was developed for Archaeoriddle, a project to test computational archaeological methods. We simulate the spread of farming in an artificial world, based on data provided by Archaeoriddle.

## HOW IT WORKS

### Purpose

The implementation of this model was used within the Archaeoriddle project to test if it can explain the archaeological record correctly. Artificial data was provided by Archaeoriddle. This data was generated by simulating a complete record of archaeological data and then removing some of it according to certain rules of "loss over time". The fragmented data is the basis for this model and the aim is to evaluate how well it can estimate the complete record. 
 
### Entities, state variables, and scales

#### Extent 
The spatial extent of the model world is determined by the input, i.e. it comprises the raster data specified by Archaeoriddle and the settlements loaded into the model as a shapefile.
 
One time step represents one month and simulations are run for 12000 ticks, i.e. 1000 years. 

#### Entities 
_Entity 1: Settlements (agents, collective)_

  * State variables (stable)
    * Location (coordinates)
    * Start date (begin of occupation)
    * End date (end of occupation)
    * Econonmy (hunter-gatherer or farmer)

_Entity 2: Farmers (agents, collective)_

  * State variables (stable)
    * funded (start date)          
    * abandoned (end date)        
    * group (economy)    
  * State variables (dynamic)
    * population  
    * known-patches (patches visited by the farmer settler, i.e. known to the community) 

_Entity 3: Farmer settler (agents, collective)_

  * State variables (stable)
    * home-site (farmer-site the farmer belongs to)       
    * my-region (region of the home-site in which the farmer-settler can move)    
  * State variables (dynamic)
    * visited-patches (patches visited, reported to home-site and stored there as known-patches)
    * sailor (if farmer-settler is at the coast, he becomes a sailor)
    * landing-place (first coast patch the farmer-settler arrives at)
    * time-here (time since the farmer arrived in the current coastal area)

_Entity 4: Hunter-gatheres (agents, collective)_

  * State variables (stable)
    * funded (start date)          
    * abandoned (end date)        
    * group (economy)    
  * State variables (dynamic)
    * population
    * farmer arrival (tick when a farmer site first showed up in the vicinity)
    * last move (tick when the site last moved)

_Entity 5: Grid cells (spatial units)_

  * State variables (stable)
    * elevation (m, derived from DEM)
    * fertility (probability of hunters and farmers settling here)
    * patchtype (suitable or unsuitable)
    * landform (sea, land or coast)
    * continent (area in which hunters can move)
    * coast (land patches adjacent to sea patches)
  * State variables (dynamic)
    * occupied-hg (occupied by hunter-gatheres)
    * occupied-f (occupied by farmers)
    * near-patches (patches in the vicinity)
    * region (number of region = id of the site that occupies the patch and its neighbours)
    * allowed (region in which farmer-settlers are allowed to move)
    * region-patches (patches that the farmer-settler can explore)
    * blocked (for hunter-sites: when moving, previous visited patches are blocked for a certain time)


To set up a simulation, the user first needs to load a raster basemap of the area which specifies the elevation of the cells. Additionanally, a raster map representing environmental fitness has to be imported, adding the "fertility" value to the patches. The raster map "continent" is optional and limits the area in which hunter-gatherers cn move as they are not able to cross the sea. Optionally, the user can load a vector points map of sites. In the model, we use the site information provided by Archaeoriddle to cross-check our model. The sites pop up when the ticks reach their start date and disappear once their occupation period is over, allowing us to evaluate if our simulated sites have a similar trajectory. The maps must be in the same geospatial projection. 

### Base map
The raster base map needs to be in ESRI ASCII format to be read by the GIS extension. Each raster cell should have a value that indicates the elevation. An input box can be used to define the real-world extent of each grid cell.

### Fertility map
The raster fertility needs to be in ESRI ASCII format to be read by the GIS extension. Each raster cell should have a value that indicates the probability of hunter-gatheres or farmers settling here. The model assumes that a higher value indicates greater suitability.

### Continent map
The raster continent map needs to be in ESRI ASCII format to be read by the GIS extension. Each raster cell has a value of either 1 or -9999 that specifies if a hunter-gatherer can move to this patch (1) or not (-9999). This map is only used to limit the movement of the hunter-gatherers as they are no seafarers. 

### Sites map
The vector points map sites needs to be in ESRI shapefile format. The information for each site are used as variables for this agent group, i.e. start date, end date, location and economy. Including sites is optional and can be initiated with the button setup sites>. 

### Starting points
The origin for farming is defined as the oldest farmer site in the data set. Currently, the site appears in the location and at the time defined in the Archaeoriddle data. 

The hunter-gatherers sites are assumed to already be there when the first farmers appear. For simplicity, hunter-gatherer sites are therefore created in certain intervals until there are 30 of them spread over the map.
 
Alternatively, an origin point or set of points for farmers and hunter-gatheres can be set interactively with a mouse or from a text file of geospatial coordinate pairs. 

For a coordinates file, the coordinates must be in the same geospatial projection as the GIS base map (e.g., longitude/latitude or UTM). Each coordinate pair must be 

  1. written as east (horizontal or x coordinate) and north (vertical or y coordinate), 
  2. separated by a space, 
  3. inside square brackets,´ 
  4. on a new line

For example, if the UTM coordinates for point 1 are 728707 east, 4374094 north, and the coordinates for point 2 are 996073 east 4720022 north, they must be written as:

[728707 4374094]
[996073 4720022]

### Hunter-gatherers
Hunter-gatherers are a mobile community and hence, their sites move constantly. Every 10 years, a hunter-gatherer site will therefore shift to another patch in a certain radius. Previously occupied patches are blocked for the time specified by the slider <time-blocked>. The initial population for sites can be set with the <number-hunter> slider. 

If a site reaches the population threshold, determined by the slider <number-hunter-split>, a number of hunter-gatherers, defined by <number-hunter>, leaves the site and founds a new one close by. The growth rate of the hunter-gatherers can be adjusted wiith the slider <growth-rate-hunter> and the population of a site grows once per year according to this rate. 

### Farmers
Unlike hunter-gatherers, farmers are settled and hence their approach to spreadinng is different. Every farmer site has a settler, i.e. an agent who explores the vicinity of the site and records the patches he has visited. If a farmer site reaches the threshold to split (<number-farmer-split>), the patch with the highest fertility among those recorded by the settler is chosen to found a new site. As with the hunter-gatherers, the initial population of a site is defined by <number-farmer> and the growth rate by <growth-rate-farmer>. 

If a settler arrives at a patch with landform "coast", he becomes a sailor, i.e. he can now cross patches with landform "sea". As a sailor, he can travel sea patches with a larger distacne than on land, allowing him to reach islands and therfore, enabling farming to spread over sea and not only over land. This rule was included because the Archaeoriddle suggested that the farmers were seafarers and occupied islands while the hunter-gatherers moved exclusively over land.  

All sites, no matter if hunter-gatherer or farmer, have a certain probality to be abandoned, depending on the fertility of the patch and the occupation span. The longer a site exists and the lower the fertility, the higher is the cahnce of it to be abandoned. Those probabilities were calculated based on the average occupation span of the sites provided by Archaeoriddle in relation to the fertility.

### Interaction types
Two types of interaction can be selecte, cultural or demic diffusion.

Cultural diffusion is the peaceful interaction between farmers and hunter-gatherers. If a farmer sites is established near a hunter-gatherer site, a timer starts, indicated by the <farmer-arrival> variable within the hunter-gatherer sites. After the sites have been in close contact for 20 years, the hunter-gatherer sites change their breed and become farmers. This interaction type simulates the spred of farming through peaceful exchange and co-existence that results in hunter-gatherers adapting the new lifestyle.

Demic diffusion represents the spread of farming through conflict. If farmer and hunter-gatherer sites are set up in close vicinity to each other, there is a probability that the farmer site will be abnadoned, i.e. destroyed by the hunter-gatherers. This probability can be set with the slider <farmer-die-prob>. On the other hand, if a farmer site has reached the threshold to split but cannot find a suitable spot for a new settlement, it will destroy a hunter-gatherer site to occupy its place.

### Saving output
The model will save a *.csv file of farmer and hunter-gatherer sites that have been founded and abandoned in the course of the simulation and a separate *.csv file that includes all sites that were still occupied at the end of the run. The economy, coordinates, population, start and end dates of the sites will be recorded. Additionally, a *.png of the current view will be exported.


## HOW TO USE IT
Set up the world by using the <setup> button. Note that the size of the NetLogo world in cells can be set through the world-max-dim entry field. Also, the user can indicate the real world size of the raster cells in the GIS data set with the GIS-grid-cell-km entry field. The file names can be changed diretly in the code:

; to setup-world
  ;; define the ASCII files that serve as the environment for the simulation
  set landmap "east_narnia.asc" ;; elevation 
  set remap "resources.asc"	;; fertility
  set contmap "continent.asc"	;; continent

Optionally, select a vector sites map (*.shp) with the <setup sites> button.

In the current model, hunter-gatherer and farmer sites are automatically initialised. Alternatively, the respective code can be disablED and one of more starting points can be set using a mouse or load starting points from a text file of coordinate pairs.

Select an interaction type, either cultural or demic diffusion.

Define the parameters for the hunter-gatherers and farmers: 
  * <number-hunter> and <number-farmer> for the initial population of sites
  * <number-hunter-split> and <number-farmer-split> for the threshold to split a site
  * <growth-rate-hunter> and <growth-rate-farmer> for the respective growth rates
  * <maxslope> for the maximum slope the farmer settlers can travel
  * <time-blocked> for the time span a patch is blocked for hunter-gatherer occupation
  * <farmer-die-prob> for the proability of farmer sites to be abandoned if they are in the vicinity of a hunter-gatherer site

Press <Go>. At the end of a simulation run, the output will be automatically saved.

## THINGS TO NOTICE

Note that the setup procedure might fail or result in the wrong display of the environment due to a bug in one of the extensions (see comments in the code). In this case, the setup needs to be run again until succeeds and the environment is created correctly.

## EXTENDING THE MODEL

This is just a very basic model there are a variety of configurations for it. Too list just a few: 

  1. The parameter values have not been tested comprehensively. Hence, additional 		   runs,
 e.g. in BehaviourSpace, would be useful to find the best fitting values.
	   Those parameter values include the initial population numbers, the point of 			   splitting for individual sites, birth and death rates, travel distances, 			   refinement of seafaring and many more.			   
  2. We used the artificial world provided by Archaeoriddle for our model. 			   Integrating real-world data and case studies would be a natural next step.
  3. The basis for our environmental fitness layer is not very specific. Including 		   different maps for different characteristics such as soil, water availability 		   or vegetation would allow for a more detailed definiton of fitness.
  4. Compare different variations of spreading, i.e. one startpoint vs. multiple 			   startpoints of farmers.


## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

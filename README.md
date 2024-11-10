Introduction 
This study was developed as part of the Archaeoriddle project to explore how accurate our methods in computational archaeology can answer questions posted by archaeological research and where the limits of those methods are. Archaeoriddle generated artificial archaeological data using a model and then simulated the loss of this data over the millennia. The setup is a neolithic landscape with hunter-gatherers (Rabbit Skinners) already living there and farmers (Poppy Chewers) starting to occupy the landscape.
Archaeologists were then invited to explore the artificial environment (Rabbithole) with methods of their choice to answer one or more of three research questions: 
1.	What was the relationship between the two groups? Was it peaceful or hostile?
2.	What was the population trajectory of each group?
3.	What was the rate of dispersal of poppy chewers?
Our approach includes exploratory data analysis (EDA), digital fieldwork and agent-based modelling (ABM) to investigate the spread of farming across Rabbithole. 

Contents of the repository
1.	Data provided by Archaeoriddle
a.	Initial excavated area (5 tiles): “Biblio_data.csv”
b.	Initial tiles supplemented with further 5 tiles after EDA: “Biblio_all_tiles.csv”
c.	Image of Rabbithole: “Rabbithole.png”
d.	Distribution of resources: “resources.tiff”
e.	Digitial elevation model (DEM) of Rabbithole: “east_narnia4x.tif”

2.	EDA in R: R project and script for data analysis in R

3.	EDA in ArcGIS: ArcGIS Geodatabase

4.	ABM: NetLogo model in folder “code” with data necessay for the model in folder “data”. Note that the data folder contains original data provided by Archaeoriddle as well as data produced during EDA. 

5.	EAA 2023: PowerPoint presented at the Archaeoriddle session at the EAA conference 2023.

Software
For the EDA, we used R version 4.2.2 and RStudio version 2022.07.2 with packages:
sf_1.0-13     
ggplot2_3.4.1 
oxcAAR_1.1.1  
stringr_1.4.1
In addition, EDA was carried out in ArcGIS Pro, version 3.1.1
The ABM was developed in NetLogo 6.3.

Exploratory analysis
First, we calibrated the 14C dates obtained from all sites and calculated rates of dispersal, studied site preferences, site persistence and distances to nearby settlements over time for both populations; the Rabbit Skinners and the Poppy Chewers. Rates of dispersal are based on the assumption that the Poppy Chewers first settled in the eastern part of Rabbithole while farmers immigrated from the south – a hypothesis which was tested later. Dispersal rates were modelled using the earliest date within the 1-sigma span of the calibrated start dates and the latest date of the calibrated end date of a settlement. A nearest-neighbour algorithm was used for interpolation. 
After the initial assessment, additional fieldwork was carried out to explore specific questions and hypotheses. During the second phase of data exploration, we tried to identify initial parameters for the model, including spread rates and preferred distances between settlements. We then developed an ABM to simulate different scenarios with varying parameters for the behaviours of Rabbit Skinners and Poppy Chewers with the intention to find the best fit with the available data.
 

Agent-based model
The ABM simulates the spread of the two populations, hunter-gatherers and farmers, based on the data provided by Archaeoriddle and supplemented through the exploratory analysis and literature. 
A detailed description of the ABM in the form of an ODD protocol can be found in the “Info” tab of the NetLogo model with additional comments throughout the code. 



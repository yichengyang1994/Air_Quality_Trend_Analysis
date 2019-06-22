### This studdy applied the based on the "rmweather" package from Grange et al. (2018):https://github.com/skgrange/normalweatherr

setwd("F:/Air Quality Trends/ Data analysis/")
workingDirectory<<-"F:/Air Quality Trends/ Data analysis/"

library(rmweather) ### Random Forest/ Weather Normalization from Grange Github
# Reference: https://github.com/skgrange/rmweather
library (openair) ### For Theil-sen analysis

###01. Import the data set which contains: date, PM2.5 and MET weathers

# data preparation
data_prepared_PM2.5 <- data_PM2.5 %>% 
  filter(!is.na(ws)) %>% 
  rename(value = PM2.5) %>% 
  rmw_prepare_data(na.rm = TRUE)

#Variables in the data set: date_unix, day_julian, week/weekday, hour
#MET variable: temperature (temp), Relative Humidity (RH), wind speed (ws), wind direction (wd), atmospheric pressure (pressure), back-trajectories (cluster).
set.seet(123) 

###02.  Build RF model: 

RF_PM2.5_model <- rmw_do_all(
  data_prepared_PM2.5,
  variables = c(
    "date_unix", "day_julian", "weekday", "air_temp", "RH", "wd", "ws",
    "press"
  ),
  n_trees = 200,
  n_samples = 300,
  verbose = TRUE
  )

### 03. Predict the level of a pollutant in different weather condition

# Initial MET data 
MET_1988_2017<-import("MET_1988_2017.csv", date="date", date.format = "%d/%m/%Y %H:%M")
MET_2013_2017<-import("PM2.5_MET_2013_2017.csv", date="date", date.format = "%d/%m/%Y %H:%M")
# Initial_nomarlised_data<-import("data_normalisation_initial_1000.csv", date="date", date.format = "%d/%m/%Y %H:%M")### A blank matrix, nrow= nrow(PM2.5_MET_2013_2017), ncol=1000
nomarlised_prediction<- data_PM2.5 %>% select(1)

# Use Parallel computing: 
library(doParallel)
registerDoParallel(cores = detectCores() - 1)

#Predict the level of a pollutant in different weather condition
Pollutant_prediction <-function (n){    ###n is the number of re-sample MET data set
  for (j in 1:n){
    for (i in 1:43824){           ### 43824 is number of hourly obserbvation from 2013-2017                    
      hour_1<-MET_2013_2017[i,5] ### "hour" variable is in the 5th column in the data set  
      week_1<-MET_2013_2017[i,3] ### "week" variable is in the 3rd column in the data set 
      ### Randomly sample weather data from 1988-2017
      if(week_1==1){
        MET_sample<-MET_1988_2017 %>% filter(hour==hour_1)  %>% filter(week>=52|week <= 3)  %>% sample_n(10)}
      if(week_1==2){
        MET_sample<-MET_1988_2017 %>% filter(hour==hour_1)  %>% filter(week>=53|week <= 4)  %>% sample_n(10)}
      if(week_1==52) {
        MET_sample<-MET_1988_2017 %>% filter(hour==hour_1)  %>% filter(week>=50|week <= 1)  %>% sample_n(10)}
      if(week_1==53) {
        MET_sample<-MET_1988_2017 %>% filter(hour==hour_1)  %>% filter(week>=51|week <= 2)  %>% sample_n(10)}
      if(week_1>2 & week_1<51){
        MET_sample<-MET_1988_2017 %>% filter(hour==hour_1)  %>% filter(week>= week_1-2 & week <= week_1+2) %>% sample_n(10)}  
      ### Generate the new dataset of MET data from 2013-2017 by 1988-2017  
      MET_2013_2017[i,9:18]<-MET_sample[5,9:18]} # Generate the new data met for 2013-2017 by 1988-2017
    
    predict_PM2.5_level<- rmw_predict( ### RUN Random Forest model with new MET dataset
      RF_PM2.5_model$model, 
      MET_2013_2017
    )
    
    nomarlised_prediction <-cbind(nomarlised_prediction, predict_PM2.5_level$value_predict)}
    nomarlised_prediction
}

### Final_weather_normalised_PM2.5 by aggregating 1000 single predictions.
# Pollutant_prediction (1000) ### random by 1000 times
nomarlised_prediction <- Pollutant_prediction (1000)
final_weather_nomarlised_PM2.5 %>% apply(nomarlised_prediction[,2:1001],1,mean, na.rm=TRUE) ### Mean value of 1000 predictions
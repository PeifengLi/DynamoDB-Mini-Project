SELECT COUNT(*) AS Row_Count
FROM sensor_data;

SELECT * FROM sensor_data LIMIT 10;

/* List the sensors for which you have data */
SELECT DISTINCT sensorid.s AS SensorId FROM sensor_data; 

/* Get the number of readings from a specific sensor */ 
SELECT COUNT(*) AS NumberOfReadings FROM sensor_data
WHERE sensorid.s = 'some-sensor-id';

/* Find the average temperature measured by a specific sensor */ 
SELECT AVG(temperature.n) AS AverageTemp FROM sensor_data
WHERE sensorid.s = 'some-sensor-id';

/* Find the average temperature across all sensors */
SELECT AVG(temperature.n) AS AverageTempAllSensors FROM sensor_data; 

/* Find the average temperature from a specific sensor */
SELECT AVG(temperature.n) AS AverageTemp FROM sensor_data
WHERE sensorid.s = 'some-sensor-id';

/* Find the maximum temperature across all sensors */
SELECT MAX(temperature.n) AS MaxTemp FROM sensor_data;

/* Find the standard deviation for temperature across all sensors */ 
SELECT STDDEV(temperature.n) AS StdDev FROM sensor_data;

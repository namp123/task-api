# TASK MANAGER API

## About the App
  I have built a NodeJS (ExpressJs) application that simulates a basic 'task manager'. It has 2 basic API's:  
  
    1.GET /tasks - Fetches and returns all tasks stored in the database (mongodB) as a JSON array.  
    2.POST /tasks - Accepts a task name in the request body, validates it, creates a new task in the database, and returns the created task as a JSON response.

## Lets get the app to run locally! here's how: 
**PREREQUISITES**

  Make sure you have docker desktop intalled and running as a background process on your laptop  
  
  If you don't already have it installed visit -> https://www.docker.com/products/docker-desktop/  

Now run the following commands to initalise your local environment to get the app running for you.
```
   git clone https://github.com/namp123/task-api.git
```
```
   cd task-api
```
you don't have to install npm or another dependecy as the docker container is going to be intialised with them.  

This will build the image from the Dockerfile
```
   docker-compose build
```
Run the containers (starts the app, mongodb, prometheus, grafana, alertmanager elasticsearch, logstash, kibana containers all together)
```
   docker-compose up -d
```
on your browser now open -> http://localhost:3000

There you have it, the task manager on your laptop! :smile: :rocket: :tada:

## Adding a new task to the task manager (uses the POST API)
From your terminal run  
```
  curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"name": "Writing to db..."}'
```
Now visit -> http://localhost:3000 and navigate to the "View Tasks" link to see your new task being added here

## Fetching a task from task manager (uses the GET API)
From your terminal run  
```
  curl http://localhost:3000/tasks
```

## Relevant links to monitor the application (make sure containers are running to access these)  
http://localhost:3000 (Webapp)  

http://localhost:3000/metrics (View all the default and custom metrics exposed by the application)

http://localhost:9090 (Query metrics on Prometheus)  

http://localhost:9090/alerts (View Prometheus alerts)  

http://localhost:9090/targets (View targets on Prometheus)  

http://localhost:3001 (Check out the "APP Monitoring" dashboard on Grafana)  

http://localhost:9200 (Elasticsearch)  

http://localhost:5601 (Kibana, NOTE: need to create service account with a role attatched to it for it to work)


## View the full documentation along here 

https://docs.google.com/document/d/1xhTZ5yPmU6nFm6-d9sZGTM47XTDCmfacx0RDQomU_GI/edit?usp=sharing











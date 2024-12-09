const express = require('express');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');

const app = express();
app.use(bodyParser.json());

// establish MongoDB connection first
const mongoUrl = process.env.MONGO_URL || 'mongodb://localhost:27017/tasksdb';

mongoose.connect(mongoUrl, { useNewUrlParser: true, useUnifiedTopology: true })
    .then(() => console.log('Connected to MongoDB'))
    .catch(err => console.error('MongoDB connection error:', err));

//schema and model for db
const taskSchema = new mongoose.Schema({
    name: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
});

//home page
app.get('/', (req, res) => {
    res.send('<h1>Welcome to the Namithas Task Manager!</h1><p>Manage your tasks here.</p><a href="/tasks">View Tasks</a>');
});

const Task = mongoose.model('Task', taskSchema);

// GET /tasks - Retrieve all tasks
app.get('/tasks', async (req, res) => {
    try {
        const tasks = await Task.find();
        res.json(tasks);
    } catch (err) {
        res.status(500).json({ error: 'Failed to retrieve tasks' });
    }
});

// POST /tasks - Add a new task
app.post('/tasks', async (req, res) => {
    try {
        const { name } = req.body;
        if (!name) {
            return res.status(400).json({ error: 'Task name is required' });
        }

        const newTask = new Task({ name });
        const savedTask = await newTask.save();
        res.status(201).json(savedTask);
    } catch (err) {
        res.status(500).json({ error: 'Failed to create task' });
    }
});

//EXPOSING PROMETHEUS DEFAULT AND CUSTOM METRICS FOR MY APPLICATION----------------
const client = require('prom-client');
const register = new client.Registry(); //creating a registry to store metrics
client.collectDefaultMetrics({ register }); //create default metrics
// Custom metrics (total number of HTTP requests)
const httpRequestCounter = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status'],
  });
register.registerMetric(httpRequestCounter); //registering this custom metric
app.use((req, res, next) => {
    res.on('finish', () => {
      httpRequestCounter.labels(req.method, req.path, res.statusCode).inc();
    });
    next();
});
// Expose metrics at /metrics endpoint
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.send(await register.metrics());
});

  



const port = 3000;
app.listen(port, () => {
    console.log(`task Api App is running on http://localhost:${port}`);
});

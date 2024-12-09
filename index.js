const express = require('express');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
const client = require('prom-client');

const app = express();
app.use(bodyParser.json());

// MongoDB connection
const mongoUrl = process.env.MONGO_URL || 'mongodb://localhost:27017/tasksdb';
mongoose
    .connect(mongoUrl)
    .then(() => console.log('Connected to MongoDB'))
    .catch((err) => console.error('MongoDB connection error:', err));

// Task schema and model
const taskSchema = new mongoose.Schema({
    name: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
});
const Task = mongoose.model('Task', taskSchema);

// Routes
app.get('/', (req, res) => {
    res.send('<h1>Welcome to Namitha\'s Task Manager!</h1><p>Manage your tasks here.</p><a href="/tasks">View Tasks</a>');
});

app.get('/tasks', async (req, res) => {
    try {
        const tasks = await Task.find();
        res.json(tasks);
    } catch (err) {
        res.status(500).json({ error: 'Failed to retrieve tasks' });
    }
});

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

// Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestCounter = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status'],
});
register.registerMetric(httpRequestCounter);

app.use((req, res, next) => {
    res.on('finish', () => {
        httpRequestCounter.labels(req.method, req.path, res.statusCode).inc();
    });
    next();
});

app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.send(await register.metrics());
});

// Export the app (without starting the server)
module.exports = app;

// Start the server only if this file is executed directly
if (require.main === module) {
    const port = process.env.PORT || 3000;
    app.listen(port, () => {
        console.log(`Safle Api App is running on http://localhost:${port}`);
    });
}

const request = require('supertest');
const assert = require('chai').assert;
const app = require('../index'); // Import the app without starting the server

describe('task API Tests', () => {
    it('should fetch all items', (done) => {
        request(app)
            .get('/tasks') // Fixed route
            .expect(200)
            .end((err, res) => {
                assert.ifError(err);
                assert.isArray(res.body);
                done();
            });
    });

    it('should add a new item', (done) => {
        const newItem = { name: 'Item 3' };

        request(app)
            .post('/tasks') // Fixed route
            .send(newItem)
            .expect(201)
            .end((err, res) => {
                assert.ifError(err);
                assert.equal(res.body.name, 'Item 3');
                done();
            });
    });
});


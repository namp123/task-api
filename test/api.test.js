const request = require('supertest');
const assert = require('chai').assert;
const app = require('../index');

describe('task API Tests', () => {

  // Test GET /items endpoint
  it('should fetch all items', (done) => {
    request(app)
      .get('/items')
      .expect(200) 
      .end((err, res) => {
        assert.ifError(err);  
        assert.isArray(res.body);  
        assert.lengthOf(res.body, 2);  
        done();
      });
  });

  // Test POST /items endpoint
  it('should add a new item', (done) => {
    const newItem = { name: 'Item 3' };

    request(app)
      .post('/items')
      .send(newItem)  
      .expect(201) 
      .end((err, res) => {
        assert.ifError(err);  
        assert.deepEqual(res.body.name, 'Item 3');  
        assert.property(res.body, 'id');
        done();
      });
  });

});

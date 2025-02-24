const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    message: 'Portfolio application is running!',
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(`Portfolio app listening at http://localhost:${port}`);
}); 
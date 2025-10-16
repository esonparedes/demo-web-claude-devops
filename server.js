const express = require('express');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use('/public', express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
  res.render('index', { q: req.query.q || '' });
});

// Minimal API that returns fake search results for testing/demo purposes
app.get('/api/search', (req, res) => {
  const q = (req.query.q || '').toString().slice(0, 200);
  const items = [];
  if (q) {
    for (let i = 1; i <= 5; i++) {
      items.push({
        title: `${q} result ${i}`,
        link: `https://example.com/${encodeURIComponent(q)}/${i}`,
        snippet: `This is a demo result for ${q} (#${i}).`
      });
    }
  }
  res.json({ q, items });
});

if (require.main === module) {
  app.listen(port, () => console.log(`App listening on http://localhost:${port}`));
}

module.exports = app;

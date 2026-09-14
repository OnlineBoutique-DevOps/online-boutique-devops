const http = require('http');

const PORT = process.env.PORT || 8080;

const reviews = [
  { id: 1, productId: 'OLJ94N68D6', rating: 5, comment: 'Excelente producto, supero mis expectativas.' },
  { id: 2, productId: 'OLJ94N68D6', rating: 4, comment: 'Buena calidad, llego a tiempo.' },
  { id: 3, productId: '66V1O2S34X', rating: 5, comment: 'Muy recomendado, excelente diseno.' }
];

const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/liveness') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ status: 'ok' }));
  } else if (req.url.startsWith('/reviews')) {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(reviews));
  } else {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ message: 'Review Service Active' }));
  }
});

server.listen(PORT, () => {
  console.log('Review service listening on port ' + PORT);
});

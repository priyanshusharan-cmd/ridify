const jwt = require('jsonwebtoken');

const SECRET = process.env.JWT_SECRET;
const EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

function signAccessToken(payload) {
  return jwt.sign(payload, SECRET, { expiresIn: EXPIRES_IN, algorithm: 'HS256' });
}

function signRefreshToken(payload) {
  return jwt.sign(payload, SECRET + '_refresh', {
    expiresIn: REFRESH_EXPIRES_IN, algorithm: 'HS256'
  });
}

function verifyAccessToken(token) {
  return jwt.verify(token, SECRET, { algorithms: ['HS256'] });
}

function verifyRefreshToken(token) {
  return jwt.verify(token, SECRET + '_refresh', { algorithms: ['HS256'] });
}

module.exports = { signAccessToken, signRefreshToken, verifyAccessToken, verifyRefreshToken };

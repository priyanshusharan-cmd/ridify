const { verifyAccessToken } = require('../utils/jwt');
const User = require('../models/user');

module.exports = async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required. Provide a Bearer token.' });
  }
  const token = authHeader.slice(7);
  try {
    const payload = verifyAccessToken(token);
    
    // Ensure the user actually exists in the database
    const user = await User.findById(payload.id);
    if (!user) {
      return res.status(401).json({ error: 'User account has been deleted.', code: 'USER_DELETED' });
    }

    if (user.isBanned) {
      return res.status(403).json({ error: 'Your account has been suspended. Contact support.', code: 'ACCOUNT_BANNED' });
    }

    req.user = { email: payload.email, id: payload.id };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired. Please log in again.', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Invalid token.' });
  }
};

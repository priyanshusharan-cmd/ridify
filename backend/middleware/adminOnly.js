const adminEmails = (process.env.ADMIN_EMAILS || '')
  .split(',')
  .map(e => e.trim().toLowerCase())
  .filter(Boolean);

function adminOnly(req, res, next) {
  const callerEmail = (req.headers['x-admin-email'] || '').trim().toLowerCase();
  if (!callerEmail || !adminEmails.includes(callerEmail)) {
    return res.status(403).json({ error: 'Forbidden: Admin access required.' });
  }
  if (process.env.ADMIN_SECRET) {
    const callerSecret = req.headers['x-admin-secret'];
    if (callerSecret !== process.env.ADMIN_SECRET) {
      return res.status(403).json({ error: 'Forbidden: Invalid Admin Secret.' });
    }
  }
  next();
}

module.exports = adminOnly;

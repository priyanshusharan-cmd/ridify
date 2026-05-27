const adminEmails = (process.env.ADMIN_EMAILS || '')
  .split(',').map(e => e.trim().toLowerCase()).filter(Boolean);

function adminOnly(req, res, next) {
  // req.user is guaranteed by authenticate middleware running first
  if (!req.user || !adminEmails.includes(req.user.email)) {
    return res.status(403).json({ error: 'Forbidden: Admin access required.' });
  }
  // ADMIN_SECRET is now REQUIRED — no optional behavior
  const secret = req.headers['x-admin-secret'];
  if (!secret || secret !== process.env.ADMIN_SECRET) {
    return res.status(403).json({ error: 'Forbidden: Invalid Admin Secret.' });
  }
  next();
}

module.exports = adminOnly;

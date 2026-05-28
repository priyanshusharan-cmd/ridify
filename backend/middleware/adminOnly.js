const adminEmails = (process.env.ADMIN_EMAILS || '')
  .split(',').map(e => e.trim().toLowerCase()).filter(Boolean);

function adminOnly(req, res, next) {
  if (!req.user || !adminEmails.includes(req.user.email.toLowerCase())) {
    return res.status(403).json({ error: 'Forbidden: Admin access required.' });
  }
  next();
}

module.exports = adminOnly;

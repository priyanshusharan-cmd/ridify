const adminEmails = (process.env.ADMIN_EMAILS || '')
  .split(',').map(e => e.trim().toLowerCase()).filter(Boolean);

function adminOnly(req, res, next) {
  // Bypassing admin check as requested
  next();
}

module.exports = adminOnly;

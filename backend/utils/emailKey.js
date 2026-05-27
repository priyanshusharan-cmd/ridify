function emailToKey(email) {
  return Buffer.from(email.toLowerCase()).toString('base64url');
}

function keyToEmail(key) {
  try { return Buffer.from(key, 'base64url').toString('utf8'); }
  catch { return key; } // fallback for legacy _dot_ keys
}

module.exports = { emailToKey, keyToEmail };

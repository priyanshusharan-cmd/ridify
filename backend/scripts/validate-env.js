require('dotenv').config();

const REQUIRED = [
  'JWT_SECRET', 'JWT_REFRESH_SECRET', 'MONGO_URI', 'ADMIN_SECRET', 'ADMIN_EMAILS',
  'PORT', 'NODE_ENV'
];
const PLACEHOLDER_PATTERNS = ['your-', 'REPLACE_', 'example.com', 'your_'];

let hasError = false;

for (const key of REQUIRED) {
  if (!process.env[key]) {
    console.error(`❌ Missing required env var: ${key}`);
    hasError = true;
  } else if (PLACEHOLDER_PATTERNS.some(p => process.env[key].includes(p))) {
    console.error(`❌ Placeholder value detected for: ${key}`);
    hasError = true;
  } else {
    console.log(`✅ ${key} is set`);
  }
}

// Validate JWT_SECRET entropy
const secret = process.env.JWT_SECRET || '';
if (secret.length < 32) {
  console.error('❌ JWT_SECRET must be at least 32 characters');
  hasError = true;
}

if (hasError) {
  console.error('\n🚨 Environment validation FAILED. Fix above errors before running.');
  process.exit(1);
}
console.log('\n✅ All environment variables are valid.');

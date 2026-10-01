const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('--- Starting Build & Validation ---');

const projectRoot = path.resolve(__dirname, '..');

// 1. Verify required files exist
console.log('1. Checking required project files...');
const requiredFiles = [
  'package.json',
  'package-lock.json',
  'src/app.js',
  'src/server.js',
  'src/db/schema.sql'
];

for (const relPath of requiredFiles) {
  const fullPath = path.join(projectRoot, relPath);
  if (!fs.existsSync(fullPath)) {
    console.error(`[ERROR] Missing required file: ${relPath}`);
    process.exit(1);
  }
  console.log(`  ✓ Found ${relPath}`);
}

// 2. Syntax check on all .js files under src/
console.log('2. Running syntax checks (node --check) on src/ files...');

function getJsFiles(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  for (const file of list) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat && stat.isDirectory()) {
      results = results.concat(getJsFiles(filePath));
    } else if (filePath.endsWith('.js')) {
      results.push(filePath);
    }
  }
  return results;
}

const srcDir = path.join(projectRoot, 'src');
const jsFiles = getJsFiles(srcDir);

for (const file of jsFiles) {
  const rel = path.relative(projectRoot, file);
  try {
    execSync(`node --check "${file}"`, { stdio: 'pipe' });
    console.log(`  ✓ Syntax OK: ${rel}`);
  } catch (err) {
    console.error(`[ERROR] Syntax check failed for ${rel}:`, err.stderr ? err.stderr.toString() : err.message);
    process.exit(1);
  }
}

// 3. Write build-info.json
console.log('3. Generating build-info.json...');
const pkg = JSON.parse(fs.readFileSync(path.join(projectRoot, 'package.json'), 'utf8'));

let commitHash = 'unknown';
try {
  commitHash = execSync('git rev-parse --short HEAD', { cwd: projectRoot, stdio: 'pipe' }).toString().trim();
} catch (_) {}

const buildNumber = process.env.BUILD_NUMBER || 'local';
const timestamp = new Date().toISOString();

const buildInfo = {
  name: pkg.name,
  version: pkg.version,
  commit: commitHash,
  buildNumber: buildNumber,
  builtAt: timestamp
};

const buildInfoPath = path.join(projectRoot, 'build-info.json');
fs.writeFileSync(buildInfoPath, JSON.stringify(buildInfo, null, 2) + '\n', 'utf8');
console.log(`  ✓ Generated build-info.json:`, JSON.stringify(buildInfo));

console.log('--- Build completed successfully ---');

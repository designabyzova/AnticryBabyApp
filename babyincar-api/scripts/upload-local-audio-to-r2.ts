#!/usr/bin/env npx ts-node
/**
 * Upload Local Audio Files to Cloudflare R2
 *
 * This script scans the iOS app's audio resources directory and uploads
 * all audio files to Cloudflare R2 storage, removing them from git tracking.
 *
 * Prerequisites:
 *   - Create R2 bucket: wrangler r2 bucket create babyincar-audio
 *   - Create R2 API token in Cloudflare dashboard with Object Read & Write permissions
 *
 * Usage:
 *   # Set environment variables
 *   export R2_ACCOUNT_ID="your-account-id"
 *   export R2_ACCESS_KEY_ID="your-access-key"
 *   export R2_SECRET_ACCESS_KEY="your-secret-key"
 *
 *   # Run the script
 *   cd babyincar-api
 *   npx ts-node scripts/upload-local-audio-to-r2.ts
 *
 *   # Or with wrangler (uses wrangler.toml config)
 *   npx wrangler r2 object put babyincar-audio/path/file.mp3 --file=./file.mp3
 */

import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

// Configuration
const CONFIG = {
  accountId: process.env.R2_ACCOUNT_ID || '',
  accessKeyId: process.env.R2_ACCESS_KEY_ID || '',
  secretAccessKey: process.env.R2_SECRET_ACCESS_KEY || '',
  bucketName: process.env.R2_BUCKET_NAME || 'babyincar-audio',
  // Path to iOS app audio resources
  audioDir: path.join(__dirname, '../../BabyInCarApp/BabyInCarApp/Resources/Audio'),
  // Minimum file size to upload (100MB) - smaller files can stay in git
  minFileSizeBytes: 100 * 1024 * 1024, // 100MB
  // Whether to upload all files or just large ones
  uploadAll: process.argv.includes('--all'),
  // Dry run mode
  dryRun: process.argv.includes('--dry-run'),
};

interface AudioFile {
  localPath: string;
  relativePath: string;
  r2Key: string;
  size: number;
  category: string;
  filename: string;
}

// AWS Signature V4 implementation for R2
function getSignatureKey(
  key: string,
  dateStamp: string,
  regionName: string,
  serviceName: string
): Buffer {
  const kDate = crypto.createHmac('sha256', `AWS4${key}`).update(dateStamp).digest();
  const kRegion = crypto.createHmac('sha256', kDate).update(regionName).digest();
  const kService = crypto.createHmac('sha256', kRegion).update(serviceName).digest();
  const kSigning = crypto.createHmac('sha256', kService).update('aws4_request').digest();
  return kSigning;
}

function sign(key: Buffer, msg: string): string {
  return crypto.createHmac('sha256', key).update(msg, 'utf8').digest('hex');
}

function hash(data: Buffer | string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

function getContentType(filename: string): string {
  const ext = path.extname(filename).toLowerCase().slice(1);
  const types: Record<string, string> = {
    mp3: 'audio/mpeg',
    ogg: 'audio/ogg',
    wav: 'audio/wav',
    m4a: 'audio/mp4',
    flac: 'audio/flac',
    aac: 'audio/aac',
  };
  return types[ext] || 'application/octet-stream';
}

function formatSize(bytes: number): string {
  if (bytes >= 1024 * 1024 * 1024) {
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  } else if (bytes >= 1024 * 1024) {
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  } else if (bytes >= 1024) {
    return `${(bytes / 1024).toFixed(2)} KB`;
  }
  return `${bytes} bytes`;
}

async function uploadToR2(
  filePath: string,
  key: string,
  contentType: string
): Promise<boolean> {
  const fileContent = fs.readFileSync(filePath);
  const payloadHash = hash(fileContent);

  const method = 'PUT';
  const service = 's3';
  const region = 'auto';
  const host = `${CONFIG.bucketName}.${CONFIG.accountId}.r2.cloudflarestorage.com`;

  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
  const dateStamp = amzDate.substring(0, 8);

  const canonicalUri = `/${key.split('/').map(encodeURIComponent).join('/')}`;
  const canonicalQueryString = '';
  const canonicalHeaders = [
    `content-length:${fileContent.length}`,
    `content-type:${contentType}`,
    `host:${host}`,
    `x-amz-content-sha256:${payloadHash}`,
    `x-amz-date:${amzDate}`,
  ].join('\n') + '\n';
  const signedHeaders = 'content-length;content-type;host;x-amz-content-sha256;x-amz-date';

  const canonicalRequest = [
    method,
    canonicalUri,
    canonicalQueryString,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');

  const algorithm = 'AWS4-HMAC-SHA256';
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    algorithm,
    amzDate,
    credentialScope,
    hash(canonicalRequest),
  ].join('\n');

  const signingKey = getSignatureKey(CONFIG.secretAccessKey, dateStamp, region, service);
  const signature = sign(signingKey, stringToSign);

  const authHeader = `${algorithm} Credential=${CONFIG.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const url = `https://${host}${canonicalUri}`;

  try {
    const response = await fetch(url, {
      method: 'PUT',
      headers: {
        'Content-Type': contentType,
        'Content-Length': fileContent.length.toString(),
        'X-Amz-Content-Sha256': payloadHash,
        'X-Amz-Date': amzDate,
        'Authorization': authHeader,
      },
      body: fileContent,
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`  Upload failed: ${response.status} ${errorText}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error(`  Upload error: ${error}`);
    return false;
  }
}

function scanAudioDirectory(dir: string, baseDir: string = dir): AudioFile[] {
  const files: AudioFile[] = [];
  const audioExtensions = ['.mp3', '.ogg', '.wav', '.m4a', '.flac', '.aac'];

  if (!fs.existsSync(dir)) {
    console.error(`Directory not found: ${dir}`);
    return files;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      // Skip .build and other hidden directories
      if (!entry.name.startsWith('.')) {
        files.push(...scanAudioDirectory(fullPath, baseDir));
      }
    } else if (entry.isFile()) {
      const ext = path.extname(entry.name).toLowerCase();
      if (audioExtensions.includes(ext)) {
        const stats = fs.statSync(fullPath);
        const relativePath = path.relative(baseDir, fullPath);
        // Category is the first directory in the relative path
        const category = relativePath.split(path.sep)[0] || 'uncategorized';

        files.push({
          localPath: fullPath,
          relativePath,
          r2Key: `audio/${relativePath.replace(/\\/g, '/')}`,
          size: stats.size,
          category,
          filename: entry.name,
        });
      }
    }
  }

  return files;
}

async function main() {
  console.log('='.repeat(60));
  console.log('Upload Local Audio Files to Cloudflare R2');
  console.log('='.repeat(60));
  console.log();

  // Check if --help
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log(`
Usage: npx ts-node scripts/upload-local-audio-to-r2.ts [options]

Options:
  --all       Upload all audio files (default: only files > 100MB)
  --dry-run   Show what would be uploaded without actually uploading
  --help, -h  Show this help message

Environment Variables:
  R2_ACCOUNT_ID         Your Cloudflare account ID (required)
  R2_ACCESS_KEY_ID      R2 API access key ID (required)
  R2_SECRET_ACCESS_KEY  R2 API secret access key (required)
  R2_BUCKET_NAME        R2 bucket name (default: babyincar-audio)

To create R2 API credentials:
  1. Go to Cloudflare Dashboard > R2 > Manage R2 API Tokens
  2. Create a new API token with "Object Read & Write" permissions
  3. Copy the Access Key ID and Secret Access Key
`);
    process.exit(0);
  }

  // Validate configuration
  if (!CONFIG.accountId || !CONFIG.accessKeyId || !CONFIG.secretAccessKey) {
    console.error('Error: R2 credentials not configured.');
    console.error();
    console.error('Please set the following environment variables:');
    console.error('  R2_ACCOUNT_ID         Your Cloudflare account ID');
    console.error('  R2_ACCESS_KEY_ID      R2 API access key ID');
    console.error('  R2_SECRET_ACCESS_KEY  R2 API secret access key');
    console.error();
    console.error('Run with --help for more information.');
    process.exit(1);
  }

  console.log(`Configuration:`);
  console.log(`  Account ID: ${CONFIG.accountId.substring(0, 8)}...`);
  console.log(`  Bucket: ${CONFIG.bucketName}`);
  console.log(`  Audio directory: ${CONFIG.audioDir}`);
  console.log(`  Upload mode: ${CONFIG.uploadAll ? 'All files' : 'Files > 100MB only'}`);
  console.log(`  Dry run: ${CONFIG.dryRun ? 'Yes' : 'No'}`);
  console.log();

  // Scan for audio files
  console.log('Scanning for audio files...');
  const allFiles = scanAudioDirectory(CONFIG.audioDir);
  console.log(`Found ${allFiles.length} audio files.`);
  console.log();

  // Filter files based on size
  const filesToUpload = CONFIG.uploadAll
    ? allFiles
    : allFiles.filter(f => f.size >= CONFIG.minFileSizeBytes);

  // Calculate totals
  const totalSize = filesToUpload.reduce((sum, f) => sum + f.size, 0);
  const largeFiles = allFiles.filter(f => f.size >= CONFIG.minFileSizeBytes);

  console.log(`Summary:`);
  console.log(`  Total audio files: ${allFiles.length}`);
  console.log(`  Files > 100MB: ${largeFiles.length}`);
  console.log(`  Files to upload: ${filesToUpload.length}`);
  console.log(`  Total size to upload: ${formatSize(totalSize)}`);
  console.log();

  if (filesToUpload.length === 0) {
    console.log('No files to upload.');
    return;
  }

  // Group by category for display
  const byCategory = new Map<string, AudioFile[]>();
  for (const file of filesToUpload) {
    if (!byCategory.has(file.category)) {
      byCategory.set(file.category, []);
    }
    byCategory.get(file.category)!.push(file);
  }

  console.log('Files by category:');
  for (const [category, files] of byCategory) {
    const categorySize = files.reduce((sum, f) => sum + f.size, 0);
    console.log(`  ${category}: ${files.length} files (${formatSize(categorySize)})`);
  }
  console.log();

  if (CONFIG.dryRun) {
    console.log('DRY RUN - Files that would be uploaded:');
    for (const file of filesToUpload) {
      console.log(`  ${file.r2Key} (${formatSize(file.size)})`);
    }
    console.log();
    console.log('Run without --dry-run to actually upload.');
    return;
  }

  // Upload files
  console.log('Starting upload...');
  console.log();

  let successCount = 0;
  let failCount = 0;
  const uploadedFiles: AudioFile[] = [];

  for (let i = 0; i < filesToUpload.length; i++) {
    const file = filesToUpload[i];
    const progress = `[${i + 1}/${filesToUpload.length}]`;

    console.log(`${progress} Uploading: ${file.filename}`);
    console.log(`  Size: ${formatSize(file.size)}`);
    console.log(`  R2 Key: ${file.r2Key}`);

    const success = await uploadToR2(
      file.localPath,
      file.r2Key,
      getContentType(file.filename)
    );

    if (success) {
      successCount++;
      uploadedFiles.push(file);
      console.log(`  Status: SUCCESS`);
    } else {
      failCount++;
      console.log(`  Status: FAILED`);
    }
    console.log();
  }

  // Summary
  console.log('='.repeat(60));
  console.log('Upload Complete');
  console.log('='.repeat(60));
  console.log(`  Successful: ${successCount}`);
  console.log(`  Failed: ${failCount}`);
  console.log();

  // Generate metadata file for tracking
  if (uploadedFiles.length > 0) {
    const metadataPath = path.join(__dirname, '../r2-uploaded-files.json');
    const metadata = uploadedFiles.map(f => ({
      localPath: f.relativePath,
      r2Key: f.r2Key,
      size: f.size,
      category: f.category,
      uploadedAt: new Date().toISOString(),
      r2Url: `r2://${f.r2Key}`,
    }));

    fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));
    console.log(`Metadata saved to: ${metadataPath}`);
    console.log();
  }

  // Instructions for next steps
  console.log('Next steps:');
  console.log('  1. Remove uploaded files from git:');
  console.log('     git rm --cached <files>');
  console.log('  2. Add files to .gitignore');
  console.log('  3. Update app to stream from R2 instead of local files');
  console.log();
  console.log('R2 file URLs will be:');
  console.log(`  https://${CONFIG.bucketName}.${CONFIG.accountId}.r2.cloudflarestorage.com/<key>`);
  console.log();
  console.log('Or configure a custom domain in Cloudflare Dashboard > R2 > Settings');
}

main().catch(console.error);

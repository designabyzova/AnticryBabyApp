/**
 * Upload Audio Files to Cloudflare R2
 *
 * This script uploads collected audio files to your Cloudflare R2 bucket.
 * It uses the AWS S3 SDK with Cloudflare R2's S3-compatible API.
 *
 * Prerequisites:
 *   - Create R2 bucket: wrangler r2 bucket create babyincar-audio
 *   - Create R2 API token in Cloudflare dashboard
 *
 * Usage:
 *   R2_ACCOUNT_ID=xxx R2_ACCESS_KEY_ID=xxx R2_SECRET_ACCESS_KEY=xxx \
 *   npx ts-node scripts/upload-to-r2.ts
 */

import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

// R2 Configuration
const CONFIG = {
  accountId: process.env.R2_ACCOUNT_ID || '',
  accessKeyId: process.env.R2_ACCESS_KEY_ID || '',
  secretAccessKey: process.env.R2_SECRET_ACCESS_KEY || '',
  bucketName: process.env.R2_BUCKET_NAME || 'babyincar-audio',
  endpoint: '', // Will be set based on account ID
  audioLibraryDir: path.join(__dirname, '../audio-library'),
  metadataFile: path.join(__dirname, '../audio-library/metadata.json'),
};

CONFIG.endpoint = `https://${CONFIG.accountId}.r2.cloudflarestorage.com`;

interface AudioMetadata {
  id: string;
  source: string;
  sourceId: string;
  title: string;
  artist: string;
  category: string;
  subcategory: string;
  duration: number;
  fileSize: number;
  format: string;
  license: string;
  licenseUrl: string;
  sourceUrl: string;
  downloadUrl: string;
  localPath?: string;
  r2Key?: string;
  tags: string[];
  calmingScore: number;
  ageRangeMin: number;
  ageRangeMax: number;
  isPremium: boolean;
  createdAt: string;
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

  const canonicalUri = `/${encodeURIComponent(key)}`;
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
      console.error(`Upload failed: ${response.status} ${errorText}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error(`Upload error: ${error}`);
    return false;
  }
}

function getContentType(format: string): string {
  const types: Record<string, string> = {
    mp3: 'audio/mpeg',
    ogg: 'audio/ogg',
    wav: 'audio/wav',
    m4a: 'audio/mp4',
  };
  return types[format] || 'application/octet-stream';
}

async function main() {
  // Validate configuration
  if (!CONFIG.accountId || !CONFIG.accessKeyId || !CONFIG.secretAccessKey) {
    console.error(`
Error: R2 credentials not configured.

Please set the following environment variables:
  R2_ACCOUNT_ID         Your Cloudflare account ID
  R2_ACCESS_KEY_ID      R2 API access key ID
  R2_SECRET_ACCESS_KEY  R2 API secret access key
  R2_BUCKET_NAME        (optional) R2 bucket name (default: babyincar-audio)

To create R2 API credentials:
  1. Go to Cloudflare Dashboard > R2 > Manage R2 API Tokens
  2. Create a new API token with "Object Read & Write" permissions
  3. Copy the Access Key ID and Secret Access Key
`);
    process.exit(1);
  }

  // Check for metadata file
  if (!fs.existsSync(CONFIG.metadataFile)) {
    console.error('Metadata file not found. Run audio-collector.ts --collect first.');
    process.exit(1);
  }

  const metadata: AudioMetadata[] = JSON.parse(
    fs.readFileSync(CONFIG.metadataFile, 'utf-8')
  );

  // Filter files that have local paths and need uploading
  const toUpload = metadata.filter(m =>
    m.localPath && fs.existsSync(m.localPath) && !m.r2Key
  );

  console.log(`=== Uploading to Cloudflare R2 ===\n`);
  console.log(`Bucket: ${CONFIG.bucketName}`);
  console.log(`Files to upload: ${toUpload.length}\n`);

  let successCount = 0;
  let failCount = 0;

  for (let i = 0; i < toUpload.length; i++) {
    const audio = toUpload[i];
    const filename = path.basename(audio.localPath!);
    const r2Key = `audio/${audio.category}/${filename}`;

    console.log(`[${i + 1}/${toUpload.length}] Uploading: ${audio.title}`);
    console.log(`  Key: ${r2Key}`);

    const success = await uploadToR2(
      audio.localPath!,
      r2Key,
      getContentType(audio.format)
    );

    if (success) {
      audio.r2Key = r2Key;
      successCount++;
      console.log(`  Success`);
    } else {
      failCount++;
      console.log(`  Failed`);
    }
  }

  // Update metadata with R2 keys
  fs.writeFileSync(CONFIG.metadataFile, JSON.stringify(metadata, null, 2));

  console.log(`\n=== Upload Complete ===`);
  console.log(`Success: ${successCount}`);
  console.log(`Failed: ${failCount}`);

  // Generate public URLs info
  console.log(`\nTo enable public access, create a custom domain for your R2 bucket:`);
  console.log(`  1. Go to Cloudflare Dashboard > R2 > ${CONFIG.bucketName} > Settings`);
  console.log(`  2. Add a custom domain (e.g., audio.babyincar.app)`);
  console.log(`  3. Files will be accessible at: https://audio.babyincar.app/audio/[category]/[filename]`);
}

main().catch(console.error);

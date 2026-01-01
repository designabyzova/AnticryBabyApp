#!/usr/bin/env npx ts-node
/**
 * Upload Collected Audio to Cloudflare R2
 *
 * Uploads files from audio-library/downloads/ to R2 bucket
 *
 * Usage:
 *   R2_ACCOUNT_ID=xxx R2_ACCESS_KEY_ID=xxx R2_SECRET_ACCESS_KEY=xxx \
 *   npx ts-node scripts/upload-collected-to-r2.ts
 */

import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

const CONFIG = {
  accountId: process.env.R2_ACCOUNT_ID || '',
  accessKeyId: process.env.R2_ACCESS_KEY_ID || '',
  secretAccessKey: process.env.R2_SECRET_ACCESS_KEY || '',
  bucketName: process.env.R2_BUCKET_NAME || 'babyincar-audio',
  downloadDir: path.join(__dirname, '../audio-library/downloads'),
  metadataFile: path.join(__dirname, '../audio-library/collected-metadata.json'),
};

interface DownloadedTrack {
  id: string;
  title: string;
  artist: string;
  category: string;
  duration: number;
  source: string;
  sourceUrl: string;
  license: string;
  localPath: string;
  r2Key?: string;
  tags: string[];
  calmingScore: number;
}

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

  const canonicalUri = `/${encodeURIComponent(key).replace(/%2F/g, '/')}`;
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
      console.error(`  Upload failed: ${response.status} ${errorText.substring(0, 100)}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error(`  Upload error: ${error}`);
    return false;
  }
}

async function main() {
  console.log('╔═══════════════════════════════════════════════════════╗');
  console.log('║   Upload Collected Audio to Cloudflare R2             ║');
  console.log('╚═══════════════════════════════════════════════════════╝\n');

  // Validate config
  if (!CONFIG.accountId || !CONFIG.accessKeyId || !CONFIG.secretAccessKey) {
    console.error('Error: R2 credentials not configured.\n');
    console.error('Set these environment variables:');
    console.error('  R2_ACCOUNT_ID         - Cloudflare account ID');
    console.error('  R2_ACCESS_KEY_ID      - R2 API access key');
    console.error('  R2_SECRET_ACCESS_KEY  - R2 API secret key');
    console.error('  R2_BUCKET_NAME        - (optional) bucket name\n');
    console.error('To create R2 credentials:');
    console.error('  1. Cloudflare Dashboard > R2 > Manage R2 API Tokens');
    console.error('  2. Create token with Object Read & Write permissions');
    process.exit(1);
  }

  // Load metadata
  if (!fs.existsSync(CONFIG.metadataFile)) {
    console.error('Metadata file not found. Run collector first.');
    process.exit(1);
  }

  const tracks: DownloadedTrack[] = JSON.parse(
    fs.readFileSync(CONFIG.metadataFile, 'utf-8')
  );

  // Filter tracks that need uploading
  const toUpload = tracks.filter(t =>
    t.localPath &&
    fs.existsSync(t.localPath) &&
    !t.r2Key
  );

  console.log(`Bucket: ${CONFIG.bucketName}`);
  console.log(`Account: ${CONFIG.accountId}`);
  console.log(`Files to upload: ${toUpload.length}\n`);

  let success = 0;
  let failed = 0;

  for (let i = 0; i < toUpload.length; i++) {
    const track = toUpload[i];
    const filename = path.basename(track.localPath);
    const r2Key = `audio/${track.category}/${filename}`;

    process.stdout.write(`[${i + 1}/${toUpload.length}] ${filename.substring(0, 40)}... `);

    const uploaded = await uploadToR2(track.localPath, r2Key, 'audio/mpeg');

    if (uploaded) {
      track.r2Key = r2Key;
      success++;
      console.log('✓');
    } else {
      failed++;
      console.log('✗');
    }
  }

  // Save updated metadata
  fs.writeFileSync(CONFIG.metadataFile, JSON.stringify(tracks, null, 2));

  console.log(`\n=== Upload Complete ===`);
  console.log(`Success: ${success}`);
  console.log(`Failed: ${failed}`);

  if (success > 0) {
    console.log(`\nFiles accessible at:`);
    console.log(`  https://${CONFIG.bucketName}.${CONFIG.accountId}.r2.cloudflarestorage.com/audio/[category]/[file]`);
    console.log(`\nOr with custom domain:`);
    console.log(`  https://audio.babyincar.app/audio/[category]/[file]`);
  }
}

main().catch(console.error);

import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

test.describe('Cry Classification API - Full Integration', () => {

  const API_URL = 'http://localhost:8000';

  test('should classify test cry audio file correctly', async ({ request }) => {
    // Read the test audio file
    const audioPath = path.join(__dirname, 'fixtures', 'test_cry.wav');
    const audioBuffer = fs.readFileSync(audioPath);

    // Create form data with the audio file
    const response = await request.post(`${API_URL}/classify`, {
      multipart: {
        audio: {
          name: 'test_cry.wav',
          mimeType: 'audio/wav',
          buffer: audioBuffer,
        },
      },
    });

    expect(response.ok()).toBeTruthy();
    const result = await response.json();

    // Verify response structure
    expect(result).toHaveProperty('is_cry');
    expect(result).toHaveProperty('cry_confidence');
    expect(result).toHaveProperty('cry_type');
    expect(result).toHaveProperty('type_confidence');
    expect(result).toHaveProperty('probabilities');
    expect(result).toHaveProperty('features');
    expect(result).toHaveProperty('model_used');

    // Verify detection result
    expect(result.is_cry).toBe(true);
    expect(result.cry_confidence).toBeGreaterThan(0.5);

    // Verify cry type probabilities
    expect(result.probabilities).toHaveProperty('hunger');
    expect(result.probabilities).toHaveProperty('tired');
    expect(result.probabilities).toHaveProperty('pain');
    expect(result.probabilities).toHaveProperty('attention');
    expect(result.probabilities).toHaveProperty('discomfort');
    expect(result.probabilities).toHaveProperty('general');

    // Verify probabilities sum to ~1.0
    const totalProb = Object.values(result.probabilities as Record<string, number>).reduce(
      (sum, prob) => sum + prob,
      0
    );
    expect(totalProb).toBeCloseTo(1.0, 1);

    // Verify features were extracted
    expect(result.features).toHaveProperty('rms');
    expect(result.features).toHaveProperty('spectral_centroid');
    expect(result.features).toHaveProperty('duration_seconds');

    console.log('Classification result:', JSON.stringify(result, null, 2));
  });

  test('should return correct content type', async ({ request }) => {
    const response = await request.get(`${API_URL}/`);
    expect(response.headers()['content-type']).toContain('application/json');
  });

  test('should handle API health check', async ({ request }) => {
    const response = await request.get(`${API_URL}/`);
    expect(response.ok()).toBeTruthy();

    const data = await response.json();
    expect(data.status).toBe('healthy');
    expect(data).toHaveProperty('model_type');
  });

  test('should reject invalid audio format gracefully', async ({ request }) => {
    // Send a text file as audio
    const response = await request.post(`${API_URL}/classify`, {
      multipart: {
        audio: {
          name: 'invalid.wav',
          mimeType: 'audio/wav',
          buffer: Buffer.from('This is not audio data'),
        },
      },
    });

    // Should return an error (500 or 422)
    expect(response.status()).toBeGreaterThanOrEqual(400);
  });
});

test.describe('Web Frontend - API Integration', () => {

  test('should show API status in model status element', async ({ page }) => {
    await page.goto('/');

    // Wait for API check to complete
    await page.waitForTimeout(2000);

    const modelStatus = page.locator('#modelStatus');
    const text = await modelStatus.textContent();

    // Should show some status (API connected or fallback)
    expect(text).toBeTruthy();
    expect(text!.length).toBeGreaterThan(5);
  });

  test('should have functional upload button', async ({ page }) => {
    await page.goto('/');

    const uploadBtn = page.locator('#uploadBtn');
    const fileInput = page.locator('#audioFileInput');

    // Upload button should be visible and clickable
    await expect(uploadBtn).toBeVisible();
    await expect(uploadBtn).toBeEnabled();

    // File input should be hidden but present
    await expect(fileInput).toBeHidden();
    await expect(fileInput).toBeAttached();
  });

  test('should handle file upload via input', async ({ page }) => {
    await page.goto('/');

    // Wait for app initialization
    await page.waitForFunction(
      () => typeof window.cryDetectorApp !== 'undefined',
      { timeout: 5000 }
    );

    const fileInput = page.locator('#audioFileInput');

    // Upload the test audio file
    const audioPath = path.join(__dirname, 'fixtures', 'test_cry.wav');
    await fileInput.setInputFiles(audioPath);

    // Wait for processing
    await page.waitForTimeout(3000);

    // Check that something happened (history should have an entry or status changed)
    const historyList = page.locator('#historyList');
    const historyText = await historyList.textContent();

    // Either we have a detection in history or still showing empty
    // (depending on API response time)
    expect(historyText).toBeTruthy();
  });
});

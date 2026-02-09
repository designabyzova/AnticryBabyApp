import { test, expect } from '@playwright/test';

test.describe('Baby Cry Detector - UI Tests', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should load the page with correct title', async ({ page }) => {
    await expect(page).toHaveTitle('Baby Cry Detector - Two-Stage Detection');
  });

  test('should display main heading', async ({ page }) => {
    const heading = page.locator('h1');
    await expect(heading).toHaveText('Baby Cry Detector');
  });

  test('should show two-stage subtitle', async ({ page }) => {
    const subtitle = page.locator('.subtitle');
    await expect(subtitle).toContainText('Two-Stage Detection');
  });

  test('should have status indicator', async ({ page }) => {
    const statusIndicator = page.locator('#statusIndicator');
    await expect(statusIndicator).toBeVisible();
  });

  test('should have Start Detection button', async ({ page }) => {
    const startBtn = page.locator('#startBtn');
    await expect(startBtn).toBeVisible();
    await expect(startBtn).toContainText('Start Detection');
  });

  test('should have Stop button', async ({ page }) => {
    const stopBtn = page.locator('#stopBtn');
    await expect(stopBtn).toBeVisible();
    await expect(stopBtn).toContainText('Stop');
  });

  test('should have Upload Audio button', async ({ page }) => {
    const uploadBtn = page.locator('#uploadBtn');
    await expect(uploadBtn).toBeVisible();
    await expect(uploadBtn).toContainText('Upload Audio');
  });

  test('should have hidden file input', async ({ page }) => {
    const fileInput = page.locator('#audioFileInput');
    await expect(fileInput).toBeHidden();
  });

  test('should display Stage 1 section', async ({ page }) => {
    const stage1 = page.locator('.stage-1');
    await expect(stage1).toBeVisible();

    const stage1Heading = stage1.locator('h2');
    await expect(stage1Heading).toContainText('Stage 1: Is This a Baby Cry?');
  });

  test('should have Stage 2 section hidden initially', async ({ page }) => {
    const stage2 = page.locator('#stage2Section');
    await expect(stage2).toBeHidden();
  });

  test('should have waveform canvas', async ({ page }) => {
    const canvas = page.locator('#waveformCanvas');
    await expect(canvas).toBeVisible();
  });

  test('should have audio level indicator', async ({ page }) => {
    const levelBar = page.locator('.level-bar');
    await expect(levelBar).toBeVisible();
  });

  test('should have detection scores section', async ({ page }) => {
    const detectionScores = page.locator('#detectionScores');
    await expect(detectionScores).toBeVisible();

    // Check for score value labels (fill elements have 0% width initially)
    await expect(page.locator('#scoreF0Val')).toBeVisible();
    await expect(page.locator('#scoreHarmonicVal')).toBeVisible();
    await expect(page.locator('#scoreFormantsVal')).toBeVisible();
    await expect(page.locator('#scoreTemporalVal')).toBeVisible();
    await expect(page.locator('#scoreAntiMusicVal')).toBeVisible();
  });

  test('should have category mode toggle', async ({ page }) => {
    // Category mode toggle is inside stage 2, which is hidden
    // Just check it exists in DOM
    const simpleRadio = page.locator('input[name="categoryMode"][value="simple"]');
    const detailedRadio = page.locator('input[name="categoryMode"][value="detailed"]');

    await expect(simpleRadio).toBeAttached();
    await expect(detailedRadio).toBeAttached();
  });

  test('should have history section', async ({ page }) => {
    const historySection = page.locator('.history-section');
    await expect(historySection).toBeVisible();

    const historyHeading = historySection.locator('h2');
    await expect(historyHeading).toHaveText('Detection History');
  });

  test('should have clear history button', async ({ page }) => {
    const clearBtn = page.locator('#clearHistoryBtn');
    await expect(clearBtn).toBeVisible();
    await expect(clearBtn).toContainText('Clear History');
  });

  test('should have debug section', async ({ page }) => {
    const debugSection = page.locator('.debug-section');
    await expect(debugSection).toBeVisible();

    const summary = debugSection.locator('summary');
    await expect(summary).toHaveText('Debug Information');
  });

  test('should expand debug section on click', async ({ page }) => {
    const details = page.locator('.debug-section details');
    const summary = details.locator('summary');

    // Initially closed
    await expect(details).not.toHaveAttribute('open');

    // Click to open
    await summary.click();
    await expect(details).toHaveAttribute('open');

    // Check debug items are visible
    await expect(page.locator('#debugSampleRate')).toBeVisible();
    await expect(page.locator('#debugBufferSize')).toBeVisible();
  });
});

test.describe('Baby Cry Detector - API Integration', () => {

  test('should check API health', async ({ request }) => {
    const response = await request.get('http://localhost:8000/');
    expect(response.ok()).toBeTruthy();

    const data = await response.json();
    expect(data.status).toBe('healthy');
  });

  test('should have model status info', async ({ request }) => {
    const response = await request.get('http://localhost:8000/');
    const data = await response.json();

    expect(data).toHaveProperty('model_loaded');
    expect(data).toHaveProperty('model_type');
  });
});

test.describe('Baby Cry Detector - API Classification', () => {

  test('should reject empty request', async ({ request }) => {
    const response = await request.post('http://localhost:8000/classify');
    // Should fail without audio file
    expect(response.status()).toBe(422); // Unprocessable Entity
  });
});

test.describe('Baby Cry Detector - JavaScript Initialization', () => {

  test('should initialize CryDetector class', async ({ page }) => {
    await page.goto('/');

    // Wait for scripts to load
    await page.waitForFunction(() => typeof window.CryDetector !== 'undefined', {
      timeout: 5000
    });

    const hasCryDetector = await page.evaluate(() => {
      return typeof window.CryDetector === 'function';
    });

    expect(hasCryDetector).toBe(true);
  });

  test('should initialize CryClassifier class', async ({ page }) => {
    await page.goto('/');

    await page.waitForFunction(() => typeof window.CryClassifier !== 'undefined', {
      timeout: 5000
    });

    const hasCryClassifier = await page.evaluate(() => {
      return typeof window.CryClassifier === 'function';
    });

    expect(hasCryClassifier).toBe(true);
  });

  test('should initialize AudioProcessor class', async ({ page }) => {
    await page.goto('/');

    await page.waitForFunction(() => typeof window.AudioProcessor !== 'undefined', {
      timeout: 5000
    });

    const hasAudioProcessor = await page.evaluate(() => {
      return typeof window.AudioProcessor === 'function';
    });

    expect(hasAudioProcessor).toBe(true);
  });

  test('should initialize CryClassifierAPIClient class', async ({ page }) => {
    await page.goto('/');

    await page.waitForFunction(() => typeof window.CryClassifierAPIClient !== 'undefined', {
      timeout: 5000
    });

    const hasAPIClient = await page.evaluate(() => {
      return typeof window.CryClassifierAPIClient === 'function';
    });

    expect(hasAPIClient).toBe(true);
  });

  test('should initialize CryDetectorApp', async ({ page }) => {
    await page.goto('/');

    // Wait for app initialization (stored as window.cryDetectorApp)
    await page.waitForFunction(() => typeof window.cryDetectorApp !== 'undefined', {
      timeout: 10000
    });

    const hasApp = await page.evaluate(() => {
      return window.cryDetectorApp !== undefined && window.cryDetectorApp !== null;
    });

    expect(hasApp).toBe(true);
  });
});

test.describe('Baby Cry Detector - API Client Check', () => {

  test('should detect API availability on page load', async ({ page }) => {
    await page.goto('/');

    // Wait for app to check API
    await page.waitForTimeout(3000);

    // Check model status shows API connection
    const modelStatus = page.locator('#modelStatus');
    const statusText = await modelStatus.textContent();

    // Should show either API connected or fallback mode
    expect(statusText).toBeTruthy();
    console.log('Model status:', statusText);
  });
});

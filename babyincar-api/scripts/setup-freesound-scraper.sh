#!/bin/bash
# Setup script for Freesound Baby-Safe Scraper

echo "=================================="
echo "Freesound Scraper Setup"
echo "=================================="

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install -r freesound-scraper-requirements.txt

# Test run (single execution)
echo ""
echo "Testing API connection..."
python3 -c "
import os
import requests
from dotenv import load_dotenv

load_dotenv('../../.env')
key = os.environ.get('FREESOUND_API_KEY', '')
if not key:
    print('ERROR: FREESOUND_API_KEY not found in .env')
    exit(1)

resp = requests.get(f'https://freesound.org/apiv2/search/text/?query=lullaby&token={key}&page_size=1')
if resp.status_code == 200:
    print(f'SUCCESS! API working. Found {resp.json().get(\"count\", 0)} results for \"lullaby\"')
else:
    print(f'ERROR: API returned {resp.status_code}')
    print(resp.text[:200])
"

echo ""
echo "=================================="
echo "Setup Options:"
echo "=================================="
echo ""
echo "1. RUN ONCE (test):"
echo "   python3 freesound-baby-safe-scraper.py"
echo ""
echo "2. RUN 24/7 DAEMON (foreground):"
echo "   python3 freesound-baby-safe-scraper.py --daemon"
echo ""
echo "3. RUN AS SYSTEMD SERVICE (Linux server):"
echo "   sudo cp freesound-scraper.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable freesound-scraper"
echo "   sudo systemctl start freesound-scraper"
echo ""
echo "4. RUN WITH PM2 (Node.js process manager):"
echo "   pm2 start freesound-baby-safe-scraper.py --name freesound --interpreter python3 -- --daemon"
echo ""
echo "5. RUN WITH LAUNCHD (macOS):"
echo "   See freesound-scraper.plist for configuration"
echo ""

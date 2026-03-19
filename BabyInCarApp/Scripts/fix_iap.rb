#!/usr/bin/env ruby
# Fix IAP availability and submit IAPs for review
# Uses App Store Connect API v1/v2

require 'net/http'
require 'json'
require 'jwt'
require 'openssl'

KEY_ID = "JZ2ML9M66A"
ISSUER_ID = "a9be87c1-47d8-40f2-897d-75df80a540fb"
KEY_PATH = File.expand_path("../fastlane/keys/AuthKey_JZ2ML9M66A.p8", __dir__)
APP_ID = "6756977992"
BASE_URL = "https://api.appstoreconnect.apple.com"

def generate_token
  private_key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  header = { alg: "ES256", kid: KEY_ID, typ: "JWT" }
  now = Time.now.to_i
  payload = { iss: ISSUER_ID, iat: now, exp: now + 1200, aud: "appstoreconnect-v1" }
  JWT.encode(payload, private_key, "ES256", header)
end

def api_request(method, path, body = nil)
  token = generate_token
  uri = URI("#{BASE_URL}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  case method
  when :get then req = Net::HTTP::Get.new(uri)
  when :post then req = Net::HTTP::Post.new(uri)
  when :patch then req = Net::HTTP::Patch.new(uri)
  when :delete then req = Net::HTTP::Delete.new(uri)
  end

  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = body.to_json if body

  response = http.request(req)
  puts "#{method.upcase} #{path} -> #{response.code}"

  if response.body && !response.body.empty?
    parsed = JSON.parse(response.body) rescue nil
    if response.code.to_i >= 400 && parsed
      errors = parsed["errors"] || []
      errors.each { |e| puts "  ERROR: #{e['detail'] || e['title']}" }
    end
    parsed
  else
    nil
  end
end

puts "=" * 60
puts "IAP FIX SCRIPT"
puts "=" * 60

# Step 1: Get all IAPs for the app
puts "\n--- Step 1: List all IAPs ---"
iaps = api_request(:get, "/v2/inAppPurchases?filter[apps]=#{APP_ID}&include=appStoreReviewScreenshot&limit=200")

if iaps.nil? || iaps["data"].nil?
  # Try v1 endpoint through app relationship
  puts "Trying via app relationship..."
  iaps = api_request(:get, "/v1/apps/#{APP_ID}/inAppPurchasesV2?limit=200")
end

if iaps && iaps["data"]
  iaps["data"].each do |iap|
    attrs = iap["attributes"] || {}
    puts "  IAP: #{attrs['name']} (#{attrs['productId']}) - State: #{attrs['state']} - Type: #{iap['type']}"
    puts "    ID: #{iap['id']}"

    iap_id = iap["id"]
    product_id = attrs["productId"]

    # Step 2: Check and fix availability for Lifetime product
    if product_id == "com.babyincar.premium.lifetime"
      puts "\n--- Step 2: Fix Lifetime availability ---"

      # Check current availability
      avail = api_request(:get, "/v1/inAppPurchases/#{iap_id}/iapPriceSchedule?include=baseTerritory")

      # Get all territories
      territories = api_request(:get, "/v1/territories?limit=200")
      all_territory_ids = []
      if territories && territories["data"]
        all_territory_ids = territories["data"].map { |t| t["id"] }
        puts "  Found #{all_territory_ids.count} territories"
      end

      # Create availability with all territories
      avail_body = {
        data: {
          type: "inAppPurchaseAvailabilities",
          attributes: {
            availableInNewTerritories: true
          },
          relationships: {
            inAppPurchase: {
              data: { type: "inAppPurchases", id: iap_id }
            },
            availableTerritories: {
              data: all_territory_ids.map { |tid| { type: "territories", id: tid } }
            }
          }
        }
      }

      result = api_request(:post, "/v1/inAppPurchaseAvailabilities", avail_body)
      if result && result["data"]
        puts "  ✅ Availability set for all territories!"
      else
        puts "  ⚠️  May need manual fix for availability"
      end
    end

    # Step 3: Submit IAP for review
    puts "\n--- Step 3: Submit IAP #{attrs['name']} for review ---"
    submission_body = {
      data: {
        type: "inAppPurchaseSubmissions",
        relationships: {
          inAppPurchase: {
            data: { type: "inAppPurchases", id: iap_id }
          }
        }
      }
    }

    result = api_request(:post, "/v2/inAppPurchaseSubmissions", submission_body)
    if result && result["data"]
      puts "  ✅ IAP #{attrs['name']} submitted for review!"
    else
      puts "  ⚠️  IAP submission may need screenshot or other metadata"
    end
  end
else
  puts "  No IAPs found or API error"
end

# Step 4: Get current app store version
puts "\n--- Step 4: Check app store version ---"
versions = api_request(:get, "/v1/apps/#{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,REJECTED,DEVELOPER_REJECTED&limit=5")
if versions && versions["data"] && !versions["data"].empty?
  version = versions["data"].first
  puts "  Version: #{version['attributes']['versionString']} - State: #{version['attributes']['appStoreState']}"
  puts "  Version ID: #{version['id']}"
end

puts "\n" + "=" * 60
puts "DONE"
puts "=" * 60

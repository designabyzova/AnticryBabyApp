require 'jwt'
require 'openssl'
require 'json'

key_id = "JZ2ML9M66A"
issuer_id = "a9be87c1-47d8-40f2-897d-75df80a540fb"
key_path = "./fastlane/keys/AuthKey_JZ2ML9M66A.p8"

private_key = OpenSSL::PKey::EC.new(File.read(key_path))

payload = {
  iss: issuer_id,
  exp: Time.now.to_i + 1200,  # 20 minutes
  aud: "appstoreconnect-v1"
}

token = JWT.encode(payload, private_key, "ES256", { kid: key_id })
puts token

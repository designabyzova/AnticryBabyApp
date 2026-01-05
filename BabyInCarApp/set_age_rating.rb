require 'spaceship'
require 'json'

# Load API key
api_key = Spaceship::ConnectAPI::Token.create(
  key_id: "JZ2ML9M66A",
  issuer_id: "a9be87c1-47d8-40f2-897d-75df80a540fb",
  filepath: "./fastlane/keys/AuthKey_JZ2ML9M66A.p8"
)

Spaceship::ConnectAPI.token = api_key

# Get the app
app = Spaceship::ConnectAPI::App.find("com.babyincar.app")
puts "Found app: #{app.name}"

# Get the editable version (should be 1.0)
version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
puts "App version: #{version.version_string}"

# Get the age rating declaration
age_rating_declaration = version.fetch_age_rating_declaration
puts "Age rating declaration ID: #{age_rating_declaration.id}"

# Update the age rating with all values set to NONE (4+ rating)
attributes = {
  violenceCartoonOrFantasy: "NONE",
  violenceRealistic: "NONE",
  violenceRealisticProlongedGraphicOrSadistic: "NONE",
  profanityOrCrudeHumor: "NONE",
  matureOrSuggestiveThemes: "NONE",
  horrorOrFearThemes: "NONE",
  medicalOrTreatmentInformation: "NONE",
  alcoholTobaccoOrDrugUseOrReferences: "NONE",
  gamblingSimulated: "NONE",
  sexualContentOrNudity: "NONE",
  sexualContentGraphicAndNudity: "NONE",
  unrestrictedWebAccess: false,
  gambling: false,
  contests: false,
  kidsAgeBand: nil
}

age_rating_declaration.update(attributes: attributes)
puts "Age rating updated successfully!"

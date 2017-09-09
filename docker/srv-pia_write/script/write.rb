# ruby write.rb -c '{"url":"http://1.2.3.4:5678","key":"eu.ownyourdata.repo","secret":"secret","repo":"eu.ownyourdata.repo","partial":"bookings","merge":["field1","field2"],"map":[{"date":"date"},{"field_1":"field1|sub1"}]}'

require 'httparty'
require 'optparse'
require 'digest'
require 'json'
require "active_support/core_ext/hash/except"

# parsing arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: write.rb [options]"
  opts.on('-c', '--config JSON', 'Konfiguration zum Speichern im Datentresor') { |v| options[:credentials] = v }
end.parse!

if options[:credentials].nil?
  puts "Error: fehldende Zugangsdaten"
  abort
end

begin
  ji = JSON.parse(options[:credentials])
rescue JSON::ParserError => e
  puts "Error: ungültiges Zugangsdaten-JSON"
  abort
end

if ji["url"].nil?
  puts "Error: fehlende Url"
  abort
end
if ji["key"].nil?
  puts "Error: fehlender Key"
  abort
end
if ji["secret"].nil?
  puts "Error: fehlendes Secret"
  abort
end
if ji["repo"].nil?
  puts "Error: fehlendes Repo"
  abort
end
if ji["map"].nil?
  puts "Error: fehlendes Mapping"
  abort
end

PIA_URL = ji["url"]
APP_ID = ji["key"]
APP_SECRET = ji["secret"]
REPO = ji["repo"]
PARTIAL = ji["partial"]
MERGE = ji["merge"]
MAP = ji["map"]

# reading stdin
input = ARGF.read
begin
  jsonInput = JSON.parse(input)
rescue JSON::ParserError => e
  puts "Error: ungültiges Input-JSON"
  abort
end
if !PARTIAL.nil?
  jsonInput = jsonInput[PARTIAL]
end

puts jsonInput.to_s
abort

# Basis-Funktionen zum Zugriff auf PIA ====================
# verwendete Header bei GET oder POST Requests
def defaultHeaders(token)
  { 'Accept' => '*/*',
    'Content-Type' => 'application/json',
    'Authorization' => 'Bearer ' + token }
end

# URL beim Zugriff auf eine Repo
def itemsUrl(url, repo_name)
  url + '/api/repos/' + repo_name + '/items'
end

# Anforderung eines Tokens für ein Plugin (App)
def getToken(pia_url, app_key, app_secret)
  auth_url = pia_url + '/oauth/token'
  auth_credentials = { username: app_key, 
                       password: app_secret }
  response = HTTParty.post(auth_url,
                           basic_auth: auth_credentials,
                           body: { grant_type: 'client_credentials' })
  token = response.parsed_response["access_token"]
  if token.nil?
      nil
  else
      token
  end
end

# Hash mit allen App-Informationen zum Zugriff auf PIA
def setupApp(pia_url, app_key, app_secret)
  token = getToken(pia_url, app_key, app_secret)
  { "url"        => pia_url,
    "app_key"    => app_key,
    "app_secret" => app_secret,
    "token"      => token }
end

# Lese und CRUD Operationen für ein Plugin (App) ==========
# Daten aus PIA lesen
def readItems(app, repo_url)
  if app.nil? | app == ""
      nil
  else
      headers = defaultHeaders(app["token"])
      url_data = repo_url + '?size=2000'
      response = HTTParty.get(url_data,
                              headers: headers).parsed_response
      if response.nil? or 
         response == "" or
         response.include?("error")
          nil
      else
          response
      end
  end
end

# Daten in PIA schreiben
def writeItem(app, repo_url, item)
  headers = defaultHeaders(app["token"])
  data = item.to_json
  response = HTTParty.post(repo_url,
                           headers: headers,
                           body: data)
  response
end

# Daten in PIA aktualisieren
def updateItem(app, repo_url, item, id)
  headers = defaultHeaders(app["token"])
  data = id.merge(item).to_json
  response = HTTParty.post(repo_url,
                           headers: headers,
                           body: data)
  response    
end

# Daten in PIA löschen
def deleteItem(app, repo_url, id)
  headers = defaultHeaders(app["token"])
  url = repo_url + '/' + id.to_s
  response = HTTParty.delete(url,
                             headers: headers)
  response
end

# create digest
def createDigest(items, fields)
  if !items.nil?
    items.each do |element|
      myMerge = ""
      fields.each do |field|
        myMerge = myMerge + element[field.to_s].to_s + ","
      end
      element[:digest] = Digest::SHA2.hexdigest myMerge
    end
  else
    []
  end
end

# Setup
myApp = setupApp(PIA_URL, APP_ID, APP_SECRET)
myUrl = itemsUrl(myApp["url"], REPO)

# read all existing items
piaItems = readItems(myApp, myUrl)

# process all input items according to "map"
newItems = Array.new
jsonInput.each do |element|
  myData = {}
  MAP.each do |pair|
    myKey = pair.keys[0].to_s
    myVal = element
    myValList = pair.values[0].to_s.split('|')
    myValList.each do |sub|
      myVal = myVal[sub]
    end
    case myKey
    when 'date'
      myData.store("date", Date.parse(myVal).strftime("%F"))
    else
      myData.store(myKey, myVal)
    end
  end
  newItems << myData
end

if MERGE.nil?
  newItems.each do |element|
    writeItem(myApp, myUrl, element)
  end
else
  # find all hashes in newItems that are not already in piaItems
  piaDigest = createDigest(piaItems, MERGE).map{ |x| x[:digest] }
  newDigest = createDigest(newItems, MERGE)
  newDigest.each do |element|
    if !piaDigest.include? element[:digest]
      writeItem(myApp, myUrl, element.except(:digest))
    end
  end
end

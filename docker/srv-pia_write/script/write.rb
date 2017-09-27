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
  opts.on('-c', '--config JSON', 'Konfiguration zum Speichern im Datentresor') { |v| options[:config] = v }
end.parse!

if options[:config].nil?
  puts "Error: fehldende Zugangsdaten"
  abort
end

begin
  config = JSON.parse(options[:config])
rescue JSON::ParserError => e
  puts "Error: ungültiges Konfigurations-JSON"
  abort
end

delete_all = false

if config["url"].nil?
  puts "Error: fehlende Url"
  abort
end
if config["key"].nil?
  puts "Error: fehlender Key"
  abort
end
if config["secret"].nil?
  puts "Error: fehlendes Secret"
  abort
end
if config["repo"].nil?
  puts "Error: fehlendes Repo"
  abort
end
if config["map"].nil?
  puts "Error: fehlendes Mapping"
  abort
end
if !config["delete"].nil?
  if config["delete"] == 'all'
    delete_all = true
  else
    puts "Error: ungültiger Wert für 'delete'"
    abort
  end
end

PIA_URL = config["url"]
APP_ID = config["key"]
APP_SECRET = config["secret"]
REPO = config["repo"]
REPONAME = config["repoName"]
PARTIAL = config["partial"]
MERGE = config["merge"]
MAP = config["map"]

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
                              headers: headers)
      response_parsed = response.parsed_response
      if response_parsed.nil? or 
         response_parsed == "" or
         response_parsed.include?("error")
          nil
      else
          recs = response.headers["x-total-count"].to_i
          if recs > 2000
              (1..(recs/2000.0).floor).each_with_index do |page|
                  url_data = repo_url + '?page=' + page.to_s + '&size=2000'
                  subresp = HTTParty.get(url_data,
                                         headers: headers).parsed_response
                  response_parsed = response_parsed + subresp
              end
              response_parsed
          else
              response_parsed
          end
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

# alle Daten einer Liste (Repo) löschen
def deleteRepo(app, repo_url)
  allItems = readItems(app, repo_url)
  if !allItems.nil?
    allItems.each do |item|
      deleteItem(app, repo_url, item["id"])
    end
  end
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
  doImport = true
  begin
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
    if element["_oydRepoName"].nil?
      if !(REPONAME.nil? or REPONAME == '')
        myData.store("_oydRepoName", REPONAME)
      end
    else
      myData.store("_oydRepoName", element["_oydRepoName"])
    end
  rescue
    doImport = false
  end
  if doImport
    newItems << myData
  end
end

if delete_all
  deleteRepo(myApp, myUrl)
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

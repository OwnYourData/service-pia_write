# ruby write.rb -c '{"url":"http://192.168.1.134:8080","key":"eu.ownyourdata.sample","secret":"eK6PWldcDTqarRfLCerm"}'

require 'httparty'
require 'optparse'
require 'json'

# parsing arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: write.rb [options]"
  opts.on('-c', '--credentials JSON', 'Zugangsdaten für Datentresor') { |v| options[:credentials] = v }
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
  puts "Error: fehlende URL"
  abort
end
if ji["key"].nil?
  puts "Error: fehlender KEY"
  abort
end
if ji["secret"].nil?
  puts "Error: fehlendes SECRET"
  abort
end

PIA_URL = ji["url"]
APP_ID = ji["key"]
APP_SECRET = ji["secret"]

# reading stdin
input = ARGF.read
begin
  ip = JSON.parse(input)
rescue JSON::ParserError => e
  puts "Error: ungültiges Input-JSON"
  abort
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

# Setup
myApp = setupApp(PIA_URL, APP_ID, APP_SECRET)
myUrl = itemsUrl(myApp["url"], "eu.ownyourdata.sample")

# write each element
ip.each do |element|
  myData = { "date":            Date.parse(element["date"]).strftime("%F"),
             "description":     element["description"]["desc1"],
             "descriptionOrig": element["description"]["original"],
             "value":           element["amount"] }
  writeItem(myApp, myUrl, myData) 
end

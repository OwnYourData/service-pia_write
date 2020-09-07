#!/usr/bin/env ruby
# encoding: utf-8

require 'optparse'
require 'httparty'
require 'rbnacl'

def defaultHeaders(token)
    { 'Accept' => '*/*',
      'Content-Type' => 'application/json',
      'Authorization' => 'Bearer ' + token.to_s }
end

def getToken(pia_url, app_key, app_secret)
    auth_url = pia_url.to_s + "/oauth/token"
        response_nil = false
    begin
        response = HTTParty.post(auth_url,
            headers: { 'Content-Type' => 'application/json' },
            body: { client_id: app_key, client_secret: app_secret,
                    grant_type: "client_credentials" }.to_json )
    rescue => ex
        response_nil = true
    end
    if !response_nil && !response.body.nil? && response.code == 200
        return response.parsed_response["access_token"].to_s
    else
        nil
    end
end

def setupApp(pia_url, app_key, app_secret)
    token = getToken(pia_url, app_key, app_secret)
    { :pia_url    => pia_url,
      :app_key    => app_key,
      :app_secret => app_secret,
      :token      => token }
end

def getWriteKey(app, repo)
    headers = defaultHeaders(app[:token])
    repo_url = app[:pia_url] + '/api/repos/' + repo + '/pub_key'
    response = HTTParty.get(repo_url, headers: headers).parsed_response
    if response.key?("public_key")
        response["public_key"]
    else
        nil
    end
end

def encrypt_message(message, public_key)
    authHash = RbNaCl::Hash.sha256('auth'.force_encoding('ASCII-8BIT'))
    auth_key = RbNaCl::PrivateKey.new(authHash)
    box = RbNaCl::Box.new(public_key, auth_key)
    nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)
    msg = message.force_encoding('ASCII-8BIT')
    cipher = box.encrypt(nonce, msg)

    { "value" => cipher.unpack('H*')[0],
      "nonce" => nonce.unpack('H*')[0],
      "version" => "0.4" }
end

options = {}
options[:pia_url] = "https://data-vault.eu"
options[:repo] = "oyd.settings"
op = OptionParser.new do |opts|
    opts.banner = "Usage: echo -n '{\"a\": 1}' | encrypt.rb [options]"
    opts.on('-u', '--pia-url [URL]', 'Data Vault URL (default: https://data-vault.eu)') {
        |v| options[:pia_url] = v }
    opts.on('-k', '--app-key KEY', 'Client ID from plugin') {
        |v| options[:app_key] = v }
    opts.on('-s', '--app-secret SECRET', 'Client Secret from plugin') {
        |v| options[:app_secret] = v }
    opts.on('-r', '--repo [REPO]', 'Repo identfier (default: oyd.settings)') {
        |v| options[:repo] = v }
end.parse!
raw_input = ARGF.readlines.join("\n")
if options[:app_key].to_s == "" || options[:app_secret].to_s == "" || raw_input.to_s == ""
    puts op
    abort("Error: missing input and/or parameters")
end
app = setupApp(options[:pia_url],
               options[:app_key],
               options[:app_secret])
if app[:token].to_s == ""
    abort("Error: invalid url and/or credenials")
end
pubkey_string = getWriteKey(app, options[:repo])
pubkey = [pubkey_string].pack('H*')

puts encrypt_message(raw_input, pubkey).to_json
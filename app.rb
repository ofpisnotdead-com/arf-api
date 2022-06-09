require 'rack'
require 'json'
require 'monitor'
require 'open-uri'
require 'logger'

API_URL = ENV.fetch('ARF_API_URL')
EXPIRE = 60 * 1 # 1 minute in seconds
LOGGER = Logger.new($stdout)

class App
  HEADERS = {
    'Access-Control-Allow-Origin' => '*',
    'Content-Type' => 'application/json'
  }

  def initialize
    @db = {}
    @db_updated = nil

    reload_db
  end

  def reload_db
    LOGGER.info 'servers updated'
    @db = JSON.parse(URI.open(API_URL).read) 
    @db_updated_at = Time.now
  end

  def db_expired?
    return true if @db_updated_at.nil?

    (Time.now - @db_updated_at) > EXPIRE
  end

  def db
    reload_db if db_expired?
    @db
  end

  def find_by_address(address)
    db['data'].find { |server| server['address'] == address }
  end

  def find_by_id(id)
    db['data'].find { |server| server['id'] == id }
  end

  def add_timestamp(result)
    result.merge(updated_at: @db['updated_at'])
  end

  def call(env)
    path = env["PATH_INFO"].delete('/')

    if path.empty?
      return [400, HEADERS, [{'error' => 'invalid query, add server ID or IP:PORT to url address'}.to_json]]
    end

    result = find_by_address(path) || find_by_id(path)

    if result
      [200, HEADERS, [add_timestamp(result).to_json]]
    else
      [404, HEADERS, [{'error' => ":( No server with ID/IP:PORT of '#{path}' found."}.to_json]]
    end
  rescue Exception => e
    [500, HEADERS, [{'error' => 'unexpected error'}.to_json]]
  end
end

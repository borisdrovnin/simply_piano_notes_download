require 'json'
require 'open-uri'
require 'fileutils'
require 'tempfile'

require 'faraday'
require 'zip'

conn = Faraday.new(
  url: 'https://asla.joytunes.com',
  headers: {'Content-Type' => 'application/json'}
)

response = conn.post('/server/asla/play/getDlc') do |req|
  req.body = '{
    "abTests": "",
    "appBundleID": "com.joytunes.asla.android",
    "appVersion": "4913",
    "country": "RU",
    "deviceID": "11d3571a-736a-47f5-9b87-488042791a84",
    "deviceType": "Redmi Note 7",
    "downloadZipFromCDN": true,
    "firstRun": false,
    "locale": "ru",
    "osVersion": "11",
    "zipVersion": 1644492317
  }'
end

assets = nil
songs_wide = nil
songs_compact = nil
dlc_url = response.headers['Zip-Url']
dlc_file = Tempfile.new('dlc.zip')

dlc_file.write(Faraday.get(dlc_url).body)
# dlc_file.write(File.read('dlc (2).zip'))
dlc_file.rewind

Zip::File.open(dlc_file.path) do |zip_file|
  big_file = zip_file.glob('BigFilesMD5s.json').first.get_input_stream.read
  assets = JSON.parse(big_file)
  songs_file = zip_file.glob('Songs.config.json').first.get_input_stream.read
  songs_wide = JSON.parse(songs_file)['songs']
  songs_file_compact = zip_file.glob('Compact.Songs.config.json').first.get_input_stream.read
  songs_compact = JSON.parse(songs_file_compact)['songs']
end

def generate_select_data(songs, assets, type)
  songs.each_with_object([]) do |(key, song), memo|
    artist = song['artistDisplayName']
    name = song['displayName']

    arrangements = song['arrangements'].each_with_object([]) do |(diff, arr), arr_memo|
      id = arr.sub('.lsmarr.json', '')
      hash = assets["#{id}.png"]
      arr_memo << {
        id: id,
        text: diff,
        hash: hash
      }
    end

    memo << {
      id: "#{key}#{type}",
      text: "#{artist} #{name} #{type}",
      arrangements: arrangements
    }
  end
end

select_data = []
select_data += generate_select_data(songs_compact, assets, ' Compact')
select_data += generate_select_data(songs_wide, assets, '')

File.write('select_data.json', select_data.to_json)

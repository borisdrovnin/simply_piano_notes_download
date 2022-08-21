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
dlc_file.binmode
dlc_file.write(Faraday.get(dlc_url).body)
dlc_file.rewind

Zip::File.open(dlc_file.path) do |zip_file|
  big_file = zip_file.glob('BigFilesMD5s.json').first.get_input_stream.read
  assets = JSON.parse(big_file)
  songs_file = zip_file.glob('Songs.config.json').first.get_input_stream.read
  songs_wide = JSON.parse(songs_file)['songs']
  songs_file_compact = zip_file.glob('Compact.Songs.config.json').first.get_input_stream.read
  songs_compact = JSON.parse(songs_file_compact)['songs']
end

dlc_file.unlink

def generate_select_data(songs_index, songs, assets, compact)
  songs.each do |key, song|
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

    songs_index[key] ||= {
      id: key,
      text: "#{artist} #{name}".strip
    }

    if compact
      songs_index[key][:arrangements] ||= []
      songs_index[key][:arrangements_compact] = arrangements.sort_by { |arr| arr[:text] }
    else
      songs_index[key][:arrangements] = arrangements.sort_by { |arr| arr[:text] }
      songs_index[key][:arrangements_compact] ||= []
    end
  end
end

songs_index = {}
generate_select_data(songs_index, songs_compact, assets, true)
generate_select_data(songs_index, songs_wide, assets, false)

File.write('select_data.json', songs_index.values.sort_by { |song| song[:text] }.to_json)

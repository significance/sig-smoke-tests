# quick and dirty, no deps, `gem install byebug` for debugging purposes!

require 'json'
# require 'byebug'

TIMEOUT = 10000
TOTAL = 500
VERBOSE = true
UP = 'http://localhost:8083'
DOWN = 'http://localhost:8083'

SIZE = 1024

RETRY_WAIT = 5
MAX_TRIES = 5

@retry_cmds = []

def get h, filepath_out, md5, tries = 0
  beginning_time = Time.now
  cmd = "curl -s --connect-timeout #{TIMEOUT} -m #{TIMEOUT} -s #{DOWN}/files/#{h}  > #{filepath_out} && cat #{filepath_out} | md5"
  r = `#{cmd}`
  end_time = Time.now
  time2 = ((end_time - beginning_time)*1000).to_i
  if r == md5
    puts "Retrieved in #{time2} ms - #{h} #{r}" if VERBOSE
    return [h, time2]
  elsif tries < MAX_TRIES
    rr = `cat #{filepath_out} | md5`
    puts "Error retrieving #{h} after #{tries+1} tries in #{time2}ms: #{rr.strip.chomp}" if VERBOSE 
    puts "Waiting #{RETRY_WAIT}s" if VERBOSE 
    sleep RETRY_WAIT
    return get h, filepath_out, md5, tries + 1
  else
    rr = `cat #{filepath_out} | md5`
    puts "Error retrieving #{h} after #{tries+1} tries in #{time2}ms: #{rr.strip.chomp}" if VERBOSE 
    puts "cmd to retry: #{cmd}"
    @retry_cmds.push cmd
    return false
  end
end

def post filepath_in, md5, tries = 0
  begin
    beginning_time = Time.now
    cmd = "curl --connect-timeout #{TIMEOUT} -m #{TIMEOUT} -s #{UP}/files -F file=@#{filepath_in} "
    resp = `#{cmd}`
    h = JSON.parse(resp)["reference"]
    end_time = Time.now
    time1 = ((end_time - beginning_time)*1000).to_i
    puts "Posted #{h} in #{time1} ms" if VERBOSE
    return [h, time1, tries]
  rescue Exception => e
    if tries < MAX_TRIES
      puts "Error posting after #{tries+1} tries in #{time1}ms: #{resp.strip.chomp}" if VERBOSE 
      puts "Waiting #{RETRY_WAIT}s" if VERBOSE 
      sleep RETRY_WAIT
      return post filepath_in, md5, tries + 1
    else
      rr = `cat #{filepath_out}`
      puts "Error posting #{h} after #{tries+1} tries in #{time1}ms: #{resp.strip.chomp}" if VERBOSE 
      puts "cmd to retry: #{cmd}"
      @retry_cmds.push cmd
      return false
    end
  end
end

i = 0
datas = []
puts "up - #{UP} // down - #{DOWN}"
puts "timeout - #{TIMEOUT} // total - #{TOTAL} // size - #{SIZE}"
while i<TOTAL

  puts "processing #{i}/#{TOTAL}"

  data = Random.new.rand(100000000000000000000000000)

  filepath_in = "/tmp/#{data}-i.txt"
  filepath_out = "/tmp/#{data}-o.txt"

  md5 = `head -c #{SIZE} < /dev/urandom > #{filepath_in} && cat #{filepath_in} | md5`

  puts "created file #{filepath_in} with digest #{md5}"

  r = post filepath_in, md5

  if r != false
    h = r[0]
    time1 = r[1]
    tries = r[2]
  else
    time1 = false
  end

  sleep 1

  r2 = get h, filepath_out, md5

  if r2 != false
    h = r2[0]
    time2 = r2[1]
    tries = r2[2]
  else
    time2 = false
  end

  i = i+1
  datas.push([time1,time2,tries])
end

puts "\nRESULTS ------\n\n"

puts "#{datas.count} processed in total"
ds = datas.reject{|d| d[1] === false}.count
puts "#{ds}/#{TOTAL} completed successfully"
ds = datas.reject{|d| d[2] == nil}
puts "#{ds.count}/#{TOTAL} required retries"


limits = [100,200,500,1000,1500,3000,5000,10000]

limits.each_with_index do |l,i| 
  if i == 0
    ll = 0
  else
    ll = limits[i-1]
  end
  ds = datas.select{|d| ll < d[0] and d[0] < l}.count 
  if ds>0
    puts "#{ds} POST requests #{ll}-#{l} ms"
  end
end

limits.each_with_index do |l,i| 
  if i == 0
    ll = 0
  else
    ll = limits[i-1]
  end
  ds = datas.reject{|d| d[1] == false}.select{|d| ll < d[1] and d[1] < l}.count 
  if ds>0
    puts "#{ds} GET requests #{ll}-#{l} ms"
  end
end
# frozen_string_literal: true
require 'json'
require 'fileutils'
require 'set'
require 'concurrent'

$LOAD_PATH.unshift(File.expand_path('../collector/lib', __dir__))
require 'publikes/environment'
require 'publikes/enumerate'

class TakeoutSync
  MAX_PENDING = 64

  def initialize(target_dir:, env:, threads: 8, max_pending: MAX_PENDING)
    @target_dir = target_dir
    @env = env
    @pool = Concurrent::FixedThreadPool.new(threads)
    @max_pending = max_pending

    @pending_futures = []
    @pending_mutex = Mutex.new
    @pending_count = Concurrent::AtomicFixnum.new(0)
    @shutting_down = false

    @jsonl_indexes = Concurrent::Map.new  # year_month => Concurrent::Set of status IDs
    @jsonl_writers = Concurrent::Map.new  # year_month => { queue:, thread: }

    @errors_mutex = Mutex.new
    @errors_file = File.join(@target_dir, 'errors.jsonl')

    @statuses_synced = Concurrent::AtomicFixnum.new(0)
    @media_downloaded = Concurrent::AtomicFixnum.new(0)

    FileUtils.mkdir_p(File.join(@target_dir, 'tweets'))
    FileUtils.mkdir_p(File.join(@target_dir, 'media'))
  end

  attr_reader :env

  def run
    setup_signal_handlers

    enumerator = Publikes::Enumerate.new(environment: env)
    enumerator.each_batch do |batch, page_ids|
      break if @shutting_down

      page_ids.each do |page_id|
        break if @shutting_down

        drain_pending(@max_pending)
        submit do
          process_page(page_id)
        end
      end
    end
  ensure
    $stderr.puts "Waiting for #{@pending_count.value} pending tasks to finish..." if @shutting_down
    drain_pending_all
    shutdown_writers
    $stderr.puts "Done: #{@statuses_synced.value} statuses synced, #{@media_downloaded.value} media files downloaded"
  end

  private

  def setup_signal_handlers
    trap(:INT) do
      if @shutting_down
        $stderr.puts "\nForce exit"
        exit!(1)
      end
      @shutting_down = true
      $stderr.puts "\nInterrupted, waiting for in-flight tasks to complete... (^C again to force exit)"
    end
    trap(:TERM) do
      @shutting_down = true
      $stderr.puts "\nTerminated, waiting for in-flight tasks to complete..."
    end
  end

  def submit(&block)
    @pending_count.increment
    future = Concurrent::Promises.future_on(@pool) do
      block.call
    ensure
      @pending_count.decrement
    end
    @pending_mutex.synchronize { @pending_futures << future }
  end

  def drain_pending(threshold)
    loop do
      futures = @pending_mutex.synchronize do
        @pending_futures.reject!(&:resolved?)
        break if @pending_futures.empty?
        @pending_futures.dup if @pending_futures.size >= threshold
      end
      break unless futures

      $stderr.puts "  backpressure: #{futures.size} pending (threshold: #{threshold})" if threshold > 0
      Concurrent::Promises.any(*futures).wait
    end
  end

  def drain_pending_all
    loop do
      futures = @pending_mutex.synchronize do
        @pending_futures.reject!(&:resolved?)
        break if @pending_futures.empty?
        @pending_futures.dup
      end
      break unless futures

      Concurrent::Promises.any(*futures).wait
    end
  end

  def process_page(page_id)
    page = JSON.parse(
      env.s3.get_object(bucket: env.s3_bucket, key: "data/public/pages/#{page_id}.json").body.read,
      symbolize_names: true,
    )

    page_created = page[:created_at] ? Time.at(page[:created_at]) : nil
    $stderr.puts "Page #{page[:id]} (#{page_created}): #{page[:statuses]&.size || 0} statuses"

    new_count = 0
    (page[:statuses] || []).each do |entry|
      status_id = entry[:id].to_s
      ts = entry[:ts]
      year_month = Time.at(ts).strftime('%Y-%m')

      next if known_id?(year_month, status_id)

      process_status(status_id, ts, year_month)
      new_count += 1
    end

    $stderr.puts "  -> #{new_count} new statuses to fetch" if new_count > 0
  end

  def process_status(status_id, ts, year_month)
    tweet_data = fetch_status(status_id)
    unless tweet_data
      append_error(type: 'status_not_found', status_id: status_id, ts: ts)
      return
    end

    media_index = fetch_media_index(status_id)

    screen_name = tweet_data.dig(:fxtwitter_data, :tweet, :author, :screen_name)
    push_to_writer(year_month, status_id, { tweet: tweet_data, media: media_index, ts: ts })
    synced = @statuses_synced.increment
    $stderr.puts "  #{status_id} @#{screen_name} (pending: #{@pending_count.value}, synced: #{synced})"

    download_media(status_id, tweet_data, media_index)
  end

  def fetch_status(status_id)
    JSON.parse(
      env.s3.get_object(bucket: env.s3_bucket, key: "data/private/statuses/#{status_id}.json").body.read,
      symbolize_names: true,
    )
  rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
    nil
  end

  def fetch_media_index(status_id)
    JSON.parse(
      env.s3.get_object(bucket: env.s3_bucket, key: "data/private/media/#{status_id}/index.json").body.read,
      symbolize_names: true,
    )
  rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
    nil
  end

  def download_media(status_id, tweet_data, media_index)
    return unless media_index && media_index[:media]

    tweet_ts = tweet_data.dig(:fxtwitter_data, :tweet, :created_timestamp)
    media_ym = tweet_ts ? Time.at(tweet_ts).strftime('%Y-%m') : Time.now.strftime('%Y-%m')
    screen_name = tweet_data.dig(:fxtwitter_data, :tweet, :author, :screen_name) || 'unknown'
    tweet_id = tweet_data.dig(:fxtwitter_data, :tweet, :id) || status_id

    media_dir = File.join(@target_dir, 'media', media_ym)
    FileUtils.mkdir_p(media_dir)

    media_index[:media].each do |entry|
      filename = entry[:filename]
      next unless filename

      s3_key = entry[:key] || "data/private/media/#{status_id}/#{filename}"
      local_path = File.join(media_dir, "#{screen_name}.#{tweet_id}.#{filename}")

      next if File.exist?(local_path)

      tmp_path = "#{local_path}.tmp"
      begin
        File.open(tmp_path, 'wb') do |f|
          env.s3.get_object(bucket: env.s3_bucket, key: s3_key, response_target: f)
        end
        File.rename(tmp_path, local_path)
        @media_downloaded.increment
      rescue => e
        File.delete(tmp_path) if File.exist?(tmp_path)
        append_error(type: 'media_download_failed', status_id: status_id, key: s3_key, message: e.message)
      end
    end
  end

  # --- JSONL index and writer management ---

  def known_id?(year_month, status_id)
    index = @jsonl_indexes.compute_if_absent(year_month) { load_jsonl_index(year_month) }
    index.include?(status_id)
  end

  def load_jsonl_index(year_month)
    ids = Concurrent::Set.new
    path = jsonl_path(year_month)
    if File.exist?(path)
      File.foreach(path) do |line|
        begin
          obj = JSON.parse(line, symbolize_names: true)
          id = obj.dig(:tweet, :id)
          ids.add(id.to_s) if id
        rescue JSON::ParserError
          # skip malformed lines
        end
      end
    end
    ids
  end

  def push_to_writer(year_month, status_id, data)
    writer = @jsonl_writers.compute_if_absent(year_month) { start_writer(year_month) }
    writer[:queue].push([status_id, data])
  end

  def start_writer(year_month)
    queue = Thread::Queue.new
    thread = Thread.new do
      File.open(jsonl_path(year_month), 'a') do |f|
        while (item = queue.pop)
          status_id, data = item
          f.puts(JSON.generate(data))
          f.flush
          @jsonl_indexes[year_month]&.add(status_id)
        end
      end
    end
    { queue: queue, thread: thread }
  end

  def shutdown_writers
    @jsonl_writers.each_pair do |_, w|
      w[:queue].close
      w[:thread].join
    end
  end

  def jsonl_path(year_month)
    File.join(@target_dir, 'tweets', "#{year_month}.jsonl")
  end

  # --- Error logging ---

  def append_error(error)
    @errors_mutex.synchronize do
      File.open(@errors_file, 'a') do |f|
        f.puts(JSON.generate(error: error))
      end
    end
  end
end

# --- Main ---

target_dir = ARGV[0] || abort("Usage: ruby takeout.rb TARGET_DIR")
s3_bucket = ENV.fetch('S3_BUCKET')
threads = (ENV['THREADS'] || '8').to_i
max_pending = (ENV['MAX_PENDING'] || '64').to_i

env = Publikes::Environment.new(s3_bucket: s3_bucket)
sync = TakeoutSync.new(target_dir: target_dir, env: env, threads: threads, max_pending: max_pending)
sync.run

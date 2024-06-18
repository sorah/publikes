#!/usr/bin/env ruby
require 'aws-sdk-s3'
require 'fileutils'
require 'securerandom'
require 'digest/md5'
require 'logger'
require 'thread'

$stdout.sync = true

CACHE_CONTROLS = {
  'font/woff2' => 'max-age=31536000',
  'text/css; charset=utf-8' => 'max-age=31536000',
  'text/javascript; charset=utf-8' => 'max-age=31536000',
  'text/plain; charset=utf-8' => 'public, must-revalidate, max-age=0, s-maxage=0',
  'text/html; charset=utf-8' => 'max-age=0, s-maxage=31536000',
  'application/json; charset=utf-8' => 'public, must-revalidate, max-age=0, s-maxage=0',
  'image/webp' => 'public, must-revalidate, max-age=0, s-maxage=0',
  'image/svg+xml' => 'public, must-revalidate, max-age=0, s-maxage=0',
}

bucket = ARGV[0]
cloudfront_distribution_id = ARGV[1]
prefix ="ui/"
@s3 = Aws::S3::Client.new(logger: Logger.new($stdout))

abort "usage: #$0 bucket [cloudfornt_distribution_id]" unless bucket

srcdir = File.join(__dir__,"dist")

publicdir = File.join(__dir__,"public")
Dir[File.join(publicdir, "**", '*')].each do |path|
  key = "#{path[(publicdir.size + File::SEPARATOR.size)..-1].split(File::SEPARATOR).join('/')}"
  dst = File.join(srcdir,key)
  FileUtils.mkdir_p(File.dirname(dst))
  p [:cp, path, dst]
  File.write "#{dst}", File.read(path)
end

indexhtml = File.read(File.join(srcdir,'index.html'))
%w(
).each do |path|
  dst = File.join(srcdir,path)
  FileUtils.mkdir_p(File.dirname(dst))
  File.write "#{dst}.html", indexhtml
end

Dir[File.join(srcdir, '**', '*')].each do |path|
  next if File.directory?(path)
  key = "#{prefix}#{path[(srcdir.size + File::SEPARATOR.size)..-1].split(File::SEPARATOR).join('/')}"
    .sub(/\.html$/,'')

  case path
  when File.join(srcdir, 'index.html')
    key = "#{prefix}index.html"
  end

  content_type = case path
                 when /\.txt$/
                   'text/plain; charset=utf-8'
                 when /\.html$/
                   'text/html; charset=utf-8'
                 when /\.js$/
                   'text/javascript; charset=utf-8'
                 when /\.css$/
                   'text/css; charset=utf-8'
                 when /feed\.xml$/
                   'application/atom+xml; charset=utf-8'
                 when /\.json$/
                   'application/json; charset=utf-8'
                  when /\.woff2$/
                    'font/woff2'
                  when /\.webp$/
                    'image/webp'
                  when /\.svg$/
                    'image/svg+xml'
                 end

    cache_control = CACHE_CONTROLS[content_type]
    File.open(path,'r') do |io|
      @s3.put_object(
        bucket: bucket,
        key: key,
        content_type: content_type,
        cache_control: cache_control,
        body: io,
      )
    end
end

if cloudfront_distribution_id
  require 'aws-sdk-cloudfront'
  @cf = Aws::CloudFront::Client.new(region: 'us-east-1', logger: Logger.new($stdout))
  resp = @cf.create_invalidation(
    distribution_id: cloudfront_distribution_id,
    invalidation_batch: {
      paths: {
        quantity: 2,
        items: ['/', '/index.html'],
      },
      caller_reference: ENV['GITHUB_ACTION'] ? "#{ENV['GITHUB_ACTION']}_#{ENV['GITHUB_RUN_ID']}" : SecureRandom.hex(10),
    },
  )
  @cf.wait_until(:invalidation_completed, { distribution_id: cloudfront_distribution_id, id: resp.invalidation.id })
end

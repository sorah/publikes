# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "publikes-collector"
  spec.version = "0.0.1"
  spec.authors = ["Sorah Fukumori"]
  spec.email = ["her@sorah.jp"]

  spec.summary = "publikes collector"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "aws-sdk-s3"
  spec.add_dependency "aws-sdk-secretsmanager"
  spec.add_dependency "aws-sdk-sqs"
  spec.add_dependency "aws-sdk-states"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

source 'https://rubygems.org'

gem 'rails', '~>3.2' # otherwise 0.9.2 is installed
gem 'sqlite3', :group => :development
gem 'pg'

#View related stuff
gem 'jquery-rails'
gem 'bootstrap-sass'
gem 'haml-rails'
gem 'sass-rails'
gem 'prawn'

gem 'days360'

group :development do
  gem 'debugger'
end

group :test do
  gem 'cucumber'
  gem 'cucumber-rails', :require => false
  # database_cleaner is not required, but highly recommended
  gem 'database_cleaner'
  gem 'timecop'
  gem 'test-unit'
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'coffee-rails'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', :platforms => :ruby

  gem 'uglifier', '>= 1.0.3'
end



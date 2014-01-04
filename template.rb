# coding: utf-8
# Git: Initialize
git :init

append_file '.gitignore' do
<<-CODE
*.lock

# Ignore vendor bundle.
vendor/bundle
CODE
end

git add: "-A"
git commit: %Q{ -m 'Rails4 scaffold' }

# Helpers

def erb_to_haml(file)
  output_file = file.gsub(/\.erb$/, '.haml')
  create_file output_file, html_to_haml(file)
  remove_file file
end

# from https://github.com/RailsApps/rails-composer
def html_to_haml(source)
  begin
    html = open(source) {|input| input.binmode.read }
    Haml::HTML.new(html, :erb => true, :xhtml => true).render
  rescue RubyParser::SyntaxError
    say_wizard "Ignoring RubyParser::SyntaxError"
    # special case to accommodate https://github.com/RailsApps/rails-composer/issues/55
    html = open(source) {|input| input.binmode.read }
    say_wizard "applying patch" if html.include? 'card_month'
    say_wizard "applying patch" if html.include? 'card_year'
    html = html.gsub(/, {add_month_numbers: true}, {name: nil, id: "card_month"}/, '')
    html = html.gsub(/, {start_year: Date\.today\.year, end_year: Date\.today\.year\+10}, {name: nil, id: "card_year"}/, '')
    result = Haml::HTML.new(html, :erb => true, :xhtml => true).render
    result = result.gsub(/select_month nil/, "select_month nil, {add_month_numbers: true}, {name: nil, id: \"card_month\"}")
    result = result.gsub(/select_year nil/, "select_year nil, {start_year: Date.today.year, end_year: Date.today.year+10}, {name: nil, id: \"card_year\"}")
  end
end

# Localization

inject_into_file 'config/application.rb', "\n  config.autoload_paths += %W(#__{config.root}/lib)\n", after: 'class Application < Rails::Application'
gsub_file 'config/application.rb', '#__', '#'

create_file 'config/initializers/time_formats.rb' do
<<-CODE
Time::DATE_FORMATS[:default] = '%Y-%m-%d %H:%M:%S'
CODE
end

gsub_file 'config/application.rb', "# config.time_zone = 'Central Time (US & Canada)'", "config.time_zone = 'Tokyo'"
gsub_file 'config/application.rb', "# config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]", "config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]"
gsub_file 'config/application.rb', "# config.i18n.default_locale = :de" do
<<-CODE
config.i18n.enforce_available_locales = true
    config.i18n.default_locale = :ja
    config.i18n.fallbacks = true
CODE
end

remove_file "config/locales/en.yml"
get "https://raw.github.com/svenfuchs/rails-i18n/master/rails/locale/en.yml", "config/locales/en.yml"
get "https://raw.github.com/svenfuchs/rails-i18n/master/rails/locale/ja.yml", "config/locales/ja.yml"

git add: "-A"
git commit: %Q{ -m 'Localization' }


# Questions

app_long_name = ask "What is your Application name?"
company_name = ask "What is your Company name?"
install_oauth_provider = yes? "Install OAuth provider?"

# Gems

append_to_file 'Gemfile', "\nENV['NOKOGIRI_USE_SYSTEM_LIBRARIES'] = 'YES'"
gem 'nokogiri', '1.6.0'

gem 'unicorn'
gem 'haml-rails'
#gem 'mongoid', '~> 4', github: 'mongoid/mongoid'
gem 'mongoid', github: 'mongoid/mongoid'
gem 'haml-rails'
gem 'anjlab-bootstrap-rails', require: 'bootstrap-rails',
                              github: 'anjlab/bootstrap-rails'
gem 'devise', '~> 3.1.0.rc2'
gem 'cancan'
gem 'figaro'
gem 'rolify'
gem 'simple_form', github: 'plataformatec/simple_form'

gem_group :development do
  gem 'better_errors'
  gem 'binding_of_caller', platforms: [:mri_19, :mri_20, :rbx]
  gem 'guard-bundler'
  gem 'guard-cucumber'
  gem 'guard-rails'
  gem 'guard-rspec'
  gem 'html2haml'
  gem 'quiet_assets'
  gem 'rb-fchange', require: false
  gem 'rb-fsevent', require: false
  gem 'rb-inotify', require: false
end

gem_group :development, :test do
  gem 'debugger'
  gem 'factory_girl_rails'
  gem 'rspec-rails'
end

gem_group :test do
  gem 'capybara'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner', '1.0.1'
  gem 'email_spec'
  gem 'launchy'
  gem 'mongoid-rspec', '>= 1.6.0', github: 'evansagge/mongoid-rspec'
end


# Clean up Assets

# Use SASS extension for application.css
run "mv app/assets/stylesheets/application.css app/assets/stylesheets/application.css.scss"
# Remove the require_tree directives from the SASS and JavaScript files. 
# It's better design to import or require things manually.
run "sed -i '' /require_tree/d app/assets/javascripts/application.js"
run "sed -i '' /require_tree/d app/assets/stylesheets/application.css.scss"


# Configure generators for RSpec and FactoryGirl

app_generators_config = <<-CODE

    # don't generate RSpec tests for views and helpers
    config.generators do |g|
      g.test_framework :rspec, fixture: true
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
      g.view_specs false
      g.helper_specs false
    end
CODE

environment app_generators_config


# Install and configure gems

run 'bundle install'

generate 'scaffold', 'User', 'first_name:string', 'last_name:string'

generate 'figaro:install'
generate 'mongoid:config'
generate 'rspec:install'
generate 'cucumber:install'
generate 'cancan:ability'
generate 'simple_form:install', '--bootstrap'

gsub_file 'features/support/env.rb', /transaction/, "truncation"
inject_into_file 'features/support/env.rb', "\n  DatabaseCleaner.orm = 'mongoid'", after: 'begin'

gsub_file 'config/mongoid.yml', '# raise_not_found_error: true', 'raise_not_found_error: false'
gsub_file 'config/mongoid.yml', /database: .+_development/, "database: #{app_long_name}_development"
gsub_file 'config/mongoid.yml', /database: .+_test/, "database: #{app_long_name}_test"

# Configure RSpec
gsub_file 'spec/spec_helper.rb', /config.fixture_path/, '# config.fixture_path'
gsub_file 'spec/spec_helper.rb', /config.use_transactional_fixtures/, '# config.use_transactional_fixtures'

inject_into_file 'spec/spec_helper.rb', "\nrequire 'email_spec'", after: "require 'rspec/rails'"

inject_into_file 'spec/spec_helper.rb', after: "RSpec.configure do |config|" do
<<-CODE
\n
  config.include(EmailSpec::Helpers)
  config.include(EmailSpec::Matchers)
CODE
end

inject_into_file 'spec/spec_helper.rb', after: 'config.order = "random"' do
<<-CODE
\n
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end
  config.before(:each) do
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
  end
CODE
end

# Twitter Bootstrap
inject_into_file 'app/assets/javascripts/application.js', "\n//= require twitter/bootstrap", after: '//= require turbolinks'
inject_into_file 'app/assets/stylesheets/application.css.scss', " *= require twitter/bootstrap\n", before: ' */'


# Base layout in haml

remove_file 'app/views/layouts/application.html.erb'

create_file 'app/views/layouts/_messages.html.haml' do
<<-CODE
- flash.each do |name, msg|
  - if msg.is_a?(String)
    %div{class: "alert alert-\#{name == :notice ? "success" : "error"}"}
      %a.close{"data-dismiss" => "alert"} ×
      = content_tag :div, msg, id: "flash_\#{name}"
CODE
end

create_file 'app/views/layouts/_navigation.html.haml' do
<<-CODE
%nav.navbar.navbar-inverse{role: "navigation"}
  / Brand and toggle get grouped for better mobile display
  .navbar-header
    %button.navbar-toggle{"data-target" => ".navbar-ex8-collapse", "data-toggle" => "collapse", type: "button"}
      %span.sr-only Toggle navigation
      %span.icon-bar
      %span.icon-bar
      %span.icon-bar
    = link_to "#{app_long_name}", root_path, class: 'navbar-brand'
  / Collect the nav links, forms, and other content for toggling
  .collapse.navbar-collapse.navbar-ex8-collapse
    %ul.nav.navbar-nav
      %li
        %a{href: root_path} Home
      %li
        %a{href: users_path} Users
      %li
        %a{href: access_logs_path} AccessLogs
    %ul.nav.navbar-nav.navbar-right
      - if user_signed_in?
        %li
          = link_to 'Your account', edit_user_registration_path
        %li
          = link_to 'Logout', destroy_user_session_path, method: 'delete'
      - else
        %li
          = link_to 'Login', new_user_session_path
CODE
end

create_file 'app/views/layouts/application.html.haml' do
<<-CODE
!!!
%html
  %head
    %meta{content: "width=device-width, initial-scale=1.0", name: "viewport"}
      %title= content_for?(:title) ? yield(:title) : "#{app_long_name}"
      %meta{name:"viewport", content:"width=device-width, initial-scale=1.0"}
      %meta{content: content_for?(:description) ? yield(:description) : "#{app_long_name}", name: "description"}
        = stylesheet_link_tag "application", media: "all", "data-turbolinks-track" => true
        = javascript_include_tag "application", "data-turbolinks-track" => true
        = csrf_meta_tags
        = yield(:head)
  %body{class: "\#{controller_name} \#{action_name}"}
    %section.container
      = render 'layouts/navigation'
      \#main{role: "main"}
        .container
          .content
            .row
              .span12
                = render 'layouts/messages'
                = yield
            %footer
              %hr
                #{company_name} - © #{Time.now.year}
CODE
end

git add: "-A"
git commit: %Q{ -m 'configured gems' }


# add devise
generate 'devise:install'
generate 'devise', 'User'
generate 'devise:views'

require 'html2haml'
say "Converting Devise to yaml"
Dir["app/views/devise/**/*.erb"].each do |file|
  erb_to_haml(file)
end

inject_into_file 'app/controllers/application_controller.rb', "\n  before_filter :authenticate_user!\n", before: /^end/
get "https://raw.github.com/Junsuke/miscellaneous/master/devise.ja.yml", "config/locales/devise.ja.yml"

git add: "-A"
git commit: %Q{ -m 'add devise' }

generate :controller, 'home', 'index'
gsub_file 'config/routes.rb', 'get "home/index"', "root 'home#index'"
gsub_file 'config/routes.rb', 'devise_for :users', "devise_for :user"

# User

inject_into_file 'app/models/user.rb', "\n  include Mongoid::Timestamps", after: '  include Mongoid::Document'

inject_into_file 'app/views/users/index.html.haml', after: /^    %th Last name/ do
<<-CODE

    %th Email
    %th Sign in count
    %th Current sign in at
    %th Last sign in at
    %th Current sign in ip
    %th Last sign in ip
CODE
end
inject_into_file 'app/views/users/index.html.haml', after: /^      %td= user.last_name/ do
<<-CODE

      %td= user.email
      %td= user.sign_in_count
      %td= user.current_sign_in_at
      %td= user.last_sign_in_at
      %td= user.current_sign_in_ip
      %td= user.last_sign_in_ip
CODE
end

git add: "-A"
git commit: %Q{ -m 'add homepage view and root route' }

if install_oauth_provider
  gem 'doorkeeper', github: 'exabugs/doorkeeper'
  run 'bundle install'
  generate 'doorkeeper:install'
  gsub_file 'config/initializers/doorkeeper.rb', /orm :active_record/, 'orm :mongoid3'
  run "sed -i '' /raise/d config/initializers/doorkeeper.rb"
  inject_into_file 'config/initializers/doorkeeper.rb', "\n    current_user || warden.authenticate!(:scope => :user)", after: 'resource_owner_authenticator do'
  generate 'doorkeeper:views'
  say "Converting Devise to yaml"
  Dir["app/views/doorkeeper/**/*.erb"].each do |file|
    erb_to_haml(file)
  end
  git add: "-A"
  git commit: %Q{ -m 'add doorkeeper (OAuth provider for SSO)' }
end

# Initialize guard
run "bundle exec guard init rspec"


# CanCan

inject_into_file 'app/controllers/application_controller.rb', before: /^end/ do
<<-CODE

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end
CODE
end

git add: "-A"
git commit: %Q{ -m 'add guard' }

# AccessLog

generate 'scaffold', 'access_log', 'date:time', 'host:string', 'http:string', 'path:string', 'time:integer'

inject_into_file 'app/controllers/application_controller.rb', before: /^end/ do
<<-CODE

  around_filter :logging_filter

  def logging_filter

    time_a = Time.now
    ret = yield
    time_b = Time.now

    if user_signed_in?
      log = AccessLog.new
      log.date = time_a
      log.time = (time_b.to_r - time_a.to_r) * 1000
      log.path = request.original_fullpath
      log.http = request.request_method
      log.host = request.remote_ip
      log.user = current_user
      log.save
    end

    return ret
  end
CODE
end

inject_into_file 'app/models/access_log.rb', before: /^end/ do
<<-CODE
  belongs_to :user

  default_scope order_by(:date => :desc).limit(15)
CODE
end

gsub_file 'app/controllers/access_logs_controller.rb', 'AccessLog.all', 'AccessLog.includes(:user).all'
gsub_file 'app/views/access_logs/show.json.jbuilder', ', :created_at, :updated_at', ''
inject_into_file 'app/views/access_logs/index.html.haml', "\n    %th User", after: '%th Date'
inject_into_file 'app/views/access_logs/index.html.haml', "\n      %td= access_log.user.email", after: '%td= access_log.date'


git add: "-A"
git commit: %Q{ -m 'add access_log' }


# carrierwave

gem "mongoid-grid_fs", github: "ahoward/mongoid-grid_fs", branch: "master"
gem 'carrierwave', :git => "git://github.com/jnicklas/carrierwave.git"
gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
gem "rmagick", :require => false

run 'bundle install'

run 'rails g uploader photo'
#gsub_file 'app/uploaders/photo_uploader.rb', '# include CarrierWave::MiniMagick', 'include CarrierWave::MiniMagick'
gsub_file 'app/uploaders/photo_uploader.rb', '# include CarrierWave::RMagick', 'include CarrierWave::RMagick'
gsub_file 'app/uploaders/photo_uploader.rb', 'storage :file', 'storage :grid_fs'
gsub_file 'app/uploaders/photo_uploader.rb', 'uploads/#{model.class.to_s.underscore}', '#{model.class.to_s.underscore}'
inject_into_file 'app/models/user.rb', "\n  mount_uploader :photo, PhotoUploader\n", before: /^end/
gsub_file 'app/controllers/users_controller.rb', 'require(:user).permit(', 'require(:user).permit(:photo, '
inject_into_file 'config/routes.rb', "\n  get '/upload/grid/*path' => 'gridfs#serve'\n", after: /resources :users/

create_file 'config/initializers/carrierwave.rb' do
<<-CODE
CarrierWave.configure do |config|
  config.storage = :grid_fs
  config.grid_fs_access_url = "/upload/grid"
end
CODE
end

create_file 'app/controllers/gridfs_controller.rb' do
<<-CODE
class GridfsController < ActionController::Metal
  def serve
    gridfs_path = env["PATH_INFO"].gsub("/upload/grid/", "")
    begin
      gridfs_file = Mongoid::GridFS[gridfs_path]
      self.response_body = gridfs_file.data
      self.content_type = gridfs_file.content_type
    rescue
      self.status = :file_not_found
      self.content_type = 'text/plain'
      self.response_body = ''
    end
  end
end
CODE
end

inject_into_file 'app/views/users/_form.html.haml', after: "%li= msg\n\n" do
<<-CODE
  .field
    = f.label :photo
    = f.file_field :photo
CODE
end

inject_into_file 'app/views/users/show.html.haml', after: "%p#notice= notice\n\n" do
<<-CODE
%p
  %b Photo:
  =image_tag @user.photo.to_s
CODE
end

git add: "-A"
git commit: %Q{ -m 'add carrierwave' }

# Log

inject_into_file 'config/environments/development.rb', before: /^end/ do
<<-CODE

  Mongoid.logger.level = Logger::DEBUG
  Moped.logger.level = Logger::DEBUG
CODE
end

# for NetBeans
copy_file "bin/rails", "script/rails"

git add: "-A"
git commit: %Q{ -m 'modified for NetBeans' }


# Tweet

generate 'scaffold', 'tweet', 'type:integer', 'content:string'

inject_into_file 'app/views/layouts/_navigation.html.haml', after: /access_logs_path.*$/ do
<<-CODE

      %li
        %a{href: tweets_path} Tweets
CODE
end

git add: "-A"
git commit: %Q{ -m 'Add Tweet' }


# Natto

gem 'natto'
get "https://raw.github.com/exabugs/rails4-template/master/lib/misc/natto.rb", 'lib/misc/natto.rb'

inject_into_file 'app/models/tweet.rb', before: /^end/ do
<<-CODE
  
  field :similarity, type: Float
  field :tf, type: Hash

  before_save :before_save

  protected

  def before_save
    self.tf = Misc::Natto.tfidf(Tweet, self.content, 2)
  end
CODE
end

inject_into_file 'app/controllers/tweets_controller.rb', after: /^  before_action .*$/ do
<<-CODE


  def search
    @q = params[:q]
    @words = Misc::Natto.to_array(Misc::Natto.tf(@q, 1))
    @tweets = Misc::Natto.search(Tweet, @q)
    render "index"
    return
  end

  def similar_search
    @q = params[:q]
    @words = Misc::Natto.to_array(Misc::Natto.tf(@q, 1))
    @tweets = Misc::Natto.similar_search(Tweet, @q)
    render "index"
  end
CODE
end

inject_into_file 'config/routes.rb', after: /resources :tweets/ do
<<-CODE
 do
    collection { post :search }
    collection { post :similar_search }
  end
CODE
end

inject_into_file 'app/views/tweets/index.html.haml', after: /%h1 Listing tweets/ do
<<-CODE


%table
  %tr
    %td= "Full Search"
    %td
      = form_tag({:action => "search"}, {:class => "tweet"}) do
        = text_field_tag "q", @q
        = submit_tag "Search"
    %td= @words
  %tr
    %td= "Similar Search"
    %td
      = form_tag({:action => "similar_search"}, {:class => "tweet"}) do
        = text_field_tag "q", @q
        = submit_tag "Search"
    %td= @words
CODE
end

inject_into_file 'app/views/tweets/index.html.haml', "\n    %th Similarity", after: /%th Content/
inject_into_file 'app/views/tweets/index.html.haml', "\n      %td= tweet.similarity", after: /%td= tweet.content/
gsub_file 'app/views/tweets/index.html.haml', "tweet.content", "highlight(tweet.content, @words)"


git add: "-A"
git commit: %Q{ -m 'Add Tweet Search' }

inject_into_file 'app/controllers/access_logs_controller.rb', after: /before_action .*$/ do
<<-CODE

  def graph

    type = 3
    max = Time.now
    min = max - 60*60*12
    dim = 4
    bar = 3

    range = Misc::Counter.graph(AccessLog, min, max, type, dim)
    puts range

    graph = Misc::Graph.new(800, 600, 40)

    graph.line(range, dim, bar, type)

    send_data(graph.to_blob, :type => 'image/png', :disposition=>'inline')
  end

CODE
end

get "https://raw.github.com/exabugs/rails4-template/master/lib/misc/counter.rb", 'lib/misc/counter.rb'
get "https://raw.github.com/exabugs/rails4-template/master/lib/misc/image.rb", 'lib/misc/image.rb'
get "https://raw.github.com/exabugs/rails4-template/master/lib/misc/graph.rb", 'lib/misc/graph.rb'

inject_into_file 'config/routes.rb', after: /resources :access_logs/ do
<<-CODE
  get '/access_logs/graph(/:year(/:month(/:day)))'  => "access_logs#graph"
CODE
end

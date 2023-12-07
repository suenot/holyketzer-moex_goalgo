# config/puma.rb
threads 8, 8
workers 1

on_worker_boot do
  require "active_record"
  # cwd = File.dirname(__FILE__) + "/../.."
  cwd = File.absolute_path(File.join(`pwd`.strip(), "../.."))
  ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
  ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"] || YAML.load_file("#{cwd}/config/database.yml")["production"])
end

bind "unix://#{cwd}/tmp/sockets/puma_web.sock"
environment "production"
pidfile "#{cwd}/tmp/pids/server.pid"

# state_path "#{cwd}/tmp/sockets/puma.state"

rackup "#{cwd}/config.ru"

activate_control_app

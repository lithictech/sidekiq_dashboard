# inspiration from
# https://github.com/mperham/sidekiq/wiki/Monitoring#standalone-with-basic-auth

require 'sidekiq'

url = ENV.fetch('REDIS_URL','redis://localhost:6379')
redis_params = {url: url, size: 1}
if url.start_with?("rediss:") && ENV["HEROKU_APP_ID"]
  # rediss: schema is Redis with SSL. They use self-signed certs, so we have to turn off SSL verification.
  # There is not a clear KB on this, you have to piece it together from Heroku and Sidekiq docs.
  redis_params[:ssl_params] = {verify_mode: OpenSSL::SSL::VERIFY_NONE}
end

Sidekiq.configure_client do |config|
  config.redis = redis_params
end

require 'sidekiq/web'

map '/' do
  if ENV['USERNAME'] && ENV['PASSWORD']
    use Rack::Auth::Basic, "Protected Area" do |username, password|
      # Protect against timing attacks: (https://codahale.com/a-lesson-in-timing-attacks/)
      # - Use & (do not use &&) so that it doesn't short circuit.
      # - Use digests to stop length information leaking
      Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["USERNAME"])) &
        Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["PASSWORD"]))
    end
  end

  run Sidekiq::Web
end

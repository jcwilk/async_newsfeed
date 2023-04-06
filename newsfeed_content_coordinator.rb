require 'bundler/setup'

class NewsfeedContentCoordinator
  attr_reader :user_id, :redis

  def initialize(user_id, redis)
    @user_id = user_id
    @redis = redis
  end

  def generate_content_on_login
    content = generate_newsfeed_content
    redis.set(cache_key, content, ex: 30 * 60)
  end

  def request_newsfeed_content(timeout: 3)
    content = redis.get(cache_key)

    if content.nil?
      if redis.set(cache_key, "LOCK", ex: timeout, nx: true)
        content = generate_newsfeed_content
        redis.set(cache_key, content, ex: 30 * 60)
      else
        content = redis.brpoplpush(cache_key, "#{cache_key}:queue", timeout)
        redis.lpop("#{cache_key}:queue") unless content.nil?
      end
    end

    content
  end

  def handle_login_trigger
    return if redis.get(cache_key)

    generate_content_on_login
  end

  def cache_key
    "newsfeed_content:#{user_id}"
  end

  def generate_newsfeed_content
    # Replace this with your actual implementation for generating newsfeed content
    "personalized content for user #{user_id}"
  end
end

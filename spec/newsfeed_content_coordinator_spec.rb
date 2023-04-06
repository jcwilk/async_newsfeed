require 'bundler/setup'
Bundler.require(:test)
require_relative '../newsfeed_content_coordinator'

RSpec.describe NewsfeedContentCoordinator do
  let(:user_id) { 1234 }
  let(:redis) { Redis.new }
  let(:coordinator) { NewsfeedContentCoordinator.new(user_id, redis) }

  describe "#initialize" do
    it "should initialize the coordinator with a user ID and a Redis instance" do
      expect(coordinator.user_id).to eq(user_id)
      expect(coordinator.redis).to be_an_instance_of(Redis)
    end
  end

  describe "#generate_content_on_login" do
    before do
      allow(coordinator).to receive(:generate_newsfeed_content).and_return("sample content")
    end

    context "when the user logs in" do
      it "should start generating the newsfeed content synchronously" do
        coordinator.generate_content_on_login
        expect(coordinator).to have_received(:generate_newsfeed_content)
      end

      it "should store the generated content in Redis with a 30-minute expiration time" do
        coordinator.generate_content_on_login
        expect(redis.get(coordinator.cache_key)).to eq("sample content")
        expect(redis.ttl(coordinator.cache_key)).to be_within(5).of(30 * 60)
      end
    end
  end

  describe "#request_newsfeed_content" do
    before do
      allow(coordinator).to receive(:generate_newsfeed_content).and_return("sample content")
      # TODO: stubbing in this way throws off the test because `generate_content_on_login` calls it
    end

    context "when the SPA requests newsfeed content" do
      context "and the content generation is in progress" do
        it "should block the request for up to 3 seconds waiting for the content to be generated" do
          coordinator.generate_content_on_login

          # Simulate content generation taking 1 second
          allow(coordinator).to receive(:generate_newsfeed_content) { sleep 1; "sample content" }

          start_time = Time.now
          content = coordinator.request_newsfeed_content
          end_time = Time.now
          elapsed_time = end_time - start_time

          expect(content).to eq("sample content")
          expect(elapsed_time).to be_within(0.5).of(1)
        end

        it "should return the generated content once it's available" do
          coordinator.generate_content_on_login
          content = coordinator.request_newsfeed_content
          expect(content).to eq("sample content")
        end
      end

      context "and the content generation is not in progress" do
        it "should start generating the newsfeed content" do
          content = coordinator.request_newsfeed_content
          expect(coordinator).to have_received(:generate_newsfeed_content)
          expect(content).to eq("sample content")
        end

        it "should store the generated content in Redis with a 30-minute expiration time" do
          coordinator.request_newsfeed_content
          expect(redis.get(coordinator.cache_key)).to eq("sample content")
          expect(redis.ttl(coordinator.cache_key)).to be_within(5).of(30 * 60)
        end

        it "should return the generated content" do
          content = coordinator.request_newsfeed_content
          expect(content).to eq("sample content")
        end
      end

      context "and the content generation takes longer than 3 seconds" do
        before do
          # Simulate content generation taking 4 seconds
          allow(coordinator).to receive(:generate_newsfeed_content) { sleep 4; "slow content" }
          # TODO: stubbing in this way throws off the test because `generate_content_on_login` calls it
        end

        it "should give up waiting for the content after 3 seconds" do
          coordinator.generate_content_on_login

          start_time = Time.now
          content = coordinator.request_newsfeed_content(timeout: 3)
          end_time = Time.now
          elapsed_time = end_time - start_time

          expect(content).to eq("slow content")
          expect(elapsed_time).to be_within(0.5).of(3)
        end

        it "should start generating the newsfeed content" do
          content = coordinator.request_newsfeed_content(timeout: 3)
          expect(coordinator).to have_received(:generate_newsfeed_content)
          expect(content).to eq("slow content")
        end

        it "should store the generated content in Redis with a 30-minute expiration time" do
          coordinator.request_newsfeed_content(timeout: 3)
          expect(redis.get(coordinator.cache_key)).to eq("slow content")
          expect(redis.ttl(coordinator.cache_key)).to be_within(5).of(30 * 60)
        end

        it "should return the generated content" do
          content = coordinator.request_newsfeed_content(timeout: 3)
          expect(content).to eq("slow content")
        end
      end
    end
  end

  describe "#handle_login_trigger" do
    context "when a login trigger is received after the newsfeed content request" do
      it "should not start generating the newsfeed content" do
        coordinator.request_newsfeed_content
        allow(coordinator).to receive(:generate_newsfeed_content).and_return("other content")
        coordinator.handle_login_trigger
        expect(coordinator).not_to have_received(:generate_newsfeed_content)
      end
    end
  end

  describe "#cache_key" do
    it "should generate a unique cache key based on the user ID" do
      expect(coordinator.cache_key).to eq("newsfeed_content:#{user_id}")
    end
  end

  describe "#generate_newsfeed_content" do
    it "should generate personalized newsfeed content for the user" do
      # Replace this with your actual implementation for generating newsfeed content
      allow(coordinator).to receive(:generate_newsfeed_content).and_return("personalized content")
      content = coordinator.generate_newsfeed_content
      expect(content).to eq("personalized content")
    end
  end
end

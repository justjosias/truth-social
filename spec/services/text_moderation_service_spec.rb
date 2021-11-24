require 'rails_helper'

RSpec.describe TextModerationService, type: :service do
  subject { TextModerationService.new }
  let!(:alice)  { Fabricate(:account, user: Fabricate(:user)) }
  let!(:status)  { Fabricate(:status, text: "Some text here") }

  before do
    acct = Fabricate(:account, username: "ModerationAI")
    Fabricate(:user, admin: true, account: acct)
  end

  context "rating of 0" do
    before :example do
      stub_request(:post, ENV["MODERATION_TASK_API_URL"]).to_return(status: 200, body: request_fixture('moderation-response-0.txt'))
    end

    it 'create a moderation record' do
      subject.call(status)
      expect(status.reported?).to be_falsey
    end
  end

  context "rating of 1" do
    before :example do
      stub_request(:post, ENV["MODERATION_TASK_API_URL"]).to_return(status: 200, body: request_fixture('moderation-response-1.txt'))
    end

    it 'create a moderation record' do
      subject.call(status)

      expect(status.reported?).to be_truthy
    end
  end

  context "rating of 2" do
    before :example do
      stub_request(:post, ENV["MODERATION_TASK_API_URL"]).to_return(status: 200, body: request_fixture('moderation-response-2.txt'))
    end

    it 'sets ratings of 2 or higher to be "sensitive"' do
      subject.call(status)
      s = Status.find(status.id)

      expect(s.sensitive).to eq(true)
    end
  end

  context "rating of 3" do
    before :example do
      stub_request(:post, ENV["MODERATION_TASK_API_URL"]).to_return(status: 200, body: request_fixture('moderation-response-3.txt'))
    end

    it 'removes statuses with ratings of 3 or higher' do
      subject.call(status)

      expect(Status.where(id: status.id)).to_not exist
    end
  end
end

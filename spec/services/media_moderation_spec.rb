require 'rails_helper'

RSpec.describe MediaModerationService, type: :service do
  subject { MediaModerationService.new }
  let!(:alice)  { Fabricate(:account, user: Fabricate(:user)) }
  let!(:status) { Fabricate(:status, account: alice, text: 'Hi future!') }
  let!(:media) { Fabricate(:media_attachment, status: status) }

  before do
    acct = Fabricate(:account, username: "ModerationAI")
    Fabricate(:user, admin: true, account: acct)
  end

  context "sensitive imagery" do
    before :example do
      stub_request(:post, ENV["MODERATION_TASK_API_URL"]).to_return(status: 200, body: request_fixture('moderation-image-response.txt'))
    end

    it 'creates reports for content with ratings over a threshold' do
      subject.call(status.id, media.id)

      expect(ModerationRecord.where(media_attachment_id: media.id)).to exist
    end
  end

  context "imagery with inappropriate text overlaid" do
    before :example do
      stub_request(:post, ENV["MODERATION_TASK_API_URL"])
        .to_return(status: 200, body: request_fixture('moderation-textual-image-response.txt'))
        .to_return(status: 200, body: request_fixture('moderation-ocr-response.txt'))
    end

    it 'creates textual moderation reports for images with text' do
      # post an image with naughty language
      # get response back from moderation
      subject.call(status.id, media.id)
      # since moderation says it has text find out what the text says
      expect(ModerationRecord.where(media_attachment_id: media.id)).to exist
      # then analyze the text for content
      # when naughty mark as sensitive or remove
      expect(Status.where(id: status.id)).to_not exist
    end
  end
end

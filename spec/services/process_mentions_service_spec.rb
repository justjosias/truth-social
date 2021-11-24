require 'rails_helper'

RSpec.describe ProcessMentionsService, type: :service do
  let(:account)    { Fabricate(:account, username: 'alice') }
  let(:visibility) { :public }
  let(:status)     { Fabricate(:status, account: account, text: "Hello @#{remote_user.acct}", visibility: visibility) }

  subject { ProcessMentionsService.new }

  context 'ActivityPub' do
    context 'with an IDN domain' do
      let(:remote_user) { Fabricate(:account, username: 'sneak', protocol: :activitypub, domain: 'xn--hresiar-mxa.ch', inbox_url: 'http://example.com/inbox') }
      let(:status) { Fabricate(:status, account: account, text: "Hello @sneak@hæresiar.ch") }

      before do
        stub_request(:post, remote_user.inbox_url)
        subject.call(status)
      end

      it 'creates a mention' do
        expect(remote_user.mentions.where(status: status).count).to eq 1
      end

      it 'sends activity to the inbox' do
        expect(a_request(:post, remote_user.inbox_url)).to have_been_made.once
      end
    end
  end
end

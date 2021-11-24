# frozen_string_literal: true

class AutoModerationService < BaseService
  # for a status
  # grab the text
  # and or each piece of media
  # create a moderation record for each
  # and spin up a new job to get the moderation results
  def call(status)
    if status.text?
      TextModerationService.new.call(status)
    end

    if status.media_attachments.any?
      # TODO: Potentially move this into the worker
      status.media_attachments.each do |attachment|
        MediaModerationService.new.call(status.id, attachment.id)
      end
    end
  end
end

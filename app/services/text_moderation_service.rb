# frozen_string_literal: true
require 'http'
class TextModerationService
  def call(status)
    record = ModerationRecord.create!(status: status)

    TextModerationWorker.perform_async(
      record_id: record.id,
      text: status.text
    )
  end
end

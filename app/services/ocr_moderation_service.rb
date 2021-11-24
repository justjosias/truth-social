# frozen_string_literal: true
class OcrModerationService < BaseService
  def call(status, attachment)
    record = ModerationRecord.create!(status: status, media_attachment: attachment)

    OcrModerationWorker.perform_async(
      record_id: record.id,
      attachment_id: attachment.id
    )
  end
end

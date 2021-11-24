# frozen_string_literal: true
class MediaModerationService < BaseService
  def call(status_id, attachment_id)
    status = Status.find(status_id)
    record = ModerationRecord.create!(status: status, media_attachment_id: attachment_id)

    MediaModerationWorker.perform_async(
      record_id: record.id,
      attachment_id: attachment_id
    )
  end
end

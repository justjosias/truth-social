# frozen_string_literal: true
class OcrModerationWorker
  include Sidekiq::Worker
  include RoutingHelper

  def perform(args)
    url = ENV['MODERATION_TASK_API_URL']
    token = ENV['OCR_MODERATION_TOKEN']
    token_header = "token #{token}"
    attachment_id = args['attachment_id']
    attachment = MediaAttachment.find(attachment_id)
    asset_url = full_asset_url(attachment.file.url)

    response = HTTP.headers(accept: 'application/json').auth(token_header).post(url, form: { image_url: asset_url })

    record = ModerationRecord.find(args['record_id'])
    record.update(analysis: response.body.to_s)
    record.save

    handle_ratings(record)

    response
  end

  private

  def handle_ratings(moderation_record)
    json = JSON.parse(moderation_record.analysis)
    output = json['status'].first['response']['output'].first
    frames = output['frame_results']

    global_max = 0

    frames.each do |frame|
      local_max = frame['classes']
                  .reject { |klass| klass['class'] == 'spam' }
                  .map { |klass| klass['score'] }.max

      global_max = local_max if local_max > global_max
    end

    status = moderation_record.status

    case global_max
    when 1
      create_report(moderation_record)
    when 2
      create_report(moderation_record)
      status.update(sensitive: true)
    when 3
      create_report(moderation_record)
      status.update(sensitive: true)
      RemoveStatusService.new.call(status)
    end
  end

  def create_report(moderation_record)
    source_account = Account.find_by(username: 'ModerationAI')
    status = moderation_record.status
    target_account = status.account
    ReportService.new.call(
      source_account,
      target_account,
      status_ids: [moderation_record.status_id]
    )
  end
end

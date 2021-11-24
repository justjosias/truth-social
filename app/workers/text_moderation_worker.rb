# frozen_string_literal: true
class TextModerationWorker
  include Sidekiq::Worker
  # send text to moderation
  # store the response
  # maybe create a report
  def perform(args)
    url = ENV['MODERATION_TASK_API_URL']
    token = ENV['TEXT_MODERATION_TOKEN']
    token_header = "token #{token}"
    text_data = args['text']

    response = HTTP.headers(accept: 'application/json').auth(token_header).post(url, form: { text_data: text_data })

    record = ModerationRecord.find args['record_id']
    record.update(analysis: response.body)
    record.save

    handle_ratings(record)

    response
  end

  private

  def handle_ratings(moderation_record)
    json = JSON.parse(moderation_record.analysis.first)
    output = json['status'].first['response']['output'].first
    analysis = output['classes']

    max_rating = analysis
                 .reject { |klass| klass['class'] == 'spam' }
                 .map { |klass| klass['score'] }
                 .max

    status = moderation_record.status

    case max_rating
    when 1
      create_report(moderation_record, analysis)
    when 2
      create_report(moderation_record, analysis)
      status.update(sensitive: true)
    when 3
      create_report(moderation_record, analysis)
      status.update(sensitive: true)
      RemoveStatusService.new.call(status)
    end
  end

  def create_report(moderation_record, analysis)
    source_account = Account.find_by(username: 'ModerationAI')
    status = moderation_record.status
    target_account = status.account
    ReportService.new.call(
      source_account,
      target_account,
      comment: analysis,
      status_ids: [moderation_record.status_id]
    )
  end
end

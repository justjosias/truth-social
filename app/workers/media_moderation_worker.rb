# frozen_string_literal: true
class MediaModerationWorker
  include Sidekiq::Worker
  include RoutingHelper

  # send image to moderation
  # store the response
  # maybe create a report

  def perform(args)
    url = ENV['MODERATION_TASK_API_URL']
    token = ENV['IMAGE_MODERATION_TOKEN']
    token_header = "token #{token}"
    attachment_id = args['attachment_id']
    attachment = MediaAttachment.find(attachment_id)
    asset_url = full_asset_url(attachment.file.url)

    response = HTTP.headers(accept: 'application/json').auth(token_header).post(url, form: { image_url: asset_url })

    record = ModerationRecord.find(args['record_id'])
    record.update(analysis: response.body)
    record.save

    handle_ratings(record)

    response
  end

  private

  def handle_ratings(moderation_record)
    json = JSON.parse(moderation_record.analysis.first)
    output = json['status'].first['response']['output'].first

    danger_class_names = %w(
      general_nsfw
      general_suggestive
      yes_female_underwear
      yes_male_underwear
      yes_sex_toy
      yes_female_nudity
      yes_male_nudity
      yes_female_swimwear
      yes_male_shirtless
      gun_in_hand
      knife_in_hand
      very_bloody
      yes_pills
      yes_smoking
      illicit_injectables
      yes_nazi
      yes_kkk
      yes_middle_finger
      yes_terrorist
      yes_sexual_activity
      hanging
      noose
      yes_realistic_nsfw
      animated_corpse
      human_corpse
      yes_self_harm
      yes_emaciated_body
    )

    danger_classes = output['classes'].select { |klass| danger_class_names.include?(klass['class']) }
    text_class = output['classes'].find { |klass| klass['class'] == 'text' }

    if text_class['score'] > 0.8
      OcrModerationService.new.call(moderation_record.status, moderation_record.media_attachment)
    end

    violations = danger_classes.select { |klass| klass['score'] > 0.8 }

    if violations.any?
      source_account = Account.find_by(username: 'ModerationAI')
      status = moderation_record.status

      violation_strings = violations.map do |violation|
        "#{violation['class']}: #{violation['score']}"
      end

      violations_comment = "Media contained prohibited classes: #{violation_strings.join(', ')}"
      target_account = status.account

      ReportService.new.call(
        source_account,
        target_account,
        comment: violations_comment,
        status_ids: [moderation_record.status_id]
      )

      if output['classes'].any? { |klass| klass['score'] > 0.9 }
        status.update(sensitive: true)
      end
    end
  end
end

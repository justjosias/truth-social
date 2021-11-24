# frozen_string_literal: true

# == Schema Information
#
# Table name: account_aliases
#
#  id            :bigint(8)        not null, primary key
#  event         :string
#  message       :text             default("")
#  app_id        :string
#  created_at :datetime            not null
#  updated_at :datetime            not null
#

class Log < ApplicationRecord
  validates :event, presence: true
  validates :message, presence: true
  validates :app_id, presence: true
end

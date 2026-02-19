# frozen_string_literal: true

module Fang
  class HeartbeatRun < ActiveRecord::Base
    self.table_name = 'heartbeat_runs'

    belongs_to :heartbeat

    scope :recent, -> { order(ran_at: :desc) }
  end
end

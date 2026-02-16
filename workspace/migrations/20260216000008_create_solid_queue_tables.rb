# frozen_string_literal: true

class CreateSolidQueueTables < ActiveRecord::Migration[8.0]
  def change
    # Jobs table
    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.timestamps

      t.index [:queue_name, :finished_at], name: "index_solid_queue_jobs_for_filtered_count"
      t.index [:scheduled_at, :finished_at], name: "index_solid_queue_jobs_for_alerting"
      t.index :active_job_id, unique: true
    end

    # Scheduled executions table
    create_table :solid_queue_scheduled_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.timestamps

      t.index [:scheduled_at, :priority, :job_id], name: "index_solid_queue_dispatch_all"
    end

    # Ready executions table
    create_table :solid_queue_ready_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.timestamps

      t.index [:priority, :job_id], name: "index_solid_queue_poll_all"
      t.index [:queue_name, :priority, :job_id], name: "index_solid_queue_poll_by_queue"
    end

    # Claimed executions table
    create_table :solid_queue_claimed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.bigint :process_id
      t.timestamps

      t.index [:process_id, :job_id]
    end

    # Failed executions table
    create_table :solid_queue_failed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.text :error
      t.integer :attempts, default: 0
      t.timestamps

      t.index [:job_id, :created_at], name: "index_solid_queue_failed_executions_for_filtering"
    end

    # Pauses table
    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.timestamps

      t.index :queue_name, unique: true
    end

    # Processes table
    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.timestamps

      t.index [:last_heartbeat_at, :supervisor_id], name: "index_solid_queue_processes_for_claiming"
    end

    # Semaphores table
    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at
      t.timestamps

      t.index [:key, :value], name: "index_solid_queue_semaphores_on_key_and_value"
      t.index :expires_at
    end
  end
end

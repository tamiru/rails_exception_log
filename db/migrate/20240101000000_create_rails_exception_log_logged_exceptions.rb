class CreateRailsExceptionLogLoggedExceptions < ActiveRecord::Migration[7.1]
  def change
    create_table :rails_exception_log_logged_exceptions do |t|
      t.string :exception_class, null: false
      t.text :message
      t.text :backtrace
      t.string :controller_name
      t.string :action_name
      t.string :request_method
      t.string :request_path
      t.json :request_params
      t.json :request_headers
      t.json :session_data
      t.text :exception_data
      t.string :environment
      t.string :fingerprint
      t.integer :status, default: 0, null: false
      t.integer :occurrence_count, default: 1, null: false
      t.string :user_email
      t.string :user_id
      t.text :comments
      t.datetime :resolved_at
      t.datetime :last_occurred_at
      t.integer :severity, default: 0

      t.timestamps
    end

    add_index :rails_exception_log_logged_exceptions, :created_at
    add_index :rails_exception_log_logged_exceptions, :exception_class
    add_index :rails_exception_log_logged_exceptions, %i[controller_name action_name]
    add_index :rails_exception_log_logged_exceptions, :fingerprint
    add_index :rails_exception_log_logged_exceptions, :status
    add_index :rails_exception_log_logged_exceptions, :last_occurred_at
  end
end

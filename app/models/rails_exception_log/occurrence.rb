# frozen_string_literal: true

module RailsExceptionLog
  # One row per time an exception was captured. LoggedException folds repeats
  # into a single row with a running count, so this is the only record of
  # *when* they happened; the list's 7-day trend is drawn from it.
  #
  # It has no database foreign key on purpose: the list's "Delete all" and
  # "Clear" remove exceptions with delete_all, so history is deleted
  # alongside them explicitly (see LoggedException.delete_with_history).
  class Occurrence < BaseRecord
    self.table_name = "rails_exception_log_occurrences"

    RETENTION = 30.days
    TREND_DAYS = 7

    belongs_to :logged_exception, class_name: "RailsExceptionLog::LoggedException"

    class << self
      # Apps that have not re-run the install generator have no history
      # table; capture and the list keep working without it.
      def available?
        return @available if defined?(@available)

        @available = table_exists?
      rescue StandardError
        @available = false
      end

      def reset_availability!
        remove_instance_variable(:@available) if defined?(@available)
      end

      # Counts per day for the given exceptions over the last `days` days,
      # oldest day first, in one grouped query:
      #   { 12 => [0, 0, 3, 1, 0, 0, 5], ... }
      def daily_counts(exception_ids, days: TREND_DAYS, now: Time.current)
        return {} if exception_ids.empty? || !available?

        first_day = now.utc.to_date - (days - 1)
        rows = where(logged_exception_id: exception_ids)
               .where(occurred_at: first_day.beginning_of_day.utc..)
               .group(:logged_exception_id, Arel.sql("DATE(occurred_at)"))
               .count

        exception_ids.index_with { Array.new(days, 0) }.tap do |series|
          rows.each do |(exception_id, day), count|
            index = (day.to_date - first_day).to_i
            series[exception_id][index] = count if series.key?(exception_id) && index.between?(0, days - 1)
          end
        end
      end

      # The same series summed per exception class, for the grouped view:
      #   { "NoMethodError" => [0, 2, 0, 0, 1, 0, 7], ... }
      def daily_counts_by_class(exception_scope, days: TREND_DAYS, now: Time.current)
        return {} unless available?

        first_day = now.utc.to_date - (days - 1)
        exceptions = LoggedException.arel_table
        rows = joins(:logged_exception)
               .where(logged_exception_id: exception_scope.reorder(nil).select(:id))
               .where(occurred_at: first_day.beginning_of_day.utc..)
               .group(exceptions[:exception_class], Arel.sql("DATE(occurred_at)"))
               .count

        rows.each_with_object(Hash.new { |hash, key| hash[key] = Array.new(days, 0) }) do |((klass, day), count), series|
          index = (day.to_date - first_day).to_i
          series[klass][index] += count if index.between?(0, days - 1)
        end
      end

      def prune(before: RETENTION.ago)
        return 0 unless available?

        where(occurred_at: ...before).delete_all
      end
    end
  end
end

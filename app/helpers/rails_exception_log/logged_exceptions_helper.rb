# frozen_string_literal: true

module RailsExceptionLog
  module LoggedExceptionsHelper
    include SourceCodeHelper
    def pretty_exception_date(exception)
      if RailsExceptionLog.configuration.date_format
        return exception.created_at.strftime(RailsExceptionLog.configuration.date_format)
      end

      time = exception.created_at
      diff = Time.current - time

      case
      when diff < 60
        "#{(diff).to_i}s ago"
      when diff < 3600
        "#{(diff / 60).to_i}m ago"
      when diff < 86400
        "#{(diff / 3600).to_i}h ago"
      when diff < 604800
        "#{(diff / 86400).to_i}d ago"
      when Date.today == time.to_date
        "Today, #{time.strftime('%I:%M %p')}"
      when Date.yesterday == time.to_date
        "Yesterday, #{time.strftime('%I:%M %p')}"
      else
        time.strftime('%b %d, %Y %I:%M %p')
      end
    end

    def filtered?
      legacy_filters = %i[
        query date_ranges_filter exception_names_filter platform_filter
        controller_actions_filter status_filter
      ]
      ransack_filters = params[:q].respond_to?(:to_unsafe_h) ? params[:q].to_unsafe_h.except("s") : {}

      legacy_filters.any? { |name| params[name].present? } || ransack_filters.values.any?(&:present?)
    end

    def listify(text)
      list_items = text.scan(/^\s*\* (.+)/).map { |match| content_tag(:li, match.first) }
      content_tag(:ul, list_items)
    end

    def page_title(text)
      title = [RailsExceptionLog.application_name.presence, text].compact.join(" :: ")
      content_for(:title, title)
    end

    # Readable text for a detail box (.rn-detail-code preserves line breaks):
    # hashes, arrays, and JSON strings are pretty-printed, anything else is
    # shown as-is.
    def pretty_format(value)
      value = JSON.parse(value) if value.is_a?(String) && value.lstrip.start_with?("{", "[")
      value.is_a?(Hash) || value.is_a?(Array) ? JSON.pretty_generate(value) : value.to_s
    rescue JSON::ParserError, JSON::GeneratorError
      value.to_s
    end

    # Splits the stored "* Key: value" request/environment text into pairs.
    # Returns [] when the text is not in that format.
    def detail_pairs(text)
      text.to_s.each_line.filter_map do |line|
        match = line.match(/\A\*\s+(.+?)\s*:\s(.*)\z/m)
        [match[1].strip, match[2].strip] if match
      end
    end

    # "Foo::Bar::Baz" with line-break opportunities after each "::"; every part is escaped.
    def breakable_class_name(name)
      safe_join(name.to_s.split("::"), safe_join(["::", tag.wbr]))
    end

    def status_badges_for(exception)
      safe_join(exception.status_badges.map do |badge|
        content_tag(:span, badge[:label], class: "rn-pill rn-pill-#{badge[:tone]}")
      end)
    end

    # Sort link helper for Ransack-compatible table headers.
    def sort_link(search, attribute, name = nil, **options, &block)
      name ||= attribute.to_s.humanize

      if defined?(Ransack) && search.respond_to?(:result)
        Ransack::Helpers::FormHelper.instance_method(:sort_link).bind(self).call(search, attribute, name, **options, &block)
      else
        link_to name, "#", **options, &block
      end
    end

    # Format backtrace for display with optional collapse
    def format_backtrace(backtrace, limit: nil)
      limit ||= RailsExceptionLog.configuration.backtrace_limit
      lines = backtrace.to_s.split("\n")

      if lines.length > limit
        collapsed = lines[0...limit]
        remaining = lines[limit..]
        {
          visible: collapsed.join("\n"),
          hidden: remaining.join("\n"),
          hidden_count: remaining.length
        }
      else
        { visible: lines.join("\n"), hidden: nil, hidden_count: 0 }
      end
    end

    # Severity badge class based on exception type
    def severity_for(exception)
      case exception.exception_class
      when /Timeout|Slow|Performance/i
        "warning"
      when /404|NotFound|Missing/i
        "info"
      else
        "danger"
      end
    end

    # Active filter pills for the filter bar
    def active_filter_pills
      pills = []

      if params[:q].present?
        params[:q].each do |key, value|
          next if value.blank? || key.to_s == "s"

          labels = {
            "exception_class_cont" => "Exception",
            "message_cont" => "Message",
            "message_or_exception_class_or_controller_name_or_action_name_cont" => "Search",
            "platform_eq" => "Platform",
            "priority_eq" => "Priority",
            "assigned_to_cont" => "Assigned to",
            "fingerprint_cont" => "Fingerprint",
            "occurrence_count_gteq" => "Minimum count"
          }
          label = labels[key.to_s] || key.to_s.sub(/_(cont|eq|gteq|lteq)$/, "").humanize
          pills << { label: label, value: value, group: :q, key: key.to_s }
        end
      end

      if params[:date_ranges_filter].present?
        value = { "1" => "Today", "3" => "Last 3 days", "7" => "Last 7 days", "30" => "Last 30 days" }[params[:date_ranges_filter].to_s] || "Custom"
        pills << { label: "Time", value: value, key: "date_ranges_filter" }
      end

      {
        "controller_actions_filter" => "Source",
        "status_filter" => "Status",
        "query" => "Search"
      }.each do |key, label|
        pills << { label: label, value: params[key], key: key } if params[key].present?
      end

      pills
    end

    def filter_params_without(pill)
      filters = params_filters.deep_stringify_keys

      if pill[:group] == :q
        filters["q"]&.delete(pill[:key])
        filters.delete("q") if filters["q"].blank?
      else
        filters.delete(pill[:key])
      end

      filters
    end

    def exception_occurrence_count(exception)
      exception.respond_to?(:occurrence_count) ? (exception.occurrence_count || 1) : 1
    end

    def exception_status(exception)
      if exception.has_attribute?(:muted) && exception.muted?
        ["Muted", "muted"]
      elsif exception.has_attribute?(:snoozed_until) && exception.snoozed?
        ["Snoozed", "warning"]
      else
        ["Active", "success"]
      end
    end

    def sort_header_class(attribute)
      sort = @q&.sorts&.find { |item| item.name == attribute.to_s }
      ["sortable", ("sorted-#{sort.dir}" if sort)].compact.join(" ")
    end

    def exception_searchable?(attribute)
      LoggedException.ransackable_attributes.include?(attribute.to_s)
    end

    # Simple sparkline data for stats
    def exception_trend_data(days: 7)
      data = (0...days).reverse_each.map do |i|
        date = i.days.ago.to_date
        LoggedException.where(created_at: date.beginning_of_day..date.end_of_day).count
      end
      data
    end

    # Source reading, git blame, and backtrace parsing live in SourceCodeHelper.
  end
end

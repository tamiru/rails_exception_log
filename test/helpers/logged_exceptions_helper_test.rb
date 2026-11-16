require "test_helper"

module RailsExceptionLog
  class LoggedExceptionsHelperTest < ActionView::TestCase
    include LoggedExceptionsHelper

    # ─── detail_pairs ──────────────────────────────────────────────

    test "detail_pairs splits single-line pairs" do
      text = "* Method: GET\n* URL: http://example.com/\n"

      assert_equal [["Method", "GET"], ["URL", "http://example.com/"]], detail_pairs(text)
    end

    test "detail_pairs keeps the continuation lines of a multi-line value" do
      text = "* PATH   : /usr/bin\n" \
             "* CERT   : -----BEGIN CERTIFICATE-----\n" \
             "MIIBszCCAVmgAwIBAgIU\n" \
             "-----END CERTIFICATE-----\n" \
             "* SHELL  : /bin/bash\n"

      assert_equal [
        ["PATH", "/usr/bin"],
        ["CERT", "-----BEGIN CERTIFICATE-----\nMIIBszCCAVmgAwIBAgIU\n-----END CERTIFICATE-----"],
        ["SHELL", "/bin/bash"]
      ], detail_pairs(text)
    end

    test "detail_pairs keeps continuation lines of the last value" do
      text = "* Method: POST\n* Body: {\n  \"a\": 1\n}"

      assert_equal [["Method", "POST"], ["Body", "{\n  \"a\": 1\n}"]], detail_pairs(text)
    end

    test "detail_pairs keeps blank lines inside a value but trims them at its ends" do
      text = "* Notes: first\n\nsecond\n\n* Next: x\n"

      assert_equal [["Notes", "first\n\nsecond"], ["Next", "x"]], detail_pairs(text)
    end

    test "detail_pairs handles CRLF line endings" do
      text = "* Method: GET\r\n* Body: line one\r\nline two\r\n"

      assert_equal [["Method", "GET"], ["Body", "line one\nline two"]], detail_pairs(text)
    end

    test "detail_pairs splits on the first colon so values may contain colons" do
      text = "* URL: http://localhost:3000/a?b=c:d\n"

      assert_equal [["URL", "http://localhost:3000/a?b=c:d"]], detail_pairs(text)
    end

    test "detail_pairs keeps an empty value" do
      assert_equal [["Request ID", ""], ["Format", "html"]], detail_pairs("* Request ID: \n* Format: html")
    end

    test "detail_pairs ignores lines before the first pair" do
      text = "stray preamble\n* Method: GET\n"

      assert_equal [["Method", "GET"]], detail_pairs(text)
    end

    test "detail_pairs reads the padded format the model stores environments in" do
      environment = { "Rails Environment" => "test", "SECRET_PEM" => "line1\nline2", "PATH" => "/bin" }
      max_length = environment.keys.map(&:length).max
      text = environment.sort.map { |key, value| "* %-*s: %s" % [max_length, key, value] }.join("\n")

      assert_equal [
        ["PATH", "/bin"],
        ["Rails Environment", "test"],
        ["SECRET_PEM", "line1\nline2"]
      ], detail_pairs(text)
    end

    test "detail_pairs returns no pairs for text not in that format" do
      assert_empty detail_pairs("{\"a\": 1}\nplain text")
      assert_empty detail_pairs("")
      assert_empty detail_pairs(nil)
    end

    # ─── pretty_format ─────────────────────────────────────────────

    test "pretty_format pretty-prints hashes, arrays, and JSON strings" do
      expected = JSON.pretty_generate({ "a" => 1 })

      assert_equal expected, pretty_format({ "a" => 1 })
      assert_equal expected, pretty_format('  {"a": 1}')
      assert_equal JSON.pretty_generate([1, 2]), pretty_format([1, 2])
    end

    test "pretty_format returns other values as strings" do
      assert_equal "plain text", pretty_format("plain text")
      assert_equal "{not json", pretty_format("{not json")
      assert_equal "42", pretty_format(42)
      assert_equal "", pretty_format(nil)
    end

    # ─── breakable_class_name ──────────────────────────────────────

    test "breakable_class_name adds a break opportunity after each namespace separator" do
      assert_equal "Foo::<wbr>Bar::<wbr>Baz", breakable_class_name("Foo::Bar::Baz")
      assert_equal "Plain", breakable_class_name("Plain")
    end

    test "breakable_class_name escapes each part" do
      html = breakable_class_name("A::<script>")

      assert_includes html, "&lt;script&gt;"
      refute_includes html, "<script>"
    end

    # ─── listify ───────────────────────────────────────────────────

    test "listify turns bullet lines into list items and escapes them" do
      html = listify("* one\n  * <two>\nnot a bullet")

      assert_equal "<ul><li>one</li><li>&lt;two&gt;</li></ul>", html
    end

    # ─── format_backtrace ──────────────────────────────────────────

    test "format_backtrace shows everything when within the limit" do
      result = format_backtrace("a\nb", limit: 2)

      assert_equal({ visible: "a\nb", hidden: nil, hidden_count: 0 }, result)
    end

    test "format_backtrace hides lines beyond the limit" do
      result = format_backtrace("a\nb\nc\nd", limit: 2)

      assert_equal({ visible: "a\nb", hidden: "c\nd", hidden_count: 2 }, result)
    end

    test "format_backtrace handles a missing backtrace" do
      assert_equal({ visible: "", hidden: nil, hidden_count: 0 }, format_backtrace(nil, limit: 5))
    end

    # ─── severity_for ──────────────────────────────────────────────

    test "severity_for picks a tone from the exception class" do
      assert_equal "warning", severity_for(LoggedException.new(exception_class: "Net::ReadTimeout"))
      assert_equal "info", severity_for(LoggedException.new(exception_class: "ActiveRecord::RecordNotFound"))
      assert_equal "danger", severity_for(LoggedException.new(exception_class: "NoMethodError"))
    end
  end
end

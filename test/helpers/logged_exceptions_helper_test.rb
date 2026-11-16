require "test_helper"

module RailsExceptionLog
  class LoggedExceptionsHelperTest < ActionView::TestCase
    include LoggedExceptionsHelper

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

    test "detail_pairs returns no pairs for text not in that format" do
      assert_empty detail_pairs("{\"a\": 1}\nplain text")
      assert_empty detail_pairs(nil)
    end
  end
end

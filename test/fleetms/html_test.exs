defmodule Fleetms.HtmlTest do
  use ExUnit.Case, async: true

  alias Fleetms.Html

  describe "sanitize/1" do
    test "passes nil through" do
      assert Html.sanitize(nil) == nil
    end

    test "keeps editor formatting tags" do
      html = "<h2>Title</h2><p><strong>bold</strong> and <em>italic</em></p><ul><li>one</li></ul>"
      result = Html.sanitize(html)

      assert result =~ "<h2>"
      assert result =~ "<strong>"
      assert result =~ "<em>"
      assert result =~ "<li>"
    end

    test "strips script tags and event handlers" do
      html = ~s|<p onclick="steal()">hi</p><script>alert(1)</script>|
      result = Html.sanitize(html)

      refute result =~ "<script"
      refute result =~ "onclick"
      assert result =~ "hi"
    end

    test "treats empty paragraphs and whitespace as blank" do
      assert Html.sanitize("<p></p>") == ""
      assert Html.sanitize("<p><br></p>") == ""
      assert Html.sanitize("   ") == ""
    end
  end
end

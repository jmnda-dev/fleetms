defmodule FleetmsWeb.CoreComponentsTest do
  use FleetmsWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias FleetmsWeb.CoreComponents

  describe "breadcrumbs/1" do
    test "renders links for items with a path and plain text for the current page" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.breadcrumbs items={[
          %{label: "Dashboard", path: "/o/abc", icon: "fa-house"},
          %{label: "Users", path: "/o/abc/users"},
          %{label: "New member"}
        ]} />
        """)

      assert html =~ "Dashboard"
      assert html =~ ~s(href="/o/abc")
      assert html =~ ~s(href="/o/abc/users")
      # The current page is not a link and is marked aria-current.
      assert html =~ "New member"
      assert html =~ ~s(aria-current="page")
      refute html =~ ~s(href="/o/abc/users/new")
      # The home icon renders.
      assert html =~ "fa-house"
    end
  end

  describe "date_input/1" do
    test "renders the Datepicker hook inside an ignored container with the value" do
      assigns = %{form: to_form(%{"purchase_date" => "2024-03-15"}, as: :demo)}

      html =
        rendered_to_string(~H"""
        <CoreComponents.date_input field={@form[:purchase_date]} label="Purchase date" />
        """)

      assert html =~ "Purchase date"
      assert html =~ ~s(phx-hook="DatePicker")
      # The widget DOM is owned by the hook, not patched by LiveView.
      assert html =~ ~s(phx-update="ignore")
      assert html =~ ~s(value="2024-03-15")
      assert html =~ ~s(data-format="yyyy-mm-dd")
    end

    test "accepts a Date struct value" do
      assigns = %{form: to_form(%{"purchase_date" => ~D[2024-03-15]}, as: :demo)}

      html =
        rendered_to_string(~H"""
        <CoreComponents.date_input field={@form[:purchase_date]} />
        """)

      assert html =~ ~s(value="2024-03-15")
    end
  end

  describe "rich_text/1" do
    test "renders the editor hook, toolbar and hidden input carrying the HTML" do
      assigns = %{form: to_form(%{"description" => "<p>hi</p>"}, as: :demo)}

      html =
        rendered_to_string(~H"""
        <CoreComponents.rich_text field={@form[:description]} label="Description" />
        """)

      assert html =~ "Description"
      assert html =~ ~s(phx-hook="RichText")
      assert html =~ ~s(phx-update="ignore")
      assert html =~ "data-rt-toolbar"
      assert html =~ "data-rt-content"
      assert html =~ "data-rt-input"
      assert html =~ ~s(data-rt-action="bold")
      # The hidden input carries the current value and the form field name.
      assert html =~ ~s(name="demo[description]")
      assert html =~ "&lt;p&gt;hi&lt;/p&gt;"
    end
  end

  describe "live_modal/1" do
    test "renders the title, body, footer and a close control" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.live_modal id="user-modal" show>
          <:title>New member</:title>
          <p>Body content here</p>
          <:footer>Footer content</:footer>
        </CoreComponents.live_modal>
        """)

      assert html =~ ~s(id="user-modal")
      assert html =~ ~s(id="user-modal-title")
      assert html =~ "New member"
      assert html =~ "Body content here"
      assert html =~ "Footer content"
      assert html =~ ~s(role="dialog")
      assert html =~ "Close modal"
      # URL-aware close machinery is wired.
      assert html =~ "data-cancel"
      assert html =~ ~s(phx-key="escape")
    end
  end
end

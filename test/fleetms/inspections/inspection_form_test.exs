defmodule Fleetms.Inspections.InspectionFormTest do
  use Fleetms.DataCase

  alias Fleetms.Inspections

  alias Fleetms.Inspections.Schema.{
    MeterConfig,
    NumberConfig,
    PassFailConfig,
    SingleSelectConfig
  }

  setup :shared_org

  # A realistic document as the builder would post it: string keys, nested item
  # configs discriminated by "type".
  defp valid_schema do
    %{
      "settings" => %{"pass_policy" => "all_pass", "require_signature" => true},
      "sections" => [
        %{
          "id" => "sec_ext",
          "title" => "Exterior",
          "items" => [
            %{
              "id" => "i_brakes",
              "label" => "Brakes",
              "required" => true,
              "config" => %{"type" => "pass_fail", "comment_on" => "fail", "photo_on" => "fail"}
            },
            %{
              "id" => "i_psi",
              "label" => "Tire pressure",
              "config" => %{
                "type" => "number",
                "unit" => "psi",
                "pass_min" => 30,
                "pass_max" => 35
              }
            },
            %{
              "id" => "i_odo",
              "label" => "Odometer",
              "config" => %{"type" => "meter", "unit" => "km"}
            },
            %{
              "id" => "i_wipers",
              "label" => "Wiper state",
              "config" => %{
                "type" => "single_select",
                "display" => "dropdown",
                "options" => [
                  %{"value" => "good", "label" => "Good"},
                  %{"value" => "worn", "label" => "Worn", "fail?" => true}
                ]
              }
            },
            %{"id" => "i_notes", "label" => "Notes", "config" => %{"type" => "text"}},
            %{
              "id" => "i_sign",
              "label" => "Sign here",
              "config" => %{"type" => "signature", "who" => "driver"}
            }
          ]
        }
      ]
    }
  end

  defp form_fixture(scope, attrs \\ %{}) do
    attrs
    |> Enum.into(%{title: "Form #{System.unique_integer([:positive])}"})
    |> Inspections.create_inspection_form!(scope: scope)
  end

  describe "draft schema (union-typed items)" do
    test "a new form starts as an empty draft", %{scope: scope} do
      form = form_fixture(scope)

      assert form.status == :draft
      assert form.draft_schema.sections == []
      assert form.draft_schema.settings.pass_policy == :all_pass
      assert form.draft_schema.settings.meter_unit == "km"
    end

    test "casts a full document into typed structs, tagging each item's config", %{scope: scope} do
      form =
        form_fixture(scope)
        |> Inspections.update_inspection_form!(%{draft_schema: valid_schema()}, scope: scope)

      assert form.draft_schema.settings.require_signature == true
      assert [section] = form.draft_schema.sections
      assert section.id == "sec_ext"
      assert [brakes, psi, odo, wipers, _notes, _sign] = section.items

      # each config comes back as an %Ash.Union{} tagged by its type
      assert %Ash.Union{type: :pass_fail, value: %PassFailConfig{comment_on: :fail}} =
               brakes.config

      assert %Ash.Union{type: :number, value: %NumberConfig{} = num} = psi.config
      assert Decimal.equal?(num.pass_min, Decimal.new(30))
      assert Decimal.equal?(num.pass_max, Decimal.new(35))

      assert %Ash.Union{type: :meter, value: %MeterConfig{write_to_vehicle: true}} = odo.config

      assert %Ash.Union{type: :single_select, value: %SingleSelectConfig{options: opts}} =
               wipers.config

      assert [%{value: "good", fail?: false}, %{value: "worn", fail?: true}] = opts
    end

    test "rejects a config that violates its variant's validation", %{scope: scope} do
      bad =
        put_in(valid_schema(), ["sections", Access.at(0), "items", Access.at(1), "config"], %{
          "type" => "number",
          "pass_min" => 40,
          "pass_max" => 10
        })

      assert {:error, error} =
               form_fixture(scope)
               |> Inspections.update_inspection_form(%{draft_schema: bad}, scope: scope)

      assert Exception.message(error) =~ "pass_min must be less than or equal to pass_max"
    end

    test "rejects an unknown item type (no matching union member)", %{scope: scope} do
      bad =
        put_in(valid_schema(), ["sections", Access.at(0), "items", Access.at(0), "config"], %{
          "type" => "banana"
        })

      assert {:error, _} =
               form_fixture(scope)
               |> Inspections.update_inspection_form(%{draft_schema: bad}, scope: scope)
    end
  end

  describe "publishing and versioning" do
    test "publish freezes the draft into version 1 and activates the form", %{
      scope: scope,
      owner: owner
    } do
      form =
        form_fixture(scope)
        |> Inspections.update_inspection_form!(%{draft_schema: valid_schema()}, scope: scope)
        |> Inspections.publish_inspection_form!(scope: scope)

      assert form.status == :active

      form = Inspections.get_inspection_form!(form.id, scope: scope)
      assert form.version_count == 1
      assert form.latest_version_number == 1

      [version] = form.versions
      version = Inspections.get_inspection_form_version!(version.id, scope: scope)
      version = Ash.load!(version, [:published_by], scope: scope)

      assert version.version_number == 1
      assert version.published_at
      assert version.published_by.id == owner.id
      assert [%{id: "sec_ext"}] = version.schema.sections
    end

    test "republishing mints version 2 and leaves version 1's snapshot untouched", %{scope: scope} do
      form =
        form_fixture(scope)
        |> Inspections.update_inspection_form!(%{draft_schema: valid_schema()}, scope: scope)
        |> Inspections.publish_inspection_form!(scope: scope)

      [v1] = Inspections.get_inspection_form!(form.id, scope: scope).versions

      # edit the draft (rename the first item), then publish again
      edited =
        put_in(
          valid_schema(),
          ["sections", Access.at(0), "items", Access.at(0), "label"],
          "Brake pads"
        )

      Inspections.update_inspection_form!(form, %{draft_schema: edited}, scope: scope)
      Inspections.publish_inspection_form!(form, scope: scope)

      form = Inspections.get_inspection_form!(form.id, scope: scope)
      assert form.version_count == 2
      assert form.latest_version_number == 2

      # v1's frozen snapshot still shows the original label
      v1 = Inspections.get_inspection_form_version!(v1.id, scope: scope)
      assert [%{items: [brakes | _]}] = v1.schema.sections
      assert brakes.label == "Brakes"
    end
  end
end

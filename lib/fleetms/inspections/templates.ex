defmodule Fleetms.Inspections.Templates do
  @moduledoc """
  A small library of ready-made starter inspection forms.

  Each template is a `%{key, title, description, schema}` — the `schema` is a plain
  map in the exact shape the builder emits and `Fleetms.Inspections.Schema` casts,
  so creating a form from a template is just setting `draft_schema` to it (see the
  `:duplicate` action). Templates are code-defined and org-agnostic; picking one
  gives the user a fully populated draft they can then edit and publish.
  """

  @templates [
    %{
      key: "dvir",
      title: "Daily Vehicle Inspection (DVIR)",
      description: "A driver's daily walkaround: lights, tyres, fluids, brakes and a sign-off.",
      schema: %{
        "sections" => [
          %{
            "id" => "exterior",
            "title" => "Exterior & lights",
            "items" => [
              %{
                "id" => "lights",
                "label" => "Lights & indicators",
                "config" => %{"type" => "pass_fail", "comment_on" => "fail"}
              },
              %{
                "id" => "tyres",
                "label" => "Tyres & wheels",
                "config" => %{"type" => "pass_fail", "comment_on" => "fail", "photo_on" => "fail"}
              },
              %{
                "id" => "mirrors",
                "label" => "Mirrors & glass",
                "config" => %{"type" => "pass_fail"}
              },
              %{
                "id" => "body",
                "label" => "Body damage",
                "config" => %{"type" => "pass_fail", "photo_on" => "fail"}
              }
            ]
          },
          %{
            "id" => "engine",
            "title" => "Engine & fluids",
            "items" => [
              %{
                "id" => "odometer",
                "label" => "Odometer reading",
                "config" => %{"type" => "meter", "unit" => "km", "must_increase" => true}
              },
              %{
                "id" => "oil",
                "label" => "Engine oil level",
                "config" => %{"type" => "pass_fail"}
              },
              %{
                "id" => "coolant",
                "label" => "Coolant level",
                "config" => %{"type" => "pass_fail"}
              },
              %{
                "id" => "leaks",
                "label" => "Leaks under vehicle",
                "config" => %{"type" => "pass_fail", "comment_on" => "fail", "photo_on" => "fail"}
              }
            ]
          },
          %{
            "id" => "cab",
            "title" => "Cab & safety",
            "items" => [
              %{
                "id" => "brakes",
                "label" => "Brakes",
                "config" => %{"type" => "pass_fail", "comment_on" => "fail"}
              },
              %{
                "id" => "seatbelts",
                "label" => "Seatbelts",
                "config" => %{"type" => "pass_fail"}
              },
              %{"id" => "horn", "label" => "Horn", "config" => %{"type" => "pass_fail"}},
              %{
                "id" => "wipers",
                "label" => "Wipers & washers",
                "config" => %{"type" => "pass_fail"}
              }
            ]
          },
          %{
            "id" => "signoff",
            "title" => "Sign-off",
            "items" => [
              %{
                "id" => "notes",
                "label" => "Driver notes",
                "config" => %{"type" => "text", "multiline" => true}
              },
              %{
                "id" => "signature",
                "label" => "Driver signature",
                "config" => %{"type" => "signature", "who" => "driver"}
              }
            ]
          }
        ]
      }
    },
    %{
      key: "pre_trip",
      title: "Pre-Trip Safety Check",
      description: "Documents, safety equipment and a walkaround before a vehicle sets off.",
      schema: %{
        "sections" => [
          %{
            "id" => "documents",
            "title" => "Documents",
            "items" => [
              %{
                "id" => "licence",
                "label" => "Licence & insurance present",
                "config" => %{"type" => "pass_fail", "comment_on" => "fail"}
              },
              %{
                "id" => "insurance_expiry",
                "label" => "Insurance expiry date",
                "config" => %{"type" => "date", "fail_if_past" => true}
              }
            ]
          },
          %{
            "id" => "safety",
            "title" => "Safety equipment",
            "items" => [
              %{
                "id" => "extinguisher",
                "label" => "Fire extinguisher",
                "config" => %{"type" => "pass_fail"}
              },
              %{
                "id" => "first_aid",
                "label" => "First-aid kit",
                "config" => %{"type" => "pass_fail"}
              },
              %{
                "id" => "triangle",
                "label" => "Warning triangle",
                "config" => %{"type" => "pass_fail"}
              }
            ]
          },
          %{
            "id" => "walkaround",
            "title" => "Walkaround",
            "items" => [
              %{
                "id" => "tyres",
                "label" => "Tyres & pressure",
                "config" => %{"type" => "pass_fail", "photo_on" => "fail"}
              },
              %{"id" => "lights", "label" => "Lights", "config" => %{"type" => "pass_fail"}},
              %{
                "id" => "load",
                "label" => "Load secured",
                "config" => %{"type" => "pass_fail", "comment_on" => "fail"}
              }
            ]
          },
          %{
            "id" => "signoff",
            "title" => "Sign-off",
            "items" => [
              %{
                "id" => "signature",
                "label" => "Driver signature",
                "config" => %{"type" => "signature", "who" => "driver"}
              }
            ]
          }
        ]
      }
    },
    %{
      key: "tyre_brake",
      title: "Tyre & Brake Inspection",
      description: "A focused check of tread depths and the braking system.",
      schema: %{
        "sections" => [
          %{
            "id" => "tyres",
            "title" => "Tyres",
            "items" => [
              %{
                "id" => "tread_fl",
                "label" => "Front-left tread depth",
                "config" => %{
                  "type" => "number",
                  "unit" => "mm",
                  "decimals" => 1,
                  "pass_min" => 1.6
                }
              },
              %{
                "id" => "tread_fr",
                "label" => "Front-right tread depth",
                "config" => %{
                  "type" => "number",
                  "unit" => "mm",
                  "decimals" => 1,
                  "pass_min" => 1.6
                }
              },
              %{
                "id" => "tread_rear",
                "label" => "Rear tread depth",
                "config" => %{
                  "type" => "number",
                  "unit" => "mm",
                  "decimals" => 1,
                  "pass_min" => 1.6
                }
              },
              %{
                "id" => "tyre_damage",
                "label" => "Visible damage",
                "config" => %{"type" => "pass_fail", "comment_on" => "fail", "photo_on" => "fail"}
              }
            ]
          },
          %{
            "id" => "brakes",
            "title" => "Brakes",
            "items" => [
              %{
                "id" => "pads",
                "label" => "Brake pads",
                "config" => %{"type" => "pass_fail", "comment_on" => "fail"}
              },
              %{
                "id" => "fluid",
                "label" => "Brake fluid level",
                "config" => %{"type" => "pass_fail"}
              },
              %{
                "id" => "handbrake",
                "label" => "Handbrake",
                "config" => %{"type" => "pass_fail"}
              },
              %{
                "id" => "brake_notes",
                "label" => "Notes",
                "config" => %{"type" => "text", "multiline" => true}
              }
            ]
          }
        ]
      }
    }
  ]

  @doc "All starter templates as `%{key, title, description, schema}`."
  def all, do: @templates

  @doc "Returns the template with `key`, or `nil`."
  def get(key), do: Enum.find(@templates, &(&1.key == key))
end

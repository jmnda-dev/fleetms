Application.put_env(:elixir, :ansi_enabled, true)

timestamp = fn ->
  {_date, {hour, minute, _second}} = :calendar.local_time()

  [hour, minute]
  |> Enum.map(&String.pad_leading(Integer.to_string(&1), 2, "0"))
  |> Enum.join(":")
end

IEx.configure(
  colors: [
    syntax_colors: [
      number: :light_yellow,
      atom: :light_cyan,
      string: :light_black,
      boolean: :red,
      nil: [:magenta, :bright]
    ],
    ls_directory: :cyan,
    ls_device: :yellow,
    doc_code: :green,
    doc_inline_code: :magenta,
    doc_headings: [:cyan, :underline],
    doc_title: [:cyan, :bright, :underline]
  ],
  default_prompt:
    "#{IO.ANSI.green()}%prefix#{IO.ANSI.reset()} " <>
      "[#{IO.ANSI.magenta()}#{timestamp.()}#{IO.ANSI.reset()} " <>
      ":: #{IO.ANSI.cyan()}%counter#{IO.ANSI.reset()}] >",
  alive_prompt:
    "#{IO.ANSI.green()}%prefix#{IO.ANSI.reset()} " <>
      "(#{IO.ANSI.yellow()}%node#{IO.ANSI.reset()}) " <>
      "[#{IO.ANSI.magenta()}#{timestamp.()}#{IO.ANSI.reset()} " <>
      ":: #{IO.ANSI.cyan()}%counter#{IO.ANSI.reset()}] >",
  history_size: 200,
  inspect: [
    pretty: true,
    limit: :infinity,
    width: 80,
    custom_options: [sort_maps: true]
  ],
  width: 80
)

require Ash.Query

alias Fleetms.Repo

alias Fleetms.{Accounts, Vehicles}

alias Fleetms.Accounts.{Organization, User, UserProfile}
alias Fleetms.Vehicles.{VehicleMake, VehicleModel, Vehicle}

defmodule :_exit do
  defdelegate exit(), to: System, as: :halt
end

defmodule :_shortcuts do
  defdelegate c, to: IEx.Helpers, as: :clear

  defdelegate r, to: IEx.Helpers, as: :recompile
end

import :_exit
import :_shortcuts

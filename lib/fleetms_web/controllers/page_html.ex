defmodule FleetmsWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use FleetmsWeb, :html

  embed_templates "page_html/*"

  @doc "A compact icon + title + text card used in the landing page's 'what it helps with' grid."
  attr :icon, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  def problem_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
      <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-primary-50 text-primary-700 dark:bg-gray-700 dark:text-primary-400">
        <i class={["fa-solid text-lg", @icon]}></i>
      </div>
      <h3 class="mt-4 text-lg font-semibold">{@title}</h3>
      <p class="mt-2 text-sm text-gray-600 dark:text-gray-300">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  @doc "A feature-module card used in the landing page's modules grid."
  attr :icon, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  def feature_card(assigns) do
    ~H"""
    <div class="group flex gap-4">
      <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-brand text-white dark:text-primary-900">
        <i class={["fa-solid text-lg", @icon]}></i>
      </div>
      <div>
        <h3 class="text-lg font-semibold">{@title}</h3>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-300">{render_slot(@inner_block)}</p>
      </div>
    </div>
    """
  end
end

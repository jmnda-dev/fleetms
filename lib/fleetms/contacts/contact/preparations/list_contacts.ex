defmodule Fleetms.Contacts.Contact.Preparations.ListContacts do
  @moduledoc """
  Applies the contact list's free-text search, an optional type filter, and sort.
  Search is trigram-based across the name, company, email and phone.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    contact_type = Ash.Query.get_argument(query, :contact_type)
    sort_by = Ash.Query.get_argument(query, :sort_by) || :name
    sort_order = Ash.Query.get_argument(query, :sort_order) || :asc

    query
    |> apply_type(contact_type)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_type(query, nil), do: query
  defp apply_type(query, type), do: Ash.Query.filter(query, contact_type == ^type)

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(name, ^search) > ^@search_threshold or
        trigram_similarity(company, ^search) > ^@search_threshold or
        trigram_similarity(email, ^search) > ^@search_threshold or
        trigram_similarity(phone, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query
end

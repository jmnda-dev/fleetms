defmodule IssueDocument do
  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 500
    end

    attribute :mime_type, :string do
      allow_nil? true
      public? true
      description "The MIME type of the document."
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end
end

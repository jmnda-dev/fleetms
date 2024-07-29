defmodule Fleetms.Issues do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Issues.Issue do
      define :list_issues,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]
    end

    resource Fleetms.Issues.IssuePhoto
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end

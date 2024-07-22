defmodule Fleetms.Issues do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Issues.Issue
    resource Fleetms.Issues.IssuePhoto
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end

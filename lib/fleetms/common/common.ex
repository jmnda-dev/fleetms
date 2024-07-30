defmodule Fleetms.Common do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Common.Vendor
    resource Fleetms.Common.VendorPart
    resource Fleetms.Common.Sequence
    resource Fleetms.Common.PaginationSortParam
  end

  admin do
    show? true
  end
end

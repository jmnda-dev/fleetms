defmodule FleetmsWeb.Router do
  use FleetmsWeb, :router
  use AshAuthentication.Phoenix.Router
  # use PhoenixAnalytics.Web, :router

  import AshAdmin.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FleetmsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug FleetmsWeb.Plugs.SetTenant
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :public_layout do
    plug :put_root_layout, html: {FleetmsWeb.Layouts, :public_root}
    plug :put_layout, html: {FleetmsWeb.Layouts, :public}
  end

  pipeline :auth_layout do
    plug :put_root_layout, html: {FleetmsWeb.Layouts, :auth_root}
  end

  pipeline :require_service_provider_user do
    plug FleetmsWeb.Plugs.RequireServiceProviderUser
  end

  scope "/", FleetmsWeb do
    pipe_through [:browser, :public_layout]

    get "/", PageController, :home
    get "/demo/sign-in", PageController, :demo_signin
  end

  scope "/", FleetmsWeb do
    pipe_through :browser

    ash_authentication_live_session :user_authenticated,
      on_mount: [
        # AshAuthentication.Phoenix.LiveSession,
        {FleetmsWeb.LiveUserAuth, :require_authenticated_user}
      ] do
      live "/dashboard", DashboardLive, :index
      live "/vehicles", VehicleLive.List, :index
      live "/vehicles/filter_form", VehicleLive.List, :filter_form
      live "/vehicles/add", VehicleLive.List, :add
      live "/vehicles/:id/edit", VehicleLive.List, :edit

      live "/vehicles/:id", VehicleLive.Detail, :detail
      live "/vehicles/:id/detail/edit", VehicleLive.Detail, :edit
      live "/vehicles/:id/detail/documents", VehicleLive.DocumentList
      live "/vehicles/:id/detail/issues", VehicleLive.Detail, :vehicle_issues

      live "/vehicles/:id/detail/service_reminders",
           VehicleLive.Detail,
           :vehicle_service_reminders

      live "/vehicles/:id/detail/work_orders", VehicleLive.Detail, :vehicle_work_orders
      live "/vehicles/:id/detail/fuel_histories", VehicleLive.Detail, :vehicle_fuel_histories

      live "/vehicle_assignments", VehicleAssignmentLive.Index, :index
      live "/vehicle_assignments/filter_form", VehicleAssignmentLive.Index, :filter_form
      live "/vehicle_assignments/new", VehicleAssignmentLive.Index, :new
      live "/vehicle_assignments/:id/edit", VehicleAssignmentLive.Index, :edit

      live "/vehicle_general_reminders", VehicleGeneralReminderLive.Index, :index

      live "/vehicle_general_reminders/filter_form",
           VehicleGeneralReminderLive.Index,
           :filter_form

      live "/vehicle_general_reminders/new", VehicleGeneralReminderLive.Index, :new
      live "/vehicle_general_reminders/:id/edit", VehicleGeneralReminderLive.Index, :edit

      live "/inspection_forms", InspectionFormLive.Index, :index
      live "/inspection_forms/new", InspectionFormLive.Index, :new
      live "/inspection_forms/:id/edit", InspectionFormLive.Index, :edit
      live "/inspection_forms/:id", InspectionFormLive.Detail, :detail
      live "/inspection_forms/:id/detail/edit", InspectionFormLive.Detail, :edit

      live "/inspections", InspectionLive.List, :index

      live "/inspections/perform_inspection",
           InspectionLive.New,
           :start_inspection

      live "/inspections/:id", InspectionLive.Detail, :detail
      live "/inspections/:id/details/edit", InspectionLive.Edit, :edit

      live "/issues", IssueLive.Index, :index
      live "/issues/new", IssueLive.Index, :new
      live "/issues/:id/edit", IssueLive.Index, :edit
      live "/issues/:id/close_issue", IssueLive.Index, :close_issue
      live "/issues/:id/resolve_issue_with_comment", IssueLive.Index, :resolve_issue_with_comment
      live "/issues/filter_form", IssueLive.Index, :filter_form

      live "/issues/:id", IssueLive.Detail, :detail
      live "/issues/:id/detail/edit", IssueLive.Detail, :edit
      live "/issues/:id/detail/close_issue", IssueLive.Detail, :close_issue

      live "/issues/:id/detail/resolve_issue_with_comment",
           IssueLive.Detail,
           :resolve_issue_with_comment

      live "/parts", PartLive.Index, :index
      live "/parts/new", PartLive.Index, :new
      live "/parts/filter_form", PartLive.Index, :filter_form
      live "/parts/:id/edit", PartLive.Index, :edit
      live "/parts/:id", PartLive.Detail, :detail
      live "/parts/:id/detail/edit", PartLive.Detail, :edit

      live "/inventory_locations", InventoryLocationLive.Index, :index
      live "/inventory_locations/new", InventoryLocationLive.Index, :new
      live "/inventory_locations/filter_form", InventoryLocationLive.Index, :filter_form
      live "/inventory_locations/:id/edit", InventoryLocationLive.Index, :edit
      live "/inventory_locations/:id", InventoryLocationLive.Detail, :detail
      live "/inventory_locations/:id/detail/edit", InventoryLocationLive.Detail, :edit

      live "/service_tasks", ServiceTaskLive.Index, :index
      live "/service_tasks/new", ServiceTaskLive.Index, :new
      live "/service_tasks/:id/edit", ServiceTaskLive.Index, :edit

      live "/service_groups", ServiceGroupLive.Index, :index
      live "/service_groups/new", ServiceGroupLive.Index, :new
      live "/service_groups/:id/edit", ServiceGroupLive.Index, :edit
      live "/service_groups/:id", ServiceGroupLive.Detail, :detail

      live "/service_groups/:id/service_group_schedules",
           ServiceGroupLive.Detail,
           :service_group_schedules

      live "/service_groups/:id/service_group_schedules/add_service_group_schedule",
           ServiceGroupLive.Detail,
           :add_service_group_schedule

      live "/service_groups/:id/service_group_schedules/:service_group_schedule_id/edit",
           ServiceGroupLive.Detail,
           :edit_service_group_schedule

      live "/service_groups/:id/vehicles", ServiceGroupLive.Detail, :vehicles
      live "/service_groups/:id/detail/edit", ServiceGroupLive.Detail, :edit

      live "/service_reminders", ServiceReminderLive.Index, :index
      live "/service_reminders/filter_form", ServiceReminderLive.Index, :filter_form
      live "/service_reminders/new", ServiceReminderLive.Index, :new
      live "/service_reminders/:id/edit", ServiceReminderLive.Index, :edit

      live "/service_reminders/:id", ServiceReminderLive.Detail, :detail
      live "/service_reminders/:id/detail/edit", ServiceReminderLive.Detail, :edit

      live "/work_orders", WorkOrderLive.Index, :index
      live "/work_orders/new", WorkOrderLive.Index, :new
      live "/work_orders/filter_form", WorkOrderLive.Index, :filter_form
      live "/work_orders/:id/edit", WorkOrderLive.Index, :edit
      live "/work_orders/:id", WorkOrderLive.Detail, :detail
      live "/work_orders/:id/detail/edit", WorkOrderLive.Detail, :edit

      live "/fuel_histories", FuelHistoryLive.Index, :index
      live "/fuel_histories/new", FuelHistoryLive.Index, :new
      live "/fuel_histories/filter_form", FuelHistoryLive.Index, :filter_form
      live "/fuel_histories/:id/edit", FuelHistoryLive.Index, :edit
      live "/fuel_histories/:id", FuelHistoryLive.Detail, :detail
      live "/fuel_histories/:id/detail/edit", FuelHistoryLive.Detail, :edit

      live "/users", UserLive.Index, :index
      live "/users/filter_form", UserLive.Index, :filter_form
      live "/users/new", UserLive.Index, :new
      live "/users/:id/edit", UserLive.Index, :edit
      live "/my_profile", UserLive.Profile
      live "/settings", UserLive.Settings

      live "/reports", ReportLive.Summary
      live "/reports/fuel_costs", ReportLive.FuelCosts
      live "/reports/downloads", ReportLive.Download
    end

    get "/reports/downloads/:filename", DownloadController, :report_download
    get "/vehicles/documents/download/:id", VehicleDocumentDownloadController, :download
  end

  scope "/", FleetmsWeb do
    pipe_through [:browser, :auth_layout]

    ash_authentication_live_session :redirect_if_authenticated,
      on_mount: [
        {FleetmsWeb.LiveUserAuth, :redirect_if_authenticated},
        {FleetmsWeb.LiveUserAuth, :user_optional}
      ],
      layout: {FleetmsWeb.Layouts, :auth} do
      live "/sign-in", AuthLive.SignIn
      live "/sign-up", AuthLive.SignUp
      live "/password-reset/:token", AuthLive.PasswordReset
      live "/request-password-reset", AuthLive.RequestPasswordReset
    end
  end

  scope "/", FleetmsWeb do
    pipe_through :browser
    get "/sign-out", AuthController, :sign_out
    auth_routes_for Fleetms.Accounts.User, to: AuthController
    reset_route([])
  end

  scope "/platform" do
    pipe_through [:browser, :require_service_provider_user]
    ash_admin "/admin"
    # phoenix_analytics_dashboard("/analytics")

    import Phoenix.LiveDashboard.Router
    live_dashboard "/dashboard", metrics: FleetmsWeb.Telemetry
  end

  scope "/" do
    pipe_through [:browser, :require_service_provider_user]

    forward "/feature-flags", FunWithFlags.UI.Router, namespace: "feature-flags"
  end

  # Other scopes may use custom stacks.
  # scope "/api", FleetmsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:fleetms, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).

    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

defmodule FleetmsWeb.Router do
  use FleetmsWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FleetmsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    # Serve the 503 page while maintenance_mode is on (staff pass through).
    plug FleetmsWeb.Plugs.MaintenanceMode
    # Backstop for the user_registration flag: blocks the sign-up POST when off.
    plug FleetmsWeb.Plugs.PublicRegistration
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  # Public JSON:API: bearer token sets the actor, the `x-organization` header sets
  # the tenant (and enforces membership). AshJsonApi negotiates its own content type.
  pipeline :json_api do
    # Global kill-switch: when the `public_api` flag is off, data endpoints 503.
    plug FleetmsWeb.Plugs.ApiEnabled

    # A request authenticates with EITHER a user JWT or an API key, both in the
    # `Authorization: Bearer` header. load_from_bearer handles a JWT; the API-key
    # plug (on_error swallowed) handles a key, or leaves a JWT-authed request be.
    plug :load_from_bearer

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Fleetms.Accounts.User,
      required?: false,
      on_error: &FleetmsWeb.Plugs.ApiTenant.ignore_api_key_error/2

    plug :set_actor, :user
    plug FleetmsWeb.Plugs.ApiTenant
  end

  # Resolves the `:org_id` path param into `current_scope` for plain controllers
  # (e.g. CSV report downloads), the way the LiveViews get it from an on_mount hook.
  pipeline :org_scoped do
    plug FleetmsWeb.Plugs.RequireOrganization
  end

  # For the forwarded feature-flags UI (a plain Plug router). It brings its own
  # CSRF protection, so we deliberately omit `:protect_from_forgery`; we add the
  # session + super-admin gate so only platform staff can reach it.
  pipeline :feature_flags_ui do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :load_from_session
    plug FleetmsWeb.Plugs.RequireSuperAdmin
  end

  # Liveness check for the platform (Fly). No pipeline, no DB — just proves the
  # server is up. Excluded from force_ssl in config/prod.exs.
  scope "/", FleetmsWeb do
    get "/health", HealthController, :index
  end

  # Public payment-provider callbacks: no auth and no tenant. The customer returns
  # here from DPO's hosted checkout; we verify with the provider before trusting it.
  pipeline :public_page do
    plug :accepts, ["html"]
  end

  pipeline :provider_webhook do
    plug :accepts, ["json"]
  end

  scope "/billing", FleetmsWeb.Billing do
    pipe_through :public_page

    get "/pay/dpo/return", DpoReturnController, :show
  end

  scope "/billing/webhooks", FleetmsWeb.Billing do
    pipe_through :provider_webhook

    post "/lenco", LencoWebhookController, :create
  end

  # Feature-flags admin UI (FunWithFlags), platform-staff only. It's a plain Plug
  # router with its own CSRF, forwarded outside the :browser pipeline.
  scope "/admin" do
    pipe_through :feature_flags_ui
    forward "/feature-flags", FunWithFlags.UI.Router, namespace: "admin/feature-flags"
  end

  # Public API docs + token login — no auth, defined BEFORE the authenticated
  # forward below so these exact paths match first. The OpenAPI spec is schema
  # only (no data), so it and the Swagger UI are open; the data endpoints aren't.
  pipeline :api_docs do
    plug :accepts, ["json", "html"]
    plug OpenApiSpex.Plug.PutApiSpec, module: FleetmsWeb.ApiSpec
  end

  pipeline :accepts_json do
    plug :accepts, ["json"]
  end

  scope "/api/v1" do
    pipe_through :api_docs
    get "/open_api", OpenApiSpex.Plug.RenderSpec, []
    get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/open_api"
  end

  scope "/api/v1", FleetmsWeb do
    pipe_through [:accepts_json]
    post "/sign-in", ApiSessionController, :create
    post "/register", ApiAuthController, :register
    post "/request-password-reset", ApiAuthController, :request_password_reset
    post "/reset-password", ApiAuthController, :reset_password
  end

  # Organization membership management — a plain controller (see the module doc for
  # why it isn't an AshJsonApi route). Defined before the forward so these exact
  # paths win; shares the authenticated + tenant-resolving `:json_api` pipeline.
  scope "/api/v1", FleetmsWeb do
    pipe_through :json_api
    get "/members", ApiMembersController, :index
    post "/members", ApiMembersController, :create
    post "/members/:id/suspend", ApiMembersController, :suspend
    post "/members/:id/reactivate", ApiMembersController, :reactivate
    delete "/members/:id", ApiMembersController, :delete

    post "/uploads", ApiUploadController, :create
    delete "/uploads", ApiUploadController, :delete
  end

  # Public JSON:API (AshJsonApi), versioned under /api/v1.
  scope "/api/v1" do
    pipe_through :json_api
    forward "/", FleetmsWeb.JsonApiRouter
  end

  scope "/", FleetmsWeb do
    pipe_through :browser

    # Authenticated, but no tenant yet: create or choose an organization.
    ash_authentication_live_session :require_user,
      on_mount: {FleetmsWeb.LiveUserAuth, :live_user_required} do
      live "/orgs", OrgLive.Index
      live "/orgs/new", OrgLive.New
    end

    # Platform staff only (is_super_admin), tenant-less: manage clients across orgs.
    ash_authentication_live_session :require_platform_admin,
      on_mount: [
        {FleetmsWeb.LiveUserAuth, :live_user_required},
        {FleetmsWeb.LiveUserAuth, :require_platform_admin}
      ] do
      live "/admin", AdminLive.Dashboard, :index
      live "/admin/organizations", AdminLive.Organizations, :index
      live "/admin/organizations/:id", AdminLive.OrganizationShow, :show
      live "/admin/individuals", AdminLive.Individuals, :index
      live "/admin/access-log", AdminLive.AccessLog, :index
      live "/admin/provision", AdminLive.Provision, :new
    end

    # Authenticated AND scoped to an organization (tenant) via `/o/:org_id`.
    ash_authentication_live_session :require_org,
      on_mount: [
        {FleetmsWeb.LiveUserAuth, :live_user_required},
        {FleetmsWeb.LiveUserAuth, :require_organization},
        {FleetmsWeb.LiveNotifications, :notifications}
      ] do
      live "/o/:org_id", DashboardLive
      live "/o/:org_id/calendar", CalendarLive
      live "/o/:org_id/notifications", NotificationLive.Index
      live "/o/:org_id/profile", ProfileLive
      live "/o/:org_id/settings", SettingsLive
      live "/o/:org_id/organization-settings", OrgSettingsLive
      live "/o/:org_id/billing", BillingLive
      live "/o/:org_id/users", UserLive, :index
      live "/o/:org_id/users/new", UserLive, :new
      live "/o/:org_id/users/:user_id", UserLive, :show
      live "/o/:org_id/users/:user_id/edit", UserLive, :edit
      live "/o/:org_id/users/:user_id/delete", UserLive, :delete
      live "/o/:org_id/roles", RoleLive
      live "/o/:org_id/user-roles", UserRoleLive
      live "/o/:org_id/tags", TagLive.Index

      live "/o/:org_id/reports", ReportLive.Index
      live "/o/:org_id/reports/maintenance", ReportLive.Maintenance
      live "/o/:org_id/reports/cost-of-ownership", ReportLive.CostOfOwnership
      live "/o/:org_id/reports/fuel", ReportLive.Fuel
      live "/o/:org_id/reports/roster", ReportLive.Roster

      live "/o/:org_id/vehicles", VehicleLive.Index, :index
      live "/o/:org_id/vehicles/new", VehicleLive.Form, :new
      live "/o/:org_id/vehicles/import", VehicleLive.Import, :import
      live "/o/:org_id/vehicles/:id", VehicleLive.Show, :show
      live "/o/:org_id/vehicles/:id/edit", VehicleLive.Form, :edit

      live "/o/:org_id/issues", IssueLive.Index, :index
      live "/o/:org_id/issues/new", IssueLive.Form, :new
      live "/o/:org_id/issues/:id", IssueLive.Show, :show
      live "/o/:org_id/issues/:id/edit", IssueLive.Form, :edit

      live "/o/:org_id/inspection-forms", InspectionFormLive.Index, :index
      live "/o/:org_id/inspection-forms/new", InspectionFormLive.Form, :new
      live "/o/:org_id/inspection-forms/:id/build", InspectionFormLive.Build, :build

      live "/o/:org_id/inspections", InspectionLive.Index, :index
      live "/o/:org_id/inspections/new", InspectionLive.New, :new
      live "/o/:org_id/inspections/:id", InspectionLive.Show, :show

      live "/o/:org_id/inspection-schedules", InspectionScheduleLive.Index, :index
      live "/o/:org_id/inspection-schedules/new", InspectionScheduleLive.Form, :new
      live "/o/:org_id/inspection-schedules/:id/edit", InspectionScheduleLive.Form, :edit

      live "/o/:org_id/inspection-assignments", InspectionAssignmentLive.Index, :index

      live "/o/:org_id/assignments", AssignmentLive.Index, :index
      live "/o/:org_id/assignments/new", AssignmentLive.Form, :new
      live "/o/:org_id/assignments/:id/edit", AssignmentLive.Form, :edit

      live "/o/:org_id/renewals", RenewalLive.Index, :index
      live "/o/:org_id/renewals/new", RenewalLive.Form, :new
      live "/o/:org_id/renewals/:id/edit", RenewalLive.Form, :edit

      live "/o/:org_id/fuel", FuelLive.Index, :index
      live "/o/:org_id/fuel/new", FuelLive.Form, :new
      live "/o/:org_id/fuel/:id/edit", FuelLive.Form, :edit

      live "/o/:org_id/expenses", ExpenseLive.Index, :index
      live "/o/:org_id/expenses/new", ExpenseLive.Form, :new
      live "/o/:org_id/expenses/:id/edit", ExpenseLive.Form, :edit

      live "/o/:org_id/drivers", DriverLive.Index, :index
      live "/o/:org_id/drivers/new", DriverLive.Form, :new
      live "/o/:org_id/drivers/:id/edit", DriverLive.Form, :edit

      live "/o/:org_id/contacts", ContactLive.Index, :index
      live "/o/:org_id/contacts/new", ContactLive.Form, :new
      live "/o/:org_id/contacts/:id/edit", ContactLive.Form, :edit

      live "/o/:org_id/service-tasks", ServiceTaskLive.Index, :index
      live "/o/:org_id/service-tasks/new", ServiceTaskLive.Form, :new
      live "/o/:org_id/service-tasks/:id/edit", ServiceTaskLive.Form, :edit

      live "/o/:org_id/vendors", VendorLive.Index, :index
      live "/o/:org_id/vendors/new", VendorLive.Form, :new
      live "/o/:org_id/vendors/:id/edit", VendorLive.Form, :edit

      live "/o/:org_id/service-groups", ServiceGroupLive.Index, :index
      live "/o/:org_id/service-groups/new", ServiceGroupLive.Form, :new
      live "/o/:org_id/service-groups/:id/edit", ServiceGroupLive.Form, :edit

      live "/o/:org_id/service-reminders", ServiceReminderLive.Index, :index
      live "/o/:org_id/service-reminders/new", ServiceReminderLive.Form, :new
      live "/o/:org_id/service-reminders/:id/edit", ServiceReminderLive.Form, :edit

      live "/o/:org_id/work-orders", WorkOrderLive.Index, :index
      live "/o/:org_id/work-orders/new", WorkOrderLive.Form, :new
      live "/o/:org_id/work-orders/:id/edit", WorkOrderLive.Form, :edit
      live "/o/:org_id/work-orders/:id", WorkOrderLive.Show, :show

      live "/o/:org_id/parts", PartLive.Index, :index
      live "/o/:org_id/parts/new", PartLive.Form, :new
      live "/o/:org_id/parts/:id/edit", PartLive.Form, :edit
      live "/o/:org_id/parts/:id/stock", PartLive.Stock, :index

      live "/o/:org_id/inventory-locations", LocationLive.Index, :index
      live "/o/:org_id/inventory-locations/new", LocationLive.Form, :new
      live "/o/:org_id/inventory-locations/:id/edit", LocationLive.Form, :edit
    end
  end

  # Controller-served report downloads (CSV), org-scoped like the LiveViews.
  scope "/", FleetmsWeb do
    pipe_through [:browser, :org_scoped]

    get "/o/:org_id/reports/maintenance.csv", ReportController, :maintenance
    get "/o/:org_id/reports/cost-of-ownership.csv", ReportController, :cost_of_ownership
    get "/o/:org_id/reports/fuel.csv", ReportController, :fuel
    get "/o/:org_id/reports/roster.csv", ReportController, :roster

    get "/o/:org_id/vehicles/import-template.csv", VehicleController, :import_template
  end

  scope "/", FleetmsWeb do
    pipe_through :browser

    get "/", PageController, :home
    auth_routes AuthController, Fleetms.Accounts.User, path: "/auth"

    # Our own sign-out: a confirmed DELETE straight to AuthController.sign_out
    # (clears the session, redirects home). We deliberately do NOT use
    # `sign_out_route/1`, whose GET route renders the Ash-branded SignOutLive page.
    delete "/sign-out", AuthController, :sign_out

    # Platform staff: enter/leave "manage an individual client" mode. These write
    # the session (LiveViews can't), then hand off to the pool's LiveViews.
    get "/admin/individuals/:owner_id/enter", AdminController, :enter_individual
    get "/admin/exit-individual", AdminController, :exit_individual

    # Custom authentication views (replacing the generated AshAuthentication UI).
    # The pages POST to the `auth_routes` controller above to do the actual work.
    ash_authentication_live_session :auth_no_user,
      on_mount: [{FleetmsWeb.LiveUserAuth, :live_no_user}] do
      live "/sign-in", AuthLive.SignIn
      live "/register", AuthLive.Register
      live "/forgot-password", AuthLive.ForgotPassword
      live "/password-reset/:token", AuthLive.ResetPassword
      live "/invitations/:token", InvitationLive.Accept
    end

    # Remove this if you do not use the confirmation strategy
    confirm_route Fleetms.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [FleetmsWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Fleetms.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [FleetmsWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", FleetmsWeb do
  #   pipe_through :api
  # end

  # Dev-only component/theme style guide.
  if Application.compile_env(:fleetms, :dev_routes) do
    scope "/", FleetmsWeb do
      pipe_through :browser

      live "/theme", ThemeLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:fleetms, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FleetmsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:fleetms, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end

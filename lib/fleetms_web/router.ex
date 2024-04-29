defmodule FleetmsWeb.Router do
  use FleetmsWeb, :router
  use AshAuthentication.Phoenix.Router
  import AshAdmin.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FleetmsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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

  scope "/", FleetmsWeb do
    pipe_through [:browser, :public_layout]

    get "/", PageController, :home
  end

  scope "/", FleetmsWeb do
    pipe_through [:browser, :auth_layout]

    ash_authentication_live_session :redirect_if_authenticated,
      on_mount: [
        {FleetmsWeb.LiveUserAuth, :redirect_if_authenticated},
        {FleetmsWeb.LiveUserAuth, :user_optional}
      ],
      layout: {FleetmsWeb.Layouts, :auth} do
      live "/sign-up", AuthLive.SignUp
      live "/sign-in", AuthLive.SignIn
    end
  end

  scope "/", FleetmsWeb do
    pipe_through :browser

    get "/sign-out", AuthController, :sign_out
    auth_routes_for Fleetms.Accounts.User, to: AuthController
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
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      ash_admin "/admin"
      live_dashboard "/dashboard", metrics: FleetmsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

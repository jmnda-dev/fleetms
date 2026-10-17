defmodule FleetmsWeb.ErrorHTML do
  @moduledoc """
  Renders HTML error pages (404 / 403 / 500 / 503).

  Error responses render OUTSIDE the app's root layout, so each page is a
  self-contained document that loads the same stylesheet, fonts and light/dark
  theme script as `layouts/root.html.heex` — it therefore matches the app and
  respects the viewer's theme. The markup is deliberately simple (a centered
  card) so the 500 page still reads even if assets fail to load.
  """
  use FleetmsWeb, :html

  # 404 — the most common; anything Phoenix can't route lands here.
  def render("404.html", assigns) do
    page(assigns,
      code: "404",
      icon: "fa-compass",
      title: gettext("Page not found"),
      message: gettext("The page you're looking for doesn't exist or may have moved.")
    )
  end

  # 403 — authenticated but not allowed (there's no Phoenix default for this).
  def render("403.html", assigns) do
    page(assigns,
      code: "403",
      icon: "fa-lock",
      title: gettext("Access denied"),
      message: gettext("You don't have permission to view this page.")
    )
  end

  # 503 — for a maintenance window (served deliberately, not on a crash).
  def render("503.html", assigns) do
    page(assigns,
      code: "503",
      icon: "fa-screwdriver-wrench",
      title: gettext("Down for maintenance"),
      message: gettext("We're carrying out some scheduled maintenance and will be back shortly.")
    )
  end

  # 500 and any other status → a generic "something went wrong" page.
  def render(template, assigns) do
    page(assigns,
      code: error_code(template),
      icon: "fa-triangle-exclamation",
      title: gettext("Something went wrong"),
      message:
        gettext("An unexpected error occurred. Our team has been notified — please try again.")
    )
  end

  # "500.html" -> "500"; fall back to Phoenix's status message for odd templates.
  defp error_code(template) do
    case Integer.parse(template) do
      {code, _} -> to_string(code)
      :error -> Phoenix.Controller.status_message_from_template(template)
    end
  end

  # Error assigns are a plain map without change-tracking, so build the component
  # assigns by hand (with `__changed__: nil` so HEEx renders everything).
  defp page(assigns, fields) do
    assigns = assigns |> Map.merge(Map.new(fields)) |> Map.put(:__changed__, nil)

    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{@code} · {@title} · FleetMS</title>
        <link rel="icon" href={~p"/images/favicon.svg"} type="image/svg+xml" />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&display=swap"
        />
        <link rel="stylesheet" href={~p"/fontawesome/css/fontawesome.css"} />
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script>
          if (
            localStorage.getItem("color-theme") === "dark" ||
            (!("color-theme" in localStorage) && window.matchMedia("(prefers-color-scheme: dark)").matches)
          ) {
            document.documentElement.classList.add("dark");
          }
          document.documentElement.setAttribute(
            "data-theme",
            localStorage.getItem("app-theme") || "midnight"
          );
        </script>
      </head>
      <body class="bg-gray-50 antialiased dark:bg-gray-900">
        <main class="flex min-h-screen flex-col items-center justify-center px-4 py-16 text-center">
          <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary-50 text-primary-600 dark:bg-primary-900/30 dark:text-primary-400">
            <i class={"fa-solid #{@icon} text-2xl"}></i>
          </div>
          <p class="mt-6 text-5xl font-extrabold tracking-tight text-gray-900 dark:text-white">
            {@code}
          </p>
          <h1 class="mt-2 text-xl font-semibold text-gray-900 dark:text-white">{@title}</h1>
          <p class="mt-2 max-w-md text-sm text-gray-500 dark:text-gray-400">{@message}</p>
          <a
            href="/"
            class="mt-8 inline-flex items-center gap-2 rounded-lg bg-primary-700 px-6 py-3 text-sm font-medium text-white hover:bg-primary-800 focus:outline-none focus:ring-2 focus:ring-primary-300 dark:focus:ring-primary-800"
          >
            <i class="fa-solid fa-arrow-left text-xs"></i> {gettext("Back to home")}
          </a>
        </main>
      </body>
    </html>
    """
  end
end

defmodule FleetmsWeb.LayoutComponents do
  use Phoenix.Component
  import FleetmsWeb.CoreComponents, only: [button: 1]
  use FleetmsWeb, :verified_routes
  alias Fleetms.Accounts.User
  alias Fleetms.FeatureFlags

  @doc """
  A Navbar component for public pages
  """

  attr :current_user, :map, required: true

  def public_navbar(assigns) do
    ~H"""
    <header>
      <nav class="bg-white border-gray-200 px-4 lg:px-6 py-2.5 dark:bg-gray-800">
        <div class="flex flex-wrap justify-between items-center mx-auto max-w-screen-xl">
          <a href="https://flowbite.com" class="flex items-center">
            <img src="/images/logo_light.svg" class="dark:hidden mr-3 h-6 sm:h-14" alt="Fleetms Logo" />
            <img
              src="/images/logo_dark.svg"
              class="hidden dark:flex mr-3 h-6 sm:h-14"
              alt="Fleetms Logo"
            />
          </a>
          <div class="flex items-center lg:order-2">
            <button
              id="themeToggle"
              data-tooltip-target="tooltip-toggle"
              type="button"
              class="text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 focus:outline-none focus:ring-4 focus:ring-gray-200 dark:focus:ring-gray-700 rounded-lg text-sm p-2.5 mr-2.5"
            >
              <svg
                id="themeToggleDarkIcon"
                class="hidden w-5 h-5"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z"></path>
              </svg>
              <svg
                id="themeToggleLightIcon"
                class="hidden w-5 h-5"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z"
                  fill-rule="evenodd"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
            </button>
            <div
              id="tooltip-toggle"
              role="tooltip"
              class="absolute z-10 invisible inline-block px-3 py-2 text-sm font-medium text-white transition-opacity duration-300 bg-gray-900 rounded-lg shadow-sm opacity-0 tooltip"
            >
              Toggle dark mode
              <div class="tooltip-arrow" data-popper-arrow></div>
            </div>

            <%= if @current_user do %>
              <.link navigate={~p"/dashboard"}>
                <.button>
                  Dashboard
                </.button>
              </.link>
              <button
                class="flex items-center gap-4 hover:cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-700 focus:outline-none focus:ring-4 focus:ring-gray-200 dark:focus:ring-gray-700 rounded-lg p-2 mr-2.5"
                id="user-menu-button"
                aria-expanded="false"
                data-dropdown-toggle="dropdown"
              >
                <img
                  class="w-10 h-10 rounded-full"
                  src={
                    Fleetms.UserProfilePhoto.url(
                      {@current_user.user_profile.profile_photo, @current_user.user_profile},
                      :thumb
                    )
                  }
                  alt={"#{@current_user.full_name} Profile Photo"}
                />
                <div class="font-medium dark:text-white">
                  <div><%= @current_user.full_name %></div>
                  <div class="text-sm text-gray-500 dark:text-gray-400">
                    <%= @current_user.email %>
                  </div>
                </div>
              </button>
              <!-- Dropdown menu -->
              <div
                class="hidden z-50 my-4 w-56 text-base list-none bg-white rounded divide-y divide-gray-100 shadow dark:bg-gray-700 dark:divide-gray-600"
                id="dropdown"
              >
                <ul class="py-1 text-gray-500 dark:text-gray-400" aria-labelledby="dropdown">
                  <li>
                    <.link
                      navigate={~p"/my_profile"}
                      class="block py-2 px-4 text-sm hover:bg-gray-100 dark:hover:bg-gray-600 dark:text-gray-400 dark:hover:text-white"
                    >
                      My profile
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/settings"}
                      class="block py-2 px-4 text-sm hover:bg-gray-100 dark:hover:bg-gray-600 dark:text-gray-400 dark:hover:text-white"
                    >
                      Account settings
                    </.link>
                  </li>
                </ul>
                <ul class="py-1 text-gray-500 dark:text-gray-400" aria-labelledby="dropdown">
                  <li>
                    <.link
                      navigate={~p"/sign-out"}
                      class="block py-2 px-4 text-sm hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white"
                    >
                      Sign out
                    </.link>
                  </li>
                </ul>
              </div>

            <% else %>
              <.link navigate={~p"/demo/sign-in"}>
                <.button>
                  Demo
                </.button>
              </.link>
              <.link navigate={~p"/sign-in"}>
                <.button kind={:light}>
                  Sign In
                </.button>
              </.link>
              <.link :if={FeatureFlags.Accounts.user_registration_enabled?()} navigate={~p"/sign-up"}>
                <.button>
                  Sign up
                </.button>
              </.link>
            <% end %>
            <button
              data-collapse-toggle="mobile-menu-2"
              type="button"
              class="inline-flex items-center p-2 ml-1 text-sm text-gray-500 rounded-lg lg:hidden hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-600"
              aria-controls="mobile-menu-2"
              aria-expanded="false"
            >
              <span class="sr-only">Open main menu</span>
              <svg
                class="w-6 h-6"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M3 5a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 10a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 15a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
              <svg
                class="hidden w-6 h-6"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
            </button>
          </div>
          <div
            class="hidden justify-between items-center w-full lg:flex lg:w-auto lg:order-1"
            id="mobile-menu-2"
          >
            <ul class="flex flex-col mt-4 font-medium lg:flex-row lg:space-x-8 lg:mt-0">
              <li>
                <a
                  href="#"
                  class="block py-2 pr-4 pl-3 text-primary-600 border-b border-gray-100 hover:bg-gray-50 lg:hover:bg-transparent lg:border-0 lg:hover:text-primary-700 lg:p-0 dark:text-primary-500 lg:dark:hover:text-white dark:hover:bg-gray-700 dark:hover:text-white lg:dark:hover:bg-transparent dark:border-gray-700"
                  aria-current="page"
                >
                  Home
                </a>
              </li>
              <li>
                <a
                  href="#"
                  class="block py-2 pr-4 pl-3 text-gray-700 border-b border-gray-100 hover:bg-gray-50 lg:hover:bg-transparent lg:border-0 lg:hover:text-primary-700 lg:p-0 dark:text-gray-400 lg:dark:hover:text-white dark:hover:bg-gray-700 dark:hover:text-white lg:dark:hover:bg-transparent dark:border-gray-700"
                >
                  Features
                </a>
              </li>
              <li>
                <a
                  href="#"
                  class="block py-2 pr-4 pl-3 text-gray-700 border-b border-gray-100 hover:bg-gray-50 lg:hover:bg-transparent lg:border-0 lg:hover:text-primary-700 lg:p-0 dark:text-gray-400 lg:dark:hover:text-white dark:hover:bg-gray-700 dark:hover:text-white lg:dark:hover:bg-transparent dark:border-gray-700"
                >
                  Contact
                </a>
              </li>
              <li>
                <a
                  href="#"
                  class="block py-2 pr-4 pl-3 text-gray-700 border-b border-gray-100 hover:bg-gray-50 lg:hover:bg-transparent lg:border-0 lg:hover:text-primary-700 lg:p-0 dark:text-gray-400 lg:dark:hover:text-white dark:hover:bg-gray-700 dark:hover:text-white lg:dark:hover:bg-transparent dark:border-gray-700"
                >
                  Blog
                </a>
              </li>
            </ul>
          </div>
        </div>
      </nav>
    </header>
    """
  end

  attr :current_user, :map, required: false

  def navbar(assigns) do
    ~H"""
    <nav
      id="navbar"
      phx-hook="initDarkModeToggle"
      class="fixed z-30 w-full bg-white border-b border-gray-200 dark:bg-gray-800 dark:border-gray-700"
    >
      <div class="py-3 px-3 lg:px-5 lg:pl-3">
        <div class="flex justify-between items-center">
          <div class="flex justify-start items-center">
            <button
              id="toggleSidebar"
              aria-expanded="true"
              aria-controls="sidebar"
              class="hidden p-2 mr-3 text-gray-600 rounded cursor-pointer lg:inline hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-white dark:hover:bg-gray-700"
            >
              <svg
                class="w-6 h-6"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M3 5a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 10a1 1 0 011-1h6a1 1 0 110 2H4a1 1 0 01-1-1zM3 15a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
            </button>
            <button
              id="toggleSidebarMobile"
              aria-expanded="true"
              aria-controls="sidebar"
              class="p-2 mr-2 text-gray-600 rounded cursor-pointer lg:hidden hover:text-gray-900 hover:bg-gray-100 focus:bg-gray-100 dark:focus:bg-gray-700 focus:ring-2 focus:ring-gray-100 dark:focus:ring-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white"
            >
              <svg
                id="toggleSidebarMobileHamburger"
                class="w-6 h-6"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M3 5a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 10a1 1 0 011-1h6a1 1 0 110 2H4a1 1 0 01-1-1zM3 15a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
              <svg
                id="toggleSidebarMobileClose"
                class="hidden w-6 h-6"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
            </button>
            <.link href={~p"/"} class="flex mr-14">
              <img src="/images/logo_light.svg" class="dark:hidden mr-3 h-10" alt="Fleetms Logo" />
              <img src="/images/logo_dark.svg" class="hidden dark:block mr-3 h-10" alt="Fleetms Logo" />
            </.link>
            <form action="#" method="GET" class="hidden lg:block lg:pl-2">
              <label for="topbar-search" class="sr-only">Search</label>
              <div class="relative mt-1 lg:w-96">
                <div class="flex absolute inset-y-0 left-0 items-center pl-3 pointer-events-none">
                  <svg
                    class="w-5 h-5 text-gray-500 dark:text-gray-400"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z"
                      clip-rule="evenodd"
                    >
                    </path>
                  </svg>
                </div>
                <input
                  type="text"
                  name="email"
                  id="topbar-search"
                  class="bg-gray-50 border border-gray-300 text-gray-900 sm:text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 block w-full pl-10 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
                  placeholder="Search"
                />
              </div>
            </form>
          </div>
          <div class="flex items-center">
            <button
              id="toggleSidebarMobileSearch"
              type="button"
              class="p-2 text-gray-500 rounded-lg lg:hidden hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white"
            >
              <span class="sr-only">Search</span>

              <svg
                class="w-6 h-6"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
            </button>

            <button
              type="button"
              data-dropdown-toggle="notification-dropdown"
              class="p-2 text-gray-500 rounded-lg hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-white dark:hover:bg-gray-700"
            >
              <span class="sr-only">View notifications</span>

              <svg
                class="w-6 h-6"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z">
                </path>
              </svg>
            </button>

            <div
              class="hidden overflow-hidden z-20 z-50 my-4 max-w-sm text-base list-none bg-white rounded divide-y divide-gray-100 shadow-lg dark:divide-gray-600 dark:bg-gray-700"
              id="notification-dropdown"
            >
              <div class="block py-2 px-4 text-base font-medium text-center text-gray-700 bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                Notifications
              </div>

              <a
                href="#"
                class="block py-2 text-base font-normal text-center text-gray-900 bg-gray-50 hover:bg-gray-100 dark:bg-gray-700 dark:text-white dark:hover:underline"
              >
                <div class="inline-flex items-center ">
                  <svg
                    class="mr-2 w-5 h-5"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path d="M10 12a2 2 0 100-4 2 2 0 000 4z"></path>
                    <path
                      fill-rule="evenodd"
                      d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z"
                      clip-rule="evenodd"
                    >
                    </path>
                  </svg>
                  View all
                </div>
              </a>
            </div>

            <button
              id="theme-toggle"
              data-tooltip-target="tooltip-toggle"
              type="button"
              class="text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 focus:outline-none focus:ring-4 focus:ring-gray-200 dark:focus:ring-gray-700 rounded-lg text-sm p-2.5"
            >
              <svg
                id="theme-toggle-dark-icon"
                class="hidden w-5 h-5"
                data-clone-attributes
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z"></path>
              </svg>
              <svg
                id="theme-toggle-light-icon"
                class="hidden w-5 h-5"
                data-clone-attributes
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z"
                  fill-rule="evenodd"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
            </button>
            <div
              id="tooltip-toggle"
              role="tooltip"
              class="inline-block absolute invisible z-10 py-2 px-3 text-sm font-medium text-white bg-gray-900 rounded-lg shadow-sm opacity-0 transition-opacity duration-300 tooltip"
            >
              Toggle dark mode
              <div class="tooltip-arrow" data-popper-arrow></div>
            </div>

            <div class="flex items-center ml-3">
              <div>
                <button
                  type="button"
                  class="flex text-sm bg-gray-800 rounded-full focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600"
                  id="user-menu-button-2"
                  aria-expanded="false"
                  data-dropdown-toggle="dropdown-2"
                >
                  <span class="sr-only">Open user menu</span>
                  <img
                    class="w-8 h-8 rounded-full"
                    src={
                      Fleetms.UserProfilePhoto.url(
                        {@current_user.user_profile.profile_photo, @current_user.user_profile},
                        :thumb
                      )
                    }
                    alt={"#{@current_user.full_name} Profile Photo"}
                  />
                </button>
              </div>

              <div
                class="hidden z-50 my-4 text-base list-none bg-white rounded divide-y divide-gray-100 shadow dark:bg-gray-700 dark:divide-gray-600"
                id="dropdown-2"
              >
                <div class="py-3 px-4" role="none">
                  <p class="text-sm text-gray-900 dark:text-white" role="none">
                    <%= @current_user.full_name %>
                  </p>
                  <p class="text-sm font-medium text-gray-900 truncate dark:text-gray-300" role="none">
                    <%= @current_user.email %>
                  </p>
                </div>
                <ul class="py-1" role="none">
                  <li>
                    <.link
                      navigate={~p"/my_profile"}
                      class="block py-2 px-4 text-sm text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-600 dark:hover:text-white"
                      role="menuitem"
                    >
                      My Profile
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/settings"}
                      class="block py-2 px-4 text-sm text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-600 dark:hover:text-white"
                      role="menuitem"
                    >
                      Settings
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/sign-out"}
                      class="block py-2 px-4 text-sm text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-600 dark:hover:text-white"
                      role="menuitem"
                    >
                      Sign out
                    </.link>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  attr :active_link, :any, required: true
  attr :current_user, :map, required: true

  def sidebar(assigns) do
    ~H"""
    <aside
      id="sidebar"
      phx-hook="initSidebarJs"
      class="flex hidden fixed top-0 left-0 z-20 flex-col flex-shrink-0 pt-16 w-64 h-full duration-75 lg:flex transition-width"
      aria-label="Sidebar"
    >
      <div class="flex relative flex-col flex-1 pt-0 min-h-0 bg-white border-r border-gray-200 dark:bg-gray-800 dark:border-gray-700">
        <div class="flex overflow-y-auto flex-col flex-1 pt-5 pb-4">
          <div class="flex-1 px-3 space-y-1 bg-white divide-y divide-gray-200 dark:bg-gray-800 dark:divide-gray-700">
            <ul class="pb-2 space-y-2">
              <li>
                <form action="#" method="GET" class="lg:hidden">
                  <label for="mobile-search" class="sr-only">Search</label>
                  <div class="relative">
                    <div class="flex absolute inset-y-0 left-0 items-center pl-3 pointer-events-none">
                      <svg
                        class="w-5 h-5 text-gray-500"
                        fill="currentColor"
                        viewBox="0 0 20 20"
                        xmlns="http://www.w3.org/2000/svg"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z"
                          clip-rule="evenodd"
                        >
                        </path>
                      </svg>
                    </div>
                    <input
                      type="text"
                      name="email"
                      id="mobile-search"
                      class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 block w-full pl-10 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-gray-200 dark:focus:ring-primary-500 dark:focus:border-primary-500"
                      placeholder="Search"
                    />
                  </div>
                </form>
              </li>
              <li>
                <.link
                  navigate={~p"/dashboard"}
                  class={[
                    "flex items-center px-2 text-base font-normal rounded-lg transition duration-75 group",
                    @active_link != :dashboard &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link == :dashboard &&
                      "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                >
                  <i class="fa-solid fa-chart-pie w-6 h-8 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>
                  <span class="ml-3" sidebar-toggle-item>Dashboard</span>
                </.link>
              </li>
              <li>
                <button
                  type="button"
                  class={[
                    "flex items-center px-2 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group",
                    @active_link not in [:vehicles, :vehicle_assignments] &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link in [:vehicles, :vehicle_assignments] &&
                      "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                  aria-controls="dropdown-vehicles-link"
                  data-collapse-toggle="dropdown-vehicles-link"
                >
                  <i class="fa-solid fa-truck w-6 h-8 pt-1 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>
                  <span class="flex-1 ml-3 text-left whitespace-nowrap" sidebar-toggle-item>
                    Vehicles
                  </span>
                  <i class="fa-solid fa-angle-down w-6" sidebar-toggle-item></i>
                </button>

                <ul
                  id="dropdown-vehicles-link"
                  class={[
                    @active_link not in [:vehicles, :vehicle_assignments, :vehicle_general_reminders] &&
                      "hidden",
                    "py-2 space-y-2 "
                  ]}
                >
                  <li>
                    <.link
                      navigate={~p"/vehicles"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :vehicles &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :vehicles &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Vehicles
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/vehicle_assignments"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :vehicle_assignments &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :vehicle_assignments &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Assignments
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/vehicle_general_reminders"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :vehicle_general_reminders &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :vehicle_general_reminders &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Reminders
                    </.link>
                  </li>
                </ul>
              </li>
              <li>
                <button
                  type="button"
                  class={[
                    "flex items-center px-2 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group",
                    @active_link not in [:inspection_submissions, :inspection_forms] &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link in [:inspection_submissions, :inspection_forms] &&
                      "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                  aria-controls="dropdown-inspections-link"
                  data-collapse-toggle="dropdown-inspections-link"
                >
                  <i class="fa-solid fa-list-check w-6 h-8 pt-1 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>
                  <span class="flex-1 ml-3 text-left whitespace-nowrap" sidebar-toggle-item>
                    Inspections
                  </span>
                  <i class="fa-solid fa-angle-down w-6"></i>
                </button>
                <ul
                  id="dropdown-inspections-link"
                  class={[
                    @active_link not in [:inspection_submissions, :inspection_forms] && "hidden",
                    "py-2 space-y-2 "
                  ]}
                >
                  <li>
                    <.link
                      navigate={~p"/inspection_forms"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :inspection_forms &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :inspection_forms &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Forms
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/inspections"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :inspection_submissions &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :inspection_submissions &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Submissions
                    </.link>
                  </li>
                </ul>
              </li>
              <li :if={FeatureFlags.VehicleIssues.module_enabled?(@current_user.organization)}>
                <.link
                  navigate={~p"/issues"}
                  class={[
                    "flex items-center px-2 text-base font-normal rounded-lg transition duration-75 group",
                    @active_link != :issues &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link == :issues &&
                      "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                >
                  <i class="fa-solid fa-circle-exclamation w-6 h-8 pt-1 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>
                  <span class="ml-3" sidebar-toggle-item>Issues</span>
                </.link>
              </li>
              <li :if={FeatureFlags.VehicleMaintenance.module_enabled?(@current_user.organization)}>
                <button
                  type="button"
                  class={[
                    "flex items-center px-2 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group",
                    @active_link not in [
                      :service_tasks,
                      :service_groups,
                      :service_reminders,
                      :work_orders
                    ] &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link in [
                      :service_tasks,
                      :service_groups,
                      :service_reminders,
                      :work_orders
                    ] && "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                  aria-controls="dropdown-service-links"
                  data-collapse-toggle="dropdown-service-links"
                >
                  <i class="fa-solid fa-screwdriver-wrench w-6 h-8 pt-1 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>

                  <span class="flex-1 ml-3 text-left whitespace-nowrap" sidebar-toggle-item>
                    Service
                  </span>
                  <i class="fa-solid fa-angle-down w-6" sidebar-toggle-item></i>
                </button>
                <ul
                  id="dropdown-service-links"
                  class={[
                    @active_link not in [
                      :service_reminders,
                      :service_groups,
                      :service_tasks,
                      :work_orders
                    ] && "hidden",
                    "py-2 space-y-2 "
                  ]}
                >
                  <li>
                    <.link
                      navigate={~p"/service_tasks"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :service_tasks &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :service_tasks &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Service Tasks
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/service_groups"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :service_groups &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :service_groups &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Service Groups
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/service_reminders"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :service_reminders &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :service_reminders &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Service Reminders
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/work_orders"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :work_orders &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :work_orders &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Work Orders
                    </.link>
                  </li>
                </ul>
              </li>
              <li :if={FeatureFlags.Accounts.user_management_enabled?(@current_user.organization)}>
                <button
                  type="button"
                  class={[
                    "flex items-center px-2 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group",
                    @active_link not in [:users_list] &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link in [:users_list] &&
                      "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                  aria-controls="dropdown-users"
                  data-collapse-toggle="dropdown-users"
                >
                  <i class="fa-solid fa-users w-6 h-8 pt-1 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>
                  <span class="flex-1 ml-3 text-left whitespace-nowrap" sidebar-toggle-item>
                    Users
                  </span>

                  <i class="fa-solid fa-angle-down w-6" sidebar-toggle-item></i>
                </button>
                <ul
                  :if={Ash.can?({User, :list}, @current_user)}
                  id="dropdown-users"
                  class={[@active_link != :users_list && "hidden", "py-2 space-y-2"]}
                >
                  <li>
                    <.link
                      navigate={~p"/users"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :users_list &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :users_list &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Users list
                    </.link>
                  </li>
                </ul>
              </li>
              <li :if={FeatureFlags.Inventory.module_enabled?(@current_user.organization)}>
                <button
                  type="button"
                  class={[
                    "flex items-center px-2 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group",
                    @active_link not in [:parts, :inventory_locations] &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link in [:parts, :inventory_locations] &&
                      "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                  aria-controls="dropdown-inventory-link"
                  data-collapse-toggle="dropdown-inventory-link"
                >
                  <i class="fa-solid fa-warehouse w-6 h-8 pt-1 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>
                  <span class="flex-1 ml-3 text-left whitespace-nowrap" sidebar-toggle-item>
                    Inventory
                  </span>
                  <i class="fa-solid fa-angle-down w-6" sidebar-toggle-item></i>
                </button>
                <ul
                  id="dropdown-inventory-link"
                  class={[
                    @active_link not in [:parts, :inventory_locations] && "hidden",
                    "py-2 space-y-2 "
                  ]}
                >
                  <li>
                    <.link
                      navigate={~p"/parts"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :parts &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :parts &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Parts
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/inventory_locations"}
                      class={[
                        "flex items-center p-2 pl-11 text-base font-normal rounded-lg transition duration-75 group",
                        @active_link != :inventory_locations &&
                          "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                        @active_link == :inventory_locations &&
                          "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                      ]}
                    >
                      Inventory Locations
                    </.link>
                  </li>
                </ul>
              </li>
              <li :if={FeatureFlags.FuelManagement.module_enabled?(@current_user.organization)}>
                <.link
                  navigate={~p"/fuel_histories"}
                  class={[
                    "flex items-center px-2 text-base font-normal rounded-lg transition duration-75 group",
                    @active_link != :fuel_histories &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link == :fuel_histories &&
                      "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                >
                  <i class="fa-solid fa-gas-pump w-6 h-8 pt-1 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>
                  <span class="ml-3" sidebar-toggle-item>Fuel Tracking</span>
                </.link>
              </li>
              <li :if={FeatureFlags.Common.reports_enabled?(@current_user.organization)}>
                <.link
                  navigate={~p"/reports"}
                  class={[
                    "flex items-center px-2 text-base font-normal rounded-lg transition duration-75 group",
                    @active_link != :reports &&
                      "text-gray-900 dark:text-gray-200 hover:text-primary-600 dark:hover:text-primary-300 hover:bg-primary-50 dark:hover:bg-gray-700",
                    @active_link == :reports &&
                      "text-primary-600 dark:text-primary-300 bg-primary-50 dark:bg-gray-700"
                  ]}
                >
                  <i class="fa-solid fa-chart-area w-6 h-8 pt-1 text-xl text-gray-500 transition duration-75 group-hover:text-gray-900 dark:text-gray-400 dark:group-hover:text-white">
                  </i>
                  <span class="ml-3" sidebar-toggle-item>Reports</span>
                </.link>
              </li>
            </ul>
          </div>
        </div>
        <div
          class="hidden absolute bottom-0 left-0 justify-center p-4 space-x-4 w-full lg:flex"
          sidebar-bottom-menu
        >
          <div
            id="tooltip-settings"
            role="tooltip"
            class="inline-block absolute invisible z-10 py-2 px-3 text-sm font-medium text-white bg-gray-900 rounded-lg shadow-sm opacity-0 transition-opacity duration-300 tooltip dark:bg-gray-700"
          >
            Settings page
            <div class="tooltip-arrow" data-popper-arrow></div>
          </div>
        </div>
      </div>
    </aside>

    <div class="hidden fixed inset-0 z-10 bg-gray-900/50 dark:bg-gray-900/90" id="sidebarBackdrop">
    </div>
    """
  end

  def footer(assigns) do
    ~H"""
    <footer class="p-4 my-6 mx-4 bg-white rounded-lg shadow md:flex md:items-center md:justify-between md:p-6 xl:p-8 dark:bg-gray-800">
      <ul class="flex flex-wrap items-center mb-6 space-y-1 md:mb-0">
        <li>
          <a
            href="#"
            class="mr-4 text-sm font-normal text-gray-500 hover:underline md:mr-6 dark:text-gray-400"
          >
            Terms
            and conditions
          </a>
        </li>
        <li>
          <a
            href="#"
            class="mr-4 text-sm font-normal text-gray-500 hover:underline md:mr-6 dark:text-gray-400"
          >
            Privacy
            Policy
          </a>
        </li>
        <li>
          <a
            href="#"
            class="mr-4 text-sm font-normal text-gray-500 hover:underline md:mr-6 dark:text-gray-400"
          >
            Licensing
          </a>
        </li>
        <li>
          <a
            href="#"
            class="mr-4 text-sm font-normal text-gray-500 hover:underline md:mr-6 dark:text-gray-400"
          >
            Cookie
            Policy
          </a>
        </li>
        <li>
          <a href="#" class="text-sm font-normal text-gray-500 hover:underline dark:text-gray-400">
            Contact
          </a>
        </li>
      </ul>
    </footer>
    <p class="my-10 text-sm text-center text-gray-500">
      &copy; 2019-2022 <a href="https://flowbite.com/" class="hover:underline" target="_blank">Fleetms</a>. All rights reserved.
    </p>
    """
  end
end

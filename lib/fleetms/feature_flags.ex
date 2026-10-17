defmodule Fleetms.FeatureFlags do
  @moduledoc """
  The platform's global feature flags, a thin wrapper over `FunWithFlags`.

  Flags are persisted in Postgres and toggled at runtime by platform staff (see
  the `/admin/feature-flags` UI); a change fans out to every node over PubSub, so
  no redeploy is needed. Call sites use the named predicates
  (`individual_registration?/0`, `user_registration?/0`) rather than `FunWithFlags`
  directly, so the flag set is discoverable and the library stays swappable.

  Each flag has a **default** (below). FunWithFlags treats an unknown flag as
  disabled, which is the wrong default for flags that gate existing behavior, so
  `ensure_defaults!/0` writes each flag's default once (on boot) without
  clobbering a value staff have already set.

    * `:individual_registration` (default on) — the pool-based individual-client
      workflow. Off ⇒ individuals are provisioned into their own org/schema and
      the pool UI is hidden.
    * `:user_registration` (default on) — public self-service sign-up.
    * `:maintenance_mode` (default off) — serve the 503 maintenance page to
      non-staff; staff pass through.
    * `:public_api` (default on) — the public JSON:API under `/api/v1`. Off ⇒ data
      endpoints return 503 (a global kill-switch for the REST API). *Enforced.*
    * `:api_keys` (default on) — whether users can create personal API keys in
      account settings. *Enforced in the settings UI.*
    * `:email_notifications` (default on) — global outbound-email switch (invites,
      confirmations, digests). Off ⇒ the app suppresses non-critical email.
      *Check `email_notifications?/0` at your send sites.*
    * `:sms_notifications` (default off) — outbound SMS (reminders, OTP). Reserved
      for the SMS-provider integration; ships **off** so nothing tries to send
      until a provider is configured.
    * `:onboarding_checklist` (default on) — the dashboard onboarding checklist.
    * `:demo_mode` (default off) — mark the deployment as a public demo (banner,
      and a hook you can use to soften destructive actions). Reserved.
  """

  # {flag, default_enabled?}
  @flags [
    individual_registration: true,
    user_registration: true,
    maintenance_mode: false,
    public_api: true,
    api_keys: true,
    email_notifications: true,
    sms_notifications: false,
    onboarding_checklist: true,
    demo_mode: false
  ]

  @doc "All known flag names."
  @spec names() :: [atom()]
  def names, do: Keyword.keys(@flags)

  @doc "Whether `flag` is enabled globally."
  @spec enabled?(atom()) :: boolean()
  def enabled?(flag) when is_atom(flag), do: FunWithFlags.enabled?(flag)

  def individual_registration?, do: enabled?(:individual_registration)
  def user_registration?, do: enabled?(:user_registration)
  def maintenance_mode?, do: enabled?(:maintenance_mode)
  def public_api?, do: enabled?(:public_api)
  def api_keys?, do: enabled?(:api_keys)
  def email_notifications?, do: enabled?(:email_notifications)
  def sms_notifications?, do: enabled?(:sms_notifications)
  def onboarding_checklist?, do: enabled?(:onboarding_checklist)
  def demo_mode?, do: enabled?(:demo_mode)

  @spec enable(atom()) :: :ok | {:error, any()}
  def enable(flag) when is_atom(flag), do: FunWithFlags.enable(flag)

  @spec disable(atom()) :: :ok | {:error, any()}
  def disable(flag) when is_atom(flag), do: FunWithFlags.disable(flag)

  @doc """
  Ensures each known flag exists at its default value, leaving any value staff
  have already set untouched. Idempotent and tolerant of a missing table (e.g.
  before the first migration), so it's safe to run on every boot.
  """
  @spec ensure_defaults!() :: :ok
  def ensure_defaults! do
    existing =
      case FunWithFlags.all_flag_names() do
        {:ok, names} -> names
        _ -> []
      end

    for {flag, default} <- @flags, flag not in existing do
      if default, do: enable(flag), else: disable(flag)
    end

    :ok
  rescue
    _ -> :ok
  end
end

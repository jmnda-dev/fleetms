This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


<!-- usage-rules-start -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications._

# Rules for working with Ash

## Understanding Ash

Ash is an opinionated, composable framework for building applications in Elixir. It provides a declarative approach to modeling your domain with resources at the center. Read documentation  *before* attempting to use its features. Do not assume that you have prior knowledge of the framework or its conventions.


<!-- ash-end -->
<!-- ash:actions-start -->
## ash:actions usage
# Actions

- Create specific, well-named actions rather than generic ones
- Put all business logic inside action definitions
- Use hooks like `Ash.Changeset.after_action/2`, `Ash.Changeset.before_action/2` to add additional logic
  inside the same transaction.
- Use hooks like `Ash.Changeset.after_transaction/2`, `Ash.Changeset.before_transaction/2` to add additional logic
  outside the transaction.
- Use action arguments for inputs that need validation
- Use preparations to modify queries before execution
- Preparations support `where` clauses for conditional execution
- Use `only_when_valid?` to skip preparations when the query is invalid
- Use changes to modify changesets before execution
- Use validations to validate changesets before execution
- Prefer domain code interfaces to call actions instead of directly building queries/changesets and calling functions in the `Ash` module
- A resource could be *only generic actions*. This can be useful when you are using a resource only to model behavior.
- Instead of defining functions in the domain, you should be defining actions and exposing them through code interface calls in the domain. Use standard actions when they fit what you're doing and generic actions when you need arbitrary functionality.

## Error Handling

Functions to call actions, like `Ash.create` and code interfaces like `MyApp.Accounts.register_user` all return ok/error tuples. All have `!` variations, like `Ash.create!` and `MyApp.Accounts.register_user!`. Use the `!` variations when you want to "let it crash", like if looking something up that should definitely exist, or calling an action that should always succeed. Always prefer the raising `!` variation over something like `{:ok, user} = MyApp.Accounts.register_user(...)`.

All Ash code returns errors in the form of `{:error, error_class}`. Ash categorizes errors into four main classes:

1. **Forbidden** (`Ash.Error.Forbidden`) - Occurs when a user attempts an action they don't have permission to perform
2. **Invalid** (`Ash.Error.Invalid`) - Occurs when input data doesn't meet validation requirements
3. **Framework** (`Ash.Error.Framework`) - Occurs when there's an issue with how Ash is being used
4. **Unknown** (`Ash.Error.Unknown`) - Occurs for unexpected errors that don't fit the other categories

These error classes help you catch and handle errors at an appropriate level of granularity. An error class will always be the "worst" (highest in the above list) error class from above. Each error class can contain multiple underlying errors, accessible via the `errors` field on the exception.

## Using Validations

Validations ensure that data meets your business requirements before it gets processed by an action. Unlike changes, validations cannot modify the changeset - they can only validate it or add errors.

Validations work on both changesets and queries. Built-in validations that support queries include:
- `action_is`, `argument_does_not_equal`, `argument_equals`, `argument_in`
- `compare`, `confirm`, `match`, `negate`, `one_of`, `present`, `string_length`
- Custom validations that implement the `supports/1` callback

Common validation patterns:

```elixir
# Built-in validations with custom messages
validate compare(:age, greater_than_or_equal_to: 18) do
  message "You must be at least 18 years old"
end
validate match(:email, "@")
validate one_of(:status, [:active, :inactive, :pending])

# Conditional validations with where clauses
validate present(:phone_number) do
  where present(:contact_method) and eq(:contact_method, "phone")
end

# only_when_valid? - skip validation if prior validations failed
validate expensive_validation() do
  only_when_valid? true
end

# Action-specific vs global validations
actions do
  create :sign_up do
    validate present([:email, :password])  # Only for this action
  end
  
  read :search do
    argument :email, :string
    validate match(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)  # Validates query arguments
  end
end

validations do
  validate present([:title, :body]), on: [:create, :update]  # Multiple actions
end
```

- Create **custom validation modules** for complex validation logic:
  ```elixir
  defmodule MyApp.Validations.UniqueUsername do
    use Ash.Resource.Validation

    @impl true
    def init(opts), do: {:ok, opts}

    @impl true
    def validate(changeset, _opts, _context) do
      # Validation logic here
      # Return :ok or {:error, message}
    end
  end

  # Usage in resource:
  validate {MyApp.Validations.UniqueUsername, []}
  ```

- Make validations **atomic** when possible to ensure they work correctly with direct database operations by implementing the `atomic/3` callback in custom validation modules.

  ```elixir
  defmodule MyApp.Validations.IsEven do
    # transform and validate opts

    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      if is_atom(opts[:attribute]) do
        {:ok, opts}
      else
        {:error, "attribute must be an atom!"}
      end
    end

    @impl true
    # This is optional, but useful to have in addition to validation
    # so you get early feedback for validations that can otherwise
    # only run in the datalayer
    def validate(changeset, opts, _context) do
      value = Ash.Changeset.get_attribute(changeset, opts[:attribute])

      if is_nil(value) || (is_number(value) && rem(value, 2) == 0) do
        :ok
      else
        {:error, field: opts[:attribute], message: "must be an even number"}
      end
    end

    @impl true
    def atomic(changeset, opts, context) do
      {:atomic,
        # the list of attributes that are involved in the validation
        [opts[:attribute]],
        # the condition that should cause the error
        # here we refer to the new value or the current value
        expr(rem(^atomic_ref(opts[:attribute]), 2) != 0),
        # the error expression
        expr(
          error(^InvalidAttribute, %{
            field: ^opts[:attribute],
            # the value that caused the error
            value: ^atomic_ref(opts[:attribute]),
            # the message to display
            message: ^(context.message || "%{field} must be an even number"),
            vars: %{field: ^opts[:attribute]}
          })
        )
      }
    end
  end
  ```

- **Avoid redundant validations** - Don't add validations that duplicate attribute constraints:
  ```elixir
  # WRONG - redundant validation
  attribute :name, :string do
    allow_nil? false
    constraints min_length: 1
  end

  validate present(:name) do  # Redundant! allow_nil? false already handles this
    message "Name is required"
  end

  validate attribute_does_not_equal(:name, "") do  # Redundant! min_length: 1 already handles this
    message "Name cannot be empty"
  end

  # CORRECT - let attribute constraints handle basic validation
  attribute :name, :string do
    allow_nil? false
    constraints min_length: 1
  end
  ```

## Using Preparations

Preparations modify queries before they're executed. They are used to add filters, sorts, or other query modifications based on the query context.

Common preparation patterns:

```elixir
# Built-in preparations
prepare build(sort: [created_at: :desc])
prepare build(filter: [active: true])

# Conditional preparations with where clauses
prepare build(filter: [visible: true]) do
  where argument_equals(:include_hidden, false)
end

# only_when_valid? - skip preparation if prior validations failed
prepare expensive_preparation() do
  only_when_valid? true
end

# Action-specific vs global preparations
actions do
  read :recent do
    prepare build(sort: [created_at: :desc], limit: 10)
  end
end

preparations do
  prepare build(filter: [deleted: false]), on: [:read, :update]
end
```

## Using Changes

Changes allow you to modify the changeset before it gets processed by an action. Unlike validations, changes can manipulate attribute values, add attributes, or perform other data transformations.

Common change patterns:

```elixir
# Built-in changes with conditions
change set_attribute(:status, "pending")
change relate_actor(:creator) do
  where present(:actor)
end
change atomic_update(:counter, expr(^counter + 1))

# Action-specific vs global changes
actions do
  create :sign_up do
    change set_attribute(:joined_at, expr(now()))  # Only for this action
  end
end

changes do
  change set_attribute(:updated_at, expr(now())), on: :update  # Multiple actions
  change manage_relationship(:items, type: :append), on: [:create, :update]
end
```

- Create **custom change modules** for reusable transformation logic:
  ```elixir
  defmodule MyApp.Changes.SlugifyTitle do
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      title = Ash.Changeset.get_attribute(changeset, :title)

      if title do
        slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
        Ash.Changeset.change_attribute(changeset, :slug, slug)
      else
        changeset
      end
    end
  end

  # Usage in resource:
  change {MyApp.Changes.SlugifyTitle, []}
  ```

- Create a **change module with lifecycle hooks** to handle complex multi-step operations:

  ```elixir
  defmodule MyApp.Changes.ProcessOrder do
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      changeset
      |> Ash.Changeset.before_transaction(fn changeset ->
        # Runs before the transaction starts
        # Use for external API calls, logging, etc.
        MyApp.ExternalService.reserve_inventory(changeset, scope: context)
        changeset
      end)
      |> Ash.Changeset.before_action(fn changeset ->
        # Runs inside the transaction before the main action
        # Use for related database changes in the same transaction
        Ash.Changeset.change_attribute(changeset, :processed_at, DateTime.utc_now())
      end)
      |> Ash.Changeset.after_action(fn changeset, result ->
        # Runs inside the transaction after the main action, only on success
        # Use for related database changes that depend on the result
        MyApp.Inventory.update_stock_levels(result, scope: context)
        {changeset, result}
      end)
      |> Ash.Changeset.after_transaction(fn changeset,
        {:ok, result} ->
          # Runs after the transaction completes (success or failure)
          # Use for notifications, external systems, etc.
          MyApp.Mailer.send_order_confirmation(result, scope: context)
          {changeset, result}

        {:error, error} ->
          # Runs after the transaction completes (success or failure)
          # Use for notifications, external systems, etc.
          MyApp.Mailer.send_order_issue_notice(result, scope: context)
          {:error, error}
      end)
    end
  end

  # Usage in resource:
  change {MyApp.Changes.ProcessOrder, []}
  ```

## Atomic Changes

Atomic changes execute directly in the database as part of the update query, without requiring the record to be loaded first. This provides better performance and correct behavior under concurrent updates.

**Why atomic matters:**
- Avoids race conditions (e.g., incrementing a counter)
- Better performance (no round-trip to load the record)
- Required for bulk operations to work efficiently

**Built-in atomic changes:**
```elixir
# Increment a counter atomically
change atomic_update(:view_count, expr(view_count + 1))

# Set a value using an expression
change set_attribute(:updated_at, expr(now()))
```

**Making custom changes atomic:**
Implement the `atomic/3` callback to support atomic execution:

```elixir
defmodule MyApp.Changes.IncrementVersion do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # Fallback for non-atomic execution
    current = Ash.Changeset.get_attribute(changeset, :version) || 0
    Ash.Changeset.change_attribute(changeset, :version, current + 1)
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    # Atomic implementation - runs in the database
    {:atomic, %{version: expr(coalesce(version, 0) + 1)}}
  end
end
```

## Using `require_atomic? false`

By default, update and destroy actions require all changes and validations to support atomic execution. If they don't, the action will raise an error.

**IMPORTANT:** When you see `require_atomic? false` on an action, carefully consider whether it is truly necessary. This option should be used sparingly.

**When `require_atomic? false` is needed:**
- The action has `before_action` or `around_action` hooks that need to read or modify the record
- A change reads the current record state (e.g., `Ash.Changeset.get_data/2`) and cannot be rewritten atomically
- Complex validations that cannot be expressed as database expressions

**When `require_atomic? false` is NOT needed:**
- Simple attribute transformations (these can usually be made atomic)
- Setting timestamps or default values (use `expr(now())` instead)
- Incrementing counters (use `atomic_update/2`)
- After-action hooks (these don't prevent atomic execution)
- After-transaction hooks (these don't prevent atomic execution)

```elixir
actions do
  update :update do
    # AVOID unless truly necessary
    require_atomic? false
  end

  update :increment_views do
    # GOOD - fully atomic, no need to disable
    change atomic_update(:view_count, expr(view_count + 1))
  end
end
```

If you find yourself adding `require_atomic? false`, first check if your changes and validations can be rewritten with `atomic/3` callbacks. Only disable atomic requirements when the action genuinely needs to read or manipulate the record in hooks.

## Custom Modules vs. Anonymous Functions

Prefer to put code in its own module and refer to that in changes, preparations, validations etc.

For example, prefer this:

```elixir
defmodule MyApp.MyDomain.MyResource.Changes.SlugifyName do
  use Ash.Resource.Change

  def change(changeset, _, _) do
    Ash.Changeset.before_action(changeset, fn changeset, _ ->
      slug = MyApp.Slug.get()
      Ash.Changeset.force_change_attribute(changeset, :slug, slug)
    end)
  end
end

change MyApp.MyDomain.MyResource.Changes.SlugifyName
```

## Action Types

- **Read**: For retrieving records
- **Create**: For creating records
- **Update**: For changing records
- **Destroy**: For removing records
- **Generic**: For custom operations that don't fit the other types



<!-- ash:actions-end -->
<!-- ash:aggregates-start -->
## ash:aggregates usage
# Aggregates

Aggregates allow you to retrieve summary information over groups of related data, like counts, sums, or averages. Define aggregates in the `aggregates` block of a resource.

Aggregates can work over relationships or directly over unrelated resources:

```elixir
aggregates do
  # Related aggregates - use relationship path
  count :published_post_count, :posts do
    filter expr(published == true)
  end

  sum :total_sales, :orders, :amount

  exists :is_admin, :roles do
    filter expr(name == "admin")
  end

  # Unrelated aggregates - use resource module directly
  count :matching_profiles_count, Profile do
    filter expr(name == parent(name))
  end
  
  sum :total_report_score, Report, :score do
    filter expr(author_name == parent(name))
  end
  
  exists :has_reports, Report do
    filter expr(author_name == parent(name))
  end
end
```

For unrelated aggregates, use `parent/1` to reference fields from the source resource.

## Aggregate Types

- **count**: Counts related items meeting criteria
- **sum**: Sums a field across related items
- **exists**: Returns boolean indicating if matching related items exist (also supports unrelated resources)
- **first**: Gets the first related value matching criteria
- **list**: Lists the related values for a specific field
- **max**: Gets the maximum value of a field
- **min**: Gets the minimum value of a field
- **avg**: Gets the average value of a field

## Using Aggregates

```elixir
# Using code interface options (preferred)
users = MyDomain.list_users!(
  load: [:published_post_count, :total_sales],
  query: [
    filter: [published_post_count: [greater_than: 5]],
    sort: [published_post_count: :desc]
  ]
)

# Manual query building (for complex cases)
User |> Ash.Query.filter(published_post_count > 5) |> Ash.read!()

# Loading on existing records
Ash.load!(users, :published_post_count)
```

### Join Filters

For complex aggregates involving multiple relationships, use join filters:

```elixir
aggregates do
  sum :redeemed_deal_amount, [:redeems, :deal], :amount do
    # Filter on the aggregate as a whole
    filter expr(redeems.redeemed == true)

    # Apply filters to specific relationship steps
    join_filter :redeems, expr(redeemed == true)
    join_filter [:redeems, :deal], expr(active == parent(require_active))
  end
end
```

## Inline Aggregates

Use aggregates inline within expressions:

```elixir
# Related inline aggregates
calculate :grade_percentage, :decimal, expr(
  count(answers, query: [filter: expr(correct == true)]) * 100 /
  count(answers)
)

# Unrelated inline aggregates
calculate :profile_count, :integer, expr(
  count(Profile, filter: expr(name == parent(name)))
)

calculate :stats, :map, expr(%{
  profiles: count(Profile, filter: expr(active == true)),
  reports: count(Report, filter: expr(author_name == parent(name))),
  has_active_profile: exists(Profile, active == true and name == parent(name))
})
```


<!-- ash:aggregates-end -->
<!-- ash:authorization-start -->
## ash:authorization usage
# Authorization

- When performing administrative actions, you can bypass authorization with `authorize?: false`
- To run actions as a particular user, look that user up and pass it as the `actor` option
- Always set the actor on the query/changeset/input, not when calling the action
- Use policies to define authorization rules

```elixir
# Good
Post
|> Ash.Query.for_read(:read, %{}, actor: current_user)
|> Ash.read!()

# BAD, DO NOT DO THIS
Post
|> Ash.Query.for_read(:read, %{})
|> Ash.read!(actor: current_user)
```

## Policies

To use policies, add the `Ash.Policy.Authorizer` to your resource:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    authorizers: [Ash.Policy.Authorizer]

  # Rest of resource definition...
end
```

## Policy Basics

Policies determine what actions on a resource are permitted for a given actor. Define policies in the `policies` block:

```elixir
policies do
  # A simple policy that applies to all read actions
  policy action_type(:read) do
    # Authorize if record is public
    authorize_if expr(public == true)

    # Authorize if actor is the owner
    authorize_if relates_to_actor_via(:owner)
  end

  # A policy for create actions
  policy action_type(:create) do
    # Only allow active users to create records
    forbid_unless actor_attribute_equals(:active, true)

    # Ensure the record being created relates to the actor
    authorize_if relating_to_actor(:owner)
  end
end
```

## Policy Evaluation Flow

Policies evaluate from top to bottom with the following logic:

1. All policies that apply to an action must pass for the action to be allowed
2. Within each policy, checks evaluate from top to bottom
3. The first check that produces a decision determines the policy result
4. If no check produces a decision, the policy defaults to forbidden

## IMPORTANT: Policy Check Logic

**the first check that yields a result determines the policy outcome**

```elixir
# WRONG - This is OR logic, not AND logic!
policy action_type(:update) do
  authorize_if actor_attribute_equals(:admin?, true)    # If this passes, policy passes
  authorize_if relates_to_actor_via(:owner)           # Only checked if first fails
end
```

To require BOTH conditions in that example, you would use `forbid_unless` for the first condition:

```elixir
# CORRECT - This requires BOTH conditions
policy action_type(:update) do
  forbid_unless actor_attribute_equals(:admin?, true)  # Must be admin
  authorize_if relates_to_actor_via(:owner)           # AND must be owner
end
```

Alternative patterns for AND logic:
- Use multiple separate policies (each must pass independently)
- Use a single complex expression with `expr(condition1 and condition2)`
- Use `forbid_unless` for required conditions, then `authorize_if` for the final check

## Bypass Policies

Use bypass policies to allow certain actors to bypass other policy restrictions. This should be used almost exclusively for admin bypasses.

```elixir
policies do
  # Bypass policy for admins - if this passes, other policies don't need to pass
  bypass actor_attribute_equals(:admin, true) do
    authorize_if always()
  end

  # Regular policies follow...
  policy action_type(:read) do
    # ...
  end
end
```

## Field Policies

Field policies control access to specific fields (attributes, calculations, aggregates):

```elixir
field_policies do
  # Only supervisors can see the salary field
  field_policy :salary do
    authorize_if actor_attribute_equals(:role, :supervisor)
  end

  # Allow access to all other fields
  field_policy :* do
    authorize_if always()
  end
end
```

## Policy Checks

There are two main types of checks used in policies:

1. **Simple checks** - Return true/false answers (e.g., "is the actor an admin?")
2. **Filter checks** - Return filters to apply to data (e.g., "only show records owned by the actor")

You can use built-in checks or create custom ones:

```elixir
# Built-in checks
authorize_if actor_attribute_equals(:role, :admin)
authorize_if relates_to_actor_via(:owner)
authorize_if expr(public == true)

# Custom check module
authorize_if MyApp.Checks.ActorHasPermission
```

### Custom Policy Checks

Create custom checks by implementing `Ash.Policy.SimpleCheck` or `Ash.Policy.FilterCheck`:

```elixir
# Simple check - returns true/false
defmodule MyApp.Checks.ActorHasRole do
  use Ash.Policy.SimpleCheck

  def match?(%{role: actor_role}, _context, opts) do
    actor_role == (opts[:role] || :admin)
  end
  def match?(_, _, _), do: false
end

# Filter check - returns query filter
defmodule MyApp.Checks.VisibleToUserLevel do
  use Ash.Policy.FilterCheck

  def filter(actor, _authorizer, _opts) do
    expr(visibility_level <= ^actor.user_level)
  end
end

# Usage
policy action_type(:read) do
  authorize_if {MyApp.Checks.ActorHasRole, role: :manager}
  authorize_if MyApp.Checks.VisibleToUserLevel
end
```


<!-- ash:authorization-end -->
<!-- ash:calculations-start -->
## ash:calculations usage
# Calculations

Calculations allow you to define derived values based on a resource's attributes or related data. Define calculations in the `calculations` block of a resource:

```elixir
calculations do
  # Simple expression calculation
  calculate :full_name, :string, expr(first_name <> " " <> last_name)

  # Expression with conditions
  calculate :status_label, :string, expr(
    cond do
      status == :active -> "Active"
      status == :pending -> "Pending Review"
      true -> "Inactive"
    end
  )

  # Using module calculations for more complex logic
  calculate :risk_score, :integer, {MyApp.Calculations.RiskScore, min: 0, max: 100}
end
```

## Expression Calculations

Expression calculations use Ash expressions and can be pushed down to the data layer when possible:

```elixir
calculations do
  # Simple string concatenation
  calculate :full_name, :string, expr(first_name <> " " <> last_name)

  # Math operations
  calculate :total_with_tax, :decimal, expr(amount * (1 + tax_rate))

  # Date manipulation
  calculate :days_since_created, :integer, expr(
    date_diff(^now(), inserted_at, :day)
  )
end
```

## Expressions

In order to use expressions outside of resources, changes, preparations etc. you will need to use `Ash.Expr`.

It provides both `expr/1` and template helpers like `actor/1` and `arg/1`.

For example:

```elixir
import Ash.Expr

Author
|> Ash.Query.aggregate(:count_of_my_favorited_posts, :count, [:posts], query: [
  filter: expr(favorited_by(user_id: ^actor(:id)))
])
```

See the expressions guide for more information on what is available in expresisons and
how to use them.

## Module Calculations

For complex calculations, create a module that implements `Ash.Resource.Calculation`:

```elixir
defmodule MyApp.Calculations.FullName do
  use Ash.Resource.Calculation

  # Validate and transform options
  @impl true
  def init(opts) do
    {:ok, Map.put_new(opts, :separator, " ")}
  end

  # Specify what data needs to be loaded
  @impl true
  def load(_query, _opts, _context) do
    [:first_name, :last_name]
  end

  # Implement the calculation logic
  @impl true
  def calculate(records, opts, _context) do
    Enum.map(records, fn record ->
      [record.first_name, record.last_name]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(opts.separator)
    end)
  end
end

# Usage in a resource
calculations do
  calculate :full_name, :string, {MyApp.Calculations.FullName, separator: ", "}
end
```

## Calculations with Arguments

You can define calculations that accept arguments:

```elixir
calculations do
  calculate :full_name, :string, expr(first_name <> ^arg(:separator) <> last_name) do
    argument :separator, :string do
      allow_nil? false
      default " "
      constraints [allow_empty?: true, trim?: false]
    end
  end
end
```

## Using Calculations

```elixir
# Using code interface options (preferred)
users = MyDomain.list_users!(load: [full_name: [separator: ", "]])

# Filtering and sorting
users = MyDomain.list_users!(
  query: [
    filter: [full_name: [separator: " ", value: "John Doe"]],
    sort: [full_name: {[separator: " "], :asc}]
  ]
)

# Manual query building (for complex cases)
User |> Ash.Query.load(full_name: [separator: ", "]) |> Ash.read!()

# Loading on existing records
Ash.load!(users, :full_name)
```

### Code Interface for Calculations

Define calculation functions on your domain for standalone use:

```elixir
# In your domain
resource User do
  define_calculation :full_name, args: [:first_name, :last_name, {:optional, :separator}]
end

# Then call it directly
MyDomain.full_name("John", "Doe", ", ")  # Returns "John, Doe"
```


<!-- ash:calculations-end -->
<!-- ash:code_interfaces-start -->
## ash:code_interfaces usage
# Code Interfaces

Domains and Resources can define code interfaces. Prefer writing code interfaces instead of regular elixir functions.

Use code interfaces on domains to define the contract for calling into Ash resources. See the [Code interface guide for more](https://hexdocs.pm/ash/code-interfaces.html).

Define code interfaces on the domain, like this:

```elixir
resource ResourceName do
  define :fun_name, action: :action_name
end
```

For more complex interfaces with custom transformations:

```elixir
define :custom_action do
  action :action_name
  args [:arg1, :arg2]

  custom_input :arg1, MyType do
    transform do
      to :target_field
      using &MyModule.transform_function/1
    end
  end
end
```

Prefer using the primary read action for "get" style code interfaces, and using `get_by` when the field you are looking up by is the primary key or has an `identity` on the resource.

```elixir
resource ResourceName do
  define :get_thing, action: :read, get_by: [:id]
end
```

**Avoid direct Ash calls in web modules** - Don't use `Ash.get!/2` and `Ash.load!/2` directly in LiveViews/Controllers, similar to avoiding `Repo.get/2` outside context modules:

You can also pass additional inputs in to code interfaces before the options:

```elixir
resource ResourceName do
  define :create, action: :action_name, args: [:field1]
end
```

```elixir
Domain.create!(field1_value, %{field2: field2_value}, actor: current_user)
```

You should generally prefer using this map of extra inputs over defining optional arguments.

```elixir
# BAD - in LiveView/Controller
group = MyApp.Resource |> Ash.get!(id) |> Ash.load!(rel: [:nested])

# GOOD - use code interface with get_by
resource DashboardGroup do
  define :get_dashboard_group_by_id, action: :read, get_by: [:id]
end

# Then call:
MyApp.Domain.get_dashboard_group_by_id!(id, load: [rel: [:nested]])
```

**Code interface options** - Prefer passing options directly to code interface functions rather than building queries manually:

```elixir
# PREFERRED - Use the query option for filter, sort, limit, etc.
# the query option is passed to `Ash.Query.build/2`
posts = MyApp.Blog.list_posts!(
  query: [
    filter: [status: :published],
    sort: [published_at: :desc],
    limit: 10
  ],
  load: [author: :profile, comments: [:author]]
)

# All query-related options go in the query parameter
users = MyApp.Accounts.list_users!(
  query: [filter: [active: true], sort: [created_at: :desc]],
  load: [:profile]
)

# AVOID - Verbose manual query building
query = MyApp.Post |> Ash.Query.filter(...) |> Ash.Query.load(...)
posts = Ash.read!(query)
```

Supported options: `load:`, `query:` (which accepts `filter:`, `sort:`, `limit:`, `offset:`, etc.), `page:`, `stream?:`

**Using Scopes in LiveViews** - When using `Ash.Scope`, the scope will typically be assigned to `scope` in LiveViews and used like so:

```elixir
# In your LiveView
MyApp.Blog.create_post!("new post", scope: socket.assigns.scope)
```

Inside action hooks and callbacks, use the provided `context` parameter as your scope instead:

```elixir
|> Ash.Changeset.before_transaction(fn changeset, context ->
  MyApp.ExternalService.reserve_inventory(changeset, scope: context)
  changeset
end)
```

## Authorization Functions

For each action defined in a code interface, Ash automatically generates corresponding authorization check functions:

- `can_action_name?(actor, params \\ %{}, opts \\ [])` - Returns `true`/`false` for authorization checks
- `can_action_name(actor, params \\ %{}, opts \\ [])` - Returns `{:ok, true/false}` or `{:error, reason}`

Example usage:
```elixir
# Check if user can create a post
if MyApp.Blog.can_create_post?(current_user) do
  # Show create button
end

# Check if user can update a specific post
if MyApp.Blog.can_update_post?(current_user, post) do
  # Show edit button
end

# Check if user can destroy a specific comment
if MyApp.Blog.can_destroy_comment?(current_user, comment) do
  # Show delete button
end
```

These functions are particularly useful for conditional rendering of UI elements based on user permissions.


<!-- ash:code_interfaces-end -->
<!-- ash:code_structure-start -->
## ash:code_structure usage
# Code Structure & Organization

- Organize code around domains and resources
- Each resource should be focused and well-named
- Create domain-specific actions rather than generic CRUD operations
- Put business logic inside actions rather than in external modules
- Use resources to model your domain entities

<!-- ash:code_structure-end -->
<!-- ash:data_layers-start -->
## ash:data_layers usage
# Data Layers

Data layers determine how resources are stored and retrieved. Examples of data layers:

- **Postgres**: For storing resources in PostgreSQL (via `AshPostgres`)
- **ETS**: For in-memory storage (`Ash.DataLayer.Ets`)
- **Mnesia**: For distributed storage (`Ash.DataLayer.Mnesia`)
- **Embedded**: For resources embedded in other resources (`data_layer: :embedded`) (typically JSON under the hood)
- **Ash.DataLayer.Simple**: For resources that aren't persisted at all. Leave off the data layer, as this is the default.

Specify a data layer when defining a resource:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "posts"
    repo MyApp.Repo
  end

  # ... attributes, relationships, etc.
end
```

For embedded resources:

```elixir
defmodule MyApp.Address do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :street, :string
    attribute :city, :string
    attribute :state, :string
    attribute :zip, :string
  end
end
```

Each data layer has its own configuration options and capabilities. Refer to the rules & documentation of the specific data layer package for more details.


<!-- ash:data_layers-end -->
<!-- ash:exist_expressions-start -->
## ash:exist_expressions usage
# Exists Expressions

Use `exists/2` to check for the existence of records, either through relationships or unrelated resources:

### Related Exists

```elixir
# Check if user has any admin roles
Ash.Query.filter(User, exists(roles, name == "admin"))

# Check if post has comments with high scores
Ash.Query.filter(Post, exists(comments, score > 50))
```

### Unrelated Exists

```elixir
# Check if any profile exists with the same name
Ash.Query.filter(User, exists(Profile, name == parent(name)))

# Check if user has any reports
Ash.Query.filter(User, exists(Report, author_name == parent(name)))

# Complex existence checks
Ash.Query.filter(User, 
  active == true and 
  exists(Profile, active == true and name == parent(name))
)
```

Unrelated exists expressions automatically apply authorization using the target resource's primary read action. Use `parent/1` to reference fields from the source resource.

<!-- ash:exist_expressions-end -->
<!-- ash:generating_code-start -->
## ash:generating_code usage
# Generating Code

Use `mix ash.gen.*` tasks as a basis for code generation when possible. Check the task docs with `mix help <task>`.
Be sure to use `--yes` to bypass confirmation prompts. Use `--yes --dry-run` to preview the changes.


<!-- ash:generating_code-end -->
<!-- ash:migrations-start -->
## ash:migrations usage
# Migrations and Schema Changes

After creating or modifying Ash code, run `mix ash.codegen <short_name_describing_changes>` to ensure any required additional changes are made (like migrations are generated). The name of the migration should be lower_snake_case. In a longer running dev session it's usually better to use `mix ash.codegen --dev` as you go and at the end run the final codegen with a sensible name describing all the changes made in the session.


<!-- ash:migrations-end -->
<!-- ash:query_filter-start -->
## ash:query_filter usage
# Ash.Query.filter is a macro

**Important**: You must `require Ash.Query` if you want to use `Ash.Query.filter/2`, as it is a macro.

If you see errors like the following:

```
Ash.Query.filter(MyResource, id == ^id)
error: misplaced operator ^id

The pin operator ^ is supported only inside matches or inside custom macros...
```

```
iex(3)> Ash.Query.filter(MyResource, something == true)
error: undefined variable "something"
└─ iex:3
```

You are very likely missing a `require Ash.Query`

## Common Query Operations

- **Filter**: `Ash.Query.filter(query, field == value)`
- **Sort**: `Ash.Query.sort(query, field: :asc)`
- **Load relationships**: `Ash.Query.load(query, [:author, :comments])`
- **Limit**: `Ash.Query.limit(query, 10)`
- **Offset**: `Ash.Query.offset(query, 20)`


<!-- ash:query_filter-end -->
<!-- ash:querying_data-start -->
## ash:querying_data usage
# Querying Data

Use `Ash.Query` to build queries for reading data from your resources. The query module provides a declarative way to filter, sort, and load data.


<!-- ash:querying_data-end -->
<!-- ash:relationships-start -->
## ash:relationships usage
# Relationships

Relationships describe connections between resources and are a core component of Ash. Define relationships in the `relationships` block of a resource.

## Best Practices for Relationships

- Be descriptive with relationship names (e.g., use `:authored_posts` instead of just `:posts`)
- Configure foreign key constraints in your data layer if they have them (see `references` in AshPostgres)
- Always choose the appropriate relationship type based on your domain model

### Relationship Types

- For Polymorphic relationships, you can model them using `Ash.Type.Union`; see the “Polymorphic Relationships” guide for more information.

```elixir
relationships do
  # belongs_to - adds foreign key to source resource
  belongs_to :owner, MyApp.User do
    allow_nil? false
    attribute_type :integer  # defaults to :uuid
  end

  # has_one - foreign key on destination resource
  has_one :profile, MyApp.Profile

  # has_many - foreign key on destination resource, returns list
  has_many :posts, MyApp.Post do
    filter expr(published == true)
    sort published_at: :desc
  end

  # many_to_many - requires join resource
  many_to_many :tags, MyApp.Tag do
    through MyApp.PostTag
    source_attribute_on_join_resource :post_id
    destination_attribute_on_join_resource :tag_id
  end
end
```

The join resource must be defined separately:

```elixir
defmodule MyApp.PostTag do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    # Add additional attributes if you need metadata on the relationship
    attribute :added_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
    end
  end

  relationships do
    belongs_to :post, MyApp.Post, primary_key?: true, allow_nil?: false
    belongs_to :tag, MyApp.Tag, primary_key?: true, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
```

## Loading Relationships

```elixir
# Using code interface options (preferred)
post = MyDomain.get_post!(id, load: [:author, comments: [:author]])

# Complex loading with filters
posts = MyDomain.list_posts!(
  query: [load: [comments: [filter: [is_approved: true], limit: 5]]]
)

# Manual query building (for complex cases)
MyApp.Post
|> Ash.Query.load(comments: MyApp.Comment |> Ash.Query.filter(is_approved == true))
|> Ash.read!()

# Loading on existing records
Ash.load!(post, :author)
```

Prefer to use the `strict?` option when loading to only load necessary fields on related data.

```elixir
MyApp.Post
|> Ash.Query.load([comments: [:title]], strict?: true)
```

## Managing Relationships

There are two primary ways to manage relationships in Ash:

### 1. Using `change manage_relationship/2-3` in Actions
Use this when input comes from action arguments:

```elixir
actions do
  update :update do
    # Define argument for the related data
    argument :comments, {:array, :map} do
      allow_nil? false
    end

    argument :new_tags, {:array, :map}

    # Link argument to relationship management
    change manage_relationship(:comments, type: :append)

    # For different argument and relationship names
    change manage_relationship(:new_tags, :tags, type: :append)
  end
end
```

### 2. Using `Ash.Changeset.manage_relationship/3-4` in Custom Changes
Use this when building values programmatically:

```elixir
defmodule MyApp.Changes.AssignTeamMembers do
  use Ash.Resource.Change

  def change(changeset, _opts, context) do
    members = determine_team_members(changeset, context.actor)

    Ash.Changeset.manage_relationship(
      changeset,
      :members,
      members,
      type: :append_and_remove
    )
  end
end
```

### Quick Reference - Management Types
- `:append` - Add new related records, ignore existing
- `:append_and_remove` - Add new related records, remove missing
- `:remove` - Remove specified related records
- `:direct_control` - Full CRUD control (create/update/destroy)
- `:create` - Only create new records

### Quick Reference - Common Options
- `on_lookup: :relate` - Look up and relate existing records
- `on_no_match: :create` - Create if no match found
- `on_match: :update` - Update existing matches
- `on_missing: :destroy` - Delete records not in input
- `value_is_key: :name` - Use field as key for simple values

For comprehensive documentation, see the [Managing Relationships](https://hexdocs.pm/ash/relationships.html#managing-relationships) section.

### Examples

Creating a post with tags:
```elixir
MyDomain.create_post!(%{
  title: "New Post",
  body: "Content here...",
  tags: [%{name: "elixir"}, %{name: "ash"}]  # Creates new tags
})

# Updating a post to replace its tags
MyDomain.update_post!(post, %{
  tags: [tag1.id, tag2.id]  # Replaces tags with existing ones by ID
})
```


<!-- ash:relationships-end -->
<!-- ash:testing-start -->
## ash:testing usage
# Testing

When testing resources:
- Test your domain actions through the code interface
- Use test utilities in `Ash.Test`
- Test authorization policies work as expected using `Ash.can?`
- Use `authorize?: false` in tests where authorization is not the focus
- Write generators using `Ash.Generator`
- Prefer to use raising versions of functions whenever possible, as opposed to pattern matching

## Preventing Deadlocks in Concurrent Tests

When running tests concurrently, using fixed values for identity attributes can cause deadlock errors. Multiple tests attempting to create records with the same unique values will conflict.

### Use Globally Unique Values

Always use globally unique values for identity attributes in tests:

```elixir
# BAD - Can cause deadlocks in concurrent tests
%{email: "test@example.com", username: "testuser"}

# GOOD - Use globally unique values
%{
  email: "test-#{System.unique_integer([:positive])}@example.com",
  username: "user_#{System.unique_integer([:positive])}",
  slug: "post-#{System.unique_integer([:positive])}"
}
```

### Creating Reusable Test Generators

For better organization, create a generator module:

```elixir
defmodule MyApp.TestGenerators do
  use Ash.Generator

  def user(opts \\ []) do
    changeset_generator(
      User,
      :create,
      defaults: [
        email: "user-#{System.unique_integer([:positive])}@example.com",
        username: "user_#{System.unique_integer([:positive])}"
      ],
      overrides: opts
    )
  end
end

# In your tests
test "concurrent user creation" do
  users = MyApp.TestGenerators.generate_many(user(), 10)
  # Each user has unique identity attributes
end
```

This applies to ANY field used in identity constraints, not just primary keys. Using globally unique values prevents frustrating intermittent test failures in CI environments.

<!-- ash:testing-end -->
<!-- ash_authentication-start -->
## ash_authentication usage
_Authentication extension for the Ash Framework._

# AshAuthentication Usage Rules

## Core Concepts
- **Strategies**: password, OAuth2, magic_link, api_key authentication methods
- **Tokens**: JWT for stateless authentication
- **UserIdentity**: links users to OAuth2 providers
- **Add-ons**: confirmation, logout-everywhere functionality
- **Actions**: auto-generated by strategies (register, sign_in, etc.), can be overridden on the resource

## Key Principles
- Always use secrets management - never hardcode credentials
- Enable tokens for magic_link, confirmation, OAuth2
- UserIdentity resource optional for OAuth2 (required for multiple providers per user)
- API keys require strict policy controls and expiration management
- Use prefixes for API keys to enable secret scanning compliance
- Check existing strategies: `AshAuthentication.Info.strategies/1`

## Strategy Selection

**Password** - Email/password authentication
- Requires: `:email`, `:hashed_password` attributes, unique identity

**Magic Link** - Passwordless email authentication
- Requires: `:email` attribute, sender implementation, tokens enabled

**API Key** - Token-based authentication for APIs
- Requires: API key resource, relationship to user, sign-in action

**OAuth2** - Social/enterprise login (GitHub, Google, Auth0, Apple, OIDC, Slack)
- Requires: custom actions, secrets
- Optional: UserIdentity resource (for multiple providers per user)

## Password Strategy

```elixir
authentication do
  strategies do
    password :password do
      identity_field :email
      hashed_password_field :hashed_password
      resettable do
        sender MyApp.PasswordResetSender
      end
    end
  end
end

# Required attributes:
attributes do
  attribute :email, :ci_string, allow_nil?: false, public?: true
  attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
end

identities do
  identity :unique_email, [:email]
end
```

## Magic Link Strategy

```elixir
authentication do
  strategies do
    magic_link do
      identity_field :email
      sender MyApp.MagicLinkSender
    end
  end
end

# Sender implementation required:
defmodule MyApp.MagicLinkSender do
  use AshAuthentication.Sender

  def send(user_or_email, token, _opts) do
    MyApp.Emails.deliver_magic_link(user_or_email, token)
  end
end
```

## API Key Strategy

```elixir
# 1. Create API key resource
defmodule MyApp.Accounts.ApiKey do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :expires_at]
      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey, prefix: :myapp, hash: :api_key_hash}
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :api_key_hash, :binary, allow_nil?: false, sensitive?: true
    attribute :expires_at, :utc_datetime_usec, allow_nil?: false
  end

  relationships do
    belongs_to :user, MyApp.Accounts.User, allow_nil?: false
  end

  calculations do
    calculate :valid, :boolean, expr(expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end
end

# 2. Add strategy to user resource
authentication do
  strategies do
    api_key do
      api_key_relationship :valid_api_keys
      api_key_hash_attribute :api_key_hash
    end
  end
end

# 3. Add relationship to user
relationships do
  has_many :valid_api_keys, MyApp.Accounts.ApiKey do
    filter expr(valid)
  end
end

# 4. Add sign-in action to user
actions do
  read :sign_in_with_api_key do
    argument :api_key, :string, allow_nil?: false
    prepare AshAuthentication.Strategy.ApiKey.SignInPreparation
  end
end
```

**Security considerations:**
- API keys are hashed for storage security
- Use policies to restrict API key access to specific actions
- Check `user.__metadata__[:using_api_key?]` to detect API key authentication
- Access the API key via `user.__metadata__[:api_key]` for permission checks

## OAuth2 Strategies

**Supported providers:** github, google, auth0, apple, oidc, slack

**Required for all OAuth2:**
- Custom `register_with_[provider]` action
- Secrets management
- Tokens enabled

**Optional for all OAuth2:**
- UserIdentity resource (for multiple providers per user)

### OAuth2 Configuration Pattern
```elixir
# Strategy configuration
authentication do
  strategies do
    github do  # or google, auth0, apple, oidc, slack
      client_id MyApp.Secrets
      client_secret MyApp.Secrets
      redirect_uri MyApp.Secrets
      # auth0 also needs: base_url
      # apple also needs: team_id, private_key_id, private_key_path
      # oidc also needs: openid_configuration_uri
      identity_resource MyApp.Accounts.UserIdentity
    end
  end
end

# Required action (replace 'github' with provider name)
actions do
  create :register_with_github do
    argument :user_info, :map, allow_nil?: false
    argument :oauth_tokens, :map, allow_nil?: false
    upsert? true
    upsert_identity :unique_email

    change AshAuthentication.GenerateTokenChange
    
    # If UserIdentity resource is being used
    change AshAuthentication.Strategy.OAuth2.IdentityChange

    change fn changeset, _ctx ->
      user_info = Ash.Changeset.get_argument(changeset, :user_info)
      Ash.Changeset.change_attributes(changeset, Map.take(user_info, ["email"]))
    end
  end
end
```

## Add-ons

### Confirmation
```elixir
authentication do
  tokens do
    enabled? true
    token_resource MyApp.Accounts.Token
  end

  add_ons do
    confirmation :confirm do
      monitor_fields [:email]
      sender MyApp.ConfirmationSender
    end
  end
end
```

### Log Out Everywhere
```elixir
authentication do
  tokens do
    store_all_tokens? true
  end

  add_ons do
    log_out_everywhere do
      apply_on_password_change? true
    end
  end
end
```

## Working with Authentication

### Strategy Protocol
```elixir
# Get and use strategies
strategy = AshAuthentication.Info.strategy!(MyApp.User, :password)
{:ok, user} = AshAuthentication.Strategy.action(strategy, :sign_in, params)

# List strategies
strategies = AshAuthentication.Info.strategies(MyApp.User)
```

### Token Operations
```elixir
# User/subject conversion
subject = AshAuthentication.user_to_subject(user)
{:ok, user} = AshAuthentication.subject_to_user(subject, MyApp.User)

# Token management
AshAuthentication.TokenResource.revoke(MyApp.Token, token)
```

### Policies
```elixir
policies do
  bypass AshAuthentication.Checks.AshAuthenticationInteraction do
    authorize_if always()
  end
end
```

## Common Implementation Patterns

### Pattern: Multiple Authentication Methods
When users need multiple ways to authenticate:

```elixir
authentication do
  tokens do
    enabled? true
    token_resource MyApp.Accounts.Token
  end

  strategies do
    password :password do
      identity_field :email
      hashed_password_field :hashed_password
    end

    github do
      client_id MyApp.Secrets
      client_secret MyApp.Secrets
      redirect_uri MyApp.Secrets
      identity_resource MyApp.Accounts.UserIdentity
    end

    magic_link do
      identity_field :email
      sender MyApp.MagicLinkSender
    end
  end
end
```

### Pattern: OAuth2 with User Registration
When new users can register via OAuth2:

```elixir
actions do
  create :register_with_github do
    argument :user_info, :map, allow_nil?: false
    argument :oauth_tokens, :map, allow_nil?: false
    upsert? true
    upsert_identity :email

    change AshAuthentication.GenerateTokenChange
    change fn changeset, _ctx ->
      user_info = Ash.Changeset.get_argument(changeset, :user_info)

      changeset
      |> Ash.Changeset.change_attribute(:email, user_info["email"])
      |> Ash.Changeset.change_attribute(:name, user_info["name"])
    end
  end
end
```

### Pattern: Custom Token Configuration
When you need specific token behavior:

```elixir
authentication do
  tokens do
    enabled? true
    token_resource MyApp.Accounts.Token
    signing_secret MyApp.Secrets
    token_lifetime {24, :hours}
    store_all_tokens? true  # For logout-everywhere functionality
    require_token_presence_for_authentication? false
  end
end
```

## Customizing Authentication Actions

When customizing generated authentication actions (register, sign_in, etc.):

**Key Security Rules:**
- Always mark credentials with `sensitive?: true` (passwords, API keys, tokens)
- Use `public?: false` for internal fields and highly sensitive PII
- Use `public?: true` for identity fields and UI display data
- Include required authentication changes (`GenerateTokenChange`, `HashPasswordChange`, etc.)

**Argument Handling:**
- All arguments must be used in `accept` or `change set_attribute()`
- Use `allow_nil?: false` for required arguments
- OAuth2 data must be extracted in changes, not accepted directly

**Example Custom Registration:**
```elixir
create :register_with_password do
  argument :password, :string, allow_nil?: false, sensitive?: true
  argument :first_name, :string, allow_nil?: false
  
  accept [:email, :first_name]
  
  change AshAuthentication.GenerateTokenChange
  change AshAuthentication.Strategy.Password.HashPasswordChange
end
```

For more guidance, see the "Customizing Authentication Actions" section in the getting started guide.
<!-- ash_authentication-end -->
<!-- ash_events-start -->
## ash_events usage
_The extension for tracking changes to your resources via a centralized event log, with replay functionality._

# Rules for working with AshEvents

## Understanding AshEvents

AshEvents is an extension for the Ash Framework that provides event capabilities for Ash resources. It allows you to track and persist events when actions (create, update, destroy) are performed on your resources, providing a complete audit trail and enabling powerful replay functionality. **Read the documentation thoroughly before implementing** - AshEvents has specific patterns and conventions that must be followed correctly.

## Core Concepts

- **Event Logging**: Automatically records create, update, and destroy actions as events
- **Event Replay**: Rebuilds resource state by replaying events chronologically
- **Version Management**: Supports tracking and routing different versions of events
- **Actor Attribution**: Stores who performed each action (users, system processes, etc)
- **Changed Attributes Tracking**: Automatically captures attributes modified by business logic that weren't in the original input
- **Metadata Tracking**: Attaches arbitrary metadata to events for audit purposes

## Project Structure & Setup

### 1. Event Log Resource (Required)

**Always start by creating a centralized event log resource** using the `AshEvents.EventLog` extension:

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  event_log do
    # Required: Module that implements clear_records! callback
    clear_records_for_replay MyApp.Events.ClearAllRecords

    # Recommended for new projects
    primary_key_type Ash.Type.UUIDv7

    # Store actor information
    persist_actor_primary_key :user_id, MyApp.Accounts.User
    persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
  end
end
```

### 2. Clear Records Implementation (Required for Replay)

**Always implement the clear records module** if you plan to use event replay:

```elixir
defmodule MyApp.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(opts) do
    # Clear all relevant records for all resources with event tracking
    # This runs before replay to ensure clean state
    :ok
  end
end
```

### 3. Enable Event Tracking on Resources

**Add the `AshEvents.Events` extension to resources you want to track**:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    # Required: Reference your event log resource
    event_log MyApp.Events.Event

    # Optional: Specify action versions for schema evolution
    current_action_versions create: 2, update: 3, destroy: 2

    # Optional: Configure replay strategies for changed attributes
    replay_non_input_attribute_changes [
      create: :force_change,    # Default strategy
      update: :as_arguments,    # Alternative strategy
      legacy_action: :force_change
    ]

    # Optional: Allow storing specific sensitive attributes (by default, sensitive attributes are excluded)
    store_sensitive_attributes [:hashed_password, :api_key]

    # Optional: Ignore specific actions (usually legacy versions)
    ignore_actions [:old_create_v1]
  end

  # Rest of your resource definition...
end
```

## Event Tracking Patterns

### Automatic Event Creation

**Events are created automatically** when you perform actions on resources with events enabled:

```elixir
# This automatically creates an event in your event log
user = User
|> Ash.Changeset.for_create(:create, %{name: "John", email: "john@example.com"})
|> Ash.create!(actor: current_user)
```

### Adding Metadata to Events

**Use `ash_events_metadata` in the changeset context** to add custom metadata:

```elixir
User
|> Ash.Changeset.for_create(:create, %{name: "Jane"}, [
  actor: current_user,
  context: %{ash_events_metadata: %{
    source: "api",
    request_id: request_id,
    ip_address: client_ip
  }}
])
|> Ash.create!()
```

### Actor Attribution

**Always set the actor** when performing actions to ensure proper attribution:

```elixir
# GOOD - Actor is properly attributed
User
|> Ash.Query.for_read(:read, %{}, actor: current_user)
|> Ash.read!()

# BAD - No actor attribution
User
|> Ash.Query.for_read(:read, %{})
|> Ash.read!()
```

### Changed Attributes Tracking

**AshEvents automatically captures attributes that are modified during action execution** but weren't part of the original input. This is essential for complete state reconstruction during replay when business logic, defaults, or extensions modify data beyond the explicit input parameters.

#### Understanding Changed Attributes

**What gets captured:**
- Default values applied to attributes
- Auto-generated values (UUIDs, slugs, computed fields)
- Attributes modified by Ash changes or extensions
- Business rule transformations of input data
- Calculated or derived attributes

**What doesn't get captured:**
- Attributes that were explicitly provided in the original input
- Attributes that remain unchanged from their current value

#### Event Data Structure

When an event is created, data is separated into two categories:

```elixir
# Example event structure
%Event{
  # Original input parameters only
  data: %{
    "name" => "John Doe",
    "email" => "john@example.com"
  },

  # Auto-generated or modified attributes
  changed_attributes: %{
    "id" => "550e8400-e29b-41d4-a716-446655440000",
    "status" => "active",           # default value
    "slug" => "john-doe",           # auto-generated from name
    "created_at" => "2023-05-01T12:00:00Z"
  }
}
```

#### Replay Strategies

Configure how changed attributes are applied during replay using `replay_non_input_attribute_changes`:

```elixir
events do
  event_log MyApp.Events.Event

  replay_non_input_attribute_changes [
    create: :force_change,      # Uses Ash.Changeset.force_change_attributes
    update: :force_change,
    legacy_create_v1: :as_arguments # Merges into action input
  ]
end
```

**`:force_change` Strategy (Default):**
- Uses `Ash.Changeset.force_change_attributes()` to apply changed attributes directly
- Bypasses validations and business logic for the changed attributes
- Best for attributes that shouldn't be recomputed during replay (IDs, timestamps)
- Ensures exact state reproduction

**`:as_arguments` Strategy:**
- Merges changed attributes into the action input parameters
- Allows business logic and validations to run normally
- Best for legacy events or when you want recomputation during replay
- May produce slightly different results if business logic has changed

#### Practical Example

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
    replay_non_input_attribute_changes [
      create: :force_change,
      update: :force_change
    ]
  end

  attributes do
    uuid_primary_key :id, writable?: true
    attribute :name, :string, public?: true, allow_nil?: false
    attribute :email, :string, public?: true, allow_nil?: false
    attribute :status, :string, default: "active", public?: true
    attribute :slug, :string, public?: true
    create_timestamp :created_at
  end

  changes do
    # Auto-generate slug from name
    change fn changeset, _context ->
      case Map.get(changeset.attributes, :name) do
        nil -> changeset
        name ->
          slug = String.downcase(name)
                |> String.replace(~r/[^a-z0-9]/, "-")
          Ash.Changeset.change_attribute(changeset, :slug, slug)
      end
    end, on: [:create, :update]
  end
end

# Creating a user
user = User
|> Ash.Changeset.for_create(:create, %{
  name: "Jane Smith",
  email: "jane@example.com"
})
|> Ash.create!(actor: current_user)

# The resulting event will have:
# data: %{"name" => "Jane Smith", "email" => "jane@example.com"}
# changed_attributes: %{
#   "id" => "generated-uuid",
#   "status" => "active",
#   "slug" => "jane-smith",
#   "created_at" => timestamp
# }
```

#### Best Practices

**Use `:force_change` strategy when:**
- Attributes should maintain their exact original values (IDs, timestamps)
- You want guaranteed state reproduction during replay
- Business logic for generating attributes shouldn't be re-executed

**Use `:as_arguments` strategy when:**
- You have legacy events that need recomputation
- Business logic has evolved and you want updated calculations
- You prefer letting validations run during replay

**Common Patterns:**
```elixir
# Mixed strategies for different actions
replay_non_input_attribute_changes [
  create: :force_change,          # Preserve exact creation state
  update: :as_arguments,          # Allow recomputation on updates
  legacy_import: :as_arguments    # Recompute legacy data
]
```

#### Working with Forms

**AshPhoenix.Form automatically works** with changed attributes tracking:

```elixir
# Form with string keys
form_params = %{
  "name" => "John Doe",
  "email" => "john@example.com"
  # status and slug will be auto-generated
}

form = User
|> AshPhoenix.Form.for_create(:create, actor: current_user)
|> AshPhoenix.Form.validate(form_params)

{:ok, user} = AshPhoenix.Form.submit(form, params: form_params)

# Event will properly separate form input from generated attributes
# regardless of whether form used string or atom keys
```

#### Troubleshooting

**Common Issues:**

1. **Missing attributes after replay:**
   - Ensure `clear_records_for_replay` includes all relevant tables
   - Check that replay strategy is appropriate for your use case

2. **Different values after replay:**
   - Using `:as_arguments` may cause recomputation with updated logic
   - Switch to `:force_change` for exact reproduction

3. **Attributes appearing in both data and changed_attributes:**
   - This shouldn't happen - file a bug if you see this
   - Attributes are only in `changed_attributes` if not in original input


## Event Replay

### Basic Replay

**Use the generated replay action** on your event log resource:

```elixir
# Replay all events to rebuild state
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{})
|> Ash.run_action!()

# Replay up to a specific event ID
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{last_event_id: 1000})
|> Ash.run_action!()

# Replay up to a specific point in time
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{point_in_time: ~U[2023-05-01 00:00:00Z]})
|> Ash.run_action!()
```

### Version Management and Replay Overrides

**Use replay overrides** to handle schema evolution and version changes:

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  # Handle different event versions
  replay_overrides do
    replay_override MyApp.Accounts.User, :create do
      versions [1]
      route_to MyApp.Accounts.User, :old_create_v1
    end

    replay_override MyApp.Accounts.User, :update do
      versions [1, 2]
      route_to MyApp.Accounts.User, :update_legacy
    end
  end
end
```

**Create legacy action implementations** for handling old event versions:

```elixir
defmodule MyApp.Accounts.User do
  # Current actions
  actions do
    create :create do
      # Current implementation
    end
  end

  # Legacy actions for replay (mark as ignored)
  actions do
    create :old_create_v1 do
      # Implementation for version 1 events
    end
  end

  events do
    event_log MyApp.Events.Event
    ignore_actions [:old_create_v1]  # Don't create new events for legacy actions
  end
end
```

## Side Effects and Lifecycle Hooks

### Important: Lifecycle Hooks During Replay

**Understand that ALL lifecycle hooks are skipped during replay**:
- `before_action`, `after_action`, `around_action`
- `before_transaction`, `after_transaction`, `around_transaction`

This prevents side effects like emails, notifications, or API calls from being triggered during replay.

### Best Practice: Encapsulate Side Effects

**Create separate Ash actions for side effects** instead of putting them directly in lifecycle hooks:

```elixir
# GOOD - Side effects as separate tracked actions
defmodule MyApp.Accounts.User do
  actions do
    create :create do
      accept [:name, :email]

      # Use after_action to trigger other tracked actions
      change after_action(fn changeset, user, context ->
        # This creates a separate event that won't be re-executed during replay
        MyApp.Notifications.EmailNotification
        |> Ash.Changeset.for_create(:send_welcome_email, %{
          user_id: user.id,
          email: user.email
        })
        |> Ash.create!(actor: context.actor)

        {:ok, user}
      end)
    end
  end
end

# The email notification resource also tracks events
defmodule MyApp.Notifications.EmailNotification do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
  end

  actions do
    create :send_welcome_email do
      # Email sending logic here
    end
  end
end
```

### External Service Integration

**Wrap external API calls in tracked actions**:

```elixir
defmodule MyApp.External.APICall do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
  end

  actions do
    create :make_api_call do
      accept [:endpoint, :payload, :method]

      change after_action(fn changeset, record, context ->
        # Make the actual API call
        response = HTTPClient.request(record.endpoint, record.payload)

        # Update with response (creates another event)
        record
        |> Ash.Changeset.for_update(:update_response, %{
          response: response,
          status: "completed"
        })
        |> Ash.update!(actor: context.actor)

        {:ok, record}
      end)
    end

    update :update_response do
      accept [:response, :status]
    end
  end
end
```

## Advanced Configuration

### Multiple Actor Types

**Configure multiple actor types** when you have different types of entities performing actions:

```elixir
event_log do
  persist_actor_primary_key :user_id, MyApp.Accounts.User
  persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
  persist_actor_primary_key :api_client_id, MyApp.APIClient
end
```

**Note**: All actor primary key fields must have `allow_nil?: true` (this is the default).

### Encryption Support

**Use encryption for sensitive event data**:

```elixir
event_log do
  cloak_vault MyApp.Vault  # Encrypts both data and metadata
end
```

### Advisory Locks

**Configure advisory locks** for high-concurrency scenarios:

```elixir
event_log do
  advisory_lock_key_default 31337
  advisory_lock_key_generator MyApp.CustomAdvisoryLockKeyGenerator
end
```

### Public Field Configuration

**Control visibility of event log fields** for GraphQL, JSON API, or other public interfaces:

```elixir
event_log do
  # Make all AshEvents fields public
  public_fields :all
  
  # Or specify only certain fields
  public_fields [:id, :resource, :action, :occurred_at]
  
  # Default: all fields are private
  public_fields []
end
```

**Valid field names** include all canonical AshEvents fields:
- `:id`, `:record_id`, `:version`, `:occurred_at`
- `:resource`, `:action`, `:action_type`
- `:metadata`, `:data`, `:changed_attributes`
- `:encrypted_metadata`, `:encrypted_data`, `:encrypted_changed_attributes` (when using encryption)
- Actor attribution fields from `persist_actor_primary_key` (e.g., `:user_id`, `:system_actor`)

**Important**: Only AshEvents-managed fields can be made public. User-added custom fields are not affected by this configuration.

### Timestamp Tracking

**Configure timestamp tracking** if your resources have custom timestamp fields:

```elixir
events do
  event_log MyApp.Events.Event
  create_timestamp :inserted_at
  update_timestamp :updated_at
end
```

## Testing Best Practices

### Testing with Events

**Use `authorize?: false` in tests** where authorization is not the focus:

```elixir
test "creates user with event" do
  user = User
  |> Ash.Changeset.for_create(:create, %{name: "Test"})
  |> Ash.create!(authorize?: false)

  # Verify event was created
  events = MyApp.Events.Event |> Ash.read!(authorize?: false)
  assert length(events) == 1
end
```

**Test event replay functionality**:

```elixir
test "can replay events to rebuild state" do
  # Create some data
  user = create_user()
  update_user(user)

  # Clear state
  clear_all_records()

  # Replay events
  MyApp.Events.Event
  |> Ash.ActionInput.for_action(:replay, %{})
  |> Ash.run_action!(authorize?: false)

  # Verify state is restored
  restored_user = get_user(user.id)
  assert restored_user.name == user.name
end
```

## Error Handling and Debugging

### Event Creation Failures

**Events are created in the same transaction** as the original action, so event creation failures will rollback the entire operation.

### Replay Failures

**Handle replay failures gracefully**:

```elixir
case MyApp.Events.Event |> Ash.ActionInput.for_action(:replay, %{}) |> Ash.run_action() do
  {:ok, _} ->
    Logger.info("Event replay completed successfully")
  {:error, error} ->
    Logger.error("Event replay failed: #{inspect(error)}")
    # Handle cleanup or notification
end
```

## Audit Logging Only

**You can use AshEvents solely for audit logging** without implementing replay:

1. **Skip implementing `clear_records_for_replay`** - only needed for replay
2. **Skip defining `current_action_versions`** - only needed for schema evolution during replay
3. **Skip implementing replay overrides** - only needed for replay functionality

This gives you automatic audit trails without the complexity of event sourcing.

## Common Patterns

### Event Metadata for Audit Trails

```elixir
# Always include relevant context in metadata
context: %{ash_events_metadata: %{
  source: "web_ui",           # Where the action originated
  user_agent: request.headers["user-agent"],
  ip_address: get_client_ip(request),
  request_id: get_request_id(),
  correlation_id: get_correlation_id()
}}
```

### Conditional Event Creation

```elixir
events do
  event_log MyApp.Events.Event
  # Only track specific actions
  only_actions [:create, :update, :destroy]
  # Or ignore specific actions
  ignore_actions [:internal_update, :system_sync]
end
```

### Sensitive Attribute Configuration

**By default, sensitive attributes are excluded from events** for security. The `store_sensitive_attributes` DSL option provides fine-grained control over which sensitive attributes to include in events.

**IMPORTANT**: `store_sensitive_attributes` is **only valid for resources using non-encrypted event logs**. Resources using cloaked (encrypted) event logs automatically store all sensitive attributes and **must not** configure this option.

#### For Non-Encrypted Event Logs

Use `store_sensitive_attributes` to explicitly allow specific sensitive attributes:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event  # Non-encrypted event log
    # Explicitly allow storing specific sensitive attributes
    store_sensitive_attributes [:hashed_password, :api_key_hash]
  end

  attributes do
    attribute :email, :string, public?: true
    attribute :hashed_password, :string, sensitive?: true, public?: true
    attribute :api_key_hash, :binary, sensitive?: true, public?: true
    attribute :secret_token, :string, sensitive?: true, public?: true  # NOT stored in events
  end
end

# Result: Only hashed_password and api_key_hash will be included in events
# secret_token will be excluded for security
```

#### For Encrypted (Cloaked) Event Logs

**Do NOT use `store_sensitive_attributes` with cloaked event logs** - it will result in a compilation error:

```elixir
# ❌ INVALID - This will cause a compilation error
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.CloakedEvent  # This is a cloaked event log
    store_sensitive_attributes [:password]  # ❌ ERROR: Invalid with cloaked logs
  end
end
```

**Correct usage with cloaked event logs:**

```elixir
# ✅ CORRECT - No store_sensitive_attributes needed
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.CloakedEvent  # Cloaked event log with encryption
    # No store_sensitive_attributes - all sensitive data automatically stored
  end

  attributes do
    attribute :email, :string, public?: true
    attribute :hashed_password, :string, sensitive?: true, public?: true
    attribute :api_key_hash, :binary, sensitive?: true, public?: true
    attribute :secret_token, :string, sensitive?: true, public?: true
  end
end

# Result: ALL sensitive attributes (hashed_password, api_key_hash, secret_token)
# are automatically stored because they're encrypted by the cloaked event log
```

**Cloaked event log configuration:**

```elixir
defmodule MyApp.Events.CloakedEvent do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  event_log do
    cloak_vault MyApp.Vault  # Enables encryption for all event data
  end
end
```

#### Summary

| Event Log Type | Sensitive Attribute Behavior | `store_sensitive_attributes` Usage |
|----------------|------------------------------|-------------------------------------|
| **Non-encrypted** | Excluded by default | ✅ **Required** to store specific sensitive attributes |
| **Cloaked (encrypted)** | All automatically stored | ❌ **Invalid** - will cause compilation error |

**⚠️ Security considerations:**
- **Non-encrypted event logs:** Only store sensitive attributes that are absolutely necessary for replay or audit purposes
- **Encrypted event logs:** All sensitive attributes are safely stored because they're encrypted
- Use encryption (`cloak_vault`) when you need comprehensive sensitive data storage in events
- Never store sensitive attributes in non-encrypted logs unless specifically required for functionality

### Resource-Specific Event Handling

```elixir
# Different resources can have different event configurations
defmodule MyApp.Accounts.User do
  events do
    event_log MyApp.Events.Event
    current_action_versions create: 2, update: 1
  end
end

defmodule MyApp.Blog.Post do
  events do
    event_log MyApp.Events.Event
    current_action_versions create: 1, update: 3, destroy: 1
  end
end
```

### Changed Attributes Configuration Patterns

```elixir
# Pattern 1: Default configuration (recommended for most cases)
defmodule MyApp.Accounts.User do
  events do
    event_log MyApp.Events.Event
    # Uses :force_change for all actions by default
    # No explicit configuration needed
  end
end

# Pattern 2: Mixed strategies based on action type
defmodule MyApp.Blog.Post do
  events do
    event_log MyApp.Events.Event
    replay_non_input_attribute_changes [
      create: :force_change,      # Preserve exact creation state
      update: :as_arguments,      # Allow recomputation on updates
      publish: :force_change,     # Preserve published state exactly
      archive: :force_change      # Preserve archive timestamps
    ]
  end
end

# Pattern 3: Legacy compatibility with gradual migration
defmodule MyApp.Legacy.Document do
  events do
    event_log MyApp.Events.Event
    replay_non_input_attribute_changes [
      create: :force_change,        # New events use force_change
      legacy_create_v1: :as_arguments,  # Legacy events recompute
      legacy_create_v2: :as_arguments   # Multiple legacy versions
    ]
  end
end
```

### Common Auto-Generated Attribute Patterns

```elixir
# Pattern 1: Status + Slug generation
defmodule MyApp.Content.Article do
  attributes do
    attribute :title, :string, public?: true
    attribute :content, :string, public?: true
    attribute :status, :string, default: "draft", public?: true
    attribute :slug, :string, public?: true
    attribute :word_count, :integer, public?: true
  end

  changes do
    # Auto-generate slug and word count
    change fn changeset, _context ->
      changeset
      |> auto_generate_slug()
      |> calculate_word_count()
    end, on: [:create, :update]
  end

  events do
    event_log MyApp.Events.Event
    # status, slug, word_count will be tracked as changed_attributes
  end
end
```

## Performance Considerations

- **Event insertion uses advisory locks** to prevent race conditions
- **Replay operations are sequential** and can be time-consuming for large datasets
- **Use `primary_key_type Ash.Type.UUIDv7`** for better performance with time-ordered events
- **Metadata should be kept reasonable in size** as it's stored as JSON

<!-- ash_events-end -->
<!-- ash_json_api-start -->
## ash_json_api usage
_The JSON:API extension for the Ash Framework._

# Rules for working with AshJsonApi

## Understanding AshJsonApi

AshJsonApi is a package for integrating Ash Framework with the JSON:API specification. It provides tools for generating JSON:API compliant endpoints from your Ash resources. AshJsonApi allows you to expose your Ash resources through a standardized RESTful API, supporting all JSON:API features like filtering, sorting, pagination, includes, and relationships.

## Domain Configuration

AshJsonApi works by extending your Ash domains and resources with JSON:API capabilities. First, add the AshJsonApi extension to your domain.

### Setting Up Your Domain

```elixir
defmodule MyApp.Blog do
  use Ash.Domain,
    extensions: [
      AshJsonApi.Domain
    ]

  json_api do
    # Define JSON:API-specific settings for this domain
    authorize? true

    # You can define routes at the domain level
    routes do
      base_route "/posts", MyApp.Blog.Post do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end
    end
  end

  resources do
    resource MyApp.Blog.Post
    resource MyApp.Blog.Comment
  end
end
```

## Resource Configuration

Each resource that you want to expose via JSON:API needs to include the AshJsonApi.Resource extension.

### Setting Up Resources

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    extensions: [AshJsonApi.Resource]

  attributes do
    uuid_primary_key :id
    attribute :title, :string
    attribute :body, :string
    attribute :published, :boolean
  end

  relationships do
    belongs_to :author, MyApp.Accounts.User
    has_many :comments, MyApp.Blog.Comment
  end

  json_api do
    # The JSON:API type name (required)
    type "post"
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :list_published do
      filter expr(published == true)
    end

    update :publish do
      accept []
      change set_attribute(:published, true)
    end
  end
end
```

## Route Types

AshJsonApi supports various route types according to the JSON:API spec:

- `get` - Fetch a single resource by ID
- `index` - List resources, with support for filtering, sorting, and pagination
- `post` - Create a new resource
- `patch` - Update an existing resource
- `delete` - Destroy an existing resource
- `related` - Fetch related resources (e.g., `/posts/123/comments`)
- `relationship` - Fetch relationship data (e.g., `/posts/123/relationships/comments`)
- `post_to_relationship` - Add to a relationship
- `patch_relationship` - Replace a relationship
- `delete_from_relationship` - Remove from a relationship

## JSON:API Pagination, Filtering, and Sorting

AshJsonApi supports standard JSON:API query parameters:

- Filter: `?filter[attribute]=value`
- Sort: `?sort=attribute,-other_attribute` (descending with `-`)
- Pagination: `?page[number]=2&page[size]=10`
- Includes: `?include=author,comments.author`

<!-- ash_json_api-end -->
<!-- ash_oban-start -->
## ash_oban usage
_The extension for integrating Ash resources with Oban._

# Rules for working with AshOban

## Understanding AshOban

AshOban is a package that integrates the Ash Framework with Oban, a robust job processing system for Elixir. It enables you to define triggers that can execute background jobs based on specific conditions in your Ash resources, as well as schedule periodic actions. AshOban is particularly useful for handling asynchronous tasks, background processing, and scheduled operations in your Ash application.

<!-- ash_oban-end -->
<!-- ash_oban:best_practices-start -->
## ash_oban:best_practices usage
# Best Practices

1. **Always define module names** - Use explicit `worker_module_name` and `scheduler_module_name` to prevent issues when refactoring.

2. **Use meaningful trigger names** - Choose clear, descriptive names for your triggers that reflect their purpose.

3. **Handle errors gracefully** - Use the `on_error` option to define how to handle records that fail processing repeatedly.

4. **Use appropriate queues** - Organize your jobs into different queues based on priority and resource requirements.

5. **Optimize read actions** - Ensure that read actions used in triggers support keyset pagination for efficient processing.

6. **Design for idempotency** - Jobs should be designed to be safely retried without causing data inconsistencies.

<!-- ash_oban:best_practices-end -->
<!-- ash_oban:debugging_and_error_handling-start -->
## ash_oban:debugging_and_error_handling usage
# Debugging and Error Handling

AshOban provides options for debugging and handling errors:

```elixir
trigger :process do
  action :process
  # Enable detailed debug logging for this trigger
  debug? true

  # Configure error handling
  log_errors? true
  log_final_error? true

  # Define an action to call after the last attempt has failed
  on_error :mark_failed
end
```

You can also enable global debug logging:

```elixir
config :ash_oban, :debug_all_triggers?, true
```

## Snoozing and Cancelling Jobs

From within any action run by a trigger or scheduled action, you can snooze or cancel the Oban job using special error types. These work from both the main action and the `on_error` action.

**Snooze** — re-schedule the job after a delay without consuming a retry attempt:

```elixir
# Via add_error (idiomatic for change functions):
Ash.Changeset.add_error(changeset, AshOban.Errors.SnoozeJob.exception(snooze_for: 60))

# Via raise:
raise AshOban.Errors.SnoozeJob, snooze_for: 60
```

**Cancel** — stop all retries and mark the job as cancelled:

```elixir
# Via add_error:
Ash.Changeset.add_error(changeset, AshOban.Errors.CancelJob.exception(reason: :permanently_invalid))

# Via raise:
raise AshOban.Errors.CancelJob, reason: :permanently_invalid
```
<!-- ash_oban:debugging_and_error_handling-end -->
<!-- ash_oban:defining_triggers-start -->
## ash_oban:defining_triggers usage
# Defining Triggers

Triggers are the primary way to define background jobs in AshOban. They can be configured to run when certain conditions are met on your resources. They work
by running a scheduler job on the given cron job.

## Basic Trigger

```elixir
oban do
  triggers do
    trigger :process do
      action :process
      scheduler_cron "*/5 * * * *"
      where expr(processed != true)
      worker_read_action :read
      worker_module_name MyApp.Workers.Process
      scheduler_module_name MyApp.Schedulers.Process
    end
  end
end
```

## Trigger Configuration Options

- `action` - The action to be triggered (required)
- `where` - The filter expression to determine if something should be triggered
- `worker_read_action` - The read action to use when fetching individual records
- `read_action` - The read action to use when querying records (must support keyset pagination)
- `worker_module_name` - The module name for the generated worker (important for job stability)
- `scheduler_module_name` - The module name for the generated scheduler
- `max_attempts` - How many times to attempt the job (default: 1)
- `queue` - The queue to place the worker job in (defaults to trigger name)
- `trigger_once?` - Ensures that jobs that complete quickly aren't rescheduled (default: false)
<!-- ash_oban:defining_triggers-end -->
<!-- ash_oban:multi_tenancy_support-start -->
## ash_oban:multi_tenancy_support usage
# Multi-tenancy Support

AshOban supports multi-tenancy in your Ash application:

```elixir
oban do
  # Global tenant configuration
  list_tenants [1, 2, 3]  # or a function that returns tenants

  triggers do
    trigger :process do
      # Override tenants for a specific trigger
      list_tenants fn -> [2] end
      action :process
    end
  end
end
```
<!-- ash_oban:multi_tenancy_support-end -->
<!-- ash_oban:scheduled_actions-start -->
## ash_oban:scheduled_actions usage
# Scheduled Actions

Scheduled actions allow you to run periodic tasks according to a cron schedule:

```elixir
oban do
  scheduled_actions do
    schedule :daily_report, "0 8 * * *" do
      action :generate_report
      worker_module_name MyApp.Workers.DailyReport
    end
  end
end
```

## Scheduled Action Configuration Options

- `cron` - The schedule in crontab notation
- `action` - The generic or create action to call when the schedule is triggered
- `action_input` - Inputs to supply to the action when it is called
- `worker_module_name` - The module name for the generated worker
- `queue` - The queue to place the job in
- `max_attempts` - How many times to attempt the job (default: 1)
<!-- ash_oban:scheduled_actions-end -->
<!-- ash_oban:setting_up_ash_oban-start -->
## ash_oban:setting_up_ash_oban usage
# Setting Up AshOban

To use AshOban with an Ash resource, add AshOban to the extensions list:

```elixir
use Ash.Resource,
  extensions: [AshOban]
```
<!-- ash_oban:setting_up_ash_oban-end -->
<!-- ash_oban:triggering_jobs_programmatically-start -->
## ash_oban:triggering_jobs_programmatically usage
# Triggering Jobs Programmatically

You can trigger jobs programmatically using `run_oban_trigger` in your actions:

```elixir
update :process_item do
  accept [:item_id]
  change set_attribute(:processing, true)
  change run_oban_trigger(:process_data)
end
```

Or directly using the AshOban API:

```elixir
# Run a trigger for a specific record
AshOban.run_trigger(record, :process_data)

# Run a trigger for multiple records
AshOban.run_triggers(records, :process_data)

# Schedule a trigger or scheduled action
AshOban.schedule(MyApp.Resource, :process_data, actor: current_user)
```
<!-- ash_oban:triggering_jobs_programmatically-end -->
<!-- ash_oban:working_with_actors-start -->
## ash_oban:working_with_actors usage
# Working with Actors

AshOban can persist the actor that triggered a job, making it available when the job runs:

## Setting up Actor Persistence

```elixir
# Define an actor persister module
defmodule MyApp.ObanActorPersister do
  @behaviour AshOban.PersistActor

  @impl true
  def store(actor) do
    # Convert actor to a format that can be stored in JSON
    Jason.encode!(actor)
  end

  @impl true
  def lookup(actor_json) do
    # Convert the stored JSON back to an actor
    case Jason.decode(actor_json) do
      {:ok, data} -> {:ok, MyApp.Accounts.get_user!(data["id"])}
      error -> error
    end
  end
end

# Configure it
config :ash_oban, :actor_persister, MyApp.ObanActorPersister
```

## Using Actor in Triggers

```elixir
# Specify actor_persister for a specific trigger
trigger :process do
  action :process
  actor_persister MyApp.ObanActorPersister
end

# Pass the actor when triggering a job
AshOban.run_trigger(record, :process, actor: current_user)
```
<!-- ash_oban:working_with_actors-end -->
<!-- ash_phoenix-start -->
## ash_phoenix usage
_Utilities for integrating Ash and Phoenix_

# Rules for working with AshPhoenix

## Understanding AshPhoenix

AshPhoenix is a package for integrating Ash Framework with Phoenix Framework. It provides tools for integrating with Phoenix forms (`AshPhoenix.Form`), Phoenix LiveViews (`AshPhoenix.LiveView`), and more. AshPhoenix makes it seamless to use Phoenix's powerful UI capabilities with Ash's data management features.

<!-- ash_phoenix-end -->
<!-- ash_phoenix:best_practices-start -->
## ash_phoenix:best_practices usage
## Best Practices

1. **Let the Resource guide the UI**: Your Ash resource configuration determines a lot about how forms and inputs will work. Well-defined resources with appropriate validations and changes make AshPhoenix more effective.

2. **Leverage code interfaces**: Define code interfaces on your domains for a clean and consistent API to call your resource actions.

3. **Update resources before editing**: When building forms for updating resources, load the resource with all required relationships using `Ash.load!/2` before creating the form.

<!-- ash_phoenix:best_practices-end -->
<!-- ash_phoenix:debugging_form_submissions-start -->
## ash_phoenix:debugging_form_submissions usage
# Debugging Form Submission

Errors on forms are only shown when they implement the `AshPhoenix.FormData.Error` protocol and have a `field` or `fields` set. 
Most Phoenix applications are set up to show errors for `<.input`s. This can some times lead to errors happening in the 
action that are not displayed because they don't implement the protocol, have field/fields, or for a field that is not shown
in the form.

To debug these situations, you can use `AshPhoenix.Form.raw_errors(form, for_path: :all)` on a failed form submission to see what
is going wrong, and potentially add custom error handling, or resolve whatever error is occurring. If the action has errors
that can go wrong that aren't tied to fields, you will need to detect those error scenarios and display that with some other UI,
like a flash message or a notice at the top/bottom of the form, etc.

If you want to see what errors the form will see (that implement the protocl and have fields) use 
`AshPhoenix.Form.errors(form, for_path: :all)`.
<!-- ash_phoenix:debugging_form_submissions-end -->
<!-- ash_phoenix:error_handling-start -->
## ash_phoenix:error_handling usage
# Error Handling

AshPhoenix provides helpful error handling mechanisms:

```elixir
# In your LiveView
def handle_event("submit", %{"form" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
    {:ok, post} ->
      # Success path
      {:noreply, success_path(socket, post)}

    {:error, form} ->
      # Show validation errors
      {:noreply, assign(socket, form: form)}
  end
end
```
<!-- ash_phoenix:error_handling-end -->
<!-- ash_phoenix:form_integration-start -->
## ash_phoenix:form_integration usage
# Form Integration

AshPhoenix provides `AshPhoenix.Form`, a powerful module for creating and handling forms backed by Ash resources.

## Creating Forms

```elixir
# For creating a new resource
form = AshPhoenix.Form.for_create(MyApp.Blog.Post, :create) |> to_form()

# For updating an existing resource
post = MyApp.Blog.get_post!(post_id)
form = AshPhoenix.Form.for_update(post, :update) |> to_form()

# Form with initial value
form = AshPhoenix.Form.for_create(MyApp.Blog.Post, :create,
  params: %{title: "Draft Title"}
) |> to_form()
```

## Code Interfaces

Using the `AshPhoenix` extension in domains gets you special functions in a resource's
code interface called `form_to_*`. Use this whenever possible.

First, add the `AshPhoenix` extension to our domains and resources, like so:

```elixir
use Ash.Domain,
  extensions: [AshPhoenix]
```

which will cause another function to be generated for each definition, beginning with `form_to_`.

For example, if you had the following,
```elixir
# in MyApp.Accounts
resources do
  resource MyApp.Accounts.User do
    define :register_with_password, args: [:email, :password]
  end
end
```

you could then make a form with:

```elixir
MyApp.Accounts.form_to_register_with_password(...opts)
```

By default, the `args` option in `define` is ignored when building forms. If you want to have positional arguments, configure that in the `forms` section which is added by the `AshPhoenix` section. For example:

```elixir
forms do
  form :register_with_password, args: [:email]
end
```

Which could then be used as:

```elixir
MyApp.Accounts.register_with_password(email, ...)
```

These positional arguments are *very important* for certain cases, because there may be values you do not want the form to be able to set. For example, when updating a user's settings, maybe the action takes a `user_id`, but the form is on a page for a specific user's id and so this should therefore not be editable in the form. Use positional arguments for this.

## Handling Form Submission

In your LiveView:

```elixir
def handle_event("validate", %{"form" => params}, socket) do
  form = AshPhoenix.Form.validate(socket.assigns.form, params)
  {:noreply, assign(socket, :form, form)}
end

def handle_event("submit", %{"form" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
    {:ok, post} ->
      socket =
        socket
        |> put_flash(:info, "Post created successfully")
        |> push_navigate(to: ~p"/posts/#{post.id}")
      {:noreply, socket}

    {:error, form} ->
      {:noreply, assign(socket, :form, form)}
  end
end
```
<!-- ash_phoenix:form_integration-end -->
<!-- ash_phoenix:nested_forms-start -->
## ash_phoenix:nested_forms usage
# Nested Forms

AshPhoenix supports forms with nested relationships, such as creating or updating related resources in a single form.

## Automatically Inferred Nested Forms

If your action has `manage_relationship`, AshPhoenix automatically infers nested forms:

```elixir
# In your resource:
create :create do
  accept [:name]
  argument :locations, {:array, :map}
  change manage_relationship(:locations, type: :create)
end

# In your template:
<.simple_form for={@form} phx-change="validate" phx-submit="submit">
  <.input field={@form[:name]} />

  <.inputs_for :let={location} field={@form[:locations]}>
    <.input field={location[:name]} />
  </.inputs_for>
</.simple_form>
```

## Adding and Removing Nested Forms

To add a nested form with a button:

```heex
<.button type="button" phx-click="add-form" phx-value-path={@form.name <> "[locations]"}>
  <.icon name="hero-plus" />
</.button>
```

In your LiveView:

```elixir
def handle_event("add-form", %{"path" => path}, socket) do
  form = AshPhoenix.Form.add_form(socket.assigns.form, path)
  {:noreply, assign(socket, :form, form)}
end
```

To remove a nested form:

```heex
<.button type="button" phx-click="remove-form" phx-value-path={location.name}>
  <.icon name="hero-x-mark" />
</.button>
```

```elixir
def handle_event("remove-form", %{"path" => path}, socket) do
  form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
  {:noreply, assign(socket, :form, form)}
end
```
<!-- ash_phoenix:nested_forms-end -->
<!-- ash_phoenix:union_forms-start -->
## ash_phoenix:union_forms usage
# Union Forms

AshPhoenix supports forms for union types, allowing different inputs based on the selected type.

```heex
<.inputs_for :let={fc} field={@form[:content]}>
  <.input
    field={fc[:_union_type]}
    phx-change="type-changed"
    type="select"
    options={[Normal: "normal", Special: "special"]}
  />

  <%= case fc.params["_union_type"] do %>
    <% "normal" -> %>
      <.input type="text" field={fc[:body]} />
    <% "special" -> %>
      <.input type="text" field={fc[:text]} />
  <% end %>
</.inputs_for>
```

In your LiveView:

```elixir
def handle_event("type-changed", %{"_target" => path} = params, socket) do
  new_type = get_in(params, path)
  path = :lists.droplast(path)

  form =
    socket.assigns.form
    |> AshPhoenix.Form.remove_form(path)
    |> AshPhoenix.Form.add_form(path, params: %{"_union_type" => new_type})

  {:noreply, assign(socket, :form, form)}
end
```
<!-- ash_phoenix:union_forms-end -->
<!-- ash_postgres-start -->
## ash_postgres usage
_The PostgreSQL data layer for Ash Framework_

# Rules for working with AshPostgres

## Understanding AshPostgres

AshPostgres is the PostgreSQL data layer for Ash Framework. It's the most fully-featured Ash data layer and should be your default choice unless you have specific requirements for another data layer. Any PostgreSQL version higher than 13 is fully supported.

Remember that using AshPostgres provides a full-featured PostgreSQL data layer for your Ash application, giving you both the structure and declarative approach of Ash along with the power and flexibility of PostgreSQL.

<!-- ash_postgres-end -->
<!-- ash_postgres:advanced_features-start -->
## ash_postgres:advanced_features usage
# Advanced Features

## Manual Relationships

For complex relationships that can't be expressed with standard relationship types:

```elixir
defmodule MyApp.Post.Relationships.HighlyRatedComments do
  use Ash.Resource.ManualRelationship
  use AshPostgres.ManualRelationship

  def load(posts, _opts, context) do
    post_ids = Enum.map(posts, & &1.id)

    {:ok,
     MyApp.Comment
     |> Ash.Query.filter(post_id in ^post_ids)
     |> Ash.Query.filter(rating > 4)
     |> MyApp.read!()
     |> Enum.group_by(& &1.post_id)}
  end

  def ash_postgres_join(query, _opts, current_binding, as_binding, :inner, destination_query) do
    {:ok,
     Ecto.Query.from(_ in query,
       join: dest in ^destination_query,
       as: ^as_binding,
       on: dest.post_id == as(^current_binding).id,
       on: dest.rating > 4
     )}
  end

  # Other required callbacks...
end

# In your resource:
relationships do
  has_many :highly_rated_comments, MyApp.Comment do
    manual MyApp.Post.Relationships.HighlyRatedComments
  end
end
```

## Using Multiple Repos (Read Replicas)

Configure different repos for reads vs mutations:

```elixir
postgres do
  repo fn resource, type ->
    case type do
      :read -> MyApp.ReadReplicaRepo
      :mutate -> MyApp.WriteRepo
    end
  end
end
```
<!-- ash_postgres:advanced_features-end -->
<!-- ash_postgres:best_practices-start -->
## ash_postgres:best_practices usage
# Best Practices

1. **Organize migrations**: Run `mix ash.codegen` after each meaningful set of resource changes with a descriptive name:
   ```bash
   mix ash.codegen --name add_user_roles
   mix ash.codegen --name implement_post_tagging
   ```

2. **Use check constraints for domain invariants**: Enforce data integrity at the database level:
   ```elixir
   check_constraints do
     check_constraint :valid_status, check: "status IN ('pending', 'active', 'completed')"
     check_constraint :positive_balance, check: "balance >= 0"
   end
   ```

3. **Use custom statements for schema-only changes**: If you need to add database objects not directly tied to resources:
   ```elixir
   custom_statements do
     statement "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\""
     statement "CREATE INDEX users_search_idx ON users USING gin(search_vector)"
   end
   ```
<!-- ash_postgres:best_practices-end -->
<!-- ash_postgres:check_constraints-start -->
## ash_postgres:check_constraints usage
# Check Constraints

Define database check constraints:

```elixir
postgres do
  check_constraints do
    check_constraint :positive_amount,
      check: "amount > 0",
      name: "positive_amount_check",
      message: "Amount must be positive"

    check_constraint :status_valid,
      check: "status IN ('pending', 'active', 'completed')"
  end
end
```
<!-- ash_postgres:check_constraints-end -->
<!-- ash_postgres:configuration-start -->
## ash_postgres:configuration usage
# Basic Configuration

To use AshPostgres, add the data layer to your resource:

```elixir
defmodule MyApp.Tweet do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    integer_primary_key :id
    attribute :text, :string
  end

  relationships do
    belongs_to :author, MyApp.User
  end

  postgres do
    table "tweets"
    repo MyApp.Repo
  end
end
```

# PostgreSQL Configuration

## Table & Schema Configuration

```elixir
postgres do
  # Required: Define the table name for this resource
  table "users"

  # Optional: Define the PostgreSQL schema
  schema "public"

  # Required: Define the Ecto repo to use
  repo MyApp.Repo

  # Optional: Control whether migrations are generated for this resource
  migrate? true
end
```

<!-- ash_postgres:configuration-end -->
<!-- ash_postgres:custom_indexes-start -->
## ash_postgres:custom_indexes usage
# Custom Indexes

Define custom indexes beyond those automatically created for identities and relationships:

```elixir
postgres do
  custom_indexes do
    index [:first_name, :last_name]

    index :email,
      unique: true,
      name: "users_email_index",
      where: "email IS NOT NULL",
      using: :gin

    index [:status, :created_at],
      concurrently: true,
      include: [:user_id]
  end
end
```
<!-- ash_postgres:custom_indexes-end -->
<!-- ash_postgres:custom_sql_statements-start -->
## ash_postgres:custom_sql_statements usage
# Custom SQL Statements

Include custom SQL in migrations:

```elixir
postgres do
  custom_statements do
    statement "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    statement """
    CREATE TRIGGER update_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();
    """

    statement "DROP INDEX IF EXISTS posts_title_index",
      on_destroy: true # Only run when resource is destroyed/dropped
  end
end
```
<!-- ash_postgres:custom_sql_statements-end -->
<!-- ash_postgres:foreign_keys-start -->
## ash_postgres:foreign_keys usage
# Foreign Key References

Use the `references` section to configure foreign key behavior:

```elixir
postgres do
  table "comments"
  repo MyApp.Repo

  references do
    # Simple reference with defaults
    reference :post

    # Fully configured reference
    reference :user,
      on_delete: :delete,      # What happens when referenced row is deleted
      on_update: :update,      # What happens when referenced row is updated
      name: "comments_to_users_fkey", # Custom constraint name
      deferrable: true,        # Make constraint deferrable
      initially_deferred: false # Defer constraint check to end of transaction
  end
end
```

## Foreign Key Actions

For `on_delete` and `on_update` options:

- `:nothing` or `:restrict` - Prevent the change to the referenced row
- `:delete` - Delete the row when the referenced row is deleted (for `on_delete` only)
- `:update` - Update the row according to changes in the referenced row (for `on_update` only)
- `:nilify` - Set all foreign key columns to NULL
- `{:nilify, columns}` - Set specific columns to NULL (Postgres 15.0+ only)

> **Warning**: These operations happen directly at the database level. No resource logic, authorization rules, validations, or notifications are triggered.
<!-- ash_postgres:foreign_keys-end -->
<!-- ash_postgres:migrations-start -->
## ash_postgres:migrations usage
# Migrations and Codegen

## Development Migration Workflow (Recommended)

For development iterations, use the dev workflow to avoid naming migrations prematurely:

1. Make resource changes
2. Run `mix ash.codegen --dev` to generate and run dev migrations
3. Review the migrations and run `mix ash.migrate` to run them
4. Continue making changes and running `mix ash.codegen --dev` as needed
5. When your feature is complete, run `mix ash.codegen add_feature_name` to generate final named migrations (this will rollback dev migrations and squash them)
3. Review the migrations and run `mix ash.migrate` to run them

## Traditional Migration Generation

For single-step changes or when you know the final feature name:

1. Run `mix ash.codegen add_feature_name` to generate migrations
2. Review the generated migrations in `priv/repo/migrations`
3. Run `mix ash.migrate` to apply the migrations

> **Tip**: The dev workflow (`--dev` flag) is preferred during development as it allows you to iterate without thinking of migration names and provides better development ergonomics.

> **Warning**: Always review migrations before applying them to ensure they are correct and safe.
<!-- ash_postgres:migrations-end -->
<!-- ash_postgres:multitenancy-start -->
## ash_postgres:multitenancy usage
# Multitenancy

AshPostgres supports schema-based multitenancy:

```elixir
defmodule MyApp.Tenant do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  # Resource definition...

  postgres do
    table "tenants"
    repo MyApp.Repo

    # Automatically create/manage tenant schemas
    manage_tenant do
      template ["tenant_", :id]
    end
  end
end
```

## Setting Up Multitenancy

1. Configure your repo to support multitenancy:

```elixir
defmodule MyApp.Repo do
  use AshPostgres.Repo, otp_app: :my_app

  # Return all tenant schemas for migrations
  def all_tenants do
    import Ecto.Query, only: [from: 2]
    all(from(t in "tenants", select: fragment("? || ?", "tenant_", t.id)))
  end
end
```

2. Mark resources that should be multi-tenant:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  multitenancy do
    strategy :context
    attribute :tenant
  end

  # Resource definition...
end
```

3. When tenant migrations are generated, they'll be in `priv/repo/tenant_migrations`

4. Run tenant migrations in addition to regular migrations:

```bash
# Run regular migrations
mix ash.migrate

# Run tenant migrations
mix ash_postgres.migrate --tenants
```
<!-- ash_postgres:multitenancy-end -->
<!-- ash_typescript-start -->
## ash_typescript usage
_Generate type-safe TypeScript clients directly from your Ash resources and actions, ensuring end-to-end type safety between your backend and frontend._

# AshTypescript Usage Rules

## Quick Reference

**Critical**: Add `AshTypescript.Rpc` extension to domain, run `mix ash_typescript.codegen`
**Authentication**: Use `buildCSRFHeaders()` for Phoenix CSRF protection
**Controller Routes**: Use `AshTypescript.TypedController` for controller-style actions with `conn` access
**Typed Channels**: Use `AshTypescript.TypedChannel` for typed PubSub event subscriptions
**Validation**: Always verify generated TypeScript compiles

## Essential Syntax Table

| Pattern | Syntax | Example |
|---------|--------|---------|
| **Domain Setup** | `use Ash.Domain, extensions: [AshTypescript.Rpc]` | Required extension |
| **RPC Action** | `rpc_action :name, :action_type` | `rpc_action :list_todos, :read` |
| **Basic Call** | `functionName({ fields: [...] })` | `listTodos({ fields: ["id", "title"] })` |
| **Field Selection** | `["field1", {"nested": ["field2"]}]` | Relationships in objects |
| **Union Fields** | `{ unionField: ["member1", {"member2": [...]}] }` | Selective union member access |
| **Calculation (no args)** | `{ calc: ["field1", ...] }` | Simple nested syntax |
| **Calculation (with args)** | `{ calc: { args: {...}, fields: [...] } }` | Args + fields object |
| **Filter Syntax** | `{ field: { eq: value } }` | Always use operator objects |
| **Sort String** | `"-field1,field2"` | Dash prefix = descending |
| **CSRF Headers** | `headers: buildCSRFHeaders()` | Phoenix CSRF protection |
| **Input Args** | `input: { argName: value }` | Action arguments |
| **Identity (PK)** | `identity: "id-123"` | Primary key lookup |
| **Identity (Named)** | `identity: { email: "a@b.com" }` | Named identity lookup |
| **Identities Config** | `identities: [:_primary_key, :email]` | Allowed lookup methods |
| **Actor-Scoped** | `identities: []` | No identity param needed |
| **Get Action** | `get?: true` or `get_by: [:email]` | Single record lookup |
| **Not Found** | `not_found_error?: false` | Return null instead of error |
| **Custom Fetch** | `customFetch: myFetchFn` | Replace native fetch |
| **Pagination** | `page: { limit: 10 }` | Offset/keyset pagination |
| **Disable Filter** | `enable_filter?: false` | Disable client filtering |
| **Disable Sort** | `enable_sort?: false` | Disable client sorting |
| **Allowed Loads** | `allowed_loads: [:user, comments: [:author]]` | Whitelist loadable fields |
| **Denied Loads** | `denied_loads: [:user]` | Blacklist loadable fields |
| **Field Mapping** | `field_names [field_1: "field1"]` | Map invalid field names |
| **Arg Mapping** | `argument_names [action: [arg_1: "arg1"]]` | Map invalid arg names |
| **Type Mapping** | `def typescript_field_names, do: [...]` | NewType/TypedStruct callback |
| **Metadata Config** | `show_metadata: [:field1]` | Control metadata exposure |
| **Metadata Mapping** | `metadata_field_names: [field_1: "field1"]` | Map metadata names |
| **Metadata (Read)** | `metadataFields: ["field1"]` | Merged into records |
| **Metadata (Mutation)** | `result.metadata.field1` | Separate metadata field |
| **Domain Namespace** | `typescript_rpc do namespace :api` | Default for all resources |
| **Resource Namespace** | `resource X do namespace :todos` | Override domain default |
| **Action Namespace** | `namespace: :custom` | Override resource default |
| **Deprecation** | `deprecated: true` or `"message"` | Mark action deprecated |
| **Related Actions** | `see: [:create_todo]` | Link in JSDoc |
| **Description** | `description: "Custom desc"` | Override JSDoc description |
| **Channel Function** | `actionNameChannel({channel, resultHandler})` | Phoenix channel RPC |
| **Validation Fn** | `validateActionName({...})` | Client-side validation |
| **Type Overrides** | `type_mapping_overrides: [{Module, "TSType"}]` | Map dependency types |
| **Typed Controller** | `use AshTypescript.TypedController` | Controller-style routes |
| **Controller Module** | `typed_controller do module_name MyWeb.Ctrl` | Generated controller module |
| **Verb Shortcut** | `get :auth do run fn ... end end` | Preferred route syntax |
| **Positional Method** | `route :login, :post do run fn ... end end` | Method as 2nd arg |
| **Default GET** | `route :home do run fn ... end end` | Method defaults to :get |
| **Route Argument** | `argument :code, :string, allow_nil?: false` | Colocated in route |
| **Route Namespace** | `namespace "auth"` | Inside typed_controller or route do block |
| **Route Description** | `description "..."` | JSDoc on route (inside do block) |
| **Route Deprecated** | `deprecated true` | Deprecation notice (inside do block) |
| **Route @see Tags** | `see [:auth, :logout]` | JSDoc `@see` cross-references |
| **Typed Controllers** | `config :ash_typescript, typed_controllers: [M]` | Module discovery |
| **Router Config** | `config :ash_typescript, router: MyWeb.Router` | Path introspection |
| **Routes Output** | `config :ash_typescript, routes_output_file: "routes.ts"` | Route file path |
| **Paths-Only Mode** | `config :ash_typescript, typed_controller_mode: :paths_only` | Skip fetch functions |
| **GET Query Params** | `argument :q, :string, allow_nil?: false` on GET route | Becomes `?q=value` |
| **Typed Channel** | `use AshTypescript.TypedChannel` | Server-push event subscriptions |
| **Channel Topic** | `typed_channel do topic "org:*"` | Wildcard or static topic |
| **Channel Resource** | `resource MyApp.Post do publish :event end` | Declare events per resource |
| **Channel Create** | `createOrgChannel(socket, suffix)` | Factory with branded type |
| **Channel Subscribe** | `onOrgChannelMessages(channel, handlers)` | Multi-event subscription |
| **Channel Unsubscribe** | `unsubscribeOrgChannel(channel, refs)` | Cleanup all refs |
| **Typed Channels** | `config :ash_typescript, typed_channels: [M]` | Module discovery |
| **Channels Output** | `config :ash_typescript, typed_channels_output_file: "..."` | Channel functions file |
| **JSON Manifest** | `config :ash_typescript, json_manifest_file: "manifest.json"` | Machine-readable action metadata |
| **Manifest Filename** | `json_manifest_filename_format: :relative` | `:relative`, `:absolute`, or `:basename` |

## Action Feature Matrix

| Action Type | Fields | Filter | Page | Sort | Input | Identity |
|-------------|--------|--------|------|------|-------|----------|
| **read** | ✓ | ✓* | ✓ | ✓* | ✓ | - |
| **read (get?/get_by)** | ✓ | - | - | - | ✓ | - |
| **create** | ✓ | - | - | - | ✓ | - |
| **update** | ✓ | - | - | - | ✓ | ✓ |
| **destroy** | - | - | - | - | ✓ | ✓ |

*Can be disabled with `enable_filter?: false` / `enable_sort?: false`

## Core Patterns

### Basic Setup

```elixir
defmodule MyApp.Domain do
  use Ash.Domain, extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource MyApp.Todo do
      rpc_action :list_todos, :read
      rpc_action :create_todo, :create
      rpc_action :update_todo, :update
    end
  end
end
```

### TypeScript Usage

```typescript
// Read with all features
const todos = await listTodos({
  fields: ["id", "title", { user: ["name"] }],
  filter: { completed: { eq: false } },
  page: { limit: 10 },
  sort: "-createdAt",
  headers: buildCSRFHeaders()
});

// Update requires identity
await updateTodo({
  identity: "todo-123",
  input: { title: "Updated" },
  fields: ["id", "title"]
});

// Phoenix channel
createTodoChannel({
  channel: myChannel,
  input: { title: "New" },
  fields: ["id"],
  resultHandler: (r) => console.log(r.data)
});
```

### Field Name Mapping (Invalid Names)

```elixir
# Resource attributes/calculations
typescript do
  field_names [field_1: "field1", is_active?: "isActive"]
  argument_names [search: [filter_1: "filter1"]]
end

# Custom types (NewType, TypedStruct, map constraints)
def typescript_field_names, do: [field_1: "field1"]

# Metadata fields
rpc_action :read, :read_with_meta,
  metadata_field_names: [meta_1: "meta1"]
```

## Typed Controller (Route Helpers)

### When to Use

| Use Case | Extension |
|----------|-----------|
| Data operations with field selection, filtering, pagination | `AshTypescript.Rpc` + `AshTypescript.Resource` |
| Controller actions (Inertia renders, redirects, file downloads) | `AshTypescript.TypedController` |

### Setup

```elixir
defmodule MyApp.Session do
  use AshTypescript.TypedController

  typed_controller do
    module_name MyAppWeb.SessionController

    # Verb shortcut (preferred)
    get :auth do
      run fn conn, _params -> render_inertia(conn, "Auth") end
    end

    # Verb shortcut with args
    post :login do
      see [:auth, :logout]
      run fn conn, _params -> Plug.Conn.send_resp(conn, 200, "OK") end
      argument :code, :string, allow_nil?: false
      argument :remember_me, :boolean
    end

    # Positional method arg
    route :logout, :post do
      run fn conn, _params -> Plug.Conn.send_resp(conn, 200, "OK") end
    end

    # Default method (GET when omitted)
    route :home do
      run fn conn, _params -> Plug.Conn.send_resp(conn, 200, "Home") end
    end
  end
end
```

### Generated TypeScript

```typescript
// GET → path helper
authPath()                          // → "/auth"

// GET with query args → path with query params
searchPath({ q: "test", page: 1 }) // → "/search?q=test&page=1"

// POST → typed async function (via executeTypedControllerRequest helper)
login({ code: "abc" }, { headers: { "X-CSRF-Token": token } })

// PATCH with path params + input
updateProvider({ provider: "github" }, { enabled: true })
```

**Function parameter order**: `path` (if path params) → `input` (if args) → `config?: TypedControllerConfig`

**Modes**: `:full` generates path helpers + fetch functions (+ Zod schemas if enabled). `:paths_only` generates only path helpers.

### Typed Controller Constraints

- Handlers must return `%Plug.Conn{}` directly — no `{:ok, conn}` wrapping
- Multi-mount requires unique `as:` options on scopes for disambiguation
- Not an Ash resource — standalone Spark DSL with colocated arguments
- Path param `allow_nil?` must match presence: always present → `false`, sometimes present (multi-mount) → `true`

## Typed Channel (Event Subscriptions)

### When to Use

| Use Case | Extension |
|----------|-----------|
| Data operations with field selection, filtering, pagination | `AshTypescript.Rpc` + `AshTypescript.Resource` |
| Controller actions (Inertia renders, redirects, file downloads) | `AshTypescript.TypedController` |
| Server pushes events to clients (notifications, updates) | `AshTypescript.TypedChannel` |

### Setup

```elixir
defmodule MyAppWeb.OrgChannel do
  use AshTypescript.TypedChannel
  use Phoenix.Channel

  typed_channel do
    topic "org:*"

    resource MyApp.Post do
      publish :post_created
      publish :post_updated
    end
  end

  @impl true
  def join("org:" <> org_id, _payload, socket), do: {:ok, socket}
end
```

Resources must have `pub_sub` publications with matching `event:` names. Add `returns:` to publications for typed payloads (otherwise `unknown`).

### Generated TypeScript

```typescript
// Create branded channel + subscribe
const channel = createOrgChannel(socket, orgId);
channel.join();

const refs = onOrgChannelMessages(channel, {
  post_created: (payload) => console.log(payload),  // typed payload
  post_updated: (payload) => updatePost(payload),
});

// Single event: onOrgChannelMessage(channel, "post_created", handler)

// Cleanup
unsubscribeOrgChannel(channel, refs);
```

### Topic Patterns

| Topic Pattern | Factory Signature |
|--------------|-------------------|
| `"org:*"` (wildcard) | `createOrgChannel(socket, suffix)` |
| `"global"` (no wildcard) | `createGlobalChannel(socket)` |

### Typed Channel Constraints

- Event names must be unique across all resources in a channel
- Publications need `public?: true` (warning if missing)
- Publications need `returns:` option for typed payloads (warning if missing, falls back to `unknown`)
- Channel types go in `ash_types.ts`; channel functions go in `typed_channels_output_file`

## JSON Manifest (Third-Party Integrations)

When `json_manifest_file` is configured, `mix ash_typescript.codegen` generates a machine-readable JSON manifest. This enables third-party packages (e.g., TanStack Query wrappers) to introspect the generated API without coupling to ash_typescript internals.

```elixir
config :ash_typescript,
  json_manifest_file: "assets/js/ash_rpc_manifest.json",
  json_manifest_filename_format: :relative  # :relative | :absolute | :basename
```

The manifest contains:
- **`files`** — generated file locations with `importPath` (for TS imports, always relative, no `.ts`) and `filename` (format controlled by config)
- **`actions`** — every RPC action with: `functionName`, `actionType` (read/create/update/destroy/action), `get`, `namespace`, `types` (result, fields, input, config, filterInput — only present when applicable), `pagination`, `enableFilter`, `enableSort`, `variants`/`variantNames`, `deprecated`, `see`, `input` (none/optional/required)
- **`typedControllerRoutes`** — each route with: `functionName`, `method`, `path`, `pathParams`, `mutation`, `types`
- **`version`** — semver string (currently `"1.0"`) for consumer compatibility

### Consumer Example

```typescript
import manifest from "./ash_rpc_manifest.json";

for (const action of manifest.actions) {
  const isQuery = action.actionType === "read";
  // Import from manifest.files.rpc.importPath
  // Generate queryOptions/mutationOptions wrappers
}
```

## Common Gotchas

| Error Pattern | Fix |
|---------------|-----|
| Missing `extensions: [AshTypescript.Rpc]` | Add to domain |
| Missing `typescript` block on resource | Add `AshTypescript.Resource` extension + `typescript do type_name "X" end` |
| No `rpc_action` declarations | Explicitly declare each action |
| Filter syntax `{ field: false }` | Use operators: `{ field: { eq: false } }` |
| Missing `fields` parameter | Always include `fields: [...]` |
| Get action error on not found | Add `not_found_error?: false` |
| Invalid field name `field_1` or `is_active?` | Add field mapping |
| Identity not found | Check `identities` config; use `{ field: value }` for named |
| Load not allowed/denied | Check `allowed_loads`/`denied_loads` config |
| Channel/validation fn undefined | Enable in config |
| Typed controller 500 error | Handler must return `%Plug.Conn{}` |
| Routes not generated | Set `typed_controllers:`, `router:`, and `routes_output_file:` in config |
| Multi-mount ambiguity error | Add unique `as:` option to each scope |
| Path param without matching argument | Add `argument :param, :string` to route |
| Path param `allow_nil?` mismatch | Always-present → `false`; sometimes-present → `true` |
| Route hooks not firing | Check `typed_controller_import_into_generated` + hook names |
| Typed channel event not found | Event name must match `event:` option on resource's `pub_sub` publication |
| Duplicate channel event names | Use unique event names across all resources in one channel |
| Channel payload is `unknown` | Add `returns:` option to the resource's `pub_sub` publication |
| Typed channels not generated | Set `typed_channels:` and `typed_channels_output_file:` in config |

## Error Quick Reference

| Error Contains | Fix |
|----------------|-----|
| "Property does not exist" | Run `mix ash_typescript.codegen` |
| "fields is required" | Add `fields: [...]` |
| "No domains found" | Use `MIX_ENV=test` for test resources |
| "Action not found" | Add `rpc_action` declaration |
| "403 Forbidden" | Use `buildCSRFHeaders()` |
| "Invalid field names" | Add mapping (see Field Name Mapping) |
| "load_not_allowed" / "load_denied" | Check load restrictions config |
| "allow_nil?: true" + path param | Set `allow_nil?: false` for always-present path params |
| "allow_nil?: false" + sometimes-present | Use `allow_nil?: true` for multi-mount path params |
| "No publication with event X found" | Check `event:` option on resource's `pub_sub` block |
| "Duplicate event names found" | Use unique event names per channel |

## Configuration

```elixir
config :ash_typescript,
  output_file: "assets/js/ash_rpc.ts",
  run_endpoint: "/rpc/run",
  validate_endpoint: "/rpc/validate",
  generate_validation_functions: false,
  generate_phx_channel_rpc_actions: false,
  generate_zod_schemas: false,
  require_tenant_parameters: false,
  not_found_error?: true,
  # JSDoc/Manifest
  add_ash_internals_to_jsdoc: false,
  add_ash_internals_to_manifest: false,
  manifest_file: nil,
  json_manifest_file: nil,              # Machine-readable JSON manifest for third-party tools
  json_manifest_filename_format: :relative,  # :relative | :absolute | :basename
  source_path_prefix: nil,  # For monorepos: "backend"
  # Warnings
  warn_on_missing_rpc_config: true,
  warn_on_non_rpc_references: true,
  # Dev codegen behavior
  always_regenerate: false,
  # Imports/Types
  import_into_generated: [%{import_name: "CustomTypes", file: "./customTypes"}],
  type_mapping_overrides: [{MyApp.CustomType, "string"}],
  # Typed Controller (route helpers)
  typed_controllers: [MyApp.Session],
  router: MyAppWeb.Router,
  routes_output_file: "assets/js/routes.ts",
  typed_controller_mode: :full,                # :full or :paths_only
  typed_controller_path_params_style: :object,  # :object or :args
  # Optional: lifecycle hooks, custom imports, error handling
  # typed_controller_before_request_hook: "RouteHooks.beforeRequest",
  # typed_controller_after_request_hook: "RouteHooks.afterRequest",
  # typed_controller_hook_context_type: "RouteHooks.RouteHookContext",
  # typed_controller_import_into_generated: [%{import_name: "RouteHooks", file: "./routeHooks"}],
  # typed_controller_error_handler: {MyApp.ErrorHandler, :handle, []},
  # typed_controller_show_raised_errors: false  # true only in dev
  # Typed Channel (event subscriptions)
  typed_channels: [MyApp.OrgChannel],
  typed_channels_output_file: "assets/js/ash_typed_channels.ts"
```

## Commands

```bash
mix ash_typescript.codegen              # Generate
mix ash_typescript.codegen --check      # Verify up-to-date (CI)
mix ash_typescript.codegen --dry-run    # Preview
npx tsc ash_rpc.ts --noEmit             # Validate TS
```

<!-- ash_typescript-end -->
<!-- usage-rules-end -->

# Contributing to GreenFairy

Thank you for considering contributing to GreenFairy! This document outlines how to contribute effectively.

## Getting Started

### Prerequisites

- Elixir 1.14+
- Erlang/OTP 25+
- PostgreSQL (for running full test suite)

### Setup

```bash
# Clone the repository
git clone https://github.com/GreenFairy-GraphQL/greenfairy.git
cd green_fairy

# Install dependencies
mix deps.get

# Run tests
mix test
```

## Development Workflow

### Branch Naming

Use descriptive branch names:

- `feature/add-something` - New features
- `fix/broken-thing` - Bug fixes
- `docs/update-guide` - Documentation updates
- `refactor/improve-thing` - Code refactoring

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/green_fairy/type_test.exs

# Run tests with coverage
mix test --cover

# Run tests for specific adapter
mix test --only postgres
mix test --only mysql
```

### Code Quality

```bash
# Format code
mix format

# Run Credo for linting
mix credo

# Run dialyzer for type checking
mix dialyzer
```

### Documentation

```bash
# Generate docs locally
mix docs

# Open docs in browser
open doc/index.html
```

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `test:` Adding or updating tests
- `refactor:` Code refactoring (no functional changes)
- `chore:` Maintenance tasks

Examples:

```
feat: add support for PostgreSQL array operators
fix: resolve race condition in connection resolver
docs: update CQL getting started guide
test: add integration tests for MySQL adapter
refactor: simplify query builder logic
```

## Pull Request Process

1. **Create a branch** from `main`
2. **Make your changes** with tests
3. **Ensure tests pass** locally
4. **Update documentation** if needed
5. **Submit a PR** with a clear description

### PR Description Template

```markdown
## Summary

Brief description of changes.

## Changes

- Change 1
- Change 2

## Testing

How to test these changes.

## Checklist

- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] CHANGELOG updated (for features/fixes)
```

## Code Style

### General Guidelines

- Follow Elixir style conventions
- Use `mix format` before committing
- Keep functions small and focused
- Add typespecs for public functions
- Document public modules and functions

### Module Structure

```elixir
defmodule GreenFairy.Example do
  @moduledoc """
  Module documentation here.
  """

  # 1. Module attributes
  @behaviour SomeBehaviour

  # 2. use/import/alias
  use SomeModule
  import AnotherModule
  alias YetAnotherModule

  # 3. Module attributes
  @default_value 42

  # 4. Type definitions
  @type t :: %__MODULE__{}

  # 5. Struct definition
  defstruct [:field1, :field2]

  # 6. Callbacks (if implementing behaviour)
  @impl true
  def callback_function(arg), do: arg

  # 7. Public functions (with docs and specs)
  @doc """
  Does something useful.
  """
  @spec do_something(term()) :: {:ok, term()} | {:error, term()}
  def do_something(arg) do
    # ...
  end

  # 8. Private functions
  defp helper_function(arg), do: arg
end
```

### Testing Guidelines

- One test file per module
- Use descriptive test names
- Test edge cases
- Use `async: true` when possible
- Group related tests with `describe`

```elixir
defmodule GreenFairy.ExampleTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Example

  describe "do_something/1" do
    test "returns ok with valid input" do
      assert {:ok, result} = Example.do_something(:valid)
      assert result == :expected
    end

    test "returns error with invalid input" do
      assert {:error, _reason} = Example.do_something(:invalid)
    end
  end
end
```

## Architecture

### Module Organization

```
lib/green_fairy/
├── type.ex              # Core type DSL
├── interface.ex         # Interface DSL
├── input.ex             # Input type DSL
├── enum.ex              # Enum DSL
├── union.ex             # Union DSL
├── scalar.ex            # Custom scalar DSL
├── query.ex             # Query operations
├── mutation.ex          # Mutation operations
├── schema.ex            # Schema assembly
├── discovery.ex         # Auto-discovery
├── field/               # Field helpers
│   ├── connection.ex    # Relay connections
│   └── loader.ex        # Batch loading
├── cql/                 # CQL system
│   ├── adapter.ex       # Adapter behavior
│   └── adapters/        # Database adapters
├── relay/               # Relay support
│   ├── global_id.ex     # ID encoding
│   └── node.ex          # Node query
└── built_ins/           # Built-in types
    ├── node.ex          # Node interface
    └── page_info.ex     # PageInfo type
```

### Key Concepts

- **DSL Modules** - Provide macros for defining GraphQL types
- **Discovery** - Walks the schema graph to find all types
- **CQL** - Automatic filtering/sorting based on Ecto schemas
- **Adapters** - Database-specific operator implementations

## Reporting Issues

### Bug Reports

Include:

1. GreenFairy version
2. Elixir/Erlang versions
3. Database and version
4. Minimal reproduction code
5. Expected vs actual behavior
6. Stack trace (if applicable)

### Feature Requests

Include:

1. Use case description
2. Proposed API (if applicable)
3. Alternative solutions considered

## Questions?

- Open a [GitHub Discussion](https://github.com/GreenFairy-GraphQL/greenfairy/discussions)
- Check existing [Issues](https://github.com/GreenFairy-GraphQL/greenfairy/issues)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

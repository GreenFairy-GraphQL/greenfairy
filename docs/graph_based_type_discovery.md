# Graph-Based Type Discovery

**Status**: ✅ **IMPLEMENTED**

## Usage

Graph-based type discovery is the only way types are discovered:

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema,
    query: MyApp.GraphQL.RootQuery,
    mutation: MyApp.GraphQL.RootMutation
end
```

The schema will automatically:
1. Start from your Query/Mutation modules
2. Extract type references from field definitions
3. Recursively walk the graph to find all referenced types
4. Import only the types actually used in your schema

## Problem (Historical Context)

Previously, type discovery would scan all modules in specified namespaces:

```elixir
use GreenFairy.Schema,
  discover: [MyApp.GraphQL]  # Imports ALL types in this namespace
```

This has issues:
- Imports unused types
- Requires types to live in specific namespaces
- Magic/implicit behavior
- Can't have types in multiple locations easily

## Solution

Implement graph-based discovery that follows type references from roots:

```elixir
use GreenFairy.Schema,
  query: MyApp.GraphQL.RootQuery,
  mutation: MyApp.GraphQL.RootMutation
  # No discover: needed - follows type graph automatically
```

## Implementation Plan

### Phase 1: Track Type References in Field Definitions

**Goal**: Each GreenFairy type module knows which other types it references.

**Changes to `GreenFairy.Type`**:

1. In `parse_field_args/2`, extract the type module reference from field types
2. Store referenced type modules in a new module attribute: `@green_fairy_referenced_types`
3. Add callback function `__green_fairy_referenced_types__/0` that returns the list

**Example**:

```elixir
# In User type
field :posts, list_of(:post)  # References Post type
assoc :organization           # References Organization type (from Ecto)

# Generates:
@green_fairy_referenced_types [MyApp.GraphQL.Types.Post, MyApp.GraphQL.Types.Organization]
```

**Challenges**:
- Field types are often atoms (`:post`) not module references
- Need to map type identifiers back to modules
- Built-in scalars (`:string`, `:integer`) shouldn't be tracked
- Associations need to infer the type module from Ecto's related module

### Phase 2: Type Identifier to Module Registry

**Goal**: Map from type identifier atoms (`:user`) to their module (`MyApp.GraphQL.Types.User`)

**Create `GreenFairy.TypeRegistry`**:

```elixir
defmodule GreenFairy.TypeRegistry do
  @doc """
  Registers a type's identifier => module mapping at compile time.
  Called from each type's __before_compile__.
  """
  def register_type(identifier, module) do
    # Store in persistent_term or ETS table
    # Key: identifier atom, Value: module atom
  end

  @doc """
  Look up the module for a given type identifier.
  """
  def lookup_type(identifier) do
    # Retrieve from persistent_term or ETS
  end
end
```

**Changes**:
- Each type's `__before_compile__` registers itself: `TypeRegistry.register_type(:user, MyApp.GraphQL.Types.User)`
- When extracting field type references, map `:post` → `Post` module via registry

**Challenge**: Registry must be populated at compile time before schema compilation

### Phase 3: Graph Walking at Schema Compile Time

**Goal**: Walk the type graph from roots and discover all transitively referenced types.

**Changes to `GreenFairy.Schema.__before_compile__/1`**:

```elixir
def __before_compile__(env) do
  query_module = Module.get_attribute(env.module, :green_fairy_query_module)
  mutation_module = Module.get_attribute(env.module, :green_fairy_mutation_module)
  subscription_module = Module.get_attribute(env.module, :green_fairy_subscription_module)

  # Start with root modules
  root_modules = [query_module, mutation_module, subscription_module]
    |> Enum.reject(&is_nil/1)

  # Walk the graph
  all_referenced = walk_type_graph(root_modules, MapSet.new())

  # Generate import_types for discovered types
  import_statements = generate_imports(all_referenced)

  # ... rest of schema compilation
end

defp walk_type_graph([], visited), do: visited

defp walk_type_graph([module | rest], visited) do
  if MapSet.member?(visited, module) do
    walk_type_graph(rest, visited)
  else
    visited = MapSet.put(visited, module)

    # Get types this module references
    referenced =
      if function_exported?(module, :__green_fairy_referenced_types__, 0) do
        module.__green_fairy_referenced_types__()
      else
        []
      end

    # Recursively walk referenced types
    walk_type_graph(referenced ++ rest, visited)
  end
end
```

### Phase 4: Handle Special Cases

**Interfaces**:
- When a type implements an interface, include the interface in references
- Track interface → implementor mappings for resolve_type

**Unions**:
- Union types reference their member types
- Include all member types in graph

**Inputs**:
- Input objects can reference other input objects
- Track these references

**Connections**:
- Connection fields reference the node type
- Edge types reference the node type
- Include these in graph

**Associations**:
- `assoc :posts` needs to map Ecto's `Post` struct → GraphQL `Post` type
- Use the existing `GreenFairy.Registry` that maps struct → type identifier
- Then use TypeRegistry to map identifier → type module

### Phase 5: Remove Namespace-Based Discovery

**Changes**:
- Make `discover:` option optional/deprecated
- If both `discover:` and explicit roots provided, prefer graph-based
- Keep `discover:` for backwards compatibility but document graph-based as preferred

**Migration path**:
```elixir
# Old way (still works)
use GreenFairy.Schema,
  discover: [MyApp.GraphQL]

# New way (preferred)
use GreenFairy.Schema,
  query: MyApp.GraphQL.RootQuery,
  mutation: MyApp.GraphQL.RootMutation
```

## Benefits

1. **Explicit**: Only imports types actually used
2. **Flexible**: Types can live anywhere, not in specific namespaces
3. **Tree-shaking**: Large schemas only import what's needed
4. **Clearer dependencies**: Type graph is explicit
5. **Better errors**: Can detect unused types, circular references
6. **Modular**: Can split schemas across packages

## Edge Cases

1. **Lazy types**: Types referenced by string/atom that aren't compiled yet
   - Solution: Defer resolution until all modules compiled

2. **Dynamic types**: Types added at runtime
   - Solution: Not supported, graph must be static at compile time

3. **Circular references**: User → Post → User
   - Solution: Already handled by visited set in graph walking

4. **Forward references**: Type A references Type B before B is compiled
   - Solution: Use `__before_compile__` to defer graph walking until all types compiled

## Implementation Summary

All phases have been completed:

### ✅ Phase 1: Type Reference Tracking
- Added `@green_fairy_referenced_types` attribute to all type modules
- Extract and track field type references during AST transformation
- Handle `non_null`, `list_of` wrappers
- Filter out built-in scalars
- Added `__green_fairy_referenced_types__/0` callback

### ✅ Phase 2: TypeRegistry
- Created `GreenFairy.TypeRegistry` using ETS
- Types automatically register on compilation
- Maps type identifiers (`:user`) to modules (`MyApp.Types.User`)
- Supports lookup, listing, and clearing operations

### ✅ Phase 3: Graph Walking
- Implemented recursive graph walking in `Schema.__before_compile__/1`
- Uses MapSet to track visited types (prevents infinite loops)
- Resolves atom identifiers via TypeRegistry
- Handles module references directly
- Falls back to namespace discovery if no explicit roots

### ✅ Phase 4: Special Cases
- **Interfaces**: Track via `implements` statements
- **Unions**: Extract and track member types
- **Inputs**: Track field type references
- **Connections**: Track node type references
- **Associations**: Infer type from Ecto schema
- **Query/Mutation**: Parse blocks to extract field types

### ✅ Phase 5: Testing
- 8 comprehensive tests covering all scenarios
- TypeRegistry functionality
- Type reference tracking
- Union and Input tracking
- Graph walking with reachability
- All 1004 tests passing

## Implementation Order (Completed)

1. ✅ **Phase 1**: Track references in Type module (update `parse_field_args`, add attribute)
2. ✅ **Phase 2**: Create TypeRegistry for identifier → module mapping
3. ✅ **Phase 3**: Implement graph walking in Schema.__before_compile__
4. ✅ **Phase 4**: Handle interfaces, unions, inputs, connections, associations
5. ✅ **Phase 5**: Add tests, documentation, deprecation notices

## Testing Strategy

1. **Unit tests**: Test graph walking with mock modules
2. **Integration tests**: Full schema with complex type graphs
3. **Edge case tests**: Circular refs, unused types, missing types
4. **Performance tests**: Large schemas (100+ types)

## Open Questions

1. Should we support hybrid approach (discover + explicit roots)?
2. How to handle types in separate Mix apps/dependencies?
3. Should we warn about unused types in discovery namespaces?
4. Do we need a way to explicitly include types not in the graph (for fragments)?

## Related Code

- `lib/green_fairy/schema.ex` - Schema assembly and type importing
- `lib/green_fairy/type.ex` - Type parsing and field extraction
- `lib/green_fairy/registry.ex` - Struct to identifier mapping
- `lib/green_fairy/discovery.ex` - Graph-based discovery logic

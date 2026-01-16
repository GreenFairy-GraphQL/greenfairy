import {
  Environment,
  Network,
  RecordSource,
  Store,
  FetchFunction,
} from "relay-runtime";

// Store current user ID for demo authentication
let currentUserId: string | null = null;

export const setCurrentUserId = (userId: string | null) => {
  currentUserId = userId;
};

export const getCurrentUserId = () => currentUserId;

const fetchFn: FetchFunction = async (request, variables) => {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };

  // Add user ID header for demo authentication
  if (currentUserId) {
    headers["X-User-ID"] = currentUserId;
  }

  const response = await fetch("/api/graphql", {
    method: "POST",
    headers,
    body: JSON.stringify({
      query: request.text,
      variables,
    }),
  });

  return response.json();
};

export const environment = new Environment({
  network: Network.create(fetchFn),
  store: new Store(new RecordSource()),
});

import React, { useState } from "react";
import { graphql, useMutation } from "react-relay";
import type { CreateUserFormMutation } from "./__generated__/CreateUserFormMutation.graphql";

const mutation = graphql`
  mutation CreateUserFormMutation(
    $email: String!
    $username: String!
    $displayName: String
  ) {
    createUser(email: $email, username: $username, displayName: $displayName) {
      id
      email
      username
      displayName
    }
  }
`;

interface Props {
  onUserCreated: () => void;
}

export function CreateUserForm({ onUserCreated }: Props) {
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [error, setError] = useState<string | null>(null);

  const [commit, isInFlight] = useMutation<CreateUserFormMutation>(mutation);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    commit({
      variables: {
        email,
        username,
        displayName: displayName || undefined,
      },
      onCompleted: () => {
        setEmail("");
        setUsername("");
        setDisplayName("");
        onUserCreated();
      },
      onError: (err) => {
        setError(err.message || "Failed to create user");
      },
    });
  };

  return (
    <div className="card">
      <h2>Create User</h2>
      {error && <div className="error-message">{error}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="email">Email *</label>
          <input
            id="email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="user@example.com"
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="username">Username *</label>
          <input
            id="username"
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="johndoe"
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="displayName">Display Name</label>
          <input
            id="displayName"
            type="text"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="John Doe"
          />
        </div>
        <button type="submit" className="btn btn-primary" disabled={isInFlight}>
          {isInFlight ? "Creating..." : "Create User"}
        </button>
      </form>
    </div>
  );
}

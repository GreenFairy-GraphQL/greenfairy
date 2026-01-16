import React, { useState } from "react";
import { graphql, useMutation } from "react-relay";
import type { CreatePostFormMutation } from "./__generated__/CreatePostFormMutation.graphql";

const mutation = graphql`
  mutation CreatePostFormMutation(
    $body: String!
    $visibility: PostVisibility
  ) {
    createPost(body: $body, visibility: $visibility) {
      id
      body
      visibility
    }
  }
`;

interface Props {
  onPostCreated: () => void;
}

export function CreatePostForm({ onPostCreated }: Props) {
  const [body, setBody] = useState("");
  const [visibility, setVisibility] = useState<"PUBLIC" | "FRIENDS" | "PRIVATE">("PUBLIC");
  const [error, setError] = useState<string | null>(null);

  const [commit, isInFlight] = useMutation<CreatePostFormMutation>(mutation);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    commit({
      variables: {
        body,
        visibility,
      },
      onCompleted: (response) => {
        if (response.createPost) {
          setBody("");
          onPostCreated();
        }
      },
      onError: (err) => {
        setError(err.message || "Failed to create post. Make sure you have a user in the context.");
      },
    });
  };

  return (
    <div className="card">
      <h2>Create Post</h2>
      {error && <div className="error-message">{error}</div>}
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="body">What's on your mind?</label>
          <textarea
            id="body"
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder="Share your thoughts..."
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="visibility">Visibility</label>
          <select
            id="visibility"
            value={visibility}
            onChange={(e) => setVisibility(e.target.value as typeof visibility)}
          >
            <option value="PUBLIC">Public</option>
            <option value="FRIENDS">Friends Only</option>
            <option value="PRIVATE">Private</option>
          </select>
        </div>
        <button type="submit" className="btn btn-primary" disabled={isInFlight}>
          {isInFlight ? "Posting..." : "Post"}
        </button>
      </form>
      <p style={{ marginTop: "1rem", fontSize: "0.875rem", color: "#888" }}>
        Note: Creating posts requires authentication. In a real app, you would
        need to be logged in.
      </p>
    </div>
  );
}

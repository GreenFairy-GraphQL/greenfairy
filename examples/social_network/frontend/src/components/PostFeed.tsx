import React from "react";
import { graphql, useLazyLoadQuery } from "react-relay";
import type { PostFeedQuery } from "./__generated__/PostFeedQuery.graphql";

const query = graphql`
  query PostFeedQuery {
    posts {
      id
      body
      visibility
      insertedAt
      author {
        id
        username
        displayName
      }
    }
  }
`;

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function PostFeed() {
  const data = useLazyLoadQuery<PostFeedQuery>(query, {});

  if (!data.posts || data.posts.length === 0) {
    return (
      <div className="card">
        <div className="empty-state">
          <div className="empty-state-icon">📝</div>
          <p>No posts yet. Create one above!</p>
        </div>
      </div>
    );
  }

  return (
    <div>
      {data.posts.map((post) => (
        <div key={post.id} className="post-card">
          <div className="post-header">
            <div className="post-author-avatar">
              {(post.author?.displayName || post.author?.username || "?")[0].toUpperCase()}
            </div>
            <div className="post-author-info">
              <div className="post-author-name">
                {post.author?.displayName || post.author?.username || "Anonymous"}
              </div>
              <div className="post-time">{formatDate(post.insertedAt)}</div>
            </div>
            <span className="post-visibility">
              {post.visibility?.toLowerCase() || "public"}
            </span>
          </div>
          <div className="post-body">{post.body}</div>
        </div>
      ))}
    </div>
  );
}

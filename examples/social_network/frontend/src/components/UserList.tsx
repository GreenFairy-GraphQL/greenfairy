import React from "react";
import { graphql, useLazyLoadQuery } from "react-relay";
import type { UserListQuery } from "./__generated__/UserListQuery.graphql";

const query = graphql`
  query UserListQuery {
    users {
      id
      email
      username
      displayName
    }
  }
`;

export function UserList() {
  const data = useLazyLoadQuery<UserListQuery>(query, {});

  if (!data.users || data.users.length === 0) {
    return (
      <div className="card">
        <div className="empty-state">
          <div className="empty-state-icon">👥</div>
          <p>No users yet. Create one above!</p>
        </div>
      </div>
    );
  }

  return (
    <div className="card">
      <h2>Users</h2>
      {data.users.map((user) => (
        <div key={user.id} className="user-card">
          <div className="user-avatar">
            {(user.displayName || user.username)[0].toUpperCase()}
          </div>
          <div className="user-info">
            <div className="user-name">
              {user.displayName || user.username}
            </div>
            <div className="user-username">@{user.username}</div>
          </div>
        </div>
      ))}
    </div>
  );
}

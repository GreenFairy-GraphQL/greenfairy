import React, { useEffect } from "react";
import { graphql, useLazyLoadQuery } from "react-relay";
import { setCurrentUserId, getCurrentUserId } from "../relay/environment";
import type { UserSelectorQuery } from "./__generated__/UserSelectorQuery.graphql";

const query = graphql`
  query UserSelectorQuery {
    users {
      id
      username
      displayName
    }
  }
`;

interface Props {
  onUserChange: () => void;
}

export function UserSelector({ onUserChange }: Props) {
  const data = useLazyLoadQuery<UserSelectorQuery>(query, {});
  const [selectedUserId, setSelectedUserId] = React.useState<string | null>(
    getCurrentUserId()
  );

  useEffect(() => {
    // Auto-select first user if none selected
    if (!selectedUserId && data.users && data.users.length > 0) {
      const firstUser = data.users[0];
      setSelectedUserId(firstUser.id);
      setCurrentUserId(firstUser.id);
    }
  }, [data.users, selectedUserId]);

  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const userId = e.target.value || null;
    setSelectedUserId(userId);
    setCurrentUserId(userId);
    onUserChange();
  };

  const selectedUser = data.users?.find((u) => u.id === selectedUserId);

  return (
    <div className="user-selector">
      <label htmlFor="current-user">Logged in as:</label>
      <select
        id="current-user"
        value={selectedUserId || ""}
        onChange={handleChange}
      >
        <option value="">Not logged in</option>
        {data.users?.map((user) => (
          <option key={user.id} value={user.id}>
            {user.displayName || user.username}
          </option>
        ))}
      </select>
      {selectedUser && (
        <span className="current-user-badge">@{selectedUser.username}</span>
      )}
    </div>
  );
}

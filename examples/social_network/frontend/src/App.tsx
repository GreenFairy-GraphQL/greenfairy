import React, { Suspense, useState } from "react";
import { UserList } from "./components/UserList";
import { PostFeed } from "./components/PostFeed";
import { CreateUserForm } from "./components/CreateUserForm";
import { CreatePostForm } from "./components/CreatePostForm";
import { UserSelector } from "./components/UserSelector";
import "./App.css";

type Tab = "feed" | "users";

function App() {
  const [activeTab, setActiveTab] = useState<Tab>("feed");
  const [refreshKey, setRefreshKey] = useState(0);

  const handleRefresh = () => {
    setRefreshKey((k) => k + 1);
  };

  return (
    <div className="app">
      <header className="header">
        <div className="header-content">
          <div>
            <h1>Social Network</h1>
            <p className="subtitle">
              Built with GreenFairy + Absinthe + Relay
            </p>
          </div>
          <Suspense fallback={<div>Loading users...</div>}>
            <UserSelector onUserChange={handleRefresh} />
          </Suspense>
        </div>
      </header>

      <nav className="tabs">
        <button
          className={`tab ${activeTab === "feed" ? "active" : ""}`}
          onClick={() => setActiveTab("feed")}
        >
          Feed
        </button>
        <button
          className={`tab ${activeTab === "users" ? "active" : ""}`}
          onClick={() => setActiveTab("users")}
        >
          Users
        </button>
      </nav>

      <main className="main">
        <Suspense fallback={<div className="loading">Loading...</div>}>
          {activeTab === "feed" && (
            <div className="feed-container">
              <CreatePostForm onPostCreated={handleRefresh} />
              <PostFeed key={refreshKey} />
            </div>
          )}
          {activeTab === "users" && (
            <div className="users-container">
              <CreateUserForm onUserCreated={handleRefresh} />
              <UserList key={refreshKey} />
            </div>
          )}
        </Suspense>
      </main>

      <footer className="footer">
        <p>
          Example application demonstrating{" "}
          <a
            href="https://github.com/GreenFairy-GraphQL/greenfairy"
            target="_blank"
            rel="noopener noreferrer"
          >
            GreenFairy
          </a>
          , a cleaner DSL for Absinthe GraphQL schemas
        </p>
      </footer>
    </div>
  );
}

export default App;

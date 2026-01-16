/**
 * @generated SignedSource<<33afcc37e4045e0dda89d9bfaee6509f>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
export type PostVisibility = "FRIENDS" | "PRIVATE" | "PUBLIC" | "%future added value";
export type PostFeedQuery$variables = Record<PropertyKey, never>;
export type PostFeedQuery$data = {
  readonly posts: ReadonlyArray<{
    readonly author: {
      readonly displayName: string | null | undefined;
      readonly id: string;
      readonly username: string;
    };
    readonly body: string;
    readonly id: string;
    readonly insertedAt: any;
    readonly visibility: PostVisibility | null | undefined;
  }> | null | undefined;
};
export type PostFeedQuery = {
  response: PostFeedQuery$data;
  variables: PostFeedQuery$variables;
};

const node: ConcreteRequest = (function(){
var v0 = {
  "alias": null,
  "args": null,
  "kind": "ScalarField",
  "name": "id",
  "storageKey": null
},
v1 = [
  {
    "alias": null,
    "args": null,
    "concreteType": "Post",
    "kind": "LinkedField",
    "name": "posts",
    "plural": true,
    "selections": [
      (v0/*: any*/),
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "body",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "visibility",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "insertedAt",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "concreteType": "User",
        "kind": "LinkedField",
        "name": "author",
        "plural": false,
        "selections": [
          (v0/*: any*/),
          {
            "alias": null,
            "args": null,
            "kind": "ScalarField",
            "name": "username",
            "storageKey": null
          },
          {
            "alias": null,
            "args": null,
            "kind": "ScalarField",
            "name": "displayName",
            "storageKey": null
          }
        ],
        "storageKey": null
      }
    ],
    "storageKey": null
  }
];
return {
  "fragment": {
    "argumentDefinitions": [],
    "kind": "Fragment",
    "metadata": null,
    "name": "PostFeedQuery",
    "selections": (v1/*: any*/),
    "type": "Query",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "PostFeedQuery",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "111743ef3a7d13b6b4810946ca0a0804",
    "id": null,
    "metadata": {},
    "name": "PostFeedQuery",
    "operationKind": "query",
    "text": "query PostFeedQuery {\n  posts {\n    id\n    body\n    visibility\n    insertedAt\n    author {\n      id\n      username\n      displayName\n    }\n  }\n}\n"
  }
};
})();

(node as any).hash = "260ded6a51f9abd3519e47f9b55484d5";

export default node;

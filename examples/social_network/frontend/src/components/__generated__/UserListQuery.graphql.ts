/**
 * @generated SignedSource<<efdeeaf46fdce9e886d76d5d39e1b7ac>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
export type UserListQuery$variables = Record<PropertyKey, never>;
export type UserListQuery$data = {
  readonly users: ReadonlyArray<{
    readonly displayName: string | null | undefined;
    readonly email: string;
    readonly id: string;
    readonly username: string;
  }> | null | undefined;
};
export type UserListQuery = {
  response: UserListQuery$data;
  variables: UserListQuery$variables;
};

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "alias": null,
    "args": null,
    "concreteType": "User",
    "kind": "LinkedField",
    "name": "users",
    "plural": true,
    "selections": [
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "id",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "email",
        "storageKey": null
      },
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
];
return {
  "fragment": {
    "argumentDefinitions": [],
    "kind": "Fragment",
    "metadata": null,
    "name": "UserListQuery",
    "selections": (v0/*: any*/),
    "type": "Query",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "UserListQuery",
    "selections": (v0/*: any*/)
  },
  "params": {
    "cacheID": "d01cb19374ed9f96676a752f872b12c0",
    "id": null,
    "metadata": {},
    "name": "UserListQuery",
    "operationKind": "query",
    "text": "query UserListQuery {\n  users {\n    id\n    email\n    username\n    displayName\n  }\n}\n"
  }
};
})();

(node as any).hash = "db3f396c23b55342ce3b6d3a720f1d10";

export default node;

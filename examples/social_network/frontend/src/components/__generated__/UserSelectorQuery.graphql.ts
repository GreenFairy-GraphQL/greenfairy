/**
 * @generated SignedSource<<5d6a2253ed2dac3fa5da4c47f965830c>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Query } from 'relay-runtime';
export type UserSelectorQuery$variables = Record<PropertyKey, never>;
export type UserSelectorQuery$data = {
  readonly users: ReadonlyArray<{
    readonly displayName: string | null | undefined;
    readonly id: string;
    readonly username: string;
  }> | null | undefined;
};
export type UserSelectorQuery = {
  response: UserSelectorQuery$data;
  variables: UserSelectorQuery$variables;
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
    "name": "UserSelectorQuery",
    "selections": (v0/*: any*/),
    "type": "Query",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [],
    "kind": "Operation",
    "name": "UserSelectorQuery",
    "selections": (v0/*: any*/)
  },
  "params": {
    "cacheID": "f0470f0b1c295c54e1a832b47ef9ff9a",
    "id": null,
    "metadata": {},
    "name": "UserSelectorQuery",
    "operationKind": "query",
    "text": "query UserSelectorQuery {\n  users {\n    id\n    username\n    displayName\n  }\n}\n"
  }
};
})();

(node as any).hash = "f4b5bbb8bfeed5bfd63a521995835378";

export default node;

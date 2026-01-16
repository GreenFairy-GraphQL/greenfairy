/**
 * @generated SignedSource<<ba6b0cc0ab16822533fe9abe9bea09cd>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Mutation } from 'relay-runtime';
export type CreateUserFormMutation$variables = {
  displayName?: string | null | undefined;
  email: string;
  username: string;
};
export type CreateUserFormMutation$data = {
  readonly createUser: {
    readonly displayName: string | null | undefined;
    readonly email: string;
    readonly id: string;
    readonly username: string;
  } | null | undefined;
};
export type CreateUserFormMutation = {
  response: CreateUserFormMutation$data;
  variables: CreateUserFormMutation$variables;
};

const node: ConcreteRequest = (function(){
var v0 = {
  "defaultValue": null,
  "kind": "LocalArgument",
  "name": "displayName"
},
v1 = {
  "defaultValue": null,
  "kind": "LocalArgument",
  "name": "email"
},
v2 = {
  "defaultValue": null,
  "kind": "LocalArgument",
  "name": "username"
},
v3 = [
  {
    "alias": null,
    "args": [
      {
        "kind": "Variable",
        "name": "displayName",
        "variableName": "displayName"
      },
      {
        "kind": "Variable",
        "name": "email",
        "variableName": "email"
      },
      {
        "kind": "Variable",
        "name": "username",
        "variableName": "username"
      }
    ],
    "concreteType": "User",
    "kind": "LinkedField",
    "name": "createUser",
    "plural": false,
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
    "argumentDefinitions": [
      (v0/*: any*/),
      (v1/*: any*/),
      (v2/*: any*/)
    ],
    "kind": "Fragment",
    "metadata": null,
    "name": "CreateUserFormMutation",
    "selections": (v3/*: any*/),
    "type": "Mutation",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": [
      (v1/*: any*/),
      (v2/*: any*/),
      (v0/*: any*/)
    ],
    "kind": "Operation",
    "name": "CreateUserFormMutation",
    "selections": (v3/*: any*/)
  },
  "params": {
    "cacheID": "39ac29025d734a88d45d841b3dd94880",
    "id": null,
    "metadata": {},
    "name": "CreateUserFormMutation",
    "operationKind": "mutation",
    "text": "mutation CreateUserFormMutation(\n  $email: String!\n  $username: String!\n  $displayName: String\n) {\n  createUser(email: $email, username: $username, displayName: $displayName) {\n    id\n    email\n    username\n    displayName\n  }\n}\n"
  }
};
})();

(node as any).hash = "3d5f23983c0b94cfb68e2d2fbab7b858";

export default node;

/**
 * @generated SignedSource<<db74b8c2aaa136257f7ac1d2c88f87ca>>
 * @lightSyntaxTransform
 * @nogrep
 */

/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ConcreteRequest, Mutation } from 'relay-runtime';
export type PostVisibility = "FRIENDS" | "PRIVATE" | "PUBLIC" | "%future added value";
export type CreatePostFormMutation$variables = {
  body: string;
  visibility?: PostVisibility | null | undefined;
};
export type CreatePostFormMutation$data = {
  readonly createPost: {
    readonly body: string;
    readonly id: string;
    readonly visibility: PostVisibility | null | undefined;
  } | null | undefined;
};
export type CreatePostFormMutation = {
  response: CreatePostFormMutation$data;
  variables: CreatePostFormMutation$variables;
};

const node: ConcreteRequest = (function(){
var v0 = [
  {
    "defaultValue": null,
    "kind": "LocalArgument",
    "name": "body"
  },
  {
    "defaultValue": null,
    "kind": "LocalArgument",
    "name": "visibility"
  }
],
v1 = [
  {
    "alias": null,
    "args": [
      {
        "kind": "Variable",
        "name": "body",
        "variableName": "body"
      },
      {
        "kind": "Variable",
        "name": "visibility",
        "variableName": "visibility"
      }
    ],
    "concreteType": "Post",
    "kind": "LinkedField",
    "name": "createPost",
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
        "name": "body",
        "storageKey": null
      },
      {
        "alias": null,
        "args": null,
        "kind": "ScalarField",
        "name": "visibility",
        "storageKey": null
      }
    ],
    "storageKey": null
  }
];
return {
  "fragment": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Fragment",
    "metadata": null,
    "name": "CreatePostFormMutation",
    "selections": (v1/*: any*/),
    "type": "Mutation",
    "abstractKey": null
  },
  "kind": "Request",
  "operation": {
    "argumentDefinitions": (v0/*: any*/),
    "kind": "Operation",
    "name": "CreatePostFormMutation",
    "selections": (v1/*: any*/)
  },
  "params": {
    "cacheID": "b6a40d249ab336fa14266ef897ad54a9",
    "id": null,
    "metadata": {},
    "name": "CreatePostFormMutation",
    "operationKind": "mutation",
    "text": "mutation CreatePostFormMutation(\n  $body: String!\n  $visibility: PostVisibility\n) {\n  createPost(body: $body, visibility: $visibility) {\n    id\n    body\n    visibility\n  }\n}\n"
  }
};
})();

(node as any).hash = "fff9b248a389944c9ae413101a00e4c0";

export default node;

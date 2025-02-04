# API documentation

This API is for GOV.UK Publishing microservices (the things which make
up www.gov.uk) to implement personalisation and user session
management. This API is not for other government services.

- [Nomenclature](#nomenclature)
  - [Identity provider](#identity-provider)
  - [Session identifier](#session-identifier)
- [Using this API](#using-this-api)
- [API endpoints](#api-endpoints)
  - [`GET /api/oauth2/sign-in`](#get-apioauth2sign-in)
  - [`POST /api/oauth2/callback`](#post-apioauth2callback)
  - [`GET /api/oauth2/end-session`](#get-apioauth2end-session)
  - [`GET /api/user`](#get-apiuser)
  - [`GET /user/match-by-email`](#get-usermatch-by-email)
  - [`GET /api/attributes`](#get-apiattributes)
  - [`PATCH /api/attributes`](#patch-apiattributes)
  - [`GET /api/email-subscriptions/:subscription_name`](#get-apiemail-subscriptionssubscription_name)
  - [`PUT /api/email-subscriptions/:subscription_name`](#put-apiemail-subscriptionssubscription_name)
  - [`DELETE /api/email-subscriptions/:subscription_name`](#delete-apiemail-subscriptionssubscription_name)
  - [`PUT /api/oidc-users/:subject_identifier`](#put-apioidc-userssubject_identifier)
  - [`DELETE /api/oidc-users/:subject_identifier`](#delete-apioidc-userssubject_identifier)
  - [`GET /api/personalisation/check-email-subscription`](#get-apipersonalisationcheck-email-subscription)
  - [`POST /api/oidc_events/backchannel_logout`](#post-apioidc_eventsbackchannel_logout)
- [API errors](#api-errors)
  - [MFA required](#mfa-required)
  - [Unknown attribute names](#unknown-attribute-names)
  - [Unwritable attributes](#unwritable-attributes)

## Nomenclature

### Identity provider

The service which authenticates a user. Currently we use the Digital Identity authentication service.

### Session identifier

An opaque token which identifies a user and provides access to their attributes.

## Using this API

You should use this API in combination with the [govuk_personalisation][] gem, like so:

```ruby
class YourRailsController < ApplicationController
  # include the concern in your controller
  include GovukPersonalisation::AccountConcern

  def show
    # call the API with gds-api-adapters, the @govuk_account_session is provided by the concern
    result = GdsApi.account_api.get_attributes(
      attributes: %w[some user attributes],
      govuk_account_session: @govuk_account_session,
    )

    # set up the response header and update @govuk_account_session
    set_account_session_header(result["govuk_account_session"])

    # do something in your view with the result
    @attributes = result["values"]
  rescue GdsApi::HTTPUnauthorized
    # the user's session is invalid
    logout!
  rescue GdsApi::HTTPForbidden
    # the user needs to reauthenticate with MFA
  end
end
```

The [govuk_personalisation][] gem handles setting the `GOVUK-Account-Session` and `Vary` response headers for your app, ensuring that responses are not cached.  In local development there is a cookie instead of a custom header, which the gem also handles for you.

[govuk_personalisation]: https://github.com/alphagov/govuk_personalisation

## API endpoints

### `GET /api/oauth2/sign-in`

Generates an OAuth sign in URL.

This URL should be served to the user with a 302 response to authenticate the user against the identity provider.

#### Query parameters

- `mfa` *(optional)*
  - either `true` (require MFA) or `false` (do not require MFA, the default)
- `redirect_path` *(optional)*
  - a path on GOV.UK to send the user to after authenticating

#### JSON response fields

- `auth_uri`
  - an absolute URL, pointing to the identity provider, which the user should be redirected to so they can authenticate
- `state`
  - a random string, used for CSRF protection, which should be stored in a cookie and compared with the `state` returned by the identity provider after the user authenticated

#### Response codes

- 200

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_sign_in_url(
    redirect_path: "/guidance/keeping-a-pet-pig-or-micropig",
)
```

Response:

```json
{
    "auth_uri": "https://www.account.publishing.service.gov.uk/oauth/authorize?client_id=clientid&nonce=nonce&redirect_uri=https%3A%2F%2Fwww.gov.uk%2Fsign-in%2Fcallback&response_type=code&scope=openid&state=12345%3Aabcd",
    "state": "12345:abcdef"
}
```

### `POST /api/oauth2/callback`

Validates an OAuth response from the identity provider.

This is only used by the [`SessionsController` in frontend][], as the
identity provider redirects the user after signing in to
`https://www.gov.uk/sign-in/callback`.

[`SessionsController` in frontend]: https://github.com/alphagov/frontend/blob/main/app/controllers/sessions_controller.rb

#### Request parameters

- `code`
  - the value of the `code` parameter returned from the identity provider
- `state`
  - the value of the `state` parameter returned from the identity provider

#### JSON response fields

- `govuk_account_session`
  - a session identifier
- `redirect_path` *(optional)*
  - the `redirect_path` which was previously passed to `GET /api/oauth2/sign-in`, if given
  
#### Response codes

- 401 if authentication is unsuccessful
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.validate_auth_response(
    code: "12345",
    state: "67890",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "redirect_path": "/guidance/keeping-a-pet-pig-or-micropig",
    "cookie_consent": false,
}
```

### `GET /api/oauth2/end-session`

Generates a sign out URL.

This URL should be served to the user with a 302 response to terminate
their session with the identity provider and connected services.  If
the session identifier is given, it may be passed to the identity
provider to validate the user's session.

This does not invalidate the user's session on www.gov.uk.  You must
also use the `logout!` method in [govuk_personalisation][] to do that.

#### Request headers

- `GOVUK-Account-Session` *(optional)*
  - the user's session identifier

#### JSON response fields

- `end_session_uri`
  - an absolute URL, pointing to the identity provider, which the user should be redirected to to end their session

#### Response codes

- 200

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_end_session_url(
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "end_session_uri": "https://www.account.publishing.service.gov.uk/sign-out?continue=1"
}
```

### `GET /api/user`

Retrieves the information needed to render the `/account/home` page.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### JSON response fields

- `id`
  - the user identifier
- `mfa`
  - `true` if the user has authenticated with MFA, `false` otherwise
- `email`
  - the user's current email address
- `email_verified`
  - whether the user has confirmed their email address or not
- `services`
  - object of known services, keys are service names and values are one of:
    - `yes`: the user has used the service and can use it now
    - `yes_but_must_reauthenticate`: the user has used the service but must reauthenticate with MFA
    - `no`: the user has not used the service
    - `unknown`: the user must reauthenticate with MFA to check whether they have used the service or not

#### Response codes

- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_user(
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "id": "some-user-identifier",
    "mfa": false,
    "email": "email@example.com",
    "email_verified": false,
    "services": {}
}
```

### `GET /user/match-by-email`

Checks if a user with the given email address exists and if it is the
logged-in user (if a session is given).

This is only used by email-alert-frontend, so it can check if an
address corresponds to an account and either log the user in or show
an appropriate message with a single API call.

#### Request headers

- `GOVUK-Account-Session` *(optional)*
  - the user's session identifier, if not given `"match": true` is not a possible response

#### Query parameters

- `email`
  - the email address to search for

#### JSON response fields

- `match`
  - `true` if the session has the given email address, or `false` if a different user has that email address

#### Response codes

- 404 if there is no user with that email address
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.match_user_by_email(
    email: "email@example.com",
)
```

Response:

```json
{
    "match": false
}
```

Request with a session (with gds-api-adapters):

```ruby
GdsApi.account_api.match_user_by_email(
    email: "email@example.com",
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "match": true
}
```

### `GET /api/attributes`

Retrieves attribute values for the current user.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Query parameters

- `attributes[]` *(one for each attribute)*
  - a list of attribute names, specified once for each name

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `values`
  - a JSON object of attribute values, where keys are attribute names and values are attribute values

#### Response codes

- 422 if any attributes are unknown (see [error: unknown attribute names](#unknown-attribute-names))
- 403 if the user must reauthenticate with MFA (see [error: MFA required](#mfa-required))
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_attributes(
    attributes: %w[name1 name2],
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "values": {
        "name1": "value1",
        "name2": "value2"
    }
}
```

### `PATCH /api/attributes`

Updates the attributes of the current user.

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### JSON request parameters

- `attributes`
  - a JSON object where keys are attribute names and values are attribute values

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier

#### Response codes

- 422 if any attributes are unknown (see [error: unknown attribute names](#unknown-attribute-names))
- 403 if any attributes are unwritable (see [error: unwritable attributes](#unwritable-attributes))
- 403 if the user must reauthenticate with MFA (see [error: MFA required](#mfa-required))
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.set_attributes(
    attributes: { name1: "value1", name2: "value2" },
    govuk_account_session: "session-identifier",
)
```

Response:

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg=="
}
```

### `GET /api/email-subscriptions/:subscription_name`

Get the details of a named email subscription

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `subscription_name`
  - the name of the subscription

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `email_subscription`
  - details of the subscription

#### Response codes

- 404 if there is no such subscription (or if it has been deleted)
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.get_email_subscription(
    name: "some-subscription",
    govuk_account_session: "session-identifier",
)
```

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "email_subscription": {
      "name": "some-subscription",
      "topic_slug": "subscriber-list-slug",
      "email_alert_api_subscription_id": "cd5f6972-faf3-4f1c-bb76-3774b0a389f0"
    },
}
```

### `PUT /api/email-subscriptions/:subscription_name`

Create or update a named email subscription

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `subscription_name`
  - the name of the subscription

#### JSON request parameters

- `topic_slug`
  - the email-alert-api topic slug

#### JSON response fields

- `govuk_account_session` *(optional)*
  - a new session identifier
- `email_subscription`
  - details of the subscription

#### Response codes

- 422 if the `topic_slug` parameter is missing
- 401 if the session identifier is invalid
- 200 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.put_email_subscription(
    name: "some-subscription",
    topic_slug: "subscriber-list-slug",
    govuk_account_session: "session-identifier",
)
```

```json
{
    "govuk_account_session": "YWNjZXNzLXRva2Vu.cmVmcmVzaC10b2tlbg==",
    "email_subscription": {
      "name": "some-subscription",
      "topic_slug": "subscriber-list-slug",
      "email_alert_api_subscription_id": "96ae61d6-c2a1-48cb-8e67-da9d105ae381"
    },
}
```

### `DELETE /api/email-subscriptions/:subscription_name`

Cancel and remove a named email subscription

#### Request headers

- `GOVUK-Account-Session`
  - the user's session identifier

#### Request parameters

- `subscription_name`
  - the name of the subscription

#### Response codes

- 404 if there is no such subscription (or if it has been deleted)
- 401 if the session identifier is invalid
- 204 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.delete_email_subscription(
    name: "some-subscription",
    govuk_account_session: "session-identifier",
)
```

Response is status code only.

### `PUT /api/oidc-users/:subject_identifier`

Update an account and its email subscriptions by subject identifier.
This endpoint requires the `update_protected_attributes` scope.

#### Request parameters

- `subject_identifier`
  - the subject identifier of the user to update

#### JSON request parameters

- `legacy_sub` *(optional)*
  - if this is a user created pre-migration, their original subject identifier (a string)
- `email` *(optional)*
  - the new email address (a string)
- `email_verified` *(optional)*
  - whether the new email address is verified (a boolean)

#### JSON response fields

- `sub`
  - the subject identifier
- `email`
- `email_verified`

#### Response codes

- 200

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.update_user_by_subject_identifier(
    subject_identifier: "subject-identifier",
    email: "user@example.com",
    email_verified: true,
)
```

Response:

```json
{
    "sub": "subject-identifier",
    "email": "user@example.com",
    "email_verified": true,
}
```

### `DELETE /api/oidc-users/:subject_identifier`

Delete an account by subject identifier.  This endpoint requires the
`update_protected_attributes` scope.

#### Request parameters

- `subject_identifier`
  - the subject identifier of the user to delete

#### Query parameters

- `legacy_sub` *(optional)*
  - if this is a user created pre-migration, their original subject identifier (a string)

#### Response codes

- 404 if the user cannot be found
- 204 otherwise

#### Example request / response

Request (with gds-api-adapters):

```ruby
GdsApi.account_api.delete_user_by_subject_identifier(
    subject_identifier: "subject-identifier",
)
```

Response is status code only.

### `GET /api/personalisation/check-email-subscription`

Personalisation endpoint for checking if an email subscription is active.

See [Progressive enhancement ADR for more details](adr/002-progressive-enhancement.md)

#### Request parameters
- `subject_identifier`
  - the subject identifier from a user session

#### Query parameters

- `base_path` *(optional)*
  - the base path of the page (to match against the "url" of an email-alert-api subscriber list)
- `topic_slug` *(optional)*
  - the email-alert-api topic slug

Exactly one of `base_path` and `topic_slug` must be specified.

#### JSON response fields

- `base_path`
  - the base_path parameter, if there is one (a string)
- `topic_slug`
  - the topic_slug parameter, if there is one (a string)
- `active`
  - whether the subscription is active (a boolean)

#### Response codes

- 401 if the session identifier is invalid
- 422 if neither `base_path` nor `topic_slug` are passed; or if both are
- 200 otherwise

#### Example request / response

Note: This endpoint is not included in the GDS API Adaptors wrappers.
As a personalisation endpoint, it allows us to progressively enhance pages from client side requests.

To test the endpoint with curl:

```
curl -H "GOVUK-Account-Session={{account_session_header}}" \
  "{{GOV.UK environment}}/api/personalisation/check-email-subscription?base_path=/guidance/keeping-a-pet-pig-or-micropig"
```

```json
{
    "base_path": "/guidance/keeping-a-pet-pig-or-micropig",
    "active": true,
    "button_html": "<form>...</form>"
}
```

### `POST /api/oidc_events/backchannel_logout`

A public API endpoint that Implements OpenID Connect Back-Channel Logout 1.0 - draft 07.

#### Query parameters
- `logout_token`
  - A signed JWT

#### Response codes

- 400 if the Logout Token JWT is invalid or signature cannot be verified
- 200 otherwise

#### Note

This endpoint will only ever receive calls from the Oidc OP (Digital Identity), as an OIDC event. Because of that, there is not an GDS API Adaptor for this endpoint, as it will not be called from another Ruby application.

## API errors

API errors are returned as an [RFC 7807][] "Problem Detail" object, in
the following format:

```json
{
  "type": "URI which identifies the problem type and points to further information",
  "title": "Short human-readable summary of the problem type",
  "detail": "Human-readable explanation of this specific instance of the problem."
}
```

Each error type may define additional response fields.

[RFC 7807]: https://tools.ietf.org/html/rfc7807

### MFA required

You have tried to access something requires MFA, but the current user
has not authenticated with MFA.

#### Debugging steps

This is not an error, the user must be reauthenticated with MFA.

### Unknown attribute names

One or more of the attribute names you have specified are not known.
The `attributes` response field lists these.

### Unwritable attributes

One or more of the attributes you have specified cannot be updated
through account-api.  The `attributes` response field lists these.

Do not just reauthenticate the user and try again.

#### Debugging steps

- check the `errors` returned as an extra detail in the response for specific error messages

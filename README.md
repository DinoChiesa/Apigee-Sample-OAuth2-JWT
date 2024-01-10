# OAuth v2.0 Token Proxy - Client Credentials - JWT

This is an example Apigee proxy that illustrates how to use Apigee to dispense
and verify JWT-format tokens, for the "client credentials" grant type. This is a
grant type that is commonly-referred to as "2-legged OAuth".

The tokens dispensed by this example are OAuth 2.0 bearer tokens, JWT format.

Tokens issued via this grant type are most useful for service-to-service communication.

Consult [IETF RFC 6749](https://www.rfc-editor.org/rfc/rfc6749) for more details on OAuth2.

This example works with Apigee X and hybrid.


## Disclaimer

This example is not an official Google product, nor is it part of an official Google product.

## License

This material is Copyright 2024, Google LLC.
and is licensed under the Apache 2.0 license. See the [LICENSE](LICENSE) file.

This code is open source but you don't need to compile it in order to use it.


## Set up the example

### Pre-requisites

- a linux instance
- a GCP project
- an Apigee organization, and an environment
- the `gcloud` command
- the `curl` command

All of these are provided for you, free, if you use [Google Cloud Shell](https://cloud.google.com gle.com/shell).

### Steps

1. Set the required environment variables
   ```sh
   export PROJECT=my-gcp-project
   export APIGEE_ENV=my-apigee-environment
   export APIGEE_HOST=endpoint-where-apigee-is-accessible.io
   ```

2. Run the bundled setup script to set up the appropriate configuration:
   ```sh
   ./setup-oauth-jwt-example.sh
   ```

## Using the proxy

1. Before invoking these calls, You may want to start a debugsession on the API
   Proxy to examine its behavior.  Use the Apigee UI to do that.

2. In the output of the setup script, you should see statements showing the
   APP\_CLIENT\_ID and APP\_CLIENT\_SECRET. Copy/paste those to get those
   variables.


3. Then, invoke the token-dispensing endpoint to get a token:
   ```sh
   curl -i -X POST \
     -u $APP_CLIENT_ID:$APP_CLIENT_SECRET \
     -d grant_type=client_credentials \
     https://my-endpoint.io/oauth2-cc-jwt-mb1531-token-dispenser/token
   ```

   In the output of that, you should see a `token` header.  Copy/paste the VALUE of that header to set
   another shell variable, for `access_token`. IE, you should copy/paste something like this:
   ```sh
   access_token=eyJ0eXAiOiJhdCtKV1QiLCJhb....
   ```

4. Use the `access_token` to invoke the API:

   ```sh
   curl -i -X GET \
    -H "Authorization: Bearer $access_token" \
    https://my-apigee-endpoint.io/oauth2-cc-jwt-mb1531-token-verifier/check
   ```

   If the token is valid, you will get a happy message.
   ```
   HTTP/2 200
   apiproxy: oauth2-cc-jwt-mb1531 r1
   x-request-id: 14cc2daf-6d7e-4e32-94e4-169199d2ec14
   content-length: 20
   date: Mon, 08 Jan 2024 19:14:37 GMT

   {
     "status" : "OK"
   }
   ```

   If the token is expired, mis-formatted (eg, is not a JWT), or cannot be
   verified with the given public key, then you will get a sad message.  To test
   this, in place of a valid token, you can send an arbitrary string:

   ```sh
   curl -i -X GET \
    -H "Authorization: Bearer not-an-access-token" \
    https://my-apigee-endpoint.io/oauth2-cc-jwt-mb1531-token-verifier/check
   ```

   And the result will be something like this:
   ```
   HTTP/2 401
   content-type: application/json
   www-authenticate: Bearer realm="null",error="invalid_token",error_description="oauth.v2.JWTDecodingFailed: JWT Access token decoding failed"
   apiproxy: oauth2-cc-jwt-mb1531 r1
   content-length: 112
   date: Mon, 08 Jan 2024 19:21:20 GMT

   {"fault":{"faultstring":"JWT Access token decoding failed","detail":{"errorcode":"oauth.v2.JWTDecodingFailed"}}}
   ```

   You could also wait 5 minutes for the access token to expire, then re-try the
   request, to see what happens with an expired token.


## Commentary

This example shows you how to dispense OAuth2 access tokens, via
`client_credentials` grant type, and to verify them. In Apigee, there are two
options for the form of the token: an opaque token, or a JWT. This example shows
the use of JWT-format access tokens.

This example uses a somewhat rarely used configuration: multiple ProxyEndpoint
entities - one for dispensing tokens, and one for verifying tokens.

Normally in Apigee, the API proxy that dispenses tokens is not the same as the
API Proxy that verifies tokens. Typically there is ONE token dispensing
endpoint, and then a large number of proxies that might verify tokens. The
approach of using multiple ProxyEndpoint elements in this example stands in
place of that typical configuration.


## Clean up

Run the clean up script to remove the assets and configuration for this example:
```sh
./clean-oauth-jwt-example.sh
```

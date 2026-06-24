# Project Folder Structure

Agents must follow this folder structure when adding, moving, or generating source files.

Do not create alternative root folders unless explicitly requested. Business feature units live flat under `sources/modules/<feature-name>/`.

```text
sources
|
+-- app
|   +-- App.WebModule.dfm
|   +-- App.WebModule.pas
|
+-- core
|   +-- BFA.Core.Config.pas
|   +-- BFA.Core.Constants.pas
|   +-- BFA.Core.Endpoint.pas
|   +-- BFA.Core.Helper.pas
|   +-- BFA.Core.Messages.pas
|   +-- BFA.Core.Request.pas
|   +-- BFA.Core.Response.pas
|   +-- BFA.Core.Rest.pas
|
+-- infrastructure
|   +-- database
|   |   +-- DB.ConnectionFactory.pas
|   |   +-- DB.Helper.Query.pas
|   |
|   +-- security
|       +-- BFA.Security.Token.pas
|
+-- modules
|   +-- auth
|   |   +-- RestAPI.Auth.pas
|   |   +-- Auth.DTO.pas
|   |   +-- Auth.Repository.pas
|   |   +-- Auth.Service.pas
|   |   +-- Auth.Validator.pas
|   |
|   +-- category
|   |   +-- RestAPI.Category.pas
|   |   +-- Category.DTO.pas
|   |   +-- Category.Repository.pas
|   |   +-- Category.Service.pas
|   |   +-- Category.Validator.pas
|   |
|   +-- customers
|   |   +-- RestAPI.Customer.pas
|   |   +-- Customer.DTO.pas
|   |   +-- Customer.Repository.pas
|   |   +-- Customer.Service.pas
|   |   +-- Customer.Validator.pas
|   |
|   +-- products
|   |   +-- RestAPI.Product.pas
|   |   +-- Product.DTO.pas
|   |   +-- Product.Repository.pas
|   |   +-- Product.Service.pas
|   |   +-- Product.Validator.pas
|   |
|   +-- sample
|   |   +-- RestAPI.Sample.pas
|   |
|   +-- users
|       +-- RestAPI.User.pas
|       +-- User.DTO.pas
|       +-- User.Repository.pas
|       +-- User.Service.pas
|       +-- User.Validator.pas
|
+-- shared
    +-- helpers
        +-- BFA.Helper.Dataset.pas
        +-- BFA.Helper.Strings.pas
        +-- BFA.Helper.Transaction.pas
        +-- BFA.Helper.Validator.pas
```

## Folder Rules

- `sources/app` contains the WebBroker entry point and route dispatching.
- `sources/core` contains reusable REST abstractions, endpoint dispatching, request/response helpers, config, messages, and constants.
- `sources/infrastructure` contains database connection and security/token infrastructure.
- `sources/modules` contains business features. Each feature places controller, service, repository, validator, and DTO units directly inside the module folder.
- `sources/shared` contains reusable helper units used across modules.

## New Module Rule

When adding a new feature, use this pattern:

```text
sources/modules/<feature-name>
+-- RestAPI.<Feature>.pas
+-- <Feature>.Service.pas
+-- <Feature>.Repository.pas
+-- <Feature>.Validator.pas
+-- <Feature>.DTO.pas
```

Update these files when the new endpoint is public:

- `DelphiAPIStarterKit.dpr`
- `sources/app/App.WebModule.pas`
- `docs/api/<feature-name>.md`
- `docs/api/postman.collection.json`
- `README.md` when setup or public behavior changes

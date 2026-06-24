# Struktur Folder `sources`

Struktur saat ini berfokus pada WebBroker REST API starter kit. DataSnap sample server dan legacy method units sudah tidak menjadi bagian dari project publish.

## Struktur Saat Ini

```text
sources/
  app/
    App.WebModule.dfm
    App.WebModule.pas

  core/
    BFA.Core.Config.pas
    BFA.Core.Constants.pas
    BFA.Core.Endpoint.pas
    BFA.Core.Helper.pas
    BFA.Core.Messages.pas
    BFA.Core.Request.pas
    BFA.Core.Response.pas
    BFA.Core.Rest.pas

  infrastructure/
    database/
      DB.ConnectionFactory.pas
      DB.Helper.Query.pas
    security/
      BFA.Security.Token.pas

  modules/
    auth/
      RestAPI.Auth.pas
      Auth.DTO.pas
      Auth.Repository.pas
      Auth.Service.pas
      Auth.Validator.pas
    category/
      RestAPI.Category.pas
      Category.DTO.pas
      Category.Repository.pas
      Category.Service.pas
      Category.Validator.pas
    customers/
      RestAPI.Customer.pas
      Customer.DTO.pas
      Customer.Repository.pas
      Customer.Service.pas
      Customer.Validator.pas
    products/
      RestAPI.Product.pas
      Product.DTO.pas
      Product.Repository.pas
      Product.Service.pas
      Product.Validator.pas
    sample/
      RestAPI.Sample.pas
    users/
      RestAPI.User.pas
      User.DTO.pas
      User.Repository.pas
      User.Service.pas
      User.Validator.pas

  shared/
    helpers/
      BFA.Helper.Dataset.pas
      BFA.Helper.Strings.pas
      BFA.Helper.Transaction.pas
      BFA.Helper.Validator.pas
```

## Responsibility Map

- `sources/app`: WebBroker module, request dispatching, file/image route handling, and top-level routing.
- `sources/core`: common endpoint execution, REST abstractions, JSON request/response helpers, messages, config, and constants.
- `sources/infrastructure/database`: FireDAC connection factory and query helper.
- `sources/infrastructure/security`: access token extraction helper.
- `sources/modules/<feature>`: endpoint handler, DTO, validator, service, and repository for each feature.
- `sources/shared/helpers`: reusable dataset, string, transaction, and validation helpers.

## Pengembangan Endpoint Baru

Fitur bisnis baru dibuat di:

```text
sources/modules/<feature-name>/
```

Gunakan pola file berikut:

```text
RestAPI.<Feature>.pas
<Feature>.DTO.pas
<Feature>.Repository.pas
<Feature>.Service.pas
<Feature>.Validator.pas
```

Setelah unit dibuat, update:

- `DelphiAPIStarterKit.dpr`
- `sources/app/App.WebModule.pas`
- `docs/api/<feature-name>.md`
- `docs/api/postman.collection.json`
- `README.md` jika setup atau behavior publik berubah

## Catatan Publish

Runtime file seperti `config.ini`, `libmysql.dll`, executable, generated proxy, dan uploaded image tidak dipublish ke Git. Gunakan `config.example.ini` dan dokumentasi README untuk setup lokal.

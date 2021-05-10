# Macaroons (For Elixir)


![Elixir CI](https://github.com/doawoo/macaroon/workflows/Elixir%20CI/badge.svg?branch=main)
[![Coverage Status](https://coveralls.io/repos/github/doawoo/macaroon/badge.svg?branch=main)](https://coveralls.io/github/doawoo/macaroon?branch=main)
![MIT License](https://img.shields.io/badge/License-MIT-important)
![Hex.pm](https://img.shields.io/hexpm/v/macaroon)


Cookies but better. For Elixir.

Requires: libsodium (can usually be easily installed using your favorite package manager)

---

## Table of Contents

* [What Are They?](https://github.com/doawoo/macaroon#what-are-they)
  * [Basic Summary](https://github.com/doawoo/macaroon#basic-summary)
  * [Caveats](https://github.com/doawoo/macaroon#caveats)
  * [Verification](https://github.com/doawoo/macaroon#verification)
  * [Discharging](https://github.com/doawoo/macaroon#discharging)
* [Examples](https://github.com/doawoo/macaroon#examples)
  * [Create a Macaroon](https://github.com/doawoo/macaroon#creating-a-macaroon)
  * [Adding Caveats](https://github.com/doawoo/macaroon#adding-caveats)
  * [Verification](https://github.com/doawoo/macaroon#verification-1)
  * [Serialization and Deserialize](https://github.com/doawoo/macaroon#serialization-and-deserialize)
    * [JSON](https://github.com/doawoo/macaroon#json)
    * [Binary](https://github.com/doawoo/macaroon#binary)
* [Misc](https://github.com/doawoo/macaroon#misc)
  * [Building on Windows](https://github.com/doawoo/macaroon#building-on-windows)
---

If you'd like to know all the details about Macaroons, I encourage you to read the [research paper](https://research.google/pubs/pub41892/)!

I'll summarize it up a bit below:

## What are they?

### Basic Summary

Macaroons are bearer credentials, similar to cookies, API tokens, or JWTs. They're presented upon each of a client's request. Where Macaroons differ from most bearer credentials are the fact that they securely embed caveats (permissions, reasons, capabilities, etc.) inside the credential itself. These caveats are signed using a secret key, so the target service can trust the credential as it is presented along with the client's request. The target service can evaluate the request, and the caveats to see if the operation is allowed.

### Caveats

Caveats are simple statements that define what capabilities, identities, or authority the Macaroon holds.

Here's an example list of caveats a Macaroon may hold pertaining to an imaginary file sharing service:

```
1. user_id = 1234
2. user_upload_limit = 4MB
3. user_download_limit = 100MB
4. upload_namespace=/users/1234/*
5. timestamp <= 1/10/2021-5:48:47PM
```

With the examples above, the service should respect the requested operation should it meet the Macaroon's declared and signed caveats.

These caveats can contain any information in any string-based format. It's up to the service author to design the predicate language used.

### Verification

When operating a service, you can verify a Macaroon "exactly" or "generally". 

Exact verification means the data of the caveat must match byte-per-byte. 

General verification allows the service author to provide simple callbacks which receive the caveat and can return `true` or `false` to indicate if it is met.

### Discharging

TODO

## Examples

### Creating a Macaroon

```elixir
m = Macaroon.create_macaroon("http://my.cool.app", "public_id", "SUPER_SECRET_KEY_DO_NOT_SHARE")
```

### Adding Caveats

```elixir
m = Macaroon.create_macaroon("http://my.cool.app", "public_id", "SUPER_SECRET_KEY_DO_NOT_SHARE")
  |> Macaroon.add_first_party_caveat("upload_limit = 4MB")
  |> Macaroon.add_first_party_caveat("upload_namespace = /users/1234/*")
  |> Macaroon.add_third_party_caveat("https://auth.another.app", "identity_caveat", "SECRET_SHARED_KEY")
```

### Verification

```elixir
alias Macaroon.Verification

result = Verification.satisfy_exact("upload_limit = 4MB")
  |> Verification.satisfy_exact("upload_namespace = /users/1234/*")
  |> Verification.satisfy_exact("time < 2022-01-01T00:00")
  |> Verification.verify(macaroon, "SUPER_SECRET_KEY_DO_NOT_SHARE")

# result will be {:ok, macaroon} or {:error, reason_for_failure}
```

### Serialization and Deserialize

#### JSON

```elixir
{:ok, json_string} = Macaroon.create_macaroon("http://my.cool.app", "public_id", "SUPER_SECRET_KEY")
  |> Macaroon.serialize(:json)

macaroon = Macaroon.deserialize(json_string, :json)
```

#### Binary

```elixir
{:ok, url_base64_string} = Macaroon.create_macaroon("http://my.cool.app", "public_id", "SUPER_SECRET_KEY")
  |> Macaroon.serialize(:binary)

macaroon = Macaroon.deserialize(url_base64_string, :binary)
```

## Misc

### Building on Windows

(I really recommend using the Windows Linux Subsystem. It makes installing libsodium and most other things much easier. But if you must run this natively on Windows, follow these tips!)

1. Download the latest release of libsodium, compile it using Visual Studio's compiler using x86 ReleaseDLL config. 
2. Take note of the full path where the `.dll`, `.lib` are generated. Also note where the `include` directory is located.
3. Rename the generated `.lib` to `.dll.a`.

Then using a Developer Command Prompt navigate to your project:

1. `set lib=%lib%;<PATH_TO_FOLDER_THAT_CONTAINS_libsodium.dll.a>`
2. `set include=%include%;<PATH_TO_FOLDER_THAT_CONTAINS_sodium.h>`
3. `mix deps.get` and `mix deps.compile`

---

<p align="center">
  🍪 Baked with 🐾 by Digit (@doawoo) | https://puppy.surf
</p>
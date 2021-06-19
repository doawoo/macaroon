# Macaroons (For Elixir)


![Elixir CI](https://github.com/doawoo/macaroon/workflows/Elixir%20CI/badge.svg?branch=main)
[![Coverage Status](https://coveralls.io/repos/github/doawoo/macaroon/badge.svg?branch=main)](https://coveralls.io/github/doawoo/macaroon?branch=main)
![MIT License](https://img.shields.io/badge/License-MIT-important)
![Hex.pm](https://img.shields.io/hexpm/v/macaroon)


Cookies but better. For Elixir.

**Fully Functional But Probably Needs More Testing :)**

Requires: libsodium (can usually be easily installed using your favorite package manager)

---

## Table of Contents

* [What Are They?](https://github.com/doawoo/macaroon#what-are-they)
  * [Basic Summary](https://github.com/doawoo/macaroon#basic-summary)
  * [Caveats](https://github.com/doawoo/macaroon#caveats)
  * [Verification](https://github.com/doawoo/macaroon#verification)
  * [Discharging](https://github.com/doawoo/macaroon#discharging)
    * [Well-Known RSA public key](https://github.com/doawoo/macaroon#well-known-rsa-public-key)
    * [Round Trip](https://github.com/doawoo/macaroon#round-trip)
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

When you want to have a third-party validate a caveat, you must have them issue you a "discharge" Macaroon that can prove that specific caveat.
There are 2 well know ways to do this:

#### Well-Known RSA public key

(this is my favorite method of third-party proof!)

1. Establish a relationship between the two servers (in this case a public/private RSA key pair)
2. Encrypt your third-party predicate using the `add_rsa_third_party_caveat/5` function
3. Send this Macaroon to the client -- which will read the location and send the caveat id to the third-party server
4. The third-party server will use the `decrypt_rsa_third_party_caveat/3` function to take apart the cipher text into the predicate and the root key
5. The third-party server will create a discharge Macaroon using the root key extracted from the cipher text in step 4 -- bind it to the original Macaroon
6. Client will receive the new discharge Macaroon, and send that AND the original Macaroon back to the first-party service for verification

#### Round Trip

1. Generate a nonce, then make some form of remote call out to the third-party service informing it of that random nonce
2. The third-party service should return a unique ID, use this unique ID as the caveat ID in the third-party caveat. associate the unique ID with the random nonce that was generated
3. Send this Macaroon to the client -- which will read the location and send the caveat id to the third-party server
4. The third-party server will use the nonce to look up what needs to be verified
5. The third-party server will create a discharge Macaroon using the nonce you sent it as the root key -- bind it to the original Macaroon
6. Client will receive the new discharge Macaroon, and send that AND the original Macaroon back to the first-party service for verification

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
  |> Macaroon.add_third_party_caveat("https://auth.another.app", "PREDICATE_HOPEFULLY_ENCRYPTED", "RANDOM_SECRET_NONCE_KEY")
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

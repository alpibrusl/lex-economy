import "std.crypto" as crypto

import "std.bytes" as bytes

import "std.str" as str

type KeyPair = { secret :: Bytes, public :: Bytes }

type CompanyId = { id :: Str, public_key_b64 :: Str }

type CompanyStatus = Incorporated | Active | Restructuring | Liquidated

type Company = { id :: CompanyId, name :: Str, mission :: Str, status :: CompanyStatus }

fn generate_key() -> [random] Result[KeyPair, Str] {
  let sec := crypto.random(32)
  match crypto.ed25519_public_key(sec) {
    Ok(pub) => Ok({ secret: sec, public: pub }),
    Err(e) => Err(e),
  }
}

fn incorporate(name :: Str, mission :: Str, key :: KeyPair) -> Result[Company, Str]
  examples {
    incorporate("Acme", "Widgets", stub_key("0000000000000000000000000000000000000000000000000000000000000000", "3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29")) => Ok({ id: { id: "139e3940e64b5491722088d9a0d741628fc826e09475d341a780acde3c4b8070", public_key_b64: "O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik=" }, name: "Acme", mission: "Widgets", status: Incorporated })
  }
{
  let id := crypto.hex_encode(crypto.sha256(key.public))
  let public_key_b64 := crypto.base64_encode(key.public)
  let company_id := { id: id, public_key_b64: public_key_b64 }
  Ok({ id: company_id, name: name, mission: mission, status: Incorporated })
}

fn sign(key :: KeyPair, payload :: Str) -> Result[Str, Str]
  examples {
    sign(stub_key("0000000000000000000000000000000000000000000000000000000000000000", "3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29"), "hello") => Ok("e25c8723d039fe8f45d6c9d6a8917fa91bc754913cd596fd358a493a21a3cb590a6537babc7df0400ab61a05589c9c36b65a143878cb0341d4e9e48419c4370d")
  }
{
  match crypto.ed25519_sign(key.secret, bytes.from_str(payload)) {
    Ok(sig) => Ok(crypto.hex_encode(sig)),
    Err(e) => Err(e),
  }
}

fn verify_signature(id :: CompanyId, payload :: Str, sig :: Str) -> Bool
  examples {
    verify_signature({ id: "x", public_key_b64: "!!!" }, "payload", "00") => false,
    verify_signature({ id: "x", public_key_b64: "O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik=" }, "payload", "zz") => false,
    verify_signature({ id: "x", public_key_b64: "O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik=" }, "hello", "e25c8723d039fe8f45d6c9d6a8917fa91bc754913cd596fd358a493a21a3cb590a6537babc7df0400ab61a05589c9c36b65a143878cb0341d4e9e48419c4370d") => true
  }
{
  match crypto.base64_decode(id.public_key_b64) {
    Ok(pub) => match crypto.hex_decode(sig) {
      Ok(decoded_sig) => crypto.ed25519_verify(pub, bytes.from_str(payload), decoded_sig),
      Err(_) => false,
    },
    Err(_) => false,
  }
}

fn stub_key(secret_hex :: Str, public_hex :: Str) -> KeyPair
  examples {
    stub_key("0000000000000000000000000000000000000000000000000000000000000000", "3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29") => { secret: hex("0000000000000000000000000000000000000000000000000000000000000000"), public: hex("3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29") }
  }
{
  let secret := match crypto.hex_decode(secret_hex) {
    Ok(b) => b,
    Err(_) => bytes.from_str(""),
  }
  let public := match crypto.hex_decode(public_hex) {
    Ok(b) => b,
    Err(_) => bytes.from_str(""),
  }
  { secret: secret, public: public }
}

fn hex(h :: Str) -> Bytes
  examples {
    hex("00") => match crypto.hex_decode("00") {
      Ok(b) => b,
      Err(_) => bytes.from_str(""),
    }
  }
{
  match crypto.hex_decode(h) {
    Ok(b) => b,
    Err(_) => bytes.from_str(""),
  }
}

fn demo_deterministic_ids() -> [random] Bool {
  match generate_key() {
    Ok(k1) => match generate_key() {
      Ok(k2) => {
        let c1 := incorporate("Acme", "Widgets", k1)
        let c2 := incorporate("Beta", "Gadgets", k2)
        let c1_again := incorporate("Acme", "Widgets", k1)
        match c1 {
          Ok(comp1) => match c2 {
            Ok(comp2) => match c1_again {
              Ok(comp1_again) => {
                let ids_differ := comp1.id.id != comp2.id.id
                let same_key_same_id := comp1.id.id == comp1_again.id.id
                ids_differ and same_key_same_id
              },
              Err(_) => false,
            },
            Err(_) => false,
          },
          Err(_) => false,
        }
      },
      Err(_) => false,
    },
    Err(_) => false,
  }
}


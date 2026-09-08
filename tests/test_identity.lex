import "../src/identity" as identity

fn test_incorporate_id() -> Bool
  examples {
    test_incorporate_id() => true
  }
{
  let key := identity.stub_key("0000000000000000000000000000000000000000000000000000000000000000", "3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29")
  match identity.incorporate("Acme", "Widgets", key) {
    Ok(company) => company.id.id == "139e3940e64b5491722088d9a0d741628fc826e09475d341a780acde3c4b8070" and company.id.public_key_b64 == "O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik=" and company.status == identity.Incorporated,
    Err(_) => false,
  }
}

fn test_incorporate_content() -> Bool
  examples {
    test_incorporate_content() => true
  }
{
  let key := identity.stub_key("0000000000000000000000000000000000000000000000000000000000000000", "3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29")
  match identity.incorporate("Acme", "Widgets", key) {
    Ok(company) => company.name == "Acme" and company.mission == "Widgets",
    Err(_) => false,
  }
}

fn test_sign_known_signature() -> Bool
  examples {
    test_sign_known_signature() => true
  }
{
  let key := identity.stub_key("0000000000000000000000000000000000000000000000000000000000000000", "3b6a27bcceb6a42d62a3a8d02a6f0d73653215771de243a63ac048a18b59da29")
  match identity.sign(key, "hello") {
    Ok(sig) => sig == "e25c8723d039fe8f45d6c9d6a8917fa91bc754913cd596fd358a493a21a3cb590a6537babc7df0400ab61a05589c9c36b65a143878cb0341d4e9e48419c4370d",
    Err(_) => false,
  }
}

fn test_verify_signature_valid() -> Bool
  examples {
    test_verify_signature_valid() => true
  }
{
  let id := { id: "x", public_key_b64: "O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik=" }
  identity.verify_signature(id, "hello", "e25c8723d039fe8f45d6c9d6a8917fa91bc754913cd596fd358a493a21a3cb590a6537babc7df0400ab61a05589c9c36b65a143878cb0341d4e9e48419c4370d")
}

fn test_verify_signature_wrong_payload() -> Bool
  examples {
    test_verify_signature_wrong_payload() => true
  }
{
  let id := { id: "x", public_key_b64: "O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik=" }
  identity.verify_signature(id, "world", "e25c8723d039fe8f45d6c9d6a8917fa91bc754913cd596fd358a493a21a3cb590a6537babc7df0400ab61a05589c9c36b65a143878cb0341d4e9e48419c4370d") == false
}

fn test_verify_signature_bad_public_key_b64() -> Bool
  examples {
    test_verify_signature_bad_public_key_b64() => true
  }
{
  let id := { id: "x", public_key_b64: "!!!" }
  identity.verify_signature(id, "payload", "00") == false
}

fn test_verify_signature_bad_sig_hex() -> Bool
  examples {
    test_verify_signature_bad_sig_hex() => true
  }
{
  let id := { id: "x", public_key_b64: "O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik=" }
  identity.verify_signature(id, "payload", "zz") == false
}

fn test_verify_signature_empty_sig() -> Bool
  examples {
    test_verify_signature_empty_sig() => true
  }
{
  let id := { id: "x", public_key_b64: "O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik=" }
  identity.verify_signature(id, "payload", "") == false
}

fn test_sign_malformed_key() -> Bool
  examples {
    test_sign_malformed_key() => true
  }
{
  let key := identity.stub_key("00", "00")
  match identity.sign(key, "payload") {
    Ok(_) => false,
    Err(_) => true,
  }
}

fn test_deterministic_same_key() -> Bool
  examples {
    test_deterministic_same_key() => true
  }
{
  let key := identity.stub_key("0000000000000000000000000000000000000000000000000000000000000001", "d6c2476e499fd5f97d95cca9e4c99085d7f4886c08bc0128c663a89d3298b53c")
  match identity.incorporate("A", "B", key) {
    Ok(c1) => match identity.incorporate("A", "B", key) {
      Ok(c2) => c1.id.id == c2.id.id,
      Err(_) => false,
    },
    Err(_) => false,
  }
}

fn test_distinct_keys_different_ids() -> Bool
  examples {
    test_distinct_keys_different_ids() => true
  }
{
  let key1 := identity.stub_key("0000000000000000000000000000000000000000000000000000000000000001", "d6c2476e499fd5f97d95cca9e4c99085d7f4886c08bc0128c663a89d3298b53c")
  let key2 := identity.stub_key("0000000000000000000000000000000000000000000000000000000000000002", "6c53f3bf0a45b0c6a2c5c246a7c7f8b2e3e1b6d4c5a7f8e9d0c1b2a3f4e5d607")
  match identity.incorporate("A", "B", key1) {
    Ok(c1) => match identity.incorporate("C", "D", key2) {
      Ok(c2) => c1.id.id != c2.id.id,
      Err(_) => false,
    },
    Err(_) => false,
  }
}

fn run_all() -> Bool {
  test_incorporate_id() and test_incorporate_content() and test_sign_known_signature() and test_verify_signature_valid() and test_verify_signature_wrong_payload() and test_verify_signature_bad_public_key_b64() and test_verify_signature_bad_sig_hex() and test_verify_signature_empty_sig() and test_sign_malformed_key() and test_deterministic_same_key() and test_distinct_keys_different_ids()
}


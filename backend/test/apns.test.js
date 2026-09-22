import assert from "node:assert/strict";
import test from "node:test";
import { base64URLToBytes, buildAPNsJWT, resetAPNsCache } from "../src/apns.js";

test("APNs JWT is a verifiable ES256 token", async () => {
  resetAPNsCache();
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of pkcs8) binary += String.fromCharCode(byte);
  const wrapped = btoa(binary).match(/.{1,64}/g).join("\\n");
  const pem = `-----BEGIN PRIVATE KEY-----\\n${wrapped}\\n-----END PRIVATE KEY-----`;
  const jwt = await buildAPNsJWT({
    teamId: "TEAMID1234",
    keyId: "KEYID12345",
    privateKeyPem: pem,
    nowSeconds: 1_700_000_000,
  });
  const [headerPart, claimsPart, signaturePart] = jwt.split(".");
  const header = JSON.parse(new TextDecoder().decode(base64URLToBytes(headerPart)));
  const claims = JSON.parse(new TextDecoder().decode(base64URLToBytes(claimsPart)));
  assert.equal(header.alg, "ES256");
  assert.equal(header.kid, "KEYID12345");
  assert.equal(claims.iss, "TEAMID1234");
  assert.equal(claims.iat, 1_700_000_000);
  const verified = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    pair.publicKey,
    base64URLToBytes(signaturePart),
    new TextEncoder().encode(`${headerPart}.${claimsPart}`),
  );
  assert.equal(verified, true);
});

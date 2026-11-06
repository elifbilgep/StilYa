// StilYa R2 Worker — Secure Version
// JWT signature verification (RS256) + User isolation + Pagination

import { PRIVACY_POLICY_HTML } from './templates/privacy.js';
import { TERMS_OF_USE_HTML } from './templates/terms.js';
import { LANDING_PAGE_HTML } from './templates/landing.js';
import { ADMIN_PANEL_HTML } from './templates/admin.js';

// Debug mode: wrangler.jsonc vars'dan okunur — deploy gerekmeden ortam değişir
// Prod: IS_DEBUG="false", Dev: IS_DEBUG="true"
let IS_DEBUG = false;

// ============================================================
// Apple DeviceCheck API
// ============================================================

async function createDeviceCheckJWT(env) {
  const header = { alg: "ES256", kid: env.DEVICECHECK_KEY_ID };
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: env.APPLE_TEAM_ID, iat: now };

  const enc = new TextEncoder();
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const signingInput = `${headerB64}.${payloadB64}`;

  // Import P8 private key (PEM → PKCS8 DER)
  const pemBody = env.DEVICECHECK_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8", keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false, ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key, enc.encode(signingInput)
  );

  // Convert DER signature to raw r||s (64 bytes) for ES256
  const sigBytes = new Uint8Array(signature);
  let r, s;
  if (sigBytes[0] === 0x30) {
    // DER encoded
    let offset = 2;
    const rLen = sigBytes[offset + 1];
    r = sigBytes.slice(offset + 2, offset + 2 + rLen);
    offset = offset + 2 + rLen;
    const sLen = sigBytes[offset + 1];
    s = sigBytes.slice(offset + 2, offset + 2 + sLen);
    // Trim leading zeros, pad to 32 bytes
    if (r.length > 32) r = r.slice(r.length - 32);
    if (s.length > 32) s = s.slice(s.length - 32);
    const raw = new Uint8Array(64);
    raw.set(r, 32 - r.length);
    raw.set(s, 64 - s.length);
    const sigB64 = btoa(String.fromCharCode(...raw)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    return `${signingInput}.${sigB64}`;
  } else {
    // Already raw
    const sigB64 = btoa(String.fromCharCode(...sigBytes)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    return `${signingInput}.${sigB64}`;
  }
}

/**
 * Query Apple DeviceCheck for 2 bits.
 * bit0 = free credits already claimed on this device
 * bit1 = reserved
 * Returns { bit0: bool, bit1: bool } or null on error
 */
async function queryDeviceCheck(env, deviceToken) {
  try {
    const jwt = await createDeviceCheckJWT(env);
    const response = await fetch("https://api.devicecheck.apple.com/v1/query_two_bits", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${jwt}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        device_token: deviceToken,
        transaction_id: crypto.randomUUID(),
        timestamp: Date.now(),
      }),
    });

    if (response.status === 200) {
      const data = await response.json();
      return { bit0: data.bit0, bit1: data.bit1 };
    }

    // 200 = bits found, other = first time (no bits set yet)
    return null;
  } catch (e) {
    console.error("queryDeviceCheck error:", e);
    return null;
  }
}

/**
 * Update Apple DeviceCheck bits.
 * bit0 = free credits already claimed
 */
async function updateDeviceCheck(env, deviceToken, bit0, bit1) {
  try {
    const jwt = await createDeviceCheckJWT(env);
    const response = await fetch("https://api.devicecheck.apple.com/v1/update_two_bits", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${jwt}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        device_token: deviceToken,
        transaction_id: crypto.randomUUID(),
        timestamp: Date.now(),
        bit0,
        bit1,
      }),
    });

    return response.status === 200;
  } catch (e) {
    console.error("updateDeviceCheck error:", e);
    return false;
  }
}

// ============================================================
// Firebase Public Keys Cache
// ============================================================

const FIREBASE_CERTS_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

const RS256_ALGORITHM = {
  name: "RSASSA-PKCS1-v1_5",
  hash: { name: "SHA-256" },
};

let cachedKeys = null; // { keys: Record<string, CryptoKey>, expiresAt: number }

// ============================================================
// Base64 Helpers
// ============================================================

function base64urlDecode(input) {
  let base64 = input.replace(/-/g, "+").replace(/_/g, "/");
  while (base64.length % 4 !== 0) {
    base64 += "=";
  }
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

function base64Decode(input) {
  const binaryString = atob(input);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

// ============================================================
// ASN.1 DER Parser — Extract SPKI from X.509 Certificate
// ============================================================

function extractSPKIFromCertificate(certDer) {
  function parseTLV(data, pos) {
    const tag = data[pos];
    pos++;
    let length = 0;
    if (data[pos] < 0x80) {
      length = data[pos];
      pos++;
    } else {
      const numBytes = data[pos] & 0x7f;
      pos++;
      for (let i = 0; i < numBytes; i++) {
        length = (length << 8) | data[pos];
        pos++;
      }
    }
    return { tag, length, contentOffset: pos };
  }

  function skipTLV(data, pos) {
    const { length, contentOffset } = parseTLV(data, pos);
    return contentOffset + length;
  }

  let offset = 0;

  // Outer SEQUENCE (certificate)
  const cert = parseTLV(certDer, offset);
  offset = cert.contentOffset;

  // TBSCertificate SEQUENCE
  const tbs = parseTLV(certDer, offset);
  offset = tbs.contentOffset;

  // Field 0: version — context-specific tag [0] (0xA0)
  if (certDer[offset] === 0xa0) {
    offset = skipTLV(certDer, offset);
  }

  // Field 1: serialNumber
  offset = skipTLV(certDer, offset);
  // Field 2: signature algorithm
  offset = skipTLV(certDer, offset);
  // Field 3: issuer
  offset = skipTLV(certDer, offset);
  // Field 4: validity
  offset = skipTLV(certDer, offset);
  // Field 5: subject
  offset = skipTLV(certDer, offset);

  // Field 6: subjectPublicKeyInfo — this is what we need
  const spki = parseTLV(certDer, offset);
  const spkiEnd = spki.contentOffset + spki.length;

  return certDer.slice(offset, spkiEnd).buffer;
}

// ============================================================
// PEM Certificate → CryptoKey
// ============================================================

async function pemToCryptoKey(pem) {
  const pemBody = pem
    .replace(/-----BEGIN CERTIFICATE-----/g, "")
    .replace(/-----END CERTIFICATE-----/g, "")
    .replace(/\s/g, "");

  const certDer = base64Decode(pemBody);
  const spki = extractSPKIFromCertificate(certDer);

  return crypto.subtle.importKey("spki", spki, RS256_ALGORITHM, false, ["verify"]);
}

// ============================================================
// Fetch & Cache Firebase Public Keys
// ============================================================

async function getFirebasePublicKeys() {
  const now = Date.now();

  if (cachedKeys && now < cachedKeys.expiresAt) {
    return cachedKeys.keys;
  }

  const response = await fetch(FIREBASE_CERTS_URL);
  if (!response.ok) {
    throw new Error(`Failed to fetch Firebase public keys: ${response.status}`);
  }

  const cacheControl = response.headers.get("Cache-Control") || "";
  const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
  const maxAge = maxAgeMatch ? parseInt(maxAgeMatch[1], 10) : 3600;

  const certsJson = await response.json();
  const keys = {};

  for (const [kid, pem] of Object.entries(certsJson)) {
    keys[kid] = await pemToCryptoKey(pem);
  }

  cachedKeys = { keys, expiresAt: now + maxAge * 1000 };
  return keys;
}

// ============================================================
// Verify Firebase JWT (RS256 Signature + Claims)
// ============================================================

async function verifyFirebaseToken(token, projectId) {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid JWT format");
  }

  // Decode header & payload
  const header = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[1])));
  const signatureBytes = base64urlDecode(parts[2]);
  const signedContent = `${parts[0]}.${parts[1]}`;

  // Validate algorithm
  if (header.alg !== "RS256") {
    throw new Error(`Unexpected algorithm: ${header.alg}`);
  }
  if (!header.kid) {
    throw new Error("Missing kid in JWT header");
  }

  // Get public keys and find matching key
  let keys = await getFirebasePublicKeys();
  let publicKey = keys[header.kid];

  // If key not found, force refresh (key rotation)
  if (!publicKey) {
    cachedKeys = null;
    keys = await getFirebasePublicKeys();
    publicKey = keys[header.kid];
    if (!publicKey) {
      throw new Error(`No matching public key for kid: ${header.kid}`);
    }
  }

  // Verify RS256 signature
  const encoder = new TextEncoder();
  const data = encoder.encode(signedContent);
  const isValid = await crypto.subtle.verify(RS256_ALGORITHM.name, publicKey, signatureBytes, data);

  if (!isValid) {
    throw new Error("Invalid JWT signature");
  }

  // Validate claims
  const now = Math.floor(Date.now() / 1000);

  if (payload.exp <= now) {
    throw new Error("Token expired");
  }

  if (payload.iat > now + 60) {
    throw new Error("Token issued in the future");
  }

  const expectedIssuer = `https://securetoken.google.com/${projectId}`;
  if (payload.iss !== expectedIssuer) {
    throw new Error("Invalid token issuer");
  }

  if (payload.aud !== projectId) {
    throw new Error("Invalid token audience");
  }

  if (!payload.sub || typeof payload.sub !== "string") {
    throw new Error("Missing user ID in token");
  }

  return { sub: payload.sub, uid: payload.user_id || payload.sub };
}

// ============================================================
// Firebase App Check Verification (JWKS)
// ============================================================

const APP_CHECK_JWKS_URL = "https://firebaseappcheck.googleapis.com/v1beta/jwks";
// Set from env.FIREBASE_PROJECT_NUMBER at request time (Firebase console → Project settings)
let FIREBASE_PROJECT_NUMBER = "";

// Enforcement flag — ENABLED: reject requests without valid App Check token
const ENFORCE_APP_CHECK = false;

let cachedAppCheckKeys = null; // { keys: Record<string, CryptoKey>, expiresAt: number }

async function getAppCheckPublicKeys() {
  const now = Date.now();

  if (cachedAppCheckKeys && now < cachedAppCheckKeys.expiresAt) {
    return cachedAppCheckKeys.keys;
  }

  const response = await fetch(APP_CHECK_JWKS_URL);
  if (!response.ok) {
    throw new Error(`Failed to fetch App Check JWKS: ${response.status}`);
  }

  const jwks = await response.json();
  const keys = {};

  for (const jwk of jwks.keys) {
    if (jwk.kty === "RSA" && jwk.use === "sig" && jwk.kid) {
      const cryptoKey = await crypto.subtle.importKey(
        "jwk",
        { kty: jwk.kty, n: jwk.n, e: jwk.e },
        RS256_ALGORITHM,
        false,
        ["verify"]
      );
      keys[jwk.kid] = cryptoKey;
    }
  }

  // Cache for 1 hour
  cachedAppCheckKeys = { keys, expiresAt: now + 3600 * 1000 };
  return keys;
}

async function verifyAppCheckToken(token, projectNumber) {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid App Check JWT format");
  }

  const header = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[1])));
  const signatureBytes = base64urlDecode(parts[2]);
  const signedContent = `${parts[0]}.${parts[1]}`;

  if (header.alg !== "RS256") {
    throw new Error(`Unexpected App Check algorithm: ${header.alg}`);
  }
  if (!header.kid) {
    throw new Error("Missing kid in App Check JWT header");
  }

  // Get public keys
  let keys = await getAppCheckPublicKeys();
  let publicKey = keys[header.kid];

  // Force refresh if key not found (key rotation)
  if (!publicKey) {
    cachedAppCheckKeys = null;
    keys = await getAppCheckPublicKeys();
    publicKey = keys[header.kid];
    if (!publicKey) {
      throw new Error(`No matching App Check key for kid: ${header.kid}`);
    }
  }

  // Verify signature
  const encoder = new TextEncoder();
  const data = encoder.encode(signedContent);
  const isValid = await crypto.subtle.verify(RS256_ALGORITHM.name, publicKey, signatureBytes, data);

  if (!isValid) {
    throw new Error("Invalid App Check JWT signature");
  }

  // Validate claims
  const now = Math.floor(Date.now() / 1000);

  if (payload.exp <= now) {
    throw new Error("App Check token expired");
  }

  // Issuer: "https://firebaseappcheck.googleapis.com/{projectNumber}"
  const expectedIssuer = `https://firebaseappcheck.googleapis.com/${projectNumber}`;
  if (payload.iss !== expectedIssuer) {
    throw new Error(`Invalid App Check issuer: ${payload.iss}`);
  }

  // Audience: "projects/{projectNumber}"
  const expectedAudience = `projects/${projectNumber}`;
  const audiences = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!audiences.includes(expectedAudience)) {
    throw new Error(`Invalid App Check audience: ${payload.aud}`);
  }

  return { sub: payload.sub, app: payload.app_id || payload.sub };
}

/**
 * App Check middleware — returns null if OK, or a Response if blocked.
 * In soft mode (ENFORCE_APP_CHECK = false), always returns null but logs warnings.
 */
async function verifyAppCheck(request) {
  const appCheckHeader = request.headers.get("X-Firebase-AppCheck");

  if (!appCheckHeader) {
    if (ENFORCE_APP_CHECK) {
      console.warn("[app-check] BLOCKED: Missing App Check header");
      return new Response(
        JSON.stringify({ error: "App Check token required" }),
        { status: 403, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }
    return null;
  }

  try {
    if (!FIREBASE_PROJECT_NUMBER) return null; // App Check not configured
    await verifyAppCheckToken(appCheckHeader, FIREBASE_PROJECT_NUMBER);
    return null; // Valid — proceed
  } catch (error) {
    if (ENFORCE_APP_CHECK) {
      console.warn(`[app-check] BLOCKED: ${error.message}`);
      return new Response(
        JSON.stringify({ error: "Invalid App Check token" }),
        { status: 403, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }
    return null;
  }
}

// ============================================================
// Path Validation
// ============================================================

function validatePath(path, userId) {
  return path.startsWith(`users/${userId}/`);
}

// ============================================================
// CORS Headers (restricted origin)
// ============================================================

const ALLOWED_ORIGINS = [
  "https://stilya.app",
  "https://www.stilya.app",
];

function corsHeaders(request) {
  const origin = request.headers.get("Origin") || "";

  // iOS uygulaması Origin header göndermez — izin ver
  // Web istekleri için origin kontrolü yap
  const allowedOrigin = !origin || ALLOWED_ORIGINS.includes(origin) ? origin || "*" : null;

  if (!allowedOrigin) {
    return {
      "Access-Control-Allow-Origin": ALLOWED_ORIGINS[0],
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Authorization, Content-Type, X-Firebase-AppCheck",
      "Access-Control-Expose-Headers": "X-Credits-Remaining, X-Model-Gen-Remaining",
    };
  }

  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type, X-Firebase-AppCheck",
    "Access-Control-Expose-Headers": "X-Credits-Remaining, X-Model-Gen-Remaining",
  };
}

// ============================================================
// Ban System (KV-backed persistent bans)
// ============================================================

const bannedIPs = new Set();    // Kalıcı ban (KV'den)
const bannedUsers = new Set();  // Kalıcı ban (KV'den)

// Request'ten IP ve ülke bilgisi al (Cloudflare otomatik sağlar)
function getClientInfo(request) {
  return {
    ip: request.headers.get("CF-Connecting-IP") || "unknown",
    country: request.headers.get("CF-IPCountry") || "??",
  };
}

// Ban kontrolü — auth'dan ÖNCE çalışır
function isBanned(ip, userId) {
  if (bannedIPs.has(ip)) return "IP kalıcı banlı";
  if (userId && bannedUsers.has(userId)) return "User kalıcı banlı";
  return null;
}

// KV'den ban listesini yükle (worker başlarken)
async function loadBanLists(env) {
  if (!env.STILYA_KV) return;

  try {
    const ips = await env.STILYA_KV.get("banned_ips", "json");
    if (Array.isArray(ips)) {
      bannedIPs.clear();
      ips.forEach(ip => bannedIPs.add(ip));
    }

    const users = await env.STILYA_KV.get("banned_users", "json");
    if (Array.isArray(users)) {
      bannedUsers.clear();
      users.forEach(uid => bannedUsers.add(uid));
    }
  } catch (err) {
    console.error(`[ban] KV yükleme hatası: ${err.message}`);
  }
}

// ============================================================
// Google Cloud Service Account Auth (JWT → Access Token)
// ============================================================

let cachedAccessToken = null; // { token: string, expiresAt: number }

/**
 * PEM private key → CryptoKey (RS256 signing)
 */
async function importServiceAccountKey(pemKey) {
  const pemBody = pemKey
    .replace(/-----BEGIN (RSA )?PRIVATE KEY-----/g, "")
    .replace(/-----END (RSA )?PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  const keyData = base64Decode(pemBody);

  return crypto.subtle.importKey(
    "pkcs8",
    keyData.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: { name: "SHA-256" } },
    false,
    ["sign"]
  );
}

/**
 * Base64url encode (no padding)
 */
function base64urlEncode(data) {
  const bytes = data instanceof Uint8Array ? data : new TextEncoder().encode(data);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * Create signed JWT for Google OAuth2
 */
async function createServiceAccountJWT(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/datastore",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const headerB64 = base64urlEncode(JSON.stringify(header));
  const payloadB64 = base64urlEncode(JSON.stringify(payload));
  const signingInput = `${headerB64}.${payloadB64}`;

  const cryptoKey = await importServiceAccountKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const signatureB64 = base64urlEncode(new Uint8Array(signature));
  return `${signingInput}.${signatureB64}`;
}

/**
 * Get cached access token or refresh via Google OAuth2
 */
async function getFirestoreAccessToken(env) {
  const now = Date.now();
  if (cachedAccessToken && now < cachedAccessToken.expiresAt) {
    return cachedAccessToken.token;
  }

  const serviceAccount = JSON.parse(env.GOOGLE_SERVICE_ACCOUNT_JSON);
  const jwt = await createServiceAccountJWT(serviceAccount);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Google OAuth2 token failed: ${response.status} ${errText}`);
  }

  const data = await response.json();
  cachedAccessToken = {
    token: data.access_token,
    expiresAt: now + (data.expires_in - 60) * 1000, // Refresh 1 min early
  };
  return cachedAccessToken.token;
}

// ============================================================
// Firestore REST API Helpers
// ============================================================

// Set from env.FIREBASE_PROJECT_ID at request time
let FIRESTORE_PROJECT_ID = "stilya";

function firestoreDocURL(path) {
  return `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents/${path}`;
}

/**
 * Read a Firestore document
 */
async function firestoreGet(token, docPath) {
  const response = await fetch(firestoreDocURL(docPath), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Firestore GET ${docPath} failed: ${response.status} ${errText}`);
  }
  const doc = await response.json();
  return fromFirestoreDoc(doc);
}

/**
 * Begin a Firestore transaction
 */
async function firestoreBeginTransaction(token) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents:beginTransaction`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({}),
    }
  );
  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Firestore beginTransaction failed: ${response.status} ${errText}`);
  }
  const data = await response.json();
  return data.transaction;
}

/**
 * Commit a Firestore transaction with writes
 */
async function firestoreCommit(token, transactionId, writes) {
  const commitBody = { writes };
  if (transactionId) {
    commitBody.transaction = transactionId;
  }
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(commitBody),
    }
  );
  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Firestore commit failed: ${response.status} ${errText}`);
  }
  return await response.json();
}

/**
 * Read a document within a transaction
 */
async function firestoreGetInTransaction(token, docPath, transactionId) {
  const response = await fetch(firestoreDocURL(docPath) + `?transaction=${encodeURIComponent(transactionId)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Firestore GET (tx) ${docPath} failed: ${response.status} ${errText}`);
  }
  const doc = await response.json();
  return { data: fromFirestoreDoc(doc), name: doc.name };
}

/**
 * Convert JS value → Firestore Value
 */
function toFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  if (typeof value === "string") return { stringValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === "object") {
    const fields = {};
    for (const [k, v] of Object.entries(value)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

/**
 * Convert Firestore Value → JS value
 */
function fromFirestoreValue(fv) {
  if ("nullValue" in fv) return null;
  if ("booleanValue" in fv) return fv.booleanValue;
  if ("integerValue" in fv) return parseInt(fv.integerValue, 10);
  if ("doubleValue" in fv) return fv.doubleValue;
  if ("stringValue" in fv) return fv.stringValue;
  if ("timestampValue" in fv) return new Date(fv.timestampValue);
  if ("arrayValue" in fv) return (fv.arrayValue.values || []).map(fromFirestoreValue);
  if ("mapValue" in fv) {
    const obj = {};
    for (const [k, v] of Object.entries(fv.mapValue.fields || {})) {
      obj[k] = fromFirestoreValue(v);
    }
    return obj;
  }
  return null;
}

/**
 * Convert Firestore document → JS object
 */
function fromFirestoreDoc(doc) {
  if (!doc || !doc.fields) return null;
  const obj = {};
  for (const [key, value] of Object.entries(doc.fields)) {
    obj[key] = fromFirestoreValue(value);
  }
  return obj;
}

/**
 * Build an update write operation
 */
function buildUpdateWrite(docPath, fields) {
  const firestoreFields = {};
  const fieldPaths = [];
  for (const [key, value] of Object.entries(fields)) {
    firestoreFields[key] = toFirestoreValue(value);
    fieldPaths.push(key);
  }
  return {
    update: {
      name: `projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents/${docPath}`,
      fields: firestoreFields,
    },
    updateMask: { fieldPaths },
  };
}

// ============================================================
// Credit Logic (ported from UserRepository.swift)
// ============================================================

let CREDIT_CONSTANTS = {
  // Pay-to-use: no recurring free credits. New users get a one-time `trialCredits`
  // grant at signup (set client-side at account creation); the weekly reset then
  // grants `freeWeeklyCredits` (0), so free usage does not renew.
  freeWeeklyCredits: 0,
  trialCredits: 1, // one-time grant for a brand-new account (client-applied at creation)
  singleTryOnCost: 1,
  comboBaseCost: 1,
  proWeeklyCredits: 50,
  proMonthlyCredits: 50,
  maxDailyRewardedAds: 1,
  // Free (onboarding) model-photo generation is not charged credits, so it is
  // metered separately here. Only SUCCESSFUL generations count.
  freeModelPhotoLimit: 2, // lifetime free model-photo generations for non-Pro users
  proModelPhotoWeekly: 3, // per-week free model-photo generations for Pro users
};

// Default rate limit (per user, per hour)
let RATE_LIMIT_PER_HOUR = 15;

/**
 * Track credit usage stats in KV (fire-and-forget, non-blocking).
 * Keys:
 *   stats:weekly:{YYYY-WW}        → total credits used this week
 *   stats:weekly:{YYYY-WW}:users  → JSON set of active user IDs this week
 *   stats:daily:{YYYY-MM-DD}      → total credits used today
 *   stats:user:{userId}:{YYYY-WW} → credits used by this user this week
 */
async function trackCreditUsage(env, userId, amount) {
  if (!env.STILYA_KV) return;
  try {
    const now = new Date();
    const weekNum = getISOWeek(now);
    const weekKey = `${now.getFullYear()}-W${String(weekNum).padStart(2, "0")}`;
    const dayKey = now.toISOString().slice(0, 10);

    // Increment weekly total
    const wkTotal = parseInt(await env.STILYA_KV.get(`stats:weekly:${weekKey}`) || "0", 10);
    await env.STILYA_KV.put(`stats:weekly:${weekKey}`, String(wkTotal + amount), { expirationTtl: 60 * 60 * 24 * 30 });

    // Increment daily total
    const dayTotal = parseInt(await env.STILYA_KV.get(`stats:daily:${dayKey}`) || "0", 10);
    await env.STILYA_KV.put(`stats:daily:${dayKey}`, String(dayTotal + amount), { expirationTtl: 60 * 60 * 24 * 14 });

    // Track per-user weekly usage
    const userWkKey = `stats:user:${userId}:${weekKey}`;
    const userWk = parseInt(await env.STILYA_KV.get(userWkKey) || "0", 10);
    await env.STILYA_KV.put(userWkKey, String(userWk + amount), { expirationTtl: 60 * 60 * 24 * 30 });

    // Track active users set for this week
    const usersKey = `stats:weekly:${weekKey}:users`;
    const usersRaw = await env.STILYA_KV.get(usersKey);
    const usersSet = usersRaw ? new Set(JSON.parse(usersRaw)) : new Set();
    usersSet.add(userId);
    await env.STILYA_KV.put(usersKey, JSON.stringify([...usersSet]), { expirationTtl: 60 * 60 * 24 * 30 });
  } catch (e) {
    // Non-critical — don't break the main flow
    console.error(`[stats] trackCreditUsage error: ${e.message}`);
  }
}

function getISOWeek(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
}

/**
 * Check rate limit for a user. Uses KV with hourly TTL.
 * Returns { allowed: bool, remaining: int, limit: int }
 */
async function checkRateLimit(env, userId) {
  if (!env.STILYA_KV) return { allowed: true, remaining: RATE_LIMIT_PER_HOUR, limit: RATE_LIMIT_PER_HOUR };

  // Check user-specific override first
  const userOverride = await env.STILYA_KV.get(`ratelimit:override:${userId}`);
  const limit = userOverride !== null ? parseInt(userOverride, 10) : RATE_LIMIT_PER_HOUR;

  // 0 = blocked
  if (limit === 0) return { allowed: false, remaining: 0, limit: 0 };

  const hour = new Date().toISOString().slice(0, 13); // "2026-03-30T12"
  const key = `ratelimit:${userId}:${hour}`;

  const current = parseInt(await env.STILYA_KV.get(key) || "0", 10);
  if (current >= limit) {
    return { allowed: false, remaining: 0, limit };
  }

  // Increment — TTL 2 hours (key auto-expires)
  await env.STILYA_KV.put(key, String(current + 1), { expirationTtl: 7200 });
  return { allowed: true, remaining: limit - current - 1, limit };
}

/**
 * Check if weekly credits need reset
 */
function needsWeeklyReset(user) {
  if (!user.weeklyCreditsLastReset) return true;
  const resetDate = user.weeklyCreditsLastReset instanceof Date
    ? user.weeklyCreditsLastReset
    : new Date(user.weeklyCreditsLastReset);
  const daysSinceReset = Math.floor((Date.now() - resetDate.getTime()) / (1000 * 60 * 60 * 24));
  return daysSinceReset >= 7;
}

/**
 * Check if Pro cycle credits need reset
 */
function needsProCycleReset(user) {
  if (!user.isPro || !user.proCreditsCycleStart || !user.subscriptionPlan) return false;
  const cycleStart = user.proCreditsCycleStart instanceof Date
    ? user.proCreditsCycleStart
    : new Date(user.proCreditsCycleStart);
  const daysInCycle = 7; // Both plans refresh credits weekly
  const daysSinceCycle = Math.floor((Date.now() - cycleStart.getTime()) / (1000 * 60 * 60 * 24));
  return daysSinceCycle >= daysInCycle;
}

/**
 * Get max pro credits for plan
 */
function proCreditsMax(user) {
  if (!user.subscriptionPlan) return 0;
  return user.subscriptionPlan === "weekly"
    ? CREDIT_CONSTANTS.proWeeklyCredits
    : CREDIT_CONSTANTS.proMonthlyCredits;
}

/**
 * Compute credit deduction within a transaction.
 * Returns { fields, totalRemaining } or throws if insufficient.
 */
function computeCreditDeduction(user, amount) {
  const fields = {};

  // Reset weekly credits if needed
  let currentCredits = user.credits || 0;
  if (needsWeeklyReset(user)) {
    currentCredits = CREDIT_CONSTANTS.freeWeeklyCredits;
    fields.credits = currentCredits;
    fields.weeklyCreditsLastReset = new Date();
    fields.weeklyCreditsUsed = 0;
  }

  // Reset pro credits if needed
  let currentProCredits = user.proCredits || 0;
  if (user.isPro && needsProCycleReset(user)) {
    currentProCredits = proCreditsMax(user);
    fields.proCredits = currentProCredits;
    fields.proCreditsCycleStart = new Date();
    fields.weeklyCreditsUsed = 0;
  }

  // Total available
  const totalAvailable = (user.isPro ? currentProCredits : 0) + (user.purchasedCredits || 0) + currentCredits;
  if (totalAvailable < amount) {
    return null; // insufficient
  }

  let remaining = amount;
  let newProCredits = currentProCredits;
  let newPurchasedCredits = user.purchasedCredits || 0;
  let newCredits = currentCredits;

  // Priority 1: Pro credits
  if (user.isPro && newProCredits > 0) {
    const deduct = Math.min(remaining, newProCredits);
    newProCredits -= deduct;
    remaining -= deduct;
  }

  // Priority 2: Purchased credits
  if (remaining > 0 && newPurchasedCredits > 0) {
    const deduct = Math.min(remaining, newPurchasedCredits);
    newPurchasedCredits -= deduct;
    remaining -= deduct;
  }

  // Priority 3: Free credits
  if (remaining > 0 && newCredits > 0) {
    const deduct = Math.min(remaining, newCredits);
    newCredits -= deduct;
    remaining -= deduct;
  }

  fields.proCredits = newProCredits;
  fields.purchasedCredits = newPurchasedCredits;
  fields.credits = newCredits;
  fields.totalCreditsUsed = (user.totalCreditsUsed || 0) + amount;
  fields.weeklyCreditsUsed = (user.weeklyCreditsUsed || 0) + amount;
  fields.updatedAt = new Date();

  const totalRemaining = (user.isPro ? newProCredits : 0) + newPurchasedCredits + newCredits;
  return { fields, totalRemaining };
}

/**
 * Refund credits back to user (same priority as deduction: Pro → Purchased → Free)
 * This ensures credits return to the source they were most likely deducted from.
 */
function computeCreditRefund(user, amount) {
  let refundRemaining = amount;
  let newProCredits = user.proCredits || 0;
  let newPurchasedCredits = user.purchasedCredits || 0;
  let newCredits = user.credits || 0;
  // Cap free-bucket refunds at max(weekly, trial) so a failed trial generation
  // is refunded back to the free bucket (not converted into a permanent
  // purchased credit) even though the recurring weekly grant is 0.
  const freeMax = Math.max(CREDIT_CONSTANTS.freeWeeklyCredits, CREDIT_CONSTANTS.trialCredits);
  const proMax = proCreditsMax(user);

  // Priority 1: Refund to pro credits (if user is Pro, up to cycle max)
  if (refundRemaining > 0 && user.isPro && newProCredits < proMax) {
    const refund = Math.min(refundRemaining, proMax - newProCredits);
    newProCredits += refund;
    refundRemaining -= refund;
  }

  // Priority 2: Refund to free credits (up to weekly max)
  if (refundRemaining > 0 && newCredits < freeMax) {
    const refund = Math.min(refundRemaining, freeMax - newCredits);
    newCredits += refund;
    refundRemaining -= refund;
  }

  // Priority 3: Refund to purchased credits (no upper limit)
  if (refundRemaining > 0) {
    newPurchasedCredits += refundRemaining;
    refundRemaining = 0;
  }

  return {
    credits: newCredits,
    purchasedCredits: newPurchasedCredits,
    proCredits: newProCredits,
    totalCreditsUsed: Math.max(0, (user.totalCreditsUsed || 0) - amount),
    weeklyCreditsUsed: Math.max(0, (user.weeklyCreditsUsed || 0) - amount),
    updatedAt: new Date(),
  };
}

/**
 * Perform credit refund via Firestore transaction. Returns true if successful.
 */
async function refundCredits(env, userId, creditCost, reason) {
  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) return false;
  try {
    const fsToken = await getFirestoreAccessToken(env);
    const docPath = `users/${userId}`;
    const txId = await firestoreBeginTransaction(fsToken);
    const txResult = await firestoreGetInTransaction(fsToken, docPath, txId);

    if (txResult && txResult.data) {
      const refundFields = computeCreditRefund(txResult.data, creditCost);
      const write = buildUpdateWrite(docPath, refundFields);
      await firestoreCommit(fsToken, txId, [write]);
      return true;
    } else {
      await firestoreCommit(fsToken, txId, []);
      return false;
    }
  } catch (refundErr) {
    console.error(`[tryon] Credit refund failed (${reason}): ${refundErr.message}`);
    return false;
  }
}

/**
 * Compute total available credits (with resets applied)
 */
function computeTotalCredits(user) {
  let currentCredits = user.credits || 0;
  if (needsWeeklyReset(user)) {
    currentCredits = CREDIT_CONSTANTS.freeWeeklyCredits;
  }

  let currentProCredits = user.proCredits || 0;
  if (user.isPro && needsProCycleReset(user)) {
    currentProCredits = proCreditsMax(user);
  }

  return (user.isPro ? currentProCredits : 0) + (user.purchasedCredits || 0) + currentCredits;
}

// ============================================================
// Model-photo generation metering (free / onboarding path)
// ============================================================
// The onboarding model-photo endpoint does NOT charge credits, so without a
// server-side counter any anonymous account could generate unlimited Pro-model
// images (capped only by the 15/hr rate limit). We meter it here:
//   • non-Pro users → lifetime cap (freeModelPhotoLimit)
//   • Pro users     → rolling 7-day window (proModelPhotoWeekly)
// Only SUCCESSFUL generations are counted (incremented after the image is
// produced), so a safety-blocked attempt never burns the user's allowance.

/**
 * Count model-photo generations used in the current rolling 7-day window.
 * Returns 0 if the window has expired (so it resets naturally).
 */
function modelPhotoWeekCount(user) {
  if (!user.modelPhotoWeekStart) return 0;
  const start = user.modelPhotoWeekStart instanceof Date
    ? user.modelPhotoWeekStart
    : new Date(user.modelPhotoWeekStart);
  const days = Math.floor((Date.now() - start.getTime()) / (1000 * 60 * 60 * 24));
  if (days >= 7) return 0;
  return user.modelPhotoWeekCount || 0;
}

/**
 * Check whether a user may generate a free (onboarding) model photo.
 * Returns { allowed, remaining, isPro }.
 */
async function checkModelPhotoLimit(env, userId) {
  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    return { allowed: true, remaining: null, isPro: false };
  }
  const fsToken = await getFirestoreAccessToken(env);
  const user = await firestoreGet(fsToken, `users/${userId}`);
  if (!user) {
    // First-ever request, no doc yet → allow (counted after success).
    return { allowed: true, remaining: CREDIT_CONSTANTS.freeModelPhotoLimit, isPro: false };
  }
  const isPro = !!user.isPro;
  if (isPro) {
    const remaining = Math.max(0, CREDIT_CONSTANTS.proModelPhotoWeekly - modelPhotoWeekCount(user));
    return { allowed: remaining > 0, remaining, isPro };
  }
  const remaining = Math.max(0, CREDIT_CONSTANTS.freeModelPhotoLimit - (user.modelPhotoGenTotal || 0));
  return { allowed: remaining > 0, remaining, isPro };
}

/**
 * Record a successful free model-photo generation (atomic). Returns the
 * remaining allowance after incrementing, or null on infra error.
 */
async function incrementModelPhotoCount(env, userId) {
  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) return null;
  try {
    const fsToken = await getFirestoreAccessToken(env);
    const docPath = `users/${userId}`;
    const txId = await firestoreBeginTransaction(fsToken);
    const txResult = await firestoreGetInTransaction(fsToken, docPath, txId);
    if (!txResult || !txResult.data) {
      await firestoreCommit(fsToken, txId, []);
      return null;
    }
    const user = txResult.data;
    const isPro = !!user.isPro;
    const fields = {
      modelPhotoGenTotal: (user.modelPhotoGenTotal || 0) + 1,
      updatedAt: new Date(),
    };

    // Roll the 7-day window forward (start a new window if none/expired).
    const start = user.modelPhotoWeekStart
      ? (user.modelPhotoWeekStart instanceof Date ? user.modelPhotoWeekStart : new Date(user.modelPhotoWeekStart))
      : null;
    const windowActive = start && (Date.now() - start.getTime()) < 7 * 24 * 60 * 60 * 1000;
    if (windowActive) {
      fields.modelPhotoWeekCount = (user.modelPhotoWeekCount || 0) + 1;
    } else {
      fields.modelPhotoWeekStart = new Date();
      fields.modelPhotoWeekCount = 1;
    }

    const write = buildUpdateWrite(docPath, fields);
    await firestoreCommit(fsToken, txId, [write]);

    return isPro
      ? Math.max(0, CREDIT_CONSTANTS.proModelPhotoWeekly - fields.modelPhotoWeekCount)
      : Math.max(0, CREDIT_CONSTANTS.freeModelPhotoLimit - fields.modelPhotoGenTotal);
  } catch (e) {
    console.error(`[generate-model] gen count increment failed: ${e.message}`);
    return null;
  }
}

// ============================================================
// RevenueCat API Client
// ============================================================

/**
 * Verify Pro status via RevenueCat REST API
 */
async function verifyRevenueCatPro(env, userId) {
  const apiKey = env.REVENUECAT_API_KEY;
  if (!apiKey) throw new Error("REVENUECAT_API_KEY not configured");

  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
    }
  );

  if (!response.ok) {
    if (response.status === 404) {
      return { isPro: false, plan: null, expiryDate: null };
    }
    throw new Error(`RevenueCat API error: ${response.status}`);
  }

  const data = await response.json();
  const entitlement = data.subscriber?.entitlements?.["StilYa Pro"];

  if (!entitlement) {
    return { isPro: false, plan: null, expiryDate: null };
  }

  const expiresDate = entitlement.expires_date ? new Date(entitlement.expires_date) : null;
  const isActive = expiresDate ? expiresDate > new Date() : false;

  if (!isActive) {
    return { isPro: false, plan: null, expiryDate: null };
  }

  // Determine plan from product identifier
  const productId = entitlement.product_identifier || "";
  const plan = productId.includes("monthly") ? "monthly" : "weekly";

  return { isPro: true, plan, expiryDate: expiresDate };
}

/**
 * Verify a non-subscription purchase via RevenueCat
 */
async function verifyRevenueCatPurchase(env, userId, productId) {
  const apiKey = env.REVENUECAT_API_KEY;
  if (!apiKey) throw new Error("REVENUECAT_API_KEY not configured");

  // Retry up to 3 times with delay — RevenueCat may not have indexed the transaction yet
  const maxRetries = 3;
  const delays = [0, 2000, 4000]; // 0s, 2s, 4s

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    if (delays[attempt] > 0) {
      await new Promise(r => setTimeout(r, delays[attempt]));
    }

    const response = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    if (!response.ok) {
      throw new Error(`RevenueCat API error: ${response.status}`);
    }

    const data = await response.json();
    const transactions = data.subscriber?.non_subscriptions?.[productId] || [];

    if (transactions.length > 0) {
      transactions.sort((a, b) => new Date(b.purchase_date) - new Date(a.purchase_date));
      return transactions[0];
    }

  }

  return null;
}

// ============================================================
// API Endpoint Handlers
// ============================================================

/**
 * POST /api/account/delete — Register device fingerprint before account deletion (abuse prevention)
 */
async function handleAccountDelete(request, env, userId) {
  try {
    const body = await request.json();
    const { deviceFingerprint, deviceToken } = body;

    if (!deviceFingerprint || typeof deviceFingerprint !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing deviceFingerprint" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const token = await getFirestoreAccessToken(env);
    const docPath = `deletedDevices/${deviceFingerprint}`;

    // Check if document already exists (repeat deleter)
    const existing = await firestoreGet(token, docPath);
    const deletedCount = existing ? (existing.deletedCount || 0) + 1 : 1;

    const write = buildUpdateWrite(docPath, {
      deviceFingerprint,
      userId,
      deletedAt: new Date(),
      deletedCount,
    });

    const txId = await firestoreBeginTransaction(token);
    await firestoreCommit(token, txId, [write]);

    // Also mark on Apple DeviceCheck (bit0 = credits claimed)
    if (deviceToken && typeof deviceToken === "string" && deviceToken.length > 0) {
      await updateDeviceCheck(env, deviceToken, true, false);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("handleAccountDelete error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * Query Firestore users collection to count accounts with a given deviceId.
 * Uses Firestore REST runQuery API with structuredQuery.
 */
async function firestoreCountByDeviceId(token, deviceId) {
  const url = `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents:runQuery`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "users" }],
        where: {
          fieldFilter: {
            field: { fieldPath: "deviceId" },
            op: "EQUAL",
            value: { stringValue: deviceId },
          },
        },
        select: { fields: [{ fieldPath: "__name__" }] },
      },
    }),
  });

  if (!response.ok) {
    console.error("firestoreCountByDeviceId error:", response.status);
    return 0;
  }

  const results = await response.json();
  // runQuery returns array; entries without 'document' are skipped results
  return Array.isArray(results) ? results.filter(r => r.document).length : 0;
}

/**
 * POST /api/device/check — Firestore-based abuse prevention
 * Counts existing accounts per device fingerprint.
 * 1-2 accounts → allow with free credits
 * 3+ accounts → allow but no free credits (must purchase)
 */
async function handleDeviceCheck(request, env, userId) {
  try {
    const body = await request.json();
    const { deviceFingerprint } = body;

    if (!deviceFingerprint || typeof deviceFingerprint !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing deviceFingerprint" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const token = await getFirestoreAccessToken(env);

    // Count existing user accounts with this deviceId
    const accountCount = await firestoreCountByDeviceId(token, deviceFingerprint);

    // Check deleted accounts as additional signal
    const deletedRecord = await firestoreGet(token, `deletedDevices/${deviceFingerprint}`);
    const deletedCount = deletedRecord ? (deletedRecord.deletedCount || 1) : 0;

    // Total accounts ever created on this device
    const totalAccounts = accountCount + deletedCount;

    // 3+ total accounts = no free credits (abuse)
    const freeCreditsAlreadyClaimed = totalAccounts >= 3;

    return new Response(
      JSON.stringify({
        allowed: true,
        freeCreditsAlreadyClaimed,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("handleDeviceCheck error:", error);
    // Fail open — don't block legitimate users on error
    return new Response(
      JSON.stringify({ allowed: true, freeCreditsAlreadyClaimed: false }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * POST /api/sync-pro — Verify Pro status via RevenueCat, update Firestore
 */
async function handleSyncPro(request, env, userId) {
  try {
    const token = await getFirestoreAccessToken(env);
    const rcResult = await verifyRevenueCatPro(env, userId);
    const docPath = `users/${userId}`;

    // Begin transaction
    const txId = await firestoreBeginTransaction(token);
    const txResult = await firestoreGetInTransaction(token, docPath, txId);

    if (!txResult || !txResult.data) {
      // No user doc — just commit empty
      await firestoreCommit(token, txId, []);
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const user = txResult.data;
    const fields = { updatedAt: new Date() };

    if (rcResult.isPro) {
      fields.isPro = true;
      if (rcResult.expiryDate) fields.subscriptionExpiryDate = rcResult.expiryDate;
      if (rcResult.plan) fields.subscriptionPlan = rcResult.plan;
      if (!user.hasPurchased) fields.hasPurchased = true;

      const maxCredits = rcResult.plan === "weekly"
        ? CREDIT_CONSTANTS.proWeeklyCredits
        : CREDIT_CONSTANTS.proMonthlyCredits;

      if (!user.isPro) {
        // Newly Pro — give initial credits
        fields.proCredits = maxCredits;
        fields.proCreditsCycleStart = new Date();
      } else if (needsProCycleReset(user)) {
        // Cycle expired — reset credits
        fields.proCredits = maxCredits;
        fields.proCreditsCycleStart = new Date();
      }
      // else: cycle still active, keep existing credits
    } else if (user.isPro) {
      // Was Pro, now not — cancel
      fields.isPro = false;
      fields.proCredits = 0;
      fields.subscriptionPlan = null;
      fields.proCreditsCycleStart = null;
      fields.subscriptionExpiryDate = null;
    }

    const write = buildUpdateWrite(docPath, fields);
    await firestoreCommit(token, txId, [write]);

    // Compute remaining credits after sync
    const updatedUser = { ...user, ...fields };
    const totalCredits = computeTotalCredits(updatedUser);

    return new Response(
      JSON.stringify({
        success: true,
        isPro: fields.isPro !== undefined ? fields.isPro : user.isPro,
        credits: totalCredits,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[sync-pro] Error: ${error.message}`, error.stack);
    return new Response(
      JSON.stringify({ error: "Failed to sync Pro status", ...(IS_DEBUG && { detail: error.message }) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * POST /api/purchase/verify — Verify purchase via RevenueCat, add credits
 */
async function handleVerifyPurchase(request, env, userId) {
  try {
    const body = await request.json();
    const { productId, transactionId } = body;

    if (!productId) {
      return new Response(
        JSON.stringify({ error: "Missing productId" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Determine credit amount from product ID
    // Support both old (com.stilya.credits.X) and new (X_credit) formats
    let creditAmount = 0;
    if (productId === "5_credit" || productId === "com.stilya.credits.5") creditAmount = 5;
    else if (productId === "20_credit" || productId === "com.stilya.credits.20") creditAmount = 20;
    else if (productId === "60_credit" || productId === "com.stilya.credits.60") creditAmount = 60;
    else {
      return new Response(
        JSON.stringify({ error: "Unknown product ID" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Verify with RevenueCat
    const rcTransaction = await verifyRevenueCatPurchase(env, userId, productId);
    if (!rcTransaction) {
      return new Response(
        JSON.stringify({ error: "Purchase not found in RevenueCat" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Atomic transaction: read user → check duplicate → add credits
    const token = await getFirestoreAccessToken(env);
    const docPath = `users/${userId}`;
    const txId = await firestoreBeginTransaction(token);
    const txResult = await firestoreGetInTransaction(token, docPath, txId);

    if (!txResult || !txResult.data) {
      await firestoreCommit(token, txId, []);
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const user = txResult.data;
    const rcTxId = rcTransaction.id || transactionId;

    // Duplicate protection — same transaction won't be processed twice
    if (rcTxId && rcTxId === user.lastTransactionId) {
      await firestoreCommit(token, txId, []);
      const totalCredits = computeTotalCredits(user);
      return new Response(
        JSON.stringify({ success: true, credits: totalCredits, duplicate: true }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const fields = {
      purchasedCredits: (user.purchasedCredits || 0) + creditAmount,
      hasPurchased: true,
      updatedAt: new Date(),
    };

    if (rcTxId) {
      fields.lastTransactionId = rcTxId;
      fields.lastTransactionDate = new Date();
    }

    const write = buildUpdateWrite(docPath, fields);
    await firestoreCommit(token, txId, [write]);

    const updatedUser = { ...user, ...fields };
    const totalCredits = computeTotalCredits(updatedUser);

    return new Response(
      JSON.stringify({ success: true, credits: totalCredits, added: creditAmount }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[purchase/verify] Error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: "Failed to verify purchase" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * GET /api/credits — Return current credit balance
 */
async function handleGetCredits(request, env, userId) {
  try {
    const token = await getFirestoreAccessToken(env);
    const docPath = `users/${userId}`;
    const user = await firestoreGet(token, docPath);

    if (!user) {
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Persist reset to Firestore if needed (fixes cycle drift + stale countdown)
    const resetFields = {};
    let freeCredits = user.credits || 0;
    let proCredits = user.proCredits || 0;

    if (needsWeeklyReset(user)) {
      freeCredits = CREDIT_CONSTANTS.freeWeeklyCredits;
      resetFields.credits = freeCredits;
      resetFields.weeklyCreditsLastReset = new Date();
      resetFields.weeklyCreditsUsed = 0;
    }

    if (user.isPro && needsProCycleReset(user)) {
      proCredits = proCreditsMax(user);
      resetFields.proCredits = proCredits;
      resetFields.proCreditsCycleStart = new Date();
      resetFields.weeklyCreditsUsed = 0;
    }

    if (Object.keys(resetFields).length > 0) {
      resetFields.updatedAt = new Date();
      const write = buildUpdateWrite(docPath, resetFields);
      await firestoreCommit(token, null, [write]);
    }

    const totalCredits = (user.isPro ? proCredits : 0) + (user.purchasedCredits || 0) + freeCredits;

    return new Response(
      JSON.stringify({
        credits: totalCredits,
        breakdown: {
          free: freeCredits,
          purchased: user.purchasedCredits || 0,
          pro: user.isPro ? proCredits : 0,
        },
        isPro: user.isPro || false,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[credits] Error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: "Failed to get credits" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * POST /api/ads/reward — Grant 1 credit for watching a rewarded ad
 * Server-side daily limit enforcement (max 1 per day)
 */
async function handleRewardAd(request, env, userId) {
  try {
    const token = await getFirestoreAccessToken(env);
    const docPath = `users/${userId}`;

    // Use transaction for atomicity
    const txId = await firestoreBeginTransaction(token);
    const result = await firestoreGetInTransaction(token, docPath, txId);

    if (!result) {
      return new Response(
        JSON.stringify({ success: false, error: "User not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const user = result.data;

    // Check daily limit (server-side)
    const lastRewardedAdDate = user.lastRewardedAdDate;
    if (lastRewardedAdDate) {
      const lastDate = lastRewardedAdDate instanceof Date
        ? lastRewardedAdDate
        : new Date(lastRewardedAdDate);
      const now = new Date();
      // Same calendar day (UTC)
      if (lastDate.getUTCFullYear() === now.getUTCFullYear() &&
          lastDate.getUTCMonth() === now.getUTCMonth() &&
          lastDate.getUTCDate() === now.getUTCDate()) {
        // Already watched today
        const totalCredits = computeTotalCredits(user);
        return new Response(
          JSON.stringify({
            success: false,
            credits: totalCredits,
            dailyAdsRemaining: 0,
            error: "Daily reward ad limit reached"
          }),
          { status: 429, headers: { "Content-Type": "application/json" } }
        );
      }
    }

    // Add 1 to purchasedCredits (survives weekly reset)
    const newPurchased = (user.purchasedCredits || 0) + 1;
    const fields = {
      purchasedCredits: newPurchased,
      lastRewardedAdDate: new Date(),
      updatedAt: new Date(),
    };

    const write = buildUpdateWrite(docPath, fields);
    await firestoreCommit(token, txId, [write]);

    // Compute total credits after update
    let freeCredits = user.credits || 0;
    if (needsWeeklyReset(user)) {
      freeCredits = CREDIT_CONSTANTS.freeWeeklyCredits;
    }
    let proCredits = 0;
    if (user.isPro) {
      proCredits = needsProCycleReset(user) ? proCreditsMax(user) : (user.proCredits || 0);
    }
    const totalCredits = proCredits + newPurchased + freeCredits;

    return new Response(
      JSON.stringify({
        success: true,
        credits: totalCredits,
        dailyAdsRemaining: 0,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[ads/reward] Error: ${error.message}`);
    return new Response(
      JSON.stringify({ success: false, error: "Failed to process reward" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * POST /api/referral/process — Process a referral code server-side
 * Validates code, checks fraud, adds credits to referrer, updates referralCount
 */
async function handleProcessReferral(request, env, userId) {
  try {
    const body = await request.json();
    const rawCode = body.code;

    if (!rawCode || typeof rawCode !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing referral code" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const code = rawCode.toUpperCase().trim();
    const token = await getFirestoreAccessToken(env);

    // 1. Look up referral code → referrer userId
    const lookupDoc = await firestoreGet(token, `referralCodes/${code}`);
    if (!lookupDoc) {
      return new Response(
        JSON.stringify({ error: "Geçersiz davet kodu" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const referrerId = lookupDoc.userId;

    // 2. Self-referral check
    if (referrerId === userId) {
      return new Response(
        JSON.stringify({ error: "Kendi davet kodunuzu kullanamazsınız" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // 3. Begin transaction — read both users
    const txId = await firestoreBeginTransaction(token);
    const [newUserResult, referrerResult] = await Promise.all([
      firestoreGetInTransaction(token, `users/${userId}`, txId),
      firestoreGetInTransaction(token, `users/${referrerId}`, txId),
    ]);

    if (!newUserResult || !newUserResult.data) {
      await firestoreCommit(token, txId, []);
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!referrerResult || !referrerResult.data) {
      await firestoreCommit(token, txId, []);
      return new Response(
        JSON.stringify({ error: "Referrer not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const newUser = newUserResult.data;
    const referrer = referrerResult.data;

    // 4. Already used a referral code
    if (newUser.referredBy) {
      await firestoreCommit(token, txId, []);
      return new Response(
        JSON.stringify({ error: "Zaten bir davet kodu kullandınız" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // 5. Device fraud checks
    const newUserDeviceId = newUser.deviceId || "";
    const referrerDeviceId = referrer.deviceId || "";

    if (newUserDeviceId && referrerDeviceId && newUserDeviceId === referrerDeviceId) {
      await firestoreCommit(token, txId, []);
      return new Response(
        JSON.stringify({ error: "Davet kodu aynı cihazdan kullanılamaz" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // 5b. Check if device already used a referral code
    if (newUserDeviceId) {
      const deviceRecord = await firestoreGet(token, `deviceReferrals/${newUserDeviceId}`);
      if (deviceRecord) {
        await firestoreCommit(token, txId, []);
        return new Response(
          JSON.stringify({ error: "Bu cihazdan zaten bir davet kodu kullanılmış" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }
    }

    // 6. All checks passed — prepare writes
    const REFERRAL_BONUS = 2; // AppConstants.referralBonusCredits
    const writes = [];

    // 6a. Add credits to referrer
    writes.push(buildUpdateWrite(`users/${referrerId}`, {
      purchasedCredits: (referrer.purchasedCredits || 0) + REFERRAL_BONUS,
      referralCount: (referrer.referralCount || 0) + 1,
      updatedAt: new Date(),
    }));

    // 6b. Set referredBy on new user
    writes.push(buildUpdateWrite(`users/${userId}`, {
      referredBy: referrerId,
      updatedAt: new Date(),
    }));

    // Commit transaction
    await firestoreCommit(token, txId, writes);

    // 7. Record device usage (outside transaction, best effort)
    if (newUserDeviceId) {
      try {
        // Create device referral record via REST API
        const deviceDocURL = `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents/deviceReferrals?documentId=${encodeURIComponent(newUserDeviceId)}`;
        await fetch(deviceDocURL, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            fields: {
              deviceId: { stringValue: newUserDeviceId },
              userIds: { arrayValue: { values: [{ stringValue: userId }] } },
              updatedAt: { timestampValue: new Date().toISOString() },
            },
          }),
        });
      } catch (e) {
        console.error(`[referral] Device record creation failed: ${e.message}`);
      }
    }

    return new Response(
      JSON.stringify({ success: true, bonusCredits: REFERRAL_BONUS }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[referral/process] Error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: "Failed to process referral" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

// ============================================================
// fal Model APIs — image editing for try-on and model photos
// ============================================================
//
// Every image generation in StilYa goes through fal (https://fal.ai).
// The worker holds FAL_KEY as a secret; the iOS app never sees it.
// Models are plain endpoint IDs, so swapping models is a config change:
//   FAL_MODEL_TRYON      default try-on (single garment + combos)
//   FAL_MODEL_TRYON_PRO  harder cases (outfit-from-flat-lay, "pro" requests)
//   FAL_MODEL_PHOTO      selfie → full-body model photo

const FAL_RUN_URL = "https://fal.run";
const FAL_DEFAULT_MODELS = {
  default: "fal-ai/nano-banana-2/edit",
  pro: "fal-ai/nano-banana-pro/edit",
  photo: "fal-ai/nano-banana-pro/edit",
};
const FAL_TIMEOUT_MS = 120_000;
const MAX_AI_REQUEST_SIZE = 20 * 1024 * 1024; // 20MB (base64 images are large)

function falModelFor(env, tier) {
  if (tier === "pro") return env.FAL_MODEL_TRYON_PRO || FAL_DEFAULT_MODELS.pro;
  if (tier === "photo") return env.FAL_MODEL_PHOTO || FAL_DEFAULT_MODELS.photo;
  return env.FAL_MODEL_TRYON || FAL_DEFAULT_MODELS.default;
}

function decodeDataUri(dataUri) {
  const match = dataUri.match(/^data:([\w/+.-]+);base64,(.+)$/);
  if (!match) throw new Error("Invalid data URI format");
  const raw = atob(match[2]);
  return { mimeType: match[1], bytes: Uint8Array.from(raw, c => c.charCodeAt(0)) };
}

/**
 * Call a fal image-edit endpoint synchronously.
 *
 * imageDataUris are passed straight through as `image_urls` — fal accepts
 * base64 data URIs, so there is no separate upload step.
 *
 * Returns { ok: true, url, bytes?, mimeType } or
 *         { ok: false, reason: "unavailable" | "http_error" | "safety" | "no_image", status?, detail? }
 */
async function callFalImageEdit(env, { model, prompt, imageDataUris, aspectRatio, keepBytes, label = "fal" }) {
  const input = {
    prompt,
    image_urls: imageDataUris,
    num_images: 1,
    aspect_ratio: aspectRatio,
    output_format: "jpeg",
    // sync_mode returns the image inline and keeps it out of fal's request
    // history — used when we store results in our own R2 bucket.
    sync_mode: !!keepBytes,
  };

  const maxRetries = 3;
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    let res;
    try {
      res = await fetch(`${FAL_RUN_URL}/${model}`, {
        method: "POST",
        headers: {
          "Authorization": `Key ${env.FAL_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(input),
        signal: AbortSignal.timeout(FAL_TIMEOUT_MS),
      });
    } catch (fetchErr) {
      console.error(`[${label}] fal fetch error (attempt ${attempt + 1}): ${fetchErr.message}`);
      if (attempt < maxRetries - 1) {
        await new Promise(r => setTimeout(r, (attempt + 1) * 3000));
        continue;
      }
      return { ok: false, reason: "unavailable", detail: fetchErr.message };
    }

    const text = await res.text();

    if (!res.ok) {
      // 429 / 5xx → back off and retry
      if ((res.status === 429 || res.status >= 500) && attempt < maxRetries - 1) {
        await new Promise(r => setTimeout(r, (attempt + 1) * (res.status === 429 ? 5000 : 3000)));
        continue;
      }
      if (/content.?policy|nsfw|safety/i.test(text)) {
        return { ok: false, reason: "safety", status: res.status, detail: text.substring(0, 500) };
      }
      return { ok: false, reason: "http_error", status: res.status, detail: text.substring(0, 500) };
    }

    let output;
    try {
      output = JSON.parse(text);
    } catch {
      return { ok: false, reason: "no_image", detail: "Unparseable fal response" };
    }

    if (Array.isArray(output.has_nsfw_concepts) && output.has_nsfw_concepts.some(Boolean)) {
      return { ok: false, reason: "safety", detail: "has_nsfw_concepts" };
    }

    const image = output.images?.[0];
    if (!image?.url) {
      return { ok: false, reason: "no_image", detail: (output.description || "").substring(0, 300) };
    }

    if (image.url.startsWith("data:")) {
      const { mimeType, bytes } = decodeDataUri(image.url);
      return { ok: true, url: image.url, bytes, mimeType: image.content_type || mimeType };
    }

    if (keepBytes) {
      // Some endpoints ignore sync_mode — fetch the CDN file instead
      const imgRes = await fetch(image.url);
      if (!imgRes.ok) return { ok: false, reason: "no_image", detail: `CDN fetch ${imgRes.status}` };
      const bytes = new Uint8Array(await imgRes.arrayBuffer());
      return { ok: true, url: image.url, bytes, mimeType: image.content_type || imgRes.headers.get("Content-Type") || "image/jpeg" };
    }

    return { ok: true, url: image.url, mimeType: image.content_type || "image/jpeg" };
  }

  return { ok: false, reason: "unavailable", detail: "Retries exhausted (429/5xx)" };
}

function falErrorResponse(result, { safetyMessage = "Image was filtered for safety reasons" } = {}) {
  const json = { "Content-Type": "application/json" };
  const debug = IS_DEBUG && result.detail ? { detail: result.detail } : {};
  switch (result.reason) {
    case "safety":
      return new Response(JSON.stringify({ error: safetyMessage, ...debug }), { status: 400, headers: json });
    case "no_image":
      return new Response(JSON.stringify({ error: "AI did not generate an image. Please try again.", ...debug }), { status: 502, headers: json });
    case "unavailable":
      return new Response(JSON.stringify({ error: "AI service unavailable", ...debug }), { status: 502, headers: json });
    default:
      // fal 4xx (bad input) maps to 400; auth/quota problems on our side stay 502
      return new Response(
        JSON.stringify({ error: "AI processing failed", ...debug }),
        { status: result.status === 422 || result.status === 400 ? 400 : 502, headers: json }
      );
  }
}

/** Public origin for links to R2 assets (e.g. https://api.example.com). */
function publicBaseUrl(env, requestOrUrl) {
  if (env.PUBLIC_BASE_URL) return env.PUBLIC_BASE_URL.replace(/\/$/, "");
  return new URL(requestOrUrl.url ?? requestOrUrl).origin;
}

// ============================================================
// Try-On Prompts
// ============================================================

// ── V1 PROMPT (ACTIVE) ──────────────────────────────────────────────
// ── MAIN PROMPT ─────────────────────────────────────────────
// Concise, positive-framed, structured. Written for multi-image edit models
// (Nano Banana family on fal) that read inputs as "Image 1, Image 2, ..."
function buildNanoBananaPrompt(garments, topTuckedIn) {
  const garmentCount = garments.length;

  function typeLabel(type) {
    if (type === "tops") return "top";
    if (type === "bottoms") return "pants/bottom";
    if (type === "one-pieces") return "dress";
    if (type === "jackets") return "jacket";
    if (type === "shoes") return "shoes";
    return type;
  }

  function garmentHint(type) {
    if (type === "tops") return "Match the EXACT sleeve length, neckline, hem length, fit, and fabric from the reference. A fitted top stays fitted, a crop top stays cropped. Keep open/unbuttoned state if visible. If the garment looks like outerwear (buttons, lapels, collar), layer it over existing clothing.";
    if (type === "bottoms") return "Match the EXACT silhouette (skinny/straight/wide-leg/flared), rise, leg shape, and fabric from the reference. PANTS LENGTH IS THE #1 PRIORITY: Copy the EXACT same length from the reference image — measure how far the pants reach relative to the shoe/ankle in the reference and reproduce that EXACTLY. If pants touch the ground, bunch up at the ankle, cover the shoe, or pool over the feet in the reference, they MUST do the same in the output. It is OK if the shoes become partially or fully hidden behind the pants fabric. NEVER pull pants up or shorten them to reveal the shoes. A flare stays a flare at the same length, skinny stays skinny at the same length, wide-leg stays wide-leg at the same length.";
    if (type === "one-pieces") return "NECKLINE & STRAPS ARE #1 PRIORITY: Copy the EXACT strap/shoulder construction from the reference — spaghetti straps MUST stay thin spaghetti, thick straps stay thick, strapless stays strapless, off-shoulder stays off-shoulder, halter stays halter, sleeveless stays sleeveless, long-sleeve stays long-sleeve. Do NOT convert between ANY strap styles. The neckline shape (v-neck/square/sweetheart/round/high) MUST be identical to the reference. Match the EXACT silhouette, fabric drape, and length. Do NOT shorten or lift the hemline — floor-length stays floor-length, midi stays midi, mini stays mini. Copy the dress EXACTLY as shown.";
    if (type === "jackets") return "Layer over existing clothing. Match the EXACT collar/zipper open-or-closed state, hardware, pockets, and length from the reference.";
    if (type === "shoes") return "Reproduce the EXACT shoe on the person's feet — color, material, sole, laces, heel height, toe shape, all branding.";
    return "";
  }

  const hasShoes = garments.some(g => g.type === "shoes");

  if (garmentCount === 1) {
    const g = garments[0];
    const label = typeLabel(g.type);
    const hint = garmentHint(g.type);

    return [
      `Photorealistic virtual try-on. Image 1: a person. Image 2: a ${label}.`,
      ``,
      `Generate a photo of the SAME person from Image 1 wearing the ${label} from Image 2.`,
      ``,
      `ABSOLUTE RULES:`,
      `1. PERSON IDENTITY — The person's face, facial features, hair, skin tone, body shape, body weight, body proportions, pose, and expression MUST be 100% identical to Image 1. Do NOT alter, slim, reshape, or modify the person's body in any way. The person must be recognizably the SAME individual.`,
      `2. GARMENT FIDELITY — Reproduce the garment as a PIXEL-LEVEL COPY from Image 2. Same exact color (navy stays navy, cream stays cream), same pattern (stripe width, plaid grid, floral placement), same texture (denim, silk, knit, leather), same fabric weight (thin stays thin, heavy stays heavy), same construction details (buttons, zippers, pockets, seams, logos). SIZING RULE: Only scale the garment's WIDTH to fit the person's body size — NEVER change the LENGTH, silhouette, or design. Pants leg length, hem position, flare shape, dress length, sleeve length must all stay exactly as shown in the reference. A floor-length dress stays floor-length, wide-leg pants stay wide-leg at the same length, a cropped top stays cropped at the same level.`,
      `3. CONTEXT — Keep the EXACT same background, lighting, and setting from Image 1. Only replace clothing in the ${label} category — keep all other clothing and accessories unchanged. Garment length ALWAYS takes priority over shoe visibility — if the garment naturally covers the feet or shoes, that is correct.`,
      ``,
      `${label.toUpperCase()}: ${hint}`,
      ``,
      `RESTRICTIONS: ONLY dress the person in the PROVIDED garment(s) — nothing else. Do NOT add, invent, or hallucinate ANY extra clothing, layers, tied shirts, scarves, belts, bags, jewelry, or accessories that are not explicitly provided as input images. If it is not in Image 2, it MUST NOT appear in the output. Keep all other clothing from Image 1 exactly as-is.`,
      ``,
      `SILHOUETTE: Preserve the EXACT leg/pant silhouette — wide-leg stays wide-leg, flared stays flared, straight stays straight. Do NOT taper or narrow legs toward the ankles unless the reference shows skinny/tapered pants.`,
      hasShoes ? `\nSHOE SHOWCASE: Turn one foot slightly outward (20-30 degrees) to showcase the shoes. Keep the rest of the pose identical.` : ``,
      ``,
      `CRITICAL: Do NOT add any outline, glow, stroke, halo, or white border around the person. The person must blend seamlessly into the background with natural edges.`,
      ``,
      `Output a natural, unedited photograph — realistic lighting, correct shadows, natural fabric draping on the body.`
    ].filter(l => l !== ``|| true).join("\n");
  }

  // Multi-garment (combo)
  const imageLabels = garments.map((g, i) => `Image ${i + 2}: a ${typeLabel(g.type)}`).join(". ");
  const perGarment = garments.map((g, i) => `- ${typeLabel(g.type)} (Image ${i + 2}): ${garmentHint(g.type)}`).join("\n");
  const tuck = "Tuck the top into the waistband ONLY if a belt is clearly visible on the bottom/pants. No belt = untucked, hem falling naturally.";

  return [
    `Photorealistic virtual try-on. Image 1: a person. ${imageLabels}.`,
    ``,
    `Generate a photo of the SAME person from Image 1 wearing ALL provided garments together as a complete outfit.`,
    ``,
    `ABSOLUTE RULES:`,
    `1. PERSON IDENTITY — The person's face, facial features, hair, skin tone, body shape, body weight, body proportions, pose, and expression MUST be 100% identical to Image 1. Do NOT alter, slim, reshape, or modify the person's body in any way. The person must be recognizably the SAME individual.`,
    `2. GARMENT FIDELITY — Reproduce each garment as a PIXEL-LEVEL COPY from its reference image. Same exact color, pattern, texture, fabric weight, construction details (buttons, zippers, pockets, seams, logos), fit, and silhouette. SIZING RULE: Only scale each garment's WIDTH to fit the person's body size — NEVER change the LENGTH, silhouette, or design. Pants leg length, hem position, flare shape, dress length, sleeve length must all stay exactly as shown in the reference.`,
    `3. CONTEXT — Keep the EXACT same background, lighting, and setting from Image 1. Only replace clothing categories that are provided — keep everything else unchanged. Garment length ALWAYS takes priority over shoe visibility — if a garment naturally covers the feet or shoes, that is correct.`,
    ``,
    `PER-GARMENT:`,
    perGarment,
    ``,
    `LAYERING: ${tuck}`,
    ``,
    `RESTRICTIONS: ONLY dress the person in the PROVIDED garment(s) — nothing else. Do NOT add, invent, or hallucinate ANY extra clothing, layers, tied shirts, scarves, belts, bags, jewelry, or accessories that are not explicitly provided as input images. If it is not in the garment reference images, it MUST NOT appear in the output. Keep all other clothing from Image 1 exactly as-is.`,
    ``,
    `SILHOUETTE: Preserve the EXACT leg/pant silhouette — wide-leg stays wide-leg, flared stays flared, straight stays straight. Do NOT taper or narrow legs toward the ankles unless the reference shows skinny/tapered pants.`,
    hasShoes ? `SHOE SHOWCASE: Turn one foot slightly outward (20-30 degrees) to showcase the shoes. Keep the rest of the pose identical.` : ``,
    ``,
    `CRITICAL: Do NOT add any outline, glow, stroke, halo, or white border around the person. The person must blend seamlessly into the background with natural edges.`,
    ``,
    `Output a natural, unedited photograph — realistic lighting, correct shadows, natural fabric draping on the body.`
  ].join("\n");
}

/**
 * Prompt for outfit replication from a flat-lay / mood board / collage image.
 * The AI identifies clothing items in the reference and dresses the person.
 */
function buildOutfitReplicationPrompt() {
  return [
    `Photorealistic virtual try-on. Image 1: a person. Image 2: an outfit reference (flat-lay, collage, or mood board).`,
    ``,
    `#1 PRIORITY — PERSON IDENTITY: The output person MUST be the EXACT same person from Image 1. Copy their face pixel-for-pixel — same eyes, nose, mouth, jawline, skin tone, hair color, hair style, facial expression, body shape, weight, and proportions. Do NOT alter, beautify, slim, or reshape ANY aspect of the person. If the person in your output does not look identical to Image 1, the result is a failure.`,
    ``,
    `TASK: Identify clothing and shoes in Image 2, then dress the person from Image 1 in those items.`,
    ``,
    `STEP 1 — SCAN Image 2 carefully. List every wearable item you can see: tops, bottoms, dresses, jackets, outerwear, shoes/footwear, belts, scarves. Shoes are often at the bottom or corners of flat-lay images — look for them specifically.`,
    `IGNORE ONLY: Bags, purses, sunglasses, jewelry, hats, cups, phones, and other non-wearable objects.`,
    ``,
    `STEP 2 — DRESS the person from Image 1 in ALL identified items:`,
    `- Reproduce each piece with exact color, pattern, texture, material, and fit.`,
    `- Sleeve length: short stays short, long stays long, sleeveless stays sleeveless.`,
    `- Neckline: v-neck stays v-neck, crew stays crew, off-shoulder stays off-shoulder.`,
    `- Pants silhouette: wide-leg stays wide-leg, flared stays flared, straight stays straight. Pants length covers shoes if reference shows it.`,
    `- SHOES: Scan Image 2 for ANY footwear — flats, heels, sneakers, boots, sandals, ballet flats, loafers, etc. If shoes exist in Image 2, you MUST put them on the person's feet. Reproduce exact color, material, heel height, toe shape, sole style, laces, buckles. The person's feet MUST be visible and wearing the shoes — do NOT crop feet out. Turn one foot slightly outward to showcase. NEVER leave the person barefoot or in different shoes when footwear is present in Image 2.`,
    `- Tucking: Tuck the top into the waistband ONLY if a belt is clearly visible on the pants/skirt. No belt = untucked, hem falling naturally.`,
    ``,
    `CONTEXT: Keep Image 1's background, lighting, pose. Natural fabric draping. No outline/glow/halo.`,
    `OUTPUT: ONE single photo of ONE person wearing the COMPLETE outfit including shoes. Do NOT place any clothing items, shoes, or accessories as separate objects in the image corners or beside the person. Every item must be WORN on the person's body — nothing floating or placed next to them. Frame the photo HEAD TO TOE — the person's feet and shoes MUST be visible in the output.`
  ].join("\n");
}

async function uploadResultToR2(env, request, userId, bytes, mimeType) {
  const ext = mimeType === "image/png" ? "png" : mimeType === "image/webp" ? "webp" : "jpg";
  const key = `public/temp/tryon/${userId}/${Date.now()}.${ext}`;

  await env.STILYA_BUCKET.put(key, bytes, {
    httpMetadata: { contentType: mimeType },
  });

  // /assets/ route adds "public/" prefix, so strip it from the URL
  const urlPath = key.replace(/^public\//, "");
  return `${publicBaseUrl(env, request)}/assets/${urlPath}`;
}

/**
 * Persist a fal result and return the URL the app should download.
 * With an R2 bucket bound, the image is copied into it (fal was called with
 * sync_mode, so it never lands in fal's request history). Without one, the
 * fal CDN URL is returned as-is — handy for local development.
 */
async function storeResultImage(env, request, userId, result) {
  if (env.STILYA_BUCKET && result.bytes) {
    return uploadResultToR2(env, request, userId, result.bytes, result.mimeType);
  }
  if (result.url && !result.url.startsWith("data:")) return result.url;
  throw new Error("No storage available for inline fal result (bind STILYA_BUCKET)");
}

// ============================================================
// Generate Model Photo from Selfie (fal — image edit)
// ============================================================

async function handleGenerateModelPhoto(request, env, userId, clientInfo) {
  const bodyText = await request.text();
  if (bodyText.length > MAX_AI_REQUEST_SIZE) {
    return new Response(
      JSON.stringify({ error: "Request too large (max 20MB)" }),
      { status: 413, headers: { "Content-Type": "application/json" } }
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(bodyText);
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Validate required fields
  if (!parsed.selfie_image || typeof parsed.selfie_image !== "string" || !parsed.selfie_image.startsWith("data:image/")) {
    return new Response(
      JSON.stringify({ error: "selfie_image (base64 data URI) is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  const gender = parsed.gender || "unspecified"; // "female", "male", "unspecified"
  const hasBodyImage = parsed.body_image && typeof parsed.body_image === "string" && parsed.body_image.startsWith("data:image/");

  // Optional self-reported body measurements — a stronger, unambiguous proportion
  // signal than a single photo (a photo has no scale reference, so the model tends
  // to normalize everyone to runway proportions).
  const heightCm = (typeof parsed.height_cm === "number" && parsed.height_cm >= 120 && parsed.height_cm <= 220)
    ? Math.round(parsed.height_cm)
    : null;
  const allowedBodyTypes = ["slim", "average", "athletic", "curvy", "plus"];
  const bodyType = (typeof parsed.body_type === "string" && allowedBodyTypes.includes(parsed.body_type))
    ? parsed.body_type
    : null;

  // Parse additional selfies (max 2)
  let additionalSelfies = [];
  if (Array.isArray(parsed.additional_selfies)) {
    additionalSelfies = parsed.additional_selfies
      .filter(s => typeof s === "string" && s.startsWith("data:image/"))
      .slice(0, 2);
  }

  // Check FAL_KEY
  if (!env.FAL_KEY) {
    console.error("[generate-model] FAL_KEY not configured");
    return new Response(
      JSON.stringify({ error: "Service temporarily unavailable" }),
      { status: 503, headers: { "Content-Type": "application/json" } }
    );
  }

  // ── Credit deduction (only for profile regen, NOT onboarding) ──
  const MODEL_PHOTO_CREDIT_COST = 1;
  let creditsRemaining = 0;
  const isOnboarding = parsed.source === "onboarding";

  if (!isOnboarding && env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    try {
      const fsToken = await getFirestoreAccessToken(env);
      const docPath = `users/${userId}`;
      const txId = await firestoreBeginTransaction(fsToken);
      const txResult = await firestoreGetInTransaction(fsToken, docPath, txId);

      if (!txResult || !txResult.data) {
        await firestoreCommit(fsToken, txId, []);
        return new Response(
          JSON.stringify({ error: "User not found" }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }

      const deduction = computeCreditDeduction(txResult.data, MODEL_PHOTO_CREDIT_COST);
      if (!deduction) {
        await firestoreCommit(fsToken, txId, []);
        return new Response(
          JSON.stringify({ error: "Insufficient credits", required: MODEL_PHOTO_CREDIT_COST }),
          { status: 402, headers: { "Content-Type": "application/json" } }
        );
      }

      const write = buildUpdateWrite(docPath, deduction.fields);
      await firestoreCommit(fsToken, txId, [write]);
      creditsRemaining = deduction.totalRemaining;
      trackCreditUsage(env, userId, MODEL_PHOTO_CREDIT_COST);
    } catch (creditErr) {
      console.error(`[generate-model] Credit deduction error: ${creditErr.message}`);
      return new Response(
        JSON.stringify({ error: "Credit check failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  } else if (isOnboarding && env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    // Free onboarding generations are not charged credits, so meter them here.
    // Fail-open on a transient infra error (the 15/hr rate limit is the backstop) —
    // failing closed would block a paying-funnel user's onboarding on a Firestore hiccup.
    try {
      const limit = await checkModelPhotoLimit(env, userId);
      if (!limit.allowed) {
        return new Response(
          JSON.stringify({
            error: limit.isPro
              ? "Weekly model photo limit reached. Try again next week."
              : "Free model photo limit reached. Upgrade to Pro for more.",
            gen_remaining: 0,
            is_pro: limit.isPro,
          }),
          {
            status: 402,
            headers: {
              "Content-Type": "application/json",
              "X-Model-Gen-Remaining": "0",
              "Access-Control-Expose-Headers": "X-Model-Gen-Remaining",
            },
          }
        );
      }
    } catch (limitErr) {
      console.error(`[generate-model] limit check error (failing open): ${limitErr.message}`);
    }
  }

  // Build prompt
  const hasMultipleSelfies = additionalSelfies.length > 0;
  const prompt = buildModelPhotoPrompt(gender, hasBodyImage, hasMultipleSelfies, additionalSelfies.length, { heightCm, bodyType });

  // Selfies FIRST (earlier images weigh more for identity), then the body photo
  const imageDataUris = [parsed.selfie_image, ...additionalSelfies];
  if (hasBodyImage) imageDataUris.push(parsed.body_image);

  const model = falModelFor(env, "photo");
  const maxImageAttempts = 2;
  let result;
  for (let attempt = 1; attempt <= maxImageAttempts; attempt++) {
    result = await callFalImageEdit(env, {
      model, prompt, imageDataUris, aspectRatio: "9:16", keepBytes: !!env.STILYA_BUCKET, label: "generate-model",
    });
    // Safety filters and empty results are sometimes transient — retry once
    const retryable = !result.ok && (result.reason === "no_image" || result.reason === "safety");
    if (!retryable || attempt === maxImageAttempts) break;
    console.warn(`[generate-model] ${result.reason} (attempt ${attempt}/${maxImageAttempts}), retrying...`);
    await new Promise(r => setTimeout(r, 2000));
  }

  if (!result.ok) {
    console.error(`[generate-model] fal ${result.reason} for user ${userId}: ${result.detail || ""}`);
    if (!isOnboarding) await refundCredits(env, userId, MODEL_PHOTO_CREDIT_COST, `model_photo_${result.reason}`);
    return falErrorResponse(result, { safetyMessage: "Image was filtered for safety reasons. Please try a different photo." });
  }

  let resultUrl;
  try {
    resultUrl = await storeResultImage(env, request, userId, result);
  } catch (storeErr) {
    console.error(`[generate-model] Result storage error: ${storeErr.message}`);
    if (!isOnboarding) await refundCredits(env, userId, MODEL_PHOTO_CREDIT_COST, "model_photo_storage_error");
    return new Response(
      JSON.stringify({ error: "Failed to process AI response" }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    );
  }

  // Record the successful free generation and report the remaining allowance.
  let genRemaining = null;
  if (isOnboarding && env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    genRemaining = await incrementModelPhotoCount(env, userId);
  }

  const successHeaders = { "Content-Type": "application/json", "X-AI-Model": model };
  if (!isOnboarding) {
    successHeaders["X-Credits-Remaining"] = String(creditsRemaining);
    successHeaders["Access-Control-Expose-Headers"] = "X-Credits-Remaining";
  } else if (genRemaining !== null) {
    successHeaders["X-Model-Gen-Remaining"] = String(genRemaining);
    successHeaders["Access-Control-Expose-Headers"] = "X-Model-Gen-Remaining";
  }
  return new Response(
    JSON.stringify({ images: [{ url: resultUrl, content_type: result.mimeType }], gen_remaining: genRemaining }),
    { status: 200, headers: successHeaders }
  );
}

function buildModelPhotoPrompt(gender, hasBodyImage = false, hasMultipleSelfies = false, additionalSelfieCount = 0, measurements = {}) {
  // Calculate image numbering based on what's provided
  // Order: [selfie] [additional_selfie_1?] [additional_selfie_2?] [body_photo?]
  const selfieImageNum = 1;
  const totalSelfies = 1 + additionalSelfieCount;
  const bodyImageNum = hasBodyImage ? (totalSelfies + 1) : null;

  // Self-reported measurements — concrete, unambiguous proportion cues. A single
  // photo has no scale reference, so the model otherwise normalizes everyone to
  // tall runway proportions; explicit numbers anchor the real build.
  const heightCm = measurements.heightCm || null;
  const bodyTypeDescriptions = {
    slim: "slim / lean",
    average: "average / medium",
    athletic: "athletic / toned",
    curvy: "curvy / fuller-figured",
    plus: "plus-size / fuller-figured",
  };
  const bodyType = (measurements.bodyType && bodyTypeDescriptions[measurements.bodyType]) ? measurements.bodyType : null;
  const measurementLines = [];
  if (heightCm) {
    measurementLines.push(`- STATED HEIGHT: about ${heightCm} cm. Render the height and leg-to-torso ratio of a REAL ${heightCm} cm person. Do NOT elongate the legs or stretch the figure toward tall fashion-model proportions.`);
  }
  if (bodyType) {
    measurementLines.push(`- STATED BODY TYPE: ${bodyTypeDescriptions[bodyType]}. Match this build honestly — neither slimmer nor heavier.`);
  }
  const measurementSection = measurementLines.length
    ? `\nSELF-REPORTED MEASUREMENTS — TREAT AS GROUND TRUTH (override any conflicting read of the photo):\n${measurementLines.join("\n")}`
    : "";

  // Universal realism guard — real people, not runway idealization.
  const realismGuard = `\nCRITICAL — REALISM OVER IDEALIZATION: Produce everyday, real-person proportions, NOT editorial/runway fashion-model proportions. Do NOT heighten the person, elongate the legs, slim the waist, or broaden the shoulders beyond the reference. If in doubt, err toward an ordinary body, not an idealized one.`;

  // Body proportions — always from body photo (required by client)
  const bodyProportionsSection = (hasBodyImage
    ? `BODY PROPORTIONS — HIGH PRIORITY:
- Image ${bodyImageNum} is used ONLY as a body-shape reference. Extract from it the SILHOUETTE and PROPORTIONS — nothing else.
- You MUST replicate Image ${bodyImageNum}'s body shape:
  * Same HEIGHT — if the reference looks tall with long legs, generate long legs. Do NOT shorten them.
  * Same WEIGHT and BUILD — if slim, generate slim. If curvy, generate curvy. If athletic, generate athletic.
  * Same SHOULDER WIDTH — match exactly.
  * Same LEG-TO-TORSO RATIO — this is critical. Preserve it.
  * Same ARM LENGTH and THICKNESS.
- CRITICAL — DO NOT COPY FROM Image ${bodyImageNum}:
  * Do NOT copy its face, head, or hair — the face/head comes 100% from the selfie (Image ${selfieImageNum}${hasMultipleSelfies ? "–" + (selfieImageNum + additionalSelfieCount) : ""}).
  * Do NOT copy its skin tone — skin tone comes from the selfie.
  * Do NOT copy its clothing, colors, or patterns.
  * Do NOT copy its art style, rendering style, or texture — even if Image ${bodyImageNum} looks like an illustration, drawing, 3D render, or schematic, the OUTPUT must still be a photorealistic photograph. Image ${bodyImageNum} is just a shape reference, not a style reference.
  * Do NOT copy its background, lighting, or environment.
- COMMON MISTAKE TO AVOID: Do NOT default to average/medium proportions. LOOK at Image ${bodyImageNum} carefully and match its body silhouette.
- The generated body must match Image ${bodyImageNum}'s silhouette, but with the selfie's face, hair, and skin tone, wearing the outfit specified below, as a photorealistic photograph.`
    : `BODY PROPORTIONS:
- No body reference was provided. Generate a natural, average-proportioned body for this person based on their face and overall appearance.`) + measurementSection + realismGuard;

  // Multi-selfie identity section
  let multiSelfieSection = "";
  if (hasMultipleSelfies) {
    const selfieRange = [];
    for (let i = 0; i < totalSelfies; i++) {
      selfieRange.push(`Image ${selfieImageNum + i}`);
    }
    multiSelfieSection = `
MULTIPLE SELFIE REFERENCES — USE ALL OF THEM:
You are given ${totalSelfies} selfies (${selfieRange.join(", ")}) of the SAME person taken from random angles. Study ALL of them to build the most accurate face possible:
- Analyze every selfie equally — they are taken from random angles, not specifically front or side.
- Extract facial details from whichever selfie shows them most clearly: nose shape, eye shape and spacing, lip shape and thickness, jawline, eyebrow arch, forehead shape, ear shape, chin shape.
- Cross-reference ALL selfies to resolve ambiguities — if one selfie shows the nose more clearly, use that for nose shape. If another shows the jawline better, use that.
- The generated face must be consistent with ALL provided selfies, not just one.
- Pay special attention to: skin tone consistency, nose bridge width and tip shape, lip thickness, jawline angle, eyebrow arch, hair color/texture/style, and forehead shape.
`;
  }

  return `Edit this photo to show the same person in a full-body standing pose in a studio setting. This is NOT a celebrity — this is a regular person who uploaded their own photo for a virtual try-on fashion app.

${multiSelfieSection}
FACE — CRITICAL, HIGHEST PRIORITY:
This is the user's own face. They will compare the output directly to their selfie — any deviation will be noticed immediately.
You MUST produce a PIXEL-LEVEL IDENTICAL face from the input photo${hasMultipleSelfies ? "s" : ""}:
- NOSE: Exact same bridge width, tip shape (round/pointed/upturned/flat), nostril size and shape. This is the #1 feature users notice when wrong.
- EYES: Exact same shape (round/almond/hooded/monolid), spacing between eyes, eye color, eyelid crease depth, and under-eye area.
- LIPS: Exact same thickness (upper vs lower), cupid's bow shape, lip color, and mouth width.
- JAWLINE & CHIN: Exact same jaw angle (sharp/round/square), chin shape (pointed/round/cleft), and face width.
- EYEBROWS: Exact same arch, thickness, spacing, and color.
- FOREHEAD: Exact same height and shape.
- SKIN: Exact same tone, undertone, and texture. Preserve ALL marks, freckles, moles, scars, dimples, and asymmetries.
- HAIR: Exact same color, texture (straight/wavy/curly/coily), length, parting, and style.
- Do NOT beautify, slim, smooth, symmetrize, or idealize ANY feature. Real faces are asymmetric — keep the asymmetry.
- The output must look like a PHOTOGRAPH of the same person, not a similar-looking person.

${bodyProportionsSection}

OUTFIT — FORM-FITTING BY DESIGN (so body silhouette is clearly visible):
${hasBodyImage ? `Use Image ${bodyImageNum} for body proportions only — do NOT copy its clothing.` : ""}
The outfit MUST be form-fitting (not loose, not oversized, not baggy) so that the actual waist, hip, and leg shape is clearly visible in the output. This is important — do NOT use loose or draped fabric that hides the body silhouette.
If the person wears a hijab or head covering: preserve the hijab and dress them in a fitted (body-skimming) long-sleeve ribbed knit top in a neutral color AND fitted black leggings that cover to the ankle. The top should follow the body's natural contours without being tight or revealing — modest but form-fitting, not loose or oversized.
Otherwise: a fitted (body-skimming) plain white ribbed short-sleeve top that follows the natural waistline, fitted black leggings to the ankle, and plain white sneakers. No logos, no patterns, no accessories.
IMPORTANT: Do NOT invent or exaggerate body curves. The fitted clothing exists ONLY to reveal the person's true silhouette${hasBodyImage ? ` as shown in Image ${bodyImageNum}` : ""} — keep the waist, hips, and build EXACTLY as in the reference, neither slimmer nor curvier.

POSE: Standing naturally, arms at sides, facing camera, full body head to feet in 9:16 frame.

BACKGROUND: Clean light gray studio background, soft even lighting.

Output a photorealistic photograph, not an illustration.`;
}

async function handleTryOn(request, env, userId, clientInfo) {
  const bodyText = await request.text();
  if (bodyText.length > MAX_AI_REQUEST_SIZE) {
    return new Response(
      JSON.stringify({ error: "Request too large (max 20MB)" }),
      { status: 413, headers: { "Content-Type": "application/json" } }
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(bodyText);
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Validate required fields
  const isOutfitMode = parsed.mode === "outfit";

  if (isOutfitMode) {
    // Outfit mode: person_image + outfit_image required
    if (!parsed.person_image || !parsed.outfit_image) {
      return new Response(
        JSON.stringify({ error: "person_image and outfit_image are required for outfit mode" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    if (!parsed.outfit_image.startsWith("data:image/")) {
      return new Response(
        JSON.stringify({ error: "Only base64 data URIs allowed for outfit_image" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
  } else {
    // Normal mode: person_image + garment_images required
    if (!parsed.person_image || !parsed.garment_images || !Array.isArray(parsed.garment_images) || parsed.garment_images.length === 0) {
      return new Response(
        JSON.stringify({ error: "person_image and garment_images array are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    for (const g of parsed.garment_images) {
      if (!g.data || !g.data.startsWith("data:image/")) {
        return new Response(
          JSON.stringify({ error: "Only base64 data URIs allowed for garment images" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }
    }
  }

  // SSRF protection: only base64 data URIs
  if (!parsed.person_image.startsWith("data:image/")) {
    return new Response(
      JSON.stringify({ error: "Only base64 data URIs allowed" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Check FAL_KEY
  if (!env.FAL_KEY) {
    console.error("[tryon] FAL_KEY not configured");
    return new Response(
      JSON.stringify({ error: "Service temporarily unavailable" }),
      { status: 503, headers: { "Content-Type": "application/json" } }
    );
  }

  // ── Credit deduction (server-side, atomic) ──
  // A/B test: skip credits only for server-side whitelisted users (KV-backed)
  let skipCredits = false;
  if (parsed.ab_test === true && env.STILYA_KV) {
    const isWhitelisted = await env.STILYA_KV.get(`abtest:${userId}`);
    skipCredits = isWhitelisted === "true";
    if (!skipCredits) {
      console.warn(`[tryon] ab_test requested but user ${userId} is NOT whitelisted — charging credits`);
    }
  }
  const garmentCount = isOutfitMode ? 1 : (Array.isArray(parsed.garment_images) ? parsed.garment_images.length : 0);
  const creditCost = isOutfitMode ? CREDIT_CONSTANTS.singleTryOnCost : (garmentCount <= 1 ? CREDIT_CONSTANTS.singleTryOnCost : CREDIT_CONSTANTS.comboBaseCost);
  let creditsRemaining = 0;

  if (env.GOOGLE_SERVICE_ACCOUNT_JSON && !skipCredits) {
    try {
      const fsToken = await getFirestoreAccessToken(env);
      const docPath = `users/${userId}`;
      const txId = await firestoreBeginTransaction(fsToken);
      const txResult = await firestoreGetInTransaction(fsToken, docPath, txId);

      if (!txResult || !txResult.data) {
        await firestoreCommit(fsToken, txId, []);
        return new Response(
          JSON.stringify({ error: "User not found" }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }

      const deduction = computeCreditDeduction(txResult.data, creditCost);
      if (!deduction) {
        await firestoreCommit(fsToken, txId, []);
        return new Response(
          JSON.stringify({ error: "Insufficient credits", required: creditCost }),
          { status: 402, headers: { "Content-Type": "application/json" } }
        );
      }

      const write = buildUpdateWrite(docPath, deduction.fields);
      await firestoreCommit(fsToken, txId, [write]);
      creditsRemaining = deduction.totalRemaining;
      trackCreditUsage(env, userId, creditCost);
    } catch (creditErr) {
      console.error(`[tryon] Credit deduction error: ${creditErr.message}`);
      return new Response(
        JSON.stringify({ error: "Credit check failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  }

  // Prompt — Image 1 is always the person, garments follow in order
  const prompt = isOutfitMode
    ? buildOutfitReplicationPrompt()
    : buildNanoBananaPrompt(parsed.garment_images, parsed.top_tucked_in);

  const imageDataUris = [parsed.person_image];
  if (isOutfitMode) {
    imageDataUris.push(parsed.outfit_image);
  } else {
    for (const g of parsed.garment_images) imageDataUris.push(g.data);
  }

  // Model selection: outfit mode (one flat-lay → many items) needs the stronger model
  const tier = (parsed.model === "pro" || (isOutfitMode && parsed.model !== "flash")) ? "pro" : "default";
  const model = falModelFor(env, tier);

  let result = await callFalImageEdit(env, {
    model, prompt, imageDataUris, aspectRatio: "3:4", keepBytes: !!env.STILYA_BUCKET, label: "tryon",
  });

  // Image-edit models occasionally return no image — retry once
  if (!result.ok && result.reason === "no_image") {
    console.warn(`[tryon] No image in first response, retrying once...`);
    await new Promise(r => setTimeout(r, 2000));
    result = await callFalImageEdit(env, {
      model, prompt, imageDataUris, aspectRatio: "3:4", keepBytes: !!env.STILYA_BUCKET, label: "tryon-retry",
    });
  }

  if (!result.ok) {
    console.error(`[tryon] fal ${result.reason} for user ${userId}: ${result.detail || ""}`);
    await refundCredits(env, userId, creditCost, `fal_${result.reason}`);
    return falErrorResponse(result);
  }

  try {
    const resultUrl = await storeResultImage(env, request, userId, result);
    return new Response(JSON.stringify({ images: [{ url: resultUrl, content_type: result.mimeType }] }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "X-Credits-Remaining": String(creditsRemaining),
        "X-AI-Model": model,
      },
    });
  } catch (storeErr) {
    console.error(`[tryon] Result storage error: ${storeErr.message}`);
    await refundCredits(env, userId, creditCost, "result_storage_error");
    return new Response(
      JSON.stringify({ error: "Failed to process AI response" }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    );
  }
}

// ============================================================
// Admin API Handlers
// ============================================================

function withCorsAdmin(response, request) {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders(request))) {
    headers.set(key, value);
  }
  return new Response(response.body, { status: response.status, headers });
}

function verifyAdminKey(url, env) {
  const adminKey = url.searchParams.get("key");
  if (!env.ADMIN_SECRET || adminKey !== env.ADMIN_SECRET) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  return null;
}

async function handleAdminGetUser(url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const parts = url.pathname.split("/");
  const uid = decodeURIComponent(parts[3]); // /admin/user/:uid
  if (!uid) {
    return new Response(JSON.stringify({ error: "Missing UID" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const token = await getFirestoreAccessToken(env);

  // If uid contains "@", search by email; otherwise treat as UID
  if (uid.includes("@")) {
    return await adminSearchUserByField(token, "email", uid);
  }

  const user = await firestoreGet(token, `users/${uid}`);
  return new Response(JSON.stringify({ user, uid }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

async function handleAdminSearchUser(url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const query = url.searchParams.get("q");
  const field = url.searchParams.get("field") || "displayName";
  if (!query) {
    return new Response(JSON.stringify({ error: "Missing ?q= parameter" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const token = await getFirestoreAccessToken(env);
  return await adminSearchUserByField(token, field, query);
}

async function adminSearchUserByField(token, field, value) {
  const queryUrl = `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents:runQuery`;
  const response = await fetch(queryUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "users" }],
        where: {
          fieldFilter: {
            field: { fieldPath: field },
            op: "EQUAL",
            value: { stringValue: value },
          },
        },
        limit: 10,
      },
    }),
  });

  if (!response.ok) {
    return new Response(JSON.stringify({ error: "Firestore query failed" }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }

  const results = await response.json();
  const users = Array.isArray(results)
    ? results.filter(r => r.document).map(r => {
        const doc = fromFirestoreDoc(r.document);
        const docPath = r.document.name.split("/");
        const uid = docPath[docPath.length - 1];
        return { ...doc, _uid: uid };
      })
    : [];

  if (users.length === 1) {
    return new Response(JSON.stringify({ user: users[0], uid: users[0]._uid }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ users, count: users.length }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

async function handleAdminCredits(request, url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const { uid, action, type, amount } = await request.json();
  if (!uid || !action || !type || amount === undefined) {
    return new Response(JSON.stringify({ error: "Missing fields: uid, action, type, amount" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const fieldName = type === "purchasedCredits" ? "purchasedCredits" : "credits";
  const token = await getFirestoreAccessToken(env);

  let newValue = amount;
  if (action === "add") {
    const user = await firestoreGet(token, `users/${uid}`);
    if (!user) {
      return new Response(JSON.stringify({ error: "User not found" }), {
        status: 404, headers: { "Content-Type": "application/json" },
      });
    }
    newValue = (user[fieldName] || 0) + amount;
  }

  const write = buildUpdateWrite(`users/${uid}`, { [fieldName]: newValue });
  await firestoreCommit(token, null, [write]);

  return new Response(JSON.stringify({
    success: true,
    message: `${fieldName} ${action === "add" ? "+" + amount + " → " : "→ "}${newValue} (uid: ${uid})`,
  }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

async function handleAdminBan(request, url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const { target, type } = await request.json();
  if (!target || !type) {
    return new Response(JSON.stringify({ error: "Missing target or type" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const kvKey = type === "ip" ? "banned_ips" : "banned_users";
  const memorySet = type === "ip" ? bannedIPs : bannedUsers;

  let list = await env.STILYA_KV.get(kvKey, "json") || [];
  if (!list.includes(target)) {
    list.push(target);
    await env.STILYA_KV.put(kvKey, JSON.stringify(list));
    memorySet.add(target);
  }

  return new Response(JSON.stringify({
    success: true,
    message: `${type === "ip" ? "IP" : "User"} banlandı: ${target}`,
  }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

async function handleAdminUnban(request, url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const { target, type } = await request.json();
  if (!target || !type) {
    return new Response(JSON.stringify({ error: "Missing target or type" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const kvKey = type === "ip" ? "banned_ips" : "banned_users";
  const memorySet = type === "ip" ? bannedIPs : bannedUsers;

  let list = await env.STILYA_KV.get(kvKey, "json") || [];
  list = list.filter(item => item !== target);
  await env.STILYA_KV.put(kvKey, JSON.stringify(list));
  memorySet.delete(target);

  return new Response(JSON.stringify({
    success: true,
    message: `${type === "ip" ? "IP" : "User"} unban edildi: ${target}`,
  }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

async function handleAdminGetConfig(url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  // KV override'larını oku (varsa)
  let disableApp = env.DISABLE_APP;
  let disableModelPhoto = env.DISABLE_MODEL_PHOTO;
  let debugMode = env.IS_DEBUG;
  let maintenanceMsg = env.MAINTENANCE_MESSAGE;

  if (env.STILYA_KV) {
    const kvDisableApp = await env.STILYA_KV.get("config:DISABLE_APP");
    const kvDisableModel = await env.STILYA_KV.get("config:DISABLE_MODEL_PHOTO");
    const kvDebug = await env.STILYA_KV.get("config:IS_DEBUG");
    const kvMaint = await env.STILYA_KV.get("config:MAINTENANCE_MESSAGE");
    if (kvDisableApp !== null) disableApp = kvDisableApp;
    if (kvDisableModel !== null) disableModelPhoto = kvDisableModel;
    if (kvDebug !== null) debugMode = kvDebug;
    if (kvMaint !== null) maintenanceMsg = kvMaint;
  }

  return new Response(JSON.stringify({
    appEnabled: disableApp !== "true",
    modelPhotoEnabled: disableModelPhoto !== "true",
    debugMode: debugMode === "true",
    maintenanceMessage: maintenanceMsg || null,
    freeWeeklyCredits: CREDIT_CONSTANTS.freeWeeklyCredits,
    trialCredits: CREDIT_CONSTANTS.trialCredits,
    proWeeklyCredits: CREDIT_CONSTANTS.proWeeklyCredits,
    rateLimitPerHour: RATE_LIMIT_PER_HOUR,
  }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

async function handleAdminSetConfig(request, url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const { key, value } = await request.json();
  const allowedKeys = ["DISABLE_APP", "DISABLE_MODEL_PHOTO", "IS_DEBUG", "MAINTENANCE_MESSAGE", "FREE_WEEKLY_CREDITS", "TRIAL_CREDITS", "PRO_WEEKLY_CREDITS", "RATE_LIMIT_PER_HOUR"];
  if (!allowedKeys.includes(key)) {
    return new Response(JSON.stringify({ error: "Invalid config key: " + key }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  // KV'ye kaydet — worker restart'larında korunur
  if (env.STILYA_KV) {
    await env.STILYA_KV.put("config:" + key, value);
  }

  // Runtime'da güncelle (bu worker instance için)
  if (key === "IS_DEBUG") IS_DEBUG = value === "true";
  if (key === "FREE_WEEKLY_CREDITS") {
    const parsed = parseInt(value, 10);
    if (!isNaN(parsed) && parsed >= 0) CREDIT_CONSTANTS.freeWeeklyCredits = parsed;
  }
  if (key === "TRIAL_CREDITS") {
    const parsed = parseInt(value, 10);
    if (!isNaN(parsed) && parsed >= 0) CREDIT_CONSTANTS.trialCredits = parsed;
  }
  if (key === "PRO_WEEKLY_CREDITS") {
    const parsed = parseInt(value, 10);
    if (!isNaN(parsed) && parsed > 0) {
      CREDIT_CONSTANTS.proWeeklyCredits = parsed;
      CREDIT_CONSTANTS.proMonthlyCredits = parsed;
    }
  }
  if (key === "RATE_LIMIT_PER_HOUR") {
    const parsed = parseInt(value, 10);
    if (!isNaN(parsed) && parsed >= 0) RATE_LIMIT_PER_HOUR = parsed;
  }

  return new Response(JSON.stringify({
    success: true,
    message: `${key} = ${value} (KV'ye kaydedildi — sonraki deploy'da wrangler.jsonc'den override edilir)`,
  }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

async function handleAdminRateLimit(request, url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const { uid, limit } = await request.json();
  if (!uid || limit === undefined) {
    return new Response(JSON.stringify({ error: "Missing uid or limit" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const parsedLimit = parseInt(limit, 10);
  if (isNaN(parsedLimit) || parsedLimit < 0) {
    return new Response(JSON.stringify({ error: "Limit must be >= 0" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  if (parsedLimit === -1) {
    // Remove override → user falls back to global limit
    await env.STILYA_KV.delete(`ratelimit:override:${uid}`);
    return new Response(JSON.stringify({
      success: true,
      message: `Rate limit override kaldırıldı (uid: ${uid}), genel limit uygulanacak: ${RATE_LIMIT_PER_HOUR}/saat`,
    }), { status: 200, headers: { "Content-Type": "application/json" } });
  }

  await env.STILYA_KV.put(`ratelimit:override:${uid}`, String(parsedLimit));
  return new Response(JSON.stringify({
    success: true,
    message: `Rate limit override: ${parsedLimit}/saat (uid: ${uid})${parsedLimit === 0 ? " — TAMAMEN ENGELLENDİ" : ""}`,
  }), { status: 200, headers: { "Content-Type": "application/json" } });
}

async function handleAdminGetRateLimit(url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const uid = url.pathname.split("/").pop();
  if (!uid) {
    return new Response(JSON.stringify({ error: "Missing uid" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  if (!env.STILYA_KV) {
    return new Response(JSON.stringify({ error: "KV not configured" }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
  const override = await env.STILYA_KV.get(`ratelimit:override:${uid}`);
  const hour = new Date().toISOString().slice(0, 13);
  const usage = parseInt(await env.STILYA_KV.get(`ratelimit:${uid}:${hour}`) || "0", 10);
  const effectiveLimit = override !== null ? parseInt(override, 10) : RATE_LIMIT_PER_HOUR;

  return new Response(JSON.stringify({
    uid,
    globalLimit: RATE_LIMIT_PER_HOUR,
    userOverride: override !== null ? parseInt(override, 10) : null,
    effectiveLimit,
    usageThisHour: usage,
    remaining: Math.max(0, effectiveLimit - usage),
  }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// ============================================================
// Admin A/B Test Whitelist
// ============================================================

/**
 * POST /admin/abtest — Add/remove user from A/B test whitelist
 * Body: { uid: string, enabled: boolean }
 * When enabled=true, user can send ab_test=true to skip credits
 */
async function handleAdminABTest(request, url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  if (!env.STILYA_KV) {
    return new Response(JSON.stringify({ error: "KV not configured" }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }

  const { uid, enabled, ttlDays } = await request.json();
  if (!uid) {
    return new Response(JSON.stringify({ error: "Missing uid" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  if (enabled) {
    // Default 7 gün TTL, max 30 gün — kalıcı whitelist önlenir
    const days = Math.min(Math.max(ttlDays || 7, 1), 30);
    const ttlSeconds = days * 24 * 60 * 60;
    await env.STILYA_KV.put(`abtest:${uid}`, "true", { expirationTtl: ttlSeconds });
  } else {
    await env.STILYA_KV.delete(`abtest:${uid}`);
  }

  const expiryDays = enabled ? Math.min(Math.max(ttlDays || 7, 1), 30) : 0;
  return new Response(JSON.stringify({
    success: true,
    message: enabled
      ? `A/B test whitelist: ${uid} EKLENDİ (${expiryDays} gün) — kredi düşmeden test yapabilir`
      : `A/B test whitelist: ${uid} KALDIRILDI`,
  }), { status: 200, headers: { "Content-Type": "application/json" } });
}

/**
 * GET /admin/abtest/:uid — Check if user is whitelisted
 */
async function handleAdminGetABTest(url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const uid = url.pathname.split("/").pop();
  if (!uid) {
    return new Response(JSON.stringify({ error: "Missing uid" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  if (!env.STILYA_KV) {
    return new Response(JSON.stringify({ error: "KV not configured" }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }

  const isWhitelisted = await env.STILYA_KV.get(`abtest:${uid}`);
  return new Response(JSON.stringify({
    uid,
    whitelisted: isWhitelisted === "true",
  }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// ============================================================
// Admin Trend Collections
// ============================================================

/**
 * Parse multipart/form-data from a Request.
 * Returns { fields: { name: string }, files: { name: { data: ArrayBuffer, type: string, filename: string } } }
 */
async function parseMultipartFormData(request) {
  const contentType = request.headers.get("Content-Type") || "";
  const boundaryMatch = contentType.match(/boundary=(.+)/);
  if (!boundaryMatch) throw new Error("No boundary in Content-Type");

  const boundary = boundaryMatch[1];
  const raw = await request.arrayBuffer();
  const bytes = new Uint8Array(raw);
  const decoder = new TextDecoder();

  const boundaryBytes = new TextEncoder().encode("--" + boundary);
  const fields = {};
  const files = {};

  // Find all boundary positions
  const positions = [];
  for (let i = 0; i < bytes.length - boundaryBytes.length; i++) {
    let match = true;
    for (let j = 0; j < boundaryBytes.length; j++) {
      if (bytes[i + j] !== boundaryBytes[j]) { match = false; break; }
    }
    if (match) positions.push(i);
  }

  for (let p = 0; p < positions.length - 1; p++) {
    const start = positions[p] + boundaryBytes.length;
    const end = positions[p + 1];
    const part = bytes.slice(start, end);

    // Find header/body separator (\r\n\r\n)
    let headerEnd = -1;
    for (let i = 0; i < part.length - 3; i++) {
      if (part[i] === 13 && part[i+1] === 10 && part[i+2] === 13 && part[i+3] === 10) {
        headerEnd = i;
        break;
      }
    }
    if (headerEnd === -1) continue;

    const headerStr = decoder.decode(part.slice(0, headerEnd));
    const body = part.slice(headerEnd + 4, part.length - 2); // strip trailing \r\n

    const nameMatch = headerStr.match(/name="([^"]+)"/);
    if (!nameMatch) continue;
    const name = nameMatch[1];

    const filenameMatch = headerStr.match(/filename="([^"]+)"/);
    if (filenameMatch) {
      const typeMatch = headerStr.match(/Content-Type:\s*(\S+)/i);
      files[name] = {
        data: body.buffer.slice(body.byteOffset, body.byteOffset + body.byteLength),
        type: typeMatch ? typeMatch[1] : "application/octet-stream",
        filename: filenameMatch[1],
      };
    } else {
      fields[name] = decoder.decode(body);
    }
  }
  return { fields, files };
}

/**
 * Create a new trend collection with images
 * POST /admin/trends — multipart/form-data
 */
async function handleAdminCreateTrend(request, url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const { fields, files } = await parseMultipartFormData(request);

  const titleTR = fields.titleTR || "";
  const titleEN = fields.titleEN || "";
  const category = fields.category || "casual";
  const gender = fields.gender || "unisex";
  const tags = fields.tags ? fields.tags.split(",").map(t => t.trim()).filter(Boolean) : [];
  const sortOrder = parseInt(fields.sortOrder || "0", 10);

  // Collect image files (image_0, image_1, ... or any key starting with "image")
  const imageFiles = Object.entries(files)
    .filter(([key]) => key.startsWith("image"))
    .sort(([a], [b]) => a.localeCompare(b));

  if (imageFiles.length === 0) {
    return new Response(JSON.stringify({ error: "At least one image is required" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const collectionId = crypto.randomUUID();
  const imageUrls = [];

  // Upload each image to R2
  for (let i = 0; i < imageFiles.length; i++) {
    const [, file] = imageFiles[i];
    const ext = file.type === "image/png" ? "png" : "jpg";
    const r2Key = `public/trends/${collectionId}/${i}.${ext}`;
    await env.STILYA_BUCKET.put(r2Key, file.data, {
      httpMetadata: { contentType: file.type },
    });
    imageUrls.push(r2Key);
  }

  // Write to Firestore
  const now = new Date();
  const token = await getFirestoreAccessToken(env);
  const docFields = {
    id: collectionId,
    titleTR,
    titleEN,
    category,
    gender,
    tags,
    imageUrls,
    isActive: true,
    sortOrder,
    createdAt: now,
    updatedAt: now,
  };

  const firestoreFields = {};
  for (const [key, value] of Object.entries(docFields)) {
    firestoreFields[key] = toFirestoreValue(value);
  }

  // Use createDocument via REST
  const createUrl = `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents/trendCollections?documentId=${collectionId}`;
  const createRes = await fetch(createUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields: firestoreFields }),
  });

  if (!createRes.ok) {
    const errText = await createRes.text();
    throw new Error(`Firestore create failed: ${createRes.status} ${errText}`);
  }

  return new Response(JSON.stringify({
    success: true,
    id: collectionId,
    imageCount: imageUrls.length,
    message: `Koleksiyon oluşturuldu: ${imageUrls.length} görsel`,
  }), { status: 200, headers: { "Content-Type": "application/json" } });
}

/**
 * List all trend collections
 * GET /admin/trends
 */
async function handleAdminListTrends(url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const token = await getFirestoreAccessToken(env);
  const queryUrl = `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents:runQuery`;
  const response = await fetch(queryUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "trendCollections" }],
        orderBy: [{ field: { fieldPath: "sortOrder" }, direction: "ASCENDING" }],
      },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Firestore query failed: ${response.status} ${errText}`);
  }

  const results = await response.json();
  const collections = results
    .filter(r => r.document)
    .map(r => fromFirestoreDoc(r.document));

  return new Response(JSON.stringify({ collections }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

/**
 * Update a trend collection
 * PUT /admin/trends/:id
 */
async function handleAdminUpdateTrend(request, url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const trendId = url.pathname.split("/").pop();
  if (!trendId) {
    return new Response(JSON.stringify({ error: "Missing trend ID" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const updates = await request.json();
  updates.updatedAt = new Date();

  const token = await getFirestoreAccessToken(env);
  const write = buildUpdateWrite(`trendCollections/${trendId}`, updates);
  await firestoreCommit(token, null, [write]);

  return new Response(JSON.stringify({
    success: true,
    message: "Koleksiyon güncellendi",
  }), { status: 200, headers: { "Content-Type": "application/json" } });
}

/**
 * Delete a trend collection and its R2 images
 * DELETE /admin/trends/:id
 */
async function handleAdminDeleteTrend(url, env) {
  const denied = verifyAdminKey(url, env);
  if (denied) return denied;

  const trendId = url.pathname.split("/").pop();
  if (!trendId) {
    return new Response(JSON.stringify({ error: "Missing trend ID" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const token = await getFirestoreAccessToken(env);

  // Read document to get image paths
  const doc = await firestoreGet(token, `trendCollections/${trendId}`);
  if (doc && doc.imageUrls && doc.imageUrls.length > 0) {
    // Delete all R2 images
    await env.STILYA_BUCKET.delete(doc.imageUrls);
  }

  // Delete Firestore document
  const deleteUrl = firestoreDocURL(`trendCollections/${trendId}`);
  await fetch(deleteUrl, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${token}` },
  });

  return new Response(JSON.stringify({
    success: true,
    message: "Koleksiyon silindi",
  }), { status: 200, headers: { "Content-Type": "application/json" } });
}

/**
 * Public endpoint: fetch active trend collections (paginated)
 * GET /api/trends?gender=female&page=1&limit=10
 */
async function handlePublicGetTrends(url, env) {
  const token = await getFirestoreAccessToken(env);
  const gender = url.searchParams.get("gender");
  const page = Math.max(1, parseInt(url.searchParams.get("page") || "1", 10));
  const limit = Math.min(50, Math.max(1, parseInt(url.searchParams.get("limit") || "10", 10)));

  const queryUrl = `https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/(default)/documents:runQuery`;
  const response = await fetch(queryUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "trendCollections" }],
        where: {
          fieldFilter: {
            field: { fieldPath: "isActive" },
            op: "EQUAL",
            value: { booleanValue: true },
          },
        },
        orderBy: [{ field: { fieldPath: "sortOrder" }, direction: "ASCENDING" }],
      },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Firestore query failed: ${response.status} ${errText}`);
  }

  const results = await response.json();
  let collections = results
    .filter(r => r.document)
    .map(r => {
      const data = fromFirestoreDoc(r.document);
      // Convert R2 paths to public URLs
      if (data.imageUrls) {
        data.imageUrls = data.imageUrls.map(path =>
          `${publicBaseUrl(env, url)}/assets/${path.replace("public/", "")}`
        );
      }
      return data;
    });

  // In-memory gender filter (include unisex)
  if (gender) {
    collections = collections.filter(c => c.gender === gender || c.gender === "unisex");
  }

  // Pagination
  const totalCount = collections.length;
  const startIndex = (page - 1) * limit;
  const paginatedCollections = collections.slice(startIndex, startIndex + limit);
  const hasMore = startIndex + limit < totalCount;

  return new Response(JSON.stringify({
    collections: paginatedCollections,
    totalCount,
    page,
    limit,
    hasMore,
  }), {
    status: 200,
    headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=60" },
  });
}

// ============================================================
// ============================================================
// Main Worker
// ============================================================

export default {
  async fetch(request, env, ctx) {
    // Set debug mode from environment variable
    IS_DEBUG = env.IS_DEBUG === "true";
    if (env.FIREBASE_PROJECT_ID) FIRESTORE_PROJECT_ID = env.FIREBASE_PROJECT_ID;
    FIREBASE_PROJECT_NUMBER = env.FIREBASE_PROJECT_NUMBER || "";

    // Ban listesini + config override'larını KV'den yükle
    if (env.STILYA_KV && bannedIPs.size === 0 && bannedUsers.size === 0) {
      await loadBanLists(env);
    }
    if (env.STILYA_KV) {
      const [kvFreeCredits, kvTrialCredits, kvProCredits, kvRateLimit] = await Promise.all([
        env.STILYA_KV.get("config:FREE_WEEKLY_CREDITS"),
        env.STILYA_KV.get("config:TRIAL_CREDITS"),
        env.STILYA_KV.get("config:PRO_WEEKLY_CREDITS"),
        env.STILYA_KV.get("config:RATE_LIMIT_PER_HOUR"),
      ]);
      if (kvFreeCredits !== null) {
        const parsed = parseInt(kvFreeCredits, 10);
        if (!isNaN(parsed) && parsed >= 0) CREDIT_CONSTANTS.freeWeeklyCredits = parsed;
      }
      if (kvTrialCredits !== null) {
        const parsed = parseInt(kvTrialCredits, 10);
        if (!isNaN(parsed) && parsed >= 0) CREDIT_CONSTANTS.trialCredits = parsed;
      }
      if (kvProCredits !== null) {
        const parsed = parseInt(kvProCredits, 10);
        if (!isNaN(parsed) && parsed > 0) {
          CREDIT_CONSTANTS.proWeeklyCredits = parsed;
          CREDIT_CONSTANTS.proMonthlyCredits = parsed;
        }
      }
      if (kvRateLimit !== null) {
        const parsed = parseInt(kvRateLimit, 10);
        if (!isNaN(parsed) && parsed >= 0) RATE_LIMIT_PER_HOUR = parsed;
      }
    }

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders(request) });
    }

    const url = new URL(request.url);
    const clientInfo = getClientInfo(request);

    // IP ban kontrolü — auth'dan ÖNCE (hesap açmaya gerek yok)
    const banReason = isBanned(clientInfo.ip, null);
    if (banReason && url.pathname !== "/health" && url.pathname !== "/stats" && url.pathname !== "/privacy" && url.pathname !== "/terms" && !url.pathname.startsWith("/admin")) {
      return new Response(
        JSON.stringify({ error: "Access denied" }),
        { status: 403, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }

    // Health check (no auth needed)
    if (url.pathname === "/health") {
      return new Response(
        JSON.stringify({ status: "ok", service: "stilya-worker" }),
        { headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }

    // ── Public Assets (no auth needed, served from R2 public/ prefix) ──
    if (url.pathname.startsWith("/assets/")) {
      const assetKey = "public/" + url.pathname.slice(8); // /assets/home.png → public/home.jpg
      const object = await env.STILYA_BUCKET.get(assetKey);
      if (!object) {
        return new Response("Not found", { status: 404 });
      }
      return new Response(object.body, {
        headers: {
          "Content-Type": object.httpMetadata?.contentType || "image/jpeg",
          "Cache-Control": "public, max-age=2592000", // 30 days
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    // ── Public Pages (no auth needed) ──
    if (url.pathname === "/" && !url.hostname.startsWith("api.")) {
      return new Response(LANDING_PAGE_HTML, {
        headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" },
      });
    }

    if (url.pathname === "/privacy") {
      return new Response(PRIVACY_POLICY_HTML, {
        headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=86400" },
      });
    }

    if (url.pathname === "/terms") {
      return new Response(TERMS_OF_USE_HTML, {
        headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=86400" },
      });
    }

    // Stats endpoint (admin only — secret key ile korunuyor)
    if (url.pathname === "/stats" && request.method === "GET") {
      const adminKey = url.searchParams.get("key");
      if (!env.ADMIN_SECRET || adminKey !== env.ADMIN_SECRET) {
        return new Response(
          JSON.stringify({ error: "Forbidden" }),
          { status: 403, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
        );
      }

      // Gather usage stats from KV
      let weeklyTotal = 0, dailyTotal = 0, activeUsers = 0, avgPerUser = 0, topUsers = [];
      if (env.STILYA_KV) {
        const now = new Date();
        const weekNum = getISOWeek(now);
        const weekKey = `${now.getFullYear()}-W${String(weekNum).padStart(2, "0")}`;
        const dayKey = now.toISOString().slice(0, 10);

        const [wkRaw, dayRaw, usersRaw] = await Promise.all([
          env.STILYA_KV.get(`stats:weekly:${weekKey}`),
          env.STILYA_KV.get(`stats:daily:${dayKey}`),
          env.STILYA_KV.get(`stats:weekly:${weekKey}:users`),
        ]);

        weeklyTotal = parseInt(wkRaw || "0", 10);
        dailyTotal = parseInt(dayRaw || "0", 10);

        if (usersRaw) {
          const userIds = JSON.parse(usersRaw);
          activeUsers = userIds.length;
          avgPerUser = activeUsers > 0 ? Math.round(weeklyTotal / activeUsers * 10) / 10 : 0;

          // Top 10 users by weekly usage
          const userUsages = await Promise.all(
            userIds.map(async (uid) => {
              const val = await env.STILYA_KV.get(`stats:user:${uid}:${weekKey}`);
              return { uid, used: parseInt(val || "0", 10) };
            })
          );
          topUsers = userUsages.sort((a, b) => b.used - a.used).slice(0, 10);
        }
      }

      // Estimated weekly API cost ($0.067 per credit for Flash)
      const estWeeklyCost = Math.round(weeklyTotal * 0.067 * 100) / 100;

      return new Response(
        JSON.stringify({
          status: "ok",
          service: "stilya-worker",
          bannedIPs: bannedIPs.size,
          bannedUsers: bannedUsers.size,
          usage: {
            today: dailyTotal,
            thisWeek: weeklyTotal,
            activeUsersThisWeek: activeUsers,
            avgCreditsPerUser: avgPerUser,
            estWeeklyCostUSD: estWeeklyCost,
            topUsers,
          },
        }, null, 2),
        { headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }

    // ── Admin Panel & API (ADMIN_SECRET ile korunuyor) ──
    if (url.pathname === "/admin" && request.method === "GET") {
      return new Response(ADMIN_PANEL_HTML, {
        headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" },
      });
    }

    if (url.pathname.startsWith("/admin/")) {
      const corsH = { ...corsHeaders(request), "Content-Type": "application/json" };
      try {
        if (url.pathname === "/admin/search" && request.method === "GET") {
          return withCorsAdmin(await handleAdminSearchUser(url, env), request);
        }
        if (url.pathname.startsWith("/admin/user/") && request.method === "GET") {
          return withCorsAdmin(await handleAdminGetUser(url, env), request);
        }
        if (url.pathname === "/admin/credits" && request.method === "POST") {
          return withCorsAdmin(await handleAdminCredits(request, url, env), request);
        }
        if (url.pathname === "/admin/ban" && request.method === "POST") {
          return withCorsAdmin(await handleAdminBan(request, url, env), request);
        }
        if (url.pathname === "/admin/unban" && request.method === "POST") {
          return withCorsAdmin(await handleAdminUnban(request, url, env), request);
        }
        if (url.pathname === "/admin/config" && request.method === "GET") {
          return withCorsAdmin(await handleAdminGetConfig(url, env), request);
        }
        if (url.pathname === "/admin/config" && request.method === "POST") {
          return withCorsAdmin(await handleAdminSetConfig(request, url, env), request);
        }
        if (url.pathname === "/admin/ratelimit" && request.method === "POST") {
          return withCorsAdmin(await handleAdminRateLimit(request, url, env), request);
        }
        if (url.pathname.startsWith("/admin/ratelimit/") && request.method === "GET") {
          return withCorsAdmin(await handleAdminGetRateLimit(url, env), request);
        }
        // A/B Test Whitelist
        if (url.pathname === "/admin/abtest" && request.method === "POST") {
          return withCorsAdmin(await handleAdminABTest(request, url, env), request);
        }
        if (url.pathname.startsWith("/admin/abtest/") && request.method === "GET") {
          return withCorsAdmin(await handleAdminGetABTest(url, env), request);
        }
        // Trend Collections CRUD
        if (url.pathname === "/admin/trends" && request.method === "POST") {
          return withCorsAdmin(await handleAdminCreateTrend(request, url, env), request);
        }
        if (url.pathname === "/admin/trends" && request.method === "GET") {
          return withCorsAdmin(await handleAdminListTrends(url, env), request);
        }
        if (url.pathname.match(/^\/admin\/trends\/[^/]+$/) && request.method === "PUT") {
          return withCorsAdmin(await handleAdminUpdateTrend(request, url, env), request);
        }
        if (url.pathname.match(/^\/admin\/trends\/[^/]+$/) && request.method === "DELETE") {
          return withCorsAdmin(await handleAdminDeleteTrend(url, env), request);
        }
        return new Response(JSON.stringify({ error: "Not found" }), { status: 404, headers: corsH });
      } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: corsH });
      }
    }

    // ── Authenticated API helper ──
    async function authenticateRequest() {
      const projectId = env.FIREBASE_PROJECT_ID || "stilya";
      const authHeader = request.headers.get("Authorization");
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        throw new Error("Missing Authorization header");
      }
      const token = authHeader.slice(7);
      const result = await verifyFirebaseToken(token, projectId);
      return result.sub;
    }

    function withCors(response) {
      const headers = new Headers(response.headers);
      for (const [key, value] of Object.entries(corsHeaders(request))) {
        headers.set(key, value);
      }
      return new Response(response.body, { status: response.status, headers });
    }

    // ── Public Config (no auth) — KV override destekli ──
    if (url.pathname === "/api/config" && request.method === "GET") {
      let disableApp = env.DISABLE_APP;
      let maintenanceMsg = env.MAINTENANCE_MESSAGE;
      let disableModelPhoto = env.DISABLE_MODEL_PHOTO;
      if (env.STILYA_KV) {
        const [kvApp, kvMaint, kvModel] = await Promise.all([
          env.STILYA_KV.get("config:DISABLE_APP"),
          env.STILYA_KV.get("config:MAINTENANCE_MESSAGE"),
          env.STILYA_KV.get("config:DISABLE_MODEL_PHOTO"),
        ]);
        if (kvApp !== null) disableApp = kvApp;
        if (kvMaint !== null) maintenanceMsg = kvMaint;
        if (kvModel !== null) disableModelPhoto = kvModel;
      }
      return withCors(new Response(JSON.stringify({
        appEnabled: disableApp !== "true",
        maintenanceMessage: maintenanceMsg || null,
        modelPhotoEnabled: disableModelPhoto !== "true",
        freeWeeklyCredits: CREDIT_CONSTANTS.freeWeeklyCredits,
        trialCredits: CREDIT_CONSTANTS.trialCredits,
      }), { status: 200, headers: { "Content-Type": "application/json", "Cache-Control": "no-cache" } }));
    }

    // ── Public Trends API (no auth) ──
    if (url.pathname === "/api/trends" && request.method === "GET") {
      try {
        return withCors(await handlePublicGetTrends(url, env));
      } catch (e) {
        return withCors(new Response(JSON.stringify({ error: e.message }), {
          status: 500, headers: { "Content-Type": "application/json" },
        }));
      }
    }

    // ── API Routes (authenticated) ──
    const isApiRoute = url.pathname === "/ai/tryon"
      || url.pathname === "/ai/nano-banana-tryon" // legacy path (v1.x app builds)
      || url.pathname === "/ai/generate-model-photo"
      || url.pathname === "/api/sync-pro"
      || url.pathname === "/api/purchase/verify"
      || url.pathname === "/api/credits"
      || url.pathname === "/api/referral/process"
      || url.pathname === "/api/account/delete"
      || url.pathname === "/api/device/check"
      || url.pathname === "/api/ads/reward"
      || url.pathname === "/api/debug/reset-credits";

    if (isApiRoute) {
      // Authenticate user
      let apiUserId;
      try {
        apiUserId = await authenticateRequest();
      } catch (error) {
        return new Response(
          JSON.stringify({ error: "Unauthorized", ...(IS_DEBUG && { detail: error.message }) }),
          { status: 401, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
        );
      }

      // User-level ban check (after auth)
      const userBanReason = isBanned(clientInfo.ip, apiUserId);
      if (userBanReason) {
        return new Response(
          JSON.stringify({ error: "Access denied" }),
          { status: 403, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
        );
      }

      // App Check verification
      const appCheckBlock = await verifyAppCheck(request);
      if (appCheckBlock) return appCheckBlock;

      // Route to handler — AI endpoints have rate limiting
      if ((url.pathname === "/ai/tryon" || url.pathname === "/ai/nano-banana-tryon") && request.method === "POST") {
        const rl = await checkRateLimit(env, apiUserId);
        if (!rl.allowed) {
          return withCors(new Response(
            JSON.stringify({ error: "Rate limit exceeded", limit: rl.limit, retryAfterMinutes: 60 }),
            { status: 429, headers: { "Content-Type": "application/json" } }
          ));
        }
        const res = await handleTryOn(request, env, apiUserId, clientInfo);
        const headers = new Headers(res.headers);
        headers.set("X-RateLimit-Remaining", String(rl.remaining));
        headers.set("X-RateLimit-Limit", String(rl.limit));
        return withCors(new Response(res.body, { status: res.status, headers }));
      }

      if (url.pathname === "/ai/generate-model-photo" && request.method === "POST") {
        const rl = await checkRateLimit(env, apiUserId);
        if (!rl.allowed) {
          return withCors(new Response(
            JSON.stringify({ error: "Rate limit exceeded", limit: rl.limit, retryAfterMinutes: 60 }),
            { status: 429, headers: { "Content-Type": "application/json" } }
          ));
        }
        const res = await handleGenerateModelPhoto(request, env, apiUserId, clientInfo);
        const headers = new Headers(res.headers);
        headers.set("X-RateLimit-Remaining", String(rl.remaining));
        headers.set("X-RateLimit-Limit", String(rl.limit));
        return withCors(new Response(res.body, { status: res.status, headers }));
      }

      if (url.pathname === "/api/sync-pro" && request.method === "POST") {
        return withCors(await handleSyncPro(request, env, apiUserId));
      }

      if (url.pathname === "/api/purchase/verify" && request.method === "POST") {
        return withCors(await handleVerifyPurchase(request, env, apiUserId));
      }

      if (url.pathname === "/api/credits" && request.method === "GET") {
        return withCors(await handleGetCredits(request, env, apiUserId));
      }

      if (url.pathname === "/api/referral/process" && request.method === "POST") {
        return withCors(await handleProcessReferral(request, env, apiUserId));
      }

      if (url.pathname === "/api/account/delete" && request.method === "POST") {
        return withCors(await handleAccountDelete(request, env, apiUserId));
      }

      if (url.pathname === "/api/device/check" && request.method === "POST") {
        return withCors(await handleDeviceCheck(request, env, apiUserId));
      }

      if (url.pathname === "/api/ads/reward" && request.method === "POST") {
        return withCors(await handleRewardAd(request, env, apiUserId));
      }

      // Debug: reset credits to 0 (only in debug mode)
      if (url.pathname === "/api/debug/reset-credits" && request.method === "POST") {
        if (!IS_DEBUG) {
          return withCors(new Response(
            JSON.stringify({ error: "Not available in production" }),
            { status: 403, headers: { "Content-Type": "application/json" } }
          ));
        }
        try {
          const fsToken = await getFirestoreAccessToken(env);
          const docPath = `users/${apiUserId}`;
          const write = buildUpdateWrite(docPath, {
            credits: 0,
            purchasedCredits: 0,
            proCredits: 0,
          });
          await firestoreCommit(fsToken, null, [write]);
          return withCors(new Response(
            JSON.stringify({ success: true, message: "Credits reset to 0" }),
            { status: 200, headers: { "Content-Type": "application/json" } }
          ));
        } catch (e) {
          return withCors(new Response(
            JSON.stringify({ error: "Failed to reset credits", detail: e.message }),
            { status: 500, headers: { "Content-Type": "application/json" } }
          ));
        }
      }

      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }

    // ── R2 Storage Routes (need path param) ──

    const path = url.searchParams.get("path");

    if (!path) {
      return new Response(
        JSON.stringify({ error: "Missing path parameter" }),
        { status: 400, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }

    // ── Authentication (JWT signature verified) ──
    let userId;
    try {
      const projectId = env.FIREBASE_PROJECT_ID || "stilya";
      const authHeader = request.headers.get("Authorization");
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        throw new Error("Missing Authorization header");
      }
      const token = authHeader.slice(7);
      const result = await verifyFirebaseToken(token, projectId);
      userId = result.sub;
    } catch (error) {
      return new Response(
        JSON.stringify({ error: "Unauthorized", ...(IS_DEBUG && { detail: error.message }) }),
        { status: 401, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }

    // ── App Check verification (after auth, before storage ops) ──
    const storageAppCheckBlock = await verifyAppCheck(request);
    if (storageAppCheckBlock) return storageAppCheckBlock;

    // ── Path authorization (private files: users/{userId}/) ──
    if (!validatePath(path, userId)) {
      console.error(`[Storage] Path auth failed — path: "${path}", userId: "${userId}", expected prefix: "users/${userId}/"`);
      return new Response(
        JSON.stringify({ error: "Forbidden: You can only access your own files" }),
        { status: 403, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }

    // ── Route handling ──
    try {
      // UPLOAD
      if (url.pathname === "/upload" && request.method === "PUT") {
        const body = await request.arrayBuffer();

        if (body.byteLength === 0) {
          return new Response(
            JSON.stringify({ error: "Empty body" }),
            { status: 400, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
          );
        }

        if (body.byteLength > 10 * 1024 * 1024) {
          return new Response(
            JSON.stringify({ error: "File too large (max 10MB)" }),
            { status: 413, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
          );
        }

        const contentType = request.headers.get("Content-Type") || "image/jpeg";
        await env.STILYA_BUCKET.put(path, body, {
          httpMetadata: { contentType },
        });

        return new Response(
          JSON.stringify({ success: true, path }),
          { status: 200, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
        );
      }

      // DOWNLOAD
      if (url.pathname === "/download" && request.method === "GET") {
        const object = await env.STILYA_BUCKET.get(path);

        if (!object) {
          return new Response(
            JSON.stringify({ error: "File not found" }),
            { status: 404, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
          );
        }

        // Model photos should never be cached (user can re-upload anytime)
        const cacheControl = path.includes("model_image")
          ? "no-cache, no-store, must-revalidate"
          : "private, max-age=3600";

        return new Response(object.body, {
          headers: {
            ...corsHeaders(request),
            "Content-Type": object.httpMetadata?.contentType || "image/jpeg",
            "Content-Length": object.size.toString(),
            "Cache-Control": cacheControl,
          },
        });
      }

      // DELETE single file
      if (url.pathname === "/delete" && request.method === "DELETE") {
        await env.STILYA_BUCKET.delete(path);
        return new Response(
          JSON.stringify({ success: true }),
          { status: 200, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
        );
      }

      // DELETE ALL user files (with pagination for 1000+ files)
      if (url.pathname === "/delete-all" && request.method === "DELETE") {
        const prefix = `users/${userId}/`;
        let totalDeleted = 0;
        let cursor = undefined;
        let hasMore = true;

        while (hasMore) {
          const listOptions = { prefix, limit: 1000 };
          if (cursor) {
            listOptions.cursor = cursor;
          }

          const listed = await env.STILYA_BUCKET.list(listOptions);

          if (listed.objects.length > 0) {
            const keys = listed.objects.map((obj) => obj.key);
            await env.STILYA_BUCKET.delete(keys);
            totalDeleted += keys.length;
          }

          hasMore = listed.truncated;
          cursor = listed.cursor;
        }

        return new Response(
          JSON.stringify({ success: true, deleted: totalDeleted }),
          { status: 200, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ error: "Not found" }),
        { status: 404, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    } catch (error) {
      return new Response(
        JSON.stringify({ error: "Internal error", ...(IS_DEBUG && { detail: error.message, stack: error.stack }) }),
        { status: 500, headers: { ...corsHeaders(request), "Content-Type": "application/json" } }
      );
    }
  },
};

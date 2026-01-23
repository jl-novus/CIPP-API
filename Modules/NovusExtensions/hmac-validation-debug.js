// DEBUG VERSION: HMAC Validation with extensive logging
// This will help us understand the exact data structure

// Hardcoded webhook secret (temporary - for testing)
const webhookSecret = "81eaa7f5-e1f8-4452-9cc1-f91e78d561f6";

// Get the first (and only) item from the webhook
const item = $input.first();

console.log('=== FULL ITEM STRUCTURE ===');
console.log(JSON.stringify(item.json, null, 2));

const headers = item.json.headers || {};
const bodyData = item.json.body || item.json;

console.log('\n=== HEADERS ===');
console.log(JSON.stringify(headers, null, 2));

console.log('\n=== BODY DATA ===');
console.log(JSON.stringify(bodyData, null, 2));

// Get the signature and timestamp from headers
const receivedSignature = headers['x-cipp-signature'];
const timestamp = headers['x-cipp-timestamp'];

console.log('\n=== SIGNATURE INFO ===');
console.log('Received signature:', receivedSignature);
console.log('Timestamp:', timestamp);

// Validate timestamp (reject requests older than 5 minutes)
let ageMinutes = 0;
if (timestamp) {
  const requestTime = new Date(timestamp);
  const now = new Date();
  ageMinutes = (now - requestTime) / 1000 / 60;

  console.log('Webhook age (minutes):', ageMinutes);

  if (ageMinutes > 5) {
    throw new Error(`Webhook timestamp too old: ${ageMinutes.toFixed(2)} minutes (max: 5)`);
  }
}

// Try different JSON.stringify approaches
const payload1 = JSON.stringify(bodyData);  // Default (with spaces)
const payload2 = JSON.stringify(bodyData, null, 0);  // No indentation
const payload3 = JSON.stringify(bodyData, null, 2);  // 2-space indentation

console.log('\n=== PAYLOAD VARIATIONS ===');
console.log('payload1 length (default):', payload1.length);
console.log('payload2 length (no indent):', payload2.length);
console.log('payload3 length (2-space):', payload3.length);

console.log('\npayload2 preview (first 300 chars):');
console.log(payload2.substring(0, 300));

// Calculate HMAC for each variation
const crypto = require('crypto');

function calculateHMAC(payload) {
  const hmac = crypto.createHmac('sha256', webhookSecret);
  hmac.update(payload);
  return hmac.digest('base64');
}

const sig1 = calculateHMAC(payload1);
const sig2 = calculateHMAC(payload2);
const sig3 = calculateHMAC(payload3);

console.log('\n=== CALCULATED SIGNATURES ===');
console.log('sig1 (default):', sig1);
console.log('sig2 (no indent):', sig2);
console.log('sig3 (2-space):', sig3);

console.log('\n=== COMPARISON ===');
console.log('Received:', receivedSignature);
console.log('Match sig1?', sig1 === receivedSignature);
console.log('Match sig2?', sig2 === receivedSignature);
console.log('Match sig3?', sig3 === receivedSignature);

// For now, let's pass through regardless of signature match
// This is for debugging only
return {
  json: {
    ...bodyData,
    validatedAt: new Date().toISOString(),
    webhookAge: ageMinutes,
    hmacValidated: false,
    debugInfo: {
      receivedSignature: receivedSignature,
      calculatedSignatures: {
        default: sig1,
        noIndent: sig2,
        twoSpace: sig3
      },
      payloadLengths: {
        default: payload1.length,
        noIndent: payload2.length,
        twoSpace: payload3.length
      }
    }
  }
};

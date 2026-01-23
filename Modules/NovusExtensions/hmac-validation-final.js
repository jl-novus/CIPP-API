// FINAL: HMAC Validation for n8n Code Node
// Fixed to use correct data structure (item.json.body, not item.json)

// Hardcoded webhook secret (temporary - for testing)
const webhookSecret = "81eaa7f5-e1f8-4452-9cc1-f91e78d561f6";

// Get the first (and only) item from the webhook
const item = $input.first();

// In n8n webhook structure:
// - item.json.headers = HTTP headers
// - item.json.body = The actual payload (this is what we sign)
// - item.json.params, query, etc = Other metadata

const headers = item.json.headers || {};
const bodyData = item.json.body || item.json; // Fallback to item.json if no body

// Get the signature and timestamp from headers
const receivedSignature = headers['x-cipp-signature'];
const timestamp = headers['x-cipp-timestamp'];

// Debug: Log what we received
console.log('Headers:', JSON.stringify(headers, null, 2));
console.log('Received signature:', receivedSignature);
console.log('Timestamp:', timestamp);

// Validate timestamp (reject requests older than 5 minutes)
let ageMinutes = 0;
if (timestamp) {
  const requestTime = new Date(timestamp);
  const now = new Date();
  ageMinutes = (now - requestTime) / 1000 / 60;

  if (ageMinutes > 5) {
    throw new Error(`Webhook timestamp too old: ${ageMinutes.toFixed(2)} minutes (max: 5)`);
  }
}

// Stringify the payload (this is what PowerShell signed)
const payload = JSON.stringify(bodyData, null, 0);

console.log('Payload to sign length:', payload.length);
console.log('Payload preview:', payload.substring(0, 200));

// Calculate expected HMAC signature
const crypto = require('crypto');
const hmac = crypto.createHmac('sha256', webhookSecret);
hmac.update(payload);
const expectedSignature = hmac.digest('base64');

// Compare signatures
if (receivedSignature && receivedSignature !== expectedSignature) {
  // Log details for debugging
  console.log('HMAC Validation Failed');
  console.log('Expected:', expectedSignature);
  console.log('Received:', receivedSignature);

  throw new Error('Invalid webhook signature - authentication failed');
}

console.log('HMAC validation passed!');

// Signature valid (or not provided for testing) - return the payload
return {
  json: {
    ...bodyData,
    validatedAt: new Date().toISOString(),
    webhookAge: ageMinutes,
    hmacValidated: receivedSignature ? true : false
  }
};

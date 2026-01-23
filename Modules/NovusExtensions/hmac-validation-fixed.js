// FIXED: HMAC Validation for n8n Code Node
// Headers are accessed differently in n8n webhook flow

// Hardcoded webhook secret (temporary - for testing)
const webhookSecret = "81eaa7f5-e1f8-4452-9cc1-f91e78d561f6";

// Get the first (and only) item from the webhook
const item = $input.first();

// In n8n, headers from webhook are in the item.json.headers object
// OR sometimes in $node["Webhook Receiver"].json.headers
const headers = item.json.headers || item.headers || {};

// Get the signature and timestamp from headers
const receivedSignature = headers['x-cipp-signature'];
const timestamp = headers['x-cipp-timestamp'];

// Debug: Log what we received
console.log('Headers object:', JSON.stringify(headers, null, 2));
console.log('Received signature:', receivedSignature);
console.log('Timestamp:', timestamp);

// Validate timestamp (reject requests older than 5 minutes)
if (timestamp) {
  const requestTime = new Date(timestamp);
  const now = new Date();
  const ageMinutes = (now - requestTime) / 1000 / 60;

  if (ageMinutes > 5) {
    throw new Error(`Webhook timestamp too old: ${ageMinutes.toFixed(2)} minutes (max: 5)`);
  }
}

// Get the body data (remove headers from the payload before signing)
const bodyData = { ...item.json };
delete bodyData.headers; // Don't include headers in signature calculation

// Stringify the payload
const payload = JSON.stringify(bodyData, null, 0);

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
  console.log('Payload length:', payload.length);
  console.log('Payload preview:', payload.substring(0, 200));

  throw new Error('Invalid webhook signature - authentication failed');
}

// Signature valid (or not provided for testing) - return the payload
return {
  json: {
    ...bodyData,
    validatedAt: new Date().toISOString(),
    webhookAge: timestamp ? ageMinutes : 0,
    hmacValidated: receivedSignature ? true : false
  }
};

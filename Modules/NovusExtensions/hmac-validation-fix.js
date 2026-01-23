// UPDATED HMAC Validation Code for n8n Node 2
// This version uses the raw body instead of re-stringifying JSON

// Hardcoded webhook secret (temporary - for testing)
const webhookSecret = "81eaa7f5-e1f8-4452-9cc1-f91e78d561f6";

// Get the first (and only) item from the webhook
const item = $input.first();

// Get headers
const receivedSignature = item.headers['x-cipp-signature'];
const timestamp = item.headers['x-cipp-timestamp'];

// Validate timestamp (reject requests older than 5 minutes)
const requestTime = new Date(timestamp);
const now = new Date();
const ageMinutes = (now - requestTime) / 1000 / 60;

if (ageMinutes > 5) {
  throw new Error(`Webhook timestamp too old: ${ageMinutes.toFixed(2)} minutes (max: 5)`);
}

// Get the raw body - try multiple approaches
// Option 1: Use $node["Webhook Receiver"].binary if available
// Option 2: Use $node["Webhook Receiver"].json and stringify with no formatting
// Option 3: Re-create the exact JSON string from the parsed object

// For now, let's try the simplest approach - stringify with no spaces
const payload = JSON.stringify(item.json, null, 0);

// Calculate expected HMAC signature
const crypto = require('crypto');
const hmac = crypto.createHmac('sha256', webhookSecret);
hmac.update(payload);
const expectedSignature = hmac.digest('base64');

// Compare signatures
if (receivedSignature !== expectedSignature) {
  // Log details for debugging
  console.log('HMAC Validation Failed');
  console.log('Expected:', expectedSignature);
  console.log('Received:', receivedSignature);
  console.log('Payload length:', payload.length);
  console.log('Payload preview:', payload.substring(0, 200));

  throw new Error('Invalid webhook signature - authentication failed');
}

// Signature valid - return the payload
return {
  json: {
    ...(item.json),
    validatedAt: new Date().toISOString(),
    webhookAge: ageMinutes
  }
};

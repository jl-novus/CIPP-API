// TEMPORARY: HMAC Validation DISABLED for testing
// Use this to test the rest of the workflow first
// Replace with proper HMAC validation once workflow is working

// Get the first (and only) item from the webhook
const item = $input.first();

// Get timestamp for validation
const timestamp = item.headers['x-cipp-timestamp'];

// Validate timestamp (reject requests older than 5 minutes)
if (timestamp) {
  const requestTime = new Date(timestamp);
  const now = new Date();
  const ageMinutes = (now - requestTime) / 1000 / 60;

  if (ageMinutes > 5) {
    throw new Error(`Webhook timestamp too old: ${ageMinutes.toFixed(2)} minutes (max: 5)`);
  }

  // Return the payload with validation info
  return {
    json: {
      ...(item.json),
      validatedAt: new Date().toISOString(),
      webhookAge: ageMinutes,
      hmacValidation: 'DISABLED-FOR-TESTING'
    }
  };
} else {
  // No timestamp header - just pass through
  return {
    json: {
      ...(item.json),
      validatedAt: new Date().toISOString(),
      hmacValidation: 'DISABLED-FOR-TESTING'
    }
  };
}

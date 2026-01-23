// Node 5 (Claude AI Analysis) - HTTP Request Configuration Fix
// The jsonBody parameter should only include valid Claude API parameters

// In the n8n UI for Node 5 (Claude AI Analysis):
// Change "JSON Body" from:
//   ={{ JSON.stringify($json) }}
//
// To:
//   ={{ JSON.stringify({ model: $json.model, max_tokens: $json.max_tokens, temperature: $json.temperature, system: $json.system, messages: $json.messages }) }}

// Or more readable (use this in the n8n UI):
{{
  JSON.stringify({
    model: $json.model,
    max_tokens: $json.max_tokens,
    temperature: $json.temperature,
    system: $json.system,
    messages: $json.messages
  })
}}

// This sends ONLY the valid Claude API parameters and excludes:
// - _originalAlert (our custom pass-through data)
// - _correlationId (our custom tracking ID)

// Those fields will still be in $json and accessible to later nodes
// via $node["Build AI Analysis Prompt"].json._originalAlert

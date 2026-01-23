// Node 6: Parse AI Decision - Fixed to handle markdown code blocks

const claudeResponse = $input.first().json;
const originalAlert = $node["Build AI Analysis Prompt"].json._originalAlert;
const correlationId = $node["Build AI Analysis Prompt"].json._correlationId;

// Extract the AI response text from Claude's response format
let aiResponseText = claudeResponse.content[0].text;

// Strip markdown code blocks if present
// Claude sometimes wraps JSON in ```json ... ```
aiResponseText = aiResponseText.replace(/^```json\s*/i, '').replace(/\s*```$/,'').trim();

console.log('AI Response Text (after markdown strip):');
console.log(aiResponseText.substring(0, 200) + '...');

// Parse the JSON response from Claude
let aiDecision;
try {
  aiDecision = JSON.parse(aiResponseText);
  console.log('✅ Successfully parsed AI response');
} catch (error) {
  console.log('❌ Failed to parse AI response:', error.message);
  // If JSON parsing fails, create a fallback structure
  aiDecision = {
    severity: 'high',
    riskScore: 75,
    analysis: aiResponseText,
    recommendedActions: [],
    requiresHumanReview: true,
    humanReviewReason: 'Failed to parse AI response as JSON: ' + error.message,
    confidence: 50
  };
}

// Merge AI decision with original alert data
return {
  json: {
    correlationId: correlationId,
    timestamp: new Date().toISOString(),
    tenant: originalAlert.tenant,
    alert: originalAlert.alert,
    context: originalAlert.context,
    aiDecision: aiDecision,
    claudeMetadata: {
      model: claudeResponse.model,
      usage: claudeResponse.usage,
      stopReason: claudeResponse.stop_reason
    }
  }
};

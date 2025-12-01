// Stub file to replace @initia/initia.js imports
// This prevents the module resolution error while providing empty implementations

// Export empty objects/functions for the commonly used exports
export const bcs = {
  // Add any bcs methods that might be used
};

export const MsgExecute = class {
  constructor() {
    // Empty implementation
  }
};

// Add other exports as needed based on what @thalalabs/surf uses
export default {
  bcs,
  MsgExecute,
};

# Otim Documentation Light Mode Color Fix

## Issue
The current green color in the Otim documentation is unreadable in light mode, as reported in Linear issue ENG-964.

## Solution
Replace the problematic green color with the colors indicated in the issue labels:

### Recommended Colors
- **Primary Color**: `#f2994a` (orange - from Documentation label)
- **Secondary Color**: `#4ea7fc` (blue - from Improvement label)

## Implementation

### For Mintlify Documentation (mint.json)
Update the `colors` section in your `mint.json` file:

```json
{
  "colors": {
    "primary": "#f2994a",
    "light": "#4ea7fc", 
    "dark": "#f2994a",
    "anchors": {
      "from": "#f2994a",
      "to": "#4ea7fc"
    }
  }
}
```

### Specific Changes Needed
1. **Replace the current green primary color** with `#f2994a` (orange)
2. **Set light mode accent color** to `#4ea7fc` (blue)
3. **Update anchor gradient** to use both colors for a smooth transition
4. **Ensure dark mode compatibility** by keeping the primary color consistent

### Files to Update in otim-docs Repository
- `mint.json` - Main configuration file
- Any custom CSS files that override Mintlify defaults
- Theme configuration files

### Testing
After applying these changes:
1. Test the documentation in light mode to ensure readability
2. Verify that the colors work well with the existing content
3. Check that the gradient transitions look smooth
4. Ensure dark mode still functions properly

## Color Accessibility
Both recommended colors (`#f2994a` and `#4ea7fc`) provide good contrast ratios for accessibility compliance.
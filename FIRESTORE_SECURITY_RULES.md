# Firestore Security Rules

## Quick Setup

Go to **Firebase Console** → **Firestore Database** → **Rules** tab and paste this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Game saves - users can only read/write their own saves
    match /game_saves/{userId} {
      allow read, write: if isOwner(userId);
    }
    
    // Player profiles - public read (for leaderboard), own write
    match /players/{userId} {
      allow read: if isAuthenticated(); // Anyone signed in can read (for leaderboard)
      allow write: if isOwner(userId); // Only owner can write
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Steps to Apply

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Firestore Database** → **Rules** tab
4. Paste the rules above
5. Click **Publish**

## Testing

After publishing, the app should be able to:
- ✅ Save game state to `game_saves/{userId}`
- ✅ Load game state from `game_saves/{userId}`
- ✅ Read player profiles for leaderboard
- ✅ Update own player profile

## Troubleshooting

If you still get permission errors:
1. Wait 1-2 minutes for rules to propagate
2. Sign out and sign back in
3. Check that user is authenticated: `request.auth != null`
4. Verify user ID matches: `request.auth.uid == userId`

